#!/usr/bin/env python3
"""
stage.py — the Hyprland half of STAGE desktops (services/Stage.qml).

On a STAGE desktop one window stands in the middle (on stage); the others wait
in the wings, a hidden special workspace, and show as tilted cards in a strip
at the screen's edge (modules/stage/StageStrip.qml).

  stage.py place <addr> <share>               float it, size it to <share> % of
                                              the usable screen, centre, focus
  stage.py swap <ws> <in> <out|-> <share>     <out> to the wings, <in> on stage
  stage.py park <addr>…                       to the wings
  stage.py unpark <ws> <addr>…                back onto desktop <ws>

The usable screen is what the bar and the strip leave (their reserved space).
"""

import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hypr_ipc import hyprctl_json, batch, dispatch

WINGS = "special:vstage"


def client(addr):
    return next((c for c in hyprctl_json(["clients"]) or [] if c["address"] == addr), None)


def monitor_of(c):
    mons = hyprctl_json(["monitors"]) or []
    return next((m for m in mons if m.get("id") == c.get("monitor")), None) or next((m for m in mons if m.get("focused")), None)


def usable(m):
    scale = m.get("scale") or 1
    w, h = m["width"] / scale, m["height"] / scale
    if int(m.get("transform") or 0) % 2 == 1:
        w, h = h, w
    left, top, right, bottom = (float(v or 0) for v in (list(m.get("reserved") or []) + [0, 0, 0, 0])[:4])
    return m["x"] + left, m["y"] + top, w - left - right, h - top - bottom


def settle(addr, wait=0.9):
    """The window once its size has held still for a moment (apps put back
    their last size just after they open)."""
    last, still, t0 = None, 0, time.time()
    while time.time() - t0 < wait:
        c = client(addr)
        if not c:
            return None
        g = (c.get("floating"), tuple(c["at"]), tuple(c["size"]), c.get("fullscreen"))
        still = still + 1 if g == last else 0
        last = g
        if still >= 3:
            return c
        time.sleep(0.04)
    return client(addr)


def place(addr, share):
    c = settle(addr)
    if not c or c.get("pinned") or c.get("fullscreen") == 2:
        return
    w_ = f'"address:{addr}"'
    if c.get("fullscreen") == 1:
        dispatch(f"hl.dsp.window.fullscreen_state({{ window = {w_}, internal = 0, client = 0 }})")
    exprs = []
    if not c.get("floating"):
        exprs.append(f"hl.dsp.window.float({{ window = {w_}, action = \"enable\" }})")
    m = monitor_of(c)
    if m:
        ux, uy, uw, uh = usable(m)
        w, h = round(uw * share / 100), round(uh * share / 100)
        exprs.append(f"hl.dsp.window.resize({{ window = {w_}, x = {w}, y = {h}, relative = false }})")
        exprs.append(f"hl.dsp.window.move({{ window = {w_}, x = {round(ux + (uw - w) / 2)}, y = {round(uy + (uh - h) / 2)}, relative = false }})")
    exprs.append(f"hl.dsp.focus({{ window = {w_} }})")
    batch(exprs)


def park(addrs):
    batch([f'hl.dsp.window.move({{ window = "address:{a}", workspace = "{WINGS}", follow = false }})' for a in addrs])


def unpark(ws, addrs):
    batch([f'hl.dsp.window.move({{ window = "address:{a}", workspace = {int(ws)}, follow = false }})' for a in addrs])


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    cmd, args = sys.argv[1], sys.argv[2:]
    if cmd == "place" and len(args) >= 2:
        place(args[0], max(30, min(96, int(float(args[1])))))
    elif cmd == "swap" and len(args) >= 4:
        ws, inn, out, share = args[0], args[1], args[2], args[3]
        exprs = []
        if out != "-":
            exprs.append(f'hl.dsp.window.move({{ window = "address:{out}", workspace = "{WINGS}", follow = false }})')
        exprs.append(f'hl.dsp.window.move({{ window = "address:{inn}", workspace = {int(ws)}, follow = false }})')
        batch(exprs)
        place(inn, max(30, min(96, int(float(share)))))
    elif cmd == "park" and args:
        park(args)
    elif cmd == "unpark" and len(args) >= 2:
        unpark(args[0], args[1:])
    else:
        print(__doc__)
        sys.exit(1)


if __name__ == "__main__":
    main()
