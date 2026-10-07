#!/usr/bin/env bash
# Puts the freshly built zoom plugin (plugin/velvetzoom) into the RUNNING
# Hyprland — no logging out. Hyprland keeps the plugin build it loaded at
# login; a new build otherwise only arrives with the next login.
#
#   bash ~/.config/quickshell/velvet/tools/reload-zoom-plugin.sh
#
# The zoom goes back to 1:1 first, the old plugin is unloaded, the new one is
# loaded under a fresh file name (the C library would otherwise hand back the
# old one it still remembers under the old name).
set -u
CONF="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/velvet"
BUILD="$CONF/plugin/velvetzoom/build"
NEW="$BUILD/velvetzoom.so"
REAL="$(readlink -f "$BUILD")"

[ -f "$NEW" ] || { echo "No build yet — run: bash $CONF/tools/build-zoom-plugin.sh"; exit 1; }
command -v hyprctl >/dev/null || { echo "hyprctl not found"; exit 1; }

loaded() {
    hyprctl plugin list -j 2>/dev/null | python3 -c '
import json, sys
try:
    print(next((p["version"] for p in json.load(sys.stdin) if p.get("name") == "velvetzoom"), ""))
except Exception:
    print("")'
}

before="$(loaded)"
echo "loaded now: ${before:-none}"

# both zooms back to 1:1 (the old plugin's and Hyprland's own)
python3 "$CONF/scripts/desktop_zoom.py" reset >/dev/null 2>&1
sleep 0.6

if [ -n "$before" ]; then
    for p in "$NEW" "$REAL/velvetzoom.so" "$BUILD"/velvetzoom-live-*.so "$REAL"/velvetzoom-live-*.so; do
        [ -n "$(loaded)" ] || break
        [ -e "$p" ] || [ "$p" = "$NEW" ] || continue
        hyprctl plugin unload "$p" >/dev/null 2>&1
    done
    if [ -n "$(loaded)" ]; then
        echo "The running plugin could not be unloaded — log out and in once instead."
        exit 1
    fi
fi

rm -f "$BUILD"/velvetzoom-live-*.so
copy="$BUILD/velvetzoom-live-$(date +%s).so"
cp "$NEW" "$copy"
if hyprctl plugin load "$copy" >/dev/null 2>&1 && [ -n "$(loaded)" ]; then
    echo "loaded now: $(loaded)  ✓"
else
    echo "Loading the new plugin failed — log out and in once; the zoom falls back meanwhile."
    exit 1
fi
