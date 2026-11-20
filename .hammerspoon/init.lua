--- Automatic Config Reload ---
local function reloadConfig(files)
	local doReload = false
	for _, file in pairs(files) do
		if file:sub(-4) == ".lua" then
			doReload = true
		end
	end
	if doReload then
		hs.reload()
	end
end

---@diagnostic disable-next-line: lowercase-global
myWatcher = hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", reloadConfig):start()
-- All alerts (Harbor Night colors): same translucent dark panel, hairline border and rounding as the floating clock.
hs.alert.defaultStyle.radius = 10
hs.alert.defaultStyle.strokeWidth = 1
hs.alert.defaultStyle.strokeColor = { hex = "#cdd3e2", alpha = 0.15 }
hs.alert.defaultStyle.fillColor = { hex = "#0c0c16", alpha = 0.9 } -- more opaque than the clock: alerts carry more text
hs.alert.defaultStyle.textColor = { hex = "#cdd3e2", alpha = 0.95 }
hs.alert.defaultStyle.atScreenEdge = 1 -- all alerts: top of screen, centered horizontally
hs.alert.defaultStyle.textFont = "Hack Nerd Font" -- all alerts: same font and size as the prompts
hs.alert.defaultStyle.textSize = 17
print(os.getenv("HOME") .. "/.hammerspoon/")

--- Multi-action Keys ---
local hyper = { "ctrl", "alt", "cmd", "shift" }
--- Multi-action picker for a single hotkey ---
-- Usage: hs.hotkey.bind(hyper, "G", actionPicker("Title", { { "m", "Skim" }, { "w", "Label", fn } }))
-- Each item is { rightKey, appName } or { rightKey, label, action }. Every action is also bound
-- to the mirror key on the left hand (same finger and row, Dvorak), shown after a slash. The hint
-- lists every key in right-hand keyboard order, one block per row, free keys shown as "—".
-- Press the hyper combo, then a sub-key. Esc cancels. The hint stays up until either.
-- z/; opens a search over every picker and Hyper key (see searchAll). "space" and "delete"
-- (Backspace) are extra slots with no mirror, listed below the grid as SPC and DEL.
-- An item with `front = true` acts on the front app; from search it asks to confirm first.
local MIRROR_ROWS = { -- Dvorak right-hand keys and their left-hand mirrors, row by row
	{ "fgcrl", "yp.,'" },
	{ "dhtns", "iueoa" },
	{ "bmwvz", "xkjq;" },
}
local MIRROR = {} -- right key -> left key
for _, keys in ipairs(MIRROR_ROWS) do
	for col = 1, #keys[1] do
		local right = keys[1]:sub(col, col)
		MIRROR[right] = keys[2]:sub(col, col)
	end
end
local PROMPT_STYLE = {
	textStyle = { paragraphStyle = { alignment = "left" } },
}
hs.alert.show("Config loaded", PROMPT_STYLE)
-- Every key in keyboard order, unused ones shown as free slots.
local function hintText(labels)
	local lines = {}
	for row, keys in ipairs(MIRROR_ROWS) do
		if row > 1 then
			table.insert(lines, "")
		end
		for col = 1, #keys[1] do
			local right = keys[1]:sub(col, col)
			table.insert(lines, string.format("%s/%s  %s", right, MIRROR[right], labels[right] or "—"))
		end
	end
	return table.concat(lines, "\n")
end
local EXTRA_KEYS = { { "space", "SPC" }, { "delete", "DEL" } } -- unmirrored slots, hint name
local SEARCH_KEY = "z"
local searchAll -- defined after the Hyper keys below
local commandMode -- the : prompt, defined after search below
local function itemAction(label, action)
	return action or function()
		hs.application.launchOrFocus(label)
	end
end
local function actionPicker(title, items)
	local m = hs.hotkey.modal.new()
	local labels = { [SEARCH_KEY] = "Search" } -- right key -> label
	local function bindRun(keys, run)
		for _, key in ipairs(keys) do
			m:bind({}, key, function()
				hs.alert.closeAll()
				m:exit()
				run()
			end)
		end
	end
	for _, item in ipairs(items) do
		local key, label = item[1], item[2]
		assert(key ~= SEARCH_KEY, SEARCH_KEY .. " is reserved for search")
		assert(MIRROR[key] or key == "space" or key == "delete", "no mirror key for " .. key)
		labels[key] = label
		bindRun(MIRROR[key] and { key, MIRROR[key] } or { key }, itemAction(label, item[3]))
	end
	bindRun({ SEARCH_KEY, MIRROR[SEARCH_KEY] }, function()
		searchAll()
	end)
	m:bind({}, "escape", function()
		hs.alert.closeAll()
		m:exit()
	end)
	local extras = {}
	for _, extra in ipairs(EXTRA_KEYS) do
		table.insert(extras, string.format("%-5s%s", extra[2], labels[extra[1]] or "—"))
	end
	local hint = title .. "\n\n" .. hintText(labels) .. "\n\n" .. table.concat(extras, "\n")
	function m:entered()
		hs.alert.closeAll()
		hs.alert.show(hint, PROMPT_STYLE, hs.screen.mainScreen(), true) -- non-number duration: stays up until closed
	end
	return function()
		m:enter()
	end
end

--- Y/N confirm prompt, styled like the picker hint ---
-- Returns a function that shows `title`, then `message`, and waits: Y or Enter runs fn, N or Esc cancels.
-- The prompt stays up until one of those is pressed.
local function confirmPrompt(title, message, fn)
	local m = hs.hotkey.modal.new()
	local function close()
		hs.alert.closeAll()
		m:exit()
	end
	for _, key in ipairs({ "y", "return" }) do
		m:bind({}, key, function()
			close()
			fn()
		end)
	end
	m:bind({}, "n", close)
	m:bind({}, "escape", close)
	function m:entered()
		hs.alert.closeAll()
		local text = title .. "\n\n" .. message .. "\n\nY  confirm (or Enter)\nN  cancel (or Esc)"
		hs.alert.show(text, PROMPT_STYLE, hs.screen.mainScreen(), true)
	end
	return function()
		m:enter()
	end
end

--- Firefox Active Border ---
-- Periwinkle border around the focused Firefox window, only when Firefox has more
-- than one window. Enabled state persists via hs.settings (default: on).
local borderEnabled = hs.settings.get("firefoxBorder")
if borderEnabled == nil then
	borderEnabled = true
end
local borderWidth = 3
local borderCanvas
local function refreshBorder()
	local target
	if borderEnabled then
		local focused = hs.window.focusedWindow()
		local focusedApp = focused and focused:application()
		if focusedApp and focusedApp:name() == "Firefox" then
			local count = 0
			for _, win in ipairs(hs.window.orderedWindows()) do
				local app = win:application()
				if win:isStandard() and app and app:name() == "Firefox" then
					count = count + 1
				end
			end
			if count > 1 then
				target = focused:frame()
			end
		end
	end
	if not target then
		if borderCanvas then
			borderCanvas:hide()
		end
		return
	end
	-- Stroke is centered on the path, so inset by half the width to stay inside.
	local elements = {
		{
			type = "rectangle",
			action = "stroke",
			strokeColor = { hex = "#b1b9f9", alpha = 1 }, -- Harbor Night periwinkle
			strokeWidth = borderWidth,
			frame = {
				x = borderWidth / 2,
				y = borderWidth / 2,
				w = target.w - borderWidth,
				h = target.h - borderWidth,
			},
			roundedRectRadii = { xRadius = 10, yRadius = 10 },
		},
	}
	if borderCanvas then
		borderCanvas:frame(target):replaceElements(elements):show()
	else
		-- Floating level keeps it above the window it outlines.
		borderCanvas = hs.canvas
			.new(target)
			:level(hs.canvas.windowLevels.floating)
			:appendElements(elements)
			:show()
	end
end
local function toggleBorder()
	borderEnabled = not borderEnabled
	hs.settings.set("firefoxBorder", borderEnabled)
	refreshBorder()
	hs.alert.show("Firefox border: " .. (borderEnabled and "on" or "off"))
end

-- Debounced: window moves fire many events while dragging. A second, later
-- pass catches focus changes where focusedWindow() lags behind the event.
local borderRefresh = hs.timer.delayed.new(0.05, refreshBorder)
local borderRefreshLate = hs.timer.delayed.new(0.3, refreshBorder)
local function scheduleBorder()
	borderRefresh:start()
	borderRefreshLate:start()
end
hs.window.filter.default:subscribe({
	hs.window.filter.windowCreated,
	hs.window.filter.windowDestroyed,
	hs.window.filter.windowFocused,
	hs.window.filter.windowUnfocused,
	hs.window.filter.windowMoved,
	hs.window.filter.windowMinimized,
	hs.window.filter.windowUnminimized,
	hs.window.filter.windowVisible,
	hs.window.filter.windowNotVisible,
}, scheduleBorder)
---@diagnostic disable-next-line: lowercase-global
borderSpaceWatcher = hs.spaces.watcher.new(scheduleBorder):start()
---@diagnostic disable-next-line: lowercase-global
borderAppWatcher = hs.application.watcher.new(scheduleBorder):start()
-- Safety net for any focus change that emits no event.
---@diagnostic disable-next-line: lowercase-global
borderHeartbeat = hs.timer.doEvery(1, refreshBorder)
refreshBorder()

--- Screenshot focused window to clipboard (no path) or to a file ---
local function screenshotWindow(path)
	local win = hs.window.focusedWindow()
	if not win then
		return
	end
	-- -o: no window shadow, -l: capture by window id, -c: clipboard
	local args = { "-o", "-l", tostring(win:id()), path or "-c" }
	hs.task
		.new("/usr/sbin/screencapture", function(code)
			hs.alert.show(code ~= 0 and "Screenshot failed" or (path and "Saved to Downloads" or "Window copied"))
		end, args)
		:start()
end

--- Floating Clock ---
-- 24-hour HHMM (HHMMSS with seconds) in the top-right corner, above all windows and spaces,
-- click-through, with optional YYYY-MM-DD date prefix. Toggles live in the Hyper+G picker.
-- State persists via hs.settings (default: on).
local clockOn = hs.settings.get("clockOn")
if clockOn == nil then
	clockOn = true
end
local clockSecs = hs.settings.get("clockSecs") or false
local clockDate = hs.settings.get("clockDate") or false
-- macOS system font (San Francisco) at roughly menu bar size; its digits are fixed-width.
local clockFont, clockSize = ".AppleSystemUIFont", 15
local CLOCK_PAD_X, CLOCK_PAD_Y, CLOCK_INSET = 8, 3, 0
local clockCanvas, clockTimer
local updateCt -- the ct slot left of the clock; defined with command mode below
local toggleCt -- show/hide that slot (the timer and alarm keep running)

local function clockText()
	return os.date((clockDate and "%Y-%m-%d " or "") .. (clockSecs and "%H%M%S" or "%H%M"))
end

local function clockFrame()
	local f = hs.screen.mainScreen():frame() -- excludes the menu bar
	local size = hs.drawing.getTextDrawingSize(clockText(), { font = clockFont, size = clockSize })
	local w, h = math.ceil(size.w) + 2 * CLOCK_PAD_X, math.ceil(size.h) + 2 * CLOCK_PAD_Y
	return { x = f.x + f.w - w - CLOCK_INSET, y = f.y + CLOCK_INSET, w = w, h = h }
end

local function updateClock()
	if not clockCanvas then
		return
	end
	clockCanvas:frame(clockFrame())
	clockCanvas[2].text = clockText()
	if updateCt then
		updateCt()
	end
end

-- Clock-styled overlay panel: [1] background, [2] text. Also used by the ct slot.
local function newOverlay(frame)
	local canvas = hs.canvas.new(frame)
	canvas:level(hs.canvas.windowLevels.overlay)
	canvas:behavior({ "canJoinAllSpaces", "stationary" })
	canvas:appendElements({
		type = "rectangle",
		action = "strokeAndFill",
		fillColor = { hex = "#0c0c16", alpha = 0.65 },
		strokeColor = { hex = "#cdd3e2", alpha = 0.15 },
		strokeWidth = 1,
		roundedRectRadii = { xRadius = 8, yRadius = 8 },
	}, {
		type = "text",
		text = "",
		textFont = clockFont,
		textSize = clockSize,
		textColor = { hex = "#cdd3e2", alpha = 0.95 },
		textAlignment = "center",
		frame = { x = 0, y = CLOCK_PAD_Y, w = "100%", h = "100%" },
	})
	return canvas
end

local function startClock()
	clockCanvas = newOverlay(clockFrame())
	updateClock()
	clockCanvas:show()
	clockTimer = hs.timer.doEvery(1, updateClock)
end

local function stopClock()
	if clockTimer then
		clockTimer:stop()
		clockTimer = nil
	end
	if clockCanvas then
		clockCanvas:delete()
		clockCanvas = nil
	end
end

local function setClock(on)
	clockOn = on
	hs.settings.set("clockOn", on)
	if on and not clockCanvas then
		startClock()
	elseif not on then
		stopClock()
	end
	if updateCt then
		updateCt()
	end
end

local function toggleClockSecs()
	clockSecs = not clockSecs
	hs.settings.set("clockSecs", clockSecs)
	updateClock()
end

local function toggleClockDate()
	clockDate = not clockDate
	hs.settings.set("clockDate", clockDate)
	updateClock()
end

if clockOn then
	startClock()
end

-- Cursor beacon: arm tmux's one-shot @beacon_once flag, then fire its client-focus-in hook
-- (fading block at the cursor). The hook ignores plain focus changes without the flag.
-- If Alacritty isn't frontmost, focusing it fires the hook by itself.
local function cursorBeacon()
	local front = hs.application.frontmostApplication()
	if front and front:name() == "Alacritty" then
		hs.task
			.new("/usr/local/bin/tmux", nil, { "set", "-g", "@beacon_once", "1", ";", "set-hook", "-R", "client-focus-in" })
			:start()
	else
		hs.task
			.new("/usr/local/bin/tmux", function()
				hs.application.launchOrFocus("Alacritty")
			end, { "set", "-g", "@beacon_once", "1" })
			:start()
	end
end

-- Dvorak keyboard layout reference: `crl tns wvz fdb`
-- Which Hyper chords are reachable depends on the keyboard firmware's layers; check the keyboard config.
local showHyperHints -- defined after the Hyper keys below
local function showDesktop()
	-- Private API; fall back to the Show Desktop shortcut (F11 by default).
	if not (hs.spaces.toggleShowDesktop and pcall(hs.spaces.toggleShowDesktop)) then
		hs.eventtap.keyStroke({}, "f11")
	end
end
local function handyDictate()
	hs.task.new("/Applications/Handy.app/Contents/MacOS/handy", nil, { "--toggle-transcription" }):start()
end
local function keyStroker(mods, key)
	return function()
		hs.eventtap.keyStroke(mods, key)
	end
end
local picker1Items = {
	{ "f", "Reminders" },
	{
		"g",
		"Screenshot Window to Clipboard",
		function()
			screenshotWindow()
		end,
		front = true,
	},
	{ "c", "Copy (s-c)", keyStroker({ "cmd" }, "c"), front = true },
	{ "l", "Notes" },
	{ "d", "Toggle Clock Seconds", toggleClockSecs },
	{ "h", "Handy" },
	{ "t", "Cursor Beacon", cursorBeacon, front = true },
	{ "n", "Spotify" },
	{
		"s",
		"Screenshot Window to ~/Downloads",
		function()
			screenshotWindow(
				os.getenv("HOME") .. "/Downloads/Screenshot " .. os.date("%Y-%m-%d at %H.%M.%S") .. ".png"
			)
		end,
		front = true,
	},
	{ "b", "Cut (s-x)", keyStroker({ "cmd" }, "x"), front = true },
	{ "m", "Toggle Clock Date", toggleClockDate },
	{
		"w",
		"Toggle Clock",
		function()
			setClock(not clockOn)
		end,
	},
	{ "v", "Paste (s-v)", keyStroker({ "cmd" }, "v"), front = true },
	{
		"delete",
		"Toggle Countdown",
		function()
			toggleCt()
		end,
	},
}
hs.hotkey.bind(hyper, "G", actionPicker("Picker 1 (H-g)", picker1Items))
local picker2Items = {
	{ "f", "Finder" },
	{
		"g",
		"Toggle Grayscale",
		function()
			hs.screen.setForceToGray(not hs.screen.getForceToGray())
		end,
	},
	{ "c", "Toggle Firefox Border", toggleBorder },
	{ "r", "Skim" },
	{
		"d",
		"Hyper Keys",
		function()
			showHyperHints()
		end,
	},
	{ "m", "Show Desktop", showDesktop },
	{
		"h",
		"Shut Down",
		confirmPrompt("Shut Down (H-f h)", "Shut down the computer?", hs.caffeinate.shutdownSystem),
	},
	{
		"t",
		"Restart",
		confirmPrompt("Restart (H-f t)", "Restart the computer?", hs.caffeinate.restartSystem),
	},
	{ "v", "Quit App (s-q)", keyStroker({ "cmd" }, "q"), front = true },
	{ "s", "Select All (s-a)", keyStroker({ "cmd" }, "a"), front = true },
	{ "n", "Sleep", confirmPrompt("Sleep (H-f n)", "Sleep the computer?", hs.caffeinate.systemSleep) },
	{ "b", "System Settings" },
}
hs.hotkey.bind(hyper, "F", actionPicker("Picker 2 (H-f)", picker2Items))
-- Top-level Hyper keys. Each is { key, label, action, front = bool }; no action launches the app named by
-- label. Labels in parens are handled outside Hammerspoon and only listed in the hint.
local hyperKeys = {
	{ "c", "Handy Dictate", handyDictate },
	{
		"r",
		"Switch Window in App",
		function()
			hs.eventtap.keyStroke({ "cmd" }, "`")
		end,
		front = true,
	},
	{ "d", "(Homerow)" },
	{ "h", "(Enter)" },
	{ "s", "Activity Monitor" },
	{ "b", "Messages" },
	{ "m", "Firefox" },
	{ "v", "Alacritty" },
	{
		"z",
		"Command Mode",
		function()
			commandMode()
		end,
	},
	{ "i", "Google Chrome" },
	{ "j", "zoom.us" },
}
local hyperLabels = { f = "Picker 2", g = "Picker 1" }
local extraHints = {} -- keys outside the mirrored grid
for _, item in ipairs(hyperKeys) do
	local key, label, action = item[1], item[2], item[3]
	if label:sub(1, 1) ~= "(" then
		hs.hotkey.bind(hyper, key:upper(), action or function()
			hs.application.launchOrFocus(label)
		end)
	end
	if MIRROR[key] then
		hyperLabels[key] = label
	else
		table.insert(extraHints, key .. "      " .. label)
	end
end
local hyperHint = "Hyper Keys (H-f d)\n\n" .. hintText(hyperLabels) .. "\n\n" .. table.concat(extraHints, "\n")
local hyperHintModal = hs.hotkey.modal.new()
hyperHintModal:bind({}, "escape", function()
	hs.alert.closeAll()
	hyperHintModal:exit()
end)
function hyperHintModal:entered()
	hs.alert.closeAll()
	hs.alert.show(hyperHint, PROMPT_STYLE, hs.screen.mainScreen(), true)
end
showHyperHints = function()
	hyperHintModal:enter()
end

--- Search every picker item and Hyper key (z/; in a picker) ---
-- Drawn as an alert like the pickers, growing with the matches and scrolling only past the screen
-- bottom. While open, a key tap reads every key press and keeps it from the front app: type to
-- filter, C-n/Down and C-p/Up to move, Enter to run, Esc to cancel. The query edits like a
-- readline prompt (see searchEdit), with a block cursor like Alacritty's. A front-app
-- item asks to confirm first. Matching is fuzzy over the label and the keys (see fuzzyMatch), with
-- smartcase. Rows keep their table order; the best match is selected and matched chars are pink.
local searchEntries = {} -- { group, label, keys, run }
local function addSearchEntry(group, label, keys, action, front, shortKeys)
	local run = itemAction(label, action)
	if front then
		run = confirmPrompt(label .. " (" .. (shortKeys or keys) .. ")", "Run in the front app?", run)
	end
	table.insert(searchEntries, { group = group, label = label, keys = keys, run = run })
end
for _, picker in ipairs({ { "H-g", picker1Items, "Picker 1 (H-g)" }, { "H-f", picker2Items, "Picker 2 (H-f)" } }) do
	for _, item in ipairs(picker[2]) do
		local key = item[1]
		local keyName = key
		for _, extra in ipairs(EXTRA_KEYS) do
			if extra[1] == key then
				keyName = extra[2]
			end
		end
		local shortKeys = picker[1] .. " " .. keyName -- confirm title, like "Shut Down (H-f h)"
		local keys = MIRROR[key] and string.format("%s/%s", shortKeys, MIRROR[key]) or shortKeys
		addSearchEntry(picker[3], item[2], keys, item[3], item.front, shortKeys)
	end
end
for _, item in ipairs(hyperKeys) do
	if item[2]:sub(1, 1) ~= "(" then
		addSearchEntry("Hyper Keys", item[2], "H-" .. item[1], item[3], item.front)
	end
end
local keysWidth, labelWidth = 0, 0
for _, entry in ipairs(searchEntries) do
	keysWidth = math.max(keysWidth, #entry.keys)
	labelWidth = math.max(labelWidth, utf8.len(entry.label))
end
-- Every line is padded to the widest row, so the alert keeps its width and position while typing.
local searchWidth = 2 + keysWidth + 2 + labelWidth
-- No fades: the alert is redrawn on every key press.
local SEARCH_STYLE = { textStyle = PROMPT_STYLE.textStyle, fadeInDuration = 0, fadeOutDuration = 0 }
local SEARCH_TEXT_STYLE = {
	font = { name = hs.alert.defaultStyle.textFont, size = hs.alert.defaultStyle.textSize },
	color = hs.alert.defaultStyle.textColor,
	paragraphStyle = PROMPT_STYLE.textStyle.paragraphStyle,
}
local SEARCH_MATCH_COLOR = { hex = "#97a3ff", alpha = 1 } -- more saturated than the border periwinkle so matches stand out from the off-white text
local SEARCH_CURSOR_STYLE = { -- inverted cell, like Alacritty's default block cursor
	color = { hex = "#0c0c16", alpha = 1 },
	backgroundColor = hs.alert.defaultStyle.textColor,
}
-- text: query chars; cursor: chars before it; killed: last killed text, for C-y.
local search = { query = "", text = {}, cursor = 0, killed = "", matches = {}, selected = 1, top = 1 }
local searchTap, searchAlert
local function chars(text)
	local list = {}
	for _, code in utf8.codes(text) do
		table.insert(list, utf8.char(code))
	end
	return list
end
-- Subsequence match, fzf-style: every query char must appear in order. Scores favour consecutive
-- chars and word starts and penalise gaps. Tries each start of the first query char and keeps the
-- best. Returns score and matched char positions, or nil.
local function fuzzyMatch(text, query, caseSensitive)
	local t, q = chars(caseSensitive and text or text:lower()), chars(caseSensitive and query or query:lower())
	if #q == 0 then
		return 0, {}
	end
	local best, bestPositions
	for start = 1, #t do
		if t[start] == q[1] then
			local positions, ti = { start }, start + 1
			for qi = 2, #q do
				while ti <= #t and t[ti] ~= q[qi] do
					ti = ti + 1
				end
				if ti > #t then
					positions = nil
					break
				end
				table.insert(positions, ti)
				ti = ti + 1
			end
			if not positions then
				break -- later starts can only match less
			end
			local score = 0
			for i, pos in ipairs(positions) do
				score = score + 1
				if pos == 1 or not t[pos - 1]:find("%w") then
					score = score + 3
				end
				if i > 1 then
					local gap = pos - positions[i - 1] - 1
					score = score + (gap == 0 and 5 or -0.2 * gap)
				end
			end
			if not best or score > best then
				best, bestPositions = score, positions
			end
		end
	end
	return best, bestPositions
end
local function searchFilter()
	local caseSensitive = search.query:find("%u") ~= nil -- smartcase
	search.matches = {}
	local bestScore
	for _, entry in ipairs(searchEntries) do
		local labelScore, labelPositions = fuzzyMatch(entry.label, search.query, caseSensitive)
		local keysScore, keysPositions = fuzzyMatch(entry.keys, search.query, caseSensitive)
		if labelScore or keysScore then
			local match = { entry = entry }
			if keysScore and (not labelScore or keysScore > labelScore) then
				match.score, match.keysPositions = keysScore, keysPositions
			else
				match.score, match.labelPositions = labelScore, labelPositions
			end
			table.insert(search.matches, match)
			if not bestScore or match.score > bestScore then
				bestScore, search.selected = match.score, #search.matches
			end
		end
	end
	search.selected = bestScore and search.selected or 1
	search.top = 1
end
local function searchRender()
	local lineHeight = hs.drawing.getTextDrawingSize("x", {
		font = hs.alert.defaultStyle.textFont,
		size = hs.alert.defaultStyle.textSize,
	}).h
	-- Rows that fit on screen, less the title and query (3 lines), a blank and header per group
	-- (6 lines) and 2 lines of padding.
	local fit = math.max(1, math.floor(hs.screen.mainScreen():frame().h / lineHeight) - 11)
	local n = #search.matches
	if n > fit then
		fit = fit - 1 -- room for the position line
	end
	search.top = math.min(search.top, search.selected)
	search.top = math.max(search.top, search.selected - fit + 1)
	local last = math.min(n, search.top + fit - 1)
	local lines = { "Search", "", search.query .. " " } -- trailing space holds the cursor at the end
	local highlights = {} -- { line, char column, style }
	local cursor = { 3, search.cursor + 1, SEARCH_CURSOR_STYLE }
	local group
	for i = search.top, last do
		local match = search.matches[i]
		local entry = match.entry
		if entry.group ~= group then -- a header above each group, titled like its hint
			group = entry.group
			table.insert(lines, "")
			table.insert(lines, group)
		end
		local mark = i == search.selected and ">" or " "
		table.insert(lines, string.format("%s %-" .. keysWidth .. "s  %s", mark, entry.keys, entry.label))
		for _, pos in ipairs(match.keysPositions or {}) do
			table.insert(highlights, { #lines, 2 + pos })
		end
		for _, pos in ipairs(match.labelPositions or {}) do
			table.insert(highlights, { #lines, 2 + keysWidth + 2 + pos })
		end
	end
	if n == 0 then
		table.insert(lines, "")
		table.insert(lines, "  —")
	elseif n > fit then
		table.insert(lines, string.format("  %d-%d of %d", search.top, last, n))
	end
	local lineStart, offset = {}, 0 -- char offset of each line in the joined text
	for i, line in ipairs(lines) do
		lines[i] = line .. string.rep(" ", searchWidth - utf8.len(line))
		lineStart[i] = offset
		offset = offset + utf8.len(lines[i]) + 1
	end
	local text = hs.styledtext.new(table.concat(lines, "\n"), SEARCH_TEXT_STYLE)
	table.insert(highlights, cursor)
	for _, h in ipairs(highlights) do
		local at = lineStart[h[1]] + h[2]
		text = text:setStyle(h[3] or { color = SEARCH_MATCH_COLOR }, at, at)
	end
	if searchAlert then
		hs.alert.closeSpecific(searchAlert, 0)
	end
	searchAlert = hs.alert.show(text, SEARCH_STYLE, hs.screen.mainScreen(), true)
end
local function searchClose()
	searchTap:stop()
	if searchAlert then
		hs.alert.closeSpecific(searchAlert, 0)
		searchAlert = nil
	end
end
local function isWordChar(c)
	return c:find("^%w") ~= nil
end
-- Cursor positions after word motions, Emacs style: skip separators, then the word.
local function wordForward(t, i)
	while i < #t and not isWordChar(t[i + 1]) do
		i = i + 1
	end
	while i < #t and isWordChar(t[i + 1]) do
		i = i + 1
	end
	return i
end
local function wordBackward(t, i)
	while i > 0 and not isWordChar(t[i]) do
		i = i - 1
	end
	while i > 0 and isWordChar(t[i]) do
		i = i - 1
	end
	return i
end
local function spaceWordBackward(t, i) -- C-w: back to the previous whitespace, like readline
	while i > 0 and t[i]:find("^%s") do
		i = i - 1
	end
	while i > 0 and not t[i]:find("^%s") do
		i = i - 1
	end
	return i
end
-- Readline-style editing of state.text/cursor/killed (search and the : prompt). Returns "text" if the query changed, "cursor" if only the cursor moved,
-- nil if the key isn't an editing key.
--   C-a/Home, C-e/End     start, end          C-f/Right, C-b/Left   char forward, back
--   M-f, M-b              word forward, back  DEL/C-h, C-d/Fwd Del  delete char back, forward
--   M-DEL, C-w            kill word back      M-d                   kill word forward
--   C-k, C-u              kill to end, start  C-y                   yank last kill
--   s-v                   paste the clipboard as one line
local function lineEdit(state, event, key, flags)
	local t, c = state.text, state.cursor
	local ctrl = flags.ctrl and not (flags.cmd or flags.alt)
	local meta = flags.alt and not (flags.cmd or flags.ctrl)
	local plain = not (flags.cmd or flags.ctrl or flags.alt)
	local cmdOnly = flags.cmd and not (flags.ctrl or flags.alt)
	local function remove(from, to, keep) -- chars from+1..to
		if to <= from then
			return "cursor"
		end
		if keep then
			state.killed = table.concat(t, "", from + 1, to)
		end
		for _ = from + 1, to do
			table.remove(t, from + 1)
		end
		state.cursor = from
		return "text"
	end
	local function insert(str)
		for _, code in utf8.codes(str) do
			state.cursor = state.cursor + 1
			table.insert(t, state.cursor, utf8.char(code))
		end
		return str ~= "" and "text" or "cursor"
	end
	if (ctrl and key == "a") or (plain and key == "home") then
		state.cursor = 0
	elseif (ctrl and key == "e") or (plain and key == "end") then
		state.cursor = #t
	elseif (ctrl and key == "f") or (plain and key == "right") then
		state.cursor = math.min(#t, c + 1)
	elseif (ctrl and key == "b") or (plain and key == "left") then
		state.cursor = math.max(0, c - 1)
	elseif meta and key == "f" then
		state.cursor = wordForward(t, c)
	elseif meta and key == "b" then
		state.cursor = wordBackward(t, c)
	elseif (plain and key == "delete") or (ctrl and key == "h") then
		return remove(math.max(0, c - 1), c)
	elseif (plain and key == "forwarddelete") or (ctrl and key == "d") then
		return remove(c, math.min(#t, c + 1))
	elseif meta and key == "delete" then
		return remove(wordBackward(t, c), c, true)
	elseif ctrl and key == "w" then
		return remove(spaceWordBackward(t, c), c, true)
	elseif meta and key == "d" then
		return remove(c, wordForward(t, c), true)
	elseif ctrl and key == "k" then
		return remove(c, #t, true)
	elseif ctrl and key == "u" then
		return remove(0, c, true)
	elseif ctrl and key == "y" then
		return insert(state.killed)
	elseif cmdOnly and key == "v" then
		-- one line: newlines and tabs become spaces, other control chars are dropped
		local clip = (hs.pasteboard.getContents() or ""):gsub("[\r\n\t]+", " "):gsub("%c", "")
		return insert(clip)
	elseif plain then
		local typed = event:getCharacters()
		if typed == "" or typed:find("%c") then
			return nil
		end
		return insert(typed)
	else
		return nil
	end
	return "cursor"
end
searchTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
	local key, flags = hs.keycodes.map[event:getKeyCode()], event:getFlags()
	local ctrlOnly = flags.ctrl and not (flags.cmd or flags.alt)
	local down = key == "down" or (ctrlOnly and key == "n")
	local up = key == "up" or (ctrlOnly and key == "p")
	local move = down and 1 or up and -1
	if key == "escape" then
		searchClose()
	elseif key == "return" or key == "padenter" then
		local match = search.matches[search.selected]
		searchClose()
		if match then
			hs.timer.doAfter(0, match.entry.run) -- outside the tap callback
		end
	elseif move then
		if #search.matches > 0 then -- wraps past either end
			search.selected = (search.selected - 1 + move) % #search.matches + 1
		end
		searchRender()
	else
		local edit = lineEdit(search, event, key, flags)
		if edit == "text" then
			search.query = table.concat(search.text)
			searchFilter()
		end
		if edit then
			searchRender()
		end
	end
	return true -- every key press stays out of the front app while searching
end)
searchAll = function()
	search.query, search.text, search.cursor = "", {}, 0
	searchFilter()
	searchTap:start()
	searchRender()
end

--- Command mode (H-z/;) ---
-- A vim-style : prompt drawn like search. Enter runs the command, Esc cancels, and editing is
-- the same as in search (lineEdit). An error shows under the prompt and keeps the text.
--   ct <duration> [-m label] [-e end message]   ct 30m -m DSA, ct 1h 30m, ct 90s, ct 5 (minutes)
--   ct -t <HHMM|HHMMSS> [-m label] [-e msg]     until a clock time, tomorrow if already past
--   q [all | <n> | <label>]                     cancel or dismiss timers (see below)
-- ct ports ~/scripts/countdown.zsh. Each ct adds a timer; several can run at once. They show left
-- of the clock in end-time order, soonest nearest the clock (that one is n = 0). At zero a timer's
-- end message replaces it and Hero repeats until it is dismissed. Bare q dismisses every ended
-- timer; with none ended, it cancels the only timer, and with several it asks for all, n or a label.
-- Quote multi-word values: ct 30m -m "Deep work". Timers persist via hs.settings across reloads.
local CT_GAP = 0 -- px between ct slots and the clock: flush, separate panels
local cts = hs.settings.get("cts") or {} -- { { endTime, label, endMsg }, ... } sorted by endTime
if hs.settings.get("ct") then -- migrate the single-timer setting
	table.insert(cts, hs.settings.get("ct"))
	hs.settings.clear("ct")
	hs.settings.set("cts", cts)
end
table.sort(cts, function(a, b)
	return a.endTime < b.endTime
end)
local ctHidden = hs.settings.get("ctHidden") or false -- display only; the alarm still rings
local ctCanvases, ctWidths = {}, {} -- keyed by timer table; runtime only
local ctTimer, ctAlarm
local ctSound = hs.sound.getByFile("/System/Library/Sounds/Hero.aiff")

local function ctText(t, now)
	local left = t.endTime - now
	if left <= 0 then
		return t.endMsg
	end
	local h, m, s = left // 3600, left % 3600 // 60, left % 60
	local text = h > 0 and string.format("%d:%02d:%02d", h, m, s) or string.format("%02d:%02d", m, s)
	return t.label and (t.label .. " " .. text) or text
end

-- While counting, a slot's width only grows (the first, widest reading sets it), so it stays put
-- as digits and the h: field drop away. At zero it fits the end message.
local function ctSize(t, text, ended)
	local size = hs.drawing.getTextDrawingSize(text, { font = clockFont, size = clockSize })
	local w, h = math.ceil(size.w) + 2 * CLOCK_PAD_X, math.ceil(size.h) + 2 * CLOCK_PAD_Y
	if not ended then
		ctWidths[t] = math.max(ctWidths[t] or 0, w)
		w = ctWidths[t]
	end
	return w, h
end

local function ctStopAlarm()
	if ctAlarm then
		ctAlarm:stop()
		ctAlarm = nil
	end
	ctSound:stop()
end

local function ctStartAlarm()
	if ctAlarm then
		return
	end
	local function ring()
		ctSound:stop()
		ctSound:play()
	end
	ring()
	ctAlarm = hs.timer.doEvery(ctSound:duration() + 0.5, ring) -- like the script's afplay; sleep 0.5
end

local function ctDeleteCanvas(t)
	if ctCanvases[t] then
		ctCanvases[t]:delete()
		ctCanvases[t] = nil
	end
end

-- Recomputed from the wall clock each tick, so it stays right across sleep.
updateCt = function()
	local now, anyEnded = os.time(), false
	local right, y
	if clockCanvas then
		local c = clockCanvas:frame()
		right, y = c.x - CT_GAP, c.y
	else
		local f = hs.screen.mainScreen():frame()
		right, y = f.x + f.w - CLOCK_INSET, f.y + CLOCK_INSET
	end
	for _, t in ipairs(cts) do
		local text, ended = ctText(t, now), t.endTime <= now
		anyEnded = anyEnded or ended
		if ctHidden then
			ctDeleteCanvas(t)
		else
			local w, h = ctSize(t, text, ended)
			local frame = { x = right - w, y = y, w = w, h = h }
			right = frame.x - CT_GAP
			local canvas = ctCanvases[t]
			if not canvas then
				canvas = newOverlay(frame)
				canvas[2].textAlignment = "left" -- digits drop away on the right, not both sides
				canvas[2].frame = { x = CLOCK_PAD_X, y = CLOCK_PAD_Y, w = "100%", h = "100%" }
				canvas:show()
				ctCanvases[t] = canvas
			end
			canvas:frame(frame)
			canvas[2].text = text
		end
	end
	if anyEnded then
		ctStartAlarm()
	elseif ctAlarm then
		ctStopAlarm()
	end
end

local function ctSave()
	if #cts > 0 then
		hs.settings.set("cts", cts)
	else
		hs.settings.clear("cts")
	end
end

local function ctStart()
	if not ctTimer then
		ctTimer = hs.timer.doEvery(1, updateCt)
	end
	updateCt()
end

-- Removes the timers for which remove(t, i) is true (i = 1 is nearest the clock; q shows it as 0).
local function ctRemove(remove)
	local kept = {}
	for i, t in ipairs(cts) do
		if remove(t, i) then
			ctDeleteCanvas(t)
			ctWidths[t] = nil
		else
			table.insert(kept, t)
		end
	end
	cts = kept
	ctSave()
	if #cts == 0 and ctTimer then
		ctTimer:stop()
		ctTimer = nil
	end
	updateCt()
end

toggleCt = function()
	ctHidden = not ctHidden
	hs.settings.set("ctHidden", ctHidden)
	updateCt()
	hs.alert.show("Countdown " .. (ctHidden and "hidden" or "shown"), 1)
end

local function ctAdd(state)
	table.insert(cts, state)
	table.sort(cts, function(a, b)
		return a.endTime < b.endTime
	end)
	ctSave()
	ctStart()
end

-- Returns { endTime, label, endMsg }, or nil and an error message.
local function ctParse(args)
	local label, endMsg, target, durations = nil, "Countdown complete!", nil, {}
	local i = 1
	while i <= #args do
		local a = args[i]
		local opt = ({ ["-m"] = "m", ["--message"] = "m", ["-e"] = "e", ["--end"] = "e", ["-t"] = "t", ["--time"] = "t" })[a]
		if opt then
			local v = args[i + 1]
			if not v then
				return nil, a .. " needs a value"
			end
			if opt == "m" then
				label = v
			elseif opt == "e" then
				endMsg = v
			else
				target = v
			end
			i = i + 2
		else
			table.insert(durations, a)
			i = i + 1
		end
	end
	if #durations == 0 and not target then
		return nil, "Usage: ct <time> [-m label] [-e end message]  |  ct -t <HHMM|HHMMSS> ..."
	end
	if target and #durations > 0 then
		return nil, "Use either a duration or -t, not both."
	end
	local now, endTime = os.time(), nil
	if target then
		local h, m, s = target:match("^(%d%d)(%d%d)(%d?%d?)$")
		if not h or #s == 1 then
			return nil, "Invalid target time '" .. target .. "'. Use HHMM or HHMMSS, e.g. 1100 or 110030."
		end
		h, m, s = tonumber(h), tonumber(m), tonumber(s) or 0
		if h > 23 or m > 59 or s > 59 then
			return nil, "Invalid target time '" .. target .. "'."
		end
		local d = os.date("*t", now)
		d.hour, d.min, d.sec, d.isdst = h, m, s, nil
		endTime = os.time(d)
		if endTime <= now then -- already passed today: tomorrow (os.time normalizes day + 1)
			d.day = d.day + 1
			endTime = os.time(d)
		end
	else
		local total = 0
		for _, a in ipairs(durations) do
			local n, unit = a:match("^(%d+)([hms]?)$")
			if not n then
				return nil, "Invalid time '" .. a .. "'. Use e.g. 1h 30m 45s or 5 (minutes)."
			end
			total = total + tonumber(n) * ({ h = 3600, m = 60, s = 1, [""] = 60 })[unit]
		end
		if total <= 0 then
			return nil, "Time must be > 0."
		end
		endTime = now + total
	end
	return { endTime = endTime, label = label, endMsg = endMsg }
end

-- Whitespace-separated words; "double" or 'single' quotes group words.
local function tokenize(line)
	local tokens, i = {}, 1
	while true do
		i = select(2, line:find("^%s*", i)) + 1
		if i > #line then
			return tokens
		end
		local q = line:sub(i, i)
		if q == '"' or q == "'" then
			local close = line:find(q, i + 1, true)
			if not close then
				return nil, "Unclosed quote"
			end
			table.insert(tokens, line:sub(i + 1, close - 1))
			i = close + 1
		else
			local e = select(2, line:find("^%S+", i))
			table.insert(tokens, line:sub(i, e))
			i = e + 1
		end
	end
end

-- Each command validates its args and returns the action to run, or nil and an error.
local commands = {
	ct = function(args)
		local state, err = ctParse(args)
		if not state then
			return nil, err
		end
		return function()
			ctAdd(state)
			local fmt = os.date("%S", state.endTime) == "00" and "%H%M" or "%H%M%S"
			hs.alert.show((state.label or "Timer") .. " until " .. os.date(fmt, state.endTime), 2)
		end
	end,
	q = function(args)
		local target = table.concat(args, " ")
		local now, ended = os.time(), 0
		for _, t in ipairs(cts) do
			if t.endTime <= now then
				ended = ended + 1
			end
		end
		local remove
		if #cts == 0 then
			return function() end
		elseif target == "" and ended > 0 then
			remove = function(t)
				return t.endTime <= os.time()
			end
		elseif target == "all" or (target == "" and #cts == 1) then
			remove = function()
				return true
			end
		elseif target == "" then
			return nil, #cts .. " timers: q all, q <n> (0 = nearest the clock) or q <label>"
		elseif target:match("^%d+$") then
			local n = tonumber(target)
			if n > #cts - 1 then
				return nil, "No timer " .. n .. " (0-" .. #cts - 1 .. ")"
			end
			remove = function(_, i)
				return i == n + 1
			end
		else
			local want, found = target:lower(), false
			for _, t in ipairs(cts) do
				found = found or (t.label and t.label:lower() == want)
			end
			if not found then
				return nil, "No timer labeled '" .. target .. "'"
			end
			remove = function(t)
				return t.label and t.label:lower() == want
			end
		end
		return function()
			ctRemove(remove)
		end
	end,
}

local cmd = { text = {}, cursor = 0, killed = "", error = nil }
local cmdTap, cmdAlert
local CMD_MIN_WIDTH = 40 -- chars; keeps the prompt from jumping in width while typing
local function cmdRender()
	local lines = { ":" .. table.concat(cmd.text) .. " " } -- trailing space holds the cursor at the end
	if cmd.error then
		table.insert(lines, "")
		table.insert(lines, cmd.error)
	end
	local width = CMD_MIN_WIDTH
	for _, line in ipairs(lines) do
		width = math.max(width, utf8.len(line))
	end
	for i, line in ipairs(lines) do
		lines[i] = line .. string.rep(" ", width - utf8.len(line))
	end
	local text = hs.styledtext.new(table.concat(lines, "\n"), SEARCH_TEXT_STYLE)
	text = text:setStyle(SEARCH_CURSOR_STYLE, cmd.cursor + 2, cmd.cursor + 2) -- +1 for ":", +1 for 1-based
	if cmdAlert then
		hs.alert.closeSpecific(cmdAlert, 0)
	end
	cmdAlert = hs.alert.show(text, SEARCH_STYLE, hs.screen.mainScreen(), true)
end
local function cmdClose()
	cmdTap:stop()
	if cmdAlert then
		hs.alert.closeSpecific(cmdAlert, 0)
		cmdAlert = nil
	end
end
cmdTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
	local key, flags = hs.keycodes.map[event:getKeyCode()], event:getFlags()
	if key == "escape" then
		cmdClose()
	elseif key == "return" or key == "padenter" then
		local tokens, err = tokenize(table.concat(cmd.text))
		local action
		if tokens and #tokens == 0 then
			cmdClose()
			return true
		elseif tokens then
			local name = table.remove(tokens, 1)
			if commands[name] then
				action, err = commands[name](tokens)
			else
				err = "Not a command: " .. name
			end
		end
		if action then
			cmdClose()
			hs.timer.doAfter(0, action) -- outside the tap callback
		else
			cmd.error = err
			cmdRender()
		end
	else
		local edit = lineEdit(cmd, event, key, flags)
		if edit == "text" then
			cmd.error = nil
		end
		if edit then
			cmdRender()
		end
	end
	return true -- every key press stays out of the front app while the prompt is open
end)
commandMode = function()
	cmd.text, cmd.cursor, cmd.error = {}, 0, nil
	hs.alert.closeAll()
	cmdTap:start()
	cmdRender()
end
hs.hotkey.bind(hyper, ";", commandMode) -- H-z is bound with the Hyper keys above

if #cts > 0 then -- restore timers that were running before a reload
	ctStart()
end

--- Firefox Quit, Raindrop Save Tabs Warning ---
local function frontmostAppName()
	local app = hs.application.frontmostApplication()
	return app and app:name() or ""
end
local confirmFirefoxQuit = confirmPrompt(
	"Quit Firefox (s-q)",
	"Session/tabs saved in Surfingkeys/Raindrop as needed?",
	function()
		local fx = hs.application.get("Firefox")
		if fx then
			fx:selectMenuItem({ "Firefox", "Quit Firefox" })
		end
	end
)
---@diagnostic disable-next-line: lowercase-global
cmdQTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(e)
	local flags = e:getFlags()
	local isCmdOnly = flags.cmd and not flags.alt and not flags.ctrl and not flags.shift
	local isQ = (e:getKeyCode() == hs.keycodes.map["q"])
	if not (isCmdOnly and isQ) then
		return false
	end
	if frontmostAppName() ~= "Firefox" then
		return false
	end
	confirmFirefoxQuit()
	return true
end)
cmdQTap:start()

--- Window Management ---
-- lmr
-- halves: left half: o; middle half: e/t; right half: n
-- thirds: left third: j; middle third: k/m; right third: w
-- fourths: ,rqv
local ca = { "ctrl", "alt" }
-- Helper function to move and resize windows
local function moveAndResize(xRatio, yRatio, wRatio, hRatio)
	local win = hs.window.focusedWindow()
	if not win then
		return
	end
	local f = win:frame()
	local screen = win:screen()
	local max = screen:frame()
	f.x = max.x + (max.w * xRatio)
	f.y = max.y + (max.h * yRatio)
	f.w = max.w * wRatio
	f.h = max.h * hRatio
	win:setFrameInScreenBounds(f, 0)
end
hs.hotkey.bind(ca, "return", function()
	moveAndResize(0, 0, 1, 1)
end) -- Maximized
hs.hotkey.bind({ "ctrl", "alt", "shift" }, "return", function()
	moveAndResize(0.05, 0.05, 0.9, 0.9)
end) -- Almost maximized

--- Vertical Halves ---
hs.hotkey.bind(ca, "o", function()
	moveAndResize(0, 0, 0.5, 1)
end) -- Left half
hs.hotkey.bind(ca, "e", function()
	moveAndResize(0.25, 0, 0.5, 1)
end) -- Center half
hs.hotkey.bind(ca, "t", function()
	moveAndResize(0.25, 0, 0.5, 1)
end) -- Center half (same as "e")
hs.hotkey.bind(ca, "n", function()
	moveAndResize(0.5, 0, 0.5, 1)
end) -- Right half

--- Horizontal Halves ---
hs.hotkey.bind(ca, "y", function()
	moveAndResize(0, 0, 1, 0.5)
end) -- Top half
hs.hotkey.bind(ca, "f", function()
	moveAndResize(0.5, 0.5, 1, 0.5)
end) -- Bottom half

--- Fourths - Corners ---
hs.hotkey.bind(ca, ",", function()
	moveAndResize(0, 0, 0.5, 0.5)
end) -- Top left
hs.hotkey.bind(ca, "r", function()
	moveAndResize(0.5, 0, 0.5, 0.5)
end) -- Top right
hs.hotkey.bind(ca, "v", function()
	moveAndResize(0.5, 0.5, 0.5, 0.5)
end) -- Bottom right
hs.hotkey.bind(ca, "q", function()
	moveAndResize(0, 0.5, 0.5, 0.5)
end) -- Bottom left

--- Fourths - Centered ---
hs.hotkey.bind(ca, ".", function()
	moveAndResize(0.25, 0, 0.5, 0.5)
end) -- Top middle fourth
hs.hotkey.bind(ca, "c", function()
	moveAndResize(0.25, 0, 0.5, 0.5)
end) -- Top middle fourth (same as ".")
hs.hotkey.bind(ca, "p", function()
	moveAndResize(0.25, 0.25, 0.5, 0.5)
end) -- Center fourth
hs.hotkey.bind(ca, "g", function()
	moveAndResize(0.25, 0.25, 0.5, 0.5)
end) -- Center fourth (same as "p")

--- Vertical Thirds ---
hs.hotkey.bind(ca, "j", function()
	moveAndResize(0, 0, 1 / 3, 1)
end) -- Left third
hs.hotkey.bind(ca, "k", function()
	moveAndResize(1 / 3, 0, 1 / 3, 1)
end) -- Middle third
hs.hotkey.bind(ca, "m", function()
	moveAndResize(1 / 3, 0, 1 / 3, 1)
end) -- Middle third (same as "k")
hs.hotkey.bind(ca, "w", function()
	moveAndResize(2 / 3, 0, 1 / 3, 1)
end) -- Right third

--- Vertical Two-thirds ---
hs.hotkey.bind(ca, "x", function()
	moveAndResize(0, 0, 2 / 3, 1)
end) -- Left two-thirds
hs.hotkey.bind(ca, "i", function()
	moveAndResize(1 / 6, 0, 2 / 3, 1)
end) -- Middle two-thirds
hs.hotkey.bind(ca, "d", function()
	moveAndResize(1 / 6, 0, 2 / 3, 1)
end) -- Middle two-thirds (same as "i")
hs.hotkey.bind(ca, "b", function()
	moveAndResize(1 / 3, 0, 2 / 3, 1)
end) -- Right two-thirds

--- Vertical Thirds with Horizontal Halves ---
hs.hotkey.bind(ca, "'", function()
	moveAndResize(0, 0, 1 / 3, 1 / 2)
end) -- Left upper third
hs.hotkey.bind(ca, "a", function()
	moveAndResize(1 / 3, 0, 1 / 3, 1 / 2)
end) -- Middle upper third
hs.hotkey.bind(ca, "s", function()
	moveAndResize(1 / 3, 1 / 2, 1 / 3, 1 / 2)
end) -- Middle lower third
hs.hotkey.bind(ca, "l", function()
	moveAndResize(2 / 3, 0, 1 / 3, 1 / 2)
end) -- Right upper third
hs.hotkey.bind(ca, ";", function()
	moveAndResize(0, 1 / 2, 1 / 3, 1 / 2)
end) -- Left lower third
hs.hotkey.bind(ca, "z", function()
	moveAndResize(2 / 3, 1 / 2, 1 / 3, 1 / 2)
end) -- Right lower third
