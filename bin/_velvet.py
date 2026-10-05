"""
VELVET · bin/_velvet.py

The shared floor under Velvet's little desktop programs: the palette, the
terminal, the frame loop. Standard library only, on purpose — these have to
start on login on a machine where nothing was pip-installed.

A program here is a function draw(scr, t) -> list[str]. It gets the screen and
the time in seconds since it started, and returns one already-coloured string
per row. Everything else — the alternate screen, the cursor, resizing, raw
keys, putting the terminal back the way it was even when something throws — is
handled once, here.
"""

import atexit
import json
import math
import os
import select
import shutil
import signal
import sys
import termios
import time
import tty

PALETTE_PATH = os.path.join(
    os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")),
    "velvet", "palette.json",
)

# What the shell looks like before it has ever written a palette out.
FALLBACK = {
    "accent": "#e4002b",
    "accentAlt": "#00b3a4",
    "ink": "#f7f5f6",
    "inkDim": "#a8a2a5",
    "surface": "#181315",
    "paper": "#0b0809",
}


# ───────────────────────────────────────────────────────────────────── colour
def hex_rgb(text, fallback=(255, 255, 255)):
    try:
        s = str(text).strip().lstrip("#")
        if len(s) == 8:          # Qt writes #AARRGGBB; the alpha is not ours
            s = s[2:]
        if len(s) == 3:
            s = "".join(c * 2 for c in s)
        if len(s) != 6:
            return fallback
        return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16))
    except (ValueError, TypeError):
        return fallback


def mix(a, b, t):
    t = 0.0 if t < 0 else (1.0 if t > 1 else t)
    return (
        int(a[0] + (b[0] - a[0]) * t),
        int(a[1] + (b[1] - a[1]) * t),
        int(a[2] + (b[2] - a[2]) * t),
    )


def shade(c, k):
    """Scale a colour towards black (k<1) or white (k>1)."""
    if k <= 1:
        return mix((0, 0, 0), c, k)
    return mix(c, (255, 255, 255), min(1.0, k - 1.0))


def fg(c):
    return "\x1b[38;2;%d;%d;%dm" % c


def bg(c):
    return "\x1b[48;2;%d;%d;%dm" % c


RESET = "\x1b[0m"
DIM = "\x1b[2m"
BOLD = "\x1b[1m"


# ──────────────────────────────────────────────────────────────── options
#  Where a program's switches come from: the command line — or, while the
#  DESKTOP designer is changing them, a LIVE file. The designer starts every
#  module with `--live <file>` and rewrites that file on every pick; the
#  frame loop notices within a quarter second and the next frame is drawn
#  with the new switches. No restart, no window blinking out and back.
import shlex  # noqa: E402

_TOKENS = sys.argv[1:]


def _argv_value(name):
    args = sys.argv[1:]
    for i, arg in enumerate(args):
        if arg.startswith("--%s=" % name):
            return arg.split("=", 1)[1]
        if arg == "--" + name and i + 1 < len(args):
            return args[i + 1]
    return None


LIVE_PATH = _argv_value("live")
_live_stamp = None


def refresh_live():
    """Re-read the live file if it changed. True when the switches moved."""
    global _TOKENS, _live_stamp
    if not LIVE_PATH:
        return False
    try:
        stamp = os.path.getmtime(LIVE_PATH)
    except OSError:
        return False
    if stamp == _live_stamp:
        return False
    _live_stamp = stamp
    try:
        with open(LIVE_PATH, "r", encoding="utf-8") as fh:
            text = fh.read()
        _TOKENS = shlex.split(text)
    except (OSError, ValueError):
        return False
    return True


def opt(name, default=None):
    """`--name value`, `--name=value`, or a bare `--name` (→ True).

    Every program here shares one small vocabulary of switches (see run()),
    and each can add its own; the DESKTOP designer writes them. Anything
    malformed falls back to the default — a module that refuses to start
    because of a typo in its settings is worse than one that ignores it.
    """
    args = _TOKENS
    flag = "--" + name
    for i, arg in enumerate(args):
        if arg.startswith(flag + "="):
            return arg.split("=", 1)[1]
        if arg == flag:
            nxt = args[i + 1] if i + 1 < len(args) else None
            if nxt is None or nxt.startswith("--"):
                return True
            return nxt
    return default


# The command line is the truth at start; the live file only carries what
# changes AFTER that. Reading an old file here would start a module with the
# settings of some earlier session.
if LIVE_PATH:
    try:
        _live_stamp = os.path.getmtime(LIVE_PATH)
    except OSError:
        _live_stamp = None


def opt_float(name, default, low=None, high=None):
    try:
        v = float(opt(name, default))
    except (TypeError, ValueError):
        v = float(default)
    if low is not None:
        v = max(low, v)
    if high is not None:
        v = min(high, v)
    return v


def opt_on(name):
    v = opt(name, False)
    return v is True or str(v).lower() in ("1", "on", "yes", "true")


class Palette:
    """The shell's own colours, re-read now and then so a wallpaper change
    reaches the desktop programs without restarting them. A `--tint` on the
    command line recolours the whole program with one of the palette's own
    colours instead of the accent — the override survives every reload."""

    TINT_MAP = {
        "accent": "accent",
        "alt": "accentAlt",
        "ink": "ink",
        "paper": "paper",
    }

    def __init__(self):
        self.raw = dict(FALLBACK)
        self.tint = self._tint_arg()
        self._checked = 0.0
        self._stamp = None
        self.reload(force=True)

    @staticmethod
    def _tint_arg():
        """`--tint ink` / `--tint=ink` / `--tint auto`, from the command line
        or the live file. Unknown names fall back to auto — the program just
        draws normally rather than refusing to start."""
        v = opt("tint", "auto")
        return v if isinstance(v, str) else "auto"

    def retint(self):
        """The switches changed: pick the tint up again and recolour."""
        self.tint = self._tint_arg()
        self.reload(force=True)

    def _apply_tint(self):
        tint = str(self.tint or "auto")
        # Any colour at all, not just the palette's own: --tint ff7a00 (the
        # designer drops the "#", which a shell would read as a comment).
        if len(tint) == 6 and all(ch in "0123456789abcdefABCDEF" for ch in tint):
            tint = "#" + tint
        if tint.startswith("#") and hex_rgb(tint, None) is not None:
            self.raw["accent"] = tint
            self.raw["accentAlt"] = tint
            return
        src = self.TINT_MAP.get(tint)
        if src and src in self.raw:
            self.raw["accent"] = self.raw[src]
            self.raw["accentAlt"] = self.raw[src]

    def reload(self, force=False):
        now = time.monotonic()
        if not force and now - self._checked < 3.0:
            return
        self._checked = now
        try:
            stamp = os.path.getmtime(PALETTE_PATH)
        except OSError:
            stamp = None
        if stamp == self._stamp and not force:
            return
        self._stamp = stamp
        merged = dict(FALLBACK)
        try:
            with open(PALETTE_PATH, "r", encoding="utf-8") as fh:
                data = json.load(fh)
            if isinstance(data, dict):
                merged.update({k: v for k, v in data.items() if isinstance(v, str)})
        except (OSError, ValueError):
            pass
        # Always from the untinted palette: a second tint applied on top of
        # the first used to stick (ACCENT → INK stayed INK-on-ACCENT).
        self.raw = merged
        self._apply_tint()

    def __getattr__(self, name):
        # Only reached for names that are not real attributes.
        raw = self.__dict__.get("raw") or FALLBACK
        if name in raw:
            return hex_rgb(raw[name])
        raise AttributeError(name)


# ───────────────────────────────────────────────────────────────────── screen
class Screen:
    def __init__(self):
        self.cols = 80
        self.rows = 24
        self.palette = Palette()
        self._tty = sys.stdin.isatty() and sys.stdout.isatty()
        self._saved = None
        self._entered = False
        self._last = []
        self.measure()

    # ── lifecycle
    def enter(self):
        if not self._tty:
            return
        try:
            self._saved = termios.tcgetattr(sys.stdin.fileno())
        except (termios.error, ValueError):
            self._saved = None
        try:
            tty.setcbreak(sys.stdin.fileno())
        except (termios.error, ValueError):
            # Keep whatever we captured: throwing it away here is how a
            # half-applied mode ends up with nothing to restore from.
            pass
        sys.stdout.write("\x1b[?1049h\x1b[?25l")
        sys.stdout.flush()
        self._entered = True
        atexit.register(self.leave)
        try:
            signal.signal(signal.SIGWINCH, lambda *_: self.measure())
        except (ValueError, AttributeError, OSError):
            pass

    def leave(self):
        if not self._entered:
            return
        self._entered = False
        sys.stdout.write(RESET + "\x1b[?25h\x1b[?1049l")
        sys.stdout.flush()
        if self._saved is not None:
            try:
                termios.tcsetattr(sys.stdin.fileno(), termios.TCSADRAIN, self._saved)
            except (termios.error, ValueError):
                pass

    def measure(self):
        size = shutil.get_terminal_size(fallback=(80, 24))
        self.cols = max(8, size.columns)
        self.rows = max(4, size.lines)
        self._last = []

    # ── painting
    def paint(self, lines):
        """Redraw by walking home and overwriting, never by clearing: a clear
        followed by a draw is one frame of empty screen, and at 30fps that
        reads as flicker."""
        out = ["\x1b[H"]
        for i in range(self.rows):
            line = lines[i] if i < len(lines) else ""
            out.append(line)
            out.append("\x1b[K")
            if i < self.rows - 1:
                out.append("\r\n")
        out.append("\x1b[J" + RESET)
        sys.stdout.write("".join(out))
        sys.stdout.flush()

    # ── input
    def key(self):
        if not self._tty:
            return ""
        try:
            ready, _, _ = select.select([sys.stdin], [], [], 0)
        except (OSError, ValueError):
            return ""
        if not ready:
            return ""
        try:
            return sys.stdin.read(1)
        except (OSError, ValueError):
            return ""


# ───────────────────────────────────────────────────────────── helpers to draw
def clip(text, width):
    """Trim to a printable width, counting characters and ignoring the escape
    sequences that have no width at all."""
    if width <= 0:
        return ""
    out = []
    used = 0
    i = 0
    n = len(text)
    while i < n:
        ch = text[i]
        if ch == "\x1b":
            j = text.find("m", i)
            if j == -1:
                break
            out.append(text[i:j + 1])
            i = j + 1
            continue
        if used >= width:
            break
        out.append(ch)
        used += 1
        i += 1
    return "".join(out)


def centre(text, width, printable=None):
    n = printable if printable is not None else len(text)
    if n >= width:
        return text
    pad = (width - n) // 2
    return " " * pad + text

# Eight steps of a vertical block, so a bar can be a fraction of a cell tall.
BLOCKS = " ▁▂▃▄▅▆▇█"
# …and the same idea sideways.
HBLOCKS = " ▏▎▍▌▋▊▉█"


def vbar(fraction):
    f = 0.0 if fraction < 0 else (1.0 if fraction > 1 else fraction)
    return BLOCKS[int(round(f * 8))]


def hbar(width, fraction):
    f = 0.0 if fraction < 0 else (1.0 if fraction > 1 else fraction)
    total = f * width
    full = int(total)
    rest = total - full
    out = "█" * full
    if full < width:
        out += HBLOCKS[int(round(rest * 8))]
    return out.ljust(width)[:width]


def timeline(data, rows, width, top, low, high, flip=False, indent="  "):
    """A time series as a block graph.

    Padded on the LEFT so the newest sample is always at the right edge: a
    graph that fills in from the left tells you where the program started,
    which is not what anybody is looking at it for.

    flip=True hangs the graph from the top instead, for the mirrored half of
    an up/down pair.
    """
    values = list(data[-width:]) if width > 0 else []
    pad = max(0, width - len(values))
    order = list(range(rows))
    if flip:
        order.reverse()

    out = []
    for row in order:
        hi = 1.0 - row / rows
        lo = 1.0 - (row + 1) / rows
        line = [indent, " " * pad]
        last = None
        for v in values:
            f = (v / top) if top > 0 else 0.0
            f = 0.0 if f < 0 else (1.0 if f > 1 else f)
            if f >= hi:
                ch = "█"
            elif f <= lo:
                ch = " "
            else:
                ch = vbar((f - lo) / max(0.0001, hi - lo))
            c = mix(low, high, 1.0 - row / max(1, rows))
            if c != last:
                line.append(fg(c))
                last = c
            line.append(ch)
        out.append("".join(line) + RESET)
    return out


def ease(t):
    """Smoothstep, for anything that should arrive rather than stop."""
    t = 0.0 if t < 0 else (1.0 if t > 1 else t)
    return t * t * (3 - 2 * t)


def wave(t, speed=1.0, phase=0.0):
    return 0.5 + 0.5 * math.sin(t * speed + phase)


# ──────────────────────────────────────────────────────── shaping a frame
#  The shared switches every Velvet module understands, applied to the
#  finished frame so no module has to know about them:
#    --flip            upside down: rows reversed, block glyphs hung from the top
#    --mirror          graphs run right-to-left (lines with text stay readable)
#    --align top|middle|bottom   where the content sits in a taller window
#    --frame           a rounded hairline around everything
#    --speed K         animation time × K (0.25–4)
#    --fps N           frames per second (4–60)
#    --tint NAME|#hex  recolour with a palette colour or any colour
FLIP_GLYPHS = {
    "▁": "▔", "▂": "▔", "▃": "▀", "▄": "▀", "▅": "▀", "▆": "█", "▇": "█",
    "▔": "▁", "▀": "▄",
}


def _cells(line):
    """Split a coloured line into [(escape-prefix, char)] cells."""
    cells = []
    pending = ""
    i = 0
    n = len(line)
    while i < n:
        ch = line[i]
        if ch == "\x1b":
            j = line.find("m", i)
            if j == -1:
                break
            pending += line[i:j + 1]
            i = j + 1
            continue
        cells.append((pending, ch))
        pending = ""
        i += 1
    return cells, pending


def _join(cells, tail=""):
    return "".join(p + c for p, c in cells) + tail


def _colour_state(cells):
    """The escape that is in force before each cell, so a cell can be moved
    and keep its colour."""
    out = []
    state = ""
    for prefix, ch in cells:
        if prefix:
            # A reset wipes what came before; anything else stacks on it.
            state = prefix if RESET in prefix else state + prefix
        out.append((state, ch))
    return out


def has_text(line):
    for _, ch in _cells(line)[0]:
        if ch.isalnum():
            return True
    return False


def blank(line):
    return all(ch == " " for _, ch in _cells(line)[0])


def shape_frame(lines, cols, rows, flip=False, mirror=False, align=""):
    lines = list(lines[:rows]) + [""] * max(0, rows - len(lines))

    if align in ("top", "middle", "bottom"):
        body = list(lines)
        while body and blank(body[0]):
            body.pop(0)
        while body and blank(body[-1]):
            body.pop()
        spare = max(0, rows - len(body))
        before = 0 if align == "top" else (spare if align == "bottom" else spare // 2)
        lines = [""] * before + body + [""] * (rows - before - len(body))

    if mirror:
        out = []
        for line in lines:
            if not line or has_text(line):
                out.append(line)
                continue
            cells = _colour_state(_cells(line)[0])
            cells = cells + [("", " ")] * max(0, cols - len(cells))
            cells.reverse()
            out.append("".join(RESET + st + ch for st, ch in cells) + RESET)
        lines = out

    if flip:
        out = []
        for line in reversed(lines):
            if has_text(line):
                out.append(line)
                continue
            cells, tail = _cells(line)
            out.append(_join([(p, FLIP_GLYPHS.get(c, c)) for p, c in cells], tail))
        lines = out

    return lines


def frame_box(lines, cols, rows, colour):
    """Wrap an already (cols-2)×(rows-2) frame in a rounded hairline."""
    c = fg(colour)
    inner = max(0, cols - 2)
    out = [c + "╭" + "─" * inner + "╮" + RESET]
    for i in range(max(0, rows - 2)):
        body = clip(lines[i] if i < len(lines) else "", inner)
        width = len(_cells(body)[0])
        out.append(c + "│" + RESET + body + RESET + " " * max(0, inner - width) + c + "│" + RESET)
    out.append(c + "╰" + "─" * inner + "╯" + RESET)
    return out


def shared_options():
    return {
        "flip": opt_on("flip"),
        "mirror": opt_on("mirror"),
        "align": str(opt("align", "") or ""),
        "frame": opt_on("frame"),
        "speed": opt_float("speed", 1.0, 0.25, 4.0),
        "fps": opt_float("fps", 0, 0, 60),
    }


def render(draw, scr, t, o):
    """One frame with the shared switches applied."""
    framed = o["frame"] and scr.cols > 6 and scr.rows > 4
    if framed:
        cols, rows = scr.cols, scr.rows
        scr.cols, scr.rows = cols - 2, rows - 2
        try:
            lines = draw(scr, t * o["speed"])
            lines = [clip(l, scr.cols) for l in lines]
            lines = shape_frame(lines, scr.cols, scr.rows, o["flip"], o["mirror"], o["align"])
        finally:
            scr.cols, scr.rows = cols, rows
        return frame_box(lines, scr.cols, scr.rows, mix(scr.palette.inkDim, scr.palette.accent, 0.35))
    lines = draw(scr, t * o["speed"])
    lines = [clip(l, scr.cols) for l in lines]
    return shape_frame(lines, scr.cols, scr.rows, o["flip"], o["mirror"], o["align"])


# ─────────────────────────────────────────────────────────────── the frame loop
def run(draw, fps=30, title=None):
    """Run a program until q, Escape or Ctrl-C.

    Anything that throws is caught and printed on a still screen rather than
    closing the window instantly — a desktop program that vanishes tells you
    nothing at all.
    """
    if "--selftest" in sys.argv:
        return selftest(draw)

    base_fps = fps
    o = shared_options()
    if o["fps"] >= 4:
        fps = o["fps"]

    scr = Screen()
    scr.enter()
    if title:
        sys.stdout.write("\x1b]0;%s\x07" % title)
    start = time.monotonic()
    frame = 1.0 / max(1, fps)

    live_check = 0.0
    try:
        while True:
            began = time.monotonic()
            scr.palette.reload()
            if began - live_check > 0.25:
                live_check = began
                if refresh_live():
                    o = shared_options()
                    frame = 1.0 / max(1, o["fps"] if o["fps"] >= 4 else base_fps)
                    scr.palette.retint()
                    scr.measure()      # forget the last frame: redraw everything
            try:
                lines = render(draw, scr, began - start, o)
            except Exception as exc:                     # noqa: BLE001
                return fail(scr, exc)
            scr.paint([clip(l, scr.cols) for l in lines])

            k = scr.key()
            if k in ("q", "Q", "\x1b", "\x03"):
                break

            rest = frame - (time.monotonic() - began)
            if rest > 0:
                time.sleep(rest)
    except KeyboardInterrupt:
        pass
    finally:
        scr.leave()
    return 0


def fail(scr, exc):
    """Stop on a still screen that says what happened.

    A desktop program lives in its own terminal window, and a window that
    closes the instant something goes wrong tells you nothing at all. So the
    alternate screen is handed back, the error is printed where a scrollback
    will keep it, and it waits for a key.
    """
    scr.leave()
    import traceback
    sys.stdout.write("\n  velvet: %s\n" % exc)
    trace = traceback.format_exc()
    if trace and not trace.startswith("NoneType"):
        sys.stdout.write("\n" + trace)
    sys.stdout.write("\n  press any key to close\n")
    sys.stdout.flush()
    try:
        sys.stdin.read(1)
    except (OSError, ValueError, KeyboardInterrupt):
        pass
    return 1


def selftest(draw, frames=12):
    """Render a handful of frames without a terminal and make sure nothing
    throws and nothing overflows. Used by the project's own checks."""
    scr = Screen()
    scr.cols, scr.rows = 100, 30
    worst = 0
    o = shared_options()
    for i in range(frames):
        lines = render(draw, scr, i * 0.12, o)
        if len(lines) > scr.rows:
            raise SystemExit("frame has %d rows for a %d-row screen" % (len(lines), scr.rows))
        if not isinstance(lines, list):
            raise SystemExit("draw() must return a list of strings")
        for line in lines:
            if not isinstance(line, str):
                raise SystemExit("draw() returned a %s" % type(line).__name__)
            worst = max(worst, len(clip(line, scr.cols)))
    sys.stdout.write("ok  %d frames  %dx%d\n" % (frames, scr.cols, scr.rows))
    return 0
