#!/bin/bash

# Display brightness configuration
# Format: device_name:dim_value:bright_value
DISPLAY_CONFIG=(
  "ddcci2:20:50" # LG ULTRAFINE
  "ddcci3:5:45"  # DELL U2412M (DP-1)
  "ddcci4:5:45"  # DELL U2412M (DP-2)
  "ddcci5:20:50" # AOC U34G2G4R3
)

# Function to set brightness for all displays
set_brightness() {
  local mode=$1
  local pids=()

  for config in "${DISPLAY_CONFIG[@]}"; do
    IFS=':' read -r device dim bright <<<"$config"

    if [ "$mode" == "dim" ]; then
      value=$dim
    elif [ "$mode" == "brighten" ]; then
      value=$bright
    else
      echo "Invalid mode: $mode"
      echo "Usage: $0 {dim|brighten}"
      exit 1
    fi

    echo "Setting $device to $value%"
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
  echo "Usage: $0 {dim|brighten}"
  exit 1
fi

case "$1" in
dim)
  set_brightness "dim"
  ;;
brighten)
  set_brightness "brighten"
  ;;
*)
  echo "Invalid argument: $1"
  echo "Usage: $0 {dim|brighten}"
  exit 1
  ;;
esac
