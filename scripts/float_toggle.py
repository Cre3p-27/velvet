#!/usr/bin/env python3
"""
float_toggle.py — SUPER+V: float the window ⇄ put it back in the tiles.

Hyprland's own toggle let a tiled window float at its tiled size — on a
desktop with one window that is the whole screen, so "floating" changed
nothing you could see. Here a window that would float over most of the
screen gets the size of a new floating window (DESKTOP → NEW FLOATING
WINDOWS, 60 % by default) and lands in the middle of what you see — zoomed
out too. A window that floats at a size of its own (a dialog, one you sized
before) keeps it, and is only brought back into view when it is off screen.

A FLOATING desktop (DESKTOP → WINDOWS ON DESKTOP n) asks the same of every
window that opens on it: `--fit` brings a window that came up over most of
the screen down to that size, once it has settled (kitty and browsers put
back their last size a moment AFTER they open, past Hyprland's size rule).

Usage: python3 float_toggle.py [address]
       python3 float_toggle.py --fit <address> [<address> …]
"""

import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hypr_ipc import hyprctl_json, dispatch, batch
from navigate_windows import focused_monitor, usable_center, zoom_view

CONFIG = os.path.join(os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config"), "velvet", "config.json")


def float_share():
    """DESKTOP → NEW FLOATING WINDOWS: a share of the screen, 0 = the app's own size."""
    try:
        with open(CONFIG) as f:
            v = json.load(f).get("scene", {}).get("floatSize", 60)
        return max(0, min(95, int(v)))
    except (OSError, ValueError, TypeError, AttributeError):
        return 60


def usable(m):
    scale = m.get("scale") or 1
    w, h = m["width"] / scale, m["height"] / scale
    if int(m.get("transform") or 0) % 2 == 1:
        w, h = h, w
    left, top, right, bottom = (float(v or 0) for v in (list(m.get("reserved") or []) + [0, 0, 0, 0])[:4])
    return m["x"] + left, m["y"] + top, w - left - right, h - top - bottom


def client(addr):
    return next((c for c in hyprctl_json(["clients"]) or [] if c["address"] == addr), None)


def view_middle(m):
    """The middle of what you see, in layout coordinates (zoomed out: the
    zoomed view's middle)."""
    cx, cy = usable_center(m)
    zv = zoom_view()
    if zv:
        z, tx, ty = zv
        cx, cy = (cx - tx) / z, (cy - ty) / z
    return cx, cy, zv is not None


def fit(now, m, share, always_center=False):
    """Bring a floating window that covers most of the screen down to `share`
    and into the middle; a smaller one stays as it is unless it is off screen."""
    addr = now["address"]
    ux, uy, uw, uh = usable(m)
    w, h = now["size"]
    exprs = []
    big = w * h > uw * uh * 0.55 or w > uw * 0.9 or h > uh * 0.9
    if big and share > 0:
        w, h = round(uw * share / 100), round(uh * share / 100)
        exprs.append(f'hl.dsp.window.resize({{ window = "address:{addr}", x = {w}, y = {h}, relative = false }})')
    cx, cy, zoomed = view_middle(m)
    x, y = now["at"]
    off_screen = x + w < ux + 40 or y + h < uy + 40 or x > ux + uw - 40 or y > uy + uh - 40
    if big or off_screen or (always_center and zoomed):
        exprs.append(f'hl.dsp.window.move({{ window = "address:{addr}", x = {round(cx - w / 2)}, y = {round(cy - h / 2)}, relative = false }})')
    if exprs:
        batch(exprs)
    return bool(exprs)


def settle(addr, wait=0.9):
    """The window once it floats and its size has held still for a moment."""
    last, still, t0 = None, 0, time.time()
    while time.time() - t0 < wait:
        c = client(addr)
        if not c:
            return None
        g = (c.get("floating"), tuple(c["at"]), tuple(c["size"]))
        still = still + 1 if g == last else 0
        last = g
        if c.get("floating") and still >= 3:
            return c
        time.sleep(0.04)
    c = client(addr)
    return c if c and c.get("floating") else None


def fit_new(addrs):
    share = float_share()
    if share <= 0:
        return
    m = focused_monitor()
    if not m:
        return
    for a in addrs:
        c = settle(a)
        if not c or c.get("pinned"):
            continue
        # an app that maximizes itself as it opens (1) floats like the rest;
        # real fullscreen (2, a game, a video) is left alone
        if c.get("fullscreen") == 1:
            dispatch(f'hl.dsp.window.fullscreen_state({{ window = "address:{a}", internal = 0, client = 0 }})')
            c = settle(a)
            if not c:
                continue
        if not c.get("fullscreen"):
            fit(c, m, share)


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--fit":
        fit_new(sys.argv[2:])
        return
    win = None
    if len(sys.argv) > 1:
        win = client(sys.argv[1])
    else:
        win = hyprctl_json(["activewindow"])
    if not win or not win.get("address"):
        return
    addr = win["address"]
    was_floating = bool(win.get("floating"))
    dispatch(f'hl.dsp.window.float({{ action = "toggle", window = "address:{addr}" }})')
    if was_floating:
        return

    m = focused_monitor()
    if not m:
        return
    # the window as Hyprland floated it (a remembered floating size comes back here)
    now = None
    for _ in range(8):
        now = client(addr)
        if now and now.get("floating"):
            break
        time.sleep(0.02)
    if now and now.get("floating"):
        fit(now, m, float_share(), always_center=True)


if __name__ == "__main__":
    main()
