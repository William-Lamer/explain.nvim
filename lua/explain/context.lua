-- Decides what to explain and builds the prompt for it. Every function returns a ctx table:
-- { title, prompt, focus = { buf, first, last } }, where focus is the code to highlight.

local config = require 'explain.config'
local runs = require 'explain.runs'
local util = require 'explain.util'

local M = {}

local function file_section(buf, mode, first, last)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local limits = mode.lite and config.options.lite or config.options.deep
  local from, to = util.file_window(#lines, first, last, limits.max_file_lines, limits.window)
  local numbered = {}
  for i = from, to do
    table.insert(numbered, string.format('%4d  %s', i, lines[i]))
  end
  local name = vim.api.nvim_buf_get_name(buf)
  local display = name == '' and '[unnamed buffer]' or (vim.fs.relpath(util.project_root(buf), name) or name)
  local scope = (from == 1 and to == #lines) and 'full file' or string.format('lines %d-%d of %d', from, to, #lines)
  local ft = vim.bo[buf].filetype
  return string.format('File %s (%s, may include unsaved changes):\n```%s\n%s\n```', display, scope, ft, table.concat(numbered, '\n'))
end

local function format_diagnostics(diags)
  local out = {}
  for _, d in ipairs(diags) do
    local source = d.source and (d.source .. ': ') or ''
    table.insert(out, string.format('- line %d, col %d [%s] %s%s', d.lnum + 1, d.col + 1, vim.diagnostic.severity[d.severity], source, d.message))
  end
  return table.concat(out, '\n')
end

-- The output, then the source file it belongs to, centered on the line the output mentions
local function output_prompt(header, output, source, mode)
  local prompt = string.format('%s\n```\n%s\n```', header, output)
  if not util.is_file_buffer(source) then
    return prompt
  end
  local line = util.line_mentioned_in(output, vim.api.nvim_buf_get_name(source))
  return prompt .. '\n\n' .. file_section(source, mode, line, line)
end

local function terminal_prompt(buf, output, mode)
  return output_prompt('Explain the errors in this output from `' .. util.terminal_command(buf) .. '`:', output, vim.b[buf].explain_source, mode)
end

-- Errors in a range of lines, or in a selected part of a terminal's output
local function range_context(buf, mode, target)
  local selected = table.concat(vim.api.nvim_buf_get_lines(buf, target.first - 1, target.last, false), '\n')
  if vim.bo[buf].buftype == 'terminal' then
    return {
      title = 'selected output',
      prompt = terminal_prompt(buf, selected, mode),
    }
  end
  local diags = vim.tbl_filter(function(d)
    return d.lnum + 1 >= target.first and d.lnum + 1 <= target.last
  end, vim.diagnostic.get(buf))
  local diag_text = #diags > 0 and ('Diagnostics in these lines:\n' .. format_diagnostics(diags) .. '\n\n') or ''
  return {
    title = string.format('bugs in lines %d-%d', target.first, target.last),
    focus = { buf = buf, first = target.first, last = target.last },
    prompt = string.format(
      'Find what is wrong with lines %d-%d, or say if they look correct.\n%s%s',
      target.first,
      target.last,
      diag_text,
      file_section(buf, mode, target.first, target.last)
    ),
  }
end

-- With a target, looks for bugs in those lines. Otherwise picks the most specific error available:
-- the terminal under the cursor, diagnostics on the cursor line, the last failed run in this
-- project, then warnings anywhere in the file. Returns nil when there is nothing to explain.
function M.error(mode, target)
  local buf = vim.api.nvim_get_current_buf()
  if target then
    return range_context(buf, mode, target)
  end

  if vim.bo[buf].buftype == 'terminal' then
    return {
      title = 'terminal output',
      prompt = terminal_prompt(buf, util.terminal_output(buf), mode),
    }
  end

  local line = vim.api.nvim_win_get_cursor(0)[1]
  local line_diags = vim.diagnostic.get(buf, { lnum = line - 1 })
  if #line_diags > 0 then
    return {
      title = 'error on line ' .. line,
      focus = { buf = buf, first = line, last = line },
      prompt = 'Explain these diagnostics on line ' .. line .. ':\n' .. format_diagnostics(line_diags) .. '\n\n' .. file_section(buf, mode, line, line),
    }
  end

  local run = runs.last_failed(util.project_root(buf))
  if run then
    return {
      title = 'last failed run',
      prompt = output_prompt(string.format('Explain the error from `%s`, which exited with status %d:', run.command, run.status), run.output, run.source, mode),
    }
  end

  local file_diags = vim.diagnostic.get(buf, { severity = { min = vim.diagnostic.severity.WARN } })
  if #file_diags > 0 then
    local first = file_diags[1].lnum + 1
    return {
      title = 'file diagnostics',
      prompt = 'Explain these diagnostics:\n' .. format_diagnostics(file_diags) .. '\n\n' .. file_section(buf, mode, first, first),
    }
  end
end

-- target is { first, last, text }; text narrows the question to an exact expression or identifier
function M.code(mode, target)
  local buf = vim.api.nvim_get_current_buf()
  local where = target.first == target.last and ('line ' .. target.first) or string.format('lines %d-%d', target.first, target.last)
  local subject = target.text and string.format('`%s` on %s', target.text, where) or where
  return {
    title = 'explain ' .. (target.text and ('`' .. target.text .. '`') or where),
    focus = { buf = buf, first = target.first, last = target.last },
    prompt = string.format(
      'Explain %s: what it does and how it works. Focus on that part; the rest of the file is context.\n\n%s',
      subject,
      file_section(buf, mode, target.first, target.last)
    ),
  }
end

return M
