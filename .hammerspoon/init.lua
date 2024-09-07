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
