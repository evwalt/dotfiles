-- Keymaps
--

-- Write, Quit, Wrap, Set Cursor Column, & Source
--
vim.keymap.set("n", "<space>w", ":w<CR>")
-- vim.keymap.set('n', '<space>v', function() vim.lsp.buf.format() end)
-- vim.keymap.set('n', '<space>m', function()
--     vim.lsp.buf.format()
--     vim.cmd('w')
-- end)
-- vim.keymap.set("n", "<space>q", ":q<CR>")
vim.keymap.set("n", "<space>z", ":set wrap!<CR>")
vim.keymap.set("n", "<space>hc", ":set cursorcolumn!<CR>")
vim.keymap.set("n", "<space>u.", ":set cursorcolumn!<CR>")
vim.keymap.set("n", "<space>so", ":source %<CR>")

-- Netrw
--
-- vim.keymap.set('n', '<space>e', function()
--     if vim.bo.filetype == 'netrw' then
--         vim.cmd(':e #')
--     else
--         vim.cmd(':Ex')
--     end
-- end)

-- Buffers
--
vim.keymap.set("n", "<space>q", ":bd<CR>")
vim.keymap.set("n", "<space>x", ":bd<CR>")
vim.keymap.set("n", "<space><space>xf", ":bd!<CR>")
vim.keymap.set("n", "<space><space>qf", ":bd!<CR>")

-- Windows
--
vim.keymap.set("n", "<space>u", "<C-w>")
vim.keymap.set("n", "<space>h", "<C-w>")

-- Terminal
--
vim.keymap.set("n", "<space>tj", function()
	vim.cmd.vnew()
	vim.cmd.term()
	vim.cmd.wincmd("J")
	-- vim.api.nvim_win_set_height(0, 15)
	vim.cmd("resize 50%")
end)
vim.keymap.set("n", "<space>tl", function()
	-- local current_height = vim.api.nvim_win_get_height(0)
	vim.cmd.vnew()
	vim.cmd.term()
	vim.cmd.wincmd("L")
	-- vim.api.nvim_win_set_height(0, current_height)
end)
vim.keymap.set("t", "<esc>", "<C-\\><C-n>")

-- Edit Specific Files
--
local prod_personal_path = "~/Library/CloudStorage/Dropbox/docs/notes/productivity-personal/"
vim.keymap.set("n", "<space><space>d", function()
	vim.cmd("e " .. prod_personal_path .. "daily-planning.md")
end)
vim.keymap.set("n", "<space><space>c", function()
	vim.cmd("e " .. prod_personal_path .. "../notes-generic.md")
end)
vim.keymap.set("n", "<space><space>r", function()
	vim.cmd("e " .. prod_personal_path .. "plan-overview-to-do-items.md")
end)
vim.keymap.set("n", "<space><space>l", function()
	vim.cmd("e " .. prod_personal_path .. "jots.md")
end)
vim.keymap.set("n", "<space><space>s", function()
	vim.cmd("e " .. prod_personal_path .. "/archive/complete-todo-items.md")
end)
vim.keymap.set("n", "<space><space>i", function()
	vim.cmd("e " .. prod_personal_path .. "daily-planning.md")
end)
vim.keymap.set("n", "<space><space>.", function()
	vim.cmd("e " .. prod_personal_path .. "../notes-generic.md")
end)
vim.keymap.set("n", "<space><space>,", function()
	vim.cmd("e " .. prod_personal_path .. "plan-overview-to-do-items.md")
end)
vim.keymap.set("n", "<space><space>'", function()
	vim.cmd("e " .. prod_personal_path .. "jots.md")
end)

-- Comments
--
vim.api.nvim_set_keymap("n", "<space>gc", "gcc", { noremap = false, silent = true })
vim.api.nvim_set_keymap("n", "<space>p.", "gcc", { noremap = false, silent = true })
vim.api.nvim_set_keymap("v", "<space>gc", "gc", { noremap = false, silent = true })
vim.api.nvim_set_keymap("v", "<space>p.", "gc", { noremap = false, silent = true })

-- Markdown
--
local function insert_to_do()
	if vim.bo.filetype == "markdown" then
		vim.api.nvim_command("normal! o")
		vim.api.nvim_put({ "- [ ] " }, "c", true, true)
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("a", true, false, true), "n", true)
	else
		print("Not a markdown file")
	end
end
vim.keymap.set("n", "<space>ue", function()
	insert_to_do()
end, { desc = "Insert to-do item" })
vim.keymap.set("n", "<space>ht", function()
	insert_to_do()
end, { desc = "Insert to-do item" })

-- Language-specific Settings
--
vim.api.nvim_create_autocmd("FileType", {
	pattern = { "javascript", "typescript", "javascriptreact", "typescriptreact" },
	callback = function()
		vim.keymap.set("n", "<space><space>on", "iconsole.log();<Esc>F)i", { noremap = true, silent = true })
		vim.keymap.set("v", "<space><space>on", "yoconsole.log(': ', );<Esc>F:Pf,lp", { noremap = true, silent = true })
	end,
})
