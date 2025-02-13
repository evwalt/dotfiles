local HOME = os.getenv("HOME")
return {
	"stevearc/conform.nvim",
	opts = {},
	config = function()
		local conform = require("conform")
		conform.setup({
			formatters_by_ft = {
				lua = { "stylua" },
				javascript = { "prettier" },
				typescript = { "prettier" },
				javascriptreact = { "prettier" },
				typescriptreact = { "prettier" },
				json = { "prettier", "prettier" },
				markdown = { "markdownlint-cli2" },
			},
			formatters = {
				["markdownlint-cli2"] = {
					command = "markdownlint-cli2",
					prepend_args = { "--fix", "--config", HOME .. "/.markdownlint.json" },
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
