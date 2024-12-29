return {
    {
        "stevearc/oil.nvim",
        ---@module 'oil'
        ---@type oil.SetupOpts
        -- dependencies = { { "echasnovski/mini.icons", opts = {} } },
        dependencies = { "nvim-tree/nvim-web-devicons" }, -- use if prefer nvim-web-devicons
        opts = {},
        config = function()
            require("oil").setup({
                view_options = { show_hidden = true },
            })
            vim.keymap.set('n', '<space>e', function()
                if vim.bo.filetype == 'oil' then
                    vim.cmd(':e #')
                else
                    vim.cmd(':Oil')
                end
            end)
        end,
    },
}
