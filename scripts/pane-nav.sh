#!/bin/sh
# Prefix+l / prefix+j with sidecar-aware targets. Usage: pane-nav.sh r|d WINDOW_ID PANE_ID
#  r: from a regular pane, go to the tallest @sidecar pane (the big claude pane).
#  d: from a sidecar pane, go to the leftmost sidecar pane directly below it.
# Anything else falls back to plain select-pane -R / -D.
# First leaves any zoomed state, so the move works on the real layout: tmux zoom
# (prefix z), sidecar full/hide (prefix Z) and sidecar expand (prefix e).
dir=$1 win=$2 cur=$3
IFS=: read -r zoomed full pzoom <<EOF
$(tmux display-message -p -t "$cur" '#{window_zoomed_flag}:#{@sidecar_full}#{@sidecar_hide}:#{@sidecar_pzoom}')
EOF
[ "$zoomed" = 1 ] && tmux resize-pane -Z -t "$cur"
[ -n "$pzoom" ] && ~/scripts/sidecar pzoom "$win"
[ -n "$full" ] && ~/scripts/sidecar full "$win"
panes=$(tmux list-panes -t "$win" -F '#{pane_id} #{@sidecar} #{pane_left} #{pane_top} #{pane_width} #{pane_height}')
cur_sc=$(echo "$panes" | awk -v c="$cur" '$1==c{print $2}')
p=
if [ "$dir" = r ] && [ "$cur_sc" != 1 ]; then
  p=$(echo "$panes" | awk '$2==1{print $6, $1}' | sort -nr | head -1 | cut -d' ' -f2)
elif [ "$dir" = d ] && [ "$cur_sc" = 1 ]; then
  p=$(echo "$panes" | awk -v c="$cur" '
    $1==c {cl=$3; cr=$3+$5; below=$4+$6+1}
    {id[NR]=$1; sc[NR]=$2; l[NR]=$3; r[NR]=$3+$5; t[NR]=$4}
    END {best=""; for (i=1;i<=NR;i++) if (sc[i]==1 && t[i]==below && l[i]<cr && r[i]>cl && (best=="" || l[i]<bl)) {best=id[i]; bl=l[i]}; print best}')
fi
if [ -n "$p" ]; then tmux select-pane -t "$p"; elif [ "$dir" = r ]; then tmux select-pane -R -t "$cur"; else tmux select-pane -D -t "$cur"; fi
