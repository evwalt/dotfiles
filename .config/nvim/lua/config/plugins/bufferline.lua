return {
	"akinsho/bufferline.nvim",
	version = "*",
	dependencies = "nvim-tree/nvim-web-devicons",

	config = function()
		local bufferline = require("bufferline")
		bufferline.setup({})

		vim.keymap.set("n", "<space>j", ":BufferLineCyclePrev<CR>")
		vim.keymap.set("n", "<space>k", ":BufferLineCycleNext<CR>")
		vim.keymap.set("n", "<<", ":BufferLineMovePrev<CR>")
		vim.keymap.set("n", ">>", ":BufferLineMoveNext<CR>")
		-- vim.keymap.set("n", "<space><space>m0", function()
		-- 	bufferline.move_to(1)
		-- end)
		-- vim.keymap.set("n", "<space><space>m$", function()
		-- 	bufferline.move_to(-1)
		-- end)
		vim.keymap.set("n", "<space>pp", ":BufferLineGoToBuffer 1<CR>")
		vim.keymap.set("n", "<space>gg", ":BufferLineGoToBuffer 1<CR>")
		vim.keymap.set("n", "<space>..", ":BufferLineGoToBuffer 2<CR>")
		vim.keymap.set("n", "<space>cc", ":BufferLineGoToBuffer 2<CR>")
		vim.keymap.set("n", "<space>,,", ":BufferLineGoToBuffer 3<CR>")
		vim.keymap.set("n", "<space>rr", ":BufferLineGoToBuffer 3<CR>")
		vim.keymap.set("n", "<space>''", ":BufferLineGoToBuffer 4<CR>")
		vim.keymap.set("n", "<space>ll", ":BufferLineGoToBuffer 4<CR>")
		vim.keymap.set("n", "<space>yy", ":BufferLineGoToBuffer 5<CR>") -- Refrain from using <space>ff to avoid conflict with with find files.
	end,
}
