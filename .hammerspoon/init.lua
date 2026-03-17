--- Automatic Config Reload ---
function reloadConfig(files)
	doReload = false
	for _, file in pairs(files) do
		if file:sub(-4) == ".lua" then
			doReload = true
		end
	end
	if doReload then
		hs.reload()
	end
end

myWatcher = hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", reloadConfig):start()
hs.alert.show("Config loaded")
print(os.getenv("HOME") .. "/.hammerspoon/")

--- Application Focus ---
local hyper = { "ctrl", "alt", "cmd", "shift" }
-- crl tns wvz fdb
hs.hotkey.bind(hyper, "F", function()
	hs.application.launchOrFocus("Notion")
end)
hs.hotkey.bind(hyper, "G", function()
	hs.application.launchOrFocus("Activity Monitor")
end)
hs.hotkey.bind(hyper, "C", function()
	hs.application.launchOrFocus("Finder")
end)
hs.hotkey.bind(hyper, "R", function()
	hs.application.launchOrFocus("Spotify")
end)
hs.hotkey.bind(hyper, "L", function()
	hs.application.launchOrFocus("Notes")
end)
hs.hotkey.bind(hyper, "I", function()
	-- hs.application.launchOrFocus("Visual Studio Code")
	hs.application.launchOrFocus("Discord")
end)
hs.hotkey.bind(hyper, "S", function()
	hs.application.launchOrFocus("GitHub Desktop")
end)
hs.hotkey.bind(hyper, "B", function()
	hs.application.launchOrFocus("Messages")
end)
hs.hotkey.bind(hyper, "M", function()
	-- hs.application.launchOrFocus("Google Chrome")
	hs.application.launchOrFocus("Firefox")
end)
hs.hotkey.bind(hyper, "V", function()
	hs.application.launchOrFocus("Alacritty")
end)
hs.hotkey.bind(hyper, "Z", function()
	-- hs.application.launchOrFocus("System Settings")
	-- hs.application.launchOrFocus("Skim")
	hs.application.launchOrFocus("/Applications/Adobe Digital Editions 4.5.app")
end)
hs.hotkey.bind(hyper, "J", function()
	hs.application.launchOrFocus("zoom.us")
end)

--- Window Dimming (Adobe Digital Editions) ---
local adeName = "Adobe Digital Editions"
local wf = hs.window.filter.new(adeName)
local overlay = nil
local currentWin = nil
local occlusionPoller = nil
local function rectsOverlap(a, b)
	return not (a.x + a.w <= b.x or b.x + b.w <= a.x or a.y + a.h <= b.y or b.y + b.h <= a.y)
end
local function ensureOverlay(win)
	local f = win:frame()
	if not overlay then
		overlay = hs.canvas.new(f)
		overlay:level(hs.canvas.windowLevels.floating)
		overlay:behavior({})
		overlay:clickActivating(false)
		overlay:appendElements({
			type = "rectangle",
			action = "fill",
			fillColor = { black = 0, alpha = 0.6 },
			frame = { x = 0, y = 0, w = "100%", h = "100%" },
		})
	else
		overlay:frame(f)
	end
end
local function adeIsOccluded(win)
	if not win or not win:isVisible() then
		return true
	end
	local adeFrame = win:frame()
	local adeID = win:id()
	local windows = hs.window.orderedWindows()
	for _, other in ipairs(windows) do
		local otherID = other:id()
		if otherID == adeID then
			-- We reached ADE in z-order.
			-- Anything after this is behind it and cannot cover it.
			return false
		end
		if other:isVisible() then
			local otherFrame = other:frame()
			if rectsOverlap(adeFrame, otherFrame) then
				return true
			end
		end
	end
	return false
end
local function updateOverlay(win)
	if not win then
		if overlay then
			overlay:hide()
		end
		return
	end
	currentWin = win
	ensureOverlay(win)
	if adeIsOccluded(win) then
		overlay:hide()
	else
		overlay:show()
	end
end
local function startPoller()
	if occlusionPoller then
		return
	end
	occlusionPoller = hs.timer.doEvery(0.2, function()
		if currentWin then
			updateOverlay(currentWin)
		end
	end)
end
local function stopPoller()
	if occlusionPoller then
		occlusionPoller:stop()
		occlusionPoller = nil
	end
end
wf:subscribe(hs.window.filter.windowFocused, function(win)
	currentWin = win
	updateOverlay(win)
	startPoller()
end)
wf:subscribe(hs.window.filter.windowUnfocused, function(win)
	currentWin = win
	updateOverlay(win)
	startPoller()
end)
wf:subscribe(hs.window.filter.windowMoved, function(win)
	if currentWin and win:id() == currentWin:id() then
		updateOverlay(win)
	end
end)
wf:subscribe(hs.window.filter.windowVisible, function(win)
	currentWin = win
	updateOverlay(win)
	startPoller()
end)
wf:subscribe(hs.window.filter.windowNotVisible, function(_)
	if overlay then
		overlay:hide()
	end
	stopPoller()
end)
wf:subscribe(hs.window.filter.windowHidden, function(_)
	if overlay then
		overlay:hide()
	end
	stopPoller()
end)
wf:subscribe(hs.window.filter.windowDestroyed, function(_)
	if overlay then
		overlay:hide()
	end
	currentWin = nil
	stopPoller()
end)

--- Firefox Quit, Raindrop Save Tabs Warning ---
function frontmostAppName()
	local app = hs.application.frontmostApplication()
	return app and app:name() or ""
end
confirmModal = hs.hotkey.modal.new()
confirmModal:bind({}, "y", function()
	confirmModal:exit()
	local fx = hs.application.get("Firefox")
	if fx then
		fx:selectMenuItem({ "Firefox", "Quit Firefox" })
	end
end)
confirmModal:bind({}, "n", function()
	confirmModal:exit()
end)
confirmModal:bind({}, "escape", function()
	confirmModal:exit()
end)
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

--- Horisontal Halves ---
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
