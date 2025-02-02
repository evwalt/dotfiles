local HOME = os.getenv("HOME")
return {
	"mfussenegger/nvim-lint",
	opts = {},

	config = function()
		local lint = require("lint")
		lint.linters_by_ft = {
			javascript = { "eslint_d" },
			typescript = { "eslint_d" },
			javascriptreact = { "eslint_d" },
			typescriptreact = { "eslint_d" },
			svelte = { "eslint_d" },
			markdown = { "markdownlint-cli2" },
		}

		local markdownlint_cli2 = lint.linters["markdownlint-cli2"]
		markdownlint_cli2.cmd = HOME .. "/.local/share/nvim/mason/bin/markdownlint-cli2"
		markdownlint_cli2.args = { "--config", HOME .. "/.markdownlint.json", "--" }

		local lint_augroup = vim.api.nvim_create_augroup("lint", { clear = true })
		vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost" }, {
			group = lint_augroup,
			callback = function()
				lint.try_lint()
			end,
		})

		vim.keymap.set("n", "<space>li", function()
			lint.try_lint()
		end, { desc = "Trigger linting for current file" })
	end,
}
