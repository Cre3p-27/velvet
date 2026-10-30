#!/usr/bin/env python3
"""
tools/clean_sfx.py — the shell's sounds, from Kenney's "Interface Sounds"
(CC0, kenney.nl · opengameart.org/content/interface-sounds).

One quiet set for everything: each sound is the warmest, shortest one of its
kind in the pack, filtered (no rumble, no sharp top), brought to a soft level
and faded out so nothing clicks at its end. The sounds you hear most (the
cursor, the fidget tick) are the quietest.

    python3 tools/clean_sfx.py <the unpacked pack's Audio folder>

writes assets/sfx/*.wav.
"""

import os
import subprocess
import sys

import numpy as np

# name in the shell: (file in the pack, loudness of its body in dBFS RMS)
PICK = {
    "cursor": ("click_002", -31),       # moving through a menu: a soft tap
    "tick": ("click_003", -31),         # slider notches, presses (FIDGET FEEL)
    "select": ("select_005", -25),
    "back": ("back_002", -26),
    "toggle": ("switch_005", -25),
    "snap": ("glass_002", -27),
    "pop": ("drop_002", -25),
    "boing": ("drop_003", -26),
    "open": ("maximize_009", -27),
    "close": ("minimize_009", -27),
    "whoosh": ("maximize_008", -29),
    "launch": ("confirmation_001", -26),
    "quest": ("confirmation_004", -25),
    "charge": ("question_001", -28),    # the long press that wakes Velly
    "nope": ("error_005", -26),
}
RATE = 48000
PEAK = 10 ** (-8 / 20)   # never above -8 dBFS


def load(path):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-ac", "1", "-ar", str(RATE),
                          "-af", "highpass=f=110,lowpass=f=7500", "-f", "f32le", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).copy()


def shape(x, rms_db):
    env = np.abs(x)
    on = np.where(env > env.max() * 0.04)[0]
    x = x[max(0, on[0] - 24): on[-1] + 1]
    body = x[: max(1, int(len(x)))]
    rms = np.sqrt(np.mean(body ** 2)) + 1e-9
    x = x * (10 ** (rms_db / 20) / rms)
    peak = np.abs(x).max()
    if peak > PEAK:
        x = x * (PEAK / peak)
    fade = min(len(x) // 3, int(RATE * 0.012))
    if fade > 0:
        x[-fade:] *= np.linspace(1, 0, fade) ** 2
    return np.concatenate([x, np.zeros(int(RATE * 0.02), dtype=np.float32)])


def save(x, path):
    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2").tobytes()
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "s16le", "-ar", str(RATE), "-ac", "1", "-i", "-", path],
                   input=pcm, check=True)


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    src = sys.argv[1]
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sfx")
    for name, (file, level) in PICK.items():
        save(shape(load(os.path.join(src, file + ".ogg")), level), os.path.join(out, name + ".wav"))
        print(f"{name:7s} ← {file}")


if __name__ == "__main__":
    main()
