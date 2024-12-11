-- Leader Key
--
-- See lazy.nvim configuration for this setting.
-- vim.g.mapleader = ' '
-- vim.g.maplocalleader = ' '

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

