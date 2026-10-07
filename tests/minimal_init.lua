-- Loads the plugin and mini.test into a clean Neovim for `make test`
vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:append(vim.fn.getcwd() .. '/deps/mini.nvim')
vim.cmd 'runtime! plugin/explain.lua'
require('mini.test').setup()
