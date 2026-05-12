#!/bin/bash

# Find windows that are out of bounds of their monitor and offer a picker to rescue them.

get_oob_windows() {
  python3 <(cat <<'PYEOF'
import json, subprocess

clients = json.loads(subprocess.check_output(["hyprctl", "clients", "-j"]))
monitors = json.loads(subprocess.check_output(["hyprctl", "monitors", "-j"]))

monitor_bounds = {}
for m in monitors:
    monitor_bounds[m["id"]] = {
        "x": m["x"],
        "y": m["y"],
        "w": m["width"] / m["scale"],
        "h": m["height"] / m["scale"],
    }

for c in clients:
    if not c["mapped"] or c["hidden"]:
        continue

    mid = c["monitor"]
    if mid not in monitor_bounds:
        continue

    mb = monitor_bounds[mid]
    wx, wy = c["at"]
    ww, wh = c["size"]

    visible_x = max(0, min(wx + ww, mb["x"] + mb["w"]) - max(wx, mb["x"]))
    visible_y = max(0, min(wy + wh, mb["y"] + mb["h"]) - max(wy, mb["y"]))
    visible_area = visible_x * visible_y
    total_area = ww * wh

    if total_area == 0:
        continue

    # Consider out-of-bounds if less than 20% of the window is visible
    if visible_area / total_area < 0.2:
        title = c["title"] or c["class"] or "unknown"
        # Truncate long titles
        if len(title) > 60:
            title = title[:57] + "..."
        print(f'{c["address"]}|{title} (monitor {mid})')
PYEOF
  )
}

oob_windows=$(get_oob_windows)

if [ -z "$oob_windows" ]; then
  notify-send "Rescue Window" "No out-of-bounds windows found"
  exit 0
fi

labels=$(echo "$oob_windows" | cut -d'|' -f2-)

selected=$(echo "$labels" | rofi -dmenu -i -p "Rescue window")

if [ -z "$selected" ]; then
  exit 0
fi

address=$(echo "$oob_windows" | grep -F "$selected" | head -1 | cut -d'|' -f1)

if [ -z "$address" ]; then
  exit 1
fi

# Get the monitor this window belongs to and center it there
python3 - "$address" <<'PYEOF'
import json, subprocess, sys

address = sys.argv[1]
clients = json.loads(subprocess.check_output(["hyprctl", "clients", "-j"]))
monitors = json.loads(subprocess.check_output(["hyprctl", "monitors", "-j"]))

monitor_bounds = {}
for m in monitors:
    monitor_bounds[m["id"]] = {
        "x": m["x"],
        "y": m["y"],
        "w": m["width"] / m["scale"],
        "h": m["height"] / m["scale"],
    }

for c in clients:
    if c["address"] == address:
        mid = c["monitor"]
        mb = monitor_bounds[mid]
        ww, wh = c["size"]
        cx = int(mb["x"] + (mb["w"] - ww) / 2)
        cy = int(mb["y"] + (mb["h"] - wh) / 2)
        subprocess.run(["hyprctl", "dispatch", "movewindowpixel",
                        f"exact {cx} {cy},address:{address}"])
        subprocess.run(["hyprctl", "dispatch", "focuswindow",
                        f"address:{address}"])
        break
PYEOF
