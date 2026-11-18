return {
	"lukas-reineke/indent-blankline.nvim",
	main = "ibl",
	event = { "BufReadPost", "BufNewFile" },
	config = function()
		local hooks = require("ibl.hooks")

		hooks.register(hooks.type.HIGHLIGHT_SETUP, function()
			-- Minimal Tokyonight-friendly guide colors; other themes use their own subtle groups.
			-- ibl reruns this hook on every colorscheme change.
			if (vim.g.colors_name or ""):find("^tokyonight") then
				vim.api.nvim_set_hl(0, "IblIndent", { fg = "#1f2033" })
				vim.api.nvim_set_hl(0, "IblScope", { fg = "#4a4c70" })
			else
				vim.api.nvim_set_hl(0, "IblIndent", { link = "Whitespace" })
				vim.api.nvim_set_hl(0, "IblScope", { link = "Comment" })
			end
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
