#!/usr/bin/env python3
"""Draws the country flags used by the faction picker and the sidebar (assets/ui/flags/<id>.png).
Flags are drawn 4x larger and downsampled for clean edges, then given a thin dark border.

Usage: python3 tools/make_flags.py"""
import math
import os
from PIL import Image, ImageDraw

W, H = 150, 100          # 3:2 output
SS = 4
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "ui", "flags")

RED = (200, 16, 46)
WHITE = (255, 255, 255)
BLUE = (0, 40, 104)


def star(d, cx, cy, r, col, rot=-90.0):
    pts = []
    for i in range(10):
        a = math.radians(rot + i * 36.0)
        rr = r if i % 2 == 0 else r * 0.382
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    d.polygon(pts, fill=col)


def hstripes(d, w, h, cols, weights=None):
    weights = weights or [1] * len(cols)
    tot = sum(weights)
    y = 0.0
    for c, k in zip(cols, weights):
        y1 = y + h * k / tot
        d.rectangle([0, round(y), w, round(y1)], fill=c)
        y = y1


def vstripes(d, w, h, cols):
    for i, c in enumerate(cols):
        d.rectangle([round(w * i / len(cols)), 0, round(w * (i + 1) / len(cols)), h], fill=c)


def usa(d, w, h):
    hstripes(d, w, h, [RED if i % 2 == 0 else WHITE for i in range(13)])
    cw, ch = w * 0.4, h * 7 / 13
    d.rectangle([0, 0, cw, ch], fill=(10, 49, 97))
    for row in range(9):
        n = 6 if row % 2 == 0 else 5
        for k in range(n):
            x = cw * ((k * 2 + (1 if row % 2 == 0 else 2)) / 12.0)
            y = ch * ((row + 1) / 10.0)
            star(d, x, y, ch * 0.045, WHITE)


def uk(d, w, h):
    d.rectangle([0, 0, w, h], fill=(1, 33, 105))
    t = h / 30.0
    d.line([(0, 0), (w, h)], fill=WHITE, width=round(6 * t))
    d.line([(0, h), (w, 0)], fill=WHITE, width=round(6 * t))
    # Red saltire, offset ("counterchanged") like the real flag.
    o = 1.0 * t
    d.line([(0, -o), (w / 2, h / 2 - o)], fill=RED, width=round(2 * t))
    d.line([(w / 2, h / 2 + o), (w, h + o)], fill=RED, width=round(2 * t))
    d.line([(0, h + o), (w / 2, h / 2 + o)], fill=RED, width=round(2 * t))
    d.line([(w / 2, h / 2 - o), (w, -o)], fill=RED, width=round(2 * t))
    d.rectangle([w / 2 - 5 * t, 0, w / 2 + 5 * t, h], fill=WHITE)
    d.rectangle([0, h / 2 - 5 * t, w, h / 2 + 5 * t], fill=WHITE)
    d.rectangle([w / 2 - 3 * t, 0, w / 2 + 3 * t, h], fill=RED)
    d.rectangle([0, h / 2 - 3 * t, w, h / 2 + 3 * t], fill=RED)


def germany(d, w, h):
    hstripes(d, w, h, [(0, 0, 0), (221, 0, 0), (255, 206, 0)])


def france(d, w, h):
    vstripes(d, w, h, [(0, 35, 149), WHITE, (237, 41, 57)])


def thailand(d, w, h):
    hstripes(d, w, h, [(165, 25, 49), WHITE, (45, 42, 74), WHITE, (165, 25, 49)], [1, 1, 2, 1, 1])


def korea(d, w, h):
    d.rectangle([0, 0, w, h], fill=WHITE)
    cx, cy, r = w / 2, h / 2, h / 4
    ang = math.atan2(2, 3)  # the taegeuk axis follows the flag's diagonal
    ca, sa = math.cos(ang), math.sin(ang)
    red, blue = (205, 46, 58), (0, 71, 160)

    # Upper half red, lower half blue (rotated), then the two small lobes.
    def half(col, sign):
        pts = []
        for i in range(61):
            t = math.pi * i / 60
            x, y = math.cos(t) * r, -math.sin(t) * r * sign
            pts.append((cx + x * ca - y * sa, cy + x * sa + y * ca))
        d.polygon(pts, fill=col)
    half(red, 1)
    half(blue, -1)
    for sgn, col in ((-1, red), (1, blue)):
        x, y = sgn * r / 2, 0
        px, py = cx + x * ca - y * sa, cy + x * sa + y * ca
        d.ellipse([px - r / 2, py - r / 2, px + r / 2, py + r / 2], fill=col)
    # Four trigrams.
    bl, bw, gap = h / 6, h / 24, h / 48
    for k, pattern in enumerate([(1, 1, 1), (0, 1, 0), (1, 0, 1), (0, 0, 0)]):
        a = [math.pi + ang, -ang, math.pi - ang, ang][k]   # top-left, top-right, bottom-left, bottom-right
        dist = h * 0.39
        ox, oy = cx + math.cos(a) * dist, cy + math.sin(a) * dist
        nx, ny = math.cos(a), math.sin(a)
        tx, ty = -ny, nx
        for j, solid in enumerate(pattern):
            off = (j - 1) * (bw + gap)
            bx, by = ox + nx * off, oy + ny * off
            segs = [(-bl / 2, bl / 2)] if solid else [(-bl / 2, -gap / 2), (gap / 2, bl / 2)]
            for s0, s1 in segs:
                quad = [(bx + tx * s0 - nx * bw / 2, by + ty * s0 - ny * bw / 2), (bx + tx * s1 - nx * bw / 2, by + ty * s1 - ny * bw / 2),
                        (bx + tx * s1 + nx * bw / 2, by + ty * s1 + ny * bw / 2), (bx + tx * s0 + nx * bw / 2, by + ty * s0 + ny * bw / 2)]
                d.polygon(quad, fill=(0, 0, 0))


def japan(d, w, h):
    d.rectangle([0, 0, w, h], fill=WHITE)
    r = h * 0.3
    d.ellipse([w / 2 - r, h / 2 - r, w / 2 + r, h / 2 + r], fill=(188, 0, 45))


def russia(d, w, h):
    hstripes(d, w, h, [WHITE, (0, 57, 166), (213, 43, 30)])


def china(d, w, h):
    d.rectangle([0, 0, w, h], fill=(238, 28, 37))
    gold = (255, 255, 0)
    u = h / 20.0
    star(d, 5 * u, 5 * u, 3 * u, gold)
    for x, y in ((10, 2), (12, 4), (12, 7), (10, 9)):
        rot = math.degrees(math.atan2(5 - y, 5 - x)) + 180 - 90 + 18
        star(d, x * u, y * u, 1 * u, gold, rot)


def cuba(d, w, h):
    hstripes(d, w, h, [(0, 42, 143) if i % 2 == 0 else WHITE for i in range(5)])
    d.polygon([(0, 0), (h * 0.866, h / 2), (0, h)], fill=(207, 20, 43))
    star(d, h * 0.29, h / 2, h * 0.13, WHITE)


FLAGS = {"usa": usa, "uk": uk, "germany": germany, "france": france, "thailand": thailand,
         "korea": korea, "japan": japan, "russia": russia, "china": china, "cuba": cuba}


def make(fn):
    img = Image.new("RGB", (W * SS, H * SS), WHITE)
    fn(ImageDraw.Draw(img), W * SS, H * SS)
    img = img.resize((W, H), Image.LANCZOS)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, W - 1, H - 1], outline=(30, 30, 30), width=2)
    return img


def random_flag():
    """A '?' flag for the random choice."""
    img = Image.new("RGB", (W * SS, H * SS), (60, 64, 70))
    d = ImageDraw.Draw(img)
    for i in range(0, W * SS * 2, 60):
        d.line([(i, 0), (i - H * SS, H * SS)], fill=(72, 77, 84), width=24)
    cx, cy, s = W * SS / 2, H * SS / 2, H * SS / 100.0
    # Question mark from an arc, a stem and a dot.
    d.arc([cx - 18 * s, cy - 36 * s, cx + 18 * s, cy + 2 * s], 180, 90, fill=(240, 200, 80), width=round(9 * s))
    d.rectangle([cx - 4.5 * s, cy - 2 * s, cx + 4.5 * s, cy + 14 * s], fill=(240, 200, 80))
    d.ellipse([cx - 6 * s, cy + 20 * s, cx + 6 * s, cy + 32 * s], fill=(240, 200, 80))
    img = img.resize((W, H), Image.LANCZOS)
    ImageDraw.Draw(img).rectangle([0, 0, W - 1, H - 1], outline=(30, 30, 30), width=2)
    return img


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for k, fn in FLAGS.items():
        make(fn).save(os.path.join(OUT, k + ".png"))
    random_flag().save(os.path.join(OUT, "random.png"))
    print("flags:", len(FLAGS) + 1)
