--- Key Help ---
-- Minimal which-key replacement: <space><space>? lists every normal-mode <space> mapping
-- (global and buffer-local), sorted alphabetically, in a float. <CR> runs the one under
-- the cursor, f filters, F clears the filter, / searches as usual, q or <Esc> closes.

local function show()
	local seen, rows = {}, {}
	local function add(maps)
		for _, m in ipairs(maps) do
			local lhs = m.lhs:gsub(" ", "<space>")
			if lhs:sub(1, 7) == "<space>" and not seen[lhs] then
				seen[lhs] = true
				table.insert(rows, { lhs = lhs, desc = m.desc or m.rhs or "" })
			end
		end
	end
	add(vim.api.nvim_buf_get_keymap(0, "n")) -- buffer-local first, as they win
	add(vim.api.nvim_get_keymap("n"))
	table.sort(rows, function(a, b)
		return a.lhs:lower() < b.lhs:lower()
	end)

	local width = 0
	for _, r in ipairs(rows) do
		width = math.max(width, #r.lhs)
	end
	local shown = rows -- rows currently listed, after any filter

	local buf = vim.api.nvim_create_buf(false, true)
	local function render(filter)
		shown = {}
		for _, r in ipairs(rows) do
			local hay = (r.lhs .. " " .. r.desc):lower()
			if not filter or hay:find(filter:lower(), 1, true) then
				table.insert(shown, r)
			end
		end
		local lines = {}
		for _, r in ipairs(shown) do
			table.insert(lines, string.format("%-" .. width .. "s  %s", r.lhs, r.desc))
		end
		if #lines == 0 then
			lines = { "(no matches for " .. filter .. ")" }
		end
		vim.bo[buf].modifiable = true
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
		vim.bo[buf].modifiable = false
	end
	render()

	local w = math.min(vim.o.columns - 4, 100)
	local h = math.min(vim.o.lines - 4, #rows)
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = w,
		height = math.max(h, 1),
		row = math.floor((vim.o.lines - h) / 2) - 1,
		col = math.floor((vim.o.columns - w) / 2),
		border = "rounded",
		title = " <space> keys ",
		footer = " <CR> run  f filter  F clear  / search  q close ",
		style = "minimal",
	})
	vim.wo[win].number = true
	vim.wo[win].relativenumber = true
	vim.wo[win].cursorline = true

	local function map(key, fn)
		vim.keymap.set("n", key, fn, { buffer = buf, nowait = true })
	end
	for _, key in ipairs({ "q", "<Esc>" }) do
		map(key, "<cmd>close<CR>")
	end
	-- Run the mapping under the cursor: close first so buffer-local maps of the
	-- original buffer apply, then feed the lhs as typed keys (remap on).
	map("<CR>", function()
		local r = shown[vim.api.nvim_win_get_cursor(0)[1]]
		if not r then
			return
		end
		vim.api.nvim_win_close(win, true)
		vim.api.nvim_feedkeys(vim.keycode(r.lhs), "m", false)
	end)
	-- Filter rows by substring of key or description (case-insensitive).
	map("f", function()
		local q = vim.fn.input("filter: ")
		render(q ~= "" and q or nil)
		vim.api.nvim_win_set_cursor(win, { 1, 0 })
	end)
	map("F", function()
		render()
	end)
end

vim.keymap.set("n", "<space><space>?", show, { desc = "List <space> keymaps" })
