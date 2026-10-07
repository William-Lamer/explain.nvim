-- Minimal config used to record the demo GIF with `make demo`
local repo = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h')
vim.opt.runtimepath:prepend(repo)
vim.opt.runtimepath:prepend(repo .. '/deps/tokyonight.nvim')

vim.g.mapleader = ' '
vim.o.number = true
vim.o.wrap = false
vim.o.signcolumn = 'yes'
vim.o.laststatus = 3
vim.o.shortmess = vim.o.shortmess .. 'I'
vim.cmd.colorscheme 'tokyonight-night'

vim.diagnostic.config { virtual_text = true }
-- Only the tape that shows LSP diagnostics starts clangd, so the other demos stay unchanged
if vim.env.EXPLAIN_DEMO_LSP then
  vim.lsp.config('clangd', { cmd = { 'clangd' }, filetypes = { 'c' } })
  vim.lsp.enable 'clangd'
end

vim.api.nvim_create_autocmd('FileType', {
  callback = function()
    pcall(vim.treesitter.start)
  end,
})
