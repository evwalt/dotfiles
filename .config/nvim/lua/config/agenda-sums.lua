-- Shows work-hour sums as INFO diagnostics on `### <Weekday>` headings and on
-- their parent `##` heading (combined total),
-- so they get the same blue virtual text as other diagnostics and show up in
-- <space>d (float) and <space>i (Trouble).
-- Opt-in per file: put `<!-- agenda-sums -->` in the first few lines.
-- A block runs from one HHMM time to the next; the last time in a section has
-- no known end and is not counted.
local M = {}

local ns = vim.api.nvim_create_namespace("agenda_sums")
vim.diagnostic.config({ underline = false }, ns)
local MARKER = "<!-- agenda-sums -->"

local function fmt(min)
	return string.format("%gh", math.floor(min / 60 * 100 + 0.5) / 100)
end

local function sums(lines)
	local text = table.concat(lines, " ")
	local toks = {}
	for s, h, m, e in text:gmatch("()%f[%d](%d%d)(%d%d)%f[%D]()") do
		h, m = tonumber(h), tonumber(m)
		if h < 24 and m < 60 then
			toks[#toks + 1] = { t = h * 60 + m, s = s, e = e }
		end
	end

	local r = { solopreneur = 0, freelance = 0, job = 0, deep = 0, shallow = 0 }
	for i = 1, #toks - 1 do
		local label = text:sub(toks[i].e, toks[i + 1].s - 1):lower()
		local d = toks[i + 1].t - toks[i].t
		local kind = label:find("deep work") and "deep" or label:find("shallow work") and "shallow"
		if kind then
			r[kind] = r[kind] + d
			if label:find("%(solopreneur%)") then
				r.solopreneur = r.solopreneur + d
			end
			if label:find("%(freelance%)") then
				r.freelance = r.freelance + d
			end
			if label:find("%(job search%)") then
				r.job = r.job + d
			end
		end
	end
	return r
end

local function enabled(buf)
	for _, l in ipairs(vim.api.nvim_buf_get_lines(buf, 0, 10, false)) do
		if l:find(MARKER, 1, true) then
			return true
		end
	end
	return false
end

function M.refresh(buf)
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	if not enabled(buf) then
		vim.diagnostic.reset(ns, buf)
		return
	end

	local diags = {}
	local categories = {
		{ "solopreneur", "solopreneur" },
		{ "freelance", "freelance" },
		{ "job", "job search" },
		{ "deep", "deep work" },
		{ "shallow", "shallow work" },
	}
	local function add(lnum, r)
		local parts = {}
		for _, c in ipairs(categories) do
			if r[c[1]] > 0 then
				parts[#parts + 1] = c[2] .. ": " .. fmt(r[c[1]])
			end
		end
		-- solopreneur/freelance/job search are subsets of deep+shallow, so don't add them again
		parts[#parts + 1] = "total: " .. fmt(r.deep + r.shallow)
		diags[#diags + 1] = {
			lnum = lnum,
			col = 0,
			severity = vim.diagnostic.severity.INFO,
			source = "agenda-sums",
			message = table.concat(parts, ", "),
		}
	end

	-- `day` is the current weekday heading; `group` is the enclosing `##` heading,
	-- whose total is the sum of its weekday children.
	local day, acc = nil, {}
	local group, total = nil, nil
	local function flush_day()
		if not day then
			return
		end
		local r = sums(acc)
		if r.deep + r.shallow > 0 then
			add(day, r)
			if group then
				total = total or { solopreneur = 0, freelance = 0, job = 0, deep = 0, shallow = 0 }
				for k, v in pairs(r) do
					total[k] = total[k] + v
				end
			end
		end
		day, acc = nil, {}
	end
	local function flush_group()
		flush_day()
		if group and total then
			add(group, total)
		end
		group, total = nil, nil
	end

	for i, l in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
		if l:match("^#%s") or l:match("^##%s") then
			flush_group()
			group = l:match("^##%s") and (i - 1) or nil
		elseif l:match("^#+%s") then
			flush_day()
			day = l:match("^###%s+%a+day%s*$") and (i - 1) or nil
		elseif day then
			acc[#acc + 1] = l
		end
	end
	flush_group()
	vim.diagnostic.set(ns, buf, diags)
end

function M.attach(buf)
	M.refresh(buf)
	vim.api.nvim_create_autocmd({ "BufEnter", "TextChanged", "InsertLeave" }, {
		group = vim.api.nvim_create_augroup("agenda_sums_" .. buf, { clear = true }),
		buffer = buf,
		callback = function()
			M.refresh(buf)
		end,
	})
end

return M
