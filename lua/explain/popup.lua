-- The floating window an answer streams into. Its content lives in a state table rather than in
-- the buffer, so the window can be closed and reopened while the answer keeps streaming in.
-- state is { mode, title, root, text, done, session_id, buf, proc }

local cli = require 'explain.cli'
local config = require 'explain.config'
local util = require 'explain.util'

local M = {}

local ns = vim.api.nvim_create_namespace 'explain'
local last = nil

local function render(state)
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    vim.bo[state.buf].modifiable = true
    vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, vim.split(state.text == '' and '_Thinking..._' or state.text, '\n'))
    vim.bo[state.buf].modifiable = false
  end
end

local function open_window(title)
  local opts = config.options.popup
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].filetype = 'markdown'
  vim.bo[buf].bufhidden = 'wipe'
  local width = math.min(opts.max_width, math.floor(vim.o.columns * opts.width))
  local height = math.floor(vim.o.lines * opts.height)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    border = opts.border,
    title = ' ' .. title .. ' ',
    title_pos = 'center',
    footer = ' q close   c continue in chat ',
    footer_pos = 'center',
  })
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true
  vim.wo[win].conceallevel = 2
  return buf
end

local function show(state, on_close)
  local buf = open_window(state.mode.model .. ': ' .. state.title)
  state.buf = buf
  render(state)
  if on_close then
    vim.api.nvim_create_autocmd('BufWipeout', { buffer = buf, once = true, callback = on_close })
  end

  local function close()
    vim.api.nvim_buf_delete(buf, { force = true })
  end
  vim.keymap.set('n', 'q', close, { buffer = buf, desc = 'Close' })
  vim.keymap.set('n', '<Esc>', close, { buffer = buf, desc = 'Close' })
  vim.keymap.set('n', 'c', function()
    if not state.done or not state.session_id then
      vim.notify('explain.nvim: wait for the answer to finish first', vim.log.levels.INFO)
      return
    end
    close()
    -- The chat loads the full Claude Code setup even when the popup used a lite mode
    require('explain.chat').start(state.mode, state.root, { '--resume', state.session_id })
  end, { buffer = buf, desc = 'Continue in chat' })
end

-- Opens a popup for ctx (see explain.context) and streams the answer into it
function M.open(mode, ctx)
  if not cli.has_claude() then
    return
  end
  -- Only the last popup can be brought back, so an unfinished one that is not on screen would
  -- keep running and costing tokens for an answer nobody can see
  if last and last.proc and not last.done and not (last.buf and vim.fn.bufwinid(last.buf) ~= -1) then
    last.proc:kill 'sigterm'
  end
  local state = { mode = mode, title = ctx.title, root = util.project_root(vim.api.nvim_get_current_buf()), text = '', done = false }
  last = state

  local focus = ctx.focus
  local mark
  if focus then
    mark = vim.api.nvim_buf_set_extmark(focus.buf, ns, focus.first - 1, 0, {
      end_row = focus.last - 1,
      end_col = #vim.api.nvim_buf_get_lines(focus.buf, focus.last - 1, focus.last, false)[1],
      hl_group = config.options.popup.highlight,
      hl_eol = true,
    })
  end
  show(state, function()
    if mark and vim.api.nvim_buf_is_valid(focus.buf) then
      vim.api.nvim_buf_del_extmark(focus.buf, ns, mark)
    end
  end)

  state.proc = cli.run(state, ctx.prompt, function()
    render(state)
  end)
end

-- Reopens the most recent popup without calling Claude again. The highlight isn't restored,
-- since the code may have changed since.
function M.reopen_last()
  if not last then
    vim.notify('explain.nvim: no popup to bring back yet', vim.log.levels.INFO)
    return
  end
  local win = last.buf and vim.fn.bufwinid(last.buf) or -1
  if win ~= -1 then
    vim.api.nvim_set_current_win(win)
  else
    show(last)
  end
end

return M
