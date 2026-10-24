"""Sanglier provisoire : planche 4 x 3 (marche, charge, mort), regard vers la droite."""
import sys
import numpy as np
from PIL import Image
P = sys.argv[1]
W, H = 30, 20
FUR = [(112, 78, 54), (88, 60, 42), (66, 44, 32), (140, 104, 72)]
OUT = (34, 24, 20)

def frame(leg_phase, head_down=0.0, fallen=0.0):
    a = np.zeros((H, W, 4), np.uint8)
    def p(x, y, c):
        if 0 <= x < W and 0 <= y < H:
            a[y, x] = (*c, 255)
    cx, cy = 13, 10 + int(fallen * 3)
    # Corps : ellipse, dos plus sombre, ventre clair, crête de soies.
    for y in range(H):
        for x in range(W):
            dx, dy = (x - cx) / 10.0, (y - cy) / 5.0
            if dx * dx + dy * dy <= 1:
                c = FUR[0]
                if dy < -0.45: c = FUR[1]
                if dy > 0.55: c = FUR[3]
                p(x, y, c)
    for x in range(5, 20, 2):
        p(x, cy - 5, FUR[2]); p(x + 1, cy - 6, FUR[2])
    # Tête et groin, tête baissée pendant la charge.
    hy = cy - 1 + int(head_down * 3)
    for y in range(hy - 3, hy + 4):
        for x in range(21, 27):
            if (x - 23) ** 2 / 9 + (y - hy) ** 2 / 10 <= 1:
                p(x, y, FUR[0] if y < hy + 1 else FUR[1])
    for y in range(hy, hy + 3):
        p(27, y, (180, 120, 110)); p(28, y, (150, 96, 90))
    p(24, hy - 1, (20, 16, 14))  # œil
    p(22, hy - 4, FUR[2]); p(23, hy - 4, FUR[2])  # oreille
    p(26, hy + 2, (240, 236, 220)); p(26, hy + 3, (240, 236, 220)); p(27, hy + 3, (240, 236, 220))  # défense
    # Pattes.
    if fallen < 0.5:
        legs = [(7, 0), (10, 2), (17, 1), (20, 3)]
        for i, (lx, ph) in enumerate(legs):
            off = int(round(np.sin((leg_phase + ph) * np.pi / 2) * 1.5))
            for y in range(cy + 4, cy + 8):
                p(lx + (off if y > cy + 5 else 0), y, FUR[2])
            p(lx + off, cy + 8, (40, 30, 26))
    else:
        for lx in (8, 12, 17, 21):
            p(lx, cy - 4, FUR[2]); p(lx, cy - 5, FUR[2])
    # Queue.
    p(3, cy - 2, FUR[2]); p(2, cy - 3, FUR[2])
    m = a[..., 3] > 0
    g = np.zeros_like(m)
    g[1:] |= m[:-1]; g[:-1] |= m[1:]; g[:, 1:] |= m[:, :-1]; g[:, :-1] |= m[:, 1:]
    a[g & ~m] = (*OUT, 255)
    if fallen >= 0.5:
        a = a[::-1].copy()
        ys = np.where(a[..., 3].any(1))[0]
        a = np.roll(a, H - 1 - ys.max(), axis=0)
    return a

rows = [[frame(i) for i in range(4)],
        [frame(i * 1.6, head_down=1.0) for i in range(4)],
        [frame(0, 0.5), frame(1, 0.8), frame(0, 0, fallen=1.0), frame(0, 0, fallen=1.0)]]
sheet = np.zeros((H * 3, W * 4, 4), np.uint8)
for r, row in enumerate(rows):
    for c, f in enumerate(row):
        sheet[r * H:(r + 1) * H, c * W:(c + 1) * W] = f
import os
os.makedirs(P + "/assets/sprites/enemies", exist_ok=True)
Image.fromarray(sheet, "RGBA").save(P + "/assets/sprites/enemies/boar.png")
print("boar ok")
