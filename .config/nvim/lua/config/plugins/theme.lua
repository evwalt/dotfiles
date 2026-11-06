return {
	"folke/tokyonight.nvim",
	lazy = false,
	-- enabled = false,

	config = function()
		require("tokyonight").setup({
			-- Slightly brighter than the defaults (contrast vs Storm bg: comments 2.4 -> 3.3, line numbers 1.5 -> 2.4)
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
		vim.cmd.colorscheme("tokyonight-storm")
	end,
}
