#!/usr/bin/env zsh
set -euo pipefail

FIREFOX_DIR="$HOME/Library/Application Support/Firefox"

PROFILE_PATH="$(
  awk -F= '
    /^\[Install/ { in_install=1; next }
    /^\[/        { in_install=0 }
    in_install && /^Default=/ {
      sub(/^Default=/, "")
      print
      exit
    }
  ' "$FIREFOX_DIR/profiles.ini"
)"

DB="$FIREFOX_DIR/$PROFILE_PATH/places.sqlite"
OUT_DIR="$PWD"

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
