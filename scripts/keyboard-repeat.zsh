#!/bin/zsh
# Re-apply System Settings > Keyboard: Key repeat rate = Off at every login (run by launchd,
# ~/Library/LaunchAgents/com.evan.keyboard-repeat.plist).
# Writing prefs directly (defaults write / hidutil) never stuck, so this drives the real
# slider through the UI via keyboard-repeat-ui.applescript. That needs zsh/osascript
# allowed in System Settings > Privacy & Security > Accessibility.

# Give the login session time to finish loading before opening System Settings.
sleep 15
# Only errors are logged.
/usr/bin/osascript /Users/evan/scripts/keyboard-repeat-ui.applescript > /dev/null 2>> /tmp/keyboard-repeat.log
