return {
	"akinsho/bufferline.nvim",
	version = "*",
	dependencies = "nvim-tree/nvim-web-devicons",

	config = function()
		local bufferline = require("bufferline")
		bufferline.setup({
			options = {
				numbers = "ordinal",
			},
		})

		vim.keymap.set("n", "<space>j", ":BufferLineCyclePrev<CR>")
		vim.keymap.set("n", "<space>k", ":BufferLineCycleNext<CR>")
		-- vim.keymap.set("n", "<<", ":BufferLineMovePrev<CR>")
		vim.keymap.set("n", "<space><space>j", ":BufferLineMovePrev<CR>")
		-- vim.keymap.set("n", ">>", ":BufferLineMoveNext<CR>")
		vim.keymap.set("n", "<space><space>k", ":BufferLineMoveNext<CR>")
		vim.keymap.set("n", "<space><space>1", ":lua require'bufferline'.move_to(1)<CR>")
		vim.keymap.set("n", "<space><space>2", ":lua require'bufferline'.move_to(2)<CR>")
		vim.keymap.set("n", "<space><space>3", ":lua require'bufferline'.move_to(3)<CR>")
		vim.keymap.set("n", "<space><space>4", ":lua require'bufferline'.move_to(4)<CR>")
		vim.keymap.set("n", "<space><space>5", ":lua require'bufferline'.move_to(5)<CR>")
		vim.keymap.set("n", "<space><space>6", ":lua require'bufferline'.move_to(6)<CR>")
		vim.keymap.set("n", "<space><space>7", ":lua require'bufferline'.move_to(7)<CR>")
		vim.keymap.set("n", "<space><space>8", ":lua require'bufferline'.move_to(8)<CR>")
		vim.keymap.set("n", "<space><space>9", ":lua require'bufferline'.move_to(9)<CR>")
		vim.keymap.set("n", "<space><space>-1", ":lua require'bufferline'.move_to(-1)<CR>")
		-- vim.keymap.set("n", "<space><space>m0", function()
		-- 	bufferline.move_to(1)
		-- end)
		-- vim.keymap.set("n", "<space><space>m$", function()
		-- 	bufferline.move_to(-1)
		-- end)
		vim.keymap.set("n", "<space>''", ":lua require'bufferline'.go_to(1, true)<CR>")
		vim.keymap.set("n", "<space>,,", ":lua require'bufferline'.go_to(2, true)<CR>")
		vim.keymap.set("n", "<space>..", ":lua require'bufferline'.go_to(3, true)<CR>")
		vim.keymap.set("n", "<space>pp", ":lua require'bufferline'.go_to(4, true)<CR>")
		vim.keymap.set("n", "<space>yy", ":lua require'bufferline'.go_to(5, true)<CR>") -- Refrain from using <space>ff to avoid conflict with with find files.
		vim.keymap.set("n", "<space>yff", ":lua require'bufferline'.go_to(6, true)<CR>")
		vim.keymap.set("n", "<space>gg", ":lua require'bufferline'.go_to(7, true)<CR>")
		vim.keymap.set("n", "<space>cc", ":lua require'bufferline'.go_to(8, true)<CR>")
		vim.keymap.set("n", "<space>rr", ":lua require'bufferline'.go_to(9, true)<CR>")
		vim.keymap.set("n", "<space>ll", ":lua require'bufferline'.go_to(-1, true)<CR>")
	end,
}
