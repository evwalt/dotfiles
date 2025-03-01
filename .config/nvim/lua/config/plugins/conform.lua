local HOME = os.getenv("HOME")
return {
	"stevearc/conform.nvim",
	opts = {},

	config = function()
		local conform = require("conform")
		conform.setup({
			formatters_by_ft = {
				javascript = { "prettier" },
				javascriptreact = { "prettier" },
				json = { "prettier" },
				lua = { "stylua" },
				markdown = { "markdownlint-cli2" },
				python = { "black" },
				typescript = { "prettier" },
				typescriptreact = { "prettier" },
			},
			formatters = {
				black = {
					command = "black",
				},
				["markdownlint-cli2"] = {
					command = "markdownlint-cli2",
					prepend_args = { "--fix", "--config", HOME .. "/.markdownlint.json" },
				},
				prettier = {
					command = "prettier",
				},
			},
		})

		vim.keymap.set("n", "<space>v", function()
			conform.format({
				lsp_fallback = true,
				async = false,
				timeout_ms = 5000,
			})
		end)

		vim.keymap.set("n", "<space>m", function()
			conform.format({
				lsp_fallback = true,
				async = false,
				timeout_ms = 1000,
			})

			vim.cmd("w")
		end)
	end,
}
