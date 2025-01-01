return {
	{
		"stevearc/conform.nvim",
		-- enable = false,
		opts = {},
		config = function()
			local conform = require("conform")
			conform.setup({
				formatters_by_ft = {
					lua = { "stylua" },
					-- Conform will run multiple formatters sequentially
					-- python = { "isort", "black" },
					-- You can customize some of the format options for the filetype (:help conform.format)
					-- rust = { "rustfmt", lsp_format = "fallback" },
					-- Conform will run the first available formatter
					-- javascript = { "prettierd", "prettier", stop_after_first = true },
					-- typescript = { "prettierd", "prettier", stop_after_first = true },
					markdown = { "markdownlint" },
				},
			})

			vim.keymap.set("n", "<space>v", function()
				conform.format({
					lsp_fallback = true,
					async = false,
					timeout_ms = 1000,
				})
			end)
			vim.keymap.set("n", "<space>m", function()
				conform.format({
					lsp_fallback = true,
					async = false,
					timeout_ms = 1000,
				})

				require("lint").try_lint()

				vim.cmd("w")
			end)
		end,
	},
}
