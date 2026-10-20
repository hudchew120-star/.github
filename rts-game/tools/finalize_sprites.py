#!/usr/bin/env python3
"""Downsamples supersampled bake output (premultiplied box filter), gives sprites a light
painted finish, and writes final sheets + metadata into assets/sprites/."""
import json, os, sys
import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tools", "_bake_out")
DST = os.path.join(ROOT, "assets", "sprites")

def down(arr, ss):
    h, w, _ = arr.shape
    a = arr.astype(np.float32) / 255.0
    rgb, al = a[..., :3], a[..., 3:4]
    pm = np.concatenate([rgb * al, al], axis=2)
    pm = pm.reshape(h // ss, ss, w // ss, ss, 4).mean(axis=(1, 3))
    al2 = pm[..., 3:4]
    rgb2 = np.where(al2 > 1e-4, pm[..., :3] / np.maximum(al2, 1e-4), 0)
    return np.concatenate([rgb2, al2], axis=2)

def blur(a, r):
    # Separable box blur (twice ~ gaussian).
    for _ in range(2):
        k = 2 * r + 1
        p = np.pad(a, ((r, r), (0, 0)), mode="edge")
        c = np.cumsum(p, axis=0)
        c = np.vstack([np.zeros((1, c.shape[1])), c])
        a = (c[k:] - c[:-k]) / k
        p = np.pad(a, ((0, 0), (r, r)), mode="edge")
        c = np.cumsum(p, axis=1)
        c = np.hstack([np.zeros((c.shape[0], 1)), c])
        a = (c[:, k:] - c[:, :-k]) / k
    return a

def finish(img):
    rgb, al = img[..., :3], img[..., 3]
    # Mild saturation/contrast lift for a classic painted palette.
    lum = rgb @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
    rgb = lum[..., None] + (rgb - lum[..., None]) * 1.12
    rgb = (rgb - 0.5) * 1.05 + 0.52
    # Darken the outer rim of opaque shapes slightly so sprites read crisply on terrain.
    solid = (al > 0.5).astype(np.float32)
    pad = np.pad(solid, 1, mode="constant")
    neigh = np.minimum.reduce([pad[:-2, 1:-1], pad[2:, 1:-1], pad[1:-1, :-2], pad[1:-1, 2:]])
    edge = solid * (1 - neigh)
    rgb = rgb * (1 - 0.18 * edge[..., None])
    return np.clip(np.concatenate([rgb, al[..., None]], axis=2), 0, 1)

def to_img(a):
    return Image.fromarray((np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA")

def main():
    flt = sys.argv[1] if len(sys.argv) > 1 else ""
    os.makedirs(DST, exist_ok=True)
    for fn in sorted(os.listdir(SRC)):
        if not fn.endswith(".json") or flt not in fn:
            continue
        name = fn[:-5]
        meta = json.load(open(os.path.join(SRC, fn)))
        ss = meta["ss"]
        col = finish(down(np.array(Image.open(os.path.join(SRC, name + ".png")).convert("RGBA")), ss))
        if meta.get("shadow") and meta.get("separate_shadow"):
            # Aircraft: the shadow is drawn on the ground while the body flies above it.
            sil = down(np.array(Image.open(os.path.join(SRC, name + "_shadow.png")).convert("RGBA")), ss)[..., 3]
            soft = np.clip(blur(sil, 2) * 0.45, 0, 1)
            sh = np.zeros(soft.shape + (4,), dtype=np.float32)
            sh[..., 3] = soft
            to_img(sh).save(os.path.join(DST, name + "_shadow.png"), optimize=True)
        elif meta.get("shadow"):
            sil = down(np.array(Image.open(os.path.join(SRC, name + "_shadow.png")).convert("RGBA")), ss)[..., 3]
            soft = blur(sil, 2)
            sa = (0.4 * soft)[..., None]
            ca = col[..., 3:4]
            out_a = ca + sa * (1 - ca)
            out_rgb = np.where(out_a > 1e-4, col[..., :3] * ca / np.maximum(out_a, 1e-4), 0)
            col = np.concatenate([out_rgb, out_a], axis=2)
        to_img(col).save(os.path.join(DST, name + ".png"), optimize=True)
        if meta.get("mask"):
            m = down(np.array(Image.open(os.path.join(SRC, name + "_mask.png")).convert("RGBA")), ss)
            v = m[..., 0] * m[..., 3]
            Image.fromarray((np.clip(v, 0, 1) * 255 + 0.5).astype(np.uint8), "L").save(os.path.join(DST, name + "_mask.png"), optimize=True)
        meta.pop("ss", None)
        json.dump(meta, open(os.path.join(DST, name + ".json"), "w"))
        print("finalized", name)

if __name__ == "__main__":
    main()
