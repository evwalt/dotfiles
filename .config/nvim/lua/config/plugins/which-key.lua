return {
	"folke/which-key.nvim",
	event = "VeryLazy",
	opts = {
		preset = "classic",
		-- Longer wait in visual mode, where the popup otherwise appears as soon as `v` is pressed.
		delay = function(ctx)
			if ctx.mode == "x" or ctx.mode == "v" then
				return 1000
			end
			return 500
		end,
		spec = {
			{ "<space>u", group = "window" },
			{ "<space>h", group = "window" },
			{ "<space>g", group = "comment" },
			{ "<space>p", group = "comment" },
			{ "<space><space>", group = "notes, toggles, extras" },
		},
	},
}
