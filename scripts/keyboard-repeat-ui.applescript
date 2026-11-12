-- Set System Settings > Keyboard > Key repeat rate to Off by moving the slider through the UI.
-- Writing prefs directly (defaults/hidutil) did not stick at login; the real control does.
-- Requires Accessibility permission for whatever runs this (osascript under launchd).
do shell script "open 'x-apple.systempreferences:com.apple.Keyboard-Settings.extension'"
tell application "System Events"
	repeat 40 times
		if exists process "System Settings" then exit repeat
		delay 0.5
	end repeat
	tell process "System Settings"
		set s to missing value
		repeat 40 times
			try
				set es to entire contents of window 1
				repeat with e in es
					try
						if ((role of e) as string) = "AXSlider" and ((description of e) as string) = "Key repeat rate" then
							set s to contents of e
							exit repeat
						end if
					end try
				end repeat
			end try
			if s is not missing value then exit repeat
			delay 0.5
		end repeat
		if s is missing value then error "Key repeat rate slider not found"
		-- Nudge up then back down so the change is actually applied, even if it already reads Off.
		perform action "AXIncrement" of s
		delay 0.5
		repeat 20 times
			if (value of s as real) is 0 then exit repeat
			perform action "AXDecrement" of s
			delay 0.3
		end repeat
		set v to value of s as string
	end tell
end tell
tell application "System Settings" to quit
return "Key repeat rate now " & v
