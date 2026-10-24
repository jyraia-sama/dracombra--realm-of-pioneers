"""Retexture le tileset de caverne à partir des textures ChatGPT (sols, rochers, falaises).

Garde la disposition du tileset d'origine (voir make_tileset.py) :
  lignes 0-1 : roche, index = côtés ouverts (N=1, E=2, S=4, O=8)
  ligne 2    : sols de la caverne (8 variantes)
  ligne 3    : décors (inchangés, sauf éboulis retexturés)
  ligne 4    : variantes de roche, index 4, 4, 4, 0, 0, 5, 6, 12
  ligne 5    : NOUVEAU, sols de la tanière (roche brûlée, veines de lave)
Usage : python3 make_tileset2.py <ancien cave_tiles.png> <sortie.png>
"""
import random
import sys
import numpy as np
from PIL import Image

sys.path.insert(0, '../props')
sys.path.insert(0, '../assets2')
from seg import segment
from slice import downscale, quantize

T = 16
OLD, OUT = sys.argv[1], sys.argv[2]
rgba, objs = segment('cb8a7007-image.png', dilate=3)


def piece(i, inset=0):
    y0, x0, y1, x1 = objs[i]
    return Image.fromarray(rgba[y0 + inset:y1 - inset, x0 + inset:x1 - inset].copy(), 'RGBA')


def defringe(img):
    """Retire les bavures roses laissées par le fond magenta sur les bords."""
    a = np.asarray(img).copy()
    r, g, b = [a[..., k].astype(int) for k in range(3)]
    pink = (r > 70) & (b > 70) & (g < 0.62 * np.minimum(r, b))
    a[pink, 3] = 0
    return Image.fromarray(a, 'RGBA')


def small(img, scale):
    return downscale(img, scale)


def seamless(tile, border=4):
    """Fond les bords avec le côté opposé pour que la tuile se répète sans couture."""
    a = np.asarray(tile).astype(float)
    h, w = a.shape[:2]
    out = a.copy()
    for k in range(border):
        t = 0.5 * (1 - k / border)
        out[:, k] = a[:, k] * (1 - t) + a[:, w - 1 - k] * t
        out[:, w - 1 - k] = a[:, w - 1 - k] * (1 - t) + a[:, k] * t
    a = out.copy()
    for k in range(border):
        t = 0.5 * (1 - k / border)
        out[k] = a[k] * (1 - t) + a[h - 1 - k] * t
        out[h - 1 - k] = a[h - 1 - k] * (1 - t) + a[k] * t
    out[..., 3] = 255
    return Image.fromarray(out.round().astype(np.uint8), 'RGBA')


def floor_tiles(i, scale, count, seed, calm=True):
    """Tuiles de sol découpées dans une texture. calm=True garde les découpes
    les plus unies (sans gros caillou), pour que la répétition ne se voie pas."""
    tex = small(piece(i, inset=6), scale)
    rnd = random.Random(seed)
    cands = []
    for _ in range(80):
        x = rnd.randrange(0, tex.width - T)
        y = rnd.randrange(0, tex.height - T)
        t = seamless(tex.crop((x, y, x + T, y + T)))
        lum = np.asarray(t)[..., :3].astype(float).mean(2)
        cands.append((lum.std(), x, y, t))
    cands.sort(key=lambda c: c[0])
    if not calm:
        cands = cands[len(cands) // 2:]
    picked = []
    for c in cands:
        if all(abs(c[1] - p[1]) + abs(c[2] - p[2]) > 10 for p in picked):
            picked.append(c)
        if len(picked) == count:
            break
    return [c[3] for c in picked]


# ------------------------------------------------------------------ sols
S = 0.29
cave_floor = floor_tiles(0, S, 4, 1) + floor_tiles(2, S, 1, 3) + floor_tiles(0, S, 1, 9, calm=False) \
    + floor_tiles(1, S, 1, 2) + floor_tiles(4, S, 1, 5, calm=False)
lair_floor = floor_tiles(2, S, 3, 6) + floor_tiles(0, S, 2, 10) + floor_tiles(3, S, 1, 7) + floor_tiles(5, S, 2, 8)

# ------------------------------------------------------------------ roche
# Paroi : la falaise à colonnes (pièce 15), réduite à 16 px de haut.
cliff_src = piece(15)
cliff = defringe(small(defringe(cliff_src), 0.29))                       # ~59 x 48
cliff_a = np.asarray(cliff)
cap_h, face_h = 5, 11
# Chapeau (sommets des colonnes) + bas des colonnes (avec l'ombre au pied).
face_full = np.concatenate([cliff_a[:cap_h], cliff_a[-face_h:]], axis=0)  # 16 x W
FACE_W = face_full.shape[1]

# Falaise haute (2 cases) : chapeau + 24 px de colonnes, à une échelle un peu plus grande.
tall_src = np.asarray(defringe(small(defringe(cliff_src), 0.25)))       # ~51 x 41
tall = np.concatenate([tall_src[:8], tall_src[-24:]], axis=0)          # 32 x W
TALL_W = tall.shape[1]


def tall_tile(part, e, w, seed):
    """Moitié haute (part=0) ou basse (part=1) d'une falaise de deux cases."""
    rnd = random.Random(seed)
    a = void_tile(rnd)
    ox = (TALL_W - T) // 2  # même découpe en haut et en bas : les colonnes se prolongent
    paste(a, tall[part * T:(part + 1) * T, ox:ox + T].copy(), 0, 0)
    top = 8 if part == 0 else 0
    if w:
        a[top:, 0, :3] = (a[top:, 0, :3] * 0.7).astype(np.uint8)
    if e:
        a[top:, T - 1, :3] = (a[top:, T - 1, :3] * 0.6).astype(np.uint8)
    return Image.fromarray(a, 'RGBA')


# Rochers de bordure : l'anneau de rochers (pièce 6), réduit.
ring = np.asarray(defringe(small(defringe(piece(6)), 0.24)))             # ~49 x 45
RW, RH = ring.shape[1], ring.shape[0]
VOID = np.array([22, 19, 28, 255], np.uint8)


def void_tile(rnd):
    a = np.zeros((T, T, 4), np.uint8)
    a[:] = VOID
    for _ in range(10):
        x, y = rnd.randrange(T), rnd.randrange(T)
        a[y, x, :3] = (28, 24, 35) if rnd.random() < 0.6 else (18, 15, 23)
    return a


def paste(dst, src, x, y):
    """Colle src (RGBA numpy) sur dst en respectant la transparence."""
    h, w = src.shape[:2]
    for j in range(h):
        for i in range(w):
            yy, xx = y + j, x + i
            if 0 <= yy < T and 0 <= xx < T and src[j, i, 3] > 0:
                dst[yy, xx] = src[j, i]


def rock_tile(mask, seed):
    rnd = random.Random(seed)
    a = void_tile(rnd)
    n, e, s, w = mask & 1, mask & 2, mask & 4, mask & 8
    rim = 6
    # Rangées de rochers le long des côtés qui donnent sur le sol.
    if n:
        ox = rnd.randrange(0, RW - T)
        paste(a, ring[:rim, ox:ox + T], 0, 0)
    if w:
        oy = rnd.randrange(0, RH - T)
        paste(a, ring[oy:oy + T, :rim], 0, 0)
    if e:
        oy = rnd.randrange(0, RH - T)
        paste(a, ring[oy:oy + T, RW - rim:], T - rim, 0)
    if s:
        ox = rnd.randrange(0, FACE_W - T)
        face = face_full[:, ox:ox + T].copy()
        # Le fond transparent de la falaise laisse voir le noir de la roche.
        paste(a, face, 0, 0)
        if w:
            a[cap_h:, 0, :3] = (a[cap_h:, 0, :3] * 0.7).astype(np.uint8)
        if e:
            a[cap_h:, T - 1, :3] = (a[cap_h:, T - 1, :3] * 0.6).astype(np.uint8)
    return Image.fromarray(a, 'RGBA')


# ------------------------------------------------------------------ éboulis
def rubble_block(seed):
    rnd = random.Random(seed)
    a = void_tile(rnd)
    ox, oy = rnd.randrange(0, RW - T), rnd.randrange(0, RH - T)
    # Un morceau de l'anneau, là où les rochers sont serrés.
    ring_crop = ring[oy:oy + T, ox:ox + T]
    paste(a, ring_crop, 0, 0)
    return Image.fromarray(a, 'RGBA')


pile = defringe(small(defringe(piece(14)), 0.19))
old = Image.open(OLD).convert('RGBA')
img = Image.new('RGBA', (T * 8, T * 8), (0, 0, 0, 0))
img.paste(old.crop((0, 3 * T, 8 * T, 4 * T)), (0, 3 * T))

rock_imgs = [rock_tile(m, 100 + m) for m in range(16)]
ALT = [4, 4, 4, 0, 0, 5, 6, 12]
alt_imgs = [rock_tile(m, 500 + i * 17) for i, m in enumerate(ALT)]
blocks = [rubble_block(21), rubble_block(22)]
# Ligne 6 : haut de falaise, index = côtés ouverts de la case (N=1, E=2, O=4).
uppers = [tall_tile(0, i & 2, i & 4, 700 + i) for i in range(8)]
# Ligne 7 : bas de falaise pour les masques 4, 6, 12, 14 (deux variantes chacun).
lowers = [tall_tile(1, m & 2, m & 8, 800 + k) for k, m in enumerate([4, 4, 6, 6, 12, 12, 14, 14])]
# Palette commune pour tout le tileset.
allq = quantize(rock_imgs + alt_imgs + blocks + cave_floor + lair_floor + [pile] + uppers + lowers, 40)
uppers, lowers = allq[43:51], allq[51:59]
rock_imgs, alt_imgs = allq[:16], allq[16:24]
blocks, cave_floor, lair_floor, pile = allq[24:26], allq[26:34], allq[34:42], allq[42]

for m, t in enumerate(rock_imgs):
    img.paste(t, ((m % 8) * T, (m // 8) * T))
for i, t in enumerate(cave_floor):
    img.paste(t, (i * T, 2 * T))
for i, t in enumerate(alt_imgs):
    img.paste(t, (i * T, 4 * T))
for i, t in enumerate(lair_floor):
    img.paste(t, (i * T, 5 * T))
# Éboulis : petits et gros.
img.paste(Image.new('RGBA', (T, T)), (3 * T, 3 * T))
img.alpha_composite(pile.crop((0, 0, min(T, pile.width), min(T, pile.height))),
                    (3 * T + max(0, (T - pile.width) // 2), 3 * T + max(0, T - pile.height)))
img.paste(blocks[0], (6 * T, 3 * T))
img.paste(blocks[1], (7 * T, 3 * T))
for i, t in enumerate(uppers):
    img.paste(t, (i * T, 6 * T))
for i, t in enumerate(lowers):
    img.paste(t, (i * T, 7 * T))
img.save(OUT)
print('saved', OUT, img.size, 'pile', pile.size, 'cliff', cliff.size, 'ring', ring.shape)
