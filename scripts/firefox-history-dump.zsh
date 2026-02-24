#!/usr/bin/env zsh
set -euo pipefail

FIREFOX_DIR="$HOME/Library/Application Support/Firefox/Profiles"
TIMESTAMP="$(date +%Y-%m-%d_%H-%M-%S)"
OUT="$HOME/Library/CloudStorage/Dropbox/bk/firefox-history-$TIMESTAMP.txt"

# clear output each run
: > "$OUT"

# find all `places.sqlite` files and dump history
find "$FIREFOX_DIR" -name "places.sqlite" 2>/dev/null | while read DB; do
  echo "### $DB" >> "$OUT"

  # saf snapshot so that it works even if Firefox is open
  TMP="/tmp/places_copy_$$.sqlite"
  sqlite3 "$DB" ".backup '$TMP'" >/dev/null 2>&1 || continue

  sqlite3 -separator $'\t' "$TMP" "
  select datetime(h.visit_date/1000000,'unixepoch'), p.url
  from moz_historyvisits h
  join moz_places p on p.id=h.place_id
  order by h.visit_date;
  " >> "$OUT"

  rm -f "$TMP"
done

echo "History written to $OUT"
