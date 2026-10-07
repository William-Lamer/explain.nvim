if vim.g.loaded_explain then
  return
end
vim.g.loaded_explain = true

-- Subcommand to the function in require('explain') that it calls
local subcommands = {
  error = 'explain_error',
  code = 'explain_code',
  ['function'] = 'explain_function',
  chat = 'toggle_chat',
  last = 'reopen_last',
}

vim.api.nvim_create_user_command('Explain', function(opts)
  local name, mode = opts.fargs[1] or 'error', opts.fargs[2]
  if not subcommands[name] then
    vim.notify('explain.nvim: unknown subcommand ' .. name, vim.log.levels.ERROR)
    return
  end
  local target = opts.range > 0 and { first = opts.line1, last = opts.line2 } or nil
  require('explain')[subcommands[name]](mode, target)
end, {
  nargs = '*',
  range = true,
  desc = 'Explain errors and code with Claude: :[range]Explain [error|code|function|chat|last] [mode]',
  complete = function(arg_lead, cmdline)
    local words = vim.split(cmdline:gsub('^%S*%s*', ''), '%s+')
    local candidates = #words <= 1 and vim.tbl_keys(subcommands) or vim.tbl_keys(require('explain.config').options.modes)
    table.sort(candidates)
    return vim.tbl_filter(function(c)
      return vim.startswith(c, arg_lead)
    end, candidates)
  end,
})

-- Registered at startup so failed runs are remembered before the first explain call
local group = vim.api.nvim_create_augroup('explain-runs', { clear = true })
vim.api.nvim_create_autocmd('TermOpen', {
  group = group,
  callback = function(ev)
    require('explain.runs').on_term_open(ev)
  end,
})
vim.api.nvim_create_autocmd('TermClose', {
  group = group,
  callback = function(ev)
    require('explain.runs').on_term_close(ev)
  end,
})
