#!/usr/bin/env bash
#
#  VELVET · tools/update.sh — update and repair in one go.
#
#      bash ~/.config/quickshell/velvet/tools/update.sh
#  (or Super+Tab → SHELL → UPDATE & REPAIR, which opens it in a terminal)
#
#  1. downloads the newest Velvet (git pull) — skipped when you changed files
#     yourself, so nothing of yours is overwritten
#  2. copies Velvet's Hyprland files into ~/.config/hypr again (only the ones
#     that are already wired up; the old ones are kept as *.before-update)
#  3. rebuilds the zoom plugin when its source is newer than the build
#  4. swaps a running older zoom plugin for the new one (no logging out)
#  5. reloads Hyprland and restarts the shell
#
#  --check   only say what an update would do (exit 0: all current, 10: something to do)
set -u

CHECK=0
[ "${1:-}" = "--check" ] && CHECK=1

CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
Q="$CONF/quickshell/velvet"
HY="$CONF/hypr"
SRC="$(readlink -f "$Q")"
[ -f "$SRC/shell.qml" ] || { echo "Velvet is not installed at $Q"; exit 1; }

R=$'\e[38;5;197m'; W=$'\e[1;37m'; D=$'\e[2m'; G=$'\e[38;5;79m'; Y=$'\e[38;5;221m'; N=$'\e[0m'
ok()   { printf '  %s✓%s %s\n' "$G" "$N" "$*"; }
todo() { printf '  %s•%s %s\n' "$Y" "$N" "$*"; }
skip() { printf '  %s·%s %s\n' "$D" "$N" "$*"; }

pending=0

# ── what is out of date ──────────────────────────────────────────────────────
# only the dialect Hyprland reads: a leftover velvet-shell.conf next to a
# hyprland.lua is not in use and not worth a word
EXT=conf
[ -f "$HY/hyprland.lua" ] && EXT=lua
stale_hypr=()
for f in velvet-shell.$EXT velvet-desktop.$EXT velvet-media.$EXT; do
    [ -f "$HY/$f" ] && [ -f "$SRC/hypr/$f" ] && ! cmp -s "$SRC/hypr/$f" "$HY/$f" && stale_hypr+=("$f")
done

PLUGIN_DIR="$SRC/plugin/velvetzoom"
SO="$PLUGIN_DIR/build/velvetzoom.so"
want="$(grep -oP '"Velvet", "\K[0-9.]+' "$PLUGIN_DIR/main.cpp" 2>/dev/null)"
running=""
if command -v hyprctl >/dev/null 2>&1; then
    running="$(hyprctl plugin list -j 2>/dev/null | python3 -c '
import json, sys
try:
    print(next((p["version"] for p in json.load(sys.stdin) if p.get("name") == "velvetzoom"), ""))
except Exception:
    print("")' 2>/dev/null)"
fi
need_build=0
{ [ ! -f "$SO" ] || [ "$PLUGIN_DIR/main.cpp" -nt "$SO" ]; } && need_build=1
need_swap=0
[ -n "$running" ] && [ -n "$want" ] && [ "$running" != "$want" ] && need_swap=1

if [ "$CHECK" = 1 ]; then
    [ ${#stale_hypr[@]} -gt 0 ] && { echo "hypr: ${stale_hypr[*]}"; pending=1; }
    [ "$need_build" = 1 ] && { echo "plugin: needs a build"; pending=1; }
    [ "$need_swap" = 1 ] && { echo "plugin: $running running, $want built"; pending=1; }
    if [ "$pending" = 1 ]; then echo "status=pending"; exit 10; fi
    echo "status=current"
    exit 0
fi

printf '\n%sVELVET · update & repair%s\n' "$R" "$N"

# ── 1. download ──────────────────────────────────────────────────────────────
printf '\n%sDownload%s\n' "$W" "$N"
if [ -d "$SRC/.git" ] && git -C "$SRC" remote get-url origin >/dev/null 2>&1; then
    if ! git -C "$SRC" diff --quiet 2>/dev/null || ! git -C "$SRC" diff --cached --quiet 2>/dev/null; then
        skip "You changed files in ${SRC/#$HOME/~} yourself — not downloading over them"
    else
        before="$(git -C "$SRC" rev-parse HEAD 2>/dev/null)"
        if out="$(git -C "$SRC" pull --ff-only 2>&1)"; then
            after="$(git -C "$SRC" rev-parse HEAD 2>/dev/null)"
            [ "$before" = "$after" ] && ok "Already the newest version" || ok "Updated to $(cat "$SRC/VERSION" 2>/dev/null || echo "$after")"
        else
            skip "Could not download (offline, or your copy went its own way): ${out##*$'\n'}"
        fi
    fi
else
    skip "Not a download Velvet can update by itself"
fi

# after a download, look again
stale_hypr=()
for f in velvet-shell.$EXT velvet-desktop.$EXT velvet-media.$EXT; do
    [ -f "$HY/$f" ] && [ -f "$SRC/hypr/$f" ] && ! cmp -s "$SRC/hypr/$f" "$HY/$f" && stale_hypr+=("$f")
done
want="$(grep -oP '"Velvet", "\K[0-9.]+' "$PLUGIN_DIR/main.cpp" 2>/dev/null)"
need_build=0
{ [ ! -f "$SO" ] || [ "$PLUGIN_DIR/main.cpp" -nt "$SO" ]; } && need_build=1

# ── 2. Hyprland files ────────────────────────────────────────────────────────
printf '\n%sHyprland%s\n' "$W" "$N"
reload=0
if [ ${#stale_hypr[@]} -eq 0 ]; then
    ok "Velvet's Hyprland files are current"
else
    for f in "${stale_hypr[@]}"; do
        cp -f "$HY/$f" "$HY/$f.before-update"
        cp -f "$SRC/hypr/$f" "$HY/$f"
        ok "Updated ~/.config/hypr/$f  ${D}(old one: $f.before-update)${N}"
    done
    reload=1
fi

# ── 3. zoom plugin build ─────────────────────────────────────────────────────
printf '\n%sZoom plugin%s\n' "$W" "$N"
if [ "$need_build" = 1 ]; then
    if bash "$SRC/tools/build-zoom-plugin.sh" >/dev/null 2>&1; then
        ok "Rebuilt the zoom plugin"
    else
        todo "The zoom plugin did not build — the zoom keeps working without it (run tools/build-zoom-plugin.sh to see why)"
    fi
else
    ok "The zoom plugin build is current"
fi

# ── 4. swap a running older plugin ──────────────────────────────────────────
if [ -n "$running" ] && [ -n "$want" ] && [ "$running" != "$want" ]; then
    if bash "$SRC/tools/reload-zoom-plugin.sh" >/dev/null 2>&1; then
        ok "Hyprland now runs zoom plugin $want  ${D}(was $running)${N}"
    else
        todo "Could not swap the running zoom plugin — log out and in once"
    fi
elif [ -n "$running" ]; then
    ok "Hyprland runs zoom plugin $running"
fi

# ── 5. reload and restart ────────────────────────────────────────────────────
printf '\n%sRestart%s\n' "$W" "$N"
if [ "$reload" = 1 ] && command -v hyprctl >/dev/null 2>&1; then
    hyprctl reload >/dev/null 2>&1 && ok "Hyprland reloaded"
    errs="$(hyprctl configerrors 2>/dev/null | grep -v '^\s*$')"
    [ -n "$errs" ] && todo "Hyprland reports config errors — the old files are next to the new ones (*.before-update):"$'\n'"$errs"
fi
qs -c velvet kill >/dev/null 2>&1
for i in $(seq 40); do qs -c velvet ipc show >/dev/null 2>&1 || break; sleep 0.2; done
setsid -f "$SRC/bin/velvet-session" >/dev/null 2>&1
ok "Shell restarted"

printf '\n  %sDone.%s\n\n' "$W" "$N"
