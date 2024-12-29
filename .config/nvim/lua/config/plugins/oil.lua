return {
    {
        'stevearc/oil.nvim',
        ---@module 'oil'
        ---@type oil.SetupOpts
        opts = {},
        -- Optional dependencies
        dependencies = { { "echasnovski/mini.icons", opts = {} } },
        -- dependencies = { "nvim-tree/nvim-web-devicons" }, -- use if prefer nvim-web-devicons
        config = function()
            vim.keymap.set('n', '<space>e', function()
                if vim.bo.filetype == 'oil' then
                    vim.cmd(':bdelete')
                else
                    vim.cmd(':Oil')
                end
            end)
        end
    }
}

