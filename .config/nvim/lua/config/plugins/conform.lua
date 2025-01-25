local HOME = os.getenv("HOME")
return {
	"stevearc/conform.nvim",
	-- enable = false,
	opts = {},
	config = function()
		local conform = require("conform")
		conform.setup({
			formatters_by_ft = {
				lua = { "stylua" },
				json = { "prettierd", "prettier", stop_after_first = true },
				markdown = { "markdownlint-cli2" },
			},
			formatters = {
				-- json = {
				-- 	args = { "--config-path", HOME .. "/.config/prettier/.prettierrc.jsonc", "--" },
				-- 	stylua = {
				-- 		args = { "--config-path", HOME .. "/.config/stylua/stylua.toml", "--" },
				-- 	},
				markdown = {
					args = { "--config", HOME .. "/.config/markdownlint/.markdownlint.json", "--" },
				},
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
}
