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
-- halves (home):    oeui dhtn
-- fourths (bottom): qjkx bmwv
-- thirds (top):     ,.py fgcr
local ca = {"ctrl", "alt"}
-- halves (home):    oeui dhtn
-- hs.hotkey.bind(ca, "o", function()
--     local win = hs.window.focusedWindow()
--     if not win then return end -- Make sure there is a focused window
--     local f = win:frame()
--     local screen = win:screen()
--     local max = screen:frame()
--     f.x = max.x
--     f.y = max.y
--     f.w = max.w / 2
--     f.h = max.h
--     win:setFrame(f)
-- end)

hs.hotkey.bind(ca, "o", function()
    local win = hs.window.focusedWindow()
    if win then
        win:moveToUnit(hs.layout.left50) -- Move window to the left half
    end
end)

-- hs.hotkey.bind(ca, "o", function()
--     local win = hs.window.focusedWindow()
--     if not win then return end -- Make sure there is a focused window
--     local screen = win:screen()
--     local max = screen:frame()
--     win:setFrame(hs.geometry.rect(max.x, max.y, max.w / 2, max.h))
-- end)

-- hs.hotkey.bind(ca, "o", function()
--     local win = hs.window.focusedWindow()
--     if not win then
--         hs.alert.show("No focused window")
--         return
--     end
--     local screen = win:screen()
--     local max = screen:frame()
--     win:setFrame(hs.geometry.rect(max.x, max.y, max.w / 2, max.h))
--     hs.alert.show("Snapped to left half")
-- end)
