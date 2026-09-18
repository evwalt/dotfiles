#!/bin/zsh

# Usage:
#   ct <time>                  # countdown by duration
#   ct -t <HHMM>               # countdown until exact clock time
#   ct -t <HHMMSS>             # countdown until clock time with seconds
#
# Examples:
#   ct 30m                     # 30 minutes
#   ct 90s                     # 90 seconds
#   ct 1h 30m                  # 1 hour 30 minutes
#   ct -t 1100                 # until 11:00:00 AM
#   ct -t 1430                 # until 2:30:00 PM
#   ct -t 110030               # until 11:00:30 AM
#
# Options:
#   -m "message"               # countdown label
#   -e "message"               # completion message
#
# Examples with options:
#   ct 30m -m "DSA"
#   ct -t 1100 -m "DSA"
#   ct -t 1100 -e "Time to stop"
#
# -t uses 24-hour HHMM or HHMMSS. If seconds are omitted, they default
# to 00. If the time has already passed today, it counts down to
# that time tomorrow.

# Initialize defaults
label="Countdown"
end_msg="Countdown complete!"
time_args=()
target_time=""

# Parse Arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -m|--message) label="$2"; shift 2 ;;
    -e|--end)     end_msg="$2"; shift 2 ;;
    -t|--time)    target_time="$2"; shift 2 ;;
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

# Parse target clock time like: 1100, 0930, or 110030
parse_target_time() {
  local target="$1"

  if [[ ! $target =~ ^[0-9]{4}([0-9]{2})?$ ]]; then
    print -u2 "Error: Invalid target time '$target'. Use HHMM or HHMMSS, e.g. 1100 or 110030."
    return 1
  fi

  local hour=${target[1,2]}
  local minute=${target[3,4]}
  local second="00"

  if (( ${#target} == 6 )); then
    second=${target[5,6]}
  fi

  if (( 10#$hour > 23 || 10#$minute > 59 || 10#$second > 59 )); then
    print -u2 "Error: Invalid target time '$target'."
    return 1
  fi

  local now=$(date +%s)
  local target_epoch=$(date -j -f "%Y-%m-%d %H:%M:%S" \
    "$(date +%Y-%m-%d) $hour:$minute:$second" +%s)

  # If that time already passed today, use tomorrow
  if (( target_epoch <= now )); then
    target_epoch=$(date -j -v+1d -f "%Y-%m-%d %H:%M:%S" \
      "$(date +%Y-%m-%d) $hour:$minute:$second" +%s)
  fi

  echo $(( target_epoch - now ))
}

# Require either a duration or target time
if (( ${#time_args} == 0 )) && [[ -z $target_time ]]; then
  echo "Usage: ct <time> [-m message] [-e end_message]"
  echo "       ct -t <HHMM|HHMMSS> [-m message] [-e end_message]"
  echo "Examples:"
  echo "  ct 30m -m \"DSA\""
  echo "  ct 50m -e \"Laundry\""
  echo "  ct 50m"
  echo "  ct 90s"
  echo "  ct 1h 30m"
  echo "  ct -t 1100"
  echo "  ct -t 110030"
  echo "  ct -t 1430 -m \"DSA\""
  exit 1
fi

if [[ -n $target_time ]]; then
  if (( ${#time_args} > 0 )); then
    echo "Error: Use either a duration or -t, not both."
    exit 1
  fi
  seconds=$(parse_target_time "$target_time") || exit 1
else
  seconds=$(parse_time "${time_args[@]}") || exit 1
fi

if (( seconds <= 0 )); then
  echo "Time must be > 0."
  exit 1
fi

# Show duration and end time
end_epoch=$(( $(date +%s) + seconds ))
hours=$(( seconds / 3600 ))
mins=$(( (seconds % 3600) / 60 ))
secs=$(( seconds % 60 ))

printf "Timer: %02d:%02d:%02d → %s\n" \
  "$hours" "$mins" "$secs" "$(date -r $end_epoch '+%I:%M:%S %p')"

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
