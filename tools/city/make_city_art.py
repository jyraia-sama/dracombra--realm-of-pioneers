"""Art provisoire de Dracombra (en attendant les planches ChatGPT).

Écrit dans le projet :
  assets/tilesets/dracombra_tiles.png : 8 x 4 tuiles de 16 px
    ligne 0 : pavés anciens (8 variantes)
    ligne 1 : pavés envahis d'herbe (8 variantes)
    ligne 2 : dalles de la grande place (8 variantes)
    ligne 3 : terre battue du camp (4) + gravats au sol (4)
  assets/sprites/buildings/*.png : bâtiments et chantier
  assets/sprites/items/items.png : + icône de bois (x = 64)
"""
import os
import random
import sys
import numpy as np
from PIL import Image

T = 16
P = sys.argv[1]


def new(w, h):
    return np.zeros((h, w, 4), np.uint8)


def setp(a, x, y, c, alpha=255):
    if 0 <= y < a.shape[0] and 0 <= x < a.shape[1]:
        a[y, x] = (*c, alpha)


def rect(a, x0, y0, x1, y1, c):
    for y in range(y0, y1):
        for x in range(x0, x1):
            setp(a, x, y, c)


def outline(a, col=(28, 24, 30)):
    m = a[..., 3] > 0
    g = np.zeros_like(m)
    g[1:] |= m[:-1]; g[:-1] |= m[1:]; g[:, 1:] |= m[:, :-1]; g[:, :-1] |= m[:, 1:]
    a[g & ~m] = (*col, 255)
    return a


GRASS = [(86, 140, 62), (106, 160, 70), (70, 120, 54), (134, 184, 86)]
STONE = [(150, 146, 138), (128, 124, 118), (108, 104, 100), (172, 168, 158)]
MORTAR = (78, 74, 72)


def cobbles(seed, grass=0.0, big=False):
    r = random.Random(seed)
    a = new(T, T)
    a[..., :3] = MORTAR
    a[..., 3] = 255
    size = 7 if big else 5
    y = 0
    row = 0
    while y < T:
        h = size + r.randrange(-1, 2)
        x = -(row % 2) * (size // 2)
        while x < T:
            w = size + 1 + r.randrange(-1, 2)
            base = r.choice(STONE[:3])
            for yy in range(y + 1, min(T, y + h)):
                for xx in range(max(0, x + 1), min(T, x + w)):
                    c = base
                    if yy == y + 1 or xx == x + 1:
                        c = STONE[3] if base != STONE[2] else STONE[0]
                    if yy == y + h - 1 or xx == x + w - 1:
                        c = STONE[2]
                    setp(a, xx, yy, c)
            x += w
        y += h
        row += 1
    # Fissures et usure.
    for _ in range(3):
        x, y = r.randrange(T), r.randrange(T)
        setp(a, x, y, MORTAR)
    # L'herbe reprend ses droits entre les pavés.
    for yy in range(T):
        for xx in range(T):
            if (a[yy, xx, :3] == MORTAR).all() and r.random() < grass:
                setp(a, xx, yy, r.choice(GRASS))
    for _ in range(int(grass * 30)):
        x, y = r.randrange(T), r.randrange(T)
        setp(a, x, y, r.choice(GRASS))
    return a


def dirt(seed, rubble=False):
    r = random.Random(seed)
    a = new(T, T)
    a[..., :3] = (140, 108, 76)
    a[..., 3] = 255
    for _ in range(24):
        setp(a, r.randrange(T), r.randrange(T), r.choice([(158, 124, 88), (122, 92, 66)]))
    if rubble:
        for _ in range(6):
            x, y = r.randrange(1, T - 2), r.randrange(1, T - 2)
            setp(a, x, y, STONE[3]); setp(a, x + 1, y, STONE[1]); setp(a, x, y + 1, STONE[2])
    return a


tiles = np.zeros((T * 4, T * 8, 4), np.uint8)
for i in range(8):
    tiles[0:T, i * T:(i + 1) * T] = cobbles(10 + i, 0.05)
    tiles[T:2 * T, i * T:(i + 1) * T] = cobbles(30 + i, 0.45)
    tiles[2 * T:3 * T, i * T:(i + 1) * T] = cobbles(50 + i, 0.02, big=True)
for i in range(4):
    tiles[3 * T:4 * T, i * T:(i + 1) * T] = dirt(70 + i)
    tiles[3 * T:4 * T, (4 + i) * T:(5 + i) * T] = dirt(80 + i, rubble=True)
Image.fromarray(tiles, "RGBA").save(os.path.join(P, "assets/tilesets/dracombra_tiles.png"))

# ------------------------------------------------------------------ bâtiments
CANVAS = [(214, 196, 160), (188, 168, 132), (150, 130, 100)]
WOOD = [(150, 106, 66), (120, 84, 52), (88, 60, 40)]
GUILD_RED = [(176, 52, 56), (140, 36, 44)]


def tent(w=34, h=28, color=CANVAS, banner=False):
    a = new(w, h)
    apex = (w // 2, 3)
    base_y = h - 3
    for y in range(apex[1], base_y + 1):
        half = int((y - apex[1]) / (base_y - apex[1]) * (w // 2 - 2))
        for x in range(apex[0] - half, apex[0] + half + 1):
            c = color[0] if x < apex[0] - 1 else color[1] if x < apex[0] + 2 else color[2]
            setp(a, x, y, c)
    # Ouverture sombre.
    for y in range(base_y - 9, base_y + 1):
        half = (y - (base_y - 9)) // 2
        for x in range(apex[0] - half, apex[0] + half + 1):
            setp(a, x, y, (52, 40, 34))
    for y in range(1, base_y):
        setp(a, apex[0], y if y < 4 else 0, WOOD[1])
    setp(a, apex[0], 1, WOOD[1]); setp(a, apex[0], 2, WOOD[1])
    if banner:
        for y in range(0, 7):
            for x in range(apex[0] + 1, apex[0] + 7):
                setp(a, x, y, GUILD_RED[0] if y < 5 else GUILD_RED[1])
        setp(a, apex[0] + 3, 2, (230, 200, 90))
    for x in range(2, w - 2):
        setp(a, x, base_y + 1, (60, 90, 50))
    return outline(a)


def chest(w=16, h=13):
    a = new(w, h)
    rect(a, 1, 3, w - 1, h - 1, WOOD[1])
    rect(a, 1, 3, w - 1, 6, WOOD[0])
    rect(a, 1, 6, w - 1, 7, (80, 76, 74))
    rect(a, 7, 5, 9, 9, (220, 190, 90))
    for y in range(3, h - 1):
        setp(a, 2, y, (80, 76, 74)); setp(a, w - 3, y, (80, 76, 74))
    return outline(a)


def workbench(w=30, h=20):
    a = new(w, h)
    rect(a, 1, 6, w - 1, 10, WOOD[0])
    rect(a, 1, 10, w - 1, 11, WOOD[2])
    for x in (3, w - 5):
        rect(a, x, 11, x + 2, h - 1, WOOD[1])
    # Outils : marteau, scie, planche.
    rect(a, 5, 3, 7, 6, (150, 150, 156)); rect(a, 6, 1, 7, 6, WOOD[1])
    rect(a, 12, 4, 20, 6, (190, 190, 196)); rect(a, 20, 4, 23, 6, WOOD[1])
    rect(a, 24, 5, 28, 6, (200, 170, 110))
    return outline(a)


def drying_rack(w=28, h=26):
    a = new(w, h)
    for x in (3, w - 4):
        rect(a, x, 2, x + 2, h - 1, WOOD[1])
    rect(a, 2, 3, w - 2, 5, WOOD[0])
    # Peaux tendues.
    for i, x in enumerate((6, 15)):
        rect(a, x, 5, x + 7, 16, [(150, 110, 80), (128, 92, 66)][i])
        rect(a, x + 1, 6, x + 6, 15, [(170, 130, 96), (146, 108, 78)][i])
    return outline(a)


def scaffold(w=32, h=26):
    a = new(w, h)
    for x in (2, w // 2, w - 4):
        rect(a, x, 3, x + 2, h - 1, WOOD[1])
    for y in (5, 13):
        rect(a, 1, y, w - 1, y + 2, WOOD[0])
    for i in range(0, w - 4, 2):
        setp(a, 2 + i, 6 + i // 3, WOOD[2])
    rect(a, 4, h - 6, 12, h - 1, STONE[1]); rect(a, 18, h - 5, 27, h - 1, WOOD[0])
    return outline(a)


def guild_tent(w=56, h=44):
    a = tent(w, h, color=[(196, 170, 130), (168, 140, 104), (130, 106, 80)], banner=True)
    return a


d = os.path.join(P, "assets/sprites/buildings")
os.makedirs(d, exist_ok=True)
for name, art in [("tent", tent()), ("chest", chest()), ("workbench", workbench()),
                  ("drying_rack", drying_rack()), ("scaffold", scaffold()), ("guild_tent", guild_tent())]:
    img = Image.fromarray(art, "RGBA")
    img.crop(img.getbbox()).save(os.path.join(d, name + ".png"))

# ------------------------------------------------------------------ icône de bois
items = Image.open(os.path.join(P, "assets/sprites/items/items.png")).convert("RGBA")
if items.width < 80:
    bigger = Image.new("RGBA", (80, 16))
    bigger.paste(items, (0, 0))
    items = bigger
icon = new(16, 16)
for k, (x0, y0) in enumerate([(2, 8), (5, 4)]):
    rect(icon, x0, y0, x0 + 10, y0 + 4, WOOD[1])
    rect(icon, x0, y0, x0 + 10, y0 + 1, WOOD[0])
    rect(icon, x0 + 9, y0, x0 + 11, y0 + 4, (196, 160, 110))
    setp(icon, x0 + 10, y0 + 2, WOOD[1])
icon = outline(icon, (50, 34, 24))
items.paste(Image.fromarray(icon, "RGBA"), (64, 0))
items.save(os.path.join(P, "assets/sprites/items/items.png"))
print("art ok")
