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
hs.alert.show("Config loaded")
print(os.getenv("HOME") .. "/.hammerspoon/")

--- Multi-action Keys ---
local hyper = { "ctrl", "alt", "cmd", "shift" }
--- Multi-action picker for a single hotkey ---
-- Usage: hs.hotkey.bind(hyper, "G", actionPicker({ s = "Skim", p = "Spotify" }))
-- Press the hyper combo, then one of the listed sub-keys. Esc cancels.
local function actionPicker(choices)
	local m = hs.hotkey.modal.new()
	local hint = {}
	for key, choice in pairs(choices) do
		local label = type(choice) == "table" and choice.label or choice
		table.insert(hint, key .. " → " .. label)
		m:bind({}, key, function()
			hs.alert.closeAll()
			m:exit()
			if type(choice) == "table" then
				choice.action()
			else
				hs.application.launchOrFocus(choice)
			end
		end)
	end
	m:bind({}, "escape", function()
		m:exit()
	end)
	local hintText = table.concat(hint, "\n")
	function m:entered()
		hs.alert.closeAll()
		hs.alert.show(hintText, 2)
	end
	return function()
		m:enter()
	end
end

--- Firefox Dim Mode ---
-- Dark overlay on every Firefox window that isn't the focused window.
-- The overlay covers only the parts of the window not hidden behind other
-- windows, since canvases can't be ordered relative to other apps' windows.
-- Enabled state persists across restarts via hs.settings (default: on).
local dimEnabled = hs.settings.get("firefoxDim")
if dimEnabled == nil then
	dimEnabled = true
end
local dimOverlays = {}

-- Returns the pieces of each rect in `rects` that lie outside `o`.
local function subtractRect(rects, o)
	local out = {}
	for _, r in ipairs(rects) do
		local ix1, iy1 = math.max(r.x, o.x), math.max(r.y, o.y)
		local ix2, iy2 = math.min(r.x + r.w, o.x + o.w), math.min(r.y + r.h, o.y + o.h)
		if ix1 >= ix2 or iy1 >= iy2 then
			table.insert(out, r)
		else
			if iy1 > r.y then
				table.insert(out, { x = r.x, y = r.y, w = r.w, h = iy1 - r.y })
			end
			if iy2 < r.y + r.h then
				table.insert(out, { x = r.x, y = iy2, w = r.w, h = r.y + r.h - iy2 })
			end
			if ix1 > r.x then
				table.insert(out, { x = r.x, y = iy1, w = ix1 - r.x, h = iy2 - iy1 })
			end
			if ix2 < r.x + r.w then
				table.insert(out, { x = ix2, y = iy1, w = r.x + r.w - ix2, h = iy2 - iy1 })
			end
		end
	end
	return out
end

local function refreshDim()
	local dim = {}
	if dimEnabled then
		local focused = hs.window.focusedWindow()
		local focusedId = focused and focused:id()
		local above = {} -- frames of windows in front of the current one
		for _, win in ipairs(hs.window.orderedWindows()) do
			if win:isStandard() then
				local frame = win:frame()
				local app = win:application()
				if app and app:name() == "Firefox" and win:id() ~= focusedId then
					local rects = { frame }
					for _, o in ipairs(above) do
						rects = subtractRect(rects, o)
					end
					if #rects > 0 then
						dim[win:id()] = { frame = frame, rects = rects }
					end
				end
				table.insert(above, frame)
			end
		end
	end
	for id, canvas in pairs(dimOverlays) do
		if not dim[id] then
			canvas:delete()
			dimOverlays[id] = nil
		end
	end
	for id, d in pairs(dim) do
		local elements = {}
		for _, r in ipairs(d.rects) do
			table.insert(elements, {
				type = "rectangle",
				action = "fill",
				fillColor = { white = 0, alpha = 0.60 },
				frame = { x = r.x - d.frame.x, y = r.y - d.frame.y, w = r.w, h = r.h },
				-- match macOS window corners when nothing is occluding
				roundedRectRadii = #d.rects == 1 and { xRadius = 10, yRadius = 10 } or nil,
			})
		end
		if dimOverlays[id] then
			dimOverlays[id]:frame(d.frame):replaceElements(elements)
		else
			dimOverlays[id] = hs.canvas.new(d.frame):appendElements(elements):show()
		end
	end
end
local function toggleDim()
	dimEnabled = not dimEnabled
	hs.settings.set("firefoxDim", dimEnabled)
	refreshDim()
	hs.alert.show("Firefox dim: " .. (dimEnabled and "on" or "off"))
end
-- Debounced: window moves fire many events while dragging. A second, later
-- pass catches focus changes where focusedWindow() lags behind the event.
local dimRefresh = hs.timer.delayed.new(0.05, refreshDim)
local dimRefreshLate = hs.timer.delayed.new(0.3, refreshDim)
local function scheduleDim()
	dimRefresh:start()
	dimRefreshLate:start()
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
}, scheduleDim)
---@diagnostic disable-next-line: lowercase-global
dimSpaceWatcher = hs.spaces.watcher.new(scheduleDim):start()
---@diagnostic disable-next-line: lowercase-global
dimAppWatcher = hs.application.watcher.new(scheduleDim):start()
-- Safety net for any focus change that emits no event.
---@diagnostic disable-next-line: lowercase-global
dimHeartbeat = hs.timer.doEvery(1, refreshDim)
refreshDim()

-- Dvorak keyboard layout reference: `crl tns wvz fdb`
hs.hotkey.bind(hyper, "F", function()
	hs.application.launchOrFocus("Reminders")
end)
hs.hotkey.bind(
	hyper,
	"G",
	actionPicker({
		a = "Activity Monitor",
		g = {
			label = "Toggle Grayscale",
			action = function()
				hs.screen.setForceToGray(not hs.screen.getForceToGray())
			end,
		},
		d = { label = "Toggle Firefox Dim", action = toggleDim },
		h = "Handy",
		k = "Skim",
		o = "Spotify",
	})
)
hs.hotkey.bind(hyper, "C", function()
	hs.application.launchOrFocus("Finder")
end)
hs.hotkey.bind(hyper, "R", function()
	hs.eventtap.keyStroke({ "cmd" }, "`") -- switch window in app
end)
hs.hotkey.bind(hyper, "L", function()
	hs.application.launchOrFocus("Notes")
end)
hs.hotkey.bind(hyper, "I", function()
	hs.application.launchOrFocus("Google Chrome")
end)
hs.hotkey.bind(hyper, "S", function()
	hs.application.launchOrFocus("GitHub Desktop")
end)
hs.hotkey.bind(hyper, "B", function()
	hs.application.launchOrFocus("Messages")
end)
hs.hotkey.bind(hyper, "M", function()
	hs.application.launchOrFocus("Firefox")
end)
hs.hotkey.bind(hyper, "V", function()
	hs.application.launchOrFocus("Alacritty")
end)
hs.hotkey.bind(hyper, "Z", function()
	hs.application.launchOrFocus("System Settings")
end)
hs.hotkey.bind(hyper, "J", function()
	hs.application.launchOrFocus("zoom.us")
end)

--- Firefox Quit, Raindrop Save Tabs Warning ---
local function frontmostAppName()
	local app = hs.application.frontmostApplication()
	return app and app:name() or ""
end
local confirmModal = hs.hotkey.modal.new()
confirmModal:bind({}, "y", function()
	hs.alert.closeAll()
	confirmModal:exit()
	local fx = hs.application.get("Firefox")
	if fx then
		fx:selectMenuItem({ "Firefox", "Quit Firefox" })
	end
end)
confirmModal:bind({}, "n", function()
	hs.alert.closeAll()
	confirmModal:exit()
end)
confirmModal:bind({}, "escape", function()
	hs.alert.closeAll()
	confirmModal:exit()
end)
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
	hs.alert.show(
		"Have you saved wanted open tabs to Raindrop?\n"
			.. "If yes, press Y to quit Firefox.\n"
			.. "If no, press N or Esc to cancel.",
		3
	)
	confirmModal:enter()
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
