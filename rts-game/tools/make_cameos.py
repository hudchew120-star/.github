#!/usr/bin/env python3
"""Builds sidebar cameo icons (illustrated build buttons) from the baked sprites:
picks a representative frame, applies the faction colour, and frames it on a metal plate."""
import json, math, os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SP = os.path.join(ROOT, "assets", "sprites")
OUT = os.path.join(ROOT, "assets", "ui", "cameos")
W, H = 192, 152
FACTION_COL = {"coalition": (0.25, 0.48, 0.85), "dominion": (0.78, 0.2, 0.15)}

def load_frame(name, i, team):
    meta = json.load(open(os.path.join(SP, name + ".json")))
    im = np.array(Image.open(os.path.join(SP, name + ".png")).convert("RGBA")).astype(np.float32) / 255
    fw, fh, cols = meta["fw"], meta["fh"], meta["cols"]
    x, y = (i % cols) * fw, (i // cols) * fh
    f = im[y:y + fh, x:x + fw].copy()
    if meta.get("mask"):
        k = (np.array(Image.open(os.path.join(SP, name + "_mask.png"))).astype(np.float32) / 255)[y:y + fh, x:x + fw][..., None]
        lum = (f[..., :3] @ np.array([.299, .587, .114]))[..., None]
        shade = lum / 0.62
        tc = np.array(team) * 0.82
        col = np.where(shade < 1, tc * shade, tc + (1 - tc) * np.clip(shade - 1, 0, 1) * 0.6)
        f[..., :3] = f[..., :3] * (1 - k) + np.clip(col, 0, 1) * k
    return meta, f

def over(dst, src, x, y):
    h, w = src.shape[:2]
    x0, y0 = max(x, 0), max(y, 0)
    x1, y1 = min(x + w, dst.shape[1]), min(y + h, dst.shape[0])
    if x1 <= x0 or y1 <= y0:
        return
    s = src[y0 - y:y1 - y, x0 - x:x1 - x]
    a = s[..., 3:4]
    d = dst[y0:y1, x0:x1]
    d[..., :3] = d[..., :3] * (1 - a) + s[..., :3] * a
    d[..., 3:4] = d[..., 3:4] + a * (1 - d[..., 3:4])

def compose(name, i, team, turret=None):
    meta, f = load_frame(name, i, team)
    canvas = np.zeros_like(f)
    over(canvas, f, 0, 0)
    if turret is not None:
        tmeta, t = load_frame(turret[0], turret[1], team)
        over(canvas, t, int(turret[2]), int(turret[3]))
    # Drop the soft ground shadow so the subject reads clearly.
    a = canvas[..., 3]
    canvas[..., 3] = np.where(a < 0.45, a * 0.4, a)
    ys, xs = np.where(canvas[..., 3] > 0.3)
    crop = canvas[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    img = Image.fromarray((np.clip(crop, 0, 1) * 255).astype(np.uint8), "RGBA")
    s = min((W - 20) / img.width, (H - 22) / img.height)
    img = img.resize((max(1, int(img.width * s)), max(1, int(img.height * s))), Image.LANCZOS)
    return img

def plate(faction):
    base = np.zeros((H, W, 3), np.float32)
    yy = np.linspace(0, 1, H)[:, None]
    top = np.array([0.2, 0.26, 0.33]) if faction == "coalition" else np.array([0.3, 0.2, 0.17])
    base[:] = top * (1.1 - 0.5 * yy)[..., None]
    rng = np.random.default_rng(3)
    base *= (0.94 + 0.08 * rng.random((H, W, 1)))
    img = Image.fromarray((np.clip(base, 0, 1) * 255).astype(np.uint8)).convert("RGBA")
    d = ImageDraw.Draw(img)
    for gx in range(0, W, 16):
        d.line([(gx, 0), (gx, H)], fill=(255, 255, 255, 10))
    for gy in range(0, H, 16):
        d.line([(0, gy), (W, gy)], fill=(255, 255, 255, 10))
    d.ellipse([W * 0.1, H * 0.55, W * 0.9, H * 1.05], fill=(0, 0, 0, 60))
    return img

def frame_border(img, faction):
    d = ImageDraw.Draw(img)
    hi = (190, 200, 210, 255) if faction == "coalition" else (215, 180, 140, 255)
    lo = (20, 22, 26, 255)
    for i in range(3):
        d.line([(i, i), (W - 1 - i, i)], fill=hi if i == 1 else lo)
        d.line([(i, i), (i, H - 1 - i)], fill=hi if i == 1 else lo)
        d.line([(i, H - 1 - i), (W - 1 - i, H - 1 - i)], fill=lo)
        d.line([(W - 1 - i, i), (W - 1 - i, H - 1 - i)], fill=lo)
    return img

UNITS = {
    "e1": ("i_infantry_{f}", 0 * 8 + 1, None), "e3": ("i_rocket_inf_coalition", 1, None), "e4": ("i_heavy_inf_dominion", 1, None),
    "flm": ("i_flame_inf_dominion", 1, None), "jeep": ("u_jeep_coalition", 3, True), "ltank": ("u_tank_light_coalition", 3, True),
    "mtank": ("u_tank_medium_coalition", 3, True), "htank": ("u_tank_heavy_dominion", 3, True), "harv": ("u_harvester_{f}", 32 + 3, None),
    "mcv": ("u_mcv_{f}", 3, None),
}

def main():
    os.makedirs(OUT, exist_ok=True)
    data = json.load(open(os.path.join(ROOT, "data", "units.json")))
    bdata = json.load(open(os.path.join(ROOT, "data", "buildings.json")))
    for faction in ("coalition", "dominion"):
        team = FACTION_COL[faction]
        items = []
        for t, d in data.items():
            if faction in d["factions"]:
                items.append((t, "unit"))
        for t, d in bdata.items():
            if faction in d["factions"]:
                items.append((t, "building"))
        for t, kind in items:
            try:
                if kind == "unit":
                    name, i, tur = UNITS[t]
                    name = name.format(f=faction)
                    turret = None
                    if tur:
                        meta = json.load(open(os.path.join(SP, name + ".json")))
                        pv = meta["extra"]["pivot"]
                        ang = 2 * math.pi * (i % 32) / 32
                        dx = pv[0] * math.cos(ang) - pv[2] * math.sin(ang)
                        dz = pv[0] * math.sin(ang) + pv[2] * math.cos(ang)
                        turret = (name + "_turret", i % 32, (dx - dz) * 64, (dx + dz) * 32 - pv[1] * 78.38)
                    img = compose(name, i, team, turret)
                else:
                    sprite = bdata[t]["sprite"]
                    name = "b_%s_%s" % (sprite, faction)
                    if not os.path.exists(os.path.join(SP, name + ".json")):
                        continue
                    tur = None
                    if os.path.exists(os.path.join(SP, name + "_turret.json")):
                        meta = json.load(open(os.path.join(SP, name + ".json")))
                        tmeta = json.load(open(os.path.join(SP, name + "_turret.json")))
                        pv = tmeta["extra"]["pivot"]
                        px = (pv[0] - pv[2]) * 64 - pv[1] * 0
                        py = (pv[0] + pv[2]) * 32 - pv[1] * 78.38
                        tur = (name + "_turret", 4, meta["ax"] + px - tmeta["ax"], meta["ay"] + py - tmeta["ay"])
                    img = compose(name, 0, team, tur)
            except (FileNotFoundError, KeyError) as e:
                print("skip", t, faction, e)
                continue
            bg = plate(faction)
            bg.alpha_composite(img, ((W - img.width) // 2, (H - img.height) // 2 + 4))
            frame_border(bg, faction).convert("RGB").save(os.path.join(OUT, "%s_%s.png" % (t, faction)), optimize=True)
            print("cameo", t, faction)

if __name__ == "__main__":
    main()
