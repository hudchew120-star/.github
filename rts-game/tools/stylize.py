#!/usr/bin/env python3
"""Hand-drawn finish for cel-shaded renders: an ink outline around the silhouette, thinner
interior ink lines wherever the flat colour bands change, slightly richer colours and a
faint pencil-grain texture. Works on RGBA images with transparent backgrounds.

Usage: python3 tools/stylize.py in.png out.png [line_px]"""
import sys
import numpy as np
from PIL import Image, ImageFilter

INK = np.array([0.09, 0.07, 0.06], dtype=np.float32)

def _dilate(mask, r):
    img = Image.fromarray((mask * 255).astype(np.uint8))
    return np.array(img.filter(ImageFilter.MaxFilter(r * 2 + 1))).astype(np.float32) / 255.0

def stylize(rgba, line_px=2, threshold=0.16):
    a = rgba.astype(np.float32) / 255.0
    rgb, al = a[..., :3], a[..., 3]
    solid = (al > 0.5).astype(np.float32)
    # Interior lines: colour discontinuities between neighbouring pixels (cel band edges).
    lum = rgb @ np.array([0.3, 0.59, 0.11], dtype=np.float32)
    # Edges come from a smoothed copy so fine texture (camouflage, panels, noise) is not inked.
    smooth_px = max(3, line_px + 1) | 1
    sm = np.array(Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.MedianFilter(smooth_px))).astype(np.float32) / 255.0
    sm_l = sm @ np.array([0.3, 0.59, 0.11], dtype=np.float32)
    feat = np.concatenate([sm, sm_l[..., None] * 1.5], axis=2)
    gx = np.abs(np.diff(feat, axis=1, append=feat[:, -1:])).sum(axis=2)
    gy = np.abs(np.diff(feat, axis=0, append=feat[-1:])).sum(axis=2)
    edge = np.clip((np.maximum(gx, gy) - threshold) * 4.0, 0, 1) * solid
    if line_px > 1:
        edge = _dilate(edge, max(1, line_px // 2))
    edge = np.array(Image.fromarray((edge * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.6))).astype(np.float32) / 255.0
    # Outer silhouette line, a little thicker than interior lines.
    outer = np.clip(_dilate(solid, line_px + 1) - solid, 0, 1)
    outer = np.array(Image.fromarray((outer * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.7))).astype(np.float32) / 255.0
    # Richer, slightly posterised colour and pencil grain.
    l2 = lum[..., None]
    rgb2 = np.clip(l2 + (rgb - l2) * 1.18, 0, 1)
    rgb2 = np.round(rgb2 * 24.0) / 24.0
    rng = np.random.default_rng(7)
    grain = rng.random(lum.shape).astype(np.float32)
    grain = np.array(Image.fromarray((grain * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.8))).astype(np.float32) / 255.0
    rgb2 *= (0.96 + 0.06 * grain)[..., None]
    rgb2 = rgb2 * (1 - edge[..., None] * 0.85) + INK * edge[..., None] * 0.85
    out_a = np.maximum(al, outer)
    k = np.where(out_a > 1e-4, outer / np.maximum(out_a, 1e-4), 0)[..., None]
    rgb3 = rgb2 * (1 - k) + INK * k
    return (np.clip(np.concatenate([rgb3, out_a[..., None]], axis=2), 0, 1) * 255 + 0.5).astype(np.uint8)

if __name__ == "__main__":
    im = np.array(Image.open(sys.argv[1]).convert("RGBA"))
    lp = int(sys.argv[3]) if len(sys.argv) > 3 else 2
    Image.fromarray(stylize(im, lp), "RGBA").save(sys.argv[2])
