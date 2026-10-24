"""Carte de Dracombra : les ruines de l'ancienne capitale, où le héros bâtit sa ville.

La guilde est au centre. Des avenues pavées partent en étoile ; des boulevards en anneau
marquent la limite des quartiers (un quartier par palier de la guilde).
Légende :
  X lisière infranchissable   f forêt qui envahit les bords   . herbe
  p avenue pavée   P grande place   d terre battue du camp
  r décombres (à déblayer : pierre)   t arbre poussé dans les ruines (bois)
  L monument (statue, escaliers, braseros...)   G porte sud   E sortie vers la Sylve
  S arrivée depuis la Sylve   C guilde (centre)   Z réveil au camp
"""
import math
import random
import sys

W, H = 200, 150
CX, CY = 100, 74
ASPECT = 4.0 / 3.0
RINGS = [11.0, 24.0, 40.0, 58.0]
rnd = random.Random(31)
g = [["." for _ in range(W)] for _ in range(H)]


def dist(x, y):
    return math.hypot(x - CX, (y - CY) * ASPECT)


def noise(x, y, s):
    return (math.sin(x * 0.13 + s) + math.sin(y * 0.17 + s * 1.3) + math.sin((x - y) * 0.09 + s * 0.7)) / 3


# Forêt sur les bords, lisière infranchissable tout autour.
for y in range(H):
    for x in range(W):
        edge = min(x, y, W - 1 - x, H - 1 - y)
        if edge < 4 + 3 * (noise(x, y, 2.0) + 1):
            g[y][x] = "f"
        if edge == 0:
            g[y][x] = "X"


def pave(x, y, ch="p"):
    if 0 < x < W - 1 and 0 < y < H - 1 and g[y][x] != "X":
        g[y][x] = ch


# Avenues en étoile (8 directions), larges de 2 cases.
for k in range(8):
    a = k * math.pi / 4
    for s in range(0, 140):
        x = CX + math.cos(a) * s
        y = CY + math.sin(a) * s / ASPECT
        if not (1 <= x < W - 1 and 1 <= y < H - 1):
            break
        for dx in (0, 1):
            for dy in (0, 1):
                pave(int(x) + dx, int(y) + dy)
# Boulevards en anneau.
for r in RINGS:
    for i in range(int(r * 9)):
        a = 2 * math.pi * i / (r * 9)
        x = CX + math.cos(a) * r
        y = CY + math.sin(a) * r / ASPECT
        pave(int(round(x)), int(round(y)))
# Une avenue droite vers la porte sud.
for y in range(CY, H - 1):
    for x in (CX - 1, CX, CX + 1):
        pave(x, y)
# Grande place et camp.
for y in range(H):
    for x in range(W):
        if dist(x, y) <= 7.5:
            g[y][x] = "P"
        if dist(x - 0, y - 0) <= 3.2:
            g[y][x] = "d"

# Décombres et arbres dans les ruines : rares au centre, partout ailleurs.
for y in range(2, H - 2):
    for x in range(2, W - 2):
        if g[y][x] != ".":
            continue
        d = dist(x, y)
        if d < 9:
            continue
        p_rubble = 0.022 + 0.014 * (noise(x, y, 5.0) + 1)
        if rnd.random() < p_rubble:
            g[y][x] = "r"
        elif rnd.random() < 0.012 + 0.03 * max(0.0, noise(x, y, 8.0)):
            g[y][x] = "t"

# Porte sud et sortie.
gate_y = H - 6
for y in range(gate_y, H):
    for x in range(CX - 2, CX + 3):
        g[y][x] = "p"
for x in range(CX - 1, CX + 2):
    g[H - 2][x] = "E"
g[gate_y][CX] = "G"
g[gate_y - 2][CX] = "S"
g[CY][CX] = "C"
g[CY + 2][CX - 1] = "Z"

text = "\n".join("".join(r) for r in g)
open(sys.argv[1], "w").write(text + "\n")
print("dracombra", W, H, "centre", CX, CY)
