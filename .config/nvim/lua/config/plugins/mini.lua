return {
    {
        'echasnovski/mini.nvim',
        -- enabled = false,
        version = false,
        config = function()
            require('mini.statusline').setup({
                use_icons = true
            })
            require('mini.comment').setup()
            vim.keymap.set('n', '<space>gc', ':lua MiniComment<CR>')
            vim.keymap.set('n', '<space>p.', ':lua MiniComment<CR>')
        end
    },
}
