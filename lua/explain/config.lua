local M = {}

M.defaults = {
  -- The Claude Code executable
  cmd = 'claude',

  -- Modes are selected by name when calling an explain function. A lite mode replaces Claude Code's
  -- system prompt, tools and settings with a short prompt, which cuts a call from ~13k to ~0.5k
  -- input tokens. It can't read other files, so a deep mode is there for harder questions.
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
    append_system_prompt = 'The answer is shown in a popup in the editor. Read other project files only if the answer depends on them.',
    tools = { 'Read', 'Grep', 'Glob' },
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

-- vim.tbl_deep_extend merges lists by index, so a user list would be mixed with the default one
local LIST_OPTIONS = { { 'root_markers' }, { 'deep', 'tools' } }

function M.setup(opts)
  opts = opts or {}
  M.options = vim.tbl_deep_extend('force', vim.deepcopy(M.defaults), opts)
  for _, path in ipairs(LIST_OPTIONS) do
    local value = vim.tbl_get(opts, unpack(path))
    if value then
      local parent = #path == 1 and M.options or vim.tbl_get(M.options, unpack(path, 1, #path - 1))
      parent[path[#path]] = value
    end
  end
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
