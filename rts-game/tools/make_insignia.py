#!/usr/bin/env python3
"""Draws each country's emblem (painted on its vehicles, aircraft, ships and structures) into
assets/ui/insignia/<id>.png. Every country has its own outline shape and a national animal or
symbol in its colours, so no two markings look alike even when tiny:

  USA bald eagle on a star        UK lion on a shield           Germany eagle on a gold diamond
  France rooster on a hexagon     Thailand white elephant on a Thai arch
  Korea tiger on an octagon       Japan rising sun with rays    Russia bear on a cut-corner badge
  China dragon on a triangle      Cuba crocodile on a pennant

Drawn 4x larger and downsampled. Usage: python3 tools/make_insignia.py"""
import math
import os
from PIL import Image, ImageDraw, ImageFilter

S = 128
SS = 4
N = S * SS
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "ui", "insignia")

WHITE = (255, 255, 255, 255)
BLACK = (14, 14, 16, 255)
GOLD = (236, 180, 40, 255)
DGOLD = (170, 120, 20, 255)


def P(pts, box=(0.0, 0.0, 1.0, 1.0)):
    """Scale unit-square points into a sub-box (x0, y0, x1, y1) of the canvas."""
    x0, y0, x1, y1 = box
    return [((x0 + (x1 - x0) * x) * N, (y0 + (y1 - y0) * y) * N) for x, y in pts]


def E(d, cx, cy, rx, ry, col, box=(0, 0, 1, 1)):
    (ax, ay), (bx, by) = P([(cx - rx, cy - ry), (cx + rx, cy + ry)], box)
    d.ellipse([ax, ay, bx, by], fill=col)


def star_pts(cx, cy, r, inner=0.42, n=5, rot=-90.0):
    out = []
    for i in range(n * 2):
        a = math.radians(rot + i * 180.0 / n)
        rr = r if i % 2 == 0 else r * inner
        out.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    return out


def regular(n, r=0.47, rot=-90.0, cx=0.5, cy=0.5):
    return [(cx + math.cos(math.radians(rot + i * 360.0 / n)) * r, cy + math.sin(math.radians(rot + i * 360.0 / n)) * r) for i in range(n)]


def shape(d, pts, fill, border, bw=0.045):
    """Outline shape: border colour, then the fill inset towards the centroid."""
    d.polygon(P(pts), fill=border)
    cx = sum(p[0] for p in pts) / len(pts)
    cy = sum(p[1] for p in pts) / len(pts)
    k = 1.0 - bw / 0.47
    d.polygon(P([(cx + (x - cx) * k, cy + (y - cy) * k) for x, y in pts]), fill=fill)


# ---------------------------------------------------------------- animals (unit-box coordinates)

def eagle_head(d, box):
    head = [(0.2, 0.95), (0.18, 0.55), (0.26, 0.32), (0.42, 0.2), (0.58, 0.2), (0.7, 0.28), (0.76, 0.36),
            (0.7, 0.5), (0.6, 0.58), (0.52, 0.66), (0.5, 0.95)]
    d.polygon(P(head, box), fill=WHITE)
    beak = [(0.7, 0.3), (0.86, 0.33), (0.95, 0.42), (0.9, 0.5), (0.82, 0.45), (0.74, 0.5), (0.66, 0.46)]
    d.polygon(P(beak, box), fill=GOLD)
    E(d, 0.6, 0.33, 0.035, 0.035, BLACK, box)
    d.polygon(P([(0.5, 0.3), (0.66, 0.27), (0.6, 0.31)], box), fill=(40, 40, 40, 255))   # brow


def lion_head(d, box):
    d.polygon(P(star_pts(0.5, 0.52, 0.48, 0.72, 13), box), fill=DGOLD)
    E(d, 0.5, 0.55, 0.26, 0.29, GOLD, box)
    for sx in (-1, 1):
        E(d, 0.5 + sx * 0.18, 0.3, 0.07, 0.07, GOLD, box)          # ears
        E(d, 0.5 + sx * 0.1, 0.48, 0.035, 0.03, BLACK, box)        # eyes
    E(d, 0.5, 0.68, 0.14, 0.1, (250, 225, 160, 255), box)          # muzzle
    d.polygon(P([(0.44, 0.6), (0.56, 0.6), (0.5, 0.67)], box), fill=BLACK)
    d.line(P([(0.5, 0.67), (0.5, 0.73), (0.44, 0.77)], box), fill=BLACK, width=2 * SS)
    d.line(P([(0.5, 0.73), (0.56, 0.77)], box), fill=BLACK, width=2 * SS)


def spread_eagle(d, box, col=BLACK, beak=(220, 40, 30, 255)):
    for sx in (-1, 1):
        wing = [(0.5, 0.32), (0.5 + sx * 0.18, 0.2), (0.5 + sx * 0.44, 0.1), (0.5 + sx * 0.46, 0.22),
                (0.5 + sx * 0.4, 0.3), (0.5 + sx * 0.44, 0.36), (0.5 + sx * 0.36, 0.43), (0.5 + sx * 0.4, 0.5),
                (0.5 + sx * 0.3, 0.55), (0.5 + sx * 0.32, 0.6), (0.5 + sx * 0.16, 0.6), (0.5, 0.56)]
        d.polygon(P(wing, box), fill=col)
        d.polygon(P([(0.5 + sx * 0.05, 0.7), (0.5 + sx * 0.14, 0.86), (0.5 + sx * 0.08, 0.88), (0.5 + sx * 0.02, 0.76)], box), fill=col)   # legs
    E(d, 0.5, 0.45, 0.11, 0.2, col, box)                          # body
    d.polygon(P([(0.4, 0.62), (0.6, 0.62), (0.66, 0.84), (0.5, 0.78), (0.34, 0.84)], box), fill=col)  # tail
    E(d, 0.5, 0.2, 0.075, 0.075, col, box)                        # head
    d.polygon(P([(0.56, 0.18), (0.66, 0.2), (0.58, 0.25)], box), fill=beak)


def rooster(d, box):
    tail = [(0.3, 0.55), (0.14, 0.2), (0.24, 0.24), (0.22, 0.08), (0.34, 0.2), (0.38, 0.06), (0.44, 0.3), (0.46, 0.55)]
    d.polygon(P(tail, box), fill=(237, 41, 57, 255))
    E(d, 0.5, 0.6, 0.24, 0.17, WHITE, box)                        # body
    d.polygon(P([(0.58, 0.55), (0.66, 0.3), (0.74, 0.28), (0.76, 0.46), (0.7, 0.6)], box), fill=WHITE)   # neck
    E(d, 0.72, 0.27, 0.08, 0.08, WHITE, box)                      # head
    d.polygon(P([(0.66, 0.2), (0.7, 0.12), (0.73, 0.18), (0.77, 0.11), (0.79, 0.2)], box), fill=(237, 41, 57, 255))   # comb
    d.polygon(P([(0.79, 0.25), (0.9, 0.29), (0.79, 0.32)], box), fill=GOLD)
    E(d, 0.77, 0.36, 0.03, 0.05, (237, 41, 57, 255), box)          # wattle
    E(d, 0.74, 0.25, 0.018, 0.018, BLACK, box)
    for x in (0.44, 0.56):
        d.line(P([(x, 0.74), (x, 0.92)], box), fill=GOLD, width=3 * SS)
        d.line(P([(x, 0.92), (x + 0.07, 0.94)], box), fill=GOLD, width=3 * SS)


def elephant(d, box):
    E(d, 0.52, 0.55, 0.3, 0.2, WHITE, box)                        # body
    for x in (0.3, 0.42, 0.6, 0.72):
        d.rectangle(P([(x - 0.05, 0.6), (x + 0.05, 0.9)], box), fill=WHITE)
    E(d, 0.24, 0.42, 0.14, 0.15, WHITE, box)                      # head
    trunk = [(0.14, 0.45), (0.06, 0.38), (0.03, 0.22), (0.08, 0.16), (0.12, 0.22), (0.1, 0.32), (0.18, 0.4)]
    d.polygon(P(trunk, box), fill=WHITE)
    E(d, 0.32, 0.44, 0.09, 0.12, (225, 225, 230, 255), box)        # ear
    d.polygon(P([(0.13, 0.5), (0.05, 0.56), (0.15, 0.55)], box), fill=(250, 240, 210, 255))   # tusk
    E(d, 0.2, 0.38, 0.018, 0.018, BLACK, box)
    d.polygon(P([(0.8, 0.5), (0.9, 0.62), (0.86, 0.63), (0.79, 0.56)], box), fill=WHITE)   # tail
    # Ceremonial blanket in Thai colours.
    d.polygon(P([(0.4, 0.38), (0.66, 0.38), (0.7, 0.6), (0.36, 0.6)], box), fill=(45, 42, 74, 255))
    d.polygon(P([(0.4, 0.55), (0.7, 0.55), (0.7, 0.6), (0.36, 0.6)], box), fill=(165, 25, 49, 255))


def tiger_head(d, box):
    orange, cream = (240, 130, 30, 255), (250, 238, 215, 255)
    for sx in (-1, 1):
        d.polygon(P([(0.5 + sx * 0.18, 0.28), (0.5 + sx * 0.36, 0.12), (0.5 + sx * 0.38, 0.36)], box), fill=orange)
    E(d, 0.5, 0.52, 0.36, 0.32, orange, box)
    E(d, 0.5, 0.68, 0.2, 0.15, cream, box)
    for sx in (-1, 1):
        for k in range(3):
            y = 0.36 + k * 0.1
            d.polygon(P([(0.5 + sx * 0.36, y), (0.5 + sx * 0.2, y + 0.03), (0.5 + sx * 0.34, y + 0.06)], box), fill=BLACK)
        E(d, 0.5 + sx * 0.13, 0.46, 0.05, 0.035, (255, 220, 60, 255), box)
        E(d, 0.5 + sx * 0.13, 0.46, 0.015, 0.03, BLACK, box)
    for k in range(3):
        d.polygon(P([(0.44 + k * 0.06, 0.22), (0.47 + k * 0.06, 0.34), (0.5 + k * 0.06, 0.22)], box), fill=BLACK)
    d.polygon(P([(0.44, 0.6), (0.56, 0.6), (0.5, 0.67)], box), fill=(40, 20, 20, 255))


def bear_head(d, box):
    brown, light = (120, 72, 40, 255), (200, 150, 105, 255)
    for sx in (-1, 1):
        E(d, 0.5 + sx * 0.27, 0.22, 0.11, 0.11, brown, box)
        E(d, 0.5 + sx * 0.27, 0.22, 0.05, 0.05, light, box)
    E(d, 0.5, 0.54, 0.36, 0.34, brown, box)
    E(d, 0.5, 0.66, 0.17, 0.13, light, box)
    E(d, 0.5, 0.6, 0.07, 0.05, BLACK, box)
    for sx in (-1, 1):
        E(d, 0.5 + sx * 0.14, 0.45, 0.035, 0.035, BLACK, box)
    d.line(P([(0.5, 0.64), (0.5, 0.7), (0.43, 0.74)], box), fill=BLACK, width=2 * SS)
    d.line(P([(0.5, 0.7), (0.57, 0.74)], box), fill=BLACK, width=2 * SS)


def dragon_head(d, box):
    gold, red = (255, 205, 0, 255), (200, 20, 30, 255)
    mane = [(0.18, 0.75), (0.08, 0.6), (0.16, 0.56), (0.06, 0.42), (0.18, 0.4), (0.12, 0.26), (0.26, 0.3), (0.28, 0.16), (0.38, 0.3)]
    d.polygon(P(mane + [(0.4, 0.75)], box), fill=(255, 140, 0, 255))
    head = [(0.24, 0.72), (0.3, 0.36), (0.44, 0.26), (0.62, 0.28), (0.8, 0.34), (0.95, 0.4), (0.92, 0.48), (0.7, 0.5),
            (0.88, 0.58), (0.84, 0.66), (0.62, 0.62), (0.48, 0.7), (0.4, 0.8)]
    d.polygon(P(head, box), fill=gold)
    d.polygon(P([(0.46, 0.28), (0.4, 0.08), (0.52, 0.27)], box), fill=gold)      # horns
    d.polygon(P([(0.56, 0.28), (0.56, 0.06), (0.62, 0.28)], box), fill=gold)
    d.polygon(P([(0.7, 0.5), (0.86, 0.52), (0.72, 0.55)], box), fill=red)        # mouth
    for x in (0.74, 0.8):
        d.polygon(P([(x, 0.5), (x + 0.02, 0.555), (x + 0.04, 0.5)], box), fill=WHITE)   # teeth
    E(d, 0.6, 0.37, 0.04, 0.03, red, box)
    E(d, 0.61, 0.37, 0.015, 0.02, BLACK, box)
    d.line(P([(0.9, 0.42), (0.98, 0.3), (0.92, 0.18)], box), fill=gold, width=2 * SS)   # whiskers
    d.line(P([(0.86, 0.6), (0.96, 0.72), (0.9, 0.86)], box), fill=gold, width=2 * SS)


def crocodile(d, box):
    green, dark = (70, 120, 50, 255), (40, 75, 30, 255)
    body = [(0.02, 0.5), (0.2, 0.44), (0.34, 0.4), (0.5, 0.4), (0.62, 0.42), (0.72, 0.4), (0.98, 0.44), (0.98, 0.5),
            (0.74, 0.54), (0.62, 0.6), (0.4, 0.62), (0.22, 0.58)]
    d.polygon(P(body, box), fill=green)
    d.polygon(P([(0.72, 0.47), (0.98, 0.47), (0.98, 0.5), (0.74, 0.52)], box), fill=dark)   # jaw line
    for x in range(6):
        cx = 0.24 + x * 0.07
        d.polygon(P([(cx, 0.42), (cx + 0.025, 0.36), (cx + 0.05, 0.42)], box), fill=dark)  # scutes
    for x in (0.3, 0.56):
        d.polygon(P([(x, 0.58), (x - 0.06, 0.7), (x + 0.02, 0.7), (x + 0.05, 0.6)], box), fill=green)
    E(d, 0.74, 0.41, 0.025, 0.025, (255, 220, 60, 255), box)
    for x in (0.82, 0.88, 0.94):
        d.polygon(P([(x, 0.47), (x + 0.012, 0.5), (x + 0.024, 0.47)], box), fill=WHITE)


# ---------------------------------------------------------------- emblems

def usa(d):
    shape(d, star_pts(0.5, 0.54, 0.5, 0.5), (0, 40, 104, 255), WHITE, 0.06)
    d.polygon(P(star_pts(0.5, 0.54, 0.38, 0.5)), fill=(200, 16, 46, 255))
    d.polygon(P(star_pts(0.5, 0.54, 0.34, 0.5)), fill=(0, 40, 104, 255))
    eagle_head(d, (0.27, 0.27, 0.73, 0.8))


def uk(d):
    shield = [(0.08, 0.06), (0.92, 0.06), (0.92, 0.5), (0.84, 0.72), (0.66, 0.88), (0.5, 0.96), (0.34, 0.88), (0.16, 0.72), (0.08, 0.5)]
    shape(d, shield, (190, 20, 40, 255), GOLD)
    lion_head(d, (0.18, 0.14, 0.82, 0.82))


def germany(d):
    shape(d, [(0.5, 0.02), (0.98, 0.5), (0.5, 0.98), (0.02, 0.5)], GOLD, BLACK, 0.05)
    spread_eagle(d, (0.18, 0.18, 0.82, 0.86))


def france(d):
    shape(d, regular(6, 0.48, 0.0), (0, 35, 149, 255), (237, 41, 57, 255), 0.06)
    rooster(d, (0.14, 0.12, 0.88, 0.88))


def thailand(d):
    arch = [(0.5, 0.0), (0.62, 0.16), (0.8, 0.3), (0.92, 0.5), (0.92, 0.96), (0.08, 0.96), (0.08, 0.5), (0.2, 0.3), (0.38, 0.16)]
    shape(d, arch, (165, 25, 49, 255), GOLD, 0.05)
    elephant(d, (0.14, 0.3, 0.86, 0.92))


def korea(d):
    shape(d, regular(8, 0.48, 22.5), WHITE, (0, 71, 160, 255), 0.06)
    d.polygon(P([(x, y) for x, y in regular(8, 0.4, 22.5)]), fill=(205, 46, 58, 255))
    d.polygon(P([(x, y) for x, y in regular(8, 0.36, 22.5)]), fill=WHITE)
    tiger_head(d, (0.16, 0.14, 0.84, 0.86))


def japan(d):
    red = (188, 0, 45, 255)
    rays = []
    for i in range(16):
        a0 = math.radians(i * 22.5 - 5.0)
        a1 = math.radians(i * 22.5 + 5.0)
        d.polygon(P([(0.5, 0.5), (0.5 + math.cos(a0) * 0.5, 0.5 + math.sin(a0) * 0.5), (0.5 + math.cos(a1) * 0.5, 0.5 + math.sin(a1) * 0.5)]), fill=red)
    E(d, 0.5, 0.5, 0.29, 0.29, WHITE)
    E(d, 0.5, 0.5, 0.24, 0.24, red)


def russia(d):
    c = 0.14
    badge = [(c, 0.04), (1 - c, 0.04), (0.96, c + 0.02), (0.96, 1 - c - 0.02), (1 - c, 0.96), (c, 0.96), (0.04, 1 - c - 0.02), (0.04, c + 0.02)]
    shape(d, badge, (213, 43, 30, 255), (0, 57, 166, 255), 0.06)
    bear_head(d, (0.14, 0.12, 0.86, 0.88))


def china(d):
    shape(d, [(0.5, 0.02), (0.98, 0.92), (0.02, 0.92)], (220, 20, 30, 255), (255, 205, 0, 255), 0.05)
    dragon_head(d, (0.22, 0.34, 0.8, 0.88))


def cuba(d):
    pennant = [(0.02, 0.12), (0.98, 0.5), (0.02, 0.88)]
    d.polygon(P(pennant), fill=WHITE)
    for i in range(5):
        y0, y1 = 0.12 + i * 0.152, 0.12 + (i + 1) * 0.152
        if i % 2 == 0:
            band = Image.new("L", (N, N), 0)
            ImageDraw.Draw(band).rectangle([0, y0 * N, N, y1 * N], fill=255)
            tri = Image.new("L", (N, N), 0)
            ImageDraw.Draw(tri).polygon(P([(0.05, 0.16), (0.9, 0.5), (0.05, 0.84)]), fill=255)
            from PIL import ImageChops
            d._image.paste((0, 42, 143, 255), (0, 0), ImageChops.multiply(band, tri))
    d.polygon(P([(0.05, 0.16), (0.42, 0.5), (0.05, 0.84)]), fill=(207, 20, 43, 255))
    d.polygon(P(star_pts(0.16, 0.5, 0.1)), fill=WHITE)
    crocodile(d, (0.22, 0.28, 0.86, 0.72))


DRAW = {"usa": usa, "uk": uk, "germany": germany, "france": france, "thailand": thailand,
        "korea": korea, "japan": japan, "russia": russia, "china": china, "cuba": cuba}


def make(fn):
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    fn(ImageDraw.Draw(img))
    # Dark outline so the emblem reads on any paint colour.
    a = img.getchannel("A")
    outline = Image.new("RGBA", (N, N), (16, 16, 18, 0))
    outline.putalpha(a.filter(ImageFilter.MaxFilter(11)).point(lambda v: 210 if v > 0 else 0))
    outline.alpha_composite(img)
    return outline.resize((S, S), Image.LANCZOS)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for k, fn in DRAW.items():
        make(fn).save(os.path.join(OUT, k + ".png"))
    print("insignia:", len(DRAW))
