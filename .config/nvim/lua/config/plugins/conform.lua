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
				javascriptreact = { "prettier" },
				json = { "prettier" },
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
				},
				-- ["taplo"] = {
				-- 	command = "taplo",
				-- 	prepend_args = { "fmt", "--option", "align_entries=true", "$FILENAME" },
				-- },
			},
		})

		-- -- Helper Fuctions
		-- --
		-- local function parens_escape(path)
		-- 	return path:gsub("%(", "\\("):gsub("%)", "\\)")
		-- end
		local function handle_view_and_format()
			local view = vim.fn.winsaveview()

			conform.format({
				lsp_fallback = true,
				async = false,
				timeout_ms = 5000,
			})
			vim.cmd("checktime")
			vim.fn.winrestview(view)
		end
		-- local function format_markdown()
		-- 	local filepath = vim.fn.expand("%:p")
		-- 	local safe_filepath = parens_escape(filepath)
		-- 	local config_path = HOME .. "/.markdownlint.json"
		-- 	local cmd = string.format(
		-- 		"markdownlint-cli2 --fix --config %s %s",
		-- 		vim.fn.shellescape(config_path),
		-- 		vim.fn.shellescape(safe_filepath)
		-- 	)
		-- 	local output = vim.fn.system(cmd)
		-- 	local print_message = "Command:\n" .. cmd .. "\nOutput:\n" .. output
		-- 	handle_view()
		-- 	if vim.v.shell_error ~= 0 then
		-- 		print("Error running markdownlint-cli2:\n" .. print_message)
		-- 	else
		-- 		print("markdownlint-cli2 completed successfully!\n" .. print_message)
		-- 	end
		-- end
		-- local format = function()
		-- 	if vim.bo.filetype == "markdown" then
		-- 		format_markdown()
		-- 	elseif vim.bo.filetype == "toml" then
		-- 		conform.format({
		-- 			lsp_fallback = true,
		-- 			async = false,
		-- 			timeout_ms = 1000,
		-- 		})
		-- 		handle_view()
		-- 	else
		-- 		conform.format({
		-- 			lsp_fallback = true,
		-- 			async = false,
		-- 			timeout_ms = 1000,
		-- 		})
		-- 	end
		-- end

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
