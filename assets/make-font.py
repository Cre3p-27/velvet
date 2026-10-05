#!/usr/bin/env python3
"""
VELVET · assets/make-font.py

Draws VelvetPixel.ttf — the pixel typeface of the ARCADE vibe — from the 5x7
bitmaps below, with nothing but the standard library: every lit pixel is a
square in the glyph outline, so it stays sharp at any size that is a
multiple of 10 px and reads as a pixel font at the others. Lowercase letters
use the capital forms, like the arcade machines this is after.

    python3 make-font.py [output.ttf]       # default: ./fonts/VelvetPixel.ttf
"""

import os
import struct
import sys
import time

UNIT = 100            # font units per design pixel
EM = 1000             # 10 design pixels per em
ASCENT = 800
DESCENT = -200
FAMILY = "Velvet Pixel"

G = {}


def glyph(ch, rows, below=()):
    """rows: 7 strings of 5 chars ('#' lit). below: extra rows under the baseline."""
    assert len(rows) == 7, (ch, len(rows))
    G[ch] = (rows, tuple(below))


# --- capitals
glyph("A", [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"])
glyph("B", ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."])
glyph("C", [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."])
glyph("D", ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."])
glyph("E", ["#####", "#....", "#....", "####.", "#....", "#....", "#####"])
glyph("F", ["#####", "#....", "#....", "####.", "#....", "#....", "#...."])
glyph("G", [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".###."])
glyph("H", ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"])
glyph("I", [".###.", "..#..", "..#..", "..#..", "..#..", "..#..", ".###."])
glyph("J", ["..###", "...#.", "...#.", "...#.", "...#.", "#..#.", ".##.."])
glyph("K", ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"])
glyph("L", ["#....", "#....", "#....", "#....", "#....", "#....", "#####"])
glyph("M", ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"])
glyph("N", ["#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#", "#...#"])
glyph("O", [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."])
glyph("P", ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."])
glyph("Q", [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"])
glyph("R", ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"])
glyph("S", [".####", "#....", "#....", ".###.", "....#", "....#", "####."])
glyph("T", ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."])
glyph("U", ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."])
glyph("V", ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."])
glyph("W", ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "##.##", "#...#"])
glyph("X", ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"])
glyph("Y", ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."])
glyph("Z", ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"])
# --- digits
glyph("0", [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."])
glyph("1", ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."])
glyph("2", [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"])
glyph("3", ["####.", "....#", "....#", ".###.", "....#", "....#", "####."])
glyph("4", ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."])
glyph("5", ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."])
glyph("6", ["..##.", ".#...", "#....", "####.", "#...#", "#...#", ".###."])
glyph("7", ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."])
glyph("8", [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."])
glyph("9", [".###.", "#...#", "#...#", ".####", "....#", "...#.", ".##.."])
# --- punctuation
glyph(" ", ["....", "....", "....", "....", "....", "....", "...."])
glyph(".", [".....", ".....", ".....", ".....", ".....", ".##..", ".##.."])
glyph(",", [".....", ".....", ".....", ".....", ".....", ".##..", ".##.."], below=[".#...", "#...."])
glyph(":", [".....", ".##..", ".##..", ".....", ".##..", ".##..", "....."])
glyph(";", [".....", ".##..", ".##..", ".....", ".##..", ".##..", "....."], below=[".#...", "#...."])
glyph("!", ["..#..", "..#..", "..#..", "..#..", "..#..", ".....", "..#.."])
glyph("?", [".###.", "#...#", "....#", "...#.", "..#..", ".....", "..#.."])
glyph("-", [".....", ".....", ".....", "#####", ".....", ".....", "....."])
glyph("_", [".....", ".....", ".....", ".....", ".....", ".....", "#####"])
glyph("+", [".....", "..#..", "..#..", "#####", "..#..", "..#..", "....."])
glyph("=", [".....", ".....", "#####", ".....", "#####", ".....", "....."])
glyph("/", ["....#", "....#", "...#.", "..#..", ".#...", "#....", "#...."])
glyph("\\", ["#....", "#....", ".#...", "..#..", "...#.", "....#", "....#"])
glyph("(", ["...#.", "..#..", ".#...", ".#...", ".#...", "..#..", "...#."])
glyph(")", [".#...", "..#..", "...#.", "...#.", "...#.", "..#..", ".#..."])
glyph("[", [".###.", ".#...", ".#...", ".#...", ".#...", ".#...", ".###."])
glyph("]", [".###.", "...#.", "...#.", "...#.", "...#.", "...#.", ".###."])
glyph("{", ["...##", "..#..", "..#..", ".#...", "..#..", "..#..", "...##"])
glyph("}", ["##...", "..#..", "..#..", "...#.", "..#..", "..#..", "##..."])
glyph("<", ["...#.", "..#..", ".#...", "#....", ".#...", "..#..", "...#."])
glyph(">", [".#...", "..#..", "...#.", "....#", "...#.", "..#..", ".#..."])
glyph("%", ["##..#", "##.#.", "...#.", "..#..", ".#...", ".#.##", "#..##"])
glyph("#", [".#.#.", "#####", ".#.#.", ".#.#.", ".#.#.", "#####", ".#.#."])
glyph("*", ["..#..", "#.#.#", ".###.", "..#..", ".###.", "#.#.#", "..#.."])
glyph("@", [".###.", "#...#", "#.###", "#.#.#", "#.###", "#....", ".###."])
glyph("&", [".##..", "#..#.", "#.#..", ".#...", "#.#.#", "#..#.", ".##.#"])
glyph("$", ["..#..", ".####", "#.#..", ".###.", "..#.#", "####.", "..#.."])
glyph("|", ["..#..", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."])
glyph("~", [".....", ".....", ".#...", "#.#.#", "...#.", ".....", "....."])
glyph("^", ["..#..", ".#.#.", "#...#", ".....", ".....", ".....", "....."])
glyph("'", ["..#..", "..#..", ".#...", ".....", ".....", ".....", "....."])
glyph('"', [".#.#.", ".#.#.", ".....", ".....", ".....", ".....", "....."])
glyph("`", [".#...", "..#..", ".....", ".....", ".....", ".....", "....."])
# --- the typographic marks the shell uses
glyph("·", [".....", ".....", ".....", "..#..", ".....", ".....", "....."])
glyph("•", [".....", ".....", ".###.", ".###.", ".###.", ".....", "....."])
glyph("—", [".....", ".....", ".....", "#####", ".....", ".....", "....."])
glyph("–", [".....", ".....", ".....", ".###.", ".....", ".....", "....."])
glyph("→", [".....", "..#..", "...#.", "#####", "...#.", "..#..", "....."])
glyph("←", [".....", "..#..", ".#...", "#####", ".#...", "..#..", "....."])
glyph("↑", ["..#..", ".###.", "#.#.#", "..#..", "..#..", "..#..", "..#.."])
glyph("↓", ["..#..", "..#..", "..#..", "..#..", "#.#.#", ".###.", "..#.."])
glyph("×", [".....", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "....."])
glyph("°", [".##..", "#..#.", "#..#.", ".##..", ".....", ".....", "....."])
glyph("…", [".....", ".....", ".....", ".....", ".....", ".....", "#.#.#"])
glyph("›", [".....", "#....", ".#...", "..#..", ".#...", "#....", "....."])
glyph("‹", [".....", "..#..", ".#...", "#....", ".#...", "..#..", "....."])
glyph("’", ["..#..", "..#..", ".#...", ".....", ".....", ".....", "....."])
glyph("‘", ["..#..", ".#...", ".#...", ".....", ".....", ".....", "....."])
glyph("“", [".#.#.", ".#.#.", "#.#..", ".....", ".....", ".....", "....."])
glyph("”", [".#.#.", ".#.#.", ".#.#.", ".....", ".....", ".....", "....."])

for c in "ABCDEFGHIJKLMNOPQRSTUVWXYZ":
    G[c.lower()] = G[c]


def bounds(rows):
    cols = [x for r in rows for x, c in enumerate(r) if c == "#"]
    if not cols:
        return None
    return min(cols), max(cols)


def contours(ch):
    """Outline of one glyph as clockwise rectangles (x0, y0, x1, y1) in font units,
    one per horizontal run of lit pixels."""
    rows, below = G[ch]
    allrows = list(rows) + list(below)
    rects = []
    for ry, row in enumerate(allrows):
        # capitals are 7 rows tall: their top sits at 7 px above the baseline
        y1 = 7 * UNIT - ry * UNIT
        y0 = y1 - UNIT
        x = 0
        while x < len(row):
            if row[x] == "#":
                s = x
                while x < len(row) and row[x] == "#":
                    x += 1
                rects.append((s * UNIT, y0, x * UNIT, y1))
            else:
                x += 1
    return rects


def rect_points(r):
    x0, y0, x1, y1 = r
    return [(x0, y0), (x0, y1), (x1, y1), (x1, y0)]          # clockwise


def glyph_bytes(pts_by_contour):
    """A TrueType simple glyph from lists of points (all on-curve)."""
    if not pts_by_contour:
        return b"", (0, 0, 0, 0)
    pts = [p for c in pts_by_contour for p in c]
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    bbox = (min(xs), min(ys), max(xs), max(ys))
    out = struct.pack(">hhhhh", len(pts_by_contour), *bbox)
    end = -1
    ends = []
    for c in pts_by_contour:
        end += len(c)
        ends.append(end)
    out += struct.pack(">%dH" % len(ends), *ends)
    out += struct.pack(">H", 0)                              # no instructions
    out += bytes([0x01] * len(pts))                          # on-curve, 16-bit deltas
    px = 0
    for x, _ in pts:
        out += struct.pack(">h", x - px)
        px = x
    py = 0
    for _, y in pts:
        out += struct.pack(">h", y - py)
        py = y
    while len(out) % 4:
        out += b"\x00"
    return out, bbox


def checksum(data):
    data = data + b"\x00" * (-len(data) % 4)
    return sum(struct.unpack(">%dI" % (len(data) // 4), data)) & 0xFFFFFFFF


def build():
    order = [".notdef"] + sorted(G.keys(), key=lambda c: ord(c))
    glyphs = []                  # (bytes, bbox, advance, lsb)
    # .notdef: a hollow box
    box_out = rect_points((60, 0, 540, 700))
    box_in = list(reversed(rect_points((140, 100, 460, 600))))
    b, bb = glyph_bytes([box_out, box_in])
    glyphs.append((b, bb, 600, 60))
    for ch in order[1:]:
        rows, below = G[ch]
        rects = contours(ch)
        b, bb = glyph_bytes([rect_points(r) for r in rects])
        bd = bounds(list(rows) + list(below))
        if ch == " ":
            adv = 4 * UNIT
        else:
            adv = ((bd[1] + 2) * UNIT) if bd else 6 * UNIT
        glyphs.append((b, bb, max(adv, 3 * UNIT), bb[0]))

    n = len(glyphs)
    # glyf / loca (short offsets, 4-byte padded so /2 is always whole)
    glyf = b""
    offsets = []
    for b, *_ in glyphs:
        offsets.append(len(glyf))
        glyf += b
    offsets.append(len(glyf))
    loca = b"".join(struct.pack(">H", o // 2) for o in offsets)

    hmtx = b"".join(struct.pack(">Hh", adv, lsb) for _, _, adv, lsb in glyphs)

    xmin = min(g[1][0] for g in glyphs)
    ymin = min(g[1][1] for g in glyphs)
    xmax = max(g[1][2] for g in glyphs)
    ymax = max(g[1][3] for g in glyphs)
    adv_max = max(g[2] for g in glyphs)

    now = int(time.time()) + 2082844800
    head = struct.pack(">IIIIHHqqhhhhHHhhh", 0x00010000, 0x00010000, 0, 0x5F0F3CF5, 0x000B, EM, now, now,
                       xmin, ymin, xmax, ymax, 0, 8, 2, 0, 0)
    hhea = struct.pack(">IhhhHhhhhhhhhhhhH", 0x00010000, ASCENT, DESCENT, 0, adv_max, 0, 0, xmax, 1, 0, 0, 0, 0, 0, 0, 0, n)
    maxp = struct.pack(">IHHHHHHHHHHHHHH", 0x00010000, n, 400, 40, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0)

    # cmap, format 4: one segment per code point
    cps = [ord(c) for c in order[1:] if ord(c) <= 0xFFFF]
    segs = [(cp, cp, (order.index(chr(cp)) - cp) & 0xFFFF) for cp in sorted(cps)]
    segs.append((0xFFFF, 0xFFFF, 1))
    sc = len(segs)
    pow2 = 1
    while pow2 * 2 <= sc:
        pow2 *= 2
    search = pow2 * 2
    sub = struct.pack(">HHH", 4, 16 + sc * 8, 0)
    sub += struct.pack(">HHHH", sc * 2, search, (pow2.bit_length() - 1), sc * 2 - search)
    sub += b"".join(struct.pack(">H", s[1]) for s in segs) + b"\x00\x00"
    sub += b"".join(struct.pack(">H", s[0]) for s in segs)
    sub += b"".join(struct.pack(">H", s[2]) for s in segs)
    sub += b"".join(struct.pack(">H", 0) for _ in segs)
    cmap = struct.pack(">HH", 0, 1) + struct.pack(">HHI", 3, 1, 12) + sub

    # name
    def utf16(s):
        return s.encode("utf-16-be")

    names = [(1, FAMILY), (2, "Regular"), (3, FAMILY + " Regular"), (4, FAMILY), (5, "Version 1.0"), (6, "VelvetPixel-Regular")]
    records = b""
    strings = b""
    for nid, text in names:
        raw = utf16(text)
        records += struct.pack(">HHHHHH", 3, 1, 0x409, nid, len(raw), len(strings))
        strings += raw
    name = struct.pack(">HHH", 0, len(names), 6 + len(names) * 12) + records + strings

    post = struct.pack(">IIhhIIIII", 0x00030000, 0, -100, 50, 0, 0, 0, 0, 0)

    os2 = struct.pack(">HhHHHhhhhhhhhhhh", 1, 600, 400, 5, 0, 650, 600, 0, 140, 650, 600, 0, 480, 50, 258, 0)
    os2 += bytes(10)                                                   # panose
    os2 += struct.pack(">IIII", 1, 0, 0, 0)                            # unicode ranges
    os2 += b"VLVT"
    os2 += struct.pack(">HHHhhhHHII", 0x40, 32, 0x201D, ASCENT, DESCENT, 0, ASCENT, -DESCENT, 1, 0)

    tables = {b"OS/2": os2, b"cmap": cmap, b"glyf": glyf, b"head": head, b"hhea": hhea, b"hmtx": hmtx,
              b"loca": loca, b"maxp": maxp, b"name": name, b"post": post}
    tags = sorted(tables)
    nt = len(tags)
    pow2 = 1
    while pow2 * 2 <= nt:
        pow2 *= 2
    header = struct.pack(">IHHHH", 0x00010000, nt, pow2 * 16, pow2.bit_length() - 1, nt * 16 - pow2 * 16)
    off = 12 + nt * 16
    directory = b""
    body = b""
    head_at = None
    for t in tags:
        data = tables[t]
        pad = data + b"\x00" * (-len(data) % 4)
        directory += struct.pack(">4sIII", t, checksum(data), off + len(body), len(data))
        if t == b"head":
            head_at = off + len(body)
        body += pad
    font = bytearray(header + directory + body)
    adj = (0xB1B0AFBA - checksum(bytes(font))) & 0xFFFFFFFF
    font[head_at + 8:head_at + 12] = struct.pack(">I", adj)
    return bytes(font), n


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "fonts", "VelvetPixel.ttf")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    data, n = build()
    with open(out, "wb") as f:
        f.write(data)
    print(f"{out}: {n} glyphs, {len(data)} bytes")


if __name__ == "__main__":
    main()
