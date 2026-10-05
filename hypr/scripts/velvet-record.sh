#!/bin/bash
#  VELVET · Super+Enter — start or stop the screen recording.
#  The first press starts recording the focused monitor with sound; the
#  second stops it and finalises the file. Recordings land in ~/Videos.
#
#  Uses the first recorder it finds: wl-screenrec or wf-recorder. Neither
#  installed? The bind says what to run — everything else is already wired.

PIDFILE="/run/user/$(id -u)/velvet-record.pid"
OUTDIR="$HOME/Videos"
OUT="$OUTDIR/velvet-$(date +%Y%m%d-%H%M%S).mp4"

say() { # message → criticality
    local msg="$1" crit="${2:-normal}"
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u "$crit" "VELVET" "$msg"
    fi
}

REC=""
for c in wl-screenrec wf-recorder; do
    if command -v "$c" >/dev/null 2>&1; then
        REC=$(command -v "$c")
        break
    fi
    # ~/.local/bin is not on the session PATH — look for the binary by hand.
    if [ -x "$HOME/.local/bin/$c" ]; then
        REC="$HOME/.local/bin/$c"
        break
    fi
done

stop_rec() {
    if [ -f "$PIDFILE" ]; then
        local pid
        pid=$(cat "$PIDFILE" 2>/dev/null)
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            # SIGINT = "finish the file properly" for both recorders.
            kill -INT "$pid" 2>/dev/null
        fi
        rm -f "$PIDFILE"
    fi
}

# Second press: stop. A stale pid file (recorder died on its own) is cleaned
# up and the press then falls through to starting a fresh recording.
if [ -f "$PIDFILE" ]; then
    pid=$(cat "$PIDFILE" 2>/dev/null)
    if [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null; then
        rm -f "$PIDFILE"
    else
        stop_rec
        say "RECORDING SAVED · $OUTDIR" "normal"
        exit 0
    fi
fi

if [ -z "$REC" ]; then
    say "NO RECORDER INSTALLED · RUN:  sudo pacman -S wf-recorder" "critical"
    exit 0
fi

mkdir -p "$OUTDIR"
case "$(basename "$REC")" in
    wf-recorder)
        "$REC" --audio -f "$OUT" &
        ;;
    wl-screenrec)
        "$REC" --audio --fps 60 -f "$OUT" &
        ;;
esac
echo $! > "$PIDFILE"
say "RECORDING · $OUT" "normal"
