#!/bin/zsh
# Runs inside the tmux cursor-beacon popup (see ~/.config/tmux/tmux.conf client-focus-in).
# Holds tokyonight blue, then fades toward the tokyonight-night background (~0.65s total).
# A popup grabs keyboard input while open, so any keypress ends the beacon at once and
# is forwarded (as raw bytes) to the pane underneath: typing never has to wait.
stty raw -echo
printf '\033[?25l'
for rgb hold in \
  '122;162;247' 0.2 \
  '110;145;221' 0.075 '98;128;195' 0.075 '86;112;169' 0.075 \
  '74;95;143' 0.075 '62;78;116' 0.075 '50;61;90' 0.075; do
  printf '\033[48;2;%sm\033[2J' "$rgb"
  if read -s -k 1 -t "$hold" key; then
    # Collect the rest of a multi-byte key (arrows, Alt-x, UTF-8) or a fast burst.
    while read -s -k 1 -t 0.01 c; do key+=$c; done
    tmux send-keys -H $(printf '%s' "$key" | od -An -tx1)
    exit 0
  fi
done
