-- return {
-- 	"rcarriga/nvim-notify",
-- 	-- enabled = false,
-- 	opts = {
-- 		top_down = false,
-- 	},
-- }

return {
	"rcarriga/nvim-notify",
	-- enabled = false,
	event = "VeryLazy",
	opts = {
		top_down = false,
		-- Grow with the window; longer messages wrap instead of being cut off
		max_width = function()
			return math.floor(vim.o.columns * 0.6)
		end,
		minimum_width = 20,
		max_height = 8,
		render = "wrapped-compact",
		stages = "static",
		timeout = 3000, -- ms (default: ~5000)
	},
}
