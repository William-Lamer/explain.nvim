-- Remembers the last terminal job that failed, so its output can be explained after the
-- terminal is closed. Fed by the TermOpen and TermClose autocommands in plugin/explain.lua.

local util = require 'explain.util'

local M = {}

local last_failed = nil

function M.on_term_open(ev)
  -- :terminal makes the buffer it was started from the alternate buffer
  local alt = vim.fn.bufnr '#'
  if alt > 0 and util.is_file_buffer(alt) then
    vim.b[ev.buf].explain_source = alt
  end
end

function M.on_term_close(ev)
  if vim.b[ev.buf].explain_chat then
    return
  end
  local status = vim.v.event.status
  if status == 0 then
    last_failed = nil
    return
  end
  last_failed = {
    command = util.terminal_command(ev.buf),
    status = status,
    output = util.terminal_output(ev.buf),
    source = vim.b[ev.buf].explain_source,
    root = util.project_root(ev.buf),
  }
end

-- Only runs from the same project count, so an old failure elsewhere is never explained here
function M.last_failed(root)
  if last_failed and last_failed.root == root then
    return last_failed
  end
end

return M
