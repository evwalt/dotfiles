#!/bin/zsh

# Parse args like: 2h 15m 30s OR just "5" (minutes)
parse_time() {
  local total=0 num
  for arg in "$@"; do
    if [[ $arg =~ ^([0-9]+)h$ ]]; then
      num=${match[1]}
      (( total += num * 3600 ))
    elif [[ $arg =~ ^([0-9]+)m$ ]]; then
      num=${match[1]}
      (( total += num * 60 ))
    elif [[ $arg =~ ^([0-9]+)s$ ]]; then
      num=${match[1]}
      (( total += num ))
    elif [[ $arg =~ ^([0-9]+)$ ]]; then
      num=${match[1]}
      (( total += num * 60 ))   # default: minutes if no suffix
    else
      print -u2 "Error: Invalid time '$arg'. Use e.g. 1h 30m 45s or 5 (minutes)."
      return 1
    fi
  done
  echo $total
}

# Require at least one arg
if (( $# == 0 )); then
  echo "Usage: $0 <time...>"
  echo "Examples: $0 5m | $0 90s | $0 1h 30m | $0 5"
  exit 1
fi

seconds=$(parse_time "$@") || exit 1
if (( seconds <= 0 )); then
  echo "Time must be > 0."
  exit 1
fi

# Countdown
while (( seconds > 0 )); do
  mins=$(( seconds / 60 ))
  secs=$(( seconds % 60 ))
  printf "\r%02d:%02d remaining..." "$mins" "$secs"
  sleep 1
  ((seconds--))
done
printf "\r00:00 remaining...\n"
echo "Countdown complete!"

# Finish sound (macOS)
while true; do
  afplay /System/Library/Sounds/Hero.aiff
  sleep 1
done
