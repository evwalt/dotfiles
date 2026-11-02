--- Set ---

--- EditorConfig ---
-- vim.g.editorconfig = true

--- Line Numbers ---
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.cursorline = true

--- Tabs ---
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.smartindent = true

--- Text Width (Print Width) ---
vim.opt.textwidth = 2000

--- Cases ---
vim.opt.ignorecase = true
vim.opt.smartcase = true

--- Yank Highlighting ---
-- See `:help vim.highlight.on_yank()`
vim.api.nvim_create_autocmd("TextYankPost", {
	desc = "Highlight when yanking (copying) text",
	group = vim.api.nvim_create_augroup("kickstart-highlight-yank", { clear = true }),
	callback = function()
		vim.highlight.on_yank()
	end,
})

--- Search Highlighting ---
require("config.set-search-highlighting")

--- Terminal GUI Colors ---
vim.opt.termguicolors = true

--- Clipboard ---
vim.opt.clipboard = "unnamedplus"

--- Spell ---
vim.opt.spell = false
vim.opt.spelllang = "en_us"

--- Sessions ---
vim.o.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions,globals" -- from `:checkhealth` warning and auto-session docs

--- netrw ---
-- Disable netrw per nvim-tree docs
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

--- Language-specific Settings ---
-- vim.api.nvim_create_autocmd("FileType", {
--         pattern = { "javascript", "typescript", "javascriptreact", "typescriptreact" },
--         callback = function()
--                 vim.notify("Detected JS/TS/React file")
--                 vim.opt_local.tabstop = 2
--                 vim.opt_local.shiftwidth = 2
--                 vim.opt_local.expandtab = true
--         end,
-- })

--- Scroll Position ---
-- Save scroll position when leaving a buffer
vim.api.nvim_create_autocmd("BufLeave", {
	pattern = "*",
	callback = function()
		vim.b.view = vim.fn.winsaveview()
	end,
})
-- Restore scroll position when entering a buffer
vim.api.nvim_create_autocmd("BufEnter", {
	pattern = "*",
	callback = function()
		if vim.b.view then
			vim.fn.winrestview(vim.b.view)
		end
	end,
})

--- Virtual Text ---
vim.diagnostic.config({
	virtual_text = true,
	signs = true,
	underline = true,
	update_in_insert = false,
	severity_sort = true,
})

--- Unsaved-changes indicator ---
-- The statusline and bufferline are hidden by default, so turn the line numbers red
-- while a buffer has unsaved changes. (Tokyonight's current-line number is already orange,
-- and relativenumber uses LineNrAbove/LineNrBelow, so all four groups are remapped.)
local function set_modified_hl()
	vim.api.nvim_set_hl(0, "ModifiedLineNr", { fg = "#f7768e", bold = true })
end
set_modified_hl()
vim.api.nvim_create_autocmd("ColorScheme", { callback = set_modified_hl })
vim.api.nvim_create_autocmd({ "BufModifiedSet", "BufWinEnter" }, {
	group = vim.api.nvim_create_augroup("modified-linenr", { clear = true }),
	callback = function(args)
		local hl = vim.bo[args.buf].modified
				and "LineNr:ModifiedLineNr,LineNrAbove:ModifiedLineNr,LineNrBelow:ModifiedLineNr,CursorLineNr:ModifiedLineNr"
			or ""
		for _, win in ipairs(vim.fn.win_findbuf(args.buf)) do
			vim.wo[win].winhighlight = hl
		end
	end,
})
