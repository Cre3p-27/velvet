#!/usr/bin/env python3
"""
VELVET · assets/make-wallpapers.py

Paints the three wallpapers that ship with the shell (assets/wallpapers), so a
fresh install has a picture — and the looks have colours to take from it —
before the user has a wallpaper folder of their own. Pure numpy + Pillow, no
source images: everything here is ours.

    python3 assets/make-wallpapers.py [width height]
"""
import os
import sys

import numpy as np
from PIL import Image

W, H = (int(sys.argv[1]), int(sys.argv[2])) if len(sys.argv) > 2 else (3840, 2160)
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "wallpapers")

# name: (ground, glow A, glow B, seed)
LOOKS = {
    "velvet-crimson": ((14, 10, 13), (215, 28, 66), (120, 18, 60), 7),
    "velvet-dusk": ((15, 11, 22), (228, 104, 58), (118, 52, 168), 11),
    "velvet-tide": ((8, 14, 20), (38, 196, 182), (32, 70, 160), 23),
}


def field(rng, x, y, n):
    """Soft folds of cloth: a few slanted waves bent by each other."""
    f = np.zeros_like(x)
    base = rng.uniform(0.5, 1.2)                      # drapes fall one way
    for _ in range(n):
        a = base + rng.uniform(-0.35, 0.35)
        k = rng.uniform(2.0, 4.5)
        ph = rng.uniform(0, 2 * np.pi)
        bend = rng.uniform(0.2, 0.6)
        u = x * np.cos(a) + y * np.sin(a)
        v = -x * np.sin(a) + y * np.cos(a)
        f += np.sin(k * u + bend * np.sin(1.7 * k * v + ph) + ph)
    return f / np.abs(f).max()


def paint(name, ground, ga, gb, seed):
    rng = np.random.default_rng(seed)
    ys, xs = np.mgrid[0:H, 0:W].astype(np.float32)
    x = (xs - W / 2) / H
    y = (ys - H / 2) / H

    folds = field(rng, x, y, 4)                       # -1..1
    sheen = np.clip(folds, 0, 1) ** 1.6               # the light on the ridges
    crest = np.clip(folds, 0, 1) ** 9                 # the bright line on top
    # two pools of colour, off centre
    cx, cy = rng.uniform(0.25, 0.55), rng.uniform(-0.25, 0.1)
    pool_a = np.exp(-(((x - cx) ** 2) / 0.30 + ((y - cy) ** 2) / 0.22))
    pool_b = np.exp(-(((x + cx * 1.1) ** 2) / 0.40 + ((y + cy + 0.2) ** 2) / 0.30))
    vignette = np.clip(1.15 - 0.9 * (x ** 2 + y ** 2) ** 0.8, 0, 1)

    g = np.array(ground, np.float32)
    a = np.array(ga, np.float32)
    b = np.array(gb, np.float32)
    img = g[None, None, :] * (0.6 + 0.8 * (folds[..., None] * 0.5 + 0.5))
    img += a[None, None, :] * (pool_a * (0.10 + 0.85 * sheen + 0.5 * crest))[..., None]
    img += b[None, None, :] * (pool_b * (0.08 + 0.70 * sheen + 0.35 * crest))[..., None]
    img *= vignette[..., None]
    img += rng.normal(0, 2.2, img.shape[:2])[..., None]   # a little grain, no banding
    Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).save(
        os.path.join(OUT, name + ".jpg"), quality=88, optimize=True, progressive=True)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for n, spec in LOOKS.items():
        paint(n, *spec)
        print("wrote", n)
