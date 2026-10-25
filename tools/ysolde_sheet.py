"""Planche d'Ysolde : 6 colonnes, rangées = attente face/dos/profil, marche face/dos/profil,
soin à genoux, mortier. Plus les icônes de hache et de pioche.
Usage : python3 ysolde_sheet.py <projet>"""
import sys; sys.path.insert(0, '.')
from slice import *
P = sys.argv[1]
SRC = '5dbd9ef5-image.png'
rgba = load_rgba(A + SRC)
al = rgba[..., 3] > 0

def defringe(img):
    a = np.asarray(img).copy()
    r, g, b = [a[..., k].astype(int) for k in range(3)]
    a[(r > 140) & (b > 120) & (g < 0.55 * np.minimum(r, b)), 3] = 0
    return Image.fromarray(a, 'RGBA')

def cut(x0, x1, y0, y1, n):
    dens = al[y0:y1].sum(0)
    step = (x1 - x0) / n
    edges = [x0]
    for k in range(1, n):
        c = int(x0 + k * step)
        lo, hi = c - int(step * 0.3), c + int(step * 0.3)
        edges.append(lo + int(np.argmin(dens[lo:hi])))
    edges.append(x1)
    out = []
    for i in range(n):
        sub = rgba[y0:y1, edges[i]:edges[i + 1]]
        ys = np.where(sub[..., 3].any(1))[0]
        out.append(keep_main(defringe(Image.fromarray(sub[ys[0]:ys[-1] + 1].copy(), 'RGBA')), max_gap=4))
    return out

rows = [
    cut(11, 456, 124, 348, 4), cut(491, 951, 124, 348, 4), cut(991, 1453, 124, 348, 4),
    cut(7, 535, 429, 643, 7)[:6], cut(540, 1000, 429, 643, 6), cut(1000, 1536, 429, 643, 7)[:6],
    cut(8, 629, 719, 912, 4), cut(643, 1233, 719, 912, 4),
]
ref = np.median([f.height for f in rows[0]])
s = 30.0 / ref
small = [[downscale(f, s) for f in r] for r in rows]
flat = quantize([f for r in small for f in r], 40)
it = iter(flat)
small = [[next(it) for _ in r] for r in small]
def anchor(img):
    a = np.asarray(img)[..., 3] > 0
    h = a.shape[0]
    xs = np.where(a[int(h * 0.3):int(h * 0.95)])[1]
    return float(np.median(xs)) if len(xs) else img.width / 2
anchors = [[anchor(f) for f in r] for r in small]
cw = int(max(2 * max(a, f.width - a) for r, ar in zip(small, anchors) for f, a in zip(r, ar))) + 2
cw += cw % 2
ch = max(f.height for r in small for f in r)
sheet = build_sheet(small, cw, ch, anchors)
sheet.save(P + '/assets/sprites/npc/ysolde.png')
print('scale %.3f cell %d x %d' % (s, cw, ch), sheet.size)
# Icônes hache (x 1283) et pioche (x 1406)
items = Image.open(P + '/assets/sprites/items/items.png').convert('RGBA')
for x0, w, dst in [(1283, 111, 288), (1406, 106, 304)]:
    sub = rgba[719:912, x0:x0 + w]
    ys = np.where(sub[..., 3].any(1))[0]
    img = defringe(Image.fromarray(sub[ys[0]:ys[-1] + 1].copy(), 'RGBA'))
    k = 15.0 / max(img.size)
    icon = defringe(downscale(img, k))
    icon = icon.crop(icon.getbbox())
    items.paste(Image.new('RGBA', (16, 16)), (dst, 0))
    items.alpha_composite(icon, (dst + (16 - icon.width) // 2, (16 - icon.height) // 2))
items.save(P + '/assets/sprites/items/items.png')
b = Image.new('RGBA', sheet.size, (96, 150, 70, 255)); b.alpha_composite(sheet)
b.resize((sheet.width * 3, sheet.height * 3), Image.NEAREST).save('ysolde_prev.png')
