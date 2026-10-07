local config = require 'explain.config'

local M = {}

-- Lite modes depend on these Claude Code flags, so an older or newer CLI without them breaks quietly
local REQUIRED_FLAGS = { '--system-prompt', '--tools', '--setting-sources', '--effort', '--include-partial-messages', '--strict-mcp-config' }

function M.check()
  vim.health.start 'explain.nvim'

  if vim.fn.has 'nvim-0.11' == 1 then
    vim.health.ok('Neovim ' .. tostring(vim.version()))
  else
    vim.health.error('Neovim 0.11 or newer is required, found ' .. tostring(vim.version()))
  end

  local cmd = config.options.cmd
  if vim.fn.executable(cmd) == 0 then
    vim.health.error(string.format('`%s` was not found on the PATH', cmd), 'Install Claude Code, or set `cmd` in setup()')
    return
  end
  local version = vim.trim(vim.system({ cmd, '--version' }, { text = true }):wait().stdout or '')
  vim.health.ok(string.format('`%s` found: %s', cmd, version))

  local help = vim.system({ cmd, '--help' }, { text = true }):wait().stdout or ''
  local missing = vim.tbl_filter(function(flag)
    return not help:find(flag, 1, true)
  end, REQUIRED_FLAGS)
  if #missing == 0 then
    vim.health.ok 'All Claude Code flags used by explain.nvim are supported'
  else
    vim.health.warn('This Claude Code version does not list: ' .. table.concat(missing, ', '), 'Update Claude Code')
  end

  for name, mode in pairs(config.options.modes) do
    if not mode.model then
      vim.health.error(string.format("Mode '%s' needs a `model`", name))
    end
  end
end

return M
