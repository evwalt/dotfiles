return {
	"yuratomo/w3m.vim",
	event = "VeryLazy",
	config = function()
		vim.keymap.set("n", "<space><space>w", ":W3m")
	end,
}
