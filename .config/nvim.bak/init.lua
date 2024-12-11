require("plugins")

vim.scriptencoding = "utf-8"

-- Options
vim.opt.encoding = "utf-8"
vim.opt.fileencoding = "utf-8"

vim.opt.updatetime = 50

-- Appearance
-- vim.opt.cursorcolumn = true
vim.opt.cmdheight = 2
vim.opt.relativenumber = true
vim.opt.number = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
-- vim.opt.expandtab = true
vim.opt.breakindent = true
-- vim.opt.autoindent = true
-- vim.opt.smartindent = true
vim.opt.wrap = true
-- vim.opt.scrolloff = 8

-- Colors
vim.opt.termguicolors = true
-- vim.opt.colorcolumn = "80"
vim.cmd("colorscheme rose-pine")
-- vim.api.nvim_set_hl(0, "Normal", { bg = "#000000" })

-- Words
vim.opt.spell = true
-- vim.opt.isfname:append('@-@')
-- vim.cmd("Copilot disable")

-- Backup
vim.opt.backspace = "indent,eol,start"
vim.opt.clipboard:append("unnamedplus")
-- vim.opt.swapfile = false
-- vim.opt.backup = false
-- vim.opt.undodir = os.getenv('HOME') .. 'SOME PATH'

-- Searching
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = false
vim.opt.incsearch = true

-- Remaps
vim.g.mapleader = " "

-- Left Hand
vim.keymap.set("n", "<leader>pc", vim.cmd.PackerSync)

vim.keymap.set("n", "<leader>i", function()
	vim.cmd([[
		Copilot enable
		Copilot status
	]])
end)

vim.keymap.set("n", "<leader>e", vim.cmd.Ex)
vim.keymap.set("n", "<leader>q", vim.cmd.q)
vim.keymap.set("n", "<leader>x", vim.cmd.x)

-- Right Hand
vim.keymap.set("n", "<leader>g", vim.cmd.term)

vim.keymap.set("n", "<leader>d", function()
	vim.cmd([[
		Copilot disable
		Copilot status
	]])
end)

vim.keymap.set("n", "<leader>h", function()
	vim.cmd([[
		Neoformat
		TailwindSort
		w
	]])
end)

vim.keymap.set("n", "<leader>t", vim.cmd.Ex)

vim.keymap.set("n", "<leader>n", function()
	vim.cmd("Neoformat")
	vim.cmd("TailwindSort")
end)

vim.keymap.set("n", "<leader>so", vim.cmd.so)

vim.keymap.set("n", "<leader>m", "<cmd>set invspell<cr>")

vim.keymap.set("n", "<leader>w", vim.cmd.w)

vim.keymap.set("n", "<leader>z", function()
	if vim.wo.wrap then
		vim.wo.wrap = false
	else
		vim.wo.wrap = true
	end
end)
