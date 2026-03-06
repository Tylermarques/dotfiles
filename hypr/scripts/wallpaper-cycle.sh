#!/bin/bash
# Cycles through wallpapers in ~/Pictures/Wallpaper using awww

WALLPAPER_DIR="$HOME/Pictures/HQ_Wallpaper"
INTERVAL=30

awww-daemon
sleep 1

while true; do
  img="$(find "$WALLPAPER_DIR" -type f \( -name '*.jpg' -o -name '*.jpeg' -o -name '*.png' -o -name '*.webp' \) | shuf -n1)"
  [ -n "$img" ] && awww img "$img" --transition-type center --transition-step 90 --transition-fps 60
  sleep "$INTERVAL"
done
