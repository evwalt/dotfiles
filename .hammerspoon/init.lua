-- Automatic Config Reload
--
function reloadConfig(files)
    doReload = false
    for _,file in pairs(files) do
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

-- Application Focus
--
local hyper = {"ctrl", "alt", "cmd", "shift"}
-- crl tns wvz fdb
hs.hotkey.bind(hyper, "C", function()
    hs.application.launchOrFocus("Google Chrome")
end)
hs.hotkey.bind(hyper, "R", function()
    hs.application.launchOrFocus("Alacritty")
end)
hs.hotkey.bind(hyper, "L", function()
    hs.application.launchOrFocus("Simplenote")
end)
hs.hotkey.bind(hyper, "T", function()
    hs.application.launchOrFocus("Visual Studio Code")
end)
hs.hotkey.bind(hyper, "N", function()
    hs.application.launchOrFocus("Discord")
end)
hs.hotkey.bind(hyper, "S", function()
    hs.application.launchOrFocus("GitHub Desktop")
end)
hs.hotkey.bind(hyper, "W", function()
    hs.application.launchOrFocus("Finder")
end)
hs.hotkey.bind(hyper, "V", function()
    hs.application.launchOrFocus("Spotify")
end)
hs.hotkey.bind(hyper, "Z", function()
    hs.application.launchOrFocus("System Settings")
end)
hs.hotkey.bind(hyper, "G", function()
    hs.application.launchOrFocus("LibreOffice")
end)
hs.hotkey.bind(hyper, "F", function()
    hs.application.launchOrFocus("Activity Monitor")
end)
hs.hotkey.bind(hyper, "D", function()
    hs.application.launchOrFocus("Reminders")
end)
hs.hotkey.bind(hyper, "B", function()
    hs.application.launchOrFocus("Messages")
end)

-- Window Management
--
-- lmr  
-- halves: left half: o; middle half: e/t; right half: n
-- thirds: left third: j; middle third: k/m; right third: w
-- fourths: ,rqv
local ca = {"ctrl", "alt"}
-- Helper function to move and resize windows
local function moveAndResize(xRatio, yRatio, wRatio, hRatio)
    local win = hs.window.focusedWindow()
    if not win then return end
    local f = win:frame()
    local screen = win:screen()
    local max = screen:frame()
    f.x = max.x + (max.w * xRatio)
    f.y = max.y + (max.h * yRatio)
    f.w = max.w * wRatio
    f.h = max.h * hRatio
    win:setFrameInScreenBounds(f, 0)
end
hs.hotkey.bind(ca, "return", function() moveAndResize(0, 0, 1, 1) end)  -- Maximized
hs.hotkey.bind({"ctrl", "alt", "shift"}, "return", function() moveAndResize(0.05, 0.05, 0.9, 0.9) end)  -- Almost maximized

-- Vertical Halves
--
hs.hotkey.bind(ca, "o", function() moveAndResize(0, 0, 0.5, 1) end)  -- Left half
hs.hotkey.bind(ca, "e", function() moveAndResize(0.25, 0, 0.5, 1) end)  -- Center half
hs.hotkey.bind(ca, "t", function() moveAndResize(0.25, 0, 0.5, 1) end)  -- Center half (same as "e")
hs.hotkey.bind(ca, "n", function() moveAndResize(0.5, 0, 0.5, 1) end)  -- Right half

-- Horisontal Halves
--
hs.hotkey.bind(ca, "y", function() moveAndResize(0, 0, 1, 0.5) end)  -- Top half
hs.hotkey.bind(ca, "f", function() moveAndResize(0.5, 0.5, 1, 0.5) end)  -- Bottom half

-- Fourths - Corners
--
hs.hotkey.bind(ca, ",", function() moveAndResize(0, 0, 0.5, 0.5) end)  -- Top left
hs.hotkey.bind(ca, "r", function() moveAndResize(0.5, 0, 0.5, 0.5) end)  -- Top right
hs.hotkey.bind(ca, "v", function() moveAndResize(0.5, 0.5, 0.5, 0.5) end)  -- Bottom right
hs.hotkey.bind(ca, "q", function() moveAndResize(0, 0.5, 0.5, 0.5) end)  -- Bottom left

-- Fourths - Centered
--
hs.hotkey.bind(ca, ".", function() moveAndResize(0.25, 0, 0.5, 0.5) end)  -- Top middle fourth
hs.hotkey.bind(ca, "c", function() moveAndResize(0.25, 0, 0.5, 0.5) end)  -- Top middle fourth (same as ".")
hs.hotkey.bind(ca, "p", function() moveAndResize(0.25, 0.25, 0.5, 0.5) end)  -- Center fourth
hs.hotkey.bind(ca, "g", function() moveAndResize(0.25, 0.25, 0.5, 0.5) end)  -- Center fourth (same as "p")

-- Vertical Thirds
--
hs.hotkey.bind(ca, "j", function() moveAndResize(0, 0, 1/3, 1) end)  -- Left third
hs.hotkey.bind(ca, "k", function() moveAndResize(1/3, 0, 1/3, 1) end)  -- Middle third
hs.hotkey.bind(ca, "m", function() moveAndResize(1/3, 0, 1/3, 1) end)  -- Middle third (same as "k")
hs.hotkey.bind(ca, "w", function() moveAndResize(2/3, 0, 1/3, 1) end)  -- Right third

-- Vertical Two-thirds
--
hs.hotkey.bind(ca, "x", function() moveAndResize(0, 0, 2/3, 1) end)  -- Left two-thirds
hs.hotkey.bind(ca, "i", function() moveAndResize(1/6, 0, 2/3, 1) end)  -- Middle two-thirds
hs.hotkey.bind(ca, "d", function() moveAndResize(1/6, 0, 2/3, 1) end)  -- Middle two-thirds (same as "i")
hs.hotkey.bind(ca, "b", function() moveAndResize(1/3, 0, 2/3, 1) end)  -- Right two-thirds
