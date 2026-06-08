return {
	"lukas-reineke/indent-blankline.nvim",
	main = "ibl",
	config = function()
		local hooks = require("ibl.hooks")

		hooks.register(hooks.type.HIGHLIGHT_SETUP, function()
			-- Minimal Tokyonight Storm-friendly guide colors
			vim.api.nvim_set_hl(0, "IblIndent", { fg = "#2f334d" })
			vim.api.nvim_set_hl(0, "IblScope", { fg = "#565f89" })
		end)

		require("ibl").setup({
			indent = {
				highlight = "IblIndent",
				char = "▏",
			},
			scope = {
				enabled = true,
				highlight = "IblScope",
				char = "▏",
				show_start = false,
				show_end = false,
			},
		})
	end,
}
