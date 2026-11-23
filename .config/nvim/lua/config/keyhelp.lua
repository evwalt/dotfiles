--- Key Help ---
-- Minimal which-key replacement: <space>? lists every normal-mode <space> mapping
-- (global and buffer-local), sorted alphabetically, in a float. q or <Esc> closes it.

local function show()
	local seen, rows = {}, {}
	local function add(maps)
		for _, m in ipairs(maps) do
			local lhs = m.lhs:gsub(" ", "<space>")
			if lhs:sub(1, 7) == "<space>" and lhs ~= "<space>?" and not seen[lhs] then
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
	local lines = {}
	for _, r in ipairs(rows) do
		table.insert(lines, string.format("%-" .. width .. "s  %s", r.lhs, r.desc))
	end

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	local w = math.min(vim.o.columns - 4, 100)
	local h = math.min(vim.o.lines - 4, #lines)
	vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = w,
		height = math.max(h, 1),
		row = math.floor((vim.o.lines - h) / 2) - 1,
		col = math.floor((vim.o.columns - w) / 2),
		border = "rounded",
		title = " <space> keys ",
		style = "minimal",
	})
	for _, key in ipairs({ "q", "<Esc>" }) do
		vim.keymap.set("n", key, "<cmd>close<CR>", { buffer = buf, nowait = true })
	end
end

vim.keymap.set("n", "<space>?", show, { desc = "List <space> keymaps" })
