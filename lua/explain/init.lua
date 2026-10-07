-- Public API. Every function takes an optional mode: a name from `modes` in the config, a mode
-- table, or nil for `default_mode`.

local config = require 'explain.config'
local context = require 'explain.context'
local popup = require 'explain.popup'
local util = require 'explain.util'

local M = {}

function M.setup(opts)
  config.setup(opts)
end

-- Explains the most relevant error at the cursor. In visual mode, or given a target
-- { first, last }, looks for bugs in those lines instead.
function M.explain_error(mode, target)
  mode = config.mode(mode)
  if not target and util.in_visual_mode() then
    target = util.visual_target()
  end
  local ctx = context.error(mode, target)
  if not ctx then
    vim.notify('explain.nvim: no errors here and no failed run. Select code to look for bugs in it.', vim.log.levels.INFO)
    return
  end
  popup.open(mode, ctx)
end

-- Explains the visual selection, the given target { first, last, text } or the current line
function M.explain_code(mode, target)
  mode = config.mode(mode)
  if not target then
    if util.in_visual_mode() then
      target = util.visual_target()
    else
      local line = vim.api.nvim_win_get_cursor(0)[1]
      target = { first = line, last = line }
    end
  end
  popup.open(mode, context.code(mode, target))
end

function M.explain_function(mode)
  mode = config.mode(mode)
  local target = util.enclosing_function()
  if not target then
    vim.notify('explain.nvim: the cursor is not inside a function (needs a treesitter parser for this filetype)', vim.log.levels.INFO)
    return
  end
  popup.open(mode, context.code(mode, target))
end

local operator_mode = nil

-- For an expr mapping: returns 'g@', so the mapping waits for a motion or text object and then
-- explains the code it covers. Append '_' for the current line, like `dd`.
function M.operator(mode)
  operator_mode = config.mode(mode)
  vim.o.operatorfunc = "v:lua.require'explain'._operatorfunc"
  return 'g@'
end

function M._operatorfunc(motion_type)
  local first, last = vim.fn.line "'[", vim.fn.line "']"
  local text
  if motion_type == 'char' and first == last then
    text = table.concat(vim.fn.getregion(vim.fn.getpos "'[", vim.fn.getpos "']", { type = 'v' }), '\n')
  end
  M.explain_code(operator_mode, { first = first, last = last, text = text })
end

function M.toggle_chat(mode)
  if require('explain.cli').has_claude() then
    require('explain.chat').toggle(config.mode(mode))
  end
end

function M.reopen_last()
  popup.reopen_last()
end

return M
