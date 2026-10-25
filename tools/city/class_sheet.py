"""Planche d'une classe au format de warrior.png (6 colonnes, 18 rangées) :
attente / marche / attaque viennent de la planche de la classe ; roulade, touché et mort
reprennent ceux du guerrier en attendant.
Usage : python3 class_sheet.py <planche.png> <sortie.png>
"""
import sys; sys.path.insert(0, '.')
from slice import *
src, out = sys.argv[1], sys.argv[2]
TARGET = 30.0
rows = slice_sheet(A + src, [12, 18, 15], 20, clean=True)
groups = {
    'idle': [rows[0][0:4], rows[0][4:8], rows[0][8:12]],
    'walk': [rows[1][0:6], rows[1][6:12], rows[1][12:18]],
    'attack': [rows[2][0:5], rows[2][5:10], rows[2][10:15]],
}
ref = np.median([f.height for f in groups['idle'][0]])
s = TARGET / ref
warrior = Image.open('warrior.png')
CW, CH = 56, 34

def anchor(img):
    a = np.asarray(img).astype(int); m = a[..., 3] > 0
    h = m.shape[0]
    xs = np.where(m[int(h * 0.15):int(h * 0.95)])[1]
    return float(np.median(xs)) if len(xs) else img.width / 2

small = {k: [[downscale(f, s) for f in row] for row in v] for k, v in groups.items()}
flat = quantize([f for v in small.values() for row in v for f in row], 36)
it = iter(flat)
small = {k: [[next(it) for _ in row] for row in v] for k, v in small.items()}
sheet = warrior.copy()
order = {'idle': 0, 'walk': 3, 'attack': 9}
for k, first in order.items():
    for d in range(3):
        y = (first + d) * CH
        sheet.paste(Image.new('RGBA', (CW * 6, CH)), (0, y))
        for i, f in enumerate(small[k][d]):
            ax = anchor(f)
            x = i * CW + round(CW / 2 - ax)
            sheet.alpha_composite(f, (max(i * CW, x), y + CH - min(CH, f.height)) if f.height <= CH else (max(i * CW, x), y))
sheet.save(out)
print('scale %.3f' % s, sheet.size)
