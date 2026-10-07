local util = require 'explain.util'
local eq = MiniTest.expect.equality

local T = MiniTest.new_set {
  hooks = {
    post_case = function()
      vim.cmd 'silent! %bwipeout!'
    end,
  },
}

local function numbers(n)
  local out = {}
  for i = 1, n do
    out[i] = tostring(i)
  end
  return out
end

T['trim_output()'] = MiniTest.new_set()

T['trim_output()']['keeps short output and drops trailing blank lines'] = function()
  eq(util.trim_output({ 'error: boom', '', '' }, 40, 60), { 'error: boom' })
end

T['trim_output()']['keeps the head and tail of long output'] = function()
  eq(util.trim_output(numbers(300), 2, 3), { '1', '2', '... (295 lines omitted) ...', '298', '299', '300' })
end

T['line_mentioned_in()'] = MiniTest.new_set()

T['line_mentioned_in()']['reads a compiler location'] = function()
  eq(util.line_mentioned_in('main.c:14:5: error: expected expression', '/home/me/proj/main.c'), 14)
end

T['line_mentioned_in()']['reads a location with a directory prefix'] = function()
  eq(util.line_mentioned_in('/home/me/proj/main.c:7:1: warning: unused variable', 'main.c'), 7)
end

T['line_mentioned_in()']['reads a sanitizer stack frame'] = function()
  local asan = '==1234==ERROR: AddressSanitizer: heap-buffer-overflow\n    #0 0x100003f2c in main overflow.c:6\n'
  eq(util.line_mentioned_in(asan, 'overflow.c'), 6)
end

T['line_mentioned_in()']['ignores another file whose name ends the same way'] = function()
  eq(util.line_mentioned_in('xmain.c:3:1: error: boom', 'main.c'), nil)
end

T['line_mentioned_in()']['handles pattern characters in file names'] = function()
  eq(util.line_mentioned_in('my-file+1.c:9:2: error', 'my-file+1.c'), 9)
end

T['line_mentioned_in()']['reads the last frame of a Python traceback'] = function()
  local traceback = table.concat({
    'Traceback (most recent call last):',
    '  File "/home/me/proj/app.py", line 40, in <module>',
    '    main()',
    '  File "/home/me/proj/app.py", line 12, in main',
    '    return 1 / 0',
    'ZeroDivisionError: division by zero',
  }, '\n')
  eq(util.line_mentioned_in(traceback, 'app.py'), 12)
end

T['file_window()'] = MiniTest.new_set()

T['file_window()']['sends small files whole'] = function()
  eq({ util.file_window(120, 100, 100, 150, 50) }, { 1, 120 })
end

T['file_window()']['centers large files on the target'] = function()
  eq({ util.file_window(300, 120, 130, 150, 50) }, { 70, 180 })
end

T['file_window()']['clamps the window to the file'] = function()
  eq({ util.file_window(300, 250, 250, 150, 50) }, { 200, 300 })
  eq({ util.file_window(300, 5, 5, 150, 50) }, { 1, 55 })
end

T['file_window()']['starts at the top without a target'] = function()
  eq({ util.file_window(300, nil, nil, 150, 50) }, { 1, 51 })
end

T['enclosing_function()'] = MiniTest.new_set()

local function buffer(filetype, lines)
  local buf = vim.api.nvim_create_buf(true, true)
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = filetype
  return buf
end

local C_SOURCE = {
  'int add(int a, int b);',
  '',
  'int add(int a, int b) {',
  '    return a + b;',
  '}',
}

T['enclosing_function()']['finds the C function around the cursor'] = function()
  buffer('c', C_SOURCE)
  vim.api.nvim_win_set_cursor(0, { 4, 4 })
  eq(util.enclosing_function(), { first = 3, last = 5 })
end

T['enclosing_function()']['finds the function from its name in the signature'] = function()
  buffer('c', C_SOURCE)
  vim.api.nvim_win_set_cursor(0, { 3, 5 })
  eq(util.enclosing_function(), { first = 3, last = 5 })
end

T['enclosing_function()']['does not treat a prototype as a function'] = function()
  buffer('c', C_SOURCE)
  vim.api.nvim_win_set_cursor(0, { 1, 5 })
  eq(util.enclosing_function(), nil)
end

T['enclosing_function()']['skips a function call inside a Lua function'] = function()
  buffer('lua', { 'local function greet()', "  print('hi')", 'end' })
  vim.api.nvim_win_set_cursor(0, { 2, 3 })
  eq(util.enclosing_function(), { first = 1, last = 3 })
end

-- Java's grammar isn't bundled with Neovim, so its node names are checked directly
T['enclosing_function()']['does not treat a Java method call as a function'] = function()
  eq(util.is_function_node 'method_declaration', true)
  eq(util.is_function_node 'method_invocation', false)
  eq(util.is_function_node 'method_reference', false)
end

T['enclosing_function()']['returns nil without a parser'] = function()
  buffer('', { 'plain text' })
  eq(util.enclosing_function(), nil)
end

return T
