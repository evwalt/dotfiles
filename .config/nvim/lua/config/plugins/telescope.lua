return {
	"nvim-telescope/telescope.nvim",
	tag = "0.1.8",
	-- or '...' , branch = '0.1.x',
	dependencies = {
		"nvim-lua/plenary.nvim",
		{ "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
	},
	config = function()
		local telescope = require("telescope")

		telescope.setup({
			extensions = {
				fzf = {},
			},

			defaults = require("telescope.themes").get_ivy({}),
		})

		telescope.load_extension("fzf")

		local builtin = require("telescope.builtin")
		-- local find_files = function()
		-- 	builtin.find_files({ search_dirs = { vim.fn.fnamemodify(vim.fn.getcwd(), ":h") } })
		-- end
		local find_files = builtin.find_files
		local help_tags = builtin.help_tags

		vim.keymap.set("n", "<space><space>", find_files)
		vim.keymap.set("n", "<space><space><space>", find_files)
		vim.keymap.set("n", "<space>fh", help_tags)

		require("config.telescope.multigrep").setup()
	end,
}
