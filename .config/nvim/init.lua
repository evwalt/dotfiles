-- `init.lua`
--

-- Notes
-- Many settings come from [Advent of Neovim](https://www.youtube.com/playlist?list=PLep05UYkc6wTyBe7kPjQFWVXTlhKeQejM). Some settings were created as I was going through it.
-- `:Inspect` command temporary workaround (see <https://github.com/neovim/neovim/issues/31675#issuecomment-2558405042>)
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

-- Search Highlighting
--
-- Create an augroup
local group = vim.api.nvim_create_augroup("vimrc_incsearch_highlight", { clear = true })
-- Highlight search when entering search mode
vim.api.nvim_create_autocmd("CmdlineEnter", {
    pattern = { "/", "?" },
    command = "set hlsearch",
    group = group,
    desc = "Enable search highlighting on entering search mode",
})
-- Disable highlight search when leaving search mode
vim.api.nvim_create_autocmd("CmdlineLeave", {
    pattern = { "/", "?" },
    command = "set nohlsearch",
    group = group,
    desc = "Disable search highlighting on leaving search mode",
})
-- Function to temporarily enable hlsearch with timeout
local function temporary_hlsearch()
    vim.opt.hlsearch = true
    -- Set a timeout to clear the highlight
    vim.defer_fn(function()
        vim.opt.hlsearch = false
    end, 2000) -- Timeout in milliseconds (e.g., 2000ms = 2 seconds)
end
-- Set up keybindings for * and #
vim.keymap.set('n', '*', function()
    vim.cmd("normal! *") -- Perform the default * action
    temporary_hlsearch()
end, { desc = "Search word under cursor and highlight temporarily" })
vim.keymap.set('n', '#', function()
    vim.cmd("normal! #") -- Perform the default # action
    temporary_hlsearch()
end, { desc = "Search word under cursor (reverse) and highlight temporarily" })

-- Clipboard
--
vim.opt.clipboard = 'unnamedplus'

-- Keymaps - Generic
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
vim.keymap.set('n', '<space>hc', ':set cursorcolumn!<CR>')
vim.keymap.set('n', '<space>hc', ':set cursorcolumn!<CR>')
vim.keymap.set('n', '<space>u.', ':set cursorcolumn!<CR>')
vim.keymap.set('n', '<space>so', ':source %<CR>')

-- Keymaps - LSP Default Settings in Neovim Nightly Build
--
vim.keymap.set('n', 'grn', vim.lsp.buf.rename)
vim.keymap.set('n', 'gra', vim.lsp.buf.code_action)
vim.keymap.set('n', 'grr', vim.lsp.buf.references)
vim.keymap.set('n', 'gri', vim.lsp.buf.implementation)
vim.keymap.set('n', 'gO', vim.lsp.buf.document_symbol)
vim.keymap.set('n', '<C-s>', vim.lsp.buf.signature_help)

-- Plugin Management
--
require('config.lazy')

