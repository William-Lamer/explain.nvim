local M = {}

M.defaults = {
  -- The Claude Code executable
  cmd = 'claude',

  -- Modes are selected by name when calling an explain function. A lite mode replaces Claude Code's
  -- system prompt, tools and settings with a short prompt, which cuts a call from ~7k input tokens
  -- (deep mode) to ~0.5k. It can't read other files, so a deep mode is there for harder questions.
  modes = {
    quick = { model = 'sonnet', effort = 'medium', lite = true },
    deep = { model = 'opus', effort = 'high', lite = false },
  },
  default_mode = 'quick',

  lite = {
    system_prompt = 'You help a programmer understand errors and code from inside their editor. '
      .. 'Explain why things work or fail, not just the fix, but be concise: the answer is shown in a small popup. '
      .. 'Use short paragraphs or bullets and markdown code blocks. Aim for under 200 words unless the code truly needs more.',
    -- Files up to this many lines are sent whole, larger ones as a window around the target
    max_file_lines = 150,
    window = 50,
  },

  deep = {
    append_system_prompt = 'The answer is shown in a popup in the editor. Read other project files, or more of this one, only if the answer depends on them.',
    tools = { 'Read', 'Grep', 'Glob' },
    -- Larger than in lite modes, and Claude can read the rest of the file if it needs to
    max_file_lines = 500,
    window = 200,
  },

  -- Long terminal output keeps both ends: compilers put the root cause first, crashes put it last
  output = { head = 40, tail = 60 },

  -- Claude runs from the nearest directory containing one of these, so it can find other project files
  root_markers = {
    '.git',
    'Makefile',
    'CMakeLists.txt',
    'compile_commands.json',
    'compile_flags.txt',
    'Cargo.toml',
    'package.json',
    'pyproject.toml',
    'go.mod',
  },

  popup = {
    width = 0.7,
    max_width = 100,
    height = 0.6,
    border = 'rounded',
    -- Highlight group for the code being explained while the popup is open
    highlight = 'Visual',
  },

  chat = {
    width = 0.4,
    min_width = 70,
  },
}

M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend('force', vim.deepcopy(M.defaults), opts or {})
end

-- Accepts a mode name, a mode table or nil for the default mode
function M.mode(mode)
  if type(mode) == 'table' then
    return mode
  end
  local name = mode or M.options.default_mode
  local resolved = M.options.modes[name]
  if not resolved then
    error(string.format("explain.nvim: unknown mode '%s'", name), 0)
  end
  return resolved
end

return M
