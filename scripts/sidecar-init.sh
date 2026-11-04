#!/bin/zsh
# Started in the background by tmuxinator (on_project_first_start). The sidecar hooks create a
# default group pane on a fresh server; wait for it, add a one-row shell strip under it (for
# `ct`), and leave focus on the regular left pane. Set SIDECAR_SOCK to target a non-default
# tmux server (testing).
t=(tmux); [[ -n $SIDECAR_SOCK ]] && t+=(-L $SIDECAR_SOCK)

pane=
for i in {1..100}; do
  pane=$($t list-panes -a -F '#{pane_id} #{@sidecar}' 2>/dev/null | awk '$2==1{print $1; exit}')
  [[ -n $pane ]] && break
  sleep 0.2
done
[[ -z $pane ]] && exit 1
sleep 1  # let the sidecar finish placing it

strip=$($t split-window -v -l 1 -c "$HOME" -t $pane -P -F '#{pane_id}')
$t set -p -t $strip @sidecar 1

left=$($t list-panes -t $pane -F '#{pane_id} #{@sidecar}' | awk '$2!=1{print $1; exit}')
[[ -n $left ]] && $t select-pane -t $left
