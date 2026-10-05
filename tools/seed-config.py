#!/usr/bin/env python3
"""
VELVET · tools/seed-config.py

Writes the first ~/.config/velvet/config.json by reading what Hyprland is
*already* doing and what your monitor actually is. The point is that the very
first launch changes nothing about your desktop: the WINDOWS tab opens showing
your own gaps, blur and shadows rather than my defaults, and the bar is sized
for your panel rather than for a 1080p one.

Only keys we can genuinely determine are written; the shell fills in every
other default itself.

    python3 seed-config.py <config.json> [wallpaper-dir]
"""

import json
import os
import subprocess
import sys


def hyprctl(args):
    try:
        out = subprocess.run(["hyprctl", *args, "-j"], capture_output=True, text=True, timeout=4)
        if out.returncode != 0:
            return None
        return json.loads(out.stdout)
    except Exception:
        return None


def option(name):
    """hyprctl getoption returns the value under a type-named key."""
    d = hyprctl(["getoption", name])
    if not isinstance(d, dict):
        return None
    for key in ("int", "float", "str", "custom"):
        if key in d and d[key] not in (None, ""):
            return d[key]
    return None


def as_int(name, default=None):
    v = option(name)
    if v is None:
        return default
    if isinstance(v, str):
        # Multi-value options (gaps_in can be "5 5 5 5") — take the first.
        parts = v.replace(",", " ").split()
        for p in parts:
            try:
                return int(float(p))
            except ValueError:
                continue
        return default
    try:
        return int(round(float(v)))
    except (TypeError, ValueError):
        return default


def as_float(name, default=None):
    v = as_raw_float(name)
    return default if v is None else v


def as_raw_float(name):
    v = option(name)
    if v is None:
        return None
    if isinstance(v, str):
        for p in v.replace(",", " ").split():
            try:
                return float(p)
            except ValueError:
                continue
        return None
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


def as_bool(name, default=None):
    v = as_raw_float(name)
    return default if v is None else bool(v)


def as_str(name, default=None):
    v = option(name)
    return default if v is None else str(v)


def put(tree, path, value):
    """Set a dotted path, skipping None so we never write a guess."""
    if value is None:
        return
    node = tree
    parts = path.split(".")
    for p in parts[:-1]:
        node = node.setdefault(p, {})
    node[parts[-1]] = value


def main():
    if len(sys.argv) < 2:
        print("usage: seed-config.py <config.json> [wallpaper-dir]", file=sys.stderr)
        return 2

    path = sys.argv[1]
    walls = sys.argv[2] if len(sys.argv) > 2 else ""

    if os.path.exists(path) and os.path.getsize(path) > 4:
        print("  config.json already exists — leaving it alone")
        return 0

    cfg = {}

    # ── what Hyprland is doing right now ────────────────────────────────────
    took = 0
    for key, getter, opt in [
        ("hypr.gapsIn", as_int, "general:gaps_in"),
        ("hypr.gapsOut", as_int, "general:gaps_out"),
        ("hypr.borderSize", as_int, "general:border_size"),
        ("hypr.resizeOnBorder", as_bool, "general:resize_on_border"),
        ("hypr.layout", as_str, "general:layout"),
        ("hypr.rounding", as_int, "decoration:rounding"),
        ("hypr.roundingPower", as_float, "decoration:rounding_power"),
        ("hypr.activeOpacity", as_float, "decoration:active_opacity"),
        ("hypr.inactiveOpacity", as_float, "decoration:inactive_opacity"),
        ("hypr.dimInactive", as_bool, "decoration:dim_inactive"),
        ("hypr.dimStrength", as_float, "decoration:dim_strength"),
        ("hypr.blur", as_bool, "decoration:blur:enabled"),
        ("hypr.blurSize", as_int, "decoration:blur:size"),
        ("hypr.blurPasses", as_int, "decoration:blur:passes"),
        ("hypr.shadow", as_bool, "decoration:shadow:enabled"),
        ("hypr.shadowRange", as_int, "decoration:shadow:range"),
        ("hypr.shadowRenderPower", as_int, "decoration:shadow:render_power"),
        ("hypr.animations", as_bool, "animations:enabled"),
        ("hypr.vrr", as_bool, "misc:vrr"),
        ("hypr.followMouse", as_bool, "input:follow_mouse"),
    ]:
        value = getter(opt)
        if value is not None:
            put(cfg, key, value)
            took += 1

    if took:
        print(f"  Adopted {took} live Hyprland values — nothing will jump on first start")
    else:
        print("  Could not read Hyprland options (is it running?) — using defaults")

    # Their border colours are usually deliberate; don't take them over unless
    # asked. The user can turn this on in WINDOWS → TINT WINDOW BORDERS.
    put(cfg, "hypr.manageBorders", False)

    # ── config language ─────────────────────────────────────────────────────
    hypr_dir = os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")), "hypr")
    if os.path.isfile(os.path.join(hypr_dir, "hyprland.lua")):
        put(cfg, "hypr.format", "lua")
        put(cfg, "hypr.luaDispatch", "lua")
        print("  Lua config detected — dispatchers set to Lua style")

    # ── panel size ──────────────────────────────────────────────────────────
    mons = hyprctl(["monitors"]) or []
    if isinstance(mons, list) and mons:
        focused = next((m for m in mons if m.get("focused")), mons[0])
        scale = float(focused.get("scale") or 1) or 1
        logical_h = float(focused.get("height") or 1080) / scale

        # 1080p is the baseline. Scale up gently — a 4K panel at scale 1 wants
        # a much bigger bar, but not twice as big as it is tall.
        factor = max(1.0, min(2.0, 1.0 + (logical_h / 1080.0 - 1.0) * 0.8))
        if factor > 1.05:
            put(cfg, "bar.thickness", int(round(46 * factor)))
            put(cfg, "bar.iconSize", int(round(18 * factor)))
            put(cfg, "bar.fontSize", int(round(12 * factor)))
            put(cfg, "bar.rounding", int(round(18 * factor)))
            put(cfg, "bar.margin", int(round(8 * factor)))
            put(cfg, "bar.spacing", int(round(10 * factor)))
            put(cfg, "bar.revealEdge", int(round(8 * factor)))
            put(cfg, "appearance.fontScale", round(factor, 2))
            print(f"  {int(focused.get('width', 0))}×{int(focused.get('height', 0))} at scale {scale:g}"
                  f" — sized the shell up {factor:.2f}×")

    # ── wallpapers ──────────────────────────────────────────────────────────
    if walls and os.path.isdir(walls):
        put(cfg, "wallpaper.directory", walls)

    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(cfg, fh, indent=2)
        fh.write("\n")
    print(f"  Wrote {path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
