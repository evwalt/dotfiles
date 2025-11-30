return {
	"nvim-mini/mini.nvim",
	-- enabled = false,
	version = false,

	config = function()
		local cursorword = require("mini.cursorword")
		local animate = require("mini.animate")

		cursorword.setup({})

		animate.setup({
			scroll = {
				timing = animate.gen_timing.linear({ duration = 50, unit = "total" }),
			},
		})
		require("mini.pairs").setup({})

		-- local hipatterns = require("mini.hipatterns")
		-- hipatterns.setup({
		-- 	highlighters = {
		-- 		-- Highlight standalone 'FIXME', 'HACK', 'TODO', 'NOTE'
		-- 		fixme = { pattern = "%f[%w]()FIXME()%f[%W]", group = "MiniHipatternsFixme" },
		-- 		hack = { pattern = "%f[%w]()HACK()%f[%W]", group = "MiniHipatternsHack" },
		-- 		todo = { pattern = "%f[%w]()TODO()%f[%W]", group = "MiniHipatternsTodo" },
		-- 		note = { pattern = "%f[%w]()NOTE()%f[%W]", group = "MiniHipatternsNote" },
		--
		-- 		-- Highlight hex color strings (`#rrggbb`) using that color
		-- 		hex_color = hipatterns.gen_highlighter.hex_color(),
		-- 	},
		-- })
	end,
}
