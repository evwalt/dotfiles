return {
	"stevearc/oil.nvim",
	---@module 'oil'
	---@type oil.SetupOpts
	-- dependencies = { { "echasnovski/mini.icons", opts = {} } },
	dependencies = { "nvim-tree/nvim-web-devicons" }, -- use if prefer nvim-web-devicons
	opts = {},
	config = function()
		require("oil").setup({
			view_options = {
				show_hidden = true,
				is_always_hidden = function(name, _)
					return name == ".."
				end,
			},
		})
		vim.keymap.set("n", "<space>e", function()
			if vim.bo.filetype == "oil" then
				vim.cmd(":e #")
			else
				vim.cmd(":Oil")
			end
		end)
		vim.keymap.set("n", "-", ":Oil<CR>")
		vim.keymap.set("n", "<esc>", function()
			if vim.bo.filetype == "oil" then
				vim.cmd(":e #")
			end
		end)
	end,
}
