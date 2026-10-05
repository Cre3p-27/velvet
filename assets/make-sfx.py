#!/usr/bin/env python3
"""
VELVET · assets/make-sfx.py

Synthesises the six UI sounds the menu uses. They're deliberately dry, short
and a bit percussive — closer to a UI in a fighting game than to a system beep.
Re-run this after editing to regenerate; nothing else depends on it.

    python3 make-sfx.py [output-dir]
"""

import math
import os
import random
import struct
import sys
import wave

RATE = 48000


def env(n, attack=0.002, decay=0.08, curve=3.0):
    """Percussive envelope: near-instant attack, exponential tail."""
    a = max(1, int(attack * RATE))
    out = []
    for i in range(n):
        if i < a:
            out.append(i / a)
        else:
            t = (i - a) / max(1, n - a)
            out.append(max(0.0, (1.0 - t) ** curve))
    return out


def sine(freq, n, phase=0.0):
    return [math.sin(2 * math.pi * freq * i / RATE + phase) for i in range(n)]


def sweep(f0, f1, n, curve=1.0):
    out = []
    phase = 0.0
    for i in range(n):
        t = (i / max(1, n - 1)) ** curve
        f = f0 + (f1 - f0) * t
        phase += 2 * math.pi * f / RATE
        out.append(math.sin(phase))
    return out


def noise(n, seed=1):
    rng = random.Random(seed)
    return [rng.uniform(-1, 1) for _ in range(n)]


def lowpass(buf, cutoff):
    """One-pole lowpass — enough to take the fizz off white noise."""
    a = math.exp(-2 * math.pi * cutoff / RATE)
    out = []
    z = 0.0
    for s in buf:
        z = s * (1 - a) + z * a
        out.append(z)
    return out


def highpass(buf, cutoff):
    a = math.exp(-2 * math.pi * cutoff / RATE)
    out = []
    z = 0.0
    prev = 0.0
    for s in buf:
        z = a * (z + s - prev)
        prev = s
        out.append(z)
    return out


def mix(*layers):
    n = max(len(l) for l in layers)
    out = [0.0] * n
    for l in layers:
        for i, s in enumerate(l):
            out[i] += s
    return out


def apply_env(buf, e):
    return [s * e[i] for i, s in enumerate(buf)]


def normalise(buf, peak=0.86):
    m = max(abs(s) for s in buf) or 1.0
    return [s * peak / m for s in buf]


def soft_clip(buf):
    return [math.tanh(s * 1.35) for s in buf]


def fade_out(buf, ms=4):
    n = int(RATE * ms / 1000)
    for i in range(min(n, len(buf))):
        buf[len(buf) - 1 - i] *= i / n
    return buf


def write(path, buf):
    buf = fade_out(soft_clip(normalise(buf)))
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32000)) for s in buf))
    print(f"  {os.path.basename(path):<12} {len(buf) / RATE * 1000:5.0f} ms")


# --------------------------------------------------------------------- sounds
def cursor():
    """Moving between rows. Tiny, dry, gone before you notice it."""
    n = int(RATE * 0.045)
    tick = apply_env(highpass(noise(n, 7), 2600), env(n, 0.0004, 0.03, 5.0))
    body = apply_env(sine(2050, n), env(n, 0.0004, 0.03, 6.0))
    return mix([s * 0.55 for s in tick], [s * 0.45 for s in body])


def select():
    """Confirming. A two-note stab with a bit of weight under it."""
    n = int(RATE * 0.16)
    e = env(n, 0.0008, 0.14, 3.2)
    hit = mix(
        [s * 0.5 for s in sine(880, n)],
        [s * 0.32 for s in sine(1320, n)],
        [s * 0.22 for s in sine(1760, n)],
    )
    low = apply_env(sweep(320, 150, int(RATE * 0.09), 0.6), env(int(RATE * 0.09), 0.001, 0.08, 2.4))
    crack = apply_env(highpass(noise(int(RATE * 0.03), 11), 3400), env(int(RATE * 0.03), 0.0003, 0.02, 5.0))
    return mix(apply_env(hit, e), [s * 0.45 for s in low], [s * 0.35 for s in crack])


def back():
    """Leaving a page. Same family as select, pitched down and shorter."""
    n = int(RATE * 0.12)
    e = env(n, 0.0008, 0.1, 3.0)
    tone = mix([s * 0.6 for s in sweep(760, 420, n, 0.8)], [s * 0.25 for s in sweep(1140, 630, n, 0.8)])
    return mix(apply_env(tone, e), [s * 0.3 for s in apply_env(lowpass(noise(n, 3), 1800), e)])


def toggle():
    """Flipping a switch. Two clicks a hair apart, like a real one."""
    n = int(RATE * 0.075)
    e1 = env(n, 0.0003, 0.02, 6.0)
    click1 = apply_env(highpass(noise(n, 21), 2200), e1)
    gap = [0.0] * int(RATE * 0.018)
    n2 = int(RATE * 0.055)
    click2 = apply_env(highpass(noise(n2, 22), 3000), env(n2, 0.0003, 0.03, 5.0))
    tone = apply_env(sine(1480, n2), env(n2, 0.0004, 0.035, 4.0))
    second = mix([s * 0.6 for s in click2], [s * 0.4 for s in tone])
    return mix([s * 0.7 for s in click1], gap + second)


def open_():
    """The menu arriving. Rising whoosh into an impact."""
    n = int(RATE * 0.30)
    air = apply_env(lowpass(noise(n, 5), 5200), [min(1.0, (i / n) ** 1.6) * (1 - (i / n) ** 6) for i in range(n)])
    rise = apply_env(sweep(180, 900, n, 1.9), [min(1.0, (i / n) ** 2.2) for i in range(n)])
    hit_n = int(RATE * 0.12)
    hit_pad = [0.0] * (n - hit_n)
    hit = hit_pad + apply_env(
        mix([s * 0.6 for s in sine(660, hit_n)], [s * 0.4 for s in sine(990, hit_n)]),
        env(hit_n, 0.0008, 0.1, 3.0),
    )
    return mix([s * 0.45 for s in air], [s * 0.3 for s in rise], [s * 0.6 for s in hit])


def close_():
    """The menu leaving. The same gesture, reversed and shorter."""
    n = int(RATE * 0.20)
    fall = apply_env(sweep(820, 190, n, 1.3), env(n, 0.001, 0.18, 2.2))
    air = apply_env(lowpass(noise(n, 9), 3200), [(1 - i / n) ** 2.2 for i in range(n)])
    return mix([s * 0.6 for s in fall], [s * 0.35 for s in air])


def launch():
    """Firing an app. A rising three-note chirp with a soft crack on top —
    the game-menu 'GO' moment."""
    n = int(RATE * 0.26)
    e = env(n, 0.0006, 0.24, 2.6)
    a = mix(
        [s * 0.5 for s in sine(520, n)],
        [s * 0.34 for s in sine(780, n)],
        [s * 0.26 for s in sine(1040, n)],
    )
    rise = apply_env(sweep(260, 1180, n, 1.6), [min(1.0, (i / n) ** 1.8) for i in range(n)])
    crack = apply_env(highpass(noise(int(RATE * 0.05), 23), 3200), env(int(RATE * 0.05), 0.0003, 0.04, 4.0))
    return mix(apply_env(a, e), [s * 0.4 for s in rise], [s * 0.4 for s in crack])


def whoosh():
    """Sliding through a carousel. Filtered noise that breathes up and away,
    quieter than a click — the sound of motion, not of pressing."""
    n = int(RATE * 0.16)
    air = lowpass(noise(n, 17), 3400)
    e = [math.sin(math.pi * min(1.0, i / n)) ** 1.4 for i in range(n)]
    body = apply_env(air, e)
    tone = apply_env(sweep(320, 720, n, 2.2), [min(1.0, (i / n) ** 2.0) for i in range(n)])
    return mix([s * 0.5 for s in body], [s * 0.16 for s in tone])


def quest():
    """Finishing a task. A rising three-note figure with a sparkle on top —
    the only sound in the set that is allowed to sound pleased."""
    step = int(RATE * 0.075)
    n = int(RATE * 0.30)
    parts = []
    for k, f in enumerate([523.25, 659.25, 783.99]):
        e = env(n, 0.0008, 0.26, 2.4)
        tone = mix(
            [s * 0.5 for s in sine(f, n)],
            [s * 0.26 for s in sine(f * 2, n)],
            [s * 0.18 for s in sine(f * 3, n)],
        )
        parts.append((k * step, apply_env(tone, e)))
    total = max(off + len(buf) for off, buf in parts)
    out = [0.0] * total
    for off, buf in parts:
        for i, s in enumerate(buf):
            out[off + i] += s
    spark = apply_env(highpass(noise(int(RATE * 0.05), 31), 5200),
                      env(int(RATE * 0.05), 0.0003, 0.04, 4.0))
    base = int(RATE * 0.17)
    for i, s in enumerate(spark):
        if base + i < len(out):
            out[base + i] += s * 0.22
    return out


def charge():
    """Holding the island to wake Velly. A riser that grows with the ring you
    draw, and a click at the end where the hold landed — the sound and the
    hairline along the bottom of the pill finish together.

    The hold is a beat of intent (the press proving it is a hold and not the
    start of a swipe) plus this charge, so the file is short on purpose: a
    long riser under a short bar is how a UI starts to nag."""
    n = int(RATE * 0.40)
    swell = []
    for i in range(n):
        t = i / n
        # Almost silent for the first third, then a real climb: the pressure
        # should arrive with your patience, not before it.
        swell.append(max(0.0, (t - 0.28) / 0.72) ** 1.5 * (1.0 - max(0.0, (t - 0.86) / 0.14)))
    body = apply_env(sweep(150.0, 880.0, n, curve=0.75), swell)
    air = apply_env(highpass(noise(n, 17), 2600), [s * 0.18 for s in swell])
    out = mix(body, air)
    # The landing: a short, bright, falling click.
    pop = int(RATE * 0.07)
    out = out + [s * 0.55 for s in apply_env(sweep(1500.0, 500.0, pop, 1.5), env(pop, 0.0008, 0.06, 3.0))]
    return out


SOUNDS = {
    "cursor.wav": cursor,
    "select.wav": select,
    "back.wav": back,
    "toggle.wav": toggle,
    "open.wav": open_,
    "close.wav": close_,
    "launch.wav": launch,
    "whoosh.wav": whoosh,
    "quest.wav": quest,
    "charge.wav": charge,
}


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "sfx")
    os.makedirs(out, exist_ok=True)
    print(f"Writing UI sounds to {out}")
    for name, fn in SOUNDS.items():
        write(os.path.join(out, name), fn())
    print("Done.")


if __name__ == "__main__":
    main()
