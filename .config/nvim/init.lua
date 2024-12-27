-- Line Numbers
--
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.cursorline = true

-- Tabs
--
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = false

-- Cases
--
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Clipboard
--
vim.opt.clipboard = 'unnamedplus'

-- Plugin Management
--
require('config.lazy')

-- Keymaps
--
vim.keymap.set('n', '<space>w', '<cmd>w<CR>')
vim.keymap.set('n', '<space>q', '<cmd>q<CR>')
vim.keymap.set('n', '<space>z', '<cmd>set wrap!<CR>')
