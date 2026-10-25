"""Découpe les planches ChatGPT de Dracombra : bâtiments et paliers de la guilde, icônes
d'objets, pavés et ruines de la ville, sanglier. Écrit directement dans le projet.
Usage : python3 extract_city.py <projet>
"""
import json
import os
import sys
import numpy as np
from PIL import Image

sys.path.insert(0, '../props')
sys.path.insert(0, '../assets2')
from seg import segment
from slice import downscale, quantize, keep_main, load_rgba, A, build_sheet

P = sys.argv[1]
T = 16


def defringe(img):
    a = np.asarray(img).copy()
    r, g, b = [a[..., k].astype(int) for k in range(3)]
    pink = (r > 140) & (b > 120) & (g < 0.55 * np.minimum(r, b))
    a[pink, 3] = 0
    return Image.fromarray(a, 'RGBA')


def trim(img):
    bb = img.getbbox()
    return img.crop(bb) if bb else img


def crop(rgba, box, inset=0):
    y0, x0, y1, x1 = box
    return Image.fromarray(rgba[y0 + inset:y1 - inset, x0 + inset:x1 - inset].copy(), 'RGBA')


def clean(img, scale, gap=4):
    return trim(keep_main(defringe(downscale(keep_main(defringe(img), max_gap=gap), scale)), max_gap=2))


def save(img, rel):
    path = os.path.join(P, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    return img.size


sizes = {}

# ------------------------------------------------------------------ bâtiments
rgba, objs = segment('06455da2-image.png', dilate=2, min_area=300)
box = lambda i: (objs[i][0], objs[i][1], objs[i][2], objs[i][3])
buildings = {
    "tent": (box(0), 0.12), "chest": (box(4), 0.085), "workbench": (box(1), 0.11),
    "drying_rack": (box(2), 0.11), "scaffold": (box(3), 0.11),
    "guild_0": (box(5), 0.13), "guild_1": (box(6), 0.15),
    "guild_2": ((250, 815, 578, 1500), 0.16), "guild_3": (box(8), 0.17),
    "guild_4": ((578, 724, 1012, 1530), 0.19),
}
imgs = [clean(crop(rgba, b), s, gap=6) for b, s in buildings.values()]
imgs = quantize(imgs, 64)
for name, img in zip(buildings, imgs):
    sizes[name] = save(img, f"assets/sprites/buildings/{name}.png")

# ------------------------------------------------------------------ icônes (16 x 16)
rgba, objs = segment('a61a7e53-image.png', dilate=2, min_area=300)
order = {"wood": 0, "stone": 4, "herb": 1, "flax": 2, "hide": 3, "meat": 5, "leather": 6, "rope": 7,
         "cloth": 8, "gem": 9, "balm": 14, "bow": 10, "staff": 11, "holy_symbol": 12, "sword": 13}
xs = {"wood": 64, "stone": 32, "herb": 80, "flax": 96, "hide": 112, "meat": 128, "leather": 144, "rope": 160,
      "cloth": 176, "gem": 192, "balm": 208, "bow": 224, "staff": 240, "holy_symbol": 256, "sword": 272}
icons = []
for name, i in order.items():
    src = defringe(crop(rgba, objs[i]))
    k = 15.0 / max(src.size)
    icons.append(trim(defringe(downscale(src, k))))
icons = quantize(icons, 48)
items = Image.open(os.path.join(P, "assets/sprites/items/items.png")).convert("RGBA")
for (name, _), icon in zip(order.items(), icons):
    x = xs[name]
    items.paste(Image.new("RGBA", (T, T)), (x, 0))
    items.alpha_composite(icon, (x + (T - icon.width) // 2, (T - icon.height) // 2))
items.save(os.path.join(P, "assets/sprites/items/items.png"))

# ------------------------------------------------------------------ pavés et ruines
rgba, objs = segment('c44f3af3-image.png', dilate=2, min_area=300)


def tile(i):
    img = downscale(crop(rgba, objs[i], inset=4), T / (objs[i][3] - objs[i][1] - 8))
    img = img.resize((T, T), Image.NEAREST) if img.size != (T, T) else img
    a = np.asarray(img).copy()
    a[..., 3] = 255
    return a


paving = [tile(i) for i in range(0, 6)]
grassy = [tile(i) for i in range(6, 12)]
plaza = [tile(i) for i in range(12, 16)]
dirt = [tile(i) for i in range(16, 21)]
sheet = np.zeros((T * 4, T * 8, 4), np.uint8)
rows = [paving + paving[:2], grassy + grassy[:2], plaza + plaza, dirt[:4] + [dirt[4], dirt[0], dirt[1], dirt[2]]]
for r, row in enumerate(rows):
    for c, a in enumerate(row):
        sheet[r * T:(r + 1) * T, c * T:(c + 1) * T] = a
Image.fromarray(sheet, "RGBA").save(os.path.join(P, "assets/tilesets/dracombra_tiles.png"))

city_props = {
    "rubble_dragon": (21, 0.12), "rubble_wing": (22, 0.12), "rubble_blocks": (23, 0.12),
    "rubble_pillar": (24, 0.12), "rubble_column": (25, 0.12), "rubble_slab": (26, 0.12),
    "rubble_small": (27, 0.12), "ruin_pillar_small": (28, 0.12),
    "ruin_wall": (31, 0.13), "ruin_pillars": (32, 0.13), "ruin_arch_dragon": (33, 0.13),
    "ruin_column": (34, 0.13), "ruin_arch": (29, 0.13), "dracombra_gate": (30, 0.16),
}
imgs = quantize([clean(crop(rgba, objs[i]), s) for i, s in city_props.values()], 56)
for name, img in zip(city_props, imgs):
    sizes[name] = save(img, f"assets/sprites/props/city/{name}.png")

# ------------------------------------------------------------------ sanglier (4 x 3)
rgba = load_rgba(A + 'c521530c-image.png')
alpha = rgba[..., 3] > 0
rows_y = [(60, 340), (390, 650), (700, 990)]
frames = []
for y0, y1 in rows_y:
    sub = alpha[y0:y1]
    cols = np.where(sub.any(0))[0]
    # 4 images par rangée, séparées aux colonnes vides
    xs_ = []
    runs = []
    start = None
    for x in range(rgba.shape[1]):
        on = sub[:, x].any()
        if on and start is None:
            start = x
        if not on and start is not None:
            runs.append((start, x))
            start = None
    if start is not None:
        runs.append((start, rgba.shape[1]))
    runs = [r for r in runs if r[1] - r[0] > 40]
    while len(runs) > 4:
        gaps = [runs[i + 1][0] - runs[i][1] for i in range(len(runs) - 1)]
        i = int(np.argmin(gaps))
        runs[i:i + 2] = [(runs[i][0], runs[i + 1][1])]
    row = []
    for x0, x1 in runs:
        img = Image.fromarray(rgba[y0:y1, x0:x1].copy(), 'RGBA')
        row.append(keep_main(defringe(downscale(defringe(img), 0.085)), max_gap=3))
    frames.append(row)
flat = quantize([f for r in frames for f in r], 32)
it = iter(flat)
frames = [[trim(next(it)) for _ in r] for r in frames]
cw = max(f.width for r in frames for f in r) + 2
ch = max(f.height for r in frames for f in r)
anchors = [[f.width * 0.55 for f in r] for r in frames]
boar = build_sheet(frames, cw, ch, anchors)
boar.save(os.path.join(P, "assets/sprites/enemies/boar.png"))
sizes["boar_cell"] = (cw, ch)
json.dump(sizes, open("city_sizes.json", "w"), indent=1)
for k, v in sizes.items():
    print(f"{k:18} {v}")
