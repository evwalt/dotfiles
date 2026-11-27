--- Key Help ---
-- Minimal which-key replacement: <space><space>? lists every normal-mode <space> mapping
-- (global and buffer-local), sorted alphabetically, in a float. <CR> runs the one under
-- the cursor, f fuzzy-filters live as you type, F clears the filter, / searches as usual, q or <Esc> closes.

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
	-- Empty filter lists every row; otherwise fuzzy-match "lhs  desc", best first.
	local function render(filter)
		if not filter or filter == "" then
			shown = rows
		else
			shown = vim.fn.matchfuzzy(rows, filter, {
				text_cb = function(r)
					return r.lhs .. "  " .. r.desc
				end,
			})
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
		footer = " <CR> run  f fuzzy  F clear  / search  q close ",
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
	-- Fuzzy filter that re-ranks the list on every keystroke. <CR> keeps the
	-- result (cursor on the best match, so <CR> again runs it); <Esc> restores all.
	-- While the prompt is open, push the list below any other float (noice's
	-- command palette draws the prompt over the top rows otherwise).
	local home = vim.api.nvim_win_get_config(win)
	local function dodge()
		local bottom = 0
		for _, w in ipairs(vim.api.nvim_list_wins()) do
			local c = vim.api.nvim_win_get_config(w)
			if w ~= win and c.relative ~= "" and not c.hide then
				local pos = vim.api.nvim_win_get_position(w)
				-- noice wraps its prompt in an outer window whose height already spans the border
				bottom = math.max(bottom, pos[1] + vim.api.nvim_win_get_height(w))
			end
		end
		if bottom > home.row then
			local h = math.max(home.height - (bottom - home.row), 3)
			vim.api.nvim_win_set_config(win, { relative = "editor", row = bottom, col = home.col, height = h })
		end
	end
	map("f", function()
		local au = vim.api.nvim_create_autocmd({ "CmdlineEnter", "CmdlineChanged" }, {
			callback = function(ev)
				if vim.fn.getcmdtype() ~= "@" then
					return
				end
				if ev.event == "CmdlineChanged" then
					render(vim.fn.getcmdline())
					vim.api.nvim_win_set_cursor(win, { 1, 0 })
				end
				-- noice opens its popup asynchronously, so measure on the next tick
				vim.schedule(function()
					if vim.api.nvim_win_is_valid(win) then
						dodge()
						vim.cmd.redraw()
					end
				end)
			end,
		})
		local ok, q = pcall(vim.fn.input, "fuzzy: ")
		vim.api.nvim_del_autocmd(au)
		vim.api.nvim_win_set_config(win, { relative = "editor", row = home.row, col = home.col, height = home.height })
		render(ok and q or nil)
		vim.api.nvim_win_set_cursor(win, { 1, 0 })
	end)
	map("F", function()
		render()
	end)
end

vim.keymap.set("n", "<space><space>?", show, { desc = "List <space> keymaps" })
