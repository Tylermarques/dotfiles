#!/usr/bin/env python3
"""Pull newly-mapped windows back on screen.

XWayland exposes a single rectangular root window spanning the bounding box of
every output. When the monitor layout is not itself a rectangle the leftover
region is addressable but not visible, and X11 clients that place dialogs from
root geometry drop them in there. This watches Hyprland's socket2 event stream
and moves any window that maps (almost) entirely outside every monitor back
onto its own output.

Run with --once to scan and fix the current windows instead of watching.
"""
import asyncio
import json
import os
import subprocess
import sys

VISIBLE_THRESHOLD = 0.20           # rescue anything showing less than this
RECHECK_DELAYS = (0.15, 0.6, 1.5)  # X11 clients often reposition after mapping


def log(msg):
    print(f"[keep-onscreen] {msg}", file=sys.stderr, flush=True)


def norm(addr):
    """socket2 reports addresses bare, hyprctl reports them 0x-prefixed."""
    return addr.lower().removeprefix("0x")


def hyprctl_json(*args):
    out = subprocess.run(("hyprctl", *args, "-j"), capture_output=True, text=True)
    return json.loads(out.stdout)


def monitor_rects():
    """Logical bounds per monitor id, honouring rotation, scale and reserved insets."""
    rects = {}
    for m in hyprctl_json("monitors"):
        w, h = m["width"] / m["scale"], m["height"] / m["scale"]
        if m["transform"] % 2 == 1:  # 90/270 degree rotations swap the axes
            w, h = h, w
        w, h = round(w), round(h)
        left, top, right, bottom = m["reserved"]
        rects[m["id"]] = {
            "x": m["x"], "y": m["y"], "w": w, "h": h,
            "ux": m["x"] + left, "uy": m["y"] + top,
            "uw": w - left - right, "uh": h - top - bottom,
        }
    return rects


def visible_fraction(win, rects):
    x, y = win["at"]
    w, h = win["size"]
    if w <= 0 or h <= 0:
        return 1.0
    seen = 0
    for r in rects.values():
        ix = max(0, min(x + w, r["x"] + r["w"]) - max(x, r["x"]))
        iy = max(0, min(y + h, r["y"] + r["h"]) - max(y, r["y"]))
        seen += ix * iy
    return seen / (w * h)


def rescue(addr):
    """Centre the window on its own monitor if it is effectively invisible."""
    rects = monitor_rects()
    win = next((c for c in hyprctl_json("clients")
                if norm(c["address"]) == norm(addr) and c["mapped"] and not c["hidden"]),
               None)
    if win is None:
        return False

    frac = visible_fraction(win, rects)
    if frac >= VISIBLE_THRESHOLD:
        return False

    if not win["floating"]:
        # Tiled windows are placed by the layout; moving them fights Hyprland.
        log(f"tiled window offscreen, left alone: {win['class']!r} {win['title']!r}")
        return False

    r = rects.get(win["monitor"]) or next(iter(rects.values()))
    ww, wh = win["size"]
    cx = int(r["ux"] + max(0, r["uw"] - ww) / 2)
    cy = int(r["uy"] + max(0, r["uh"] - wh) / 2)
    subprocess.run(["hyprctl", "dispatch", "movewindowpixel",
                    f"exact {cx} {cy},address:{win['address']}"],
                   capture_output=True)
    log(f"rescued {win['class']!r} {win['title']!r} at {frac:.0%} visible -> ({cx},{cy})")
    return True


async def on_open(addr):
    try:
        for delay in RECHECK_DELAYS:
            await asyncio.sleep(delay)
            if await asyncio.to_thread(rescue, addr):
                return
    except Exception as exc:  # a stray failure must not kill the watcher
        log(f"check failed for {addr}: {exc!r}")


async def read_events(pending):
    his = os.environ["HYPRLAND_INSTANCE_SIGNATURE"]
    sock = f"{os.environ['XDG_RUNTIME_DIR']}/hypr/{his}/.socket2.sock"
    reader, writer = await asyncio.open_unix_connection(sock)
    log(f"watching {sock}")
    try:
        while True:
            line = await reader.readline()
            if not line:
                log("socket2 closed by compositor")
                return
            event, _, data = line.decode(errors="replace").strip().partition(">>")
            if os.environ.get("KWO_DEBUG"):
                log(f"event {event}")
            if event == "openwindow":
                task = asyncio.create_task(on_open(data.split(",")[0]))
                pending.add(task)  # asyncio keeps only weak refs to running tasks
                task.add_done_callback(pending.discard)
    finally:
        writer.close()


async def watch():
    """Follow socket2, reconnecting if the compositor drops us."""
    pending = set()
    delay = 1
    while True:
        try:
            await read_events(pending)
            delay = 1
        except (OSError, KeyError) as exc:
            log(f"connection failed: {exc!r}")
            delay = min(delay * 2, 30)
        await asyncio.sleep(delay)


def scan_once():
    rects = monitor_rects()
    stranded = [c for c in hyprctl_json("clients")
                if c["mapped"] and not c["hidden"]
                and visible_fraction(c, rects) < VISIBLE_THRESHOLD]
    fixed = sum(rescue(c["address"]) for c in stranded)
    log(f"scan complete: {len(stranded)} offscreen, {fixed} rescued")


if __name__ == "__main__":
    if "--once" in sys.argv:
        scan_once()
    else:
        asyncio.run(watch())
