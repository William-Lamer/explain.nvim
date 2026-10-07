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
  -- -1 is a job killed by Neovim (:bdelete! on a running terminal) and 130 is Ctrl-C or Esc in a
  -- picker like fzf. Neither is an error worth explaining, so the previous failure is kept.
  if status == -1 or status == 130 then
    return
  end
  local root = util.project_root(ev.buf)
  if status == 0 then
    if last_failed and last_failed.root == root then
      last_failed = nil
    end
    return
  end
  last_failed = {
    command = util.terminal_command(ev.buf),
    status = status,
    output = util.terminal_output(ev.buf),
    source = vim.b[ev.buf].explain_source,
    root = root,
  }
end

-- Only runs from the same project count, so an old failure elsewhere is never explained here
function M.last_failed(root)
  if last_failed and last_failed.root == root then
    return last_failed
  end
end

return M
