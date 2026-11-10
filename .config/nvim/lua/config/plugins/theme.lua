-- Change this to switch themes; open nvim instances pick it up on restart.
-- Options: tokyonight-{storm,night,moon,day}, catppuccin-{mocha,macchiato,frappe,latte},
-- rose-pine-{main,moon,dawn}
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
			-- Apply the chosen theme (any of the three) here, since this plugin loads first.
			-- pcall: fall back to tokyonight-night if the name above is mistyped
			if not pcall(vim.cmd.colorscheme, colorscheme) then
				vim.cmd.colorscheme("tokyonight-night")
			end
		end,
	},
	{
		"catppuccin/nvim",
		name = "catppuccin",
		lazy = true, -- loads when the colorscheme above is set to it, so no priority needed
		opts = {
			-- Line numbers to match the tuned tokyonight (contrast 1.8 -> 3.4).
			-- Comments are already bright enough (5.8), so they're left alone.
			custom_highlights = function(c)
				return { LineNr = { fg = c.overlay0 } }
			end,
		},
	},
	{ "rose-pine/neovim", name = "rose-pine", lazy = true },
}
