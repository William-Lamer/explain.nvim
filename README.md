# explain.nvim

[![CI](https://github.com/William-Lamer/explain.nvim/actions/workflows/ci.yml/badge.svg)](https://github.com/William-Lamer/explain.nvim/actions/workflows/ci.yml)

Explain errors and code in Neovim with one key, using [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

Put the cursor on a compiler error, a crash in a terminal split, or any piece of code, press a key, and an explanation streams into a popup: what is wrong, why, and how to fix it. When one answer is not enough, press `c` to continue the same conversation in a full Claude Code chat next to your code.

<!-- Demo GIF: docs/demo.gif -->

## Features

- **Explain errors** from LSP diagnostics, a terminal's output, or the last command that failed (`make`, `gcc`, a crash with an AddressSanitizer report), even after the terminal is closed.
- **Explain code** with any motion or text object: a line, a word like `malloc`, a `{ }` block, a function, or a visual selection.
- **Find bugs** in selected lines when there is no error message at all.
- **Cheap by default.** The quick mode replaces Claude Code's system prompt, tools and settings with a three sentence prompt, so a call costs about 560 input tokens instead of about 13,000.
- **Continue in chat.** Every popup is a saved Claude Code session. Press `c` to resume it in a vertical split, where Claude can read your project and run your code.
- **Bring back** the last popup without calling Claude again. Closing a popup does not cancel the answer.
- No API key: it runs through the `claude` CLI and your existing Claude subscription.

## Requirements

- Neovim 0.11 or newer
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed and logged in (`claude` on your `PATH`)
- A treesitter parser for your language, only for explaining the function under the cursor

Run `:checkhealth explain` to verify your setup.

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  'William-Lamer/explain.nvim',
  -- Not lazy-loaded, so failed terminal runs are remembered from startup. Loading it is cheap.
  lazy = false,
  opts = {},
  keys = {
    { '<leader>ce', function() require('explain').explain_error() end, mode = { 'n', 'x' }, desc = 'Explain error' },
    { '<leader>cE', function() require('explain').explain_error 'deep' end, mode = { 'n', 'x' }, desc = 'Explain error (deep)' },
    { '<leader>cx', function() return require('explain').operator() end, expr = true, desc = 'Explain code {motion}' },
    { '<leader>cxx', function() return require('explain').operator() .. '_' end, expr = true, desc = 'Explain line' },
    { '<leader>cx', function() require('explain').explain_code() end, mode = 'x', desc = 'Explain selection' },
    { '<leader>cf', function() require('explain').explain_function() end, desc = 'Explain function' },
    { '<leader>cc', function() require('explain').toggle_chat() end, desc = 'Toggle chat' },
    { '<leader>cb', function() require('explain').reopen_last() end, desc = 'Bring back last popup' },
  },
}
```

The plugin sets no keymaps on its own. These are suggestions.

## Usage

| Keys (from the example above) | What is explained |
|---|---|
| `<leader>ce` | The error at the cursor: a diagnostic on the cursor line, the terminal under the cursor, the last failed run in this project, or warnings elsewhere in the file |
| `<leader>ce` in visual mode | Bugs in the selected lines |
| `<leader>cxx` | The current line (`3<leader>cxx` for three lines) |
| `<leader>cx` + motion | Any text object: `iw` for one word, `i{` for a block, `ip` for a paragraph |
| `<leader>cx` in visual mode | The selection |
| `<leader>cf` | The function around the cursor |
| `<leader>cc` | Show or hide the chat split |
| `<leader>cb` | The last popup again, without a new request |

In the popup, `q` or `<Esc>` closes it and `c` continues the conversation in the chat split.

The same actions are available as a command, with completion:

```vim
:Explain                 " error at the cursor
:'<,'>Explain error      " bugs in a range
:'<,'>Explain code deep  " explain a range with the deep mode
:Explain function
:Explain chat
:Explain last
```

### Capturing errors from runs

Compile and run inside a Neovim terminal, for example `:split | terminal make`, and a failure is remembered when the command exits. Press the error key from your source file afterwards and the output is explained together with the lines it points at. Output from `:!` cannot be captured, since Neovim does not keep it.

## Configuration

`setup()` is optional. These are the defaults:

```lua
require('explain').setup {
  cmd = 'claude',
  modes = {
    quick = { model = 'sonnet', effort = 'medium', lite = true },
    deep = { model = 'opus', effort = 'high', lite = false },
  },
  default_mode = 'quick',
  lite = {
    system_prompt = '...', -- see lua/explain/config.lua
    max_file_lines = 150, -- larger files send only a window around the target
    window = 50,
  },
  deep = {
    append_system_prompt = '...',
    tools = { 'Read', 'Grep', 'Glob' },
  },
  output = { head = 40, tail = 60 }, -- lines kept from long terminal output
  root_markers = { '.git', 'Makefile', 'CMakeLists.txt', 'compile_commands.json', 'compile_flags.txt', 'Cargo.toml', 'package.json', 'pyproject.toml', 'go.mod' },
  popup = { width = 0.7, max_width = 100, height = 0.6, border = 'rounded', highlight = 'Visual' },
  chat = { width = 0.4, min_width = 70 },
}
```

Every function takes a mode name, so adding a mode is enough to add a keymap for it:

```lua
opts = {
  modes = { fast = { model = 'haiku', effort = 'low', lite = true } },
},
keys = {
  { '<leader>ch', function() require('explain').explain_error 'fast' end, desc = 'Explain error (fast)' },
},
```

## Token usage

Measured with Claude Code 2.1 on small C files:

| Call | Input tokens | Output tokens |
|---|---|---|
| Quick mode, explain an error | ~560 | ~220 |
| Quick mode, explain a function | ~540 | ~300 to 400 |
| Deep mode (Opus), explain an error | ~7,100 | ~700 |
| Claude Code's default setup, for comparison | ~29,000 | |

Opening the chat split is free until you send a message. The first message loads the full Claude Code setup, so prefer the popup for quick questions.

## How it works

`claude -p` runs asynchronously with `--output-format stream-json`, and the answer is assembled from its text deltas as they arrive. The prompt holds the error or the code range plus the current file with line numbers. A lite mode passes `--system-prompt`, `--tools ''` and `--setting-sources ''`, which skips Claude Code's default prompt, tool definitions, skills and settings. The session id from the stream is what `c` passes to `claude --resume` in the chat split.

Failed runs come from `TermOpen` and `TermClose` autocommands: the output of a terminal job that exits with an error is stored with the file the terminal was opened from and the project root, and only offered again in that project.

## Similar plugins

- [wtf.nvim](https://github.com/piersolenski/wtf.nvim) explains diagnostics through AI provider APIs.
- [claudecode.nvim](https://github.com/coder/claudecode.nvim) integrates the full Claude Code agent into Neovim.

explain.nvim focuses on fast, low cost explanations of both errors and code through the Claude Code CLI, with an easy path into a full chat when needed.

## Development

```sh
make test   # runs the tests with mini.test (cloned into deps/)
make check  # stylua formatting check
```

## License

MIT
