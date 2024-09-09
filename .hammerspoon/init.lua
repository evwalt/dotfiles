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

--[[
** Application Focus
--]]
local hyper = {"ctrl", "alt", "cmd", "shift"}
-- crl tns wvz fdb
hs.hotkey.bind(hyper, "C", function()
    hs.application.launchOrFocus("Google Chrome")
end)
hs.hotkey.bind(hyper, "R", function()
    hs.application.launchOrFocus("iTerm")
end)
hs.hotkey.bind(hyper, "L", function()
    hs.application.launchOrFocus("Simplenote")
end)
hs.hotkey.bind(hyper, "T", function()
    hs.application.launchOrFocus("Visual Studio Code")
end)
hs.hotkey.bind(hyper, "N", function()
    hs.application.launchOrFocus("LibreOffice")
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
hs.hotkey.bind(hyper, "F", function()
    hs.application.launchOrFocus("Activity Monitor")
end)
hs.hotkey.bind(hyper, "D", function()
    hs.application.launchOrFocus("Reminders")
end)
hs.hotkey.bind(hyper, "B", function()
    hs.application.launchOrFocus("Messages")
end)

--[[
** Window Management
]]--
--               lmr  
-- halves: left half: o; middle half: e/t; right half: n
-- thirds: left third: j; middle third: k/m; right third: w
-- fourths: ,rqv
local ca = {"ctrl", "alt"}
local win = hs.window.focusedWindow()
local f = win:frame()
local screen = win:screen()
local max = screen:frame()
-- halves
-- left half
hs.hotkey.bind(ca, "o", function()
    if not win then return end
    f.x = max.x
    f.y = max.y
    f.w = max.w / 2
    f.h = max.h
    win:setFrame(f)
end)
-- center half
hs.hotkey.bind(ca, "e", function()
    if not win then return end
    f.x = max.x + max.w / 4
    f.y = max.y
    f.w = max.w / 2
    f.h = max.h
    win:setFrame(f)
end)
hs.hotkey.bind(ca, "t", function()
    if not win then return end
    f.x = max.x + max.w / 4
    f.y = max.y
    f.w = max.w / 2
    f.h = max.h
    win:setFrame(f)
end)
-- right half
hs.hotkey.bind(ca, "n", function()
    if not win then return end
    f.x = max.x + max.w / 2
    f.y = max.y
    f.w = max.w / 2
    f.h = max.h
    win:setFrame(f)
end)
-- two-thirds
-- left two-thirds
hs.hotkey.bind(ca, "x", function()
    if not win then return end
    f.x = max.x
    f.y = max.y
    f.w = 2 * max.w / 3
    f.h = max.h
    win:setFrame(f)
end)
-- middle two-thirds
hs.hotkey.bind(ca, "i", function()
    if not win then return end
    f.x = max.x + max.w / 6
    f.y = max.y
    f.w = 2 * max.w / 3
    f.h = max.h
    win:setFrame(f)
end)
hs.hotkey.bind(ca, "d", function()
    if not win then return end
    f.x = max.x + max.w / 6
    f.y = max.y
    f.w = 2 * max.w / 3
    f.h = max.h
    win:setFrame(f)
end)
-- thirds
-- left third
hs.hotkey.bind(ca, "j", function()
    if not win then return end
    f.x = max.x
    f.y = max.y
    f.w = max.w / 3
    f.h = max.h
    win:setFrame(f)
end)
-- middle third
hs.hotkey.bind(ca, "k", function()
    if not win then return end
    f.x = max.x + max.w / 3
    f.y = max.y
    f.w = max.w / 3
    f.h = max.h
    win:setFrame(f)
end)
hs.hotkey.bind(ca, "m", function()
    if not win then return end
    f.x = max.x + max.w / 3
    f.y = max.y
    f.w = max.w / 3
    f.h = max.h
    win:setFrame(f)
end)
-- right third
hs.hotkey.bind(ca, "w", function()
    if not win then return end
    f.x = max.x + 2 * max.w / 3
    f.y = max.y
    f.w = max.w / 3
    f.h = max.h
    win:setFrame(f)
end)
-- fourths
-- top left
hs.hotkey.bind(ca, ",", function()
    if not win then return end
    f.x = max.x
    f.y = max.y
    f.w = max.w / 2
    f.h = max.h / 2
    win:setFrame(f)
end)
-- top right
hs.hotkey.bind(ca, "r", function()
    if not win then return end
    f.x = max.x + max.w / 2
    f.y = max.y
    f.w = max.w / 2
    f.h = max.h / 2
    win:setFrame(f)
end)
-- bottom right
hs.hotkey.bind(ca, "v", function()
    if not win then return end
    f.x = max.x + max.w / 2
    f.y = max.y + max.h / 2
    f.w = max.w / 2
    f.h = max.h / 2
    win:setFrame(f)
end)
-- bottom left
hs.hotkey.bind(ca, "q", function()
    if not win then return end
    f.x = max.x
    f.y = max.y + max.h / 2
    f.w = max.w / 2
    f.h = max.h / 2
    win:setFrame(f)
end)