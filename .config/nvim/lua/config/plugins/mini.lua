return {
	"echasnovski/mini.nvim",
	-- enabled = false,
	version = false,

	config = function()
		require("mini.cursorword").setup({})
		require("mini.animate").setup({})
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
