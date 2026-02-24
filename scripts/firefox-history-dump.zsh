#!/usr/bin/env zsh
set -euo pipefail

[[ -f "$HOME/scripts/.env.local" ]] && source "$HOME/scripts/.env.local"

DB="${FIREFOX_PLACES_DB:?Set FIREFOX_PLACES_DB in ~/.env.local}"
OUT_DIR="${FIREFOX_HISTORY_OUT_DIR:?Set FIREFOX_HISTORY_OUT_DIR in ~/.env.local}"

TIMESTAMP="$(date +%Y-%m-%d_%H-%M-%S)"
OUT="$OUT_DIR/firefox-history-$TIMESTAMP.txt"

: > "$OUT"

echo "### firefox-history-export" >> "$OUT"

TMP="/tmp/places_copy_$$.sqlite"
sqlite3 -cmd ".timeout 10000" "$DB" ".backup '$TMP'"

sqlite3 -cmd ".timeout 10000" -separator $'\t' "$TMP" "
select datetime(h.visit_date/1000000,'unixepoch'), p.url
from moz_historyvisits h
join moz_places p on p.id=h.place_id
order by h.visit_date;
" >> "$OUT"

rm -f "$TMP"

echo "History written to $OUT"
