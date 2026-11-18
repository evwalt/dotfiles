return {
	"stevearc/oil.nvim",
	---@module 'oil'
	---@type oil.SetupOpts
	-- dependencies = { { "echasnovski/mini.icons", opts = {} } },
	dependencies = { "nvim-tree/nvim-web-devicons" }, -- use if prefer nvim-web-devicons
	opts = {},

	config = function()
		require("oil").setup({
			columns = {
				"permissions",
				"size",
				{ "mtime", format = "%Y-%m-%d %H:%M" },
				"icon",
			},
			view_options = {
				show_hidden = true,
				is_always_hidden = function(name, _)
					return name == ".."
				end,
			},
			keymaps = {
				["gq"] = { "actions.close", mode = "n" },
			},
		})

		vim.keymap.set("n", "-", ":Oil<CR>")
	end,
}
