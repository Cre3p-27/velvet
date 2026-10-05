#!/usr/bin/env bash
#
#  VELVET · uninstall.sh — removes the shell completely.
#
#      bash ~/.config/quickshell/velvet/uninstall.sh
#
#  Stops Velvet and takes back everything install.sh (and the shell itself)
#  put on this machine: the shell folder, its Hyprland lines and files, the
#  programs in ~/.local/bin, the downloaded fonts, the plugin, your Velvet
#  settings, and — with your password — /etc/pam.d/velvet and the SDDM
#  auto-login it may have added. Your hyprland config is backed up first and
#  gets back exactly what it had before. Packages it installed (hyprland,
#  quickshell, …) stay: other programs may need them.
#
#  --yes        no questions (removes everything, settings included)
#  --keep-config  keep ~/.config/velvet (your settings, looks, desktop)
set -uo pipefail

YES=0
KEEP_CFG=0
for arg in "$@"; do
    case "$arg" in
        -y|--yes) YES=1 ;;
        --keep-config) KEEP_CFG=1 ;;
        -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
        *) echo "unknown argument: $arg" >&2; exit 2 ;;
    esac
done

CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
QS_LINK="$CONF/quickshell/velvet"
HYPR="$CONF/hypr"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

R=$'\e[38;5;197m'; W=$'\e[1;37m'; D=$'\e[2m'; G=$'\e[38;5;79m'; Y=$'\e[38;5;221m'; N=$'\e[0m'
ok()   { printf '  %s✓%s %s\n' "$G" "$N" "$*"; }
skip() { printf '  %s·%s %s\n' "$D" "$N" "$*"; }
warn() { printf '  %s!%s %s\n' "$Y" "$N" "$*"; }
ask() { # default: yes
    [ "$YES" = 1 ] && return 0
    [ -t 0 ] || [ -t 1 ] || return 1
    [ -r /dev/tty ] || return 1
    printf '  %s%s [Y/n] %s' "$Y" "$1" "$N"
    local r; read -r r < /dev/tty || r=""
    case "$r" in n|N|no|No|nein|Nein) return 1 ;; *) return 0 ;; esac
}
gone() { # remove a file / folder / link, say so
    if [ -e "$1" ] || [ -L "$1" ]; then rm -rf -- "$1" && ok "removed ${1/#$HOME/~}"; fi
}

printf '\n%sVELVET · uninstall%s\n\n' "$R" "$N"
say_what="This removes Velvet completely from this computer."
printf '  %s\n' "$say_what"
if [ "$YES" = 0 ]; then
    ask "Remove Velvet now?" || { printf '  Nothing was changed.\n\n'; exit 0; }
fi

# ── 1. stop everything that runs ─────────────────────────────────────────────
printf '\n%sStopping%s\n' "$W" "$N"
for b in qs quickshell; do
    command -v "$b" >/dev/null 2>&1 && "$b" -c velvet kill >/dev/null 2>&1 && ok "Velvet stopped" && break
done
# the canvas engine and the desktop programs (by their exact command lines)
for pid in $(ps -eo pid=,args= | awk '/scripts\/infinite_desktop_core\.py|bin\/velvet-[a-z]+|bin\/_velvet\.py/ && !/awk/ {print $1}'); do
    [ "$pid" = "$$" ] && continue
    kill "$pid" 2>/dev/null
done
ok "Desktop programs stopped"
if command -v hyprctl >/dev/null 2>&1; then
    plug="$(hyprctl plugin list 2>/dev/null | awk '/velvetzoom/ {print; exit}')"
    [ -n "$plug" ] && skip "The zoom plugin stays loaded until you log out (unloading a live plugin can crash Hyprland)"
fi

# ── 2. Hyprland: give the config back what it had ────────────────────────────
printf '\n%sHyprland%s\n' "$W" "$N"
for f in "$HYPR/hyprland.lua" "$HYPR/hyprland.conf"; do
    [ -f "$f" ] || continue
    if grep -qE 'velvet-shell|velvet-desktop|VELVET ─' "$f"; then
        cp -f "$f" "$f.before-uninstall"
        # drop exactly the lines install.sh added
        sed -i -E '/^-- ── VELVET ─+$/d; /^# ── VELVET ─+$/d; /^require\("velvet-shell"\)$/d; /^require\("velvet-desktop"\)$/d; /^source = .*velvet-shell\.conf$/d; /^source = .*velvet-desktop\.conf$/d' "$f"
        ok "Velvet lines removed from ${f/#$HOME/~}  ${D}(backup: $(basename "$f").before-uninstall)${N}"
    fi
done
for f in velvet-shell.lua velvet-shell.conf velvet-desktop.lua velvet-desktop.conf velvet.lua velvet.conf; do
    gone "$HYPR/$f"
done

# ── 3. the shell itself ──────────────────────────────────────────────────────
printf '\n%sFiles%s\n' "$W" "$N"
for p in "$HOME"/.local/bin/velvet-*; do
    [ -L "$p" ] && gone "$p"
done
gone "$HOME/.local/share/fonts/velvet" && command -v fc-cache >/dev/null 2>&1 && fc-cache -f >/dev/null 2>&1
# the folder Quickshell loads (a link to the checkout, or a real folder)
gone "$QS_LINK"
rmdir "$CONF/quickshell" 2>/dev/null || true
if [ "$KEEP_CFG" = 0 ] && { [ "$YES" = 1 ] || ask "Also delete your Velvet settings, looks and desktop (~/.config/velvet)?"; }; then
    gone "$CONF/velvet"
else
    skip "Kept ~/.config/velvet"
fi
rm -f "${XDG_RUNTIME_DIR:-/tmp}"/velvet-* /tmp/velvet-* /tmp/infinite-desktop-state 2>/dev/null
ok "Temporary files cleared"

# ── 4. system files (need your password) ─────────────────────────────────────
sys=()
[ -f /etc/pam.d/velvet ] && sys+=(/etc/pam.d/velvet)
[ -f /etc/sddm.conf.d/velvet-autologin.conf ] && sys+=(/etc/sddm.conf.d/velvet-autologin.conf)
if [ ${#sys[@]} -gt 0 ]; then
    printf '\n%sSystem%s\n' "$W" "$N"
    if ask "Remove ${sys[*]} (asks for your password)?"; then
        for f in "${sys[@]}"; do sudo rm -f "$f" && ok "removed $f"; done
    else
        skip "Kept ${sys[*]}"
    fi
fi

# ── 5. the downloaded copy ───────────────────────────────────────────────────
# Last, because this script may live inside it.
printf '\n%sThe download%s\n' "$W" "$N"
GET_DIR="$HOME/.local/share/velvet"
if [ -d "$GET_DIR" ]; then
    gone "$GET_DIR"
elif [ -f "$SRC/shell.qml" ] && [ "$SRC" != "$HOME" ]; then
    # installed from a folder of your own (git clone): ask before deleting it
    if [ "$YES" = 0 ] && ask "Delete the Velvet folder itself (${SRC/#$HOME/~})?"; then
        gone "$SRC"
    else
        skip "Kept ${SRC/#$HOME/~}"
    fi
fi

printf '\n  %sVelvet is gone.%s Log out and back in (or restart) to finish.\n' "$W" "$N"
printf '  %sYour own programs, files and the packages that were installed are untouched.%s\n\n' "$D" "$N"
