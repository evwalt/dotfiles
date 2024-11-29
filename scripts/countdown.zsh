#!/bin/zsh

# Check for args
if [ -z "$1" ]; then
    echo "Usage: $0 <seconds>"
    exit 1
fi

# Get countdown duration from first arg
seconds=$1

# Validate that the arg is a positive number
if ! [[ "$seconds" =~ ^[0-9]+$ ]]; then
    echo "Error: Please provide a valid positive number."
    exit 1
fi

# Countdown loop
while [ $seconds -gt 0 ]; do
    echo "$seconds seconds remaining..."
    sleep 1
    ((seconds--))
done

echo "Countdown complete!"

# Play sound when finished
while true; do
    afplay /System/Library/Sounds/Hero.aiff
    sleep 1
done