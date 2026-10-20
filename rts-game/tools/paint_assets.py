#!/usr/bin/env python3
"""Generates the painted 2D art: seamless terrain materials, ore/gem clusters,
explosion/smoke/fire sprite sheets, craters, and metallic HUD textures.
All artwork is original and procedural. Output: assets/terrain, assets/ore, assets/fx, assets/ui."""
import json, math, os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
A = os.path.join(ROOT, "assets")
N = 1024
rng = np.random.default_rng(2026)

def out(sub, name):
    d = os.path.join(A, sub)
    os.makedirs(d, exist_ok=True)
    return os.path.join(d, name)

def pnoise(n, beta, seed):
    """Periodic fractal noise in [0,1] using a 1/f^beta spectrum."""
    r = np.random.default_rng(seed)
    w = r.standard_normal((n, n))
    f = np.fft.fft2(w)
    fx = np.fft.fftfreq(n)[None, :]
    fy = np.fft.fftfreq(n)[:, None]
    rad = np.sqrt(fx * fx + fy * fy)
    rad[0, 0] = 1.0
    f *= 1.0 / rad ** beta
    f[0, 0] = 0
    img = np.real(np.fft.ifft2(f))
    img -= img.min()
    return img / img.max()

def ramp(t, stops):
    """stops: list of (pos, (r,g,b)) sorted."""
    t = np.clip(t, 0, 1)
    out_ = np.zeros(t.shape + (3,), np.float32)
    for i in range(len(stops) - 1):
        p0, c0 = stops[i]
        p1, c1 = stops[i + 1]
        m = (t >= p0) & (t <= p1)
        k = ((t - p0) / max(p1 - p0, 1e-6))[..., None]
        out_ = np.where(m[..., None], np.array(c0) * (1 - k) + np.array(c1) * k, out_)
    return out_

class Canvas:
    """RGBA float canvas with wrap-around stamping (keeps textures seamless)."""
    def __init__(self, base):
        self.n = base.shape[0]
        self.pad = 48
        n2 = self.n + 2 * self.pad
        self.img = Image.new("RGBA", (n2, n2), (0, 0, 0, 0))
        self.draw = ImageDraw.Draw(self.img)
        self.base = base

    def result(self):
        layer = np.array(self.img).astype(np.float32) / 255.0
        p, n = self.pad, self.n
        acc = np.zeros((n, n, 4), np.float32)
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                y0, x0 = p + dy * n, p + dx * n
                ys = slice(max(y0, 0), min(y0 + n, n + 2 * p))
                xs = slice(max(x0, 0), min(x0 + n, n + 2 * p))
                sub = layer[ys, xs]
                ty = ys.start - y0
                tx = xs.start - x0
                region = acc[ty:ty + sub.shape[0], tx:tx + sub.shape[1]]
                a = sub[..., 3:4]
                region[..., :3] = region[..., :3] * (1 - a) + sub[..., :3] * a
                region[..., 3:4] = region[..., 3:4] + a * (1 - region[..., 3:4])
        a = acc[..., 3:4]
        return self.base * (1 - a) + acc[..., :3] * a

def c8(col, a=255):
    return tuple(int(max(0, min(1, v)) * 255) for v in col) + (a,)

def jitter(col, amt):
    return tuple(np.clip(np.array(col) * (1 + rng.uniform(-amt, amt)), 0, 1))

def pebbles(cv, count, rmin, rmax, cols, shadow=0.45, light=0.25):
    for _ in range(count):
        x, y = rng.uniform(0, cv.n) + cv.pad, rng.uniform(0, cv.n) + cv.pad
        r = rng.uniform(rmin, rmax)
        ry = r * rng.uniform(0.6, 1.0)
        col = np.array(cols[rng.integers(len(cols))]) * rng.uniform(0.85, 1.1)
        sh = max(1.2, r * 0.25)
        cv.draw.ellipse([x - r + sh, y - ry + sh * 1.3, x + r + sh, y + ry + sh * 1.3], fill=c8(col * shadow * 0.6, 150))
        steps = 5 if r > 4 else 2
        for k in range(steps):
            f = k / max(steps - 1, 1)
            rr = r * (1 - 0.55 * f)
            ryy = ry * (1 - 0.55 * f)
            ox, oy = -r * 0.28 * f, -ry * 0.32 * f
            tone = 0.62 + 0.55 * f
            cv.draw.ellipse([x + ox - rr, y + oy - ryy, x + ox + rr, y + oy + ryy], fill=c8(np.minimum(col * tone, 1)))
        if r > 4:
            cv.draw.arc([x - r, y - ry, x + r, y + ry], 20, 160, fill=c8(col * 0.45, 200), width=1)
        cv.draw.ellipse([x - r * 0.5, y - ry * 0.7, x - r * 0.1, y - ry * 0.35], fill=c8(np.minimum(col * (1 + light * 2.4), 1), 150))

def strokes(cv, count, length, cols, width=1, angle=(-0.5, 0.5), alpha=220):
    for _ in range(count):
        x, y = rng.uniform(0, cv.n) + cv.pad, rng.uniform(0, cv.n) + cv.pad
        a = rng.uniform(*angle) - math.pi / 2
        l = rng.uniform(*length)
        col = jitter(cols[rng.integers(len(cols))], 0.12)
        cv.draw.line([x, y, x + math.cos(a) * l, y + math.sin(a) * l], fill=c8(col, alpha), width=width)

def save_tex(name, rgb):
    Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8), "RGB").save(out("terrain", name + ".png"), optimize=True)
    print("terrain", name)

# ---------------------------------------------------------------- terrain materials

def grass(seed, dry=False):
    n1 = pnoise(N, 2.6, seed)
    n2 = pnoise(N, 1.6, seed + 1)
    n3 = pnoise(N, 0.9, seed + 2)
    if dry:
        stops = [(0, (0.36, 0.38, 0.17)), (0.45, (0.5, 0.5, 0.24)), (0.75, (0.6, 0.57, 0.3)), (1, (0.66, 0.62, 0.36))]
    else:
        stops = [(0, (0.17, 0.29, 0.1)), (0.4, (0.27, 0.41, 0.15)), (0.7, (0.36, 0.5, 0.19)), (1, (0.46, 0.56, 0.24))]
    base = ramp(n1 * 0.55 + n2 * 0.35 + n3 * 0.1, stops)
    base *= (0.9 + 0.2 * n3)[..., None]
    cv = Canvas(base)
    blade = [(0.2, 0.33, 0.11), (0.3, 0.45, 0.16), (0.42, 0.55, 0.22), (0.5, 0.6, 0.25)] if not dry else \
        [(0.42, 0.43, 0.2), (0.55, 0.53, 0.27), (0.63, 0.6, 0.33), (0.35, 0.37, 0.18)]
    strokes(cv, 60000, (2, 6), blade, 1)
    strokes(cv, 9000, (4, 9), blade[:2], 2, alpha=150)
    if not dry:
        for _ in range(900):
            x, y = rng.uniform(0, N) + cv.pad, rng.uniform(0, N) + cv.pad
            col = [(0.95, 0.92, 0.75), (0.95, 0.85, 0.3), (0.8, 0.55, 0.85)][rng.integers(3)]
            cv.draw.ellipse([x - 1.2, y - 1.2, x + 1.2, y + 1.2], fill=c8(col, 230))
    pebbles(cv, 250, 1.5, 3.5, [(0.5, 0.47, 0.4), (0.6, 0.57, 0.5)])
    return cv.result()

def dirt(seed):
    n1, n2, n3 = pnoise(N, 2.4, seed), pnoise(N, 1.4, seed + 1), pnoise(N, 0.8, seed + 2)
    base = ramp(n1 * 0.6 + n2 * 0.4, [(0, (0.3, 0.22, 0.13)), (0.5, (0.45, 0.34, 0.21)), (1, (0.57, 0.45, 0.29))])
    base *= (0.88 + 0.24 * n3)[..., None]
    cracks = np.abs(pnoise(N, 2.0, seed + 5) - 0.5) < 0.008
    base[cracks] *= 0.7
    cv = Canvas(base)
    pebbles(cv, 4500, 1.2, 3.2, [(0.5, 0.4, 0.27), (0.6, 0.52, 0.38), (0.4, 0.33, 0.24)])
    pebbles(cv, 500, 3, 6, [(0.55, 0.5, 0.42), (0.45, 0.4, 0.33)])
    strokes(cv, 3000, (2, 5), [(0.32, 0.4, 0.15), (0.4, 0.45, 0.2)], 1, alpha=120)
    return cv.result()

def sand(seed):
    n1, n2 = pnoise(N, 2.5, seed), pnoise(N, 1.2, seed + 1)
    yy = np.arange(N)[:, None] * np.ones((1, N))
    xx = np.ones((N, 1)) * np.arange(N)[None, :]
    rip = 0.5 + 0.5 * np.sin((xx + yy * 0.6) * 2 * math.pi / 32 + n1 * 14)
    base = ramp(n1 * 0.7 + n2 * 0.3, [(0, (0.62, 0.53, 0.35)), (0.6, (0.76, 0.67, 0.47)), (1, (0.84, 0.76, 0.56))])
    base *= (0.97 + 0.03 * rip)[..., None]
    cv = Canvas(base)
    pebbles(cv, 1500, 0.8, 2.0, [(0.6, 0.52, 0.38), (0.85, 0.8, 0.68)], shadow=0.6)
    return cv.result()

def shore(seed):
    s = sand(seed)
    n = pnoise(N, 2.2, seed + 9)
    wet = np.clip((n - 0.3) * 2.2, 0, 1)[..., None]
    s = s * (1 - 0.35 * wet) * np.array([0.92, 0.95, 1.0])
    cv = Canvas(s)
    pebbles(cv, 1200, 1.5, 4, [(0.5, 0.48, 0.44), (0.62, 0.6, 0.55)])
    return cv.result()

def road(seed):
    n1, n2, n3 = pnoise(N, 2.3, seed), pnoise(N, 1.3, seed + 1), pnoise(N, 0.7, seed + 2)
    base = ramp(n1 * 0.6 + n2 * 0.4, [(0, (0.27, 0.26, 0.24)), (0.5, (0.38, 0.36, 0.33)), (1, (0.49, 0.46, 0.41))])
    base *= (0.9 + 0.2 * n3)[..., None]
    patch = pnoise(N, 2.8, seed + 7) > 0.68
    base[patch] = base[patch] * 0.72 + np.array([0.04, 0.04, 0.045])
    cv = Canvas(base)
    pebbles(cv, 9000, 0.8, 2.2, [(0.45, 0.43, 0.4), (0.55, 0.52, 0.48), (0.35, 0.33, 0.3)], shadow=0.5)
    return cv.result()

def rock(seed, dark=False):
    n1, n2 = pnoise(N, 2.2, seed), pnoise(N, 1.2, seed + 1)
    if dark:
        stops = [(0, (0.18, 0.16, 0.14)), (0.5, (0.32, 0.29, 0.26)), (1, (0.45, 0.42, 0.38))]
    else:
        stops = [(0, (0.33, 0.3, 0.26)), (0.5, (0.46, 0.43, 0.38)), (1, (0.58, 0.55, 0.49))]
    base = ramp(n1 * 0.6 + n2 * 0.4, stops)
    cv = Canvas(base)
    cols = [(0.5, 0.47, 0.42), (0.58, 0.55, 0.5), (0.42, 0.39, 0.35)] if not dark else [(0.36, 0.33, 0.3), (0.45, 0.42, 0.38), (0.28, 0.26, 0.24)]
    pebbles(cv, 700 if not dark else 400, 6, 18 if not dark else 26, cols, shadow=0.35, light=0.3)
    pebbles(cv, 3000, 1.5, 5, cols, shadow=0.4)
    res = cv.result()
    if dark:
        cr = np.abs(pnoise(N, 1.8, seed + 4) - 0.5) < 0.012
        res[cr] *= 0.45
    return res

def forest(seed):
    g = grass(seed) * np.array([0.72, 0.78, 0.68])
    cv = Canvas(g)
    leaf = [(0.35, 0.26, 0.12), (0.45, 0.35, 0.15), (0.25, 0.3, 0.12), (0.5, 0.42, 0.2)]
    for _ in range(14000):
        x, y = rng.uniform(0, N) + cv.pad, rng.uniform(0, N) + cv.pad
        r = rng.uniform(1.2, 3.0)
        cv.draw.ellipse([x - r, y - r * 0.6, x + r, y + r * 0.6], fill=c8(jitter(leaf[rng.integers(4)], 0.15), 200))
    return cv.result()

def planks(seed):
    n1 = pnoise(N, 1.0, seed)
    base = np.zeros((N, N, 3), np.float32)
    plank_h = 32
    for i in range(N // plank_h):
        tone = rng.uniform(0.85, 1.1)
        base[i * plank_h:(i + 1) * plank_h] = np.array([0.46, 0.33, 0.2]) * tone
    grain = 0.9 + 0.2 * np.sin(np.arange(N)[None, :] * 0.08 + n1 * 20)
    base *= grain[..., None]
    for i in range(N // plank_h):
        base[i * plank_h:i * plank_h + 2] *= 0.45
    return base

def waterbed(seed):
    n1 = pnoise(N, 2.0, seed)
    return ramp(n1, [(0, (0.16, 0.18, 0.15)), (1, (0.3, 0.3, 0.24))])

# ---------------------------------------------------------------- ore / gems (isometric, 128x64 diamond)

def ore_sheet():
    W, H = 128, 96
    sheet = Image.new("RGBA", (W * 4, H * 8), (0, 0, 0, 0))
    for kind in range(2):
        for stage in range(4):
            for v in range(4):
                im = Image.new("RGBA", (W * 2, H * 2), (0, 0, 0, 0))
                d = ImageDraw.Draw(im)
                r2 = np.random.default_rng(kind * 100 + stage * 10 + v)
                count = [6, 11, 17, 24][stage]
                pts = []
                for _ in range(count):
                    while True:
                        u, w = r2.uniform(-1, 1), r2.uniform(-1, 1)
                        if abs(u) + abs(w) < 0.9:
                            break
                    pts.append((W + u * W * 0.85, H * 1.15 + w * H * 0.42))
                pts.sort(key=lambda p: p[1])
                for (x, y) in pts:
                    s = r2.uniform(4.5, 7.5) * (1 + stage * 0.12) * 2
                    if kind == 0:
                        base = np.array([0.76, 0.56, 0.17]) * r2.uniform(0.8, 1.08)
                        d.ellipse([x - s + 3, y - s * 0.55 + 4, x + s + 3, y + s * 0.55 + 4], fill=c8((0, 0, 0), 90))
                        pts_poly = []
                        k = r2.integers(6, 9)
                        for j in range(k):
                            a = 2 * math.pi * j / k
                            rr = s * r2.uniform(0.75, 1.05)
                            pts_poly.append((x + math.cos(a) * rr, y + math.sin(a) * rr * 0.62 - s * 0.25))
                        d.polygon(pts_poly, fill=c8(base * 0.55))
                        inner = [(x + (px - x) * 0.82, y + (py - y) * 0.8 - s * 0.08) for px, py in pts_poly]
                        d.polygon(inner, fill=c8(base))
                        d.ellipse([x - s * 0.55, y - s * 0.75, x + s * 0.05, y - s * 0.35], fill=c8(np.minimum(base * 1.45, 1), 220))
                        d.ellipse([x - s * 0.35, y - s * 0.68, x - s * 0.15, y - s * 0.52], fill=c8((1, 0.97, 0.85), 240))
                    else:
                        base = np.array([0.3, 0.62, 0.95]) * r2.uniform(0.85, 1.1)
                        d.ellipse([x - s + 3, y - s * 0.4 + 4, x + s + 3, y + s * 0.4 + 4], fill=c8((0, 0, 0), 90))
                        hgt = s * r2.uniform(1.2, 2.0)
                        lean = r2.uniform(-0.4, 0.4) * s
                        left = [(x - s * 0.5, y), (x + lean - s * 0.15, y - hgt), (x + lean, y - hgt * 1.15), (x, y + s * 0.15)]
                        right = [(x, y + s * 0.15), (x + lean, y - hgt * 1.15), (x + lean + s * 0.15, y - hgt), (x + s * 0.5, y)]
                        d.polygon(left, fill=c8(base * 1.25))
                        d.polygon(right, fill=c8(base * 0.7))
                        d.line([(x + lean, y - hgt * 1.15), (x, y + s * 0.15)], fill=c8((0.85, 0.95, 1), 200), width=2)
                im = im.resize((W, H), Image.LANCZOS)
                sheet.paste(im, (v * W, (kind * 4 + stage) * H), im)
    sheet.save(out("ore", "ore.png"), optimize=True)
    json.dump({"fw": W, "fh": H, "ax": 64, "ay": 64, "cols": 4, "rows": 8, "count": 32}, open(out("ore", "ore.json"), "w"))
    print("ore sheet")

# ---------------------------------------------------------------- effects

def soft_disc(arr, cx, cy, r, col, alpha, softness=0.45):
    h, w, _ = arr.shape
    x0, x1 = int(max(cx - r - 2, 0)), int(min(cx + r + 2, w))
    y0, y1 = int(max(cy - r - 2, 0)), int(min(cy + r + 2, h))
    if x1 <= x0 or y1 <= y0:
        return
    yy, xx = np.mgrid[y0:y1, x0:x1]
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / max(r, 0.5)
    a = np.clip((1 - d) / softness, 0, 1) * alpha
    sub = arr[y0:y1, x0:x1]
    a3 = a[..., None]
    sub[..., :3] = sub[..., :3] * (1 - a3) + np.array(col) * a3
    sub[..., 3] = sub[..., 3] + a * (1 - sub[..., 3])

def save_sheet(name, frames, extra=None):
    fh, fw = frames[0].shape[:2]
    cols = min(len(frames), 8)
    rows = math.ceil(len(frames) / cols)
    sheet = np.zeros((rows * fh, cols * fw, 4), np.float32)
    for i, f in enumerate(frames):
        sheet[(i // cols) * fh:(i // cols + 1) * fh, (i % cols) * fw:(i % cols + 1) * fw] = f
    Image.fromarray((np.clip(sheet, 0, 1) * 255).astype(np.uint8), "RGBA").save(out("fx", name + ".png"), optimize=True)
    meta = {"fw": fw, "fh": fh, "ax": fw // 2, "ay": int(fh * 0.7), "cols": cols, "rows": rows, "count": len(frames)}
    if extra:
        meta.update(extra)
    json.dump(meta, open(out("fx", name + ".json"), "w"))
    print("fx", name)

def explosion(name, size, nframes, seed):
    r2 = np.random.default_rng(seed)
    blobs = []
    for _ in range(26):
        a = r2.uniform(0, 2 * math.pi)
        dist = r2.uniform(0, 0.32)
        blobs.append((math.cos(a) * dist, math.sin(a) * dist * 0.6 - r2.uniform(0, 0.12), r2.uniform(0.12, 0.26), r2.uniform(0.6, 1.4)))
    sparks = [(r2.uniform(0, 2 * math.pi), r2.uniform(0.6, 1.0)) for _ in range(14)]
    billow = np.tile(pnoise(256, 1.7, seed + 300), (2, 2))[:size + 64, :size + 64]
    frames = []
    for f in range(nframes):
        t = f / (nframes - 1)
        arr = np.zeros((size, size, 4), np.float32)
        cx, cy = size * 0.5, size * 0.7
        # Ground dust ring.
        for k in range(18):
            a = 2 * math.pi * k / 18
            rr = size * 0.42 * min(1, t * 2.2)
            soft_disc(arr, cx + math.cos(a) * rr, cy + math.sin(a) * rr * 0.45, size * 0.07 * (1 - t * 0.5), (0.55, 0.47, 0.36), 0.35 * (1 - t))
        rise = t * size * 0.28
        for (bx, by, br, sp) in blobs:
            grow = 0.4 + 1.2 * min(1, t * 2.5) * sp
            px = cx + bx * size * grow
            py = cy + by * size * grow - rise * sp
            r = br * size * (0.5 + 0.7 * min(1, t * 3)) * (1 - 0.25 * t)
            heat = max(0.0, 1 - t * 2.0 - sp * 0.25 + (0.35 - math.hypot(bx, by)) * 0.8)
            smoke_c = np.array([0.16, 0.15, 0.14]) * (0.8 + 0.5 * sp)
            fire_c = np.array([1.0, 0.85, 0.45]) * heat + np.array([0.95, 0.42, 0.1]) * (1 - heat)
            col = fire_c * min(1, heat * 2.2) + smoke_c * (1 - min(1, heat * 2.2))
            alpha = (1 - t ** 1.6) * 0.95
            soft_disc(arr, px, py, r, col, alpha)
        if t < 0.25:
            soft_disc(arr, cx, cy - size * 0.05, size * 0.22 * (1 - t * 3), (1, 1, 0.85), 0.9 * (1 - t * 4))
        for (a, sp) in sparks:
            if t < 0.6:
                d = size * 0.45 * t * sp * 1.6
                x = cx + math.cos(a) * d
                y = cy + math.sin(a) * d * 0.6 - size * 0.25 * math.sin(t * math.pi) * sp
                soft_disc(arr, x, y, size * 0.015 + 1, (1, 0.8, 0.4), 1 - t / 0.6, 0.8)
        nz = billow[(f * 37) % 64:(f * 37) % 64 + size, (f * 53) % 64:(f * 53) % 64 + size]
        arr[..., 3] *= np.clip((nz - 0.25) * 2.2 + arr[..., 3] * 0.6, 0, 1)
        arr[..., :3] *= (0.72 + 0.56 * nz)[..., None]
        frames.append(arr)
    save_sheet(name, frames)

def smoke_puff(name, size, nframes, dark):
    frames = []
    r2 = np.random.default_rng(7 if dark else 8)
    blobs = [(r2.uniform(-0.15, 0.15), r2.uniform(-0.1, 0.1), r2.uniform(0.15, 0.28)) for _ in range(7)]
    for f in range(nframes):
        t = f / (nframes - 1)
        arr = np.zeros((size, size, 4), np.float32)
        for (bx, by, br) in blobs:
            col = (0.18, 0.17, 0.16) if dark else (0.85, 0.85, 0.86)
            soft_disc(arr, size * (0.5 + bx * (1 + t)), size * (0.6 + by - t * 0.25), size * br * (0.6 + t * 0.7), col, 0.55 * (1 - t) ** 1.2, 0.8)
        frames.append(arr)
    save_sheet(name, frames)

def fire_loop(name, size, nframes):
    frames = []
    r2 = np.random.default_rng(11)
    tongues = [(r2.uniform(-0.25, 0.25), r2.uniform(0, 1), r2.uniform(0.6, 1.2)) for _ in range(9)]
    for f in range(nframes):
        t = f / nframes
        arr = np.zeros((size, size, 4), np.float32)
        for (bx, ph, sp) in tongues:
            p = (t * sp + ph) % 1.0
            x = size * (0.5 + bx * (1 - p * 0.5))
            y = size * (0.82 - p * 0.55)
            r = size * 0.14 * (1 - p * 0.7)
            col = np.array([1, 0.9, 0.5]) * (1 - p) + np.array([0.9, 0.3, 0.05]) * p
            soft_disc(arr, x, y, r, col, 0.9 * (1 - p), 0.7)
        frames.append(arr)
    save_sheet(name, frames)

def muzzle(name, size, nframes):
    frames = []
    for f in range(nframes):
        t = f / max(nframes - 1, 1)
        arr = np.zeros((size, size, 4), np.float32)
        c = size / 2
        for k in range(5):
            soft_disc(arr, c + k * size * 0.07, c, size * (0.22 - k * 0.035) * (1 - t * 0.6), (1, 0.85 - k * 0.08, 0.45), 1 - t, 0.6)
        soft_disc(arr, c, c, size * 0.12 * (1 - t), (1, 1, 0.9), 1 - t, 0.5)
        frames.append(arr)
    save_sheet(name, frames)

def craters():
    frames = []
    for v in range(4):
        r2 = np.random.default_rng(40 + v)
        arr = np.zeros((96, 160, 4), np.float32)
        for k in range(30):
            a = r2.uniform(0, 2 * math.pi)
            d = r2.uniform(0, 0.8)
            soft_disc(arr, 80 + math.cos(a) * d * 60, 48 + math.sin(a) * d * 30, r2.uniform(8, 18), (0.12, 0.1, 0.08), 0.35, 0.9)
        soft_disc(arr, 80, 48, 26, (0.08, 0.07, 0.06), 0.6, 0.7)
        arr[..., :3] *= 1.0
        # squash to isometric
        img = Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8), "RGBA")
        frames.append(np.array(img).astype(np.float32) / 255)
    save_sheet("crater", frames)

def projectiles():
    arr = np.zeros((32, 64, 4), np.float32)
    for k in range(10):
        soft_disc(arr, 50 - k * 3.5, 16, 5 - k * 0.35, (1, 0.85 - k * 0.04, 0.5 - k * 0.04), 1 - k * 0.09, 0.6)
    save_sheet("shell", [arr])
    arr = np.zeros((32, 64, 4), np.float32)
    for k in range(6):
        soft_disc(arr, 22 - k * 3, 16, 5 + k * 0.4, (1, 0.6, 0.2), 0.9 - k * 0.13, 0.6)
    img = Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8), "RGBA")
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([24, 13, 56, 19], radius=3, fill=(205, 205, 195, 255), outline=(60, 60, 60, 255))
    d.polygon([(56, 13), (62, 16), (56, 19)], fill=(170, 60, 40, 255))
    d.rectangle([26, 11, 30, 21], fill=(90, 90, 85, 255))
    save_sheet("rocket", [np.array(img).astype(np.float32) / 255])

# ---------------------------------------------------------------- HUD

def metal_panel(name, w, h, tint, rivets=True):
    n1 = pnoise(256, 1.0, 5)[:h % 256 or 256, :w % 256 or 256]
    base = np.zeros((h, w, 3), np.float32) + np.array(tint)
    nn = np.tile(pnoise(256, 1.2, 9), (h // 256 + 1, w // 256 + 1))[:h, :w]
    base *= (0.9 + 0.2 * nn)[..., None]
    brushed = np.tile(rng.uniform(0.95, 1.05, (1, w)), (h, 1))
    base *= brushed[..., None]
    img = Image.fromarray((np.clip(base, 0, 1) * 255).astype(np.uint8))
    d = ImageDraw.Draw(img)
    hi = tuple(int(min(255, v * 255 * 1.6)) for v in tint)
    lo = tuple(int(v * 255 * 0.35) for v in tint)
    for i in range(3):
        d.line([(i, i), (w - 1 - i, i)], fill=hi)
        d.line([(i, i), (i, h - 1 - i)], fill=hi)
        d.line([(i, h - 1 - i), (w - 1 - i, h - 1 - i)], fill=lo)
        d.line([(w - 1 - i, i), (w - 1 - i, h - 1 - i)], fill=lo)
    if rivets:
        for (x, y) in [(8, 8), (w - 9, 8), (8, h - 9), (w - 9, h - 9)]:
            d.ellipse([x - 3, y - 3, x + 3, y + 3], fill=lo)
            d.ellipse([x - 2, y - 3, x + 1, y], fill=hi)
    img.save(out("ui", name + ".png"), optimize=True)
    print("ui", name)

def emblem(name, faction, size=128):
    img = Image.new("RGBA", (size * 2, size * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = size
    if faction == "coalition":
        d.ellipse([c - 100, c - 100, c + 100, c + 100], fill=(25, 40, 70, 255), outline=(200, 210, 225, 255), width=10)
        for side in (-1, 1):
            wing = [(c, c - 10), (c + side * 120, c - 40), (c + side * 110, c - 10), (c + side * 125, c + 5), (c + side * 100, c + 20), (c + side * 110, c + 40), (c, c + 30)]
            d.polygon(wing, fill=(200, 210, 225, 255))
        pts = []
        for i in range(10):
            a = -math.pi / 2 + i * math.pi / 5
            rr = 62 if i % 2 == 0 else 26
            pts.append((c + math.cos(a) * rr, c + math.sin(a) * rr))
        d.polygon(pts, fill=(80, 140, 230, 255), outline=(230, 240, 255, 255))
    else:
        pts = [(c, c - 110), (c + 110, c), (c, c + 110), (c - 110, c)]
        d.polygon(pts, fill=(60, 15, 12, 255), outline=(220, 180, 120, 255))
        for k in range(12):
            a = 2 * math.pi * k / 12
            d.rectangle([c + math.cos(a) * 58 - 9, c + math.sin(a) * 58 - 9, c + math.cos(a) * 58 + 9, c + math.sin(a) * 58 + 9], fill=(200, 50, 35, 255))
        d.ellipse([c - 58, c - 58, c + 58, c + 58], fill=(200, 50, 35, 255))
        d.ellipse([c - 30, c - 30, c + 30, c + 30], fill=(60, 15, 12, 255))
        d.polygon([(c, c - 26), (c + 20, c + 16), (c - 20, c + 16)], fill=(235, 200, 130, 255))
    img = img.resize((size, size), Image.LANCZOS)
    img.save(out("ui", name + ".png"), optimize=True)
    print("ui", name)

def main():
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "ore":
        ore_sheet()
        save_tex("sand", sand(31))
        save_tex("shore", shore(41))
        return
    save_tex("grass", grass(1))
    save_tex("grass_dry", grass(11, dry=True))
    save_tex("dirt", dirt(21))
    save_tex("sand", sand(31))
    save_tex("shore", shore(41))
    save_tex("road", road(51))
    save_tex("rock", rock(61))
    save_tex("cliff", rock(71, dark=True))
    save_tex("forest", forest(81))
    save_tex("bridge", planks(91))
    save_tex("waterbed", waterbed(101))
    ore_sheet()
    explosion("explosion_big", 256, 18, 1)
    explosion("explosion", 192, 16, 2)
    explosion("explosion_small", 112, 12, 3)
    smoke_puff("smoke_dark", 96, 12, True)
    smoke_puff("smoke_light", 96, 12, False)
    fire_loop("fire", 96, 10)
    muzzle("muzzle", 48, 4)
    craters()
    projectiles()
    metal_panel("panel_coalition", 320, 1080, (0.2, 0.24, 0.29))
    metal_panel("panel_dominion", 320, 1080, (0.27, 0.2, 0.18))
    metal_panel("plate_coalition", 300, 64, (0.24, 0.29, 0.36))
    metal_panel("plate_dominion", 300, 64, (0.34, 0.22, 0.19))
    metal_panel("button", 96, 84, (0.16, 0.18, 0.2), rivets=False)
    emblem("emblem_coalition", "coalition")
    emblem("emblem_dominion", "dominion")

if __name__ == "__main__":
    main()
