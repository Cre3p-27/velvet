#!/usr/bin/env python3
"""
tools/make_sounds.py — the shell's sounds, made here (nothing downloaded).

Every sound is a few notes in one key (E major), so one sound after another always
fits. What plays those notes is the TIMBRE:

  soft     little wooden taps, felt more than heard
  glass    small crystal bells with a quiet ring
  pop      round bubbles that pop
  pluck    a plucked string, like a kalimba
  keys     the thock of a good mechanical keyboard
  digital  clean little synth blips

and three dials shape any of them: PITCH (semitones, -12 … 12), BRIGHTNESS
(0 warm … 1 bright) and LENGTH (0.5 short … 2 long). Velly's chirps
(assets/sfx/velly) are her own and stay as they are.

    python3 tools/make_sounds.py                        every timbre at its default → assets/sfx/<timbre>/
    python3 tools/make_sounds.py --timbre pluck --pitch -3 --bright 0.4 --length 1.3 --out DIR
                                                        one set with the dials → DIR (SHELL → SOUND does this)
"""

import argparse
import os
import wave

import numpy as np

SR = 48000
HERE = os.path.dirname(os.path.abspath(__file__))
SFX = os.path.join(HERE, "..", "assets", "sfx")

E4, B3 = 329.63, 246.94
E5, Gs5, B5, E6, Gs6, B6 = 659.26, 830.61, 987.77, 1318.51, 1661.22, 1975.53

TIMBRES = ["soft", "glass", "pop", "pluck", "keys", "digital"]


def t_of(dur):
    return np.arange(max(1, int(SR * dur))) / SR


def soften(x, attack=0.002, release=0.012):
    a, r = int(SR * attack), int(SR * release)
    if 0 < a < len(x):
        x[:a] *= np.sin(np.linspace(0, np.pi / 2, a)) ** 2
    if 0 < r < len(x):
        x[-r:] *= np.cos(np.linspace(0, np.pi / 2, r)) ** 2
    return x


def lowpass(x, cut, order=2):
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    spec *= 1 / np.sqrt(1 + (f / max(200.0, cut)) ** (2 * order))
    return np.fft.irfft(spec, len(x))


def highpass(x, cut):
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    spec *= 1 / np.sqrt(1 + (cut / np.maximum(f, 1)) ** 4)
    return np.fft.irfft(spec, len(x))


class Voice:
    """Plays one note of a timbre: note(f, weight) where weight 0 … 1 is how
    big the note is (a tiny tick … a full chime)."""

    def __init__(self, timbre, bright, length):
        self.timbre, self.bright, self.length = timbre, bright, length

    def note(self, f, weight=1.0):
        L, b = self.length, self.bright
        rng = np.random.default_rng(int(f * 10) % 9973)
        if self.timbre == "glass":
            dur = (0.12 + 0.6 * weight) * L
            t = t_of(dur)
            ring = (0.03 + 0.18 * weight) * L
            x = np.sin(2 * np.pi * f * t) * np.exp(-t / ring)
            x += (0.15 + 0.35 * b) * np.sin(2 * np.pi * f * 2 * t) * np.exp(-t / (ring * 0.55))
            x += 0.1 * b * np.sin(2 * np.pi * f * 3.01 * t) * np.exp(-t / (ring * 0.3))
            return soften(x, 0.004, 0.03)
        if self.timbre == "pop":
            dur = (0.05 + 0.08 * weight) * L
            t = t_of(dur)
            ff = f * 0.55 + f * 0.6 * (1 - np.exp(-t / 0.008))
            x = np.sin(2 * np.pi * np.cumsum(ff) / SR) * np.exp(-t / ((0.012 + 0.02 * weight) * L))
            return soften(x, 0.001, 0.008)
        if self.timbre == "pluck":
            # Karplus-Strong: a burst of noise in a delay line that loses its top each pass
            dur = (0.15 + 0.5 * weight) * L
            n = len(t_of(dur))
            period = max(2, int(SR / f))
            buf = rng.uniform(-1, 1, period)
            # a softer pluck: the burst itself already without its top
            for _ in range(2 + int(3 * (1 - b))):
                buf = 0.5 * (buf + np.roll(buf, 1))
            out = np.zeros(n)
            damp = 0.4 + 0.1 * b
            decay = 0.996 - 0.006 / max(0.3, L)
            for i in range(n):
                j = i % period
                out[i] = buf[j]
                buf[j] = decay * (damp * buf[j] + (1 - damp) * buf[(j + 1) % period])
            return soften(out, 0.001, 0.02)
        if self.timbre == "keys":
            # a key: the click of the switch, then the thock of the keycap
            dur = (0.05 + 0.06 * weight) * L
            t = t_of(dur)
            click = lowpass(rng.standard_normal(len(t)), 3000 + 5000 * b) * np.exp(-t / 0.0015) * 0.6
            thock = np.sin(2 * np.pi * (f * 0.35) * t) * np.exp(-t / ((0.01 + 0.012 * weight) * L))
            thock += 0.4 * np.sin(2 * np.pi * (f * 0.35 * 2.3) * t) * np.exp(-t / 0.006)
            return soften(click + thock, 0.0005, 0.008)
        if self.timbre == "digital":
            dur = (0.04 + 0.12 * weight) * L
            t = t_of(dur)
            ff = f * (1 + 0.08 * np.exp(-t / 0.01))
            ph = 2 * np.pi * np.cumsum(ff) / SR
            x = np.sin(ph) + 0.25 * b * np.sign(np.sin(ph)) * 0.5
            env = np.exp(-t / ((0.02 + 0.06 * weight) * L))
            return soften(x * env, 0.002, 0.01)
        # soft: a wooden bar — modes 1, 2.76, 5.40, the upper ones dying fast
        dur = (0.04 + 0.2 * weight) * L
        t = t_of(dur)
        body = (0.008 + 0.06 * weight) * L
        x = np.sin(2 * np.pi * f * t) * np.exp(-t / body)
        x += (0.15 + 0.4 * b) * np.sin(2 * np.pi * f * 2.76 * t) * np.exp(-t / (body * 0.35))
        x += (0.05 + 0.2 * b) * np.sin(2 * np.pi * f * 5.40 * t) * np.exp(-t / (body * 0.15))
        x += lowpass(rng.standard_normal(len(t)), 3500) * np.exp(-t / 0.0012) * 0.25
        return soften(x, 0.0015, 0.01)


def seq(parts):
    end = max(int(SR * s) + len(x) for x, s in parts)
    out = np.zeros(end)
    for x, s in parts:
        i = int(SR * s)
        out[i:i + len(x)] += x
    return out


def glide(f0, f1, dur, vib=0.0, rate=16.0, shape=0.06):
    t = t_of(dur)
    k = np.clip(t / dur, 0, 1)
    k = k * k * (3 - 2 * k)
    f = (f0 + (f1 - f0) * k) * (1 + vib * np.sin(2 * np.pi * rate * t))
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = np.sin(ph) + 0.18 * np.sin(2 * ph) + 0.05 * np.sin(3 * ph)
    env = np.minimum(1, t / shape) * np.exp(-np.maximum(0, t - shape) / max(0.02, dur * 0.6))
    return soften(x * env, 0.006, 0.02)


def noise_swell(dur, lo, hi):
    t = t_of(dur)
    n = np.random.default_rng(7).standard_normal(len(t))
    n = lowpass(highpass(n, lo), hi, 2)
    return soften(n * np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 2, 0.01, 0.03)


def purr(dur=0.55):
    t = t_of(dur)
    am = 0.55 + 0.45 * np.sin(2 * np.pi * 26 * t)
    x = (np.sin(2 * np.pi * 150 * t) + 0.5 * np.sin(2 * np.pi * 300 * t) + 0.2 * np.sin(2 * np.pi * 450 * t)) * am
    env = np.minimum(1, t / 0.08) * np.minimum(1, (dur - t) / 0.18)
    return soften(lowpass(x * env, 1200), 0.02, 0.05)


def ui_set(timbre, pitch=0.0, bright=0.5, length=1.0):
    """{name: (sound, level in dBFS)} — the same notes for every timbre."""
    v = Voice(timbre, bright, length)
    k = 2 ** (pitch / 12)
    n = lambda f, w=1.0: v.note(f * k, w)
    L = length
    return {
        "cursor": (n(E6, 0.05), -37),
        "tick": (n(B6, 0.02), -37),
        "select": (n(B5, 0.45), -28),
        "back": (n(Gs5, 0.4), -29),
        "toggle": (seq([(n(B5, 0.35), 0), (n(E6, 0.4), 0.045 * L)]), -28),
        "open": (seq([(n(E5, 0.5), 0), (n(B5, 0.6), 0.05 * L)]), -29),
        "close": (seq([(n(B5, 0.45), 0), (n(E5, 0.55), 0.05 * L)]), -30),
        "launch": (seq([(n(f, 0.7), i * 0.04 * L) for i, f in enumerate([E5, Gs5, B5])]), -28),
        "quest": (seq([(n(f, 0.9), i * 0.065 * L) for i, f in enumerate([E5, Gs5, B5, E6])]), -27),
        "whoosh": (noise_swell(0.16 * L, 300, 1200 + 2400 * bright), -35),
        "charge": (glide(E4 * k, E5 * k, 0.62, 0.012, 7, 0.3), -32),
        "nope": (seq([(lowpass(n(E4, 0.4), 1600), 0), (lowpass(n(B3, 0.45), 1400), 0.09 * L)]), -29),
        "pop": (Voice("pop", bright, length).note(B5 * k, 0.5), -29),
        "boing": (glide(420 * k, 260 * k, 0.16 * L, 0.03, 18, 0.01), -31),
        "snap": (seq([(n(E6, 0.05), 0), (n(B6, 0.05), 0.03 * L)]), -32),
    }


VELLY = {
    "wake": (seq([(glide(520, 1040, 0.16, 0.02, 18, 0.04), 0), (glide(1040, 880, 0.14, 0.015, 18, 0.02), 0.13)]), -25),
    "listen": (glide(700, 990, 0.08, 0.0, 16, 0.02), -28),
    "heard": (glide(990, 700, 0.08, 0.0, 16, 0.02), -29),
    "done": (seq([(glide(784, 830, 0.09, 0.01, 20, 0.02), 0), (glide(1175, 1320, 0.14, 0.015, 20, 0.02), 0.085)]), -26),
    "error": (glide(620, 380, 0.26, 0.03, 9, 0.03), -28),
    "giggle": (seq([(glide(f, f * 1.22, 0.05, 0.02, 30, 0.01), i * 0.07) for i, f in enumerate([1300, 1200, 1100])]), -27),
    "purr": (purr(), -31),
    "boing": (seq([(glide(300, 520, 0.12, 0.04, 22, 0.01), 0), (glide(520, 360, 0.16, 0.03, 18, 0.01), 0.1)]), -27),
    "whee": (glide(600, 1500, 0.35, 0.03, 12, 0.05), -27),
}


def level(x, rms_db, bright=0.5, peak_db=-9):
    x = highpass(np.asarray(x, dtype=np.float64), 120)
    x = lowpass(x, 3500 + 6000 * bright, 1)
    on = np.abs(x) > np.abs(x).max() * 0.05
    body = x[on] if on.any() else x
    x = x * (10 ** (rms_db / 20) / (np.sqrt(np.mean(body ** 2)) + 1e-9))
    peak = np.abs(x).max()
    if peak > 10 ** (peak_db / 20):
        x = x * (10 ** (peak_db / 20) / peak)
    return np.concatenate([x, np.zeros(int(SR * 0.015))])


def save(x, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype("<i2").tobytes())


def write_set(out, timbre, pitch, bright, length):
    for key, (x, db) in ui_set(timbre, pitch, bright, length).items():
        save(level(x, db, bright), os.path.join(out, key + ".wav"))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--timbre", choices=TIMBRES)
    ap.add_argument("--pitch", type=float, default=0.0)
    ap.add_argument("--bright", type=float, default=0.5)
    ap.add_argument("--length", type=float, default=1.0)
    ap.add_argument("--out")
    a = ap.parse_args()
    if a.timbre and a.out:
        write_set(a.out, a.timbre, max(-12, min(12, a.pitch)), max(0, min(1, a.bright)), max(0.5, min(2, a.length)))
        print("done")
        return
    for timbre in TIMBRES:
        write_set(os.path.join(SFX, timbre), timbre, 0.0, 0.5, 1.0)
        print(f"{timbre}: done")
    for key, (x, db) in VELLY.items():
        save(level(x, db), os.path.join(SFX, "velly", key + ".wav"))
    print(f"velly: {len(VELLY)} chirps")


if __name__ == "__main__":
    main()
