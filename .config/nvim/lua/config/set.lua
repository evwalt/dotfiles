-- Set
--

-- EditorConfig
--
vim.g.editorconfig = true

-- Line Numbers
--
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.cursorline = true

-- Tabs
--
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.smartindent = true

-- Newline
--
-- Automatically add a newline at the end of the file on save
-- vim.api.nvim_create_autocmd("BufWritePre", {
--     pattern = "*",
--     callback = function()
--         local last_line = vim.api.nvim_buf_get_lines(0, -2, -1, false)[1]
--         if last_line ~= "" then
--             vim.api.nvim_buf_set_lines(0, -1, -1, false, { "" })
--         end
--     end,
--     desc = "Ensure newline at end of files",
-- })

-- Text Width (Print Width)
--
vim.opt.textwidth = 80

-- Cases
--
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Yank Highlighting
-- Try it with `yap` in normal mode
-- See `:help vim.highlight.on_yank()`
vim.api.nvim_create_autocmd("TextYankPost", {
	desc = "Highlight when yanking (copying) text",
	group = vim.api.nvim_create_augroup("kickstart-highlight-yank", { clear = true }),
	callback = function()
		vim.highlight.on_yank()
	end,
})

-- Search Highlighting
--
require("config.set-search-highlighting")

-- Terminal GUI Colors
--
vim.opt.termguicolors = true

-- Clipboard
--
vim.opt.clipboard = "unnamedplus"

-- Spell
--
vim.opt.spell = true
vim.opt.spelllang = "en_us"

-- Sessions
--
vim.o.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions" -- from `:checkhealth` warning
