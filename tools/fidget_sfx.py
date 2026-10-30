# tools/fidget_sfx.py — the fidget sounds (tick, nope, pop, boing, snap), synthesised:
#   python3 tools/fidget_sfx.py assets/sfx
# 48 kHz mono 16 bit, peaks at 0.802 like the rest of assets/sfx. Every sound pack shares them.
import sys, wave, numpy as np
SR = 48000
OUT = sys.argv[1]
rng = np.random.default_rng(7)

def t(sec):
    return np.arange(int(SR * sec)) / SR

def env(n, attack, decay):
    x = np.arange(n) / SR
    a = np.clip(x / max(attack, 1e-4), 0, 1)
    return a * np.exp(-x / decay)

def tone(f0, sec, decay, attack=0.001, f1=None, shape="sine"):
    x = t(sec)
    f = f0 if f1 is None else f0 * (f1 / f0) ** (x / sec)
    ph = 2 * np.pi * np.cumsum(np.full(len(x), 1.0) * f) / SR
    w = np.sin(ph) if shape == "sine" else np.sign(np.sin(ph)) * 0.6
    return w * env(len(x), attack, decay)

def noise(sec, decay, hp=0.0):
    n = rng.standard_normal(int(SR * sec))
    if hp > 0:
        n = np.diff(n, prepend=0) * hp + n * (1 - hp)
    return n * env(len(n), 0.0003, decay)

def place(buf, piece, at):
    i = int(SR * at)
    buf[i:i + len(piece)] += piece[:max(0, len(buf) - i)]

def save(name, buf):
    buf = buf - np.mean(buf)
    fade = min(len(buf), int(SR * 0.004))
    buf[-fade:] *= np.linspace(1, 0, fade)
    buf = buf / (np.abs(buf).max() + 1e-9) * 0.802
    with wave.open(f"{OUT}/{name}.wav", "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((buf * 32767).astype(np.int16).tobytes())
    print(name, round(len(buf) / SR, 3), "rms", round(float(np.sqrt(np.mean(buf ** 2))), 3))

# tick — a detent: a tiny bright click with a woody body
b = np.zeros(int(SR * 0.035))
place(b, noise(0.006, 0.0012, hp=0.9) * 0.6, 0)
place(b, tone(3200, 0.03, 0.004) * 0.7, 0)
place(b, tone(900, 0.03, 0.006) * 0.5, 0.0005)
save("tick", b)

# nope — a soft "uh-uh", two little falling boops
b = np.zeros(int(SR * 0.3))
place(b, tone(330, 0.11, 0.045, attack=0.004, f1=290) * 0.9, 0)
place(b, tone(660, 0.11, 0.03, attack=0.004, f1=580) * 0.18, 0)
place(b, tone(262, 0.15, 0.06, attack=0.004, f1=220) * 0.95, 0.12)
place(b, tone(524, 0.15, 0.04, attack=0.004, f1=440) * 0.18, 0.12)
save("nope", b)

# pop — a bubble: a quick upward chirp
b = np.zeros(int(SR * 0.09))
place(b, tone(380, 0.06, 0.018, attack=0.0008, f1=1250) * 1.0, 0)
place(b, noise(0.004, 0.0008, hp=0.8) * 0.25, 0)
save("pop", b)

# boing — a spring: a wobbling tone that settles
x = t(0.34)
f = 210 + 90 * np.exp(-x / 0.08) * np.cos(2 * np.pi * 14 * x)
ph = 2 * np.pi * np.cumsum(f) / SR
b = (np.sin(ph) + 0.25 * np.sin(2 * ph)) * env(len(x), 0.002, 0.11)
save("boing", b)

# snap — a switch flipping: crisp click + short low thock
b = np.zeros(int(SR * 0.07))
place(b, noise(0.005, 0.0009, hp=0.95) * 0.7, 0)
place(b, tone(4200, 0.02, 0.0025) * 0.45, 0)
place(b, tone(210, 0.06, 0.014, attack=0.001) * 0.9, 0.004)
save("snap", b)
