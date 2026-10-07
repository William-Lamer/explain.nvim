-- An interactive Claude Code session in a vertical terminal split.

local config = require 'explain.config'
local util = require 'explain.util'

local M = {}

local chat = {}

local function is_running()
  if not (chat.buf and vim.api.nvim_buf_is_valid(chat.buf)) then
    return false
  end
  local job = vim.b[chat.buf].terminal_job_id
  return job ~= nil and vim.fn.jobwait({ job }, 0)[1] == -1
end

local function show_window()
  vim.cmd 'botright vsplit'
  chat.win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(chat.win, chat.buf)
  vim.api.nvim_win_set_width(chat.win, math.max(config.options.chat.min_width, math.floor(vim.o.columns * config.options.chat.width)))
  vim.cmd.startinsert()
end

-- Sessions are stored per directory, so a resumed session must start in the same root.
-- Replaces any chat that is already open.
function M.start(mode, root, extra_args)
  if chat.buf and vim.api.nvim_buf_is_valid(chat.buf) then
    vim.api.nvim_buf_delete(chat.buf, { force = true })
  end
  chat.buf = vim.api.nvim_create_buf(false, true)
  show_window()
  local cmd = vim.list_extend({ config.options.cmd, '--model', mode.model, '--effort', mode.effort }, extra_args or {})
  vim.fn.jobstart(cmd, { term = true, cwd = root })
  vim.b[chat.buf].explain_chat = true
end

function M.toggle(mode)
  if chat.win and vim.api.nvim_win_is_valid(chat.win) then
    vim.api.nvim_win_hide(chat.win)
    chat.win = nil
  elseif is_running() then
    show_window()
  else
    M.start(mode, util.project_root(vim.api.nvim_get_current_buf()))
  end
end

return M
