#!/bin/sh
# Prefix+l / prefix+j / prefix+k with sidecar-aware targets. Usage: pane-nav.sh r|d|u WINDOW_ID PANE_ID
#  r: from a regular pane, go to the tallest @sidecar pane (the big claude pane).
#  d: from a sidecar pane, go to the leftmost sidecar pane directly below it.
#  u: no sidecar target; only the un-expand/un-zoom step below, then select-pane -U.
# Anything else falls back to plain select-pane -R / -D / -U.
# First leaves any zoomed state, so the move works on the real layout: tmux zoom
# (prefix z), sidecar full/hide (prefix Z) and sidecar expand (prefix e) when the
# move stays on the expanded side.
dir=$1 win=$2 cur=$3
IFS=: read -r zoomed full pzoom <<EOF
$(tmux display-message -p -t "$cur" '#{window_zoomed_flag}:#{@sidecar_full}#{@sidecar_hide}:#{@sidecar_pzoom}')
EOF
cur_sc=$(tmux display-message -p -t "$cur" '#{@sidecar}')
[ "$zoomed" = 1 ] && tmux resize-pane -Z -t "$cur"
# Keep an expand when the move leaves its side (e.g. prefix l from the regular
# panes into an expanded sidecar pane); collapse it only for moves within it.
if [ -n "$pzoom" ]; then
  pz_sc=$(tmux display-message -p -t "$pzoom" '#{@sidecar}')
  if [ "$pz_sc" = "$cur_sc" ] && ! { [ "$dir" = r ] && [ "$cur_sc" != 1 ]; }; then
    ~/scripts/sidecar pzoom "$win"
  fi
fi
# Prefix j keeps full/hide: only one side is visible, so the move stays on it.
[ -n "$full" ] && [ "$dir" != d ] && ~/scripts/sidecar full "$win"
panes=$(tmux list-panes -t "$win" -F '#{pane_id} #{@sidecar} #{pane_left} #{pane_top} #{pane_width} #{pane_height}')
p=
if [ "$dir" = r ] && [ "$cur_sc" != 1 ]; then
  p=$(echo "$panes" | awk '$2==1{print $6, $1}' | sort -nr | head -1 | cut -d' ' -f2)
elif [ "$dir" = d ] && [ "$cur_sc" = 1 ]; then
  p=$(echo "$panes" | awk -v c="$cur" '
    $1==c {cl=$3; cr=$3+$5; below=$4+$6+1}
    {id[NR]=$1; sc[NR]=$2; l[NR]=$3; r[NR]=$3+$5; t[NR]=$4}
    END {best=""; for (i=1;i<=NR;i++) if (sc[i]==1 && t[i]==below && l[i]<cr && r[i]>cl && (best=="" || l[i]<bl)) {best=id[i]; bl=l[i]}; print best}')
fi
if [ -n "$p" ]; then tmux select-pane -t "$p"
elif [ "$dir" = r ]; then tmux select-pane -R -t "$cur"
elif [ "$dir" = u ]; then tmux select-pane -U -t "$cur"
else tmux select-pane -D -t "$cur"; fi
