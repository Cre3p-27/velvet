#!/bin/bash
#  VELVET · Super+Enter — start or stop the screen recording.
#
#  The first press asks the shell for a countdown — 3 · 2 · 1 in the middle of
#  the screen (SHELL → SCREEN RECORDING, `ipc call record begin`) — and starts
#  recording once it has gone, so no countdown is ever in the video. Without a
#  running shell, or with the countdown OFF, a short "recording starts" note
#  does the same job. It records the focused
#  monitor WITH THE SOUND YOU HEAR: the monitor of the default output, not the
#  microphone (wf-recorder's own --audio takes the default INPUT — that is how
#  the old recordings came out with room noise and none of the music). The
#  second press stops it, finalises the file in ~/Videos and offers to play it
#  or open the folder. A press during the short wait cancels the start.
#
#  Encoding: the GPU first (H.264 through VA-API on the card that drives the
#  focused monitor — no load on the CPU, fine while a game runs), colours
#  converted to BT.709 in the standard video range and labelled so, so every player shows
#  them as they were.
#  When the GPU cannot take the frames straight from the compositor, the CPU
#  takes over (x264, constant 60 fps, CRF 18). VELVET_RECORD_DEVICE=/dev/dri/…
#  picks the GPU by hand; VELVET_RECORD_CPU=1 skips it.
#
#  Uses the first recorder it finds: wl-screenrec or wf-recorder. Neither
#  installed? The bind says what to run.

RUNDIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
PIDFILE="$RUNDIR/velvet-record.pid"
OUTFILE="$RUNDIR/velvet-record.out"
LOG="${XDG_CACHE_HOME:-$HOME/.cache}/velvet-record.log"
OUTDIR="$HOME/Videos"
OUT="$OUTDIR/velvet-$(date +%Y%m%d-%H%M%S).mp4"
PREROLL_MS=1000

say() { # message → criticality. A missing notification daemon is not a failed recording.
    local msg="$1" crit="${2:-normal}"
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -a Velvet -u "$crit" "VELVET" "$msg" 2>/dev/null || true
    fi
    return 0
}

# a short status line that stays out of the notification history
say_brief() { # message → milliseconds
    command -v notify-send >/dev/null 2>&1 || return 0
    notify-send -a Velvet -e -t "$2" -u low -i media-record "VELVET" "$1" 2>/dev/null || true
    return 0
}

# the saved file: play it or open its folder (the note waits for the click in the background)
say_saved() {
    command -v notify-send >/dev/null 2>&1 || return 0
    (
        act=$(notify-send -a Velvet -u normal -i video-x-generic -A play="Play" -A open="Open folder" \
            "VELVET" "RECORDING SAVED · $(basename "$1")" 2>/dev/null)
        case "$act" in
            play) xdg-open "$1" ;;
            open) xdg-open "$(dirname "$1")" ;;
        esac
    ) >/dev/null 2>&1 &
    return 0
}

# The shell's side of a recording (services/Panels.qml, target "record"):
# begin → the countdown's seconds, cancel, started, stopped. Fails quietly
# when no shell runs.
shell_says() {
    command -v qs >/dev/null 2>&1 || return 1
    timeout 2 qs -c velvet ipc call record "$1" 2>/dev/null
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

# The render node of the GPU that drives an output (HDMI-A-1 → card1 → renderD128).
render_node() {
    local f card node
    [ -n "$1" ] || return 0
    for f in /sys/class/drm/card*-"$1"; do
        [ -e "$f" ] || continue
        card=$(basename "$f")
        card=${card%%-*}
        for node in /sys/class/drm/"$card"/device/drm/renderD*; do
            [ -e "$node" ] && { echo "/dev/dri/$(basename "$node")"; return 0; }
        done
    done
    return 0
}

# Both paths write BT.709 in the video range but do not say so in the file, and a
# player that has to guess may guess BT.601 — every colour then shifts a little.
# A stream copy writes the label (no re-encoding) and puts the index up front,
# so the file starts at once in a browser or a chat.
label_colours() {
    local f="$1" tmp
    command -v ffmpeg >/dev/null 2>&1 || return 0
    tmp="${f%.mp4}.labelled.mp4"
    if ffmpeg -v error -y -i "$f" -map 0 -c copy \
        -bsf:v h264_metadata=video_full_range_flag=0:colour_primaries=1:transfer_characteristics=1:matrix_coefficients=1 \
        -movflags +faststart "$tmp" >>"$LOG" 2>&1 && [ -s "$tmp" ]; then
        mv -f "$tmp" "$f"
    else
        rm -f "$tmp"
    fi
    return 0
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
    shell_says stopped >/dev/null
    if [ -n "$saved" ] && [ -s "$saved" ]; then
        label_colours "$saved"
        say_saved "$saved"
    else
        say "RECORDING STOPPED · NOTHING WAS WRITTEN · SEE $LOG" "critical"
    fi
}

# Second press: stop — or, during the short wait before the start, cancel it.
# A stale pid file (the recorder died on its own) is cleaned up and the press
# falls through to a fresh recording.
if [ -f "$PIDFILE" ]; then
    pid=$(cat "$PIDFILE" 2>/dev/null)
    case "$pid" in
        wait:*)
            if kill -0 "${pid#wait:}" 2>/dev/null; then
                kill "${pid#wait:}" 2>/dev/null
                rm -f "$PIDFILE" "$OUTFILE"
                # the shell stops its countdown and says so; no shell: the note
                shell_says cancel >/dev/null || say_brief "RECORDING CANCELLED" 1200
                exit 0
            fi
            rm -f "$PIDFILE" "$OUTFILE"
            ;;
        *)
            if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                stop_rec
                exit 0
            fi
            rm -f "$PIDFILE" "$OUTFILE"
            ;;
    esac
fi

if [ -z "$REC" ]; then
    say "NO RECORDER INSTALLED · RUN:  sudo pacman -S wf-recorder" "critical"
    exit 0
fi

mkdir -p "$OUTDIR" "$(dirname "$LOG")"
SRC=$(sound_source)
MON=$(focused_output)

# the wait: the shell's countdown (or the short note) goes, then the recording
# starts — a press now cancels
echo "wait:$$" > "$PIDFILE"
COUNT=$(shell_says begin | tr -dc '0-9')
if [ -n "$COUNT" ] && [ "$COUNT" -gt 0 ]; then
    # no sound to record: said during the countdown, gone before the start
    [ -n "$SRC" ] || say_brief "NO SOUND IN THIS RECORDING · no output device found" "$((COUNT * 1000 - 600))"
    # the last number fades in 0.16 s; the recorder starts after it is gone
    sleep "$COUNT.35"
else
    if [ -n "$SRC" ]; then
        say_brief "RECORDING STARTS · ${MON:-screen} · WITH SOUND · SUPER+ENTER STOPS" "$PREROLL_MS"
    else
        say_brief "RECORDING STARTS · ${MON:-screen} · NO SOUND (no output device found)" "$PREROLL_MS"
    fi
    sleep "$(printf '%d.%03d' $(((PREROLL_MS + 500) / 1000)) $(((PREROLL_MS + 500) % 1000)))"
fi

# start the recorder: $1 = gpu | cpu. Leaves its pid in $pid; the log grows from $mark.
start() {
    local args=() dev
    case "$(basename "$REC")" in
        wf-recorder)
            if [ "$1" = gpu ]; then
                dev="${VELVET_RECORD_DEVICE:-$(render_node "$MON")}"
                args=(-c h264_vaapi -F "scale_vaapi=format=nv12:out_range=tv" -p qp=20)
                [ -n "$dev" ] && args+=(-d "$dev")
            else
                args=(-r 60 -c libx264 -p preset=veryfast -p crf=18 -x yuv420p -F "fps=60,scale=out_color_matrix=bt709:out_range=tv")
            fi
            [ -n "$MON" ] && args+=(-o "$MON")
            [ -n "$SRC" ] && args+=("--audio=$SRC")
            ;;
        wl-screenrec)
            args=(--fps 60)
            [ -n "$MON" ] && args+=(-o "$MON")
            [ -n "$SRC" ] && args+=(--audio "--audio-device=$SRC")
            ;;
    esac
    mark=$(stat -c %s "$LOG" 2>/dev/null || echo 0)
    echo "--- $(date '+%F %T') · $1 · $(basename "$REC") ${args[*]} -f $OUT" >>"$LOG"
    "$REC" "${args[@]}" -f "$OUT" >>"$LOG" 2>&1 &
    pid=$!
    # from now on a second press stops this recorder
    echo "$pid" > "$PIDFILE"
    echo "$OUT" > "$OUTFILE"
}

# The GPU path is only good when it gets the compositor's frames directly
# (DMA-BUF); without them it is slow and unreliable — then the CPU it is.
gpu_ok() {
    local i
    for i in $(seq 1 20); do
        kill -0 "$pid" 2>/dev/null || return 1
        if tail -c +"$((mark + 1))" "$LOG" 2>/dev/null | grep -q "disabling DMA-BUF"; then
            return 1
        fi
        if tail -c +"$((mark + 1))" "$LOG" 2>/dev/null | grep -q "enabled DMA-BUF capture"; then
            sleep 0.4
            kill -0 "$pid" 2>/dev/null
            return $?
        fi
        sleep 0.1
    done
    return 1
}

if [ "$(basename "$REC")" = wf-recorder ] && [ -z "${VELVET_RECORD_CPU:-}" ]; then
    start gpu
    if ! gpu_ok; then
        # stopped by a second press meanwhile: nothing more to start
        [ "$(cat "$PIDFILE" 2>/dev/null)" = "$pid" ] || exit 0
        kill -INT "$pid" 2>/dev/null
        for _ in $(seq 1 20); do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
        rm -f "$OUT"
        echo "--- the GPU could not take the frames directly — recording on the CPU" >>"$LOG"
        start cpu
    fi
else
    start cpu
fi

# A recorder that dies in its first second (no output, no audio device …)
# must say so, not pretend to record.
sleep 1
if ! kill -0 "$pid" 2>/dev/null; then
    rm -f "$PIDFILE" "$OUTFILE"
    say "COULDN'T START THE RECORDER · SEE $LOG" "critical"
    exit 1
fi
shell_says started >/dev/null
