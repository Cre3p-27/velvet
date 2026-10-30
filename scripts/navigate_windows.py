#!/usr/bin/env python3
"""
navigate_windows.py — SUPER+CTRL+arrows: jump to the next window in that
direction.

Every jump starts from the window you are ON (the focused one), not from the
middle of the screen: after SUPER+ALT swapped a window away, or after a click
on a window while the desktop was zoomed out, the old version measured from
the screen's middle and skipped windows or went nowhere.

  · a floating target on the infinite canvas: the floating windows glide so
    the target lands in the middle of what you see — zoomed out too
    (SUPER+ALT+wheel), where "the middle" is the middle of the zoomed view
  · a tiled target: it simply gets the focus (the layout put it on screen)
  · a desktop with tiled AND floating windows (SUPER+V floated one): both
    kinds are neighbours, so the keys never go dead
  · only tiled windows: Hyprland's own movefocus (it also crosses screens)
  · past the last window in a direction: round to the far side
  · a STAGE desktop: ↓/→ brings the latest card on stage, ↑/← the oldest
    (services/Stage.qml)

Usage: python3 navigate_windows.py <left|right|up|down>
"""

import json
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hypr_ipc import hyprctl_json, move_focus, move_window_exact_lua, focus_window, batch_async, fixed_classes

DIR_SHORT = {"left": "l", "right": "r", "up": "u", "down": "d"}
OPPOSITE = {"left": "right", "right": "left", "up": "down", "down": "up"}


def stage_desktop(ws_id):
    """Is this desktop a STAGE (scene.workspaceModes in config.json)?"""
    path = os.path.join(os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config"), "velvet", "config.json")
    try:
        with open(path) as f:
            return (json.load(f).get("scene", {}).get("workspaceModes") or {}).get(str(ws_id)) == "stage"
    except (OSError, ValueError, AttributeError):
        return False


def focused_monitor():
    for m in hyprctl_json(["monitors"]) or []:
        if m.get("focused"):
            return m
    return None


def usable_center(m):
    """Middle of the part of the monitor windows can use, in global logical
    pixels: width/height are physical (divided by the scale, swapped when the
    output is turned), minus what the bar reserves."""
    if not m:
        return 960.0, 540.0
    scale = m.get("scale") or 1
    w, h = m["width"] / scale, m["height"] / scale
    if int(m.get("transform") or 0) % 2 == 1:
        w, h = h, w
    left, top, right, bottom = (float(v or 0) for v in (list(m.get("reserved") or []) + [0, 0, 0, 0])[:4])
    return m["x"] + left + (w - left - right) / 2, m["y"] + top + (h - top - bottom) / 2


def zoom_view():
    """The zoom plugin's transform while it is on (screen = t + layout * z),
    else None. Never fails: no plugin, no answer → None."""
    try:
        r = subprocess.run(["hyprctl", "velvetzoom", "status"], capture_output=True, text=True, timeout=0.6)
    except (OSError, subprocess.SubprocessError):
        return None
    m = re.search(r"active=(true|false) z=([0-9.]+).*?shift=(-?[0-9.]+),(-?[0-9.]+)", r.stdout or "")
    if not m or m.group(1) != "true":
        return None
    z = float(m.group(2))
    if z <= 0:
        return None
    return z, float(m.group(3)), float(m.group(4))


def view_center(m):
    """Where the middle of what you see is, in layout coordinates."""
    cx, cy = usable_center(m)
    zv = zoom_view()
    if zv:
        z, tx, ty = zv
        return (cx - tx) / z, (cy - ty) / z
    return cx, cy


def center_of(w):
    return w["at"][0] + w["size"][0] / 2, w["at"][1] + w["size"][1] / 2


def bounds(w):
    x, y = w["at"]
    return x, y, x + w["size"][0], y + w["size"][1]


def overlaps(a, b, axis):
    """Do the boxes share a stretch across the direction of travel?"""
    if axis == "h":   # travelling left/right: share rows
        return not (a[3] <= b[1] or a[1] >= b[3])
    return not (a[2] <= b[0] or a[0] >= b[2])


def along(direction, dx, dy):
    """(distance in the direction, distance across it)"""
    if direction == "left":
        return -dx, abs(dy)
    if direction == "right":
        return dx, abs(dy)
    if direction == "up":
        return -dy, abs(dx)
    return dy, abs(dx)


def neighbour(windows, here, direction):
    """The window next to `here` in `direction`: one sharing its rows (or
    columns) first, the nearest; else the nearest roughly that way; else round
    to the far side."""
    hx, hy = center_of(here)
    hb = bounds(here)
    axis = "h" if direction in ("left", "right") else "v"
    aligned, ahead = [], []
    for w in windows:
        if w["address"] == here["address"]:
            continue
        wx, wy = center_of(w)
        d, side = along(direction, wx - hx, wy - hy)
        if d <= 1:
            continue
        if overlaps(hb, bounds(w), axis):
            aligned.append((d, side, w))
        ahead.append((d + side, d, w))
    if aligned:
        return min(aligned, key=lambda t: (t[0], t[1]))[2]
    if ahead:
        return min(ahead, key=lambda t: (t[0], t[1]))[2]
    # round to the far side: the farthest window the other way, preferring
    # one in the same rows
    back_aligned, back = [], []
    for w in windows:
        if w["address"] == here["address"]:
            continue
        wx, wy = center_of(w)
        d, side = along(OPPOSITE[direction], wx - hx, wy - hy)
        if d <= 1:
            continue
        (back_aligned if overlaps(hb, bounds(w), axis) else back).append((d, -side, w))
    pool = back_aligned or back
    if pool:
        return max(pool, key=lambda t: (t[0], t[1]))[2]
    return None


def bring_to_view(floating, target, vx, vy):
    """Glide every floating window so `target` lands in the middle of the view."""
    tx, ty = center_of(target)
    dx, dy = round(vx - tx), round(vy - ty)
    if dx == 0 and dy == 0:
        return
    batch_async([move_window_exact_lua(int(w["at"][0] + dx), int(w["at"][1] + dy), w["address"]) for w in floating])


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in DIR_SHORT:
        print("usage: navigate_windows.py <left|right|up|down>")
        sys.exit(1)
    direction = sys.argv[1]

    ws = hyprctl_json(["activeworkspace"])
    if not ws:
        sys.exit(1)
    if stage_desktop(ws["id"]):
        step = "1" if direction in ("down", "right") else "-1"
        subprocess.run(["qs", "-c", "velvet", "ipc", "call", "stage", "step", step], capture_output=True, timeout=3)
        return
    fixed = fixed_classes()
    windows = [w for w in (hyprctl_json(["clients"]) or [])
               if w.get("workspace", {}).get("id") == ws["id"] and w.get("mapped", True)
               and not w.get("hidden") and w.get("class") not in fixed]
    floating = [w for w in windows if w.get("floating")]

    # only tiled windows: the layout knows its neighbours (and the screens)
    if not floating:
        move_focus(DIR_SHORT[direction])
        return

    active = hyprctl_json(["activewindow"]) or {}
    here = next((w for w in windows if w["address"] == active.get("address")), None)
    m = focused_monitor()
    vx, vy = view_center(m)

    # nothing focused on this desktop: land on the window nearest the middle
    if here is None:
        target = min(floating, key=lambda w: (center_of(w)[0] - vx) ** 2 + (center_of(w)[1] - vy) ** 2)
        bring_to_view(floating, target, vx, vy)
        focus_window(target["address"])
        return

    target = neighbour(windows, here, direction)
    if target is None:
        # the only window: a floating one off to the side comes back into view
        if here.get("floating"):
            bring_to_view(floating, here, vx, vy)
        return
    if target.get("floating"):
        bring_to_view(floating, target, vx, vy)
    focus_window(target["address"])


if __name__ == "__main__":
    main()
