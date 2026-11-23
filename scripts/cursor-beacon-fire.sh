#!/bin/zsh
# Flash the cursor beacon (~/scripts/cursor-beacon.sh) at the cursor of a client's active pane.
# Arg: tmux client name; default is the most recently active client (Hammerspoon calls it bare).
# The client and pane are targeted explicitly because a command run outside any client
# resolves formats against tmux's "best" session, which right after a sidecar move is the
# hidden _sidecar_pstash session, so the beacon landed at the wrong pane.
T=/usr/local/bin/tmux
read -r c s <<<"$($T list-clients -F '#{client_activity} #{client_name} #{client_session}' |
  sort -rn | awk -v want="$1" 'want == "" || $2 == want { print $2, $3; exit }')"
[[ -n $c ]] || exit 0
p=$($T display -p -t "$s:" '#{pane_id}')
# Popup -y is the popup's bottom row, so bottom = cursor row + 1.
exec $T display-popup -c "$c" -t "$p" -B -E -s "bg=#b1b9f9" -w 5 -h 3 \
  -x "#{e|-:#{e|+:#{pane_left},#{cursor_x}},2}" \
  -y "#{e|+:#{e|+:#{pane_top},#{cursor_y}},1}" \
  ~/scripts/cursor-beacon.sh
