"""Planche du héros blessé : boiter, s'effondrer, allongé, assis au feu, se relever."""
import sys; sys.path.insert(0, '.'); sys.path.insert(0, '../props')
from slice import *
from seg import segment
rgba, objs = segment('4050a994-image.png', dilate=3, min_area=300)
def defringe(img):
    a = np.asarray(img).copy()
    r, g, b = [a[..., k].astype(int) for k in range(3)]
    pink = (r > 140) & (b > 120) & (g < 0.55 * np.minimum(r, b))
    a[pink, 3] = 0
    return Image.fromarray(a, 'RGBA')
def box(i, x1=None):
    y0, x0, y1, xe = objs[i]
    return Image.fromarray(rgba[y0:y1, x0:(x1 if x1 else xe)].copy(), 'RGBA')
rows_src = [
    [box(i) for i in range(6)],                       # boiter
    [box(i) for i in [6, 7, 8, 9]],                   # s'effondrer
    [box(10), box(11)],                               # allongé
    [box(12, 525), box(13, 1010)],                    # assis (sans le feu)
    [box(i) for i in [16, 17, 14, 15]],               # se relever
]
S = 31 / objs[15][2].__sub__(objs[15][0])
small = [[keep_main(defringe(downscale(keep_main(defringe(f), max_gap=4), S)), max_gap=2) for f in r] for r in rows_src]
flat = quantize([f for r in small for f in r], 36)
it = iter(flat); small = [[next(it) for _ in r] for r in small]
anchors = [[body_anchor_x(f, 0.1, 0.6) if j in (0, 4) else f.width / 2 for f in r] for j, r in enumerate(small)]
cw = int(max(2 * max(a, f.width - a) for r, ar in zip(small, anchors) for f, a in zip(r, ar))) + 2
cw += cw % 2
ch = max(f.height for r in small for f in r)
sheet = build_sheet(small, cw, ch, anchors)
sheet.save('hero_wounded.png')
print('scale %.3f cell %d x %d sheet %s' % (S, cw, ch, sheet.size))
b = Image.new('RGBA', sheet.size, (96, 140, 80, 255)); b.alpha_composite(sheet)
b.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST).save('hero_wounded_prev.png')
