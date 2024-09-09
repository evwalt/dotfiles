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
--                   ldur
-- halves (top):    oeui dhtn
-- thirds (top):     
-- fourths:          
local ca = {"ctrl", "alt"}
local win = hs.window.focusedWindow()
local f = win:frame()
local screen = win:screen()
local max = screen:frame()
-- halves (home):    oeui dhtn
hs.hotkey.bind(ca, "o", function()
    if not win then return end
    f.x = max.x
    f.y = max.y
    f.w = max.w / 2
    f.h = max.h
    win:setFrame(f)
end)
hs.hotkey.bind(ca, "e", function()
    if not win then return end
    f.x = max.x
    f.y = max.y + max.h / 2
    f.w = max.w
    f.h = max.h / 2
    win:setFrame(f)
end)
hs.hotkey.bind(ca, "u", function()
    if not win then return end
    f.x = max.x / 2
    f.y = max.y / 2
    f.w = max.w
    f.h = max.h / 2
    win:setFrame(f)
end)
hs.hotkey.bind(ca, "i", function()
    if not win then return end
    f.x = max.x + max.w / 2
    f.y = max.y
    f.w = max.w / 2
    f.h = max.h
    win:setFrame(f)
end)
hs.hotkey.bind(ca, "d", function()
    if not win then return end
    f.x = max.x
    f.y = max.y
    f.w = max.w / 2
    f.h = max.h
    win:setFrame(f)
end)
hs.hotkey.bind(ca, "h", function()
    if not win then return end
    f.x = max.x
    f.y = max.y + max.h / 2
    f.w = max.w
    f.h = max.h / 2
    win:setFrame(f)
end)
hs.hotkey.bind(ca, "t", function()
    if not win then return end
    f.x = max.x / 2
    f.y = max.y / 2
    f.w = max.w
    f.h = max.h / 2
    win:setFrame(f)
end)
hs.hotkey.bind(ca, "n", function()
    if not win then return end
    f.x = max.x + max.w / 2
    f.y = max.y
    f.w = max.w / 2
    f.h = max.h
    win:setFrame(f)
end)
-- fourths: qk,p mvgr
hs.hotkey.bind(ca, "q", function()
    if not win then return end
    f.x = max.x
    f.y = max.y + max.h / 2
    f.w = max.w / 2
    f.h = max.h / 2
    win:setFrame(f)
end)
hs.hotkey.bind(ca, "k", function()
    if not win then return end
    f.x = max.x
    f.y = max.y + max.h / 2
    f.w = max.w / 2
    f.h = max.h / 2
    win:setFrame(f)
end)