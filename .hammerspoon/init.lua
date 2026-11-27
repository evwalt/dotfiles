-- Lets the `hs` CLI run Lua here (scripts/claude-pane-notify shows alerts through it).
require("hs.ipc")

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
hs.alert.defaultStyle.strokeColor = { hex = "#c0c6d6", alpha = 0.15 }
hs.alert.defaultStyle.fillColor = { hex = "#0c0c16", alpha = 0.9 } -- more opaque than the clock: alerts carry more text
hs.alert.defaultStyle.textColor = { hex = "#c0c6d6", alpha = 0.95 }
hs.alert.defaultStyle.atScreenEdge = 1 -- all alerts: top of screen, centered horizontally
hs.alert.defaultStyle.textFont = "Hack Nerd Font" -- all alerts: same font and size as the prompts
hs.alert.defaultStyle.textSize = 17
-- hs.alert has no offset option for atScreenEdge = 1, so nudge each alert's drawings down after
-- it is shown. Covers prompts and search pickers, which are all alerts.
local ALERT_TOP_OFFSET = 20
local alertShow = hs.alert.show
hs.alert.show = function(...)
	local uuid = alertShow(...)
	for _, entry in ipairs(hs.alert._visibleAlerts) do
		if entry.UUID == uuid then
			for _, d in ipairs(entry.drawings) do
				local f = d:frame()
				d:setTopLeft({ x = f.x, y = f.y + ALERT_TOP_OFFSET })
			end
			entry.frame.y = entry.frame.y + ALERT_TOP_OFFSET
		end
	end
	return uuid
end
print(os.getenv("HOME") .. "/.hammerspoon/")

--- Multi-action Keys ---
local hyper = { "ctrl", "alt", "cmd", "shift" }
--- Multi-action picker for a single hotkey ---
-- Usage: hs.hotkey.bind(hyper, "G", actionPicker("Title", { { "m", "Skim" }, { "w", "Label", fn } }))
-- Each item is { rightKey, appName } or { rightKey, label, action }. Every action is also bound
-- to the mirror key on the left hand (same finger and row, Dvorak), shown after a slash. The hint
-- lists every key in right-hand keyboard order, one block per row, free keys shown as "(free)".
-- Press the hyper combo, then a sub-key. Esc cancels. The hint stays up until either.
-- s/a opens a search over every picker and Hyper key (see searchAll). "space" and "delete"
-- (Backspace) are extra slots with no mirror, listed below the grid as SPC and DEL.
-- An item with `front = true` acts on the front app; from search it asks to confirm first.
-- An item with `status = fn` shows fn()'s text after its label in the hint, read each time it opens.
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
local FREE_LABEL = "(free)" -- unused slot, in the hints and in search
-- A label as pickers and search show it: with the item's current status, if it has one.
local function shownLabel(label, status)
	return status and string.format("%s [%s]", label, status()) or label
end
-- A label's words, lowercased, without parenthesized key notes or punctuation:
-- "Screenshot Window to ~/Downloads" -> screenshot window to downloads, "Quit App (s-q)" -> quit app.
local function labelWords(text)
	local words = {}
	for w in text:lower():gsub("%b()", ""):gmatch("%S+") do
		w = w:gsub("[^%w]", "")
		if w ~= "" then
			table.insert(words, w)
		end
	end
	return words
end
local function hintText(labels)
	local lines = {}
	for row, keys in ipairs(MIRROR_ROWS) do
		if row > 1 then
			table.insert(lines, "")
		end
		for col = 1, #keys[1] do
			local right = keys[1]:sub(col, col)
			table.insert(lines, string.format("%s/%s  %s", right, MIRROR[right], labels[right] or FREE_LABEL))
		end
	end
	return table.concat(lines, "\n")
end
local EXTRA_KEYS = { { "space", "SPC" }, { "delete", "DEL" } } -- unmirrored slots, hint name
local SEARCH_KEY = "s"
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
	local statuses = {} -- right key -> status fn
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
		statuses[key] = item.status
		bindRun(MIRROR[key] and { key, MIRROR[key] } or { key }, itemAction(label, item[3]))
	end
	bindRun({ SEARCH_KEY, MIRROR[SEARCH_KEY] }, function()
		searchAll()
	end)
	m:bind({}, "escape", function()
		hs.alert.closeAll()
		m:exit()
	end)
	local function hint()
		local shown = {}
		for key, label in pairs(labels) do
			shown[key] = shownLabel(label, statuses[key])
		end
		local extras = {}
		for _, extra in ipairs(EXTRA_KEYS) do
			table.insert(extras, string.format("%-5s%s", extra[2], shown[extra[1]] or FREE_LABEL))
		end
		return title .. "\n\n" .. hintText(shown) .. "\n\n" .. table.concat(extras, "\n")
	end
	function m:entered()
		hs.alert.closeAll()
		hs.alert.show(hint(), PROMPT_STYLE, hs.screen.mainScreen(), true) -- non-number duration: stays up until closed
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
	hs.alert.show("Firefox border " .. (borderEnabled and "shown" or "hidden"))
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
-- click-through, with optional YYYY-MM-DD date prefix. On/off is in the Hyper+G picker; date and
-- seconds are the date and secs commands in command mode.
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
		strokeColor = { hex = "#c0c6d6", alpha = 0.15 },
		strokeWidth = 1,
		roundedRectRadii = { xRadius = 8, yRadius = 8 },
	}, {
		type = "text",
		text = "",
		textFont = clockFont,
		textSize = clockSize,
		textColor = { hex = "#c0c6d6", alpha = 0.95 },
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

-- Cursor beacon: a fading block at the tmux cursor. If Alacritty is frontmost, run the
-- beacon script directly (it targets the active client). Otherwise arm tmux's one-shot
-- @beacon_once flag and focus Alacritty; its client-focus-in hook then runs the script.
local function cursorBeacon()
	local front = hs.application.frontmostApplication()
	if front and front:name() == "Alacritty" then
		hs.task.new(os.getenv("HOME") .. "/scripts/cursor-beacon-fire.sh", nil, {}):start()
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
	{ "r", "Cmd-Shift-L (s-S-l)", keyStroker({ "cmd", "shift" }, "l"), front = true },
	{ "l", "Notes" },
	{
		"d",
		"Screenshot Window to ~/Downloads",
		function()
			screenshotWindow(
				os.getenv("HOME") .. "/Downloads/Screenshot " .. os.date("%Y-%m-%d at %H.%M.%S") .. ".png"
			)
		end,
		front = true,
	},
	{ "h", "Handy" },
	{ "t", "Cursor Beacon", cursorBeacon, front = true },
	{ "n", "Spotify" },
	{ "b", "Cut (s-x)", keyStroker({ "cmd" }, "x"), front = true },
	{
		"w",
		"Toggle Clock",
		function()
			setClock(not clockOn)
		end,
		status = function()
			return clockOn and "shown" or "hidden"
		end,
	},
	{ "v", "Paste (s-v)", keyStroker({ "cmd" }, "v"), front = true },
	{
		"delete",
		"Toggle Countdown",
		function()
			toggleCt()
		end,
		status = function() -- ctHidden is defined further down; it is mirrored in settings
			return hs.settings.get("ctHidden") and "hidden" or "shown"
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
		status = function()
			return (hs.screen.getForceToGray()) and "on" or "off"
		end,
	},
	{ "r", "Skim" },
	{
		"delete",
		"Show Hyper Keys", -- reference view only; search (s) runs them
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
	{ "z", "Select All (s-a)", keyStroker({ "cmd" }, "a"), front = true }, -- provisional: s is search
	{ "n", "Sleep", confirmPrompt("Sleep (H-f n)", "Sleep the computer?", hs.caffeinate.systemSleep) },
	{ "b", "System Settings" },
}
hs.hotkey.bind(hyper, "F", actionPicker("Picker 2 (H-f)", picker2Items))
-- Top-level Hyper keys. Each is { key, label, action, front = bool }; no action launches the app named by
-- label. Labels in parens are handled outside Hammerspoon and only listed in the hint.
-- `status = fn` works as in pickers (shown in search; the Hyper hint is built once at load).
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
	{ "h", "(Enter)" }, -- h/t/n/w and mirrors u/e/o: keyboard firmware
	{ "t", "(Mouse Mode)" },
	{ "n", "(Arrows Mode)" },
	{ "w", "(Volume Mode)" },
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
	{ "j", "zoom.us" }, -- firmware sends H-j from the thumb + Backspace position
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
local hyperHint = "Hyper Keys (H-f DEL)\n\n" .. hintText(hyperLabels) .. "\n\n" .. table.concat(extraHints, "\n")
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

--- Search every picker item and Hyper key (s/a in a picker) ---
-- Drawn as an alert like the pickers, growing with the matches and scrolling only past the screen
-- bottom. While open, a key tap reads every key press and keeps it from the front app: type to
-- filter, C-n/Down and C-p/Up to move, Enter to run, Esc then Esc to cancel. The query edits in
-- vim modes, insert mode like a readline prompt (see vimEdit and lineEdit). A front-app item asks
-- to confirm first. Matching is fuzzy over the label and the keys (see fuzzyMatch), with smartcase.
-- Rows keep their table order; the best match is selected and matched chars are pink. A query
-- found as plain text in a group name ("picker 1", "hyper") also lists that whole group, ranked
-- below label and key matches.
-- Command Mode group, first in search and in command mode's Tab list. Named commands take args:
-- Enter on one opens (or stays in) command mode with fill typed in. The toggles are picker-style
-- items ({ key, label, action, status }) without a key, run by typing their label.
local namedCommands = {
	{ name = "ct", label = "ct <time> [-m label] [-e end message]", fill = "ct " },
	{ name = "ct -t", label = "ct -t <HHMM|HHMMSS> [-m label] [-e msg]", fill = "ct -t " },
	{ name = "q ct", label = "q ct [all | <n> | <label>]", fill = "q ct " },
}
local commandItems = {
	{
		nil,
		"Toggle Clock Date",
		toggleClockDate,
		status = function()
			return clockDate and "shown" or "hidden"
		end,
	},
	{
		nil,
		"Toggle Clock Seconds",
		toggleClockSecs,
		status = function()
			return clockSecs and "shown" or "hidden"
		end,
	},
	{
		nil,
		"Toggle Firefox Border",
		toggleBorder,
		status = function()
			return borderEnabled and "shown" or "hidden"
		end,
	},
}
local searchEntries = {} -- { group, label, keys, run }
-- Rows are sorted like the hints (see sortSearchEntries): grid keys in Dvorak order, then extras,
-- with free slots in place.
local KEY_SLOT = {} -- key -> position in the hint
for _, row in ipairs(MIRROR_ROWS) do
	for col = 1, #row[1] do
		table.insert(KEY_SLOT, row[1]:sub(col, col))
		KEY_SLOT[row[1]:sub(col, col)] = #KEY_SLOT
	end
end
for _, extra in ipairs(EXTRA_KEYS) do
	table.insert(KEY_SLOT, extra[1])
	KEY_SLOT[extra[1]] = #KEY_SLOT
end
-- opts: front (confirm first), shortKeys (keys in the confirm title), key (hint slot), status,
-- name and fill (a named command). Command mode lists these same entries (see cmdList); it runs
-- `direct`, the action without the front-app confirm, when the label is typed in full.
local function addSearchEntry(group, label, keys, action, opts)
	opts = opts or {}
	local direct = itemAction(label, action)
	local run = direct
	if opts.front then
		run = confirmPrompt(label .. " (" .. (opts.shortKeys or keys) .. ")", "Run in the front app?", run)
	end
	table.insert(searchEntries, {
		group = group,
		label = label,
		shown = label, -- label plus status, refreshed each time search opens
		keys = keys,
		run = run,
		direct = direct,
		front = opts.front,
		words = table.concat(labelWords(label), " "), -- how command mode reads a typed label
		name = opts.name,
		fill = opts.fill,
		key = opts.key,
		status = opts.status,
	})
end
for _, command in ipairs(namedCommands) do
	addSearchEntry("Command Mode", command.label, ":" .. command.name, function()
		commandMode(command.fill)
	end, { name = command.name, fill = command.fill })
end
for _, item in ipairs(commandItems) do
	addSearchEntry("Command Mode", item[2], ":", item[3], { status = item.status })
end
-- Unused slots are listed as FREE_LABEL, so searching "free" shows every open key. Enter on one
-- just names it.
local function addFreeEntries(group, prefix, used, withExtras)
	local function add(keys, key)
		addSearchEntry(group, FREE_LABEL, keys, function()
			hs.alert.show(keys .. " is free", PROMPT_STYLE)
		end, { key = key })
	end
	for _, row in ipairs(MIRROR_ROWS) do
		for col = 1, #row[1] do
			local right = row[1]:sub(col, col)
			if not used[right] then
				add(prefix .. right .. "/" .. MIRROR[right], right)
			end
		end
	end
	if withExtras then
		for _, extra in ipairs(EXTRA_KEYS) do
			if not used[extra[1]] then
				add(prefix .. extra[2], extra[1])
			end
		end
	end
end
-- A picker item's keys as hints and search show them: "H-f h/u", "H-g DEL". Also returns the short
-- form without the mirror, for confirm titles like "Shut Down (H-f h)".
local PICKERS = { { "H-g", picker1Items, "Picker 1 (H-g)" }, { "H-f", picker2Items, "Picker 2 (H-f)" } }
local function pickerKeys(prefix, key)
	local keyName = key
	for _, extra in ipairs(EXTRA_KEYS) do
		if extra[1] == key then
			keyName = extra[2]
		end
	end
	local shortKeys = prefix .. " " .. keyName
	return MIRROR[key] and string.format("%s/%s", shortKeys, MIRROR[key]) or shortKeys, shortKeys
end
for _, picker in ipairs(PICKERS) do
	for _, item in ipairs(picker[2]) do
		local key = item[1]
		local keys, shortKeys = pickerKeys(picker[1], key)
		addSearchEntry(picker[3], item[2], keys, item[3], {
			front = item.front,
			shortKeys = shortKeys,
			key = key,
			status = item.status,
		})
	end
	local used = { [SEARCH_KEY] = true }
	for _, item in ipairs(picker[2]) do
		used[item[1]] = true
	end
	addFreeEntries(picker[3], picker[1] .. " ", used, true)
end
for _, item in ipairs(hyperKeys) do
	local action = item[3]
	if item[2]:sub(1, 1) == "(" then
		-- Handled outside Hammerspoon (firmware, Homerow), so listed for reference: Enter just names the chord.
		action = function()
			hs.alert.show(item[2]:sub(2, -2) .. ": press H-" .. item[1], PROMPT_STYLE)
		end
	end
	addSearchEntry("Hyper Keys", item[2], "H-" .. item[1], action, {
		front = item.front,
		key = item[1],
		status = item.status,
	})
end
addFreeEntries("Hyper Keys", "H-", hyperLabels, false)
do -- stable sort: group order as added, then hint slot (unslotted keys last, in table order)
	local groupOrder = {}
	for i, entry in ipairs(searchEntries) do
		groupOrder[entry.group] = groupOrder[entry.group] or i
		entry.index = i
	end
	table.sort(searchEntries, function(a, b)
		if a.group ~= b.group then
			return groupOrder[a.group] < groupOrder[b.group]
		end
		local sa, sb = KEY_SLOT[a.key] or math.huge, KEY_SLOT[b.key] or math.huge
		if sa ~= sb then
			return sa < sb
		end
		return a.index < b.index
	end)
	for i, entry in ipairs(searchEntries) do -- list order, for command mode's ranking ties
		entry.order = i
	end
end
local keysWidth, searchWidth
-- Every line is padded to the widest row, so the alert keeps its width and position while typing.
local function refreshSearchLabels()
	local labelWidth = 0
	keysWidth = 0
	for _, entry in ipairs(searchEntries) do
		entry.shown = shownLabel(entry.label, entry.status)
		keysWidth = math.max(keysWidth, #entry.keys)
		labelWidth = math.max(labelWidth, utf8.len(entry.shown))
	end
	searchWidth = 2 + keysWidth + 2 + labelWidth
end
-- No fades: the alert is redrawn on every key press.
local SEARCH_STYLE = { textStyle = PROMPT_STYLE.textStyle, fadeInDuration = 0, fadeOutDuration = 0 }
local SEARCH_TEXT_STYLE = {
	font = { name = hs.alert.defaultStyle.textFont, size = hs.alert.defaultStyle.textSize },
	color = hs.alert.defaultStyle.textColor,
	paragraphStyle = PROMPT_STYLE.textStyle.paragraphStyle,
}
local SEARCH_MATCH_COLOR = { hex = "#97a3ff", alpha = 1 } -- more saturated than the border periwinkle so matches stand out from the off-white text
-- Dimmed text: the scroll position line ("1-48 of 53"), secondary to the rows.
local DIM_STYLE = { color = { hex = "#c0c6d6", alpha = 0.7 } }
-- The selected row's background: the border periwinkle, faint, so the row stands out without
-- hiding the match colors.
local SELECTED_STYLE = { backgroundColor = { hex = "#b1b9f9", alpha = 0.18 } }
-- Styles a whole line of a joined alert text (lineStart: each line's byte offset).
local function styleLine(text, lines, lineStart, i, style)
	return text:setStyle(style, lineStart[i] + 1, lineStart[i] + #lines[i])
end
local SEARCH_CURSOR_STYLE = { -- inverted cell, like Alacritty's default block cursor
	color = { hex = "#0c0c16", alpha = 1 },
	backgroundColor = hs.alert.defaultStyle.textColor,
}
-- text: query chars; cursor: chars before it; killed: last killed text, for C-y.
-- Styles one char of a joined alert text, given its line, the line's byte offset and the char's
-- column. styledtext positions are bytes, so a multibyte char before it (the insert-mode bar, "—")
-- would shift a char-counted position.
local function styleChar(text, line, lineStart, column, style)
	local from = utf8.offset(line, column)
	local to = (utf8.offset(line, column + 1) or #line + 1) - 1
	return text:setStyle(style, lineStart + from, lineStart + to)
end
local search = { query = "", text = {}, cursor = 0, killed = "", matches = {}, selected = 1, top = 1 }
local promptLine -- the query line with its vim-mode cursor, defined with vimEdit below
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
		local labelScore, labelPositions = fuzzyMatch(entry.shown, search.query, caseSensitive)
		local keysScore, keysPositions = fuzzyMatch(entry.keys, search.query, caseSensitive)
		local groupHit = search.query ~= ""
			and (caseSensitive and entry.group or entry.group:lower()):find(
					caseSensitive and search.query or search.query:lower(),
					1,
					true
				)
				~= nil
		if labelScore or keysScore or groupHit then
			local match = { entry = entry }
			if keysScore and (not labelScore or keysScore > labelScore) then
				match.score, match.keysPositions = keysScore, keysPositions
			elseif labelScore then
				match.score, match.labelPositions = labelScore, labelPositions
			else
				match.score = -math.huge -- group-only: listed, never preselected over a real match
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
-- Text lines that fit in an alert on the main screen.
local function alertLinesFit()
	local lineHeight = hs.drawing.getTextDrawingSize("x", {
		font = hs.alert.defaultStyle.textFont,
		size = hs.alert.defaultStyle.textSize,
	}).h
	return math.floor((hs.screen.mainScreen():frame().h - ALERT_TOP_OFFSET) / lineHeight)
end
local function searchRender()
	-- Rows that fit on screen, less the title and query (3 lines), a blank and header per group
	-- (8 lines) and 2 lines of padding.
	local fit = math.max(1, alertLinesFit() - 13)
	local n = #search.matches
	if n > fit then
		fit = fit - 1 -- room for the position line
	end
	search.page = fit -- for C-d/C-u (listNav)
	search.top = math.min(search.top, search.selected)
	search.top = math.max(search.top, search.selected - fit + 1)
	local last = math.min(n, search.top + fit - 1)
	local prompt, cursorColumn, cursorStyle = promptLine(search)
	local lines = { "Search", "", prompt }
	local highlights = {} -- { line, char column, style }
	local cursor = { 3, cursorColumn, cursorStyle }
	local group, selectedLine, positionLine
	for i = search.top, last do
		local match = search.matches[i]
		local entry = match.entry
		if entry.group ~= group then -- a header above each group, titled like its hint
			group = entry.group
			table.insert(lines, "")
			table.insert(lines, group)
			local caseSensitive = search.query:find("%u") ~= nil
			local at = search.query ~= ""
				and (caseSensitive and group or group:lower()):find(
					caseSensitive and search.query or search.query:lower(),
					1,
					true
				)
			for pos = at or 1, at and at + utf8.len(search.query) - 1 or 0 do
				table.insert(highlights, { #lines, pos })
			end
		end
		local mark = i == search.selected and ">" or " "
		table.insert(lines, string.format("%s %-" .. keysWidth .. "s  %s", mark, entry.keys, entry.shown))
		if i == search.selected then
			selectedLine = #lines
		end
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
		table.insert(lines, string.format("%d-%d of %d", search.top, last, n))
		positionLine = #lines
	end
	local width = searchWidth
	for _, line in ipairs(lines) do
		width = math.max(width, utf8.len(line))
	end
	local lineStart, offset = {}, 0 -- char offset of each line in the joined text
	for i, line in ipairs(lines) do
		lines[i] = line .. string.rep(" ", width - utf8.len(line))
		lineStart[i] = offset
		offset = offset + #lines[i] + 1 -- bytes: styledtext positions count bytes, not chars
	end
	local text = hs.styledtext.new(table.concat(lines, "\n"), SEARCH_TEXT_STYLE)
	if positionLine then
		text = styleLine(text, lines, lineStart, positionLine, DIM_STYLE)
	end
	if selectedLine then
		text = styleLine(text, lines, lineStart, selectedLine, SELECTED_STYLE)
	end
	table.insert(highlights, cursor)
	for _, h in ipairs(highlights) do
		text = styleChar(text, lines[h[1]], lineStart[h[1]], h[2], h[3] or { color = SEARCH_MATCH_COLOR })
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
-- Vim modes for search and the : prompt. Both open in insert mode (readline keys, lineEdit) with a
-- thin bar cursor; Esc switches to normal mode with a block cursor on a char, and Esc there closes
-- (so does q; C-c closes from either mode). Normal mode:
--   h l 0 ^ $ w b e       motions (left/right arrows and lineEdit's ctrl/meta keys work too)
--   i a I A s S C         insert here, after, at start, at end; change char, line, to end
--   x X D p P             delete char, char before, to end; put the last kill after, before
--   d c + w b e 0 ^ $     delete or change over a motion (cw acts as ce, as in vim); dd, cc
--   j k                   next and previous row, like C-n and C-p (wrapping)
--   C-d C-u C-f C-b gg G  half page down/up, page down/up, first and last row (see listNav)
local function charClass(c) -- 0 blank, 1 word, 2 punctuation: what vim's w, b and e stop on
	return c:find("^%s") and 0 or c:find("^[%w_]") and 1 or 2
end
-- Motion targets for normal mode. c is the char index the block is on, 0-based.
local function vimMotion(t, c, m)
	local n = #t
	if m == "h" or m == "left" then
		return math.max(0, c - 1)
	elseif m == "l" or m == "right" then
		return math.min(n, c + 1)
	elseif m == "0" then
		return 0
	elseif m == "^" then
		local i = 0
		while i < n and charClass(t[i + 1]) == 0 do
			i = i + 1
		end
		return i
	elseif m == "$" then
		return math.max(0, n - 1)
	elseif m == "w" then -- start of the next word
		local i = c + 1
		local cls = i <= n and charClass(t[i])
		while i <= n and cls ~= 0 and charClass(t[i]) == cls do
			i = i + 1
		end
		while i <= n and charClass(t[i]) == 0 do
			i = i + 1
		end
		return i - 1
	elseif m == "e" then -- end of this or the next word
		local i = c + 2
		while i <= n and charClass(t[i]) == 0 do
			i = i + 1
		end
		while i < n and charClass(t[i + 1]) == charClass(t[i]) do
			i = i + 1
		end
		return math.min(i, n) - 1
	elseif m == "b" then -- start of this or the previous word
		local i = c
		while i > 0 and charClass(t[i]) == 0 do
			i = i - 1
		end
		while i > 1 and charClass(t[i - 1]) == charClass(t[i]) do
			i = i - 1
		end
		return math.max(0, i - 1)
	end
end
local VIM_INCLUSIVE = { e = true, ["$"] = true } -- operator ranges that take the target char
local function vimClamp(state)
	state.cursor = math.max(0, math.min(state.cursor, #state.text - 1))
end
-- One normal-mode key: returns "text", "cursor" or "mode" (all need a redraw), or nil if not a
-- vim key. Plain keys it does not know are swallowed by the caller, never typed.
local function vimNormal(state, event, key, flags)
	if flags.cmd or flags.ctrl or flags.alt then
		state.pending = nil
		return nil
	end
	local t, c = state.text, state.cursor
	local ch = event:getCharacters() -- shifted chars ($, ^, A) as typed
	local function remove(from, to, keep)
		if keep and to > from then
			state.killed = table.concat(t, "", from + 1, to)
		end
		for _ = from + 1, to do
			table.remove(t, from + 1)
		end
		state.cursor = from
		return "text"
	end
	local function insertMode(at)
		state.mode, state.cursor = "insert", at
		return "mode"
	end
	local function put(at)
		for i, code in ipairs({ utf8.codepoint(state.killed, 1, -1) }) do
			table.insert(t, at + i, utf8.char(code))
		end
		state.cursor = at + utf8.len(state.killed) - 1
		vimClamp(state)
		return "text"
	end
	local op = state.pending
	state.pending = nil
	if op then
		local result
		if ch == op then -- dd, cc: the whole line
			result = remove(0, #t, true)
		else
			local m = (op == "c" and ch == "w") and "e" or ch -- cw changes to the word's end, like vim
			local target = vimMotion(t, c, m)
			if not target then
				return "cursor" -- unknown motion cancels the operator
			end
			local from, to = math.min(c, target), math.max(c, target)
			if VIM_INCLUSIVE[m] then
				to = to + 1
			end
			result = remove(from, math.min(to, #t), true)
		end
		if op == "c" then
			insertMode(state.cursor)
		end
		vimClamp(state)
		return result
	end
	local target = vimMotion(t, c, ch ~= "" and ch or key) or vimMotion(t, c, key)
	if target then
		state.cursor = target
		vimClamp(state)
		return "cursor"
	elseif ch == "d" or ch == "c" then
		state.pending = ch
		return "cursor"
	elseif ch == "i" then
		return insertMode(c)
	elseif ch == "a" then
		return insertMode(math.min(#t, c + 1))
	elseif ch == "I" then
		return insertMode(vimMotion(t, c, "^"))
	elseif ch == "A" then
		return insertMode(#t)
	elseif ch == "x" then
		remove(c, math.min(#t, c + 1), true)
		vimClamp(state)
		return "text"
	elseif ch == "X" then
		return c > 0 and remove(c - 1, c, true) or "cursor"
	elseif ch == "D" then
		remove(c, #t, true)
		vimClamp(state)
		return "text"
	elseif ch == "C" then
		remove(c, #t, true)
		insertMode(c)
		return "text"
	elseif ch == "s" then
		remove(c, math.min(#t, c + 1), true)
		insertMode(c)
		return "text"
	elseif ch == "S" then
		remove(0, #t, true)
		insertMode(0)
		return "text"
	elseif ch == "p" then
		return put(math.min(#t, c + 1))
	elseif ch == "P" then
		return put(c)
	end
	return nil
end
-- Normal-mode list keys for search and the : prompt's list (j/k are handled with C-n/C-p): moves
-- state.selected over count rows, page being the rows shown. Returns true if it took the key. An
-- operator in progress (d, c) keeps its key, so dG-style input is left to vimNormal.
local function listNav(state, count, page, event, key, flags)
	if state.mode ~= "normal" or flags.cmd or flags.alt or state.pending == "d" or state.pending == "c" then
		return false
	end
	local ch = flags.ctrl and "" or event:getCharacters()
	local afterG = state.pending == "g"
	state.pending = nil
	if count == 0 then
		return false
	end
	local half, to = math.max(1, page // 2), nil
	if flags.ctrl and key == "d" then
		to = state.selected + half
	elseif flags.ctrl and key == "u" then
		to = state.selected - half
	elseif flags.ctrl and key == "f" then
		to = state.selected + page
	elseif flags.ctrl and key == "b" then
		to = state.selected - page
	elseif ch == "G" then
		to = count
	elseif ch == "g" and afterG then
		to = 1
	elseif ch == "g" then
		state.pending = "g"
		return true
	else
		return false
	end
	state.selected = math.max(1, math.min(count, to))
	return true
end
-- Esc, q and C-c for both prompts: "close", "mode" (went to normal) or nil if none of them. Esc
-- always goes to normal mode first, so the list can be browsed with j/k; Esc again or q closes, like
-- less. In insert mode q is just a letter (q ct, Quit App).
local function vimEscape(state, key, flags)
	local ctrlOnly = flags.ctrl and not (flags.cmd or flags.alt)
	local plain = not (flags.cmd or flags.ctrl or flags.alt or flags.shift)
	local normalClose = state.mode == "normal" and (key == "escape" or (plain and key == "q"))
	if (ctrlOnly and key == "c") or normalClose then
		return "close"
	elseif key == "escape" then
		state.mode, state.pending = "normal", nil
		state.cursor = state.cursor - 1
		vimClamp(state)
		return "mode"
	end
end
-- A key in either mode that edits the line: lineEdit in insert, vimNormal (then lineEdit's
-- non-plain keys) in normal. Returns "text", "cursor", "mode" or nil.
local function vimEdit(state, event, key, flags)
	if state.mode ~= "normal" then
		return lineEdit(state, event, key, flags)
	end
	local edit = vimNormal(state, event, key, flags)
	if edit == nil and (flags.cmd or flags.ctrl or flags.alt or not event:getCharacters():find("^[%g ]")) then
		edit = lineEdit(state, event, key, flags)
		vimClamp(state)
	end
	return edit or "cursor" -- unknown plain keys are swallowed
end
-- The prompt line with its cursor: a thin bar in insert mode, a block on the char in normal mode.
-- The bar is a thin space on the cursor color, set in the proportional system font: the alert font
-- is monospace, where any space takes a full cell. Returns the line (trailing space holds an end
-- cursor), the cursor's 1-based char column and its style.
local INSERT_CURSOR_STYLE = {
	font = { name = ".AppleSystemUIFont", size = hs.alert.defaultStyle.textSize },
	backgroundColor = hs.alert.defaultStyle.textColor,
}
local INSERT_BAR = "\u{2009}"
promptLine = function(state)
	if state.mode == "normal" then
		return table.concat(state.text) .. " ", state.cursor + 1, SEARCH_CURSOR_STYLE
	end
	return table.concat(state.text, "", 1, state.cursor) .. INSERT_BAR .. table.concat(state.text, "", state.cursor + 1) .. " ",
		state.cursor + 1,
		INSERT_CURSOR_STYLE
end
searchTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
	local key, flags = hs.keycodes.map[event:getKeyCode()], event:getFlags()
	local ctrlOnly = flags.ctrl and not (flags.cmd or flags.alt)
	local normal = search.mode == "normal" and not (flags.cmd or flags.ctrl or flags.alt)
	local down = key == "down" or (ctrlOnly and key == "n") or (normal and key == "j")
	local up = key == "up" or (ctrlOnly and key == "p") or (normal and key == "k")
	local move = down and 1 or up and -1
	local escape = vimEscape(search, key, flags)
	if escape == "close" then
		searchClose()
	elseif escape then
		searchRender()
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
	elseif listNav(search, #search.matches, search.page or 1, event, key, flags) then
		searchRender()
	else
		local edit = vimEdit(search, event, key, flags)
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
	search.query, search.text, search.cursor, search.mode, search.pending = "", {}, 0, "insert", nil
	refreshSearchLabels()
	searchFilter()
	searchTap:start()
	searchRender()
end

--- Command mode (H-z/;) ---
-- A vim-style : prompt drawn like search. Enter runs the command. Editing, vim modes and closing
-- (Esc in normal mode) are the same as in search (vimEdit). An error shows under the prompt and
-- keeps the text.
-- C-p/Up and C-n/Down step through past commands, like vim's : history (kept via hs.settings).
--   ct <duration> [-m label] [-e end message]   ct 30m -m DSA, ct 1h 30m, ct 90s, ct 5 (minutes)
--   ct -t <HHMM|HHMMSS> [-m label] [-e msg]     until a clock time, tomorrow if already past
--   q ct [all | <n> | <label>]                  cancel or dismiss timers (see below)
--   <label>                                     any picker item, or Toggle Clock Date, Toggle Clock
--                                               Seconds, Toggle Firefox Border: typed as its label in
--                                               any case, without (key notes) or punctuation
-- As you type, the labels that fit list under the prompt with their status, like the pickers
-- ("Toggle Clock Date [shown]"), fuzzy-matched like search (see cmdList): clock, tog gr, date clock.
-- C-n/C-p (j/k in normal mode) select, Enter runs the selection. Tab on an empty line lists every
-- command (Enter on ct or q ct fills it in for its args). A front-app item (Quit App, Copy)
-- reached by a partial match confirms first.
-- ct ports ~/scripts/countdown.zsh. Each ct adds a timer; several can run at once. They show left
-- of the clock in end-time order, soonest nearest the clock (that one is n = 0). At zero a timer's
-- end message replaces it and Hero repeats until it is dismissed. Bare q ct dismisses every ended
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
	q = function(args) -- q <thing>: ct is the only thing it quits so far
		if args[1] ~= "ct" then
			return nil, "Usage: q ct [all | <n> | <label>]"
		end
		table.remove(args, 1)
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
			return nil, #cts .. " timers: q ct all, q ct <n> (0 = nearest the clock) or q ct <label>"
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
for _, entry in ipairs(searchEntries) do
	local first = entry.words:match("^%S+")
	assert(entry.name or not commands[first] or entry.words:find(" "), "label shadows a command: " .. entry.label)
end
-- The entries a line lists under the prompt: search's entries (see addSearchEntry), as
-- { row, positions, exact }, and how to read them:
--   "all"    Tab on an empty line: every entry under its group header, exactly as search lists them
--   "match"  the line fuzzy-matched like search (fuzzyMatch, smartcase): each space-separated word
--            on its own, anywhere and in any order, scores added (clock, tog gr, date clock).
--            A named command matches on its name (ct, q ct), not its usage. Best first: the
--            exact name or label, then by score, then the earlier match, the shorter name or
--            label, and list order.
--   "usage"  the line is a named command with args (ct 30m): its usage rows, as a hint. Enter
--            runs the line itself, so there is nothing to select.
local function cmdList(line, showAll)
	local list = {}
	local first = line:match("^%s*(%S+)")
	if commands[first] and line:find("^%s*%S+%s") then
		for _, row in ipairs(searchEntries) do
			if row.name and row.name:match("^%S+") == first then
				table.insert(list, { row = row, positions = {} })
			end
		end
		return list, "usage"
	elseif not first then
		if showAll then
			for _, row in ipairs(searchEntries) do
				table.insert(list, { row = row, positions = {} })
			end
		end
		return list, "all"
	end
	local caseSensitive = line:find("%u") ~= nil
	local typed = line:match("^%s*(.-)%s*$")
	local typedWords = table.concat(labelWords(line), " ")
	for _, row in ipairs(searchEntries) do
		local total, positions = 0, {}
		for term in line:gmatch("%S+") do
			local score, at = fuzzyMatch(row.name or row.label, term, caseSensitive)
			if not score then
				total = nil
				break
			end
			total = total + score
			table.move(at, 1, #at, #positions + 1, positions)
		end
		if total then
			local exact = row.name == typed or (not row.name and row.words == typedWords)
			table.insert(list, {
				row = row,
				positions = positions,
				exact = exact,
				score = exact and math.huge or total,
				start = math.min(table.unpack(positions)),
				length = #(row.name or row.label),
			})
		end
	end
	table.sort(list, function(a, b)
		if a.score ~= b.score then
			return a.score > b.score
		elseif a.start ~= b.start then -- ct: ct before q ct
			return a.start < b.start
		elseif a.length ~= b.length then -- clock: Toggle Clock before Toggle Clock Date
			return a.length < b.length
		end
		return a.row.order < b.row.order
	end)
	return list, "match"
end
-- What Enter does with a line: returns action, the line to remember in history, and either an
-- error or, for a named command picked from the list, the text to fill in. A named command with
-- args runs as typed; otherwise the selected entry runs. A front-app item runs at once when its
-- label is typed in full, and otherwise confirms first, as from search (qu must not quit).
local function cmdResolve(line, selected, showAll)
	local tokens, err = tokenize(line)
	if not tokens then
		return nil, nil, err
	end
	local list, kind = cmdList(line, showAll)
	if kind == "usage" then
		local name = table.remove(tokens, 1)
		local action
		action, err = commands[name](tokens)
		return action, line, err
	end
	local pick = list[selected]
	if not pick then
		return nil, nil, #tokens > 0 and "Not a command: " .. line or nil
	end
	local row = pick.row
	if row.fill then
		return nil, nil, nil, row.fill
	end
	return (pick.exact and row.direct or row.run), row.words
end
local CMD_MATCHES_MAX = 10 -- matches listed under the prompt at once; more scroll

local cmd = { text = {}, cursor = 0, killed = "", error = nil, selected = 1, top = 1 }
local CMD_HISTORY_MAX = 100
local cmdHistory = hs.settings.get("cmdHistory") or {} -- oldest first
local cmdHistoryPos, cmdDraft -- index into cmdHistory while browsing (nil = the line being typed)
local function cmdRemember(line)
	for i = #cmdHistory, 1, -1 do -- one copy, moved to newest, like vim
		if cmdHistory[i] == line then
			table.remove(cmdHistory, i)
		end
	end
	table.insert(cmdHistory, line)
	while #cmdHistory > CMD_HISTORY_MAX do
		table.remove(cmdHistory, 1)
	end
	hs.settings.set("cmdHistory", cmdHistory)
end
local function cmdSetLine(line)
	cmd.text, cmd.error = {}, nil
	for _, code in utf8.codes(line) do
		table.insert(cmd.text, utf8.char(code))
	end
	cmd.cursor = #cmd.text
end
-- step -1 = older, 1 = newer; past the newest returns to the line being typed.
local function cmdHistoryStep(step)
	if #cmdHistory == 0 then
		return false
	end
	local pos = (cmdHistoryPos or #cmdHistory + 1) + step
	if pos < 1 or pos > #cmdHistory + 1 then
		return false
	end
	if not cmdHistoryPos then
		cmdDraft = table.concat(cmd.text)
	end
	cmdHistoryPos = pos <= #cmdHistory and pos or nil
	cmdSetLine(cmdHistoryPos and cmdHistory[pos] or cmdDraft)
	cmd.selected, cmd.top = 1, 1
	if cmd.mode == "normal" then
		vimClamp(cmd)
	end
	return true
end
local cmdTap, cmdAlert
local CMD_MIN_WIDTH = 40 -- chars; keeps the prompt from jumping in width while typing
local function cmdRender()
	local line = table.concat(cmd.text)
	local prompt, cursorColumn, cursorStyle = promptLine(cmd)
	local lines = { ":" .. prompt }
	local highlights = { { 1, cursorColumn + 1, cursorStyle } } -- { line, char column, style }; +1 for ":"
	local positionLine, selectedLine
	if cmd.error then
		table.insert(lines, "")
		table.insert(lines, cmd.error)
	else
		local list, kind = cmdList(line, cmd.showAll)
		cmd.selected = math.min(cmd.selected, math.max(1, #list))
		cmd.top = math.min(cmd.top, cmd.selected)
		-- The Tab list fills the screen like search: less the prompt, a blank and header per group
		-- (8 lines), the position line and 2 lines of padding.
		local max = kind == "all" and math.max(1, alertLinesFit() - 12) or CMD_MATCHES_MAX
		cmd.page = max -- for C-d/C-u (listNav)
		cmd.top = math.max(cmd.top, cmd.selected - max + 1)
		local last = math.min(#list, cmd.top + max - 1)
		local group
		for i = cmd.top, last do
			local row = list[i].row
			if i == cmd.top or (kind == "all" and row.group ~= group) then
				table.insert(lines, "")
				if kind == "all" then -- a header above each group, like search
					group = row.group
					table.insert(lines, group)
				end
			end
			local mark = (kind ~= "usage" and i == cmd.selected) and ">" or " "
			table.insert(lines, string.format("%s %-" .. keysWidth .. "s  %s", mark, row.keys, row.shown))
			if mark == ">" then
				selectedLine = #lines
			end
			for _, pos in ipairs(list[i].positions) do
				table.insert(highlights, { #lines, 2 + keysWidth + 2 + pos })
			end
		end
		if #list > max then
			table.insert(lines, string.format("%d-%d of %d", cmd.top, last, #list))
			positionLine = #lines
		end
	end
	local width = math.max(CMD_MIN_WIDTH, searchWidth) -- as wide as search, so both look the same
	for _, l in ipairs(lines) do
		width = math.max(width, utf8.len(l))
	end
	local lineStart, offset = {}, 0 -- char offset of each line in the joined text
	for i, l in ipairs(lines) do
		lines[i] = l .. string.rep(" ", width - utf8.len(l))
		lineStart[i] = offset
		offset = offset + #lines[i] + 1 -- bytes: styledtext positions count bytes, not chars
	end
	local text = hs.styledtext.new(table.concat(lines, "\n"), SEARCH_TEXT_STYLE)
	if positionLine then
		text = styleLine(text, lines, lineStart, positionLine, DIM_STYLE)
	end
	if selectedLine then
		text = styleLine(text, lines, lineStart, selectedLine, SELECTED_STYLE)
	end
	for _, h in ipairs(highlights) do
		text = styleChar(text, lines[h[1]], lineStart[h[1]], h[2], h[3] or { color = SEARCH_MATCH_COLOR })
	end
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
	local ctrlOnly = flags.ctrl and not (flags.cmd or flags.alt)
	local older = key == "up" or (ctrlOnly and key == "p")
	local newer = key == "down" or (ctrlOnly and key == "n")
	-- C-n/C-p move through the label list, as in search; Up/Down, and C-n/C-p with no list or
	-- while browsing history, step through history.
	local normal = cmd.mode == "normal" and not (flags.cmd or flags.ctrl or flags.alt)
	local listKey = ctrlOnly or normal
	older = older or (normal and key == "k")
	newer = newer or (normal and key == "j")
	local list, kind = {}, nil
	if listKey and not cmdHistoryPos then
		list, kind = cmdList(table.concat(cmd.text), cmd.showAll)
		if kind == "usage" then
			list = {} -- a hint, nothing to select
		end
	end
	local escape = vimEscape(cmd, key, flags)
	if escape == "close" then
		cmdClose()
	elseif escape then
		cmdRender()
	elseif (older or newer) and #list > 0 then -- wraps past either end
		cmd.selected = (cmd.selected - 1 + (newer and 1 or -1)) % #list + 1
		cmdRender()
	elseif older or newer then
		if cmdHistoryStep(older and -1 or 1) then
			cmdRender()
		end
	elseif listNav(cmd, #list, cmd.page or 1, event, key, flags) then
		cmdRender()
	elseif key == "tab" and not (flags.cmd or flags.ctrl or flags.alt) then -- list every command
		cmd.showAll, cmd.selected, cmd.top, cmd.error = true, 1, 1, nil
		cmdRender()
	elseif key == "return" or key == "padenter" then
		local line = table.concat(cmd.text)
		local action, remember, err, fill = cmdResolve(line, cmd.selected, cmd.showAll)
		if fill then -- a named command picked from the list: fill it in for its args
			cmdSetLine(fill)
			cmd.mode, cmd.selected, cmd.top = "insert", 1, 1
			cmdRender()
		elseif action then
			cmdClose()
			if remember ~= "" then -- free slots have no words
				cmdRemember(remember)
			end
			hs.timer.doAfter(0, action) -- outside the tap callback
		elseif err then
			cmd.error = err
			cmdRender()
		else -- Enter on an empty line
			cmdClose()
		end
	else
		local edit = vimEdit(cmd, event, key, flags)
		if edit == "text" then
			cmd.error, cmdHistoryPos = nil, nil -- an edited recall becomes the new draft
			cmd.selected, cmd.top = 1, 1
		end
		if edit then
			cmdRender()
		end
	end
	return true -- every key press stays out of the front app while the prompt is open
end)
-- fill: text to start with, like "ct " from a named command in search.
commandMode = function(fill)
	cmd.text, cmd.cursor, cmd.error, cmd.selected, cmd.top = {}, 0, nil, 1, 1
	cmd.mode, cmd.pending, cmd.showAll = "insert", nil, false
	if type(fill) == "string" then
		cmdSetLine(fill)
	end
	cmdHistoryPos, cmdDraft = nil, nil
	refreshSearchLabels() -- current statuses and column widths
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
