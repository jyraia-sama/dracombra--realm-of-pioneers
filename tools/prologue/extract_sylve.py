"""Découpe les planches ChatGPT de la Sylve (décors + sols) à l'échelle du jeu.

Remplace l'art provisoire de make_sylve_art.py, en gardant les mêmes noms et la même
disposition du tileset (voir make_sylve_art.py pour la carte des lignes).
Usage : python3 extract_sylve.py <projet> <props_sylve.json>
"""
import json
import os
import random
import sys
import numpy as np
from PIL import Image

sys.path.insert(0, '../props')
sys.path.insert(0, '../assets2')
from seg import segment
from slice import downscale, quantize, keep_main

T = 16
P, OUT_JSON = sys.argv[1], sys.argv[2]


def defringe(img):
    a = np.asarray(img).copy()
    r, g, b = [a[..., k].astype(int) for k in range(3)]
    pink = (r > 140) & (b > 120) & (g < 0.55 * np.minimum(r, b))
    a[pink, 3] = 0
    return Image.fromarray(a, 'RGBA')


def crop(rgba, box, inset=0):
    y0, x0, y1, x1 = box
    return Image.fromarray(rgba[y0 + inset:y1 - inset, x0 + inset:x1 - inset].copy(), 'RGBA')


def trim(img):
    bb = img.getbbox()
    return img.crop(bb) if bb else img


# ------------------------------------------------------------------ décors
rgba, objs = segment('465c0c01-image.png', dilate=1, min_area=300)
WARM = [1.0, 0.6, 0.25]
# nom : (indices, échelle, type, collision, cases bloquées, lumière)
PROPS = {
    "oak_a": ([0], 0.16, "object", [12, 6], [1, 1], None),
    "oak_b": ([1], 0.16, "object", [14, 6], [1, 1], None),
    "oak_c": ([3], 0.16, "object", [12, 6], [1, 1], None),
    "oak_big": ([2], 0.17, "object", [26, 8], [2, 1], None),
    "pine_a": ([5], 0.16, "object", [8, 6], [1, 1], None),
    "pine_b": ([4], 0.16, "object", [8, 6], [1, 1], None),
    "bush": ([6], 0.12, "object", [16, 6], [1, 1], None),
    "bush_berries": ([7], 0.12, "object", [16, 6], [1, 1], None),
    "flowers_white": ([8], 0.1, "object", None, [0, 0], None),
    "flowers_yellow": ([9], 0.1, "object", None, [0, 0], None),
    "flowers_pink": ([10], 0.1, "object", None, [0, 0], None),
    "tall_grass": ([11], 0.1, "object", None, [0, 0], None),
    "tall_grass_b": ([12], 0.1, "object", None, [0, 0], None),
    "rock_grey": ([13], 0.12, "object", [14, 6], [1, 1], None),
    "rock_grey_big": ([14], 0.12, "object", [22, 8], [2, 1], None),
    "log": ([15], 0.12, "object", [26, 6], [2, 1], None),
    "stump": ([16], 0.12, "object", [12, 6], [1, 1], None),
    "campfire": ([17, 18, 19], 0.11, "object", [12, 5], [1, 1], [WARM, 64, 0.8, True]),
    "bedroll": ([20], 0.12, "decal", None, [0, 0], None),
    "cave_mouth": ([21], 0.14, "object", None, [0, 0], None),
}
names = list(PROPS)
images = []
for name in names:
    idx, scale = PROPS[name][0], PROPS[name][1]
    frames = [trim(keep_main(defringe(downscale(keep_main(defringe(crop(rgba, objs[i])), max_gap=4), scale)), max_gap=2))
              for i in idx]
    images.append(frames)
flat = quantize([f for fr in images for f in fr], 56)
it = iter(flat)
images = [[next(it) for _ in fr] for fr in images]

d = os.path.join(P, "assets/sprites/props/sylve")
os.makedirs(d, exist_ok=True)
spec = {}
for name, frames in zip(names, images):
    idx, scale, kind, col, block, light = PROPS[name]
    w = max(f.width for f in frames)
    h = max(f.height for f in frames)
    strip = Image.new("RGBA", (w * len(frames), h))
    for i, f in enumerate(frames):
        strip.alpha_composite(f, (i * w + (w - f.width) // 2, h - f.height))
    strip.save(os.path.join(d, name + ".png"))
    spec[name] = {"group": "sylve", "size": [w, h], "kind": kind, "collision": col, "block": block,
                  "light": light, "frames": len(frames)}
    print(f"{name:16} {w}x{h} ({len(frames)} image(s))")
json.dump(spec, open(OUT_JSON, "w"), indent=1)

# ------------------------------------------------------------------ sols
trgba, tobjs = segment('9d9061be-image.png', dilate=1, min_area=300)
S = 16 / 150


def tile(i, flip=False):
    img = downscale(crop(trgba, tobjs[i], inset=3), S)
    img = img.resize((T, T), Image.NEAREST) if img.size != (T, T) else img
    a = np.asarray(img).copy()
    a[..., 3] = 255
    if flip:
        a = a[:, ::-1].copy()
    return seamless(a)


def seamless(a, border=3):
    a = a.astype(float)
    out = a.copy()
    for k in range(border):
        t = 0.5 * (1 - k / border)
        out[:, k] = a[:, k] * (1 - t) + a[:, T - 1 - k] * t
        out[:, T - 1 - k] = a[:, T - 1 - k] * (1 - t) + a[:, k] * t
    a = out.copy()
    for k in range(border):
        t = 0.5 * (1 - k / border)
        out[k] = a[k] * (1 - t) + a[T - 1 - k] * t
        out[T - 1 - k] = a[T - 1 - k] * (1 - t) + a[k] * t
    return out.round().astype(np.uint8)


def family(indices, count, seed, scale=0.2, calm=0.5):
    """Variantes d'une même famille : découpes 16 px les plus unies dans des textures
    réduites, puis ramenées à la même teinte moyenne (pas de damier)."""
    r = random.Random(seed)
    cands = []
    for i in indices:
        tex = np.asarray(downscale(crop(trgba, tobjs[i], inset=4), scale)).copy()
        tex[..., 3] = 255
        h, w = tex.shape[:2]
        for _ in range(40):
            x, y = r.randrange(0, w - T + 1), r.randrange(0, h - T + 1)
            c = tex[y:y + T, x:x + T]
            cands.append((c[..., :3].astype(float).mean(2).std(), c))
    cands.sort(key=lambda c: c[0])
    pool = cands[:max(count, int(len(cands) * calm))]
    picks = [pool[k][1] for k in sorted(r.sample(range(len(pool)), count))]
    mean = np.mean([p[..., :3].reshape(-1, 3).mean(0) for p in picks], axis=0)
    out = []
    for p in picks:
        q = p.astype(float)
        q[..., :3] += mean - q[..., :3].reshape(-1, 3).mean(0)
        out.append(seamless(np.clip(q, 0, 255).astype(np.uint8)))
    return out


grass = family([0, 1, 2, 3], 8, 1, calm=0.35)
flowers = family([4, 5], 4, 2, calm=0.9)
forest = family([6, 8], 4, 3)
dirt = family([10, 11], 4, 4, calm=0.4)
ford = [tile(25), tile(26)]
water = family([14, 15], 4, 5, scale=0.16)
BANK = np.array([92, 70, 48, 255], np.uint8)
BANK_D = np.array([62, 48, 40, 255], np.uint8)


def edged(base, mask, seed, kind):
    """Pose une bordure d'herbe (texture d'herbe) sur les côtés ouverts de la tuile."""
    r = random.Random(seed)
    a = base.copy()
    g = grass[seed % 4]
    depth = 4 if kind == "water" else 3
    for y in range(T):
        for x in range(T):
            ds = []
            if mask & 1: ds.append(y)
            if mask & 4: ds.append(T - 1 - y)
            if mask & 8: ds.append(x)
            if mask & 2: ds.append(T - 1 - x)
            if not ds:
                continue
            dist = min(ds) + r.choice([0, 0, 1, -1])
            if dist < depth - 1:
                a[y, x] = g[y, x]
            elif dist < depth and kind == "water":
                a[y, x] = BANK if r.random() < 0.7 else BANK_D
            elif dist < depth + 1 and kind == "water":
                a[y, x] = BANK_D
    return a


sheet = np.zeros((T * 8, T * 8, 4), np.uint8)


def put(a, col, row):
    sheet[row * T:(row + 1) * T, col * T:(col + 1) * T] = a


for i, a in enumerate(grass):
    put(a, i, 0)
for i, a in enumerate(flowers + forest):
    put(a, i, 1)
for i, a in enumerate(dirt + ford + [grass[1], grass[6]]):
    put(a, i, 2)
for i, a in enumerate(water):
    put(a, i, 3)
for m in range(16):
    put(edged(water[m % 2], m, 200 + m, "water"), m % 8, 4 + m // 8)
    put(edged(dirt[m % 3], m, 400 + m, "dirt"), m % 8, 6 + m // 8)
Image.fromarray(sheet, "RGBA").save(os.path.join(P, "assets/tilesets/sylve_tiles.png"))
print("tileset ok")
