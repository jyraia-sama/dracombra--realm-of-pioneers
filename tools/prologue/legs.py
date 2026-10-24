"""Accentue les pas de la marche du guerrier (les jambes de la planche bougent trop peu).
Pour chaque image de marche : une jambe se lève d'un pixel et avance, l'autre recule."""
import sys
import numpy as np
from PIL import Image
src, out = sys.argv[1], sys.argv[2]
CW, CH, COLS = 56, 34, 6
im = np.asarray(Image.open(src).convert('RGBA')).copy()
WALK_ROWS = [3, 4, 5]  # face, dos, profil
LIFT = [(0, 0), (1, 0), (1, 1), (0, 0), (0, 1), (0, 1)]  # (pied gauche levé ?, phase)
for r in WALK_ROWS:
    for i in range(COLS):
        cell = im[r * CH:(r + 1) * CH, i * CW:(i + 1) * CW].copy()
        alpha = cell[..., 3] > 0
        ys = np.where(alpha.any(1))[0]
        if len(ys) == 0:
            continue
        bottom = ys.max()
        leg_top = bottom - 5
        xs = np.where(alpha[leg_top:bottom + 1].any(0))[0]
        mid = int(np.median(xs))
        legs = cell[leg_top:bottom + 1].copy()
        new = cell.copy()
        new[leg_top:bottom + 1] = 0
        left = legs.copy(); left[:, mid:] = 0
        right = legs.copy(); right[:, :mid] = 0
        phase = i % 3
        lift_left = i < 3
        # Pied levé : remonte d'un pixel ; en profil, il avance aussi.
        side = r == 5
        for part, lifted, sign in [(left, lift_left, -1), (right, not lift_left, 1)]:
            dy = -1 if lifted and phase == 1 else 0
            dx = 0
            if side:
                dx = (1 if lifted else -1) * (1 if phase != 0 else 0)
            h = part.shape[0]
            for y in range(h):
                for x in range(CW):
                    if part[y, x, 3]:
                        ny, nx = leg_top + y + dy, x + dx
                        if 0 <= ny < CH and 0 <= nx < CW and new[ny, nx, 3] == 0:
                            new[ny, nx] = part[y, x]
        im[r * CH:(r + 1) * CH, i * CW:(i + 1) * CW] = new
Image.fromarray(im).save(out)
