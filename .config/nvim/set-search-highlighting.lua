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
    end, 3000) -- Timeout in milliseconds (e.g., 2000ms = 2 seconds)
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
