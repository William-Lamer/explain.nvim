local config = require 'explain.config'

local M = {}

function M.is_file_buffer(buf)
  return buf ~= nil and vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == '' and vim.api.nvim_buf_get_name(buf) ~= ''
end

-- Terminal buffers resolve to the root of the file they were opened from
function M.project_root(buf)
  if M.is_file_buffer(buf) then
    return vim.fs.root(buf, config.options.root_markers) or vim.fs.dirname(vim.api.nvim_buf_get_name(buf))
  end
  local source = vim.b[buf].explain_source
  if M.is_file_buffer(source) then
    return M.project_root(source)
  end
  return vim.fn.getcwd()
end

-- Terminal buffer names look like term://{cwd}//{pid}:{cmd}
function M.terminal_command(buf)
  return vim.api.nvim_buf_get_name(buf):match '^term://.-//%d+:(.*)$' or 'a command'
end

-- Drops trailing blank lines (terminal buffers are padded with them) and keeps only the first
-- `head` and last `tail` lines of long output.
function M.trim_output(lines, head, tail)
  lines = vim.list_slice(lines)
  while #lines > 0 and lines[#lines] == '' do
    table.remove(lines)
  end
  local omitted = #lines - head - tail
  if omitted <= 0 then
    return lines
  end
  local trimmed = vim.list_slice(lines, 1, head)
  table.insert(trimmed, string.format('... (%d lines omitted) ...', omitted))
  return vim.list_extend(trimmed, vim.list_slice(lines, #lines - tail + 1))
end

function M.terminal_output(buf)
  local lines = M.trim_output(vim.api.nvim_buf_get_lines(buf, 0, -1, false), config.options.output.head, config.options.output.tail)
  return table.concat(lines, '\n')
end

-- Line of `path` that compiler or sanitizer output points at, like "main.c:14:5: error" or
-- "#0 0x1000 in main main.c:14", or a Python traceback frame like `File "main.py", line 14`.
-- The frontier keeps "xmain.c:3" from matching main.c.
function M.line_mentioned_in(output, path)
  local name = vim.fs.basename(path)
  if name == '' then
    return nil
  end
  local file = '%f[%w_%.%-]' .. vim.pesc(name)
  local line = output:match(file .. ':(%d+)')
  if line then
    return tonumber(line)
  end
  -- Tracebacks list the most recent call last, so the last frame in this file is where it failed
  for frame in output:gmatch(file .. '", line (%d+)') do
    line = frame
  end
  return tonumber(line)
end

-- Which lines of a file to send: all of it when small, otherwise `window` lines around the target
function M.file_window(line_count, first, last, max_lines, window)
  if line_count <= max_lines then
    return 1, line_count
  end
  first = first or 1
  last = last or first
  return math.max(1, first - window), math.min(line_count, last + window)
end

function M.in_visual_mode()
  return vim.fn.mode():match '^[vV\22]' ~= nil
end

-- Returns { first, last, text } for the current visual selection and leaves visual mode.
-- text is only set for a selection within one line, so a single identifier can be explained.
function M.visual_target()
  local mode = vim.fn.mode()
  local first, last = vim.fn.line 'v', vim.fn.line '.'
  if first > last then
    first, last = last, first
  end
  local text
  if mode == 'v' and first == last then
    text = table.concat(vim.fn.getregion(vim.fn.getpos 'v', vim.fn.getpos '.', { type = 'v' }), '\n')
  end
  vim.api.nvim_feedkeys(vim.keycode '<Esc>', 'nx', false)
  return { first = first, last = last, text = text }
end

-- Node type names differ per language (function_definition in C and Python, function_item in Rust,
-- method_definition in JavaScript), so this matches on the name instead of listing every grammar.
-- Uses of a function are excluded, like function_call in Lua or method_invocation in Java.
function M.is_function_node(type)
  return (type:match 'function' or type:match 'method') ~= nil
    and not (type:match 'call' or type:match 'invocation' or type:match 'reference' or type:match 'declarator' or type:match 'parameter')
end

-- Line range of the innermost function around the cursor, or nil
function M.enclosing_function()
  local ok, parser = pcall(vim.treesitter.get_parser)
  if not ok or not parser then
    return nil
  end
  -- The tree may not be parsed yet, for example right after opening a file
  parser:parse()
  local node = vim.treesitter.get_node()
  while node do
    if M.is_function_node(node:type()) then
      local first, _, last, end_col = node:range()
      -- Some grammars end the node at column 0 of the line after it
      if end_col == 0 and last > first then
        last = last - 1
      end
      return { first = first + 1, last = last + 1 }
    end
    node = node:parent()
  end
end

return M
