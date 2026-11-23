-- Loose/strict modes for ltex spelling warnings.
-- Loose (default anywhere under the notes folder) hides spelling warnings for likely
-- proper nouns: words with an inner capital (PortSwigger) or a leading capital
-- mid-sentence (Gumroad). A capital at the start of a sentence or line says
-- nothing about the word, so those stay flagged. Loose also hides the grammar
-- rules in LOOSE_RULES, which misfire on terse notes. Strict shows everything.
local M = {}

-- Rule IDs come from ltex's diagnostic code (or `ltex-cli-plus file.md`).
local LOOSE_RULES = {
	CD_NN = true, -- "1015 plan": reads a clock time as a count, wants "plans"
	AUXILIARY_DO_WITH_INCORRECT_VERB_FORM = true, -- "do dishes" -> "do dish"
}

local LOOSE_DIRS = {
	os.getenv("HOME") .. "/Library/CloudStorage/Dropbox/docs/notes/",
}

local default_handler = vim.lsp.handlers["textDocument/publishDiagnostics"]
local last = {} -- bufnr -> { err, result, ctx } as last received from ltex

local function is_loose(bufnr)
	if vim.b[bufnr].ltex_mode then
		return vim.b[bufnr].ltex_mode == "loose"
	end
	-- resolve() so ~/Dropbox (a symlink) matches too
	local name = vim.fn.resolve(vim.api.nvim_buf_get_name(bufnr))
	for _, dir in ipairs(LOOSE_DIRS) do
		if vim.startswith(name, dir) then
			return true
		end
	end
	return false
end

local function at_sentence_start(prefix)
	prefix = prefix:gsub("%s+$", "")
	if prefix == "" then
		return true
	end
	-- List bullets, numbered items, headings, quotes, to-do boxes
	if prefix:match("^%s*[-*+>]$") or prefix:match("^%s*%d+[.)]$") or prefix:match("^%s*#+$") then
		return true
	end
	if prefix:match("^%s*[-*+]%s+%[.%]$") then
		return true
	end
	-- Colons don't count: "competitors: Steppin" is a name, not a new sentence.
	return prefix:match("[.!?][\"')%]*_]*$") ~= nil
end

local function hide(bufnr, d)
	if LOOSE_RULES[d.code] then
		return true
	end
	if not (type(d.code) == "string" and d.code:match("^MORFOLOGIK_RULE")) then
		return false
	end
	local line = vim.api.nvim_buf_get_lines(bufnr, d.range.start.line, d.range.start.line + 1, false)[1]
	if not line then
		return false
	end
	local ok_s, s = pcall(vim.str_byteindex, line, "utf-16", d.range.start.character)
	local ok_e, e = pcall(vim.str_byteindex, line, "utf-16", d.range["end"].character)
	if not (ok_s and ok_e) then
		return false
	end
	local word = line:sub(s + 1, e)
	if word:sub(2):match("%u") then
		return true
	end
	return word:match("^%u") ~= nil and not at_sentence_start(line:sub(1, s))
end

function M.handler(err, result, ctx)
	local bufnr = result and vim.uri_to_bufnr(result.uri)
	if bufnr then
		last[bufnr] = { err, result, ctx }
		if is_loose(bufnr) then
			result = vim.tbl_extend("force", result, {
				diagnostics = vim.tbl_filter(function(d)
					return not hide(bufnr, d)
				end, result.diagnostics),
			})
		end
	end
	return default_handler(err, result, ctx)
end

-- Returns "loose"/"strict" and why: "toggled", "notes folder" or "default".
function M.mode(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	if vim.b[bufnr].ltex_mode then
		return vim.b[bufnr].ltex_mode, "toggled"
	end
	if is_loose(bufnr) then
		return "loose", "notes folder"
	end
	return "strict", "default"
end

function M.toggle()
	local bufnr = vim.api.nvim_get_current_buf()
	vim.b[bufnr].ltex_mode = is_loose(bufnr) and "strict" or "loose"
	if last[bufnr] then
		M.handler(unpack(last[bufnr]))
	end
	pcall(function()
		require("lualine").refresh()
	end)
	vim.notify("ltex spelling: " .. vim.b[bufnr].ltex_mode .. " for this buffer")
end

return M
