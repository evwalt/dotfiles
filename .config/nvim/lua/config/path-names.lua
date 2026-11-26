-- Shows a line that is only a backticked path, `` `~/a/b/file.md` ``,
-- as just its name (`file.md`, or `dir/` for a directory), and shows the raw line
-- on the cursor line so it can be edited or opened with gf.
-- Opt-in per file: put `<!-- path-names -->` in the first few lines.
-- Outside nvim the line still reads as the full path in inline code.
local M = {}

local ns = vim.api.nvim_create_namespace("path_names")
local MARKER = "<!-- path-names -->"

local function enabled(buf)
	for _, l in ipairs(vim.api.nvim_buf_get_lines(buf, 0, 10, false)) do
		if l:find(MARKER, 1, true) then
			return true
		end
	end
	return false
end

local function name(path)
	local dir = path:sub(-1) == "/"
	local base = path:gsub("/+$", ""):match("[^/]+$") or path
	return dir and base .. "/" or base
end

function M.refresh(buf)
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
	if not enabled(buf) then
		return
	end

	local cursor = -1
	if vim.api.nvim_get_current_buf() == buf then
		cursor = vim.api.nvim_win_get_cursor(0)[1] - 1
		-- Conceal needs level 2 to hide text outright; render-markdown already sets 3.
		if vim.wo.conceallevel < 2 then
			vim.wo.conceallevel = 2
		end
	end

	for i, l in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
		local path = l:match("^%s*`([~/][^`]*)`%s*$")
		if path and i - 1 ~= cursor then
			vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, { end_col = #l, conceal = "" })
			vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, {
				virt_text = { { name(path), "@markup.link.label" } },
				virt_text_pos = "inline",
			})
		end
	end
end

function M.attach(buf)
	M.refresh(buf)
	vim.api.nvim_create_autocmd(
		{ "BufEnter", "BufWinEnter", "TextChanged", "TextChangedI", "CursorMoved", "CursorMovedI" },
		{
			group = vim.api.nvim_create_augroup("path_names_" .. buf, { clear = true }),
			buffer = buf,
			callback = function()
				M.refresh(buf)
			end,
		}
	)
end

return M
