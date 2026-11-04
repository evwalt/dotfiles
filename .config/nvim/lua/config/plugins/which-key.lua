return {
	"folke/which-key.nvim",
	event = "VeryLazy",
	opts = {
		preset = "classic",
		delay = 300,
		spec = {
			{ "<space>t", group = "terminal" },
			{ "<space>u", group = "window" },
			{ "<space>h", group = "window" },
			{ "<space>g", group = "comment" },
			{ "<space>p", group = "comment" },
			{ "<space><space>", group = "notes, toggles, extras" },
		},
	},
}
