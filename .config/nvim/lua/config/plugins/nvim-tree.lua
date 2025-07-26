return {
	"nvim-tree/nvim-tree.lua",
	opts = {},

	config = function()
		require("nvim-tree").setup({
			sort = {
				sorter = "case_sensitive",
			},
			view = {
				width = 30,
			},
			renderer = {
				group_empty = true,
			},
			filters = {
				dotfiles = false,
			},
		})

		vim.keymap.set("n", "<space>ne", ":NvimTreeToggle<CR>")
	end,
}
