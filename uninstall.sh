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
#  --yes          no questions (removes everything, settings and AI data included)
#  --keep-config  keep ~/.config/velvet (your settings, looks, desktop)
#  --keep-ai      keep Velly's models and voices (~/.local/share/velvet)
set -uo pipefail

YES=0
KEEP_CFG=0
KEEP_AI=0
for arg in "$@"; do
    case "$arg" in
        -y|--yes) YES=1 ;;
        --keep-config) KEEP_CFG=1 ;;
        --keep-ai) KEEP_AI=1 ;;
        -h|--help) sed -n '2,19p' "$0"; exit 0 ;;
        *) echo "unknown argument: $arg" >&2; exit 2 ;;
    esac
done

CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
QS_LINK="$CONF/quickshell/velvet"
HYPR="$CONF/hypr"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
GET_DIR="$DATA_HOME/velvet-src"   # where get.sh downloads the shell
AI_DIR="$DATA_HOME/velvet"        # Velly's models, voices and engines
# The folder the shell really lives in, read before its link is removed.
CHECKOUT="$(readlink -f "$QS_LINK" 2>/dev/null || true)"
[ -f "$CHECKOUT/shell.qml" ] || CHECKOUT="$SRC"

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
# the keeper first, or it would start the shell again
for pid in $(ps -eo pid=,args= | awk '/bin\/velvet-session/ && !/awk/ {print $1}'); do
    [ "$pid" = "$$" ] || kill "$pid" 2>/dev/null
done
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
    if grep -qE 'velvet-shell|velvet-desktop|velvet-media|VELVET ─' "$f"; then
        cp -f "$f" "$f.before-uninstall"
        # drop exactly the lines install.sh added
        # (a prefix match for the banner: `─+` is not one character in a C locale)
        sed -i -E '/^-- ── VELVET /d; /^# ── VELVET /d; /^require\("velvet-(shell|desktop|media)"\)$/d; /^source = .*velvet-(shell|desktop|media)\.conf$/d' "$f"
        # and the blank line the installer put before them
        body="$(cat "$f")"; printf '%s\n' "$body" > "$f"
        ok "Velvet lines removed from ${f/#$HOME/~}  ${D}(backup: $(basename "$f").before-uninstall)${N}"
    fi
done
for f in velvet-shell.lua velvet-shell.conf velvet-desktop.lua velvet-desktop.conf velvet-media.lua velvet-media.conf velvet.lua velvet.conf; do
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
# the three wallpapers install.sh brought along — only while they are unchanged
for w in "$CHECKOUT"/assets/wallpapers/*.jpg; do
    [ -f "$w" ] || continue
    for d in "$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")/Wallpapers" "$HOME/Pictures/Wallpapers"; do
        c="$d/$(basename "$w")"
        [ -f "$c" ] && cmp -s "$w" "$c" && gone "$c" && rmdir "$d" 2>/dev/null
    done
done
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

# ── 5. Velly's AI data ───────────────────────────────────────────────────────
# Models and voices can be tens of gigabytes and take long to download again:
# never removed without saying how much it is.
strip_checkout() { # take the shell's own files out of a folder, keep the rest
    ( cd "$1" && git ls-files | sed -n 's|/[^/]*$||p' | sort -ru > .velvet-dirs \
      && git ls-files -z | xargs -0 rm -f -- \
      && while read -r d; do rmdir -p "$d" 2>/dev/null || true; done < .velvet-dirs; rm -rf .git .velvet-dirs )
}
legacy=0   # an older get.sh downloaded the shell into Velly's folder
[ -d "$AI_DIR/.git" ] && [ -f "$AI_DIR/shell.qml" ] && legacy=1
ai_parts=()
for d in models voices engines; do [ -e "$AI_DIR/$d" ] && ai_parts+=("$AI_DIR/$d"); done
if [ -d "$AI_DIR" ]; then
    printf '\n%sVelly (the assistant)%s\n' "$W" "$N"
    size="$(du -sh "$AI_DIR" 2>/dev/null | cut -f1)"
    if [ ${#ai_parts[@]} -eq 0 ] && [ "$legacy" = 0 ]; then
        gone "$AI_DIR"
    elif [ "$KEEP_AI" = 0 ] && { [ "$YES" = 1 ] || ask "Delete Velly's models, voices and logs (${size:-?} in ${AI_DIR/#$HOME/~})?"; }; then
        gone "$AI_DIR"
    else
        [ "$legacy" = 1 ] && strip_checkout "$AI_DIR" && ok "Took the shell's files out of ${AI_DIR/#$HOME/~}"
        skip "Kept Velly's models and voices in ${AI_DIR/#$HOME/~}  ${D}(${size:-?})${N}"
    fi
fi

# ── 6. the downloaded copy ───────────────────────────────────────────────────
# Last, because this script may live inside it.
printf '\n%sThe download%s\n' "$W" "$N"
if [ -d "$GET_DIR" ]; then
    gone "$GET_DIR"
fi
if [ -d "$CHECKOUT" ] && [ -f "$CHECKOUT/shell.qml" ] && [ "$CHECKOUT" != "$HOME" ] \
   && [ "$CHECKOUT" != "$(readlink -f "$GET_DIR" 2>/dev/null)" ] && [ "$CHECKOUT" != "$(readlink -f "$AI_DIR" 2>/dev/null)" ]; then
    # installed from a folder of your own (git clone): ask before deleting it
    if [ "$YES" = 0 ] && ask "Delete the Velvet folder itself (${CHECKOUT/#$HOME/~})?"; then
        gone "$CHECKOUT"
    else
        skip "Kept ${CHECKOUT/#$HOME/~}"
    fi
fi

printf '\n  %sVelvet is gone.%s Log out and back in (or restart) to finish.\n' "$W" "$N"
printf '  %sYour own programs, files and the packages that were installed are untouched.%s\n\n' "$D" "$N"
