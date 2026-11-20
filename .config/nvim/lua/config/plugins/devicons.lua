-- File icons: recolor the default Lua blue (#51a0cf) to Harbor Night steel
return {
	"nvim-tree/nvim-web-devicons",
	opts = {
		override_by_extension = {
			lua = { icon = "\u{e620}", color = "#7fa9d1", name = "Lua" },
		},
	},
}
