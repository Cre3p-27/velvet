#!/usr/bin/env python3
"""
VELVET · assets/make-sfx-packs.py

Synthesises the sound packs that belong with the vibes (SETTINGS → VISUALS →
VIBE → SOUNDS). Each pack is the same ten sounds as the house set in sfx/,
made of different stuff: chiptune squares, neon synth blips, typewriter keys,
paper, glass bells, lute and harp, concrete thuds, soft taps, a plain
desktop's dings.

    python3 make-sfx-packs.py [output-dir] [pack ...]   # default: ./sfx/<pack>/*.wav
    --force                                             # overwrite files that exist
"""

import importlib.util
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("base", os.path.join(HERE, "make-sfx.py"))
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)

RATE = base.RATE
env, sine, sweep, noise, lowpass, highpass = base.env, base.sine, base.sweep, base.noise, base.lowpass, base.highpass
mix, apply_env, write = base.mix, base.apply_env, base.write


# ------------------------------------------------------------------ oscillators
def square(freq, n, duty=0.5):
    out = []
    ph = 0.0
    for _ in range(n):
        out.append(1.0 if ph < duty else -1.0)
        ph = (ph + freq / RATE) % 1.0
    return out


def saw(freq, n):
    out = []
    ph = 0.0
    for _ in range(n):
        out.append(2 * ph - 1)
        ph = (ph + freq / RATE) % 1.0
    return out


def tri(freq, n):
    return [2 * abs(2 * ((i * freq / RATE) % 1.0) - 1) - 1 for i in range(n)]


def gl(f0, f1, n, wave=square, curve=1.0):
    """A glide with any waveform."""
    out = []
    ph = 0.0
    for i in range(n):
        t = (i / max(1, n - 1)) ** curve
        f = f0 + (f1 - f0) * t
        ph = (ph + f / RATE) % 1.0
        out.append(wave_at(wave, ph))
    return out


def wave_at(wave, ph):
    if wave is square:
        return 1.0 if ph < 0.5 else -1.0
    if wave is saw:
        return 2 * ph - 1
    if wave is tri:
        return 2 * abs(2 * ph - 1) - 1
    return math.sin(2 * math.pi * ph)


def pluck(freq, n, damp=0.996, seed=1):
    """Karplus-Strong string."""
    period = max(2, int(RATE / freq))
    rng = random.Random(seed)
    buf = [rng.uniform(-1, 1) for _ in range(period)]
    out = []
    for i in range(n):
        j = i % period
        nxt = buf[(j + 1) % period]
        buf[j] = damp * 0.5 * (buf[j] + nxt)
        out.append(buf[j])
    return out


def bell(freq, n, decay=2.6):
    partials = [(1.0, 1.0), (2.76, 0.55), (5.4, 0.3), (8.93, 0.16)]
    out = [0.0] * n
    for ratio, amp in partials:
        e = env(n, 0.0005, 0.9, decay + ratio * 0.15)
        for i, s in enumerate(sine(freq * ratio, n)):
            out[i] += s * amp * e[i]
    return out


def thud(freq, n, drop=0.5):
    return apply_env(gl(freq, freq * drop, n, sine, 0.5), env(n, 0.0004, 0.9, 3.5))


def tick(n, cutoff=2600, seed=3, curve=5.0):
    return apply_env(highpass(noise(n, seed), cutoff), env(n, 0.0003, 0.6, curve))


def seq(notes, step, mk, tail=0.0):
    """Notes in a row: mk(freq, n) -> samples, each starting `step` s after the last."""
    parts = []
    longest = 0
    for k, f in enumerate(notes):
        buf = mk(f)
        off = int(k * step * RATE)
        parts.append((off, buf))
        longest = max(longest, off + len(buf))
    out = [0.0] * (longest + int(tail * RATE))
    for off, buf in parts:
        for i, s in enumerate(buf):
            out[off + i] += s
    return out


def ms(v):
    return int(RATE * v / 1000)


def air(n, cutoff, seed, shape=lambda t: math.sin(math.pi * t)):
    return apply_env(lowpass(noise(n, seed), cutoff), [shape(i / n) for i in range(n)])


# ------------------------------------------------------------------------ packs
def arcade():
    def chip(f, d=0.07, duty=0.5):
        n = ms(d * 1000)
        return apply_env(square(f, n, duty), env(n, 0.0005, 0.9, 2.2))

    return {
        "cursor.wav": lambda: chip(1320, 0.04, 0.25),
        "select.wav": lambda: seq([660, 990], 0.055, lambda f: chip(f, 0.09)),
        "back.wav": lambda: seq([660, 440], 0.05, lambda f: chip(f, 0.08, 0.25)),
        "toggle.wav": lambda: seq([1200, 800], 0.03, lambda f: chip(f, 0.05, 0.125)),
        "open.wav": lambda: seq([330, 440, 587, 880], 0.045, lambda f: chip(f, 0.1)),
        "close.wav": lambda: seq([880, 587, 440, 330], 0.04, lambda f: chip(f, 0.08, 0.25)),
        "launch.wav": lambda: mix(apply_env(gl(300, 1500, ms(240), square, 1.6), env(ms(240), 0.001, 0.9, 1.6)),
                                  [s * 0.4 for s in tick(ms(40), 3000, 5)]),
        "whoosh.wav": lambda: mix([s * 0.5 for s in air(ms(150), 6000, 4)],
                                  [s * 0.25 for s in apply_env(gl(900, 300, ms(150), square), env(ms(150), 0.002, 0.9, 2))]),
        "quest.wav": lambda: seq([523, 659, 784, 1047, 784, 1047], 0.075, lambda f: chip(f, 0.14, 0.25), 0.1),
        "charge.wav": lambda: mix(apply_env(gl(150, 900, ms(400), square, 1.5),
                                            [min(1.0, (i / ms(400)) ** 1.4) for i in range(ms(400))]),
                                  [0.0] * ms(330) + [s * 0.6 for s in chip(1400, 0.07, 0.25)]),
    }


def cyber():
    def blip(f0, f1, d, wave=saw, cut=5200):
        n = ms(d * 1000)
        return lowpass(apply_env(gl(f0, f1, n, wave, 0.8), env(n, 0.0006, 0.9, 2.6)), cut)

    return {
        "cursor.wav": lambda: mix([s * 0.5 for s in blip(2600, 3200, 0.035, sine)], [s * 0.25 for s in tick(ms(25), 5000, 8)]),
        "select.wav": lambda: mix(blip(500, 1400, 0.14), [s * 0.5 for s in blip(1000, 2800, 0.14, sine)]),
        "back.wav": lambda: blip(1100, 380, 0.12),
        "toggle.wav": lambda: mix(blip(1800, 1800, 0.03, sine), [0.0] * ms(30) + blip(2400, 2400, 0.04, sine)),
        "open.wav": lambda: mix(air(ms(320), 7000, 5, lambda t: t ** 1.8 * (1 - t ** 5)),
                                [s * 0.7 for s in blip(120, 900, 0.32)],
                                [0.0] * ms(200) + [s * 0.8 for s in thud(150, ms(140), 0.4)]),
        "close.wav": lambda: mix(blip(900, 140, 0.22), [s * 0.5 for s in air(ms(220), 4000, 6, lambda t: (1 - t) ** 2)]),
        "launch.wav": lambda: mix(blip(300, 2400, 0.26), [s * 0.5 for s in blip(600, 4800, 0.26, sine)],
                                  [s * 0.4 for s in tick(ms(40), 4200, 11)]),
        "whoosh.wav": lambda: mix(air(ms(170), 5200, 12), [s * 0.3 for s in blip(400, 1600, 0.17, sine)]),
        "quest.wav": lambda: seq([392, 587, 784, 1175], 0.07, lambda f: mix(blip(f, f, 0.22, saw, 4200), [s * 0.4 for s in blip(f * 2, f * 2, 0.22, sine)]), 0.1),
        "charge.wav": lambda: mix(blip(110, 1400, 0.4), [0.0] * ms(340) + [s * 0.7 for s in blip(2200, 1400, 0.07, sine)]),
    }


def terminal():
    def key(freq=150, d=0.045, cut=2200, seed=2):
        n = ms(d * 1000)
        return mix([s * 0.6 for s in thud(freq, n, 0.6)], [s * 0.6 for s in tick(ms(14), cut, seed, 6)])

    return {
        "cursor.wav": lambda: [s * 0.7 for s in key(190, 0.022, 3200, 4)],
        "select.wav": lambda: key(110, 0.07, 2000, 6),
        "back.wav": lambda: mix(key(140, 0.05, 2400, 7), [0.0] * ms(55) + [s * 0.6 for s in key(120, 0.04, 2400, 8)]),
        "toggle.wav": lambda: mix(tick(ms(18), 1800, 9), [0.0] * ms(40) + [s * 0.9 for s in tick(ms(22), 1500, 10)],
                                  [s * 0.4 for s in thud(210, ms(60), 0.7)]),
        "open.wav": lambda: mix([s * 0.9 for s in apply_env(bell(2200, ms(380), 3.0), env(ms(380), 0.0004, 0.9, 1.0))],
                                [s * 0.4 for s in key(120, 0.06, 1800, 11)]),
        "close.wav": lambda: mix(key(95, 0.08, 1400, 12), [s * 0.3 for s in air(ms(120), 2400, 13, lambda t: (1 - t) ** 2)]),
        "launch.wav": lambda: seq([1000, 1000, 1500], 0.09, lambda f: apply_env(square(f, ms(70), 0.5), env(ms(70), 0.0008, 0.9, 2.0)), 0.05),
        "whoosh.wav": lambda: [s * 0.6 for s in air(ms(120), 2600, 14)],
        "quest.wav": lambda: seq([880, 1109, 1319], 0.085, lambda f: apply_env(square(f, ms(110), 0.5), env(ms(110), 0.0008, 0.9, 2.2)), 0.1),
        "charge.wav": lambda: seq([300, 340, 390, 450, 520, 600, 700, 820, 960, 1120], 0.034,
                                  lambda f: apply_env(square(f, ms(40), 0.5), env(ms(40), 0.0005, 0.9, 2.0)), 0.06),
    }


def paper():
    def flip(d, lo=800, hi=4200, up=True, seed=5):
        n = ms(d * 1000)
        sh = (lambda t: (t ** 0.6) * (1 - t) ** 1.4 * 3) if up else (lambda t: ((1 - t) ** 0.6) * t ** 1.4 * 3)
        return apply_env(lowpass(highpass(noise(n, seed), lo), hi), [min(1.0, sh(i / n)) for i in range(n)])

    return {
        "cursor.wav": lambda: [s * 0.8 for s in mix(flip(0.03, 1800, 6000), [s * 0.2 for s in thud(260, ms(20), 0.7)])],
        "select.wav": lambda: mix([s * 0.8 for s in thud(240, ms(90), 0.55)], [s * 0.45 for s in flip(0.05, 1500, 5200)]),
        "back.wav": lambda: mix(flip(0.12, 600, 3600, False, 6), [s * 0.4 for s in thud(190, ms(60), 0.6)]),
        "toggle.wav": lambda: mix([s * 0.8 for s in thud(300, ms(40), 0.6)], [0.0] * ms(35) + [s * 0.7 for s in thud(220, ms(50), 0.6)]),
        "open.wav": lambda: mix(flip(0.28, 500, 4800, True, 7), [0.0] * ms(190) + [s * 0.6 for s in thud(210, ms(110), 0.5)]),
        "close.wav": lambda: flip(0.2, 500, 3600, False, 8),
        "launch.wav": lambda: mix([s * 0.9 for s in thud(170, ms(130), 0.45)], [s * 0.6 for s in tick(ms(35), 1200, 15, 4)],
                                  [0.0] * ms(60) + [s * 0.4 for s in flip(0.1, 1200, 5000, False, 16)]),
        "whoosh.wav": lambda: [s * 0.8 for s in flip(0.16, 700, 4200, True, 9)],
        "quest.wav": lambda: mix(seq([784, 1175], 0.09, lambda f: bell(f, ms(500), 3.2)), [s * 0.5 for s in thud(240, ms(80), 0.6)]),
        "charge.wav": lambda: mix(flip(0.4, 500, 3600, True, 10), [0.0] * ms(340) + [s * 0.8 for s in thud(210, ms(70), 0.6)]),
    }


def glass():
    def ping(f, d=0.4, g=1.0):
        return [s * g for s in apply_env(bell(f, ms(d * 1000), 2.8), env(ms(d * 1000), 0.0003, 0.9, 1.2))]

    return {
        "cursor.wav": lambda: ping(3136, 0.12, 0.5),
        "select.wav": lambda: mix(ping(1760, 0.5), [0.0] * ms(40) + ping(2349, 0.5, 0.6)),
        "back.wav": lambda: ping(1175, 0.35, 0.9),
        "toggle.wav": lambda: mix(ping(2637, 0.14, 0.7), [0.0] * ms(35) + ping(3520, 0.14, 0.6)),
        "open.wav": lambda: mix(air(ms(320), 8000, 20, lambda t: t ** 1.6 * (1 - t ** 4)),
                                [s * 0.5 for s in gl(300, 1400, ms(320), sine, 1.8)],
                                [0.0] * ms(180) + ping(1568, 0.5)),
        "close.wav": lambda: mix([s * 0.5 for s in gl(1300, 280, ms(240), sine, 1.2)], ping(880, 0.4, 0.5)),
        "launch.wav": lambda: seq([1047, 1568, 2093], 0.06, lambda f: ping(f, 0.5, 0.8)),
        "whoosh.wav": lambda: [s * 0.55 for s in air(ms(200), 9000, 21)],
        "quest.wav": lambda: seq([1047, 1319, 1568, 2093], 0.075, lambda f: ping(f, 0.55, 0.8)),
        "charge.wav": lambda: mix(apply_env(gl(260, 1800, ms(400), sine, 1.6), [min(1.0, (i / ms(400)) ** 1.8) for i in range(ms(400))]),
                                  [0.0] * ms(340) + ping(2349, 0.3)),
    }


def rpg():
    def lute(f, d=0.5, g=1.0, seed=1):
        n = ms(d * 1000)
        return [s * g for s in apply_env(pluck(f, n, 0.9965, seed), env(n, 0.0005, 0.95, 1.4))]

    def chime(f, d=0.6):
        return apply_env(bell(f, ms(d * 1000), 3.0), env(ms(d * 1000), 0.0004, 0.9, 1.1))

    return {
        "cursor.wav": lambda: lute(587, 0.16, 0.7, 3),
        "select.wav": lambda: mix(lute(440, 0.4), [0.0] * ms(35) + lute(659, 0.4, 0.8, 4), [s * 0.25 for s in chime(1760, 0.5)]),
        "back.wav": lambda: lute(294, 0.3, 0.9, 5),
        "toggle.wav": lambda: mix([s * 0.7 for s in thud(330, ms(30), 0.8)], [0.0] * ms(38) + [s * 0.7 for s in thud(260, ms(40), 0.8)]),
        "open.wav": lambda: seq([392, 494, 587, 784, 988], 0.05, lambda f: lute(f, 0.6, 0.8, int(f)), 0.1),
        "close.wav": lambda: seq([784, 587, 440, 330], 0.05, lambda f: lute(f, 0.4, 0.8, int(f)), 0.05),
        "launch.wav": lambda: mix(apply_env(lowpass(saw(220, ms(320)), 1400), env(ms(320), 0.02, 0.9, 1.6)),
                                  apply_env(lowpass(saw(330, ms(320)), 1400), env(ms(320), 0.02, 0.9, 1.6)),
                                  [0.0] * ms(120) + [s * 0.7 for s in chime(1319, 0.5)]),
        "whoosh.wav": lambda: [s * 0.5 for s in air(ms(180), 2800, 22)],
        "quest.wav": lambda: seq([392, 494, 587, 784, 988, 784, 1175], 0.09, lambda f: mix(lute(f, 0.6, 0.8, int(f)), [s * 0.4 for s in chime(f * 2, 0.7)]), 0.2),
        "charge.wav": lambda: mix(apply_env(lowpass(saw(147, ms(400)), 1200), [min(1.0, (i / ms(400)) ** 1.6) for i in range(ms(400))]),
                                  apply_env(lowpass(saw(220, ms(400)), 1200), [min(1.0, (i / ms(400)) ** 1.6) * 0.6 for i in range(ms(400))]),
                                  [0.0] * ms(340) + [s * 0.8 for s in chime(1760, 0.4)]),
    }


def brutal():
    def clack(f=110, d=0.07, cut=1800, seed=2, g=1.0):
        n = ms(d * 1000)
        return [s * g for s in mix([s * 0.9 for s in thud(f, n, 0.45)], [s * 0.7 for s in tick(ms(18), cut, seed, 5)])]

    return {
        "cursor.wav": lambda: clack(150, 0.04, 2400, 3, 0.7),
        "select.wav": lambda: clack(70, 0.14, 1600, 4),
        "back.wav": lambda: clack(95, 0.09, 1400, 5, 0.9),
        "toggle.wav": lambda: mix(clack(85, 0.06, 1600, 6), [0.0] * ms(55) + clack(120, 0.07, 1800, 7)),
        "open.wav": lambda: mix(air(ms(260), 1800, 8, lambda t: t ** 1.5 * (1 - t ** 5)), [0.0] * ms(150) + clack(55, 0.2, 1200, 9, 1.2),
                                [s * 0.4 for s in gl(60, 160, ms(260), saw, 1.5)]),
        "close.wav": lambda: mix(clack(65, 0.16, 1300, 10), [s * 0.4 for s in air(ms(180), 1500, 11, lambda t: (1 - t) ** 2)]),
        "launch.wav": lambda: mix(clack(60, 0.18, 1200, 12, 1.2), [0.0] * ms(60) + [s * 0.6 for s in gl(120, 700, ms(180), saw, 1.4)],
                                  [s * 0.4 for s in tick(ms(40), 3000, 13)]),
        "whoosh.wav": lambda: [s * 0.7 for s in air(ms(150), 1600, 14)],
        "quest.wav": lambda: seq([196, 247, 294], 0.08, lambda f: apply_env(lowpass(saw(f, ms(260)), 1800), env(ms(260), 0.004, 0.9, 2.0)), 0.1),
        "charge.wav": lambda: mix(apply_env(gl(70, 420, ms(400), saw, 1.4), [min(1.0, (i / ms(400)) ** 1.3) for i in range(ms(400))]),
                                  [0.0] * ms(350) + clack(60, 0.1, 1300, 15, 1.2)),
    }


def clean():
    """Soft sine taps — close to silence, with a little warmth."""

    def tap(f, d=0.09, g=1.0):
        n = ms(d * 1000)
        return [s * g for s in apply_env(sine(f, n), env(n, 0.0008, 0.9, 3.4))]

    def soft(f, d=0.22, g=1.0):
        n = ms(d * 1000)
        body = mix(sine(f, n), [x * 0.25 for x in sine(f * 2, n)])
        return [s * g for s in apply_env(body, env(n, 0.004, 0.9, 2.4))]

    return {
        "cursor.wav": lambda: tap(1568, 0.04, 0.55),
        "select.wav": lambda: mix(tap(880, 0.12), [0.0] * ms(45) + tap(1318, 0.16, 0.85)),
        "back.wav": lambda: mix(tap(988, 0.1), [0.0] * ms(45) + tap(659, 0.16, 0.85)),
        "toggle.wav": lambda: mix(tap(1174, 0.05, 0.85), [0.0] * ms(42) + tap(1568, 0.07, 0.7)),
        "open.wav": lambda: mix([s * 0.55 for s in air(ms(240), 3500, 31, lambda t: t ** 1.5 * (1 - t ** 4))],
                                [0.0] * ms(120) + soft(784, 0.32, 0.9)),
        "close.wav": lambda: mix([s * 0.5 for s in air(ms(200), 3000, 32, lambda t: (1 - t) ** 2)], soft(587, 0.24, 0.75)),
        "launch.wav": lambda: seq([784, 1047, 1318], 0.05, lambda f: soft(f, 0.26, 0.8)),
        "whoosh.wav": lambda: [s * 0.5 for s in air(ms(170), 3800, 33)],
        "quest.wav": lambda: seq([784, 988, 1175, 1568], 0.08, lambda f: soft(f, 0.32, 0.8), 0.1),
        "charge.wav": lambda: mix(apply_env(gl(200, 1200, ms(380), sine, 1.6), [min(1.0, (i / ms(380)) ** 1.8) for i in range(ms(380))]),
                                  [0.0] * ms(330) + soft(1568, 0.2, 0.8)),
    }


def windows():
    """A plain desktop: dry clicks, round dings, a few warm triangle chords."""

    def click(cut=2600, seed=41, g=1.0):
        return [s * g for s in mix([x * 0.6 for x in tick(ms(10), cut, seed, 7)], [x * 0.5 for x in thud(900, ms(8), 0.7)])]

    def ding(f, d=0.34, g=1.0):
        n = ms(d * 1000)
        body = mix(sine(f, n), [x * 0.3 for x in sine(f * 2.01, n)], [x * 0.12 for x in sine(f * 3.02, n)])
        return [s * g for s in apply_env(body, env(n, 0.001, 0.9, 2.6))]

    def warm(f, d=0.3, g=1.0):
        n = ms(d * 1000)
        return [s * g for s in apply_env(lowpass(tri(f, n), 3200), env(n, 0.006, 0.9, 1.9))]

    return {
        "cursor.wav": lambda: click(3200, 42, 0.8),
        "select.wav": lambda: mix(click(2400, 43), [0.0] * ms(8) + ding(1318, 0.28, 0.7)),
        "back.wav": lambda: mix(click(2000, 44), [0.0] * ms(8) + ding(880, 0.26, 0.7)),
        "toggle.wav": lambda: mix(click(2800, 45), [0.0] * ms(55) + click(2200, 46, 0.9)),
        "open.wav": lambda: seq([523, 659, 784], 0.07, lambda f: warm(f, 0.34, 0.9), 0.1),
        "close.wav": lambda: seq([784, 659, 523], 0.06, lambda f: warm(f, 0.28, 0.8), 0.05),
        "launch.wav": lambda: mix(seq([392, 523, 659, 784], 0.075, lambda f: warm(f, 0.55, 0.7), 0.2),
                                  [0.0] * ms(300) + [x * 0.8 for x in warm(1047, 0.5, 0.8)]),
        "whoosh.wav": lambda: [s * 0.5 for s in air(ms(140), 3000, 47)],
        "quest.wav": lambda: seq([1175, 880], 0.16, lambda f: ding(f, 0.5, 0.9), 0.1),
        "charge.wav": lambda: mix(apply_env(gl(180, 900, ms(380), tri, 1.5), [min(1.0, (i / ms(380)) ** 1.6) for i in range(ms(380))]),
                                  [0.0] * ms(330) + ding(1318, 0.3, 0.8)),
    }


PACKS = {"arcade": arcade, "cyber": cyber, "terminal": terminal, "paper": paper, "glass": glass, "rpg": rpg, "brutal": brutal, "clean": clean, "windows": windows}


def write_level(path, buf, target=0.21):
    """Like the house writer, then brought to the house loudness (RMS), so a
    pack never shouts over the rest of the desktop."""
    import struct
    import wave
    buf = base.fade_out(base.soft_clip(base.normalise(buf)))
    rms = math.sqrt(sum(s * s for s in buf) / len(buf)) or 1.0
    gain = min(1.0, target / rms)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * gain)) * 32000)) for s in buf))
    print(f"  {os.path.basename(path):<12} {len(buf) / RATE * 1000:5.0f} ms  x{gain:.2f}")


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    force = "--force" in sys.argv[1:]
    out = os.path.join(HERE, "sfx")
    if args and args[0] not in PACKS:
        out = args.pop(0)
    names = args or list(PACKS)
    for name in names:
        build = PACKS[name]
        d = os.path.join(out, name)
        os.makedirs(d, exist_ok=True)
        print(f"{name}:")
        for fname, fn in build().items():
            path = os.path.join(d, fname)
            # What is already there stays — a pack is made once.
            if os.path.exists(path) and not force:
                print(f"  {fname:<12} kept")
                continue
            write_level(path, fn())
    print("Done.")


if __name__ == "__main__":
    main()
