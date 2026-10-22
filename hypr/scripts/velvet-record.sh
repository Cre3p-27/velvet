#!/bin/bash
#  VELVET · Super+Enter — start or stop the screen recording.
#  The first press records the focused monitor WITH THE SOUND YOU HEAR: the
#  monitor of the default output, not the microphone (wf-recorder's own --audio
#  takes the default INPUT, which is how the old recordings came out with room
#  noise and none of the music). The second press stops and finalises the file
#  in ~/Videos.
#
#  Video is constant 60 fps (wf-recorder otherwise records only when the screen
#  changes — a variable frame rate that players stutter on) and H.264 at CRF 18,
#  which keeps text and thin lines sharp. Uses the first recorder it finds:
#  wl-screenrec or wf-recorder. Neither installed? The bind says what to run.

RUNDIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
PIDFILE="$RUNDIR/velvet-record.pid"
OUTFILE="$RUNDIR/velvet-record.out"
LOG="${XDG_CACHE_HOME:-$HOME/.cache}/velvet-record.log"
OUTDIR="$HOME/Videos"
OUT="$OUTDIR/velvet-$(date +%Y%m%d-%H%M%S).mp4"

say() { # message → criticality. A missing notification daemon is not a failed recording.
    local msg="$1" crit="${2:-normal}"
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u "$crit" "VELVET" "$msg" 2>/dev/null || true
    fi
    return 0
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

# The monitor of the default OUTPUT: what the speakers play, sink by sink.
sound_source() {
    local sink
    sink=$(pactl get-default-sink 2>/dev/null)
    [ -n "$sink" ] || return 0
    if pactl list short sources 2>/dev/null | cut -f2 | grep -qx "$sink.monitor"; then
        echo "$sink.monitor"
    fi
    return 0
}

# The output that has the focus (wf-recorder without -o takes the first one).
focused_output() {
    hyprctl monitors -j 2>/dev/null | python3 -c '
import json, sys
try:
    print(next(m["name"] for m in json.load(sys.stdin) if m.get("focused")))
except (ValueError, StopIteration):
    pass
' 2>/dev/null
}

stop_rec() {
    local pid saved
    pid=$(cat "$PIDFILE" 2>/dev/null)
    saved=$(cat "$OUTFILE" 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        # SIGINT = "finish the file properly" for both recorders. Wait for it:
        # the file is only playable once the recorder has written its end.
        kill -INT "$pid" 2>/dev/null
        for _ in $(seq 1 60); do
            kill -0 "$pid" 2>/dev/null || break
            sleep 0.2
        done
    fi
    rm -f "$PIDFILE" "$OUTFILE"
    if [ -n "$saved" ] && [ -s "$saved" ]; then
        say "RECORDING SAVED · $(basename "$saved") · ~/Videos" "normal"
    else
        say "RECORDING STOPPED · NOTHING WAS WRITTEN · SEE $LOG" "critical"
    fi
}

# Second press: stop. A stale pid file (recorder died on its own) is cleaned
# up and the press then falls through to starting a fresh recording.
if [ -f "$PIDFILE" ]; then
    pid=$(cat "$PIDFILE" 2>/dev/null)
    if [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null; then
        rm -f "$PIDFILE" "$OUTFILE"
    else
        stop_rec
        exit 0
    fi
fi

if [ -z "$REC" ]; then
    say "NO RECORDER INSTALLED · RUN:  sudo pacman -S wf-recorder" "critical"
    exit 0
fi

mkdir -p "$OUTDIR" "$(dirname "$LOG")"
SRC=$(sound_source)
MON=$(focused_output)
args=()
case "$(basename "$REC")" in
    wf-recorder)
        args=(-r 60 -c libx264 -p preset=veryfast -p crf=18 -x yuv420p)
        [ -n "$MON" ] && args+=(-o "$MON")
        [ -n "$SRC" ] && args+=("--audio=$SRC")
        ;;
    wl-screenrec)
        args=(--fps 60)
        [ -n "$MON" ] && args+=(-o "$MON")
        [ -n "$SRC" ] && args+=(--audio "--audio-device=$SRC")
        ;;
esac

{
    echo "--- $(date '+%F %T') · $(basename "$REC") ${args[*]} -f $OUT"
} >>"$LOG"
"$REC" "${args[@]}" -f "$OUT" >>"$LOG" 2>&1 &
pid=$!
echo "$pid" > "$PIDFILE"
echo "$OUT" > "$OUTFILE"

# A recorder that dies in its first second (no output, no audio device …)
# must say so, not pretend to record.
sleep 1
if ! kill -0 "$pid" 2>/dev/null; then
    rm -f "$PIDFILE" "$OUTFILE"
    say "COULDN'T START THE RECORDER · SEE $LOG" "critical"
    exit 1
fi

if [ -n "$SRC" ]; then
    say "RECORDING · ${MON:-screen} · WITH SOUND" "normal"
else
    say "RECORDING · ${MON:-screen} · NO SOUND (no output device found)" "critical"
fi
