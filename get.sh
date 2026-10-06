#!/usr/bin/env bash
#  VELVET · get.sh — the one line a beginner needs:
#
#      curl -fsSL https://raw.githubusercontent.com/Cre3p-27/velvet/main/get.sh | bash
#
#  Downloads Velvet to ~/.local/share/velvet-src (or updates it when it is
#  already there) and runs the installer, which installs what is missing, wires
#  up Hyprland and adapts everything to this machine.
#
#  ~/.local/share/velvet is NOT used for the download: that folder belongs to
#  Velly (the assistant) and holds its models and voices, which can be large.
set -euo pipefail
REPO="${VELVET_REPO:-https://github.com/Cre3p-27/velvet.git}"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
DIR="${VELVET_DIR:-$DATA/velvet-src}"
LEGACY="$DATA/velvet"   # where older versions of this script downloaded to

if ! command -v git >/dev/null 2>&1; then
    if command -v pacman >/dev/null 2>&1; then
        echo "Installing git (asks for your password) …"
        sudo pacman -S --needed --noconfirm git
    else
        echo "Please install git first, then run this again."; exit 1
    fi
fi

if [ -d "$DIR/.git" ]; then
    echo "Updating Velvet in $DIR …"
    git -C "$DIR" pull --ff-only
else
    if [ -e "$DIR" ] && [ -n "$(ls -A "$DIR" 2>/dev/null)" ]; then
        echo "$DIR already exists and is not a Velvet download."
        echo "Move it away (or run with VELVET_DIR=/another/folder) and try again."
        exit 1
    fi
    echo "Downloading Velvet to $DIR …"
    mkdir -p "$(dirname "$DIR")"
    git clone --depth 1 "$REPO" "$DIR"
fi

# the installer asks its questions on the terminal even when this script was piped in
status=0
if [ -t 1 ] && [ -r /dev/tty ]; then
    bash "$DIR/install.sh" "$@" < /dev/tty || status=$?
else
    bash "$DIR/install.sh" "$@" || status=$?
fi
[ "$status" = 0 ] || exit "$status"

# An older download inside Velly's folder: once the shell is linked to the new
# one, take the shell's own files out of it (exactly the files git knows,
# nothing else) and leave the models alone.
QS_LINK="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/velvet"
if [ "$LEGACY" != "$DIR" ] && [ -d "$LEGACY/.git" ] && [ -f "$LEGACY/shell.qml" ] \
   && [ "$(readlink -f "$QS_LINK")" = "$(readlink -f "$DIR")" ]; then
    echo "Cleaning the old download out of $LEGACY (Velly's models stay) …"
    (
        cd "$LEGACY"
        git ls-files | sed -n 's|/[^/]*$||p' | sort -ru > "$LEGACY/.velvet-dirs" || true
        git ls-files -z | xargs -0 rm -f --
        while read -r d; do rmdir -p "$d" 2>/dev/null || true; done < "$LEGACY/.velvet-dirs"
        rm -rf .git .velvet-dirs
    )
    rmdir "$LEGACY" 2>/dev/null || true
    if command -v qs >/dev/null 2>&1 && qs -c velvet ipc show >/dev/null 2>&1; then
        echo "Restarting the shell from its new place …"
        qs -c velvet kill >/dev/null 2>&1 || true
        sleep 1
        setsid -f qs -n -c velvet -d >/dev/null 2>&1 || true
    fi
fi
