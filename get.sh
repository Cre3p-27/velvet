#!/usr/bin/env bash
#  VELVET · get.sh — the one line a beginner needs:
#
#      curl -fsSL https://raw.githubusercontent.com/Cre3p/velvet/main/get.sh | bash
#
#  Downloads Velvet to ~/.local/share/velvet (or updates it when it is already
#  there) and runs the installer, which installs what is missing, wires up
#  Hyprland and adapts everything to this machine.
set -euo pipefail
REPO="${VELVET_REPO:-https://github.com/Cre3p/velvet.git}"
DIR="${VELVET_DIR:-$HOME/.local/share/velvet}"

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
    echo "Downloading Velvet to $DIR …"
    mkdir -p "$(dirname "$DIR")"
    git clone --depth 1 "$REPO" "$DIR"
fi

# the installer asks its questions on the terminal even when this script was piped in
if [ -t 1 ] && [ -r /dev/tty ]; then
    exec bash "$DIR/install.sh" "$@" < /dev/tty
else
    exec bash "$DIR/install.sh" "$@"
fi
