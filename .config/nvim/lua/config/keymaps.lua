--- Keymaps ---

--- Write, Quit, Wrap, Set Cursor Column, & Source ---
vim.keymap.set("n", "<space>w", ":w<CR>", { desc = "Write file" })
-- vim.keymap.set('n', '<space>v', function() vim.lsp.buf.format() end)
-- vim.keymap.set('n', '<space>m', function()
--     vim.lsp.buf.format()
--     vim.cmd('w')
-- end)
-- vim.keymap.set("n", "<space>q", ":q<CR>")
vim.keymap.set("n", "<space>z", ":set wrap!<CR>", { desc = "Toggle wrap" })

--- Netrw ---
-- vim.keymap.set('n', '<space>e', function()
--     if vim.bo.filetype == 'netrw' then
--         vim.cmd(':e #')
--     else
--         vim.cmd(':Ex')
--     end
-- end)

--- Buffers ---
vim.keymap.set("n", "<space>q", ":bd<CR>", { desc = "Delete buffer" })
vim.keymap.set("n", "<space>x", ":bd<CR>", { desc = "Delete buffer" })
vim.keymap.set("n", "<space><space>xf", ":bd!<CR>", { desc = "Force delete buffer" })
vim.keymap.set("n", "<space><space>qf", ":bd!<CR>", { desc = "Force delete buffer" })
vim.keymap.set("n", "<space>cp", function()
	local path = vim.fn.fnamemodify(vim.fn.expand("%:p"), ":~")
	if path == "" then
		return vim.notify("No file path", vim.log.levels.WARN)
	end
	vim.fn.setreg("+", path)
	vim.notify("Copied " .. path)
end, { desc = "Copy file path" })

--- Windows ---
vim.keymap.set("n", "<space>u", "<C-w>", { desc = "Window commands" })
vim.keymap.set("n", "<space>h", "<C-w>", { desc = "Window commands" })

--- Terminal ---
vim.keymap.set("t", "<esc><esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

--- Diagnostics Float ---
vim.keymap.set("n", "<space>d", ":lua vim.diagnostic.open_float()<CR>", { desc = "Diagnostics float" })

--- Diagnostics Inline ---
vim.keymap.set("n", "<space><space>td", function()
	local enabled = vim.diagnostic.is_enabled()
	vim.diagnostic.enable(not enabled)
	vim.notify("Diagnostics: globally " .. (enabled and "OFF" or "ON"))
end, { desc = "Toggle diagnostics globally" })

vim.keymap.set("n", "<space><space>btd", function()
	local filter = { bufnr = 0 }
	local enabled = vim.diagnostic.is_enabled(filter)
	vim.diagnostic.enable(not enabled, filter)
	vim.notify("Diagnostics: " .. (enabled and "OFF" or "ON") .. " for this buffer")
end, { desc = "Toggle diagnostics for current buffer" })

--- Edit Specific Files ---
local prod_personal_path = "~/Library/CloudStorage/Dropbox/docs/notes/productivity-personal/"
local function in_dropbox_dir()
	local cwd = vim.loop and vim.loop.cwd() or vim.fn.getcwd()
	local dropbox_root = vim.fn.expand("~/Library/CloudStorage/Dropbox/")
	if dropbox_root:sub(-1) ~= "/" then
		dropbox_root = dropbox_root .. "/"
	end
	return cwd ~= nil and vim.startswith(cwd, dropbox_root)
end

local function open_prod_personal(file)
	if not in_dropbox_dir() then
		vim.notify("prod_personal_path shortcuts only work inside Dropbox", vim.log.levels.WARN)
		return
	end
	vim.cmd("e " .. prod_personal_path .. file)
end
vim.keymap.set("n", "<space><space>d", function()
	-- open_prod_personal("daily-planning.md")
	-- jots currently being used as daily planning
	-- open_prod_personal("jots.md")
end)
vim.keymap.set("n", "<space><space>c", function()
	-- vim.cmd("e " .. prod_personal_path .. "../notes-generic.md")
	open_prod_personal("jots.md")
end, { desc = "Open jots" })
vim.keymap.set("n", "<space><space>r", function()
	open_prod_personal("notes-recent-brainstorming.md")
end, { desc = "Open daily-planning-recent" })
vim.keymap.set("n", "<space><space>l", function()
	-- open_prod_personal("jots.md")
end)
vim.keymap.set("n", "<space><space>s", function()
	open_prod_personal("archive/complete-to-do-items.md")
end, { desc = "Open complete-to-do-items" })
vim.keymap.set("n", "<space><space>i", function()
	open_prod_personal("daily-planning.md")
end, { desc = "Open daily-planning" })
vim.keymap.set("n", "<space><space>.", function()
	open_prod_personal("../notes-generic.md")
end, { desc = "Open notes-generic" })
vim.keymap.set("n", "<space><space>,", function()
	open_prod_personal("plan-overview-to-do-items.md")
end, { desc = "Open plan-overview-to-do-items" })
vim.keymap.set("n", "<space><space>'", function()
	open_prod_personal("jots.md")
end, { desc = "Open jots" })

--- Comments ---
vim.api.nvim_set_keymap("n", "<space>gc", "gcc", { noremap = false, silent = true })
vim.api.nvim_set_keymap("n", "<space>p.", "gcc", { noremap = false, silent = true })
vim.api.nvim_set_keymap("v", "<space>gc", "gc", { noremap = false, silent = true })
vim.api.nvim_set_keymap("v", "<space>p.", "gc", { noremap = false, silent = true })

--- Markdown ---
local function insert_to_do()
	if vim.bo.filetype == "markdown" then
		local row = vim.api.nvim_win_get_cursor(0)[1]

		vim.api.nvim_buf_set_lines(0, row, row, false, { "- [ ] " })
		vim.api.nvim_win_set_cursor(0, { row + 1, 0 })
		vim.cmd("startinsert!")
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

--- Markdown Date ---
vim.keymap.set("n", "<space><space>pd", function()
	--@type string
	local date = os.date("%Y-%m-%d")
	vim.api.nvim_put({ date }, "c", true, true)
end, { desc = "Insert current date" })
vim.keymap.set("n", "<space><space>mpd", function()
	local success = pcall(vim.cmd, "normal! f]l")
	if success then
		--@type string
		local date = os.date("%Y-%m-%d")
		vim.api.nvim_put({ "(" .. date .. ") " }, "c", true, true)
		vim.cmd("normal! 0j")
	else
		print("Closing bracket ']' not found")
	end
end, { desc = "Insert current date in a Markdown to-do item" })

--- Language-specific Settings ---
vim.api.nvim_create_autocmd("FileType", {
	pattern = { "javascript", "typescript", "javascriptreact", "typescriptreact" },
	callback = function()
		vim.keymap.set(
			"n",
			"<space><space>og",
			"iconsole.log();<Esc>F)i",
			{ noremap = true, silent = true, desc = "console.log()" }
		)
		vim.keymap.set(
			"n",
			"<space><space>pog",
			"iconsole.log(': ', );<Esc>F:Pf,lp",
			{ noremap = true, silent = true, desc = "console.log() with label" }
		)
		vim.keymap.set(
			"v",
			"<space><space>og",
			"yoconsole.log(': ', );<Esc>F:Pf,lp",
			{ noremap = true, silent = true, desc = "console.log() from selection" }
		)
	end,
})
