#!/bin/zsh
# Re-apply System Settings > Keyboard: Key repeat rate = Off, Delay until repeat = Long.
# macOS keeps resetting these; launchd runs this at every login.
# "Off" is KeyRepeatEnabled=0 in com.apple.Accessibility; "Long" is InitialKeyRepeat=120.
defaults write com.apple.Accessibility KeyRepeatEnabled -int 0
defaults write -g InitialKeyRepeat -float 120
