local HOME = os.getenv("HOME")
return {
	"stevearc/conform.nvim",
	-- enabled = false,
	opts = {},

	config = function()
		local conform = require("conform")
		conform.setup({
			formatters_by_ft = {
				css = { "prettier" },
				lua = { "stylua" },
				javascript = { "prettier" },
				javascriptreact = { "prettier" },
				json = { "prettier" },
				html = { "prettier" },
				markdown = { "markdownlint-cli2" },
				python = { "black" },
				-- toml = { "taplo" },
				typescript = { "prettier" },
				typescriptreact = { "prettier" },
			},
			formatters = {
				black = {
					command = "black",
				},
				["markdownlint-cli2"] = {
					command = "markdownlint-cli2",
					-- prepend_args = { "--fix", "--config", HOME .. "/.markdownlint.json", "$FILENAME" },
					prepend_args = { "--debug", "--fix", "--config", HOME .. "/.markdownlint.json", "%" },
				},
				prettier = {
					command = "prettier",
					args = {
						"--config",
						HOME .. "/.config/prettier/.prettierrc.yaml",
						"--stdin-filepath",
						"$FILENAME",
					},
					stdin = true,
				},
				-- ["taplo"] = {
				-- 	command = "taplo",
				-- 	prepend_args = { "fmt", "--option", "align_entries=true", "$FILENAME" },
				-- },
			},
		})

		-- Helper Fuctions
		--
		local function shell_escape(path)
			return path:gsub(" ", "\\ "):gsub("%(", "\\("):gsub("%)", "\\)")
		end
		local function handle_view_and_format()
			local view = vim.fn.winsaveview()
			local filepath = vim.fn.expand("%:p")
			local safe_filepath = shell_escape(filepath)
			conform.format({
				lsp_fallback = true,
				async = false,
				timeout_ms = 5000,
				bufnr = vim.fn.bufnr(), -- Ensure correct buffer formatting
				args = { safe_filepath },
			})
			vim.cmd("checktime")
			vim.fn.winrestview(view)
		end

		-- Keymaps
		--
		vim.keymap.set("n", "<space>v", function()
			-- conform.format({
			-- 	lsp_fallback = true,
			-- 	async = false,
			-- 	timeout_ms = 1000,
			-- })
			handle_view_and_format()
		end)

		vim.keymap.set("n", "<space>m", function()
			handle_view_and_format()
			vim.cmd("w")
		end)
	end,
}
