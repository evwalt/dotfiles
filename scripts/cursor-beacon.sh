#!/bin/sh
# Runs inside the tmux cursor-beacon popup (see ~/.config/tmux/tmux.conf client-focus-in).
# Holds tokyonight blue, then fades toward the tokyonight-night background (~0.65s total).
printf '\033[?25l\033[48;2;122;162;247m\033[2J'
sleep 0.2
for rgb in '110;145;221' '98;128;195' '86;112;169' '74;95;143' '62;78;116' '50;61;90'; do
  printf '\033[48;2;%sm\033[2J' "$rgb"
  sleep 0.075
done
