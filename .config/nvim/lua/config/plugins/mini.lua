return {
    {
        'echasnovski/mini.nvim',
        -- enabled = false,
        version = false,
        config = function()
            require('mini.statusline').setup({
                use_icons = true
            })
            require('mini.comment').setup({
                -- mappings = {
                --     comment_line = 'gcc',
                --     comment_line = '<space>gc',
                --     comment_line = '<space>p.',
                -- },
            })
            require('mini.cursorword').setup({})
        end
    },
}
