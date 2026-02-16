#!/bin/zsh

# Initialize defaults
label="Countdown"
end_msg="Countdown complete!"
time_args=()

# Parse Arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -m|--message) label="$2"; shift 2 ;;
    -e|--end)     end_msg="$2"; shift 2 ;;
    *)            time_args+=("$1"); shift ;;
  esac
done

# Parse args like: 2h 15m 30s OR just "5" (minutes)
parse_time() {
  local total=0 num
  for arg in "$@"; do
    if [[ $arg =~ ^([0-9]+)h$ ]]; then
      num=${match}
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
if (( ${#time_args} == 0 )); then
  echo "Usage: ct <time> [-m message] [-e end_message]"
  echo "Examples:"
  echo "  ct 30m -m \"DSA\""
  echo "  ct 50m -e \"Laundry\""
  echo "  ct 50m"
  echo "  ct 90s"
  echo "  ct 1h 30m"
  exit 1
fi

seconds=$(parse_time "${time_args[@]}") || exit 1

if (( seconds <= 0 )); then
  echo "Time must be > 0."
  exit 1
fi

# Countdown Loop
while (( seconds > 0 )); do
  mins=$(( seconds / 60 ))
  secs=$(( seconds % 60 ))
  printf "\r%s %02d:%02d remaining..." "$label" "$mins" "$secs"
  sleep 1
  ((seconds--))
done
printf "\r%s 00:00 remaining... %s" "$label" "$end_msg"

# Finish sound (macOS) - plays for 30 minutes or until Ctrl+C
# 1800 seconds = 30 minutes
alert_duration=1800
alert_end=$(( $(date +%s) + alert_duration ))

while (( $(date +%s) < alert_end )); do
  afplay /System/Library/Sounds/Hero.aiff
  sleep 1
done
