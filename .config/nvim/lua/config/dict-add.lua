-- Add the word under the cursor to the ltex and codebook dictionaries
-- (private yadm repo), with a diff preview before writing/committing.
local M = {}

local HOME = os.getenv("HOME")
local FILES = {
	{ path = HOME .. "/.config/ltex/ltex-dictionary.lua", open = "^return {", close = "^}" },
	{ path = HOME .. "/.config/codebook/codebook.toml", open = "^words = %[", close = "^%]" },
}
local YADM = {
	"yadm",
	"--yadm-dir",
	HOME .. "/.config/yadm-private",
	"--yadm-data",
	HOME .. "/.local/share/yadm-private",
}

local function notify(msg, level)
	vim.schedule(function()
		vim.notify("dict-add: " .. msg, level or vim.log.levels.INFO)
	end)
end

-- Sort key: case-insensitive, lowercase form before a cased form of the same word.
local function goes_before(word, entry)
	local lw, le = word:lower(), entry:lower()
	if lw ~= le then
		return lw < le
	end
	return word == lw and entry ~= lw
end

-- Returns new lines (or nil if the list can't be found) and the spellings added.
local function insert_words(lines, file, words)
	local first, last
	for i, line in ipairs(lines) do
		if not first and line:match(file.open) then
			first = i
		elseif first and line:match(file.close) then
			last = i
			break
		end
	end
	if not (first and last) then
		return nil, {}
	end

	local indent = (lines[first + 1] or ""):match('^(%s*)"') or "\t"
	local added = {}
	for _, word in ipairs(words) do
		local pos, present = last, false
		for i = first + 1, last - 1 do
			local entry = lines[i]:match('^%s*"(.-)",%s*$')
			if entry == word then
				present = true
				break
			end
			if entry and pos == last and goes_before(word, entry) then
				pos = i
			end
		end
		if not present then
			table.insert(lines, pos, indent .. '"' .. word .. '",')
			last = last + 1
			table.insert(added, word)
		end
	end
	return lines, added
end

local function reload_lsps()
	local ltex_dict = dofile(FILES[1].path)
	for _, client in ipairs(vim.lsp.get_clients({ name = "ltex_plus" })) do
		client.settings.ltex.dictionary["en-US"] = ltex_dict
		client:notify("workspace/didChangeConfiguration", { settings = client.settings })
	end
	-- Clients started later this session should get the new list too.
	vim.lsp.config("ltex_plus", { settings = { ltex = { dictionary = { ["en-US"] = ltex_dict } } } })
	-- codebook-lsp re-reads its config on its own at the next edit.
end

local function commit_and_push(msg)
	local function run(args, on_ok)
		vim.system(vim.list_extend(vim.deepcopy(YADM), args), { text = true }, function(res)
			if res.code ~= 0 then
				notify(table.concat(args, " ", 1, 1) .. " failed: " .. vim.trim(res.stderr or ""), vim.log.levels.ERROR)
			else
				on_ok(res)
			end
		end)
	end
	run({ "diff", "--cached", "--name-only" }, function(res)
		if vim.trim(res.stdout) ~= "" then
			notify("other changes already staged; wrote files but did not commit", vim.log.levels.WARN)
			return
		end
		run({ "add", FILES[1].path, FILES[2].path }, function()
			run({ "commit", "-q", "-m", msg }, function()
				run({ "push", "-q" }, function()
					notify("committed and pushed: " .. msg)
				end)
			end)
		end)
	end)
end

local function preview(changes, msg)
	local lines = { msg, "" }
	for _, c in ipairs(changes) do
		local diff = vim.text.diff(table.concat(c.old, "\n") .. "\n", table.concat(c.new, "\n") .. "\n", { ctxlen = 2 })
		local short = c.path:gsub("^" .. vim.pesc(HOME), "~")
		table.insert(lines, "--- " .. short)
		table.insert(lines, "+++ " .. short)
		vim.list_extend(lines, vim.split(vim.trim(diff), "\n"))
		table.insert(lines, "")
	end

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].filetype = "diff"
	vim.bo[buf].modifiable = false
	vim.bo[buf].bufhidden = "wipe"

	local width = 20
	for _, l in ipairs(lines) do
		width = math.max(width, vim.fn.strdisplaywidth(l))
	end
	width = math.min(width + 2, vim.o.columns - 4)
	local height = math.min(#lines, vim.o.lines - 6)
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = math.floor((vim.o.lines - height) / 2),
		col = math.floor((vim.o.columns - width) / 2),
		style = "minimal",
		border = "rounded",
		title = " Add to dictionaries ",
		footer = " [y] commit+push  [w] write only  [n] cancel ",
		footer_pos = "center",
	})

	local function close()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end
	local function write()
		close()
		for _, c in ipairs(changes) do
			vim.fn.writefile(c.new, c.path)
		end
		reload_lsps()
	end
	local opts = { buffer = buf, nowait = true }
	vim.keymap.set("n", "y", function()
		write()
		commit_and_push(msg)
	end, opts)
	vim.keymap.set("n", "w", function()
		write()
		notify("written, not committed")
	end, opts)
	for _, key in ipairs({ "n", "q", "<Esc>" }) do
		vim.keymap.set("n", key, close, opts)
	end
end

-- exact: add only the spelling under the cursor; otherwise also its lowercase form.
function M.add(exact)
	local col = vim.api.nvim_win_get_cursor(0)[2]
	local char = vim.api.nvim_get_current_line():sub(col + 1, col + 1)
	local word = vim.fn.expand("<cword>")
	if not char:match("%a") or not word:match("^%a+$") then
		vim.notify("dict-add: cursor must be on a word made only of letters", vim.log.levels.WARN)
		return
	end

	local words = { word }
	if not exact and word ~= word:lower() then
		words = { word:lower(), word }
	end

	local changes, all_added = {}, {}
	for _, file in ipairs(FILES) do
		local old = vim.fn.readfile(file.path)
		local new, added = insert_words(vim.deepcopy(old), file, words)
		if not new then
			vim.notify("dict-add: word list not found in " .. file.path, vim.log.levels.ERROR)
			return
		end
		if #added > 0 then
			table.insert(changes, { path = file.path, old = old, new = new })
			for _, w in ipairs(added) do
				all_added[w] = true
			end
		end
	end
	if #changes == 0 then
		vim.notify("dict-add: already in both dictionaries: " .. table.concat(words, ", "))
		return
	end

	local quoted = {}
	for _, w in ipairs(words) do
		if all_added[w] then
			table.insert(quoted, "'" .. w .. "'")
		end
	end
	preview(changes, "chore(dictionaries): add " .. table.concat(quoted, ", "))
end

return M
