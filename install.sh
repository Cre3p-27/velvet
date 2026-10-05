#!/usr/bin/env bash
#
#  VELVET · install.sh
#  Puts the shell where Quickshell looks for it, wires up Hyprland, and tells
#  you what's missing. Safe to re-run; it never overwrites your config.json and
#  never edits hyprland.conf more than once.
#
set -euo pipefail

# ── flags ────────────────────────────────────────────────────────────────────
YES=0
NO_PAM=0
NO_DEPS=0
for arg in "$@"; do
    case "$arg" in
        -y|--yes)  YES=1 ;;
        --no-pam)  NO_PAM=1 ;;
        --no-deps) NO_DEPS=1 ;;
        -h|--help) cat <<HELP
usage: $0 [--yes] [--no-pam] [--no-deps]

  --yes      answer yes to every question (for scripted installs)
  --no-pam   never touch /etc/pam.d, even if asked
  --no-deps  do not offer to install missing packages
HELP
                   exit 0 ;;
        *) echo "$0: unknown argument: $arg" >&2; exit 2 ;;
    esac
done

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
DEST="$QS_DIR/velvet"
HYPR_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/velvet"
# One source of truth for "which build is this", shared with the shell.
VELVET_VERSION="$(cat "$SRC/VERSION" 2>/dev/null || echo unknown)"

R=$'\e[38;5;197m'; W=$'\e[1;37m'; D=$'\e[2m'; G=$'\e[38;5;79m'; Y=$'\e[38;5;221m'; N=$'\e[0m'

say()  { printf '%s\n' "$*"; }
head2() { printf '\n%s%s%s\n' "$W" "$*" "$N"; }
ok()   { printf '  %s✓%s %s\n' "$G" "$N" "$*"; }
warn() { printf '  %s!%s %s\n' "$Y" "$N" "$*"; }
bad()  { printf '  %s✗%s %s\n' "$R" "$N" "$*"; }

cat <<BANNER
${R}
   ██╗   ██╗███████╗██╗    ██╗   ██╗███████╗████████╗
   ██║   ██║██╔════╝██║    ██║   ██║██╔════╝╚══██╔══╝
   ██║   ██║█████╗  ██║    ██║   ██║█████╗     ██║
   ╚██╗ ██╔╝██╔══╝  ██║    ╚██╗ ██╔╝██╔══╝     ██║
    ╚████╔╝ ███████╗███████╗╚████╔╝ ███████╗   ██║
     ╚═══╝  ╚══════╝╚══════╝ ╚═══╝  ╚══════╝   ╚═╝
${N}${D}   a quickshell desktop for hyprland  ·  build ${VELVET_VERSION}${N}
BANNER

# ── 0. packages ──────────────────────────────────────────────────────────────
# A beginner should not have to know package names. On Arch and its family
# (EndeavourOS, CachyOS, Manjaro, Garuda …) everything missing is installed in
# one go; elsewhere the exact list is printed. One package at a time, so one
# unknown name never blocks the rest.
ask() { # ask "question" → 0 for yes (default yes)
    [ "$YES" = 1 ] && return 0
    [ -t 0 ] || return 1
    printf '  %s%s [Y/n] %s' "$Y" "$1" "$N"
    local r; read -r r || r=""
    case "$r" in n|N|no|No) return 1 ;; *) return 0 ;; esac
}

OS_ID=""; OS_LIKE=""
if [ -f /etc/os-release ]; then
    OS_ID="$(. /etc/os-release; echo "${ID:-}")"
    OS_LIKE="$(. /etc/os-release; echo "${ID_LIKE:-}")"
fi
AUR=""
for h in paru yay; do command -v "$h" >/dev/null 2>&1 && { AUR="$h"; break; }; done

# command → package (Arch names)
declare -A PKG=(
    [hyprctl]=hyprland [qs]=quickshell [python3]=python [wpctl]=wireplumber
    [brightnessctl]=brightnessctl [nmcli]=networkmanager [bluetoothctl]=bluez-utils
    [playerctl]=playerctl [wl-copy]=wl-clipboard [curl]=curl [grim]=grim [slurp]=slurp
    [cava]=cava [pw-play]=pipewire [kitty]=kitty [fc-list]=fontconfig [git]=git
)
need_pkgs=()
for c in "${!PKG[@]}"; do
    if [ "$c" = qs ]; then command -v qs >/dev/null 2>&1 || command -v quickshell >/dev/null 2>&1 || need_pkgs+=("${PKG[$c]}"); continue; fi
    command -v "$c" >/dev/null 2>&1 || need_pkgs+=("${PKG[$c]}")
done
python3 -c 'import evdev' >/dev/null 2>&1 || need_pkgs+=(python-evdev)

if [ "$NO_DEPS" = 0 ] && [ ${#need_pkgs[@]} -gt 0 ]; then
    head2 "Packages"
    say "  ${D}Missing: ${need_pkgs[*]}${N}"
    if command -v pacman >/dev/null 2>&1; then
        if ask "Install them now (asks for your password)?"; then
            for p in "${need_pkgs[@]}"; do
                if sudo pacman -S --needed --noconfirm "$p" >/dev/null 2>&1; then ok "$p"
                elif [ -n "$AUR" ] && "$AUR" -S --needed --noconfirm "$p" >/dev/null 2>&1; then ok "$p  ${D}(AUR)${N}"
                else warn "$p could not be installed  ${D}— try:  ${AUR:-paru} -S $p${N}"; fi
            done
        fi
    else
        warn "Automatic install works on Arch-based systems; on ${OS_ID:-your system} please install:"
        say  "     ${D}hyprland quickshell python3 python3-evdev wireplumber brightnessctl NetworkManager bluez playerctl wl-clipboard curl grim slurp cava kitty${N}"
        say  "     ${D}(names differ a little per distribution — Quickshell: https://quickshell.org/docs/master/guide/install/)${N}"
    fi
fi

# Fonts the shell is drawn with — fetched into ~/.local/share/fonts when missing
# (Material Symbols: Apache-2.0, Archivo Black: OFL), no package needed.
if command -v fc-list >/dev/null 2>&1 && command -v curl >/dev/null 2>&1 && [ "$NO_DEPS" = 0 ]; then
    FL="$(fc-list 2>/dev/null | tr '[:upper:]' '[:lower:]')" || FL=""
    FONT_DIR="$HOME/.local/share/fonts/velvet"
    want_fonts=()
    [[ "$FL" == *"material symbols"* ]] || want_fonts+=("MaterialSymbolsRounded.ttf|https://github.com/google/material-design-icons/raw/master/variablefont/MaterialSymbolsRounded%5BFILL,GRAD,opsz,wght%5D.ttf")
    [[ "$FL" == *"archivo black"* ]] || want_fonts+=("ArchivoBlack-Regular.ttf|https://github.com/google/fonts/raw/main/ofl/archivoblack/ArchivoBlack-Regular.ttf")
    if [ ${#want_fonts[@]} -gt 0 ] && ask "Download the shell's fonts (icons + display face)?"; then
        mkdir -p "$FONT_DIR"
        for f in "${want_fonts[@]}"; do
            name="${f%%|*}"; url="${f#*|}"
            if curl -fsSL -o "$FONT_DIR/$name" "$url"; then ok "font: $name"; else warn "could not download $name"; fi
        done
        fc-cache -f >/dev/null 2>&1 || true
    fi
fi

# ── 1. hard requirements ─────────────────────────────────────────────────────
head2 "Checking requirements"
missing=0
# The binary is `qs` on most distros, `quickshell` on some; either is fine.
QS_BIN=""
for b in qs quickshell; do
    command -v "$b" >/dev/null 2>&1 && { QS_BIN="$b"; break; }
done
if [ -n "$QS_BIN" ]; then
    ok "$QS_BIN"
else
    bad "qs / quickshell  — required"
    missing=1
fi
if command -v hyprctl >/dev/null 2>&1; then
    ok "hyprctl"
else
    bad "hyprctl  — required"
    missing=1
fi
if [ "$missing" = 1 ]; then
    say ""
    say "  Install Quickshell first:"
    say "    Arch  : paru -S quickshell            (or quickshell-git)"
    say "    Nix   : github:quickshell-mirror/quickshell"
    say "    Source: https://quickshell.org/docs/master/guide/install/"
    exit 1
fi

# ── 2. soft requirements ─────────────────────────────────────────────────────
head2 "Optional, but the shell is better with them"
soft_missing=()
check_soft() {
    if command -v "$1" >/dev/null 2>&1; then ok "$1  ${D}— $2${N}"
    else warn "$1  ${D}— $2${N}"; soft_missing+=("$1"); fi
}
check_soft wpctl        "volume and mute (pipewire)"
check_soft brightnessctl "screen brightness"
check_soft nmcli        "network status"
check_soft bluetoothctl "bluetooth status"
check_soft swww         "only if you prefer an external wallpaper daemon"
check_soft hyprsunset   "night light (wlsunset/gammastep also work)"
check_soft pw-play      "menu sounds (paplay/aplay also work)"
check_soft playerctl    "media keys"
check_soft wl-copy      "launcher calculator copies its answer"
check_soft curl         "the weather module"
check_soft grim         "the screenshot module"
check_soft cava         "real audio levels in velvet-pulse, and the audio-reactive desktop"
check_soft slurp        "region select for screenshots"

head2 "Fonts"
# Read the list ONCE and match it in bash. `fc-list | grep -q` looks obvious
# and is wrong under pipefail: grep exits at the first hit, fc-list dies of
# SIGPIPE, and the pipeline reports 141 — a font you have, reported missing.
FONTS_LC=""
if command -v fc-list >/dev/null 2>&1; then
    FONTS_LC="$(fc-list 2>/dev/null | tr '[:upper:]' '[:lower:]')" || FONTS_LC=""
fi
have_font() { local needle="${1,,}"; [[ "$FONTS_LC" == *"$needle"* ]]; }
if command -v fc-list >/dev/null 2>&1; then
    have_font "Material Symbols" && ok "Material Symbols  ${D}— bar icons${N}" \
        || warn "Material Symbols  ${D}— bar falls back to unicode glyphs${N}"
    if have_font "Archivo Black" || have_font "Anton" || have_font "Bebas Neue" || have_font "Oswald"; then
        ok "A heavy display face is installed"
    else
        warn "No heavy display face found  ${D}— the Persona look wants one${N}"
        say  "     ${D}Arch: paru -S ttf-archivo otf-material-symbols-git${N}"
    fi
else
    warn "fontconfig not found, skipping font check"
fi

# ── 3. install ───────────────────────────────────────────────────────────────
head2 "Installing"
mkdir -p "$QS_DIR" "$CFG_DIR"

if [ "$SRC" = "$DEST" ]; then
    # Already living where the shell is loaded from. Moving it aside here
    # would rename the checkout out from under the rest of this script.
    ok "Already in place at $DEST"
else
    if [ -e "$DEST" ] && [ ! -L "$DEST" ]; then
        backup="$DEST.backup.$(date +%s)"
        mv "$DEST" "$backup"
        warn "Existing $DEST moved to $(basename "$backup")"
    fi
    rm -f "$DEST"
    ln -s "$SRC" "$DEST"
    ok "Linked $DEST → $SRC"
fi

# ── the little desktop programs ──────────────────────────────────────────────
# They are launched by absolute path, so PATH is not required for the desktop
# scene to work. The symlinks are a convenience for running them by hand.
chmod +x "$SRC"/bin/velvet-* 2>/dev/null || true
LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN"
linked=0
for prog in "$SRC"/bin/velvet-*; do
    [ -f "$prog" ] || continue
    ln -sf "$prog" "$LOCAL_BIN/$(basename "$prog")"
    linked=$((linked + 1))
done
ok "Linked $linked desktop programs into ~/.local/bin"
case ":$PATH:" in
    *":$LOCAL_BIN:"*) : ;;
    *) warn "~/.local/bin is not on your PATH  ${D}— the desktop still starts them by full path${N}" ;;
esac

TERM_FOUND=""
for t in kitty foot ghostty wezterm alacritty konsole xterm; do
    command -v "$t" >/dev/null 2>&1 && { TERM_FOUND="$t"; break; }
done
if [ -n "$TERM_FOUND" ]; then
    ok "Terminal for desktop programs: $TERM_FOUND"
else
    warn "No terminal emulator found  ${D}— the clock, vitals and the rest need one${N}"
fi

# Sounds: regenerate only if they're missing, so local edits survive.
if [ -f "$SRC/assets/sfx/cursor.wav" ]; then
    ok "UI sounds present"
elif command -v python3 >/dev/null 2>&1; then
    if python3 "$SRC/assets/make-sfx.py" >/dev/null 2>&1; then
        ok "Generated UI sounds"
    else
        warn "Could not generate the UI sounds  ${D}— the shell runs silently${N}"
    fi
else
    warn "No python3 and no sound files  ${D}— the shell runs silently${N}"
fi

# The vibes' sound packs and pixel typeface — also made here, only if missing.
if command -v python3 >/dev/null 2>&1; then
    if [ -f "$SRC/assets/sfx/arcade/cursor.wav" ] && [ -f "$SRC/assets/sfx/windows/cursor.wav" ] && [ -f "$SRC/assets/sfx/clean/cursor.wav" ]; then
        ok "Vibe sound packs present"
    elif python3 "$SRC/assets/make-sfx-packs.py" >/dev/null 2>&1; then
        ok "Generated the vibe sound packs"
    else
        warn "Could not generate the vibe sound packs  ${D}— those vibes use the house sounds${N}"
    fi
    if [ -f "$SRC/assets/fonts/VelvetPixel.ttf" ]; then
        ok "Pixel typeface present"
    elif python3 "$SRC/assets/make-font.py" >/dev/null 2>&1; then
        ok "Drew the pixel typeface"
    else
        warn "Could not draw the pixel typeface  ${D}— the ARCADE vibe falls back to a monospace${N}"
    fi
fi

# ── 4. hyprland wiring ───────────────────────────────────────────────────────
head2 "Wiring up Hyprland"
mkdir -p "$HYPR_DIR"

# Which config language are you on? Hyprland reads hyprland.lua if it exists,
# otherwise hyprland.conf — and the two need completely different wiring.
if [ -f "$HYPR_DIR/hyprland.lua" ]; then
    HL_LANG="lua"
    HL_CONF="$HYPR_DIR/hyprland.lua"
    INTEGRATION="velvet-shell.lua"
    GENERATED="velvet.lua"
    LINE='require("velvet-shell")'
    MARKER='require("velvet-shell")'
    COMMENT='-- ── VELVET ──────────────────────────────────────────────'
    STUB='-- Written by Velvet. Change these in Super+Tab, not here.'
else
    HL_LANG="conf"
    INTEGRATION="velvet-shell.conf"
    GENERATED="velvet.conf"
    LINE="source = $HYPR_DIR/velvet-shell.conf"
    MARKER='velvet-shell.conf'
    COMMENT='# ── VELVET ──────────────────────────────────────────────'
    STUB='# Written by Velvet. Change these in Super+Tab, not here.'

    HL_CONF=""
    for c in "$HYPR_DIR/hyprland.conf" "$HOME/.hyprland.conf"; do
        [ -f "$c" ] && { HL_CONF="$c"; break; }
    done
    if [ -z "$HL_CONF" ]; then
        # `find` exits non-zero for every start point that is missing, and
        # ~/.dotfiles usually is; under `set -euo pipefail` that ended the
        # install right here, silently.
        search_dirs=()
        for d in "$HOME/.config" "$HOME/.dotfiles" "$HOME/dotfiles"; do
            [ -d "$d" ] && search_dirs+=("$d")
        done
        HL_CONF=""
        if [ ${#search_dirs[@]} -gt 0 ]; then
            HL_CONF="$(find "${search_dirs[@]}" -maxdepth 4 -name 'hyprland.conf' \
                            -type f 2>/dev/null | head -1 || true)"
            [ -z "$HL_CONF" ] && HL_CONF="$(find "${search_dirs[@]}" -maxdepth 4 \
                            -name 'hyprland.lua' -type f 2>/dev/null | head -1 || true)"
            # The search can turn up a hyprland.lua even though this branch
            # started out as "conf" — and Hyprland prefers Lua. Wiring a Lua
            # file with `source = …` breaks the parse on the next reload, so
            # the moment we know, we switch dialect.
            if [ -n "$HL_CONF" ] && [ "${HL_CONF##*.}" = "lua" ]; then
                HL_LANG="lua"
                INTEGRATION="velvet-shell.lua"
                GENERATED="velvet.lua"
                LINE='require("velvet-shell")'
                MARKER='require("velvet-shell")'
                COMMENT='-- ── VELVET ──────────────────────────────────────────────'
                STUB='-- Written by Velvet. Change these in Super+Tab, not here.'
            fi
        fi
    fi
fi
ok "Config language: ${HL_LANG}"

cp -f "$SRC/hypr/$INTEGRATION" "$HYPR_DIR/$INTEGRATION"
ok "Wrote $HYPR_DIR/$INTEGRATION"

# The generated half — create a stub so the require/source never fails before
# the shell has written it for the first time.
[ -f "$HYPR_DIR/$GENERATED" ] || {
    printf '%s\n' "$STUB" > "$HYPR_DIR/$GENERATED"
    ok "Created $HYPR_DIR/$GENERATED (managed by the shell)"
}

if [ -n "${HL_CONF:-}" ] && [ -f "$HL_CONF" ]; then
    if grep -qF "$MARKER" "$HL_CONF"; then
        ok "$(basename "$HL_CONF") already pulls in Velvet"
    else
        cp "$HL_CONF" "$HL_CONF.pre-velvet"
        printf '\n%s\n%s\n' "$COMMENT" "$LINE" >> "$HL_CONF"
        ok "Appended the line to $(basename "$HL_CONF")"
        say "     ${D}backup: $(basename "$HL_CONF").pre-velvet${N}"
    fi
else
    warn "No Hyprland config found — add this line at the END of yours:"
    say  ""
    say  "       $LINE"
    say  ""
    say  "     Without it you get no keybinds and no autostart. The shell still"
    say  "     runs if you launch it by hand:  $QS_BIN -c velvet -d"
fi

# The infinite desktop, the zoom and the window tools: shipped as their own
# file and pulled in — unless your config already binds them itself.
if [ "$HL_LANG" = lua ]; then DESK_FILE="velvet-desktop.lua"; DESK_LINE='require("velvet-desktop")'; else DESK_FILE="velvet-desktop.conf"; DESK_LINE="source = $HYPR_DIR/velvet-desktop.conf"; fi
cp -f "$SRC/hypr/$DESK_FILE" "$HYPR_DIR/$DESK_FILE"
if [ -n "${HL_CONF:-}" ] && [ -f "$HL_CONF" ]; then
    if grep -qF "$DESK_LINE" "$HL_CONF"; then
        ok "Infinite desktop already wired"
    elif grep -qE "infinite_desktop_core|floating_tile_toggle|desktop_zoom.py" "$HL_CONF"; then
        ok "Your config binds the desktop tools itself  ${D}— left as it is${N}"
    else
        printf '\n%s\n' "$DESK_LINE" >> "$HL_CONF"
        ok "Infinite desktop, zoom and window tools wired  ${D}(Super+Z/X, Super+D, Super+Alt+wheel …)${N}"
    fi
fi

# The canvas engine reads the mouse and keyboard directly: your user must be
# in the `input` group (takes effect after the next login).
if ! id -nG "$USER" 2>/dev/null | tr ' ' '\n' | grep -qx input; then
    if ask "Let the infinite desktop read mouse and keyboard (adds you to the 'input' group)?"; then
        sudo usermod -aG input "$USER" && ok "Added to the input group  ${D}— log out and in once${N}" || warn "Could not add you to the input group"
    else
        warn "Not in the input group  ${D}— Super+drag panning stays off${N}"
    fi
else
    ok "In the input group  ${D}— Super+drag pans the infinite desktop${N}"
fi

# ── 4b. PAM service for the built-in lock ────────────────────────────────────
# Velvet's own lock screen needs a PAM service to authenticate against. Using
# another program's (hyprlock's, swaylock's) works but is impolite and breaks
# when that program is uninstalled — so offer to install our own one-liner,
# exactly as those packages do.
head2 "Lock screen"
if [ -f /etc/pam.d/velvet ]; then
    ok "/etc/pam.d/velvet already present"
else
    PAM_BASE=""
    [ -f /etc/pam.d/system-auth ] && PAM_BASE="system-auth"
    [ -z "$PAM_BASE" ] && [ -f /etc/pam.d/common-auth ] && PAM_BASE="common-auth"

    if [ -z "$PAM_BASE" ]; then
        warn "No system-auth or common-auth found — skipping"
        say  "     ${D}Velvet will fall back to an existing service, or to your own locker.${N}"
    elif [ "$NO_PAM" = 1 ]; then
        warn "--no-pam given — skipping the PAM service"
    elif [ -t 0 ] && command -v sudo >/dev/null 2>&1; then
        if [ "$YES" = 1 ]; then
            reply="y"
            say "  ${D}Installing /etc/pam.d/velvet  (--yes)${N}"
        else
            say "  Velvet's lock screen needs a PAM service to check your password."
            say "  ${D}It would install one file:  /etc/pam.d/velvet  →  auth include $PAM_BASE${N}"
            say "  ${D}Skipping is fine — the lock stays off and your usual locker is used.${N}"
            printf '  Install it? [y/N] '
            read -r reply || reply=""
        fi
        case "$reply" in
            [Yy]*)
                if printf '#%%PAM-1.0\nauth      include   %s\naccount   include   %s\n' "$PAM_BASE" "$PAM_BASE" \
                     | sudo tee /etc/pam.d/velvet >/dev/null; then
                    ok "Wrote /etc/pam.d/velvet"
                else
                    warn "Could not write it — the lock will fall back"
                fi
                ;;
            *) say "  ${D}Skipped.${N}" ;;
        esac
    else
        if [ -t 0 ]; then
            warn "sudo not found — skipping the PAM service"
        else
            warn "Not interactive — skipping the PAM service"
        fi
        say  "     ${D}To add it later:${N}"
        say  "       printf '#%%PAM-1.0\\nauth include $PAM_BASE\\naccount include $PAM_BASE\\n' | sudo tee /etc/pam.d/velvet"
    fi
fi

LOCKER_FOUND=""
for l in hyprlock swaylock waylock gtklock; do
    command -v "$l" >/dev/null 2>&1 && { LOCKER_FOUND="$l"; break; }
done
if [ -n "$LOCKER_FOUND" ]; then
    ok "External locker available: $LOCKER_FOUND"
elif [ -f /etc/pam.d/velvet ]; then
    ok "No external locker, but Velvet's own lock can take over"
else
    warn "No locker at all — Velvet will refuse to lock rather than blank the screen"
    say  "     ${D}Install hyprlock, or let this script add the PAM file above.${N}"
fi

# ── 4c. login screen ─────────────────────────────────────────────────────────
# With SDDM auto-login, a reboot lands on Velvet's lock, which asks for the
# password — the lock IS the login screen. The two halves must go together:
# auto-login without LOCK AT BOOT would boot into an open session.
head2 "Login screen"
SDDM_DROP="/etc/sddm.conf.d/velvet-autologin.conf"
if [ -f "$SDDM_DROP" ]; then
    ok "$SDDM_DROP already present"
    say  "     ${D}It enables auto-login; pair it with LOCK AT BOOT in the LOCK SCREEN tab.${N}"
elif command -v sddm >/dev/null 2>&1 || [ -d /etc/sddm.conf.d ]; then
    SESSION="hyprland"
    if [ -f /usr/share/wayland-sessions/hyprland-uwsm.desktop ] \
       && [ ! -f /usr/share/wayland-sessions/hyprland.desktop ]; then
        SESSION="hyprland-uwsm"
    fi
    if [ -t 0 ] && [ "$YES" = 0 ] && command -v sudo >/dev/null 2>&1; then
        say "  Use Velvet's lock as your login screen? SDDM auto-logs in and"
        say "  the lock appears at boot to ask for the password."
        say "  ${D}Auto-login alone would leave the session open — this turns on${N}"
        say "  ${D}LOCK AT BOOT in your config as well.${N}"
        printf '  Set it up? [y/N] '
        read -r reply || reply=""
        case "$reply" in
            [Yy]*)
                if sudo mkdir -p /etc/sddm.conf.d \
                   && printf '[Autologin]\nUser=%s\nSession=%s\n' "$USER" "$SESSION" \
                      | sudo tee "$SDDM_DROP" >/dev/null 2>&1; then
                    ok "Wrote $SDDM_DROP (user $USER, session $SESSION)"
                    if command -v python3 >/dev/null 2>&1; then
                        if python3 - "$CFG_DIR/config.json" <<'PY'
import json, sys
path = sys.argv[1]
try:
    data = json.load(open(path))
except Exception:
    data = {}
data.setdefault("lock", {})["lockOnStart"] = True
json.dump(data, open(path, "w"), indent=4)
PY
                        then ok "Enabled LOCK AT BOOT in $CFG_DIR/config.json"
                        else warn "Could not edit config.json — enable LOCK AT BOOT in the LOCK SCREEN tab"
                        fi
                    else
                        warn "python3 not found — enable LOCK AT BOOT in the LOCK SCREEN tab"
                    fi
                else
                    warn "Could not write the SDDM drop-in — skipping"
                fi
                ;;
            *) say "  ${D}Skipped.${N}" ;;
        esac
    else
        warn "SDDM present but not setting up auto-login"
        say  "     ${D}To do it later:${N}"
        say  "       sudo mkdir -p /etc/sddm.conf.d && printf '[Autologin]\\nUser=\$USER\\nSession=$SESSION\\n' | sudo tee $SDDM_DROP"
        say  "     ${D}…then switch LOCK AT BOOT on in Super+Tab → LOCK SCREEN.${N}"
    fi
fi

# ── 5. wallpapers and first-run config ───────────────────────────────────────
head2 "Wallpapers"
ok "Velvet paints the wallpaper itself — no daemon needed, and it survives a reboot"
for d in "$HOME/Pictures/Wallpapers" "$HOME/Bilder/Wallpapers" \
         "$HOME/Pictures/wallpapers" "$HOME/Bilder/wallpapers" "$HOME/Wallpapers"; do
    if [ -d "$d" ]; then
        ok "Found $d"
        FOUND_WALLS="$d"
        break
    fi
done
[ -z "${FOUND_WALLS:-}" ] && {
    warn "No wallpaper folder found"
    say  "     ${D}Set one in ~/.config/velvet/config.json → wallpaper.directory${N}"
}

head2 "First-run config"
if command -v python3 >/dev/null 2>&1; then
    python3 "$SRC/tools/seed-config.py" "$CFG_DIR/config.json" "${FOUND_WALLS:-}" \
        2>/dev/null || warn "Could not seed config.json — the shell will use its own defaults"
else
    warn "python3 not found — skipping the first-run config"
fi

# ── 5b. self check ───────────────────────────────────────────────────────────
head2 "Self check"
if command -v python3 >/dev/null 2>&1; then
    if python3 "$SRC/tools/qmlcheck.py" >/dev/null 2>&1; then
        ok "qmlcheck: every file parses and cross-references"
    else
        warn "qmlcheck found problems — run:  python3 $SRC/tools/qmlcheck.py"
    fi
    st_ok=0
    for prog in "$SRC"/bin/velvet-*; do
        [ -f "$prog" ] || continue
        if ! python3 "$prog" --selftest >/dev/null 2>&1; then
            warn "$(basename "$prog") failed its self-test"
            st_ok=1
        fi
    done
    [ "$st_ok" = 0 ] && ok "The desktop programs all pass their self-tests"
else
    warn "python3 not found — skipping the self check"
fi

# ── 5c. the desktop zoom-out plugin ──────────────────────────────────────────
head2 "Desktop zoom-out plugin"
if [ -x "$SRC/tools/build-zoom-plugin.sh" ] && command -v g++ >/dev/null 2>&1 && command -v pkg-config >/dev/null 2>&1 && pkg-config --exists hyprland 2>/dev/null; then
    if "$SRC/tools/build-zoom-plugin.sh" >/dev/null 2>&1; then
        ok "velvetzoom built — SUPER+ALT+wheel shrinks every window as a live texture"
    else
        warn "velvetzoom did not build — the zoom keeps its older fallback (tools/build-zoom-plugin.sh shows why)"
    fi
else
    say "  ${D}No compiler or Hyprland headers: the zoom-out uses its fallback (windows resize instead of scale).${N}"
fi

# ── 6. go ────────────────────────────────────────────────────────────────────
head2 "Done"
say "  ${W}Installed build ${VELVET_VERSION}${N}"
say "  ${D}If an error mentions a line you already fixed, you are running an older${N}"
say "  ${D}copy — check with:  cat ~/.config/quickshell/velvet/VERSION${N}"
say ""
say "  ${W}Start it now:${N}      $QS_BIN -c velvet -d"
say "  ${W}Watch for errors:${N}  $QS_BIN -c velvet          ${D}(stays in the terminal)${N}"
say "  ${W}Stop it:${N}           $QS_BIN -c velvet kill"
say ""
say "  ${R}Super + Tab${N}     settings          ${D}— then just start typing to search${N}"
say "  ${R}Super + Space${N}   launcher"
say "  ${R}Super + N${N}       notifications"
say "  ${R}Super + Escape${N}  power menu"
say "  ${R}Super + Shift + F${N}  focus mode  ${D}— silence everything, one key${N}"
say "  ${R}Super + Shift + M${N}  the mini desktop  ${D}— or just reach for the top edge${N}"
say "  ${R}Super + Shift + S${N}  open the desktop you arranged${N}"
  say "  ${R}Super + W${N}  wallpaper wheel"
say "  ${R}Super + Shift + L${N}  lyrics"
say "  ${R}Super + Shift + K${N}  every shortcut, on one screen"
say ""
if [ ${#soft_missing[@]} -gt 0 ]; then
    say "  ${D}Missing optional tools: ${soft_missing[*]}${N}"
    say "  ${D}Everything still runs; those features just sit out.${N}"
    say ""
fi
say "  ${R}Super + Z / X${N}   previous / next desktop      ${R}Super + D${N}  floating ⇄ tiled"
say "  ${R}Super + Alt + wheel${N}  zoom the desktop out"
say ""
say "  ${W}A welcome page opens with the shell${N} ${D}— it walks you through everything;${N}"
say "  ${D}switch it off on the page itself or in Super+Tab → HOME.${N}"
say ""
say "  ${W}New here:${N}"
say "  ${D}  Super+Tab → DESKTOP   drag programs onto a picture of your screen.${N}"
say "  ${D}                        They open where you put them, and again on login.${N}"
say "  ${D}  Super+Tab → LAYOUT    the taskbar, arranged by hand.${N}"
say "  ${D}  Top edge              the mini desktop: click a window to go to it,${N}"
say "  ${D}                        drag one to move it, scroll to see every desktop.${N}"
say ""
say "  ${D}Reload Hyprland to pick up the keybinds:  hyprctl reload${N}"
say ""

if [ -f "$HYPR_DIR/$GENERATED" ] && [ -n "${HL_CONF:-}" ]; then
    if [ -t 0 ] && [ "$YES" = 0 ]; then
        printf '  ${Y}Reload Hyprland now? [y/N] ${N}'
        read -r reply || reply=""
        [ "$reply" = y ] || [ "$reply" = Y ] && hyprctl reload >/dev/null 2>&1 && ok "Hyprland reloaded"
    fi
fi
