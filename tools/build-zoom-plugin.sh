#!/usr/bin/env bash
# Builds the desktop zoom-out plugin (plugin/velvetzoom) against the Hyprland
# headers installed on this machine. A Hyprland plugin is tied to the exact
# compositor build: after a Hyprland update, run this again (until then the
# zoom script quietly uses its older fallback).
#
#   tools/build-zoom-plugin.sh
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
cd "$here/plugin/velvetzoom"

for need in g++ make pkg-config; do
    command -v "$need" >/dev/null || { echo "missing: $need"; exit 1; }
done
pkg-config --exists hyprland || { echo "Hyprland development headers not found (pkg-config hyprland)"; exit 1; }

make -s
echo "built: $here/plugin/velvetzoom/build/velvetzoom.so"
echo "running compositor: $(hyprctl version 2>/dev/null | head -1 || echo 'not running')"
echo "headers:            $(pkg-config --modversion hyprland)"
