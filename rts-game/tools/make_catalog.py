#!/usr/bin/env python3
"""Unit and structure catalogue posters (one per faction) from the high-resolution model
renders produced by:  godot --path . res://tools/showcase.tscn -- cameos <abs>/tools/_bake_out/cameos/ 400
Output: docs/screenshots/catalog_<faction>.png"""
import json, os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REN = os.path.join(ROOT, "tools", "_bake_out", "cameos")
OUT = os.path.join(ROOT, "docs", "screenshots")
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FONT_B = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
TILE_W, TILE_H = 300, 270
COLS = 6
THEME = {
    "coalition": {"title": "ADVANCED COALITION", "sub": "Clean modern engineering - faceted armour, optics, sand and steel",
                  "bg": (24, 32, 44), "accent": (90, 160, 235), "card": (36, 48, 64)},
    "dominion": {"title": "IRON DOMINION", "sub": "Brutal heavy metal - cast turrets, reactive armour, rivets and red stars",
                 "bg": (40, 24, 20), "accent": (230, 80, 60), "card": (58, 36, 30)},
}
SECTIONS = [("INFANTRY", lambda d: d.get("category") == "infantry"),
            ("ARMOUR & SUPPORT", lambda d: d.get("category") == "vehicle"),
            ("AIRCRAFT", lambda d: d.get("category") == "aircraft"),
            ("NAVY", lambda d: d.get("category") == "naval"),
            ("STRUCTURES", lambda d: d.get("category") in ("building", "defense"))]

def font(size, bold=False):
    try:
        return ImageFont.truetype(FONT_B if bold else FONT, size)
    except OSError:
        return ImageFont.load_default()

def card(t, d, faction, th):
    c = Image.new("RGBA", (TILE_W, TILE_H), th["card"] + (255,))
    dr = ImageDraw.Draw(c)
    for y in range(TILE_H):
        k = y / TILE_H
        dr.line([(0, y), (TILE_W, y)], fill=tuple(int(v * (1.15 - 0.35 * k)) for v in th["card"]) + (255,))
    dr.ellipse([30, TILE_H - 120, TILE_W - 30, TILE_H - 40], fill=(0, 0, 0, 70))
    p = os.path.join(REN, "%s_%s.png" % (t, faction))
    if os.path.exists(p):
        im = Image.open(p).convert("RGBA")
        s = min((TILE_W - 16) / im.width, (TILE_H - 62) / im.height)
        im = im.resize((int(im.width * s), int(im.height * s)), Image.LANCZOS)
        c.alpha_composite(im, ((TILE_W - im.width) // 2, 8 + (TILE_H - 62 - im.height) // 2))
    dr.rectangle([0, TILE_H - 52, TILE_W, TILE_H], fill=(0, 0, 0, 120))
    dr.text((12, TILE_H - 48), d["name"], font=font(18, True), fill=(240, 240, 235))
    info = "$%s" % d.get("cost", 0)
    if "hp" in d:
        info += "   HP %s" % d["hp"]
    dr.text((12, TILE_H - 24), info, font=font(14), fill=th["accent"])
    dr.rectangle([0, 0, TILE_W - 1, TILE_H - 1], outline=th["accent"] + (160,), width=2)
    return c

def main():
    os.makedirs(OUT, exist_ok=True)
    units = json.load(open(os.path.join(ROOT, "data", "units.json")))
    blds = json.load(open(os.path.join(ROOT, "data", "buildings.json")))
    allitems = dict(units)
    allitems.update(blds)
    for faction, th in THEME.items():
        blocks = []
        for title, pred in SECTIONS:
            items = [(t, d) for t, d in allitems.items() if faction in d.get("factions", []) and pred(d)]
            if items:
                blocks.append((title, items))
        rows = sum((len(i) + COLS - 1) // COLS for _, i in blocks)
        W = COLS * TILE_W + (COLS + 1) * 14
        H = 150 + rows * (TILE_H + 14) + len(blocks) * 56 + 30
        img = Image.new("RGBA", (W, H), th["bg"] + (255,))
        dr = ImageDraw.Draw(img)
        dr.rectangle([0, 0, W, 120], fill=tuple(int(v * 0.6) for v in th["bg"]) + (255,))
        dr.rectangle([0, 118, W, 124], fill=th["accent"] + (255,))
        dr.text((28, 22), th["title"], font=font(48, True), fill=(245, 245, 240))
        dr.text((30, 82), th["sub"], font=font(20), fill=th["accent"])
        y = 146
        for title, items in blocks:
            dr.text((16, y), title, font=font(26, True), fill=th["accent"])
            dr.line([(16, y + 38), (W - 16, y + 38)], fill=th["accent"] + (120,), width=2)
            y += 52
            for i, (t, d) in enumerate(items):
                x = 14 + (i % COLS) * (TILE_W + 14)
                if i and i % COLS == 0:
                    y += TILE_H + 14
                img.alpha_composite(card(t, d, faction, th), (x, y))
            y += TILE_H + 18
        img.convert("RGB").save(os.path.join(OUT, "catalog_%s.png" % faction), optimize=True)
        print("catalog", faction, img.size)

if __name__ == "__main__":
    main()
