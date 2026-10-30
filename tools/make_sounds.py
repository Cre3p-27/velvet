#!/usr/bin/env python3
"""
tools/make_sounds.py — the shell's sounds, made here (nothing downloaded).

Two sets you choose between in SHELL → SOUND → SOUNDS, both in one key (E major),
so every sound that follows another sounds like it belongs with it:

  soft   little wooden taps: a short knock with a warm body, like pressing a
         good key — felt more than heard
  glass  small crystal bells: sine partials with a long, quiet ring

and Velly's own voice-less chirps (assets/sfx/velly): waking, listening, done,
an error, a giggle when you click her, a purr when you pet her.

Every sound has a soft start (no click), a smooth end, no rumble, nothing sharp
on top, and a quiet level; the ones you hear most are the quietest.

    python3 tools/make_sounds.py          writes assets/sfx/{soft,glass,velly}/*.wav
"""

import os
import subprocess

import numpy as np

SR = 48000
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sfx")

# E major: the notes the sounds are built from
E4, B3 = 329.63, 246.94
E5, Gs5, B5, E6, Gs6, B6 = 659.26, 830.61, 987.77, 1318.51, 1661.22, 1975.53


def t_of(dur):
    return np.arange(int(SR * dur)) / SR


def soften(x, attack=0.003, release=0.015):
    a, r = int(SR * attack), int(SR * release)
    if a > 0:
        x[:a] *= np.sin(np.linspace(0, np.pi / 2, a)) ** 2
    if r > 0 and r < len(x):
        x[-r:] *= np.cos(np.linspace(0, np.pi / 2, r)) ** 2
    return x


def lowpass(x, cut, order=2):
    """A gentle low-pass in the frequency domain (no ringing edge)."""
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    spec *= 1 / np.sqrt(1 + (f / cut) ** (2 * order))
    return np.fft.irfft(spec, len(x))


def highpass(x, cut):
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    spec *= 1 / np.sqrt(1 + (cut / np.maximum(f, 1)) ** 4)
    return np.fft.irfft(spec, len(x))


def wood(f, dur=0.12, body=0.05, bright=0.35):
    """A wooden tap: the modes of a small bar (1, 2.76, 5.40), the higher ones
    dying fast, and a breath of noise at the strike."""
    t = t_of(dur)
    x = np.sin(2 * np.pi * f * t) * np.exp(-t / body)
    x += bright * np.sin(2 * np.pi * f * 2.76 * t) * np.exp(-t / (body * 0.35))
    x += bright * 0.4 * np.sin(2 * np.pi * f * 5.40 * t) * np.exp(-t / (body * 0.15))
    n = np.random.default_rng(int(f)).standard_normal(len(t)) * np.exp(-t / 0.0012) * 0.25
    x += lowpass(n, 3500)
    return soften(x, 0.0015, 0.01)


def bell(f, dur=0.5, ring=0.18):
    """A small crystal bell: a pure tone, its octave, and a faint inharmonic shimmer."""
    t = t_of(dur)
    x = np.sin(2 * np.pi * f * t) * np.exp(-t / ring)
    x += 0.32 * np.sin(2 * np.pi * f * 2.0 * t) * np.exp(-t / (ring * 0.55))
    x += 0.08 * np.sin(2 * np.pi * f * 3.01 * t) * np.exp(-t / (ring * 0.3))
    return soften(x, 0.004, 0.03)


def glide(f0, f1, dur, vib=0.0, rate=16.0, shape=0.06):
    """A sung chirp: the pitch slides from f0 to f1 (with a little vibrato)."""
    t = t_of(dur)
    k = np.clip(t / dur, 0, 1)
    k = k * k * (3 - 2 * k)
    f = f0 + (f1 - f0) * k
    f = f * (1 + vib * np.sin(2 * np.pi * rate * t))
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = np.sin(ph) + 0.18 * np.sin(2 * ph) + 0.05 * np.sin(3 * ph)
    env = np.minimum(1, t / shape) * np.exp(-np.maximum(0, t - shape) / max(0.02, dur * 0.6))
    return soften(x * env, 0.006, 0.02)


def seq(parts):
    """Sounds one after the other: [(sound, start in seconds), …]."""
    end = max(int(SR * s) + len(x) for x, s in parts)
    out = np.zeros(end)
    for x, s in parts:
        i = int(SR * s)
        out[i:i + len(x)] += x
    return out


def noise_swell(dur=0.16, lo=300, hi=1600):
    t = t_of(dur)
    n = np.random.default_rng(7).standard_normal(len(t))
    n = lowpass(highpass(n, lo), hi, 2)
    env = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 2
    return soften(n * env, 0.01, 0.03)


def pop(f0=480, f1=1050, dur=0.07):
    t = t_of(dur)
    f = f0 + (f1 - f0) * (1 - np.exp(-t / 0.008))
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.022)
    return soften(x, 0.001, 0.01)


def purr(dur=0.55):
    t = t_of(dur)
    am = 0.55 + 0.45 * np.sin(2 * np.pi * 26 * t)
    x = (np.sin(2 * np.pi * 150 * t) + 0.5 * np.sin(2 * np.pi * 300 * t) + 0.2 * np.sin(2 * np.pi * 450 * t)) * am
    env = np.minimum(1, t / 0.08) * np.minimum(1, (dur - t) / 0.18)
    return soften(lowpass(x * env, 1200), 0.02, 0.05)


def level(x, rms_db, peak_db=-9):
    x = highpass(x, 120)
    x = lowpass(x, 6500, 1)
    on = np.abs(x) > np.abs(x).max() * 0.05
    body = x[on] if on.any() else x
    x = x * (10 ** (rms_db / 20) / (np.sqrt(np.mean(body ** 2)) + 1e-9))
    peak = np.abs(x).max()
    if peak > 10 ** (peak_db / 20):
        x = x * (10 ** (peak_db / 20) / peak)
    return np.concatenate([x, np.zeros(int(SR * 0.015))])


def save(x, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2").tobytes()
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "s16le", "-ar", str(SR), "-ac", "1", "-i", "-", path],
                   input=pcm, check=True)


SOFT = {
    "cursor": (wood(E6, 0.05, 0.012, 0.2), -36),
    "tick": (wood(B6, 0.03, 0.006, 0.2), -36),
    "select": (wood(B5, 0.14, 0.05), -27),
    "back": (wood(Gs5, 0.13, 0.045), -28),
    "toggle": (seq([(wood(B5, 0.1, 0.035), 0), (wood(E6, 0.12, 0.04), 0.045)]), -27),
    "open": (seq([(wood(E5, 0.14, 0.06), 0), (wood(B5, 0.18, 0.08), 0.05)]), -28),
    "close": (seq([(wood(B5, 0.12, 0.05), 0), (wood(E5, 0.16, 0.07), 0.05)]), -29),
    "launch": (seq([(wood(E5, 0.2, 0.08), 0), (wood(Gs5, 0.2, 0.08), 0.04), (wood(B5, 0.24, 0.1), 0.08)]), -27),
    "quest": (seq([(wood(f, 0.3, 0.12), i * 0.065) for i, f in enumerate([E5, Gs5, B5, E6])]), -26),
    "whoosh": (noise_swell(), -34),
    "charge": (glide(E4, E5, 0.62, 0.012, 7, 0.3), -32),
    "nope": (seq([(lowpass(wood(E4, 0.12, 0.04), 1500), 0), (lowpass(wood(B3, 0.14, 0.05), 1300), 0.09)]), -28),
    "pop": (pop(), -28),
    "boing": (glide(420, 260, 0.16, 0.03, 18, 0.01), -30),
    "snap": (seq([(wood(E6, 0.04, 0.008, 0.2), 0), (wood(B6, 0.04, 0.007, 0.2), 0.03)]), -31),
}

GLASS = {
    "cursor": (bell(E6, 0.12, 0.03), -38),
    "tick": (bell(B6, 0.08, 0.015), -38),
    "select": (bell(B5, 0.4, 0.11), -29),
    "back": (bell(Gs5, 0.35, 0.1), -30),
    "toggle": (seq([(bell(B5, 0.3, 0.07), 0), (bell(E6, 0.4, 0.1), 0.05)]), -29),
    "open": (seq([(bell(E5, 0.45, 0.13), 0), (bell(B5, 0.55, 0.16), 0.06)]), -30),
    "close": (seq([(bell(B5, 0.4, 0.11), 0), (bell(E5, 0.5, 0.14), 0.06)]), -31),
    "launch": (seq([(bell(f, 0.6, 0.16), i * 0.05) for i, f in enumerate([E5, Gs5, B5])]), -29),
    "quest": (seq([(bell(f, 0.9, 0.25), i * 0.075) for i, f in enumerate([E5, Gs5, B5, E6])]), -28),
    "whoosh": (noise_swell(0.2, 600, 2400), -36),
    "charge": (glide(E5, E6, 0.62, 0.008, 6, 0.3), -33),
    "nope": (seq([(bell(E4, 0.3, 0.07), 0), (bell(B3, 0.35, 0.08), 0.1)]), -29),
    "pop": (pop(600, 1300, 0.08), -29),
    "boing": (glide(520, 330, 0.18, 0.03, 18, 0.01), -31),
    "snap": (seq([(bell(E6, 0.1, 0.02), 0), (bell(B6, 0.12, 0.025), 0.03)]), -32),
}

VELLY = {
    "wake": (seq([(glide(520, 1040, 0.16, 0.02, 18, 0.04), 0), (glide(1040, 880, 0.14, 0.015, 18, 0.02), 0.13)]), -25),
    "listen": (glide(700, 990, 0.08, 0.0, 16, 0.02), -28),
    "heard": (glide(990, 700, 0.08, 0.0, 16, 0.02), -29),
    "done": (seq([(glide(784, 830, 0.09, 0.01, 20, 0.02), 0), (glide(1175, 1320, 0.14, 0.015, 20, 0.02), 0.085)]), -26),
    "error": (glide(620, 380, 0.26, 0.03, 9, 0.03), -28),
    "giggle": (seq([(glide(f, f * 1.22, 0.05, 0.02, 30, 0.01), i * 0.07) for i, f in enumerate([1300, 1200, 1100])]), -27),
    "purr": (purr(), -31),
}


def main():
    for name, sounds in (("soft", SOFT), ("glass", GLASS), ("velly", VELLY)):
        for key, (x, db) in sounds.items():
            save(level(np.asarray(x, dtype=np.float64), db), os.path.join(OUT, name, key + ".wav"))
        print(f"{name}: {len(sounds)} sounds")


if __name__ == "__main__":
    main()
