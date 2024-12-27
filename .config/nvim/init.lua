-- `:Inspect` command temporary workaround
--
vim.hl = vim.highlight

-- Line Numbers
--
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.cursorline = true

-- Tabs
--
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.smartindent = true

-- Cases
--
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Clipboard
--
vim.opt.clipboard = 'unnamedplus'

-- Keymaps
--
vim.keymap.set('n', '<space>w', ':w<CR>')
vim.keymap.set('n', '<space>q', ':q<CR>')
vim.keymap.set('n', '<space>e', function()
    if vim.bo.filetype == 'netrw' then
        vim.cmd(':e #')
    else
        vim.cmd(':Ex')
    end
end, { desc = 'Toggle :Ex or return to previous file' })
vim.keymap.set('n', '<space>z', ':set wrap!<CR>')

-- Plugin Management
--
require('config.lazy')

