return {
	"nvim-tree/nvim-tree.lua",
	opts = {},
	config = function()
		local nvim_tree = require("nvim-tree")
		nvim_tree.setup({
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
				dotfiles = true,
			},
		})

		vim.keymap.set("n", "<space>ne", ":NvimTreeToggle<CR>")
	end,
}
