"""Art provisoire de la Sylve des Dracombres (en attendant les planches ChatGPT).

Écrit :
  <projet>/assets/tilesets/sylve_tiles.png  (8 x 8 tuiles de 16 px)
    ligne 0 : herbe (8 variantes)
    ligne 1 : herbe fleurie (0-3), sous-bois (4-7)
    ligne 2 : terre (0-3), gué : eau peu profonde et pierres (4-5), mousse (6-7)
    ligne 3 : eau (0-3)
    lignes 4-5 : eau, index = côtés qui touchent la terre ferme (N=1, E=2, S=4, O=8)
    lignes 6-7 : chemin de terre, index = côtés qui touchent l'herbe
  <projet>/assets/sprites/props/sylve/*.png et props_sylve.json (même format que props.json)
"""
import json
import math
import os
import random
import sys
import numpy as np
from PIL import Image

T = 16
P = sys.argv[1]
OUT_JSON = sys.argv[2]
rnd = random.Random(5)

G = {"base": (86, 140, 62), "l1": (106, 160, 70), "l2": (134, 184, 86), "d1": (70, 120, 54),
     "d2": (52, 96, 46), "d3": (38, 72, 40)}
DIRT = {"base": (150, 114, 78), "l1": (170, 134, 92), "d1": (126, 92, 64), "d2": (100, 72, 52),
        "peb": (186, 170, 150)}
WATER = {"base": (54, 100, 156), "l1": (76, 130, 186), "l2": (150, 196, 226), "d1": (42, 80, 130),
         "bank": (60, 92, 58), "wet": (96, 80, 58)}


def new(w=T, h=T):
    return np.zeros((h, w, 4), np.uint8)


def setp(a, x, y, c, alpha=255):
    if 0 <= y < a.shape[0] and 0 <= x < a.shape[1]:
        a[y, x] = (*c, alpha)


def grass_tile(seed, flowers=0, dark=False):
    r = random.Random(seed)
    a = new()
    pal = G if not dark else {k: tuple(int(v * 0.8) for v in c) for k, c in G.items()}
    a[..., :3] = pal["base"]
    a[..., 3] = 255
    # Taches douces de lumière et d'ombre.
    for _ in range(5):
        cx, cy, rad = r.randrange(T), r.randrange(T), r.uniform(2, 4)
        col = pal["l1"] if r.random() < 0.5 else pal["d1"]
        for y in range(T):
            for x in range(T):
                dx = min(abs(x - cx), T - abs(x - cx))
                dy = min(abs(y - cy), T - abs(y - cy))
                if dx * dx + dy * dy < rad * rad and r.random() < 0.8:
                    a[y, x, :3] = col
    # Brins d'herbe : un trait clair sur une ombre.
    for _ in range(7):
        x, y = r.randrange(T), r.randrange(1, T)
        setp(a, x, y, pal["d2"])
        setp(a, x, y - 1, pal["l2"] if r.random() < 0.6 else pal["l1"])
    if dark:
        for _ in range(4):
            x, y = r.randrange(T - 1), r.randrange(T)
            setp(a, x, y, (92, 72, 44))
            setp(a, x + 1, y, (120, 92, 52))
    for _ in range(flowers):
        x, y = r.randrange(1, T - 1), r.randrange(1, T - 1)
        petal = r.choice([(240, 240, 232), (250, 214, 90), (236, 140, 170), (150, 170, 240)])
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            setp(a, x + dx, y + dy, petal)
        setp(a, x, y, (250, 200, 60) if petal != (250, 214, 90) else (200, 120, 40))
    return a


def dirt_tile(seed):
    r = random.Random(seed)
    a = new()
    a[..., :3] = DIRT["base"]
    a[..., 3] = 255
    for _ in range(26):
        setp(a, r.randrange(T), r.randrange(T), r.choice([DIRT["l1"], DIRT["d1"], DIRT["d1"]]))
    for _ in range(2):
        x, y = r.randrange(1, T - 2), r.randrange(1, T - 2)
        setp(a, x, y, DIRT["peb"])
        setp(a, x + 1, y, DIRT["l1"])
        setp(a, x, y + 1, DIRT["d2"])
        setp(a, x + 1, y + 1, DIRT["d2"])
    return a


def water_tile(seed, shallow=False):
    r = random.Random(seed)
    a = new()
    base = WATER["base"] if not shallow else (90, 140, 170)
    a[..., :3] = base
    a[..., 3] = 255
    for _ in range(3):
        x, y = r.randrange(T - 4), r.randrange(T)
        for i in range(r.randrange(2, 5)):
            setp(a, x + i, y, WATER["l1"])
        setp(a, x + 1, y, WATER["l2"])
    for _ in range(6):
        setp(a, r.randrange(T), r.randrange(T), WATER["d1"])
    if shallow:
        # Pierres plates du gué.
        for cx, cy in [(4, 4), (11, 6), (6, 11), (12, 12)]:
            cx += r.randrange(-1, 2)
            cy += r.randrange(-1, 2)
            for y in range(-2, 2):
                for x in range(-2, 3):
                    if x * x + y * y * 1.6 <= 5:
                        setp(a, cx + x, cy + y, (150, 146, 140) if y < 0 else (112, 108, 104))
            setp(a, cx - 1, cy - 2, (190, 186, 178))
    return a


def bordered(base, mask, seed, kind):
    """Ajoute une bordure herbeuse sur les côtés ouverts (mask : N=1, E=2, S=4, O=8)."""
    r = random.Random(seed)
    a = base.copy()
    depth = 3 if kind == "water" else 2

    def edge(x, y, d):
        # d = distance au bord (0 = tout au bord).
        if kind == "water":
            if d == 0:
                return G["d1"]
            if d == 1:
                return WATER["bank"]
            return WATER["wet"] if r.random() < 0.6 else WATER["l2"]
        return G["base"] if d == 0 else (G["d1"] if r.random() < 0.7 else G["l1"])

    for y in range(T):
        for x in range(T):
            ds = []
            if mask & 1:
                ds.append(y)
            if mask & 4:
                ds.append(T - 1 - y)
            if mask & 8:
                ds.append(x)
            if mask & 2:
                ds.append(T - 1 - x)
            if not ds:
                continue
            d = min(ds)
            wobble = 1 if r.random() < 0.3 else 0
            if d < depth - wobble:
                a[y, x, :3] = edge(x, y, d)
    return a


tiles = Image.new("RGBA", (T * 8, T * 8))


def put(a, col, row):
    tiles.paste(Image.fromarray(a, "RGBA"), (col * T, row * T))


for i in range(8):
    put(grass_tile(10 + i), i, 0)
for i in range(4):
    put(grass_tile(30 + i, flowers=2 + i % 2), i, 1)
for i in range(4):
    put(grass_tile(40 + i, dark=True), 4 + i, 1)
for i in range(4):
    put(dirt_tile(50 + i), i, 2)
put(water_tile(60, shallow=True), 4, 2)
put(water_tile(61, shallow=True), 5, 2)
for i in range(2):
    m = grass_tile(70 + i)
    rr = random.Random(80 + i)
    for _ in range(30):
        setp(m, rr.randrange(T), rr.randrange(T), (70, 130, 80))
    put(m, 6 + i, 2)
for i in range(4):
    put(water_tile(90 + i), i, 3)
for m in range(16):
    put(bordered(water_tile(100 + m), m, 200 + m, "water"), m % 8, 4 + m // 8)
    put(bordered(dirt_tile(300 + m), m, 400 + m, "dirt"), m % 8, 6 + m // 8)
tiles.save(os.path.join(P, "assets/tilesets/sylve_tiles.png"))

# ------------------------------------------------------------------ décors
OUTLINE = (30, 44, 32)


def blob_canopy(w, h, cx, cy, circles, pal, seed):
    r = random.Random(seed)
    a = new(w, h)
    mask = np.zeros((h, w), bool)
    shade = np.zeros((h, w))
    for ox, oy, rad in circles:
        for y in range(h):
            for x in range(w):
                dx, dy = x - (cx + ox), y - (cy + oy)
                dd = dx * dx + dy * dy
                if dd <= rad * rad:
                    nx, ny = dx / rad, dy / rad
                    light = -(nx * 0.55 + ny * 0.8)  # lumière en haut à gauche
                    if not mask[y, x] or light > shade[y, x]:
                        shade[y, x] = light
                    mask[y, x] = True
    for y in range(h):
        for x in range(w):
            if not mask[y, x]:
                continue
            v = shade[y, x] + r.uniform(-0.18, 0.18)
            col = pal[0] if v > 0.55 else pal[1] if v > 0.15 else pal[2] if v > -0.35 else pal[3]
            a[y, x] = (*col, 255)
    # Petites touffes de feuilles claires.
    for _ in range(int(w * h / 60)):
        x, y = r.randrange(w), r.randrange(h)
        if mask[y, x] and shade[y, x] > 0.1:
            setp(a, x, y, pal[0])
            setp(a, x + 1, y, pal[1])
            setp(a, x, y + 1, pal[2])
    return a, mask


def outline(a, col=OUTLINE):
    m = a[..., 3] > 0
    g = np.zeros_like(m)
    g[1:] |= m[:-1]
    g[:-1] |= m[1:]
    g[:, 1:] |= m[:, :-1]
    g[:, :-1] |= m[:, 1:]
    a[g & ~m] = (*col, 255)
    return a


def shadow(w, h, rx, ry, cy):
    a = new(w, h)
    for y in range(h):
        for x in range(w):
            if ((x - w / 2) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1:
                a[y, x] = (20, 34, 24, 90)
    return a


def over(dst, src, x0=0, y0=0):
    h, w = src.shape[:2]
    for y in range(h):
        for x in range(w):
            if src[y, x, 3] == 255 and 0 <= y + y0 < dst.shape[0] and 0 <= x + x0 < dst.shape[1]:
                dst[y + y0, x + x0] = src[y, x]
    return dst


def trunk(a, cx, top, bottom, width, bark=((112, 78, 50), (86, 58, 38), (62, 42, 30))):
    for y in range(top, bottom):
        flare = 1 if y >= bottom - 3 else 0
        for x in range(cx - width // 2 - flare, cx + (width + 1) // 2 + flare):
            t = (x - (cx - width // 2 - flare)) / max(1, width + 2 * flare - 1)
            col = bark[0] if t < 0.3 else bark[1] if t < 0.75 else bark[2]
            setp(a, x, y, col)


OAK = [(150, 200, 90), (98, 160, 66), (64, 120, 54), (40, 84, 44)]
OAK2 = [(176, 196, 84), (120, 160, 60), (80, 122, 48), (52, 86, 40)]
PINE = [(98, 150, 96), (62, 116, 76), (42, 86, 60), (28, 60, 46)]


def oak(seed, w=46, h=56, pal=OAK, k=1.0):
    r = random.Random(seed)
    a = new(w, h)
    a = over(a, shadow(w, h, 16, 4, h - 4))
    a[..., 3] = np.where(a[..., 3] > 0, 90, 0)
    t = new(w, h)
    trunk(t, w // 2, h - 22, h - 2, 6)
    circles = [(0, 0, 13), (-9, 3, 9), (9, 3, 9), (-5, -7, 9), (6, -6, 9), (0, 7, 10)]
    circles = [(round((ox + r.randrange(-1, 2)) * k), round((oy + r.randrange(-1, 2)) * k),
                round((rad + r.randrange(-1, 2)) * k)) for ox, oy, rad in circles]
    c, _ = blob_canopy(w, h, w // 2, h - 22 - round(15 * k), circles, pal, seed)
    t = over(t, c)
    t = outline(t)
    return over(a, t)


def pine(seed, w=30, h=56):
    r = random.Random(seed)
    a = new(w, h)
    t = new(w, h)
    trunk(t, w // 2, h - 12, h - 2, 4)
    layers = 5
    for i in range(layers):
        top = 2 + i * 8
        height = 14
        half_max = 5 + i * 2.2
        for y in range(top, top + height):
            k = (y - top) / height
            half = half_max * k
            for x in range(int(w / 2 - half), int(w / 2 + half) + 1):
                side = (x - w / 2) / max(half, 1)
                v = -side * 0.7 + (0.3 - k) + r.uniform(-0.2, 0.2)
                col = PINE[0] if v > 0.5 else PINE[1] if v > 0.0 else PINE[2] if v > -0.5 else PINE[3]
                setp(t, x, y, col)
    t = outline(t)
    sh = shadow(w, h, 10, 3, h - 3)
    sh[..., 3] = np.where(sh[..., 3] > 0, 90, 0)
    return over(sh, t)


def bush(seed, w=22, h=16, berries=False):
    a, _ = blob_canopy(w, h, w // 2, h // 2 + 1, [(0, 0, 7), (-5, 2, 5), (5, 2, 5)], OAK, seed)
    if berries:
        r = random.Random(seed)
        for _ in range(6):
            x, y = r.randrange(3, w - 3), r.randrange(3, h - 3)
            if a[y, x, 3]:
                setp(a, x, y, (200, 40, 60))
                setp(a, x, y - 1, (240, 120, 130))
    return outline(a)


def flowers(seed, color):
    r = random.Random(seed)
    a = new(14, 10)
    for _ in range(5):
        x, y = r.randrange(2, 12), r.randrange(3, 9)
        setp(a, x, y, (60, 110, 50))
        setp(a, x, y + 1, (60, 110, 50))
        for dx, dy in ((1, 0), (-1, 0), (0, -1)):
            setp(a, x + dx, y - 1 + dy, color)
        setp(a, x, y - 1, (250, 220, 90))
    return a


def tall_grass(seed):
    r = random.Random(seed)
    a = new(14, 14)
    for i in range(9):
        x = r.randrange(1, 13)
        hgt = r.randrange(6, 13)
        bend = r.choice([-1, 0, 1])
        for k in range(hgt):
            xx = x + (bend if k > hgt * 0.6 else 0)
            setp(a, xx, 13 - k, G["l2"] if k > hgt - 3 else G["l1"] if k > hgt / 2 else G["d1"])
    return a


def rock(seed, w=18, h=13):
    r = random.Random(seed)
    a = new(w, h)
    cx, cy = w / 2, h / 2 + 1
    for y in range(h):
        for x in range(w):
            dx, dy = (x - cx) / (w / 2 - 1), (y - cy) / (h / 2 - 1)
            if dx * dx + dy * dy * 1.2 <= 1 + r.uniform(-0.1, 0.05):
                v = -dx * 0.5 - dy * 0.8 + r.uniform(-0.15, 0.15)
                col = (176, 172, 164) if v > 0.5 else (140, 136, 130) if v > -0.1 else (104, 100, 98)
                setp(a, x, y, col)
    for _ in range(4):
        x, y = r.randrange(w), r.randrange(h // 2)
        if a[y, x, 3]:
            setp(a, x, y, (90, 140, 70))
    return outline(a, (52, 50, 52))


def log(w=30, h=12):
    a = new(w, h)
    for y in range(2, h - 2):
        for x in range(3, w - 3):
            t = (y - 2) / (h - 5)
            setp(a, x, y, (130, 92, 58) if t < 0.3 else (104, 72, 46) if t < 0.75 else (76, 52, 36))
    for y in range(2, h - 2):
        setp(a, w - 4, y, (190, 160, 110))
        setp(a, w - 3, y, (160, 126, 84))
    setp(a, w - 4, h // 2, (130, 92, 58))
    for x in range(6, w - 6, 5):
        setp(a, x, 4, (90, 140, 70))
    return outline(a, (52, 36, 28))


def stump(w=16, h=14):
    a = new(w, h)
    trunk(a, w // 2, 5, h - 1, 10)
    for x in range(3, 13):
        setp(a, x, 4, (196, 164, 116))
        setp(a, x, 5, (170, 136, 92))
    setp(a, 8, 4, (150, 112, 74))
    return outline(a, (52, 36, 28))


def campfire(w=18, h=15):
    a = new(w, h)
    for i, (x, y) in enumerate([(3, 11), (14, 11), (5, 13), (12, 13), (9, 13)]):
        for dx in range(-1, 2):
            setp(a, x + dx, y, (120, 116, 112))
            setp(a, x + dx, y - 1, (160, 156, 150))
    for x in range(4, 14):
        setp(a, x, 10, (92, 62, 40))
        setp(a, x, 9, (120, 84, 52))
    flame = ["...X....", "..XX..X.", "..XYX.X.", ".XYYXXX.", ".XYWYYX.", "XYYWWYYX"]
    for y, row in enumerate(flame):
        for x, ch in enumerate(row):
            col = {"X": (230, 90, 30), "Y": (250, 170, 50), "W": (255, 240, 170)}.get(ch)
            if col:
                setp(a, 5 + x, 2 + y, col)
    return a


def bedroll(w=14, h=22):
    a = new(w, h)
    for y in range(2, h - 1):
        for x in range(1, w - 1):
            setp(a, x, y, (120, 70, 60) if (y // 3) % 2 else (140, 86, 72))
    for y in range(2, 7):
        for x in range(2, w - 2):
            setp(a, x, y, (200, 190, 170))
    return outline(a, (60, 40, 36))


def cave_mouth(w=36, h=30):
    a = new(w, h)
    cx = w / 2
    for y in range(h):
        for x in range(w):
            dx = (x - cx) / (w / 2 - 2)
            dy = (h - y) / (h - 3)
            if dx * dx + dy * dy <= 1:
                d = dx * dx + dy * dy
                col = (10, 8, 14) if d < 0.55 else (22, 18, 28) if d < 0.8 else (38, 32, 46)
                setp(a, x, y, col)
    return outline(a, (64, 56, 74))


def save(name, a):
    d = os.path.join(P, "assets/sprites/props/sylve")
    os.makedirs(d, exist_ok=True)
    img = Image.fromarray(a, "RGBA")
    bbox = img.getbbox()
    img = img.crop(bbox)
    img.save(os.path.join(d, name + ".png"))
    return list(img.size)


FIRE = [1.0, 0.6, 0.25]
spec = {}


def add(name, a, kind="object", collision=None, block=(0, 0), light=None):
    size = save(name, a)
    spec[name] = {"group": "sylve", "size": size, "kind": kind, "collision": collision,
                  "block": list(block), "light": light}


add("oak_a", oak(1), collision=[10, 6], block=(1, 1))
add("oak_b", oak(2), collision=[10, 6], block=(1, 1))
add("oak_c", oak(3, pal=OAK2), collision=[10, 6], block=(1, 1))
add("oak_big", oak(4, 64, 72, k=1.3), collision=[12, 6], block=(1, 1))
add("pine_a", pine(5), collision=[8, 6], block=(1, 1))
add("pine_b", pine(6, 26, 48), collision=[8, 6], block=(1, 1))
add("bush", bush(7), collision=[16, 6], block=(1, 1))
add("bush_berries", bush(8, berries=True), collision=[16, 6], block=(1, 1))
add("flowers_white", flowers(9, (240, 240, 232)))
add("flowers_yellow", flowers(10, (250, 214, 90)))
add("flowers_pink", flowers(11, (236, 140, 170)))
add("tall_grass", tall_grass(12))
add("tall_grass_b", tall_grass(13))
add("rock_grey", rock(14), collision=[14, 6], block=(1, 1))
add("rock_grey_big", rock(15, 28, 20), collision=[24, 8], block=(2, 1))
add("log", log(), collision=[24, 6], block=(2, 1))
add("stump", stump(), collision=[10, 5], block=(1, 1))
add("campfire", campfire(), collision=[12, 5], block=(1, 1), light=[FIRE, 64, 0.75, True])
add("bedroll", bedroll(), kind="decal")
add("cave_mouth", cave_mouth(), kind="hanging")
json.dump(spec, open(OUT_JSON, "w"), indent=1)
print("ok", len(spec), "décors")
