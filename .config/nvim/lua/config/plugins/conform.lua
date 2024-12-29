return {
    {
        'stevearc/conform.nvim',
        enable = false,
        opts = {},
        --         config = function()
        --             require("conform").setup({
        --                 formatters_by_ft = {
        --                     lua = { "stylua" },
        --                     -- Conform will run multiple formatters sequentially
        --                     -- python = { "isort", "black" },
        --                     -- You can customize some of the format options for the filetype (:help conform.format)
        --                     -- rust = { "rustfmt", lsp_format = "fallback" },
        --                     -- Conform will run the first available formatter
        --                     javascript = { "prettierd", "prettier", stop_after_first = true },
        --                     typescript = { "prettierd", "prettier", stop_after_first = true },
        --                     markdown = { 'markdownlint' },
        --                     vim.keymap.set('n', '<space>v', function() conform.format() end)
        --                     vim.keymap.set('n', '<space>m', function()
        --                         conform.format()
        --                         vim.cmd('w')
        --                     end, { desc = 'Save and format file' })
        --
        --                 },
        --             })
        --         end
    }
}
