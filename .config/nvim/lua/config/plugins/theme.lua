-- Change this to switch themes; open nvim instances pick it up on restart.
-- Options: tokyonight-{storm,night,moon,day}
local colorscheme = "tokyonight-night"

return {
	{
		"folke/tokyonight.nvim",
		lazy = false,
		priority = 1000,

		config = function()
			require("tokyonight").setup({
				-- Slightly brighter than the defaults (contrast vs Storm bg: comments 2.4 -> 3.3, line numbers 1.5 -> 2.4; a bit higher on Night)
				on_colors = function(c)
					c.comment = "#6b75ad"
				end,
				on_highlights = function(hl)
					-- Set the groups directly: c.fg_gutter is also used for backgrounds (folds, popup selection)
					for _, group in ipairs({ "LineNr", "LineNrAbove", "LineNrBelow" }) do
						hl[group] = { fg = "#565f89" }
					end
				end,
			})
			-- Apply the chosen theme here, since this plugin loads first.
			-- pcall: fall back to tokyonight-night if the name above is mistyped
			if not pcall(vim.cmd.colorscheme, colorscheme) then
				vim.cmd.colorscheme("tokyonight-night")
			end
		end,
	},
}
