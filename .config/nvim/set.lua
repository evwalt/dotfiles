-- Set
--

-- EditorConfig
--
vim.g.editorconfig = true

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

-- Yank Highlighting
-- Try it with `yap` in normal mode
-- See `:help vim.highlight.on_yank()`
vim.api.nvim_create_autocmd("TextYankPost", {
    desc = "Highlight when yanking (copying) text",
    group = vim.api.nvim_create_augroup("kickstart-highlight-yank", { clear = true }),
    callback = function()
        vim.highlight.on_yank()
    end,
})

-- Search Highlighting
--
require('set-search-highlighting')

-- Clipboard
--
vim.opt.clipboard = 'unnamedplus'
