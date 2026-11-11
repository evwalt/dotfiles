#!/bin/zsh
# Re-apply System Settings > Keyboard: Key repeat rate = Off, Delay until repeat = Long.
# launchd runs this at every login.
# `defaults write` only updates the prefs files; the HID driver keeps its own live
# copy, so it must be set with hidutil too. With repeat Off, the driver shows
# HIDInitialKeyRepeat=0 (no repeat). Applied twice in case login resets it late.
log=/tmp/keyboard-repeat.log

defaults write com.apple.Accessibility KeyRepeatEnabled -int 0
defaults write -g InitialKeyRepeat -float 120

for pass in 1 2; do
  echo "$(date '+%F %T') pass $pass before: $(hidutil property --get HIDInitialKeyRepeat)" >> $log
  hidutil property --set '{"HIDInitialKeyRepeat":0}' > /dev/null
  echo "$(date '+%F %T') pass $pass after:  $(hidutil property --get HIDInitialKeyRepeat)" >> $log
  [[ $pass == 1 ]] && sleep 20
done
