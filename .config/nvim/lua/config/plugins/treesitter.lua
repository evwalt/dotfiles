return {
	"nvim-treesitter/nvim-treesitter",
	branch = "main",
	build = ":TSUpdate",
	-- `main` does not support lazy-loading
	lazy = false,

	config = function()
		-- No-op for parsers that are already installed; runs asynchronously
		require("nvim-treesitter").install({
			"c",
			"css",
			"html",
			"javascript",
			"json",
			"latex",
			"lua",
			"markdown",
			"markdown_inline",
			"prisma",
			"sql",
			"query",
			"vim",
			"vimdoc",
			"svelte",
			"toml",
			"tsx",
			"typescript",
		})

		-- `main` enables nothing by itself, so start highlighting per filetype.
		-- Neovim's own ftplugins (lua, markdown, help, query) already start it, so
		-- large files must be stopped as well as skipped.
		vim.api.nvim_create_autocmd("FileType", {
			group = vim.api.nvim_create_augroup("treesitter_highlight", { clear = true }),
			callback = function(args)
				local max_filesize = 100 * 1024 -- 100 KB
				local ok, stats = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(args.buf))
				if ok and stats and stats.size > max_filesize then
					pcall(vim.treesitter.stop, args.buf)
					return
				end
				if not vim.treesitter.highlighter.active[args.buf] then
					-- Errors when no parser is installed for this filetype
					pcall(vim.treesitter.start, args.buf)
				end
				-- Replaces legacy `additional_vim_regex_highlighting = true`:
				-- starting Tree-sitter clears 'syntax', so turn it back on
				if vim.treesitter.highlighter.active[args.buf] then
					vim.bo[args.buf].syntax = "ON"
				end
			end,
		})
	end,
}
