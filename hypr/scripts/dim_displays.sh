#!/bin/bash

# Display brightness configuration
# Format: device_name:morning:day:evening:night:dim
DISPLAY_CONFIG=(
  "ddcci2:50:50:50:50:20" # LG ULTRAFINE
  "ddcci3:45:45:45:45:5"  # DELL U2412M (DP-1)
  "ddcci4:45:45:45:45:5"  # DELL U2412M (DP-2)
  "ddcci5:80:80:80:50:20" # AOC U34G2G4R3
)

USAGE="Usage: $0 {dim|brighten|morning|day|evening|night}"

# Determine time period based on current hour
get_time_period() {
  local hour=$(date +%H)
  if ((hour >= 6 && hour < 10)); then
    echo "morning"
  elif ((hour >= 10 && hour < 17)); then
    echo "day"
  elif ((hour >= 17 && hour < 20)); then
    echo "evening"
  else
    echo "night"
  fi
}

# Function to set brightness for all displays
set_brightness() {
  local mode=$1
  local pids=()

  for config in "${DISPLAY_CONFIG[@]}"; do
    IFS=':' read -r device morning day evening night dim <<<"$config"

    case "$mode" in
    dim) value=$dim ;;
    morning) value=$morning ;;
    day) value=$day ;;
    evening) value=$evening ;;
    night) value=$night ;;
    *)
      echo "Invalid mode: $mode"
      echo "$USAGE"
      exit 1
      ;;
    esac

    echo "Setting $device to $value% ($mode)"
    brightnessctl --device="$device" set "$value%" &
    pids+=($!)
  done

  # Wait for all background processes to complete
  for pid in "${pids[@]}"; do
    wait "$pid"
  done
}

# Main script
if [ $# -ne 1 ]; then
  echo "$USAGE"
  exit 1
fi

case "$1" in
dim | morning | day | evening | night)
  set_brightness "$1"
  ;;
brighten)
  period=$(get_time_period)
  echo "Auto-detected time period: $period"
  set_brightness "$period"
  ;;
*)
  echo "Invalid argument: $1"
  echo "$USAGE"
  exit 1
  ;;
esac
