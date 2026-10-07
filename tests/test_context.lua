local config = require 'explain.config'
local context = require 'explain.context'
local runs = require 'explain.runs'
local util = require 'explain.util'
local eq = MiniTest.expect.equality

local T = MiniTest.new_set {
  hooks = {
    post_case = function()
      vim.diagnostic.reset()
      vim.cmd 'silent! only | silent! %bwipeout!'
    end,
  },
}

local quick = config.mode 'quick'
local ns = vim.api.nvim_create_namespace 'explain-test'

local function contains(haystack, needle)
  if not haystack:find(needle, 1, true) then
    error(string.format('expected to find %q in:\n%s', needle, haystack), 2)
  end
end

-- Opens a C file with `line_count` lines in a fresh directory, which becomes its project root
local function open_project_file(name, line_count)
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, 'p')
  local lines = {}
  for i = 1, line_count do
    lines[i] = 'int v' .. i .. ' = ' .. i .. ';'
  end
  vim.fn.writefile(lines, dir .. '/' .. name)
  vim.cmd.edit(dir .. '/' .. name)
  return vim.api.nvim_get_current_buf()
end

-- Runs cmd in a terminal split opened from the current file, then returns to the file
local function run_in_terminal(cmd)
  local source_win = vim.api.nvim_get_current_win()
  local closed = false
  vim.api.nvim_create_autocmd('TermClose', {
    once = true,
    callback = function()
      closed = true
    end,
  })
  vim.cmd('split | terminal ' .. cmd)
  vim.wait(5000, function()
    return closed
  end)
  vim.api.nvim_set_current_win(source_win)
end

T['error()'] = MiniTest.new_set()

T['error()']['explains the diagnostic on the cursor line'] = function()
  local buf = open_project_file('main.c', 3)
  vim.diagnostic.set(ns, buf, { { lnum = 1, col = 4, message = 'use of undeclared identifier', severity = vim.diagnostic.severity.ERROR, source = 'clang' } })
  vim.api.nvim_win_set_cursor(0, { 2, 0 })

  local ctx = context.error(quick)
  eq(ctx.title, 'error on line 2')
  eq(ctx.focus, { buf = buf, first = 2, last = 2 })
  contains(ctx.prompt, '- line 2, col 5 [ERROR] clang: use of undeclared identifier')
  contains(ctx.prompt, 'File main.c (full file')
end

T['error()']['uses a failed run, centered on the line it mentions'] = function()
  open_project_file('main.c', 300)
  run_in_terminal 'echo main.c:250:3: error: boom; exit 2'
  vim.api.nvim_win_set_cursor(0, { 1, 0 })

  local ctx = context.error(quick)
  eq(ctx.title, 'last failed run')
  contains(ctx.prompt, 'which exited with status 2')
  contains(ctx.prompt, 'main.c:250:3: error: boom')
  contains(ctx.prompt, 'lines 200-300 of 300')
end

T['error()']['ignores a failed run from another project'] = function()
  open_project_file('main.c', 3)
  run_in_terminal 'echo main.c:1: error: boom; exit 1'
  open_project_file('other.c', 3)
  eq(context.error(quick), nil)
end

T['error()']['forgets a failed run after a successful one'] = function()
  local buf = open_project_file('main.c', 3)
  run_in_terminal 'exit 1'
  eq(runs.last_failed(util.project_root(buf)) ~= nil, true)
  run_in_terminal 'exit 0'
  eq(context.error(quick), nil)
end

T['error()']['prefers the cursor line over a failed run'] = function()
  local buf = open_project_file('main.c', 3)
  run_in_terminal 'exit 1'
  vim.diagnostic.set(ns, buf, { { lnum = 0, col = 0, message = 'boom', severity = vim.diagnostic.severity.ERROR } })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  eq(context.error(quick).title, 'error on line 1')
end

T['error()']['looks for bugs in a target range'] = function()
  local buf = open_project_file('main.c', 10)
  vim.diagnostic.set(ns, buf, {
    { lnum = 3, col = 0, message = 'inside', severity = vim.diagnostic.severity.WARN },
    { lnum = 8, col = 0, message = 'outside', severity = vim.diagnostic.severity.WARN },
  })

  local ctx = context.error(quick, { first = 3, last = 5 })
  eq(ctx.title, 'bugs in lines 3-5')
  contains(ctx.prompt, 'inside')
  eq(ctx.prompt:find('outside', 1, true), nil)
end

T['code()'] = MiniTest.new_set()

T['code()']['narrows the question to selected text'] = function()
  local buf = open_project_file('main.c', 3)
  local ctx = context.code(quick, { first = 2, last = 2, text = 'v2' })
  eq(ctx.title, 'explain `v2`')
  eq(ctx.focus, { buf = buf, first = 2, last = 2 })
  contains(ctx.prompt, 'Explain `v2` on line 2')
end

return T
