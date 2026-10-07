#!/usr/bin/env python3
"""Desktop zoom for Hyprland 0.56+  ·  bound to SUPER+ALT + mouse wheel.

One wheel, one continuous zoom from 0.25x to 3.0x:

  · z >= 1.0 — the plugin (0.6+) grows the windows around the pointer while
    the wallpaper, the bar and every panel stay exactly as they are. Without
    the plugin: Hyprland's compositor zoom (`cursor:zoom_factor`), which
    magnifies the whole picture, bar included.

  · z < 1.0, THE REAL ONE — plugin/velvetzoom renders every window of the
    desktop through a scale-about-a-pivot, so each window shrinks as a live
    texture (content included, wallpaper and bar stay put), smoothly, down to
    10 %. Windows that are off screen at 1:1 slide in as the zoom opens up.
    The script loads the plugin on first use (`hyprctl plugin load`) and
    only talks to it with `hyprctl velvetzoom set|off|status`. Build it with
    tools/build-zoom-plugin.sh. If it is missing, will not load, or
    /tmp/velvet-zoom-noplugin exists, the fallback below runs.

  · z < 1.0, fallback — the compositor clamps at 1.0 (verified: "value 0.50
    is less than the minimum of 1.00"), so without the plugin the shell fakes
    the overview itself:
    every floating window on the active workspace glides toward an anchor
    point (the cursor, clamped into the central screen area) and shrinks by
    z — the whole infinite canvas becomes visible. Hyprland's `windows`
    spring animates the flight.

    The glide is split in two so it stays clean: while the wheel turns,
    only the POSITIONS move (no resize, no app relayout per tick — that is
    what made the shrink look chopped). When the wheel has rested for a
    moment, a detached "settle" pass applies the SIZE transform once — a
    single clean transition, then the overview is complete.

Wheel up zooms in, wheel down zooms out, wheel press (middle click) resets
to 1:1 — the exact original geometry is restored from the state file.
SUPER+ALT+left click is 1:1 as well; SUPER+ALT+right click (`fit`) zooms out
just far enough that every window of the desk shows. The plugin (0.5+) takes
both clicks itself; the binds that call this script are the fallback.

Zoomed in, the view stays where it is (cursor:zoom_rigid): the pointer stops
at the edge of what is shown instead of dragging the view after it.

Why a state file instead of getoption: getoption reports the ANIMATED
value, which lags the target. Compounding wheel ticks off the animated
value undershoots, and a reset fired right after a zoom step reads 1.0 and
skips itself. We keep our own target in /tmp and re-sync with Hyprland
only after the wheel has been idle, so touchpad gestures and other tools
win over a stale file.

Usage:  desktop_zoom.py in|out|reset|fit
"""

import json
import os
import re
import subprocess
import sys
import time

SCRIPT = os.path.abspath(__file__)

# VELVET_ZOOM_DIR lets a test run keep its files away from the live session.
RUN = os.environ.get("VELVET_ZOOM_DIR") or "/tmp"

MIN_Z = 0.25         # fallback regime
PLUGIN_MIN_Z = 0.1   # the plugin's overview goes right down
MAX_Z = 3.0
STEP = 1.3           # per wheel tick
STATE = f"{RUN}/velvet-zoom.json"
LOCK = f"{RUN}/velvet-zoom.lock"
NOPLUGIN = f"{RUN}/velvet-zoom-noplugin"     # touch it to force the fallback
PLUGIN_FAIL = f"{RUN}/velvet-zoom-pluginfail"
PLUGIN_SO = os.environ.get("VELVET_ZOOM_PLUGIN") or os.path.normpath(os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "plugin", "velvetzoom", "build", "velvetzoom.so"))
SYNC_AFTER = 2.0     # wheel silence before re-reading Hyprland's value
DEBOUNCE = 0.04      # merge scroll momentum into one glide
SETTLE = 0.35        # wheel silence before the size transform applies
MIN_W = 60           # never shrink a window below this
MIN_H = 40
MAP_OPEN = f"{RUN}/velvet-map-open"   # written by the map while it is up


def sh(args, timeout=1.0):
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=timeout)
    except Exception:
        return None


def cursor_zoom_from_hyprland() -> float:
    r = sh(["hyprctl", "getoption", "cursor:zoom_factor"])
    if r and r.stdout:
        m = re.search(r"float:\s*([0-9.]+)", r.stdout)
        if m:
            return max(1.0, float(m.group(1)))
    return 1.0


def set_cursor_zoom(z: float) -> None:
    # rigid: the magnified view does not follow the pointer to the screen's
    # edges (the plugin keeps the pointer inside what is shown instead)
    sh(["hyprctl", "eval",
        f'hl.config({{ cursor = {{ zoom_factor = {z:.3f}, zoom_rigid = true }} }})'])


def cursor_pos() -> (float, float):
    r = sh(["hyprctl", "cursorpos"])
    try:
        x, y = r.stdout.strip().split(",")
        return float(x), float(y)
    except Exception:
        return 1920.0, 1080.0


def focused_monitor() -> (int, int, int, int):
    r = sh(["hyprctl", "monitors", "-j"])
    try:
        mons = json.loads(r.stdout)
        m = next((m for m in mons if m.get("focused")), mons[0])
        return m["x"], m["y"], m["width"], m["height"]
    except Exception:
        return 0, 0, 3840, 2160


def active_ws() -> int:
    r = sh(["hyprctl", "activeworkspace", "-j"])
    try:
        return int(json.loads(r.stdout)["id"])
    except Exception:
        return 1


def fixed_classes() -> set:
    """Modules set to FIXED stay where they are while the canvas moves."""
    try:
        with open(os.path.join(os.environ.get("XDG_RUNTIME_DIR") or "/tmp", "velvet-fixed")) as f:
            return {line.strip() for line in f if line.strip()}
    except OSError:
        return set()


def floating_on_ws(ws: int):
    r = sh(["hyprctl", "clients", "-j"])
    try:
        fixed = fixed_classes()
        return [
            c for c in json.loads(r.stdout)
            if c.get("floating") and c.get("workspace", {}).get("id") == ws
            and c.get("class") not in fixed
        ]
    except Exception:
        return []


def read_state():
    try:
        with open(STATE) as f:
            return json.load(f)
    except Exception:
        return None


def write_state(st) -> None:
    try:
        with open(STATE, "w") as f:
            json.dump(st, f)
    except OSError:
        pass


def plugin_status():
    """The plugin's own answer, or None when it is not loaded."""
    r = sh(["hyprctl", "velvetzoom", "status"])
    if not r or not r.stdout:
        return None
    m = re.search(r"active=(true|false) z=([0-9.]+) target=([0-9.]+) pivot=(-?[0-9.]+),(-?[0-9.]+)", r.stdout)
    if not m:
        return None
    return {"active": m.group(1) == "true", "z": float(m.group(2)), "target": float(m.group(3)),
            "px": float(m.group(4)), "py": float(m.group(5)),
            # plugin 0.3+ steps the wheel itself; an older one, still loaded
            # into a running compositor, is driven with `set`
            "wheel": "wheel=" in r.stdout}


def plugin_ready():
    """The plugin's status, loading it first if needed. At most one load
    attempt a minute, so a broken build never costs a wheel tick twice."""
    if os.path.exists(NOPLUGIN):
        return None
    st = plugin_status()
    if st:
        return st
    if not os.path.isfile(PLUGIN_SO):
        return None
    try:
        if time.time() - os.path.getmtime(PLUGIN_FAIL) < 60:
            return None
    except OSError:
        pass
    sh(["hyprctl", "plugin", "load", PLUGIN_SO], timeout=4.0)
    st = plugin_status()
    if not st:
        try:
            with open(PLUGIN_FAIL, "w") as f:
                f.write("")
        except OSError:
            pass
    return st


def plugin_wheel(notches: int, ps=None) -> bool:
    """One notch of the overview, stepped by the plugin itself (its own burst
    speed-up and limits). False when the plugin passed it on."""
    ps = ps or plugin_status()
    if ps and not ps["wheel"]:
        return plugin_wheel_old(notches, ps)
    r = sh(["hyprctl", "velvetzoom", "wheel", str(notches)])
    return bool(r and r.stdout and "taken" in r.stdout)


def plugin_wheel_old(notches: int, ps) -> bool:
    """Plugin 0.2, loaded before the last update: no wheel verb, so the step
    is worked out here and sent with `set`."""
    if ps["active"] and ps["target"] < 0.999:
        target = ps["target"]
        ax, ay = ps["px"], ps["py"]
    elif notches > 0 and cursor_zoom_from_hyprland() <= 1.005:
        target = 1.0
        ax, ay = anchor()
    else:
        return False
    z = target / (STEP ** notches)
    z = max(PLUGIN_MIN_Z, min(1.0, z))
    if z >= 0.995:
        plugin_off()
        return notches < 0
    sh(["hyprctl", "velvetzoom", "set", f"{z:.4f}", f"{ax:.0f}", f"{ay:.0f}"])
    return True


def plugin_off() -> None:
    sh(["hyprctl", "velvetzoom", "off"])


def anchor():
    """Where the zoom is pinned: the cursor, clamped into the central half of
    the focused monitor so the shrunken desktop stays on screen."""
    mx, my, mw, mh = focused_monitor()
    cx, cy = cursor_pos()
    return (max(mx + mw * 0.25, min(mx + mw * 0.75, cx)),
            max(my + mh * 0.25, min(my + mh * 0.75, cy)))


def canvas_active(st) -> bool:
    return bool(st and st.get("originals"))


def debounced() -> bool:
    """True when another step ran moments ago — drop this tick so the
    animation glides once instead of being re-targeted by scroll momentum."""
    try:
        if time.time() - os.path.getmtime(LOCK) < DEBOUNCE:
            return True
    except OSError:
        pass
    try:
        with open(LOCK, "w") as f:
            f.write("")
    except OSError:
        pass
    return False


def batch_dispatches(exprs) -> None:
    if not exprs:
        return
    cmd = " ; ".join(f"dispatch {e}" for e in exprs)
    # Fire and forget: the compositor animates the flight anyway, and a
    # wheel tick must never wait on the batch.
    subprocess.Popen(["hyprctl", "--batch", cmd],
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def alive_addresses():
    """Addresses that still exist. Windows closed mid-zoom must not get
    dispatched to — a dead address spams the compositor log and, worse,
    could match a recycled address one day."""
    r = sh(["hyprctl", "clients", "-j"])
    try:
        return {c["address"] for c in json.loads(r.stdout)}
    except Exception:
        return set()


def canvas_exprs(st) -> [str]:
    """Position-only: the live pass while the wheel turns. No resize here —
    resizing per tick relaid out the apps and made the shrink look chopped."""
    z = st["z"]
    ax, ay = st["ax"], st["ay"]
    alive = alive_addresses()
    exprs = []
    for addr, (ox, oy, ow, oh) in st["originals"].items():
        if addr not in alive:
            continue
        exprs.append(f'hl.dsp.window.move({{ window = "address:{addr}", x = {round(ax + (ox - ax) * z)}, y = {round(ay + (oy - ay) * z)}, relative = false }})')
    return exprs


def canvas_size_exprs(st) -> [str]:
    """The settle pass: sizes ONCE, after the wheel has rested. Resize
    keeps the window centre, so the move follows — but both run in the
    same batch and land exactly (verified live)."""
    z = st["z"]
    ax, ay = st["ax"], st["ay"]
    alive = alive_addresses()
    exprs = []
    for addr, (ox, oy, ow, oh) in st["originals"].items():
        if addr not in alive:
            continue
        nw = max(MIN_W, round(ow * z))
        nh = max(MIN_H, round(oh * z))
        exprs.append(f'hl.dsp.window.resize({{ window = "address:{addr}", x = {nw}, y = {nh}, relative = false }})')
        exprs.append(f'hl.dsp.window.move({{ window = "address:{addr}", x = {round(ax + (ox - ax) * z)}, y = {round(ay + (oy - ay) * z)}, relative = false }})')
    return exprs


def restore_exprs(st) -> [str]:
    alive = alive_addresses()
    exprs = []
    for addr, (ox, oy, ow, oh) in st["originals"].items():
        if addr not in alive:
            continue
        exprs.append(f'hl.dsp.window.resize({{ window = "address:{addr}", x = {ow}, y = {oh}, relative = false }})')
        exprs.append(f'hl.dsp.window.move({{ window = "address:{addr}", x = {ox}, y = {oy}, relative = false }})')
    return exprs


def apply_canvas(st) -> None:
    batch_dispatches(canvas_exprs(st))
    spawn_settler()


def start_canvas():
    """Capture every floating window of the active workspace at 1:1, anchor
    the zoom at the cursor (clamped into the central half of the focused
    monitor, so the shrunken canvas stays on screen)."""
    ws = active_ws()
    originals = {}
    for c in floating_on_ws(ws):
        originals[c["address"]] = [c["at"][0], c["at"][1],
                                   c["size"][0], c["size"][1]]
    if not originals:
        return None
    ax, ay = anchor()
    return {"z": 1.0, "ax": ax, "ay": ay, "originals": originals}


def spawn_settler() -> None:
    """A detached pass that waits out the scroll and then applies the size
    transform ONCE. If more ticks arrive meanwhile, the new ticks' own
    settler takes over (the lock mtime tells whose turn it is).

    Position-only mode: while /tmp/velvet-zoom-noshrink exists, no sizes
    are ever touched — the overview gathers positions only and the apps
    never relayout."""
    if os.path.exists(f"{RUN}/velvet-zoom-noshrink"):
        return
    try:
        subprocess.Popen([sys.executable, SCRIPT, "settle"],
                         start_new_session=True,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except OSError:
        pass


def settle() -> None:
    time.sleep(SETTLE)
    try:
        if time.time() - os.path.getmtime(LOCK) < SETTLE - 0.05:
            return  # the wheel is still turning — that burst's settler owns it
    except OSError:
        return
    st = read_state()
    if canvas_active(st):
        batch_dispatches(canvas_size_exprs(st))


def sync_cursor_z() -> float:
    """The cursor-zoom regime's current target. Fresh from Hyprland after
    a quiet period; from the state file while the wheel is busy."""
    st = read_state()
    if st and not canvas_active(st):
        try:
            age = time.time() - os.path.getmtime(STATE)
        except OSError:
            age = SYNC_AFTER + 1
        if age <= SYNC_AFTER:
            return max(1.0, float(st.get("z", 1.0)))
    z = cursor_zoom_from_hyprland()
    write_state({"z": z})
    return z


def zoom_in() -> None:
    # No desktop zoom under the map: its photograph and its cards would
    # disagree with a half-zoomed desktop behind it.
    if os.path.exists(MAP_OPEN):
        return
    st = read_state()
    if canvas_active(st):
        z = min(1.0, st["z"] * STEP)
        if z >= 0.995:
            # Back across the boundary: exact restore, hand over to the
            # compositor zoom at 1.0.
            batch_dispatches(restore_exprs(st))
            set_cursor_zoom(1.0)
            write_state({"z": 1.0})
            return
        st["z"] = z
        apply_canvas(st)
        write_state(st)
        return

    # the plugin (0.6+) magnifies the windows only — bar and panels keep their
    # size; Hyprland's cursor zoom (below) magnifies the whole picture
    ps = plugin_ready()
    if ps and ps["wheel"] and plugin_wheel(-1, ps):
        return

    cur = sync_cursor_z()
    z = min(MAX_Z, cur * STEP)
    if abs(z - cur) < 0.001:
        return
    set_cursor_zoom(z)
    write_state({"z": z})


def zoom_out() -> None:
    if os.path.exists(MAP_OPEN):
        return
    st = read_state()
    if canvas_active(st):
        z = max(MIN_Z, st["z"] / STEP)
        if abs(z - st["z"]) < 0.001:
            return
        st["z"] = z
        apply_canvas(st)
        write_state(st)
        return

    # The plugin takes the wheel when the screen is not magnified; when it
    # is, it says "passed on" and the compositor zoom is stepped down first.
    ps = plugin_ready()
    if ps and plugin_wheel(1, ps):
        return

    cur = sync_cursor_z()
    if cur > 1.005:
        z = max(1.0, cur / STEP)
        set_cursor_zoom(z)
        write_state({"z": z})
        return

    # At 1.0 and no plugin: the canvas fallback.
    st = start_canvas()
    if st is None:
        return  # nothing floating to shrink — the wheel rests
    st["z"] = 1.0 / STEP
    apply_canvas(st)
    write_state(st)


def reset() -> None:
    st = read_state()
    if canvas_active(st):
        batch_dispatches(restore_exprs(st))
    if plugin_status():
        plugin_off()
    set_cursor_zoom(1.0)
    write_state({"z": 1.0})


def fit() -> None:
    """Zoom out just far enough that every window of the desk shows."""
    if os.path.exists(MAP_OPEN):
        return
    if cursor_zoom_from_hyprland() > 1.005:
        set_cursor_zoom(1.0)
        write_state({"z": 1.0})
    ps = plugin_ready()
    if ps:
        sh(["hyprctl", "velvetzoom", "fit"])


def reset_canvas() -> None:
    """Restore the canvas only — the cursor zoom is left alone. Called by
    the map when it opens, so window moves never fight stale originals."""
    st = read_state()
    if canvas_active(st):
        batch_dispatches(restore_exprs(st))
        write_state({"z": 1.0})
    if plugin_status():
        plugin_off()


def main() -> None:
    action = sys.argv[1] if len(sys.argv) > 1 else "in"
    if action == "reset":
        reset()
        return
    if action == "resetcanvas":
        reset_canvas()
        return
    if action == "settle":
        settle()
        return
    if action == "load":
        plugin_ready()
        return
    if action == "fit":
        fit()
        return
    if debounced():
        return
    if action == "out":
        zoom_out()
    else:
        zoom_in()


if __name__ == "__main__":
    main()
