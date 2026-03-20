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
	opts = {
		top_down = false,
		max_width = 50,
		minimum_width = 20,
		max_height = 8,
		render = "compact",
		stages = "static",
		timeout = 3000, -- ms (default: ~5000)
	},
}
