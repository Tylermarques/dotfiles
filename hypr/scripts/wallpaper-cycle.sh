#!/bin/bash
# Cycles through wallpapers in ~/Pictures/HQ_Wallpaper using awww

WALLPAPER_DIR="$HOME/Pictures/HQ_Wallpaper"
INTERVAL=3600

# Start the daemon in the background; without '&' bash blocks here forever.
if ! pgrep -x awww-daemon >/dev/null; then
  awww-daemon --no-cache &
  sleep 1
fi

while true; do
  img="$(find "$WALLPAPER_DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | shuf -n1)"
  [ -n "$img" ] && awww img "$img" --transition-type center --transition-step 90 --transition-fps 60
  sleep "$INTERVAL"
done
