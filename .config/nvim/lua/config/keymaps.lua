-- Keymaps
--

-- Generic
--
vim.keymap.set('n', '<space>w', ':w<CR>')
vim.keymap.set('n', '<space>v', function() vim.lsp.buf.format() end)
vim.keymap.set('n', '<space>m', function()
    vim.lsp.buf.format()
    vim.cmd('w')
end, { desc = 'Save and format file' })
vim.keymap.set('n', '<space>q', ':q<CR>')
vim.keymap.set('n', '<space>e', function()
    if vim.bo.filetype == 'netrw' then
        vim.cmd(':e #')
    else
        vim.cmd(':Ex')
    end
end, { desc = 'Toggle :Ex or return to previous file' })
vim.keymap.set('n', '<space>z', ':set wrap!<CR>')
vim.keymap.set('n', '<space>hc', ':set cursorcolumn!<CR>')
vim.keymap.set('n', '<space>hc', ':set cursorcolumn!<CR>')
vim.keymap.set('n', '<space>u.', ':set cursorcolumn!<CR>')
vim.keymap.set('n', '<space>so', ':source %<CR>')

-- Windows
--
vim.keymap.set('n', '<space>u', '<C-w>')
vim.keymap.set('n', '<space>h', '<C-w>')

-- Terminal
--
vim.keymap.set('n', '<space>j', function()
    vim.cmd.vnew()
    vim.cmd.term()
    vim.cmd.wincmd('J')
    vim.api.nvim_win_set_height(0, 15)
end)
vim.keymap.set('n', '<space>l', function()
    -- local current_height = vim.api.nvim_win_get_height(0)
    vim.cmd.vnew()
    vim.cmd.term()
    vim.cmd.wincmd('L')
    -- vim.api.nvim_win_set_height(0, current_height)
end)
vim.keymap.set('t', '<esc>', '<C-\\><C-n>')

-- LSP Default Keymaps in Neovim Nightly Build
--
vim.keymap.set('n', 'grn', vim.lsp.buf.rename)
vim.keymap.set('n', 'gra', vim.lsp.buf.code_action)
vim.keymap.set('n', 'grr', vim.lsp.buf.references)
vim.keymap.set('n', 'gri', vim.lsp.buf.implementation)
vim.keymap.set('n', 'gO', vim.lsp.buf.document_symbol)
vim.keymap.set('n', '<C-s>', vim.lsp.buf.signature_help)

