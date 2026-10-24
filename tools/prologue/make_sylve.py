"""Carte de la Sylve des Dracombres : la grande zone ouverte au sortir de la montagne.

Légende :
  #  montagne (roche)          M  entrée de la grotte (dans la falaise)
  .  herbe     ,  herbe fleurie   f  sous-bois (forêt)    X  lisière infranchissable
  d  chemin de terre   w  rivière   g  gué
  P  arrivée du héros   Z  là où il s'effondre   C  feu de camp (au réveil)
  R  centre des ruines de Dracombra   S  slime
"""
import math
import random
import sys

W, H = 150, 96
rnd = random.Random(11)
g = [["." for _ in range(W)] for _ in range(H)]


def noise(x, y, seed):
    return (math.sin(x * 0.11 + seed) + math.sin(y * 0.13 + seed * 1.7)
            + math.sin((x + y) * 0.07 + seed * 0.3) + 0.6 * math.sin(x * 0.31 - y * 0.23 + seed)) / 3.6


# --- Montagne au nord
mountain = [int(10 + 3 * math.sin(x * 0.09) + 2 * math.sin(x * 0.23 + 1) + rnd.random()) for x in range(W)]
for x in range(W):
    for y in range(mountain[x]):
        g[y][x] = "#"
# Adoucit le pied de la falaise (pas de marches d'une case).
CAVE_X = 22
for x in range(CAVE_X - 3, CAVE_X + 4):
    for y in range(H):
        g[y][x] = "#" if y < mountain[CAVE_X] else g[y][x]
        if y >= mountain[CAVE_X] and g[y][x] == "#":
            g[y][x] = "."
mouth_y = mountain[CAVE_X] - 1

# --- Rivière
river = {}
for y in range(H):
    cx = 104 + 7 * math.sin(y / 9.0) + 3 * math.sin(y / 3.7 + 1)
    river[y] = cx
    if y < mountain[int(cx)]:
        continue
    for x in range(int(cx - 2), int(cx + 2) + 1):
        g[y][x] = "w"
FORDS = [44, 78]

# --- Les ruines de Dracombra
RUINS = (60, 54)
# --- Chemin : grotte -> ruines -> gué -> l'est
path_pts = [(CAVE_X, mouth_y + 1), (24, 22), (32, 32), (44, 42), (RUINS[0] - 4, RUINS[1] - 4),
            (RUINS[0] + 8, RUINS[1] - 6), (84, 47), (int(river[FORDS[0]]) - 3, FORDS[0]),
            (int(river[FORDS[0]]) + 4, FORDS[0]), (120, 40), (138, 36)]
path = set()
for (x0, y0), (x1, y1) in zip(path_pts, path_pts[1:]):
    n = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
    for i in range(n + 1):
        t = i / n
        x = x0 + (x1 - x0) * t + math.sin(i * 0.3) * 0.6
        y = y0 + (y1 - y0) * t
        for dx in (0, 1):
            for dy in (0, 1):
                path.add((int(x) + dx, int(y) + dy))
# Branche sud vers le second gué.
for i in range(60):
    t = i / 59
    x = RUINS[0] + 4 + (river[FORDS[1]] - 4 - RUINS[0] - 4) * t
    y = RUINS[1] + 6 + (FORDS[1] - RUINS[1] - 6) * t
    path.add((int(x), int(y)))
    path.add((int(x) + 1, int(y)))

# Le parvis des ruines : de la terre battue entre les dalles.
for dx in range(-8, 9):
    for dy in range(-6, 7):
        if (dx / 8) ** 2 + (dy / 6) ** 2 <= 1:
            path.add((RUINS[0] + dx, RUINS[1] + dy))

# --- Forêts : lisières et bosquets
def edge_dist(x, y):
    return min(x, W - 1 - x, H - 1 - y)


protect = set()
for (x, y) in path:
    for dx in range(-3, 4):
        for dy in range(-3, 4):
            protect.add((x + dx, y + dy))
for dx in range(-14, 15):
    for dy in range(-11, 12):
        if (dx / 14) ** 2 + (dy / 11) ** 2 <= 1:
            protect.add((RUINS[0] + dx, RUINS[1] + dy))
for dx in range(-6, 7):
    for dy in range(0, 9):
        protect.add((CAVE_X + dx, mouth_y + dy))

for y in range(H):
    for x in range(W):
        if g[y][x] != ".":
            continue
        n = noise(x, y, 3.0)
        border = edge_dist(x, y) < 5 + 2.5 * (n + 1)
        grove = n > 0.42
        near_river = any(g[y][xx] == "w" for xx in range(max(0, x - 3), min(W, x + 4)))
        if (border or grove) and (x, y) not in protect and not near_river:
            g[y][x] = "f"
for y in range(H):
    for x in range(W):
        if edge_dist(x, y) == 0 and g[y][x] != "#":
            g[y][x] = "X"

# --- Chemin, gués, fleurs
for (x, y) in path:
    if 0 <= x < W and 0 <= y < H and g[y][x] in ".f":
        g[y][x] = "d"
for fy in FORDS:
    for x in range(W):
        if g[fy][x] == "w":
            g[fy][x] = "g"
            if g[fy + 1][x] == "w":
                g[fy + 1][x] = "g"
for y in range(H):
    for x in range(W):
        if g[y][x] == "." and noise(x, y, 9.0) > 0.35 and rnd.random() < 0.5:
            g[y][x] = ","

# --- Points de l'histoire
g[mouth_y][CAVE_X] = "M"
g[mouth_y + 2][CAVE_X] = "P"
REST = (RUINS[0] - 9, RUINS[1] - 7)
g[REST[1]][REST[0]] = "Z"
g[REST[1] + 1][REST[0] + 2] = "C"
g[RUINS[1]][RUINS[0]] = "R"
placed = 0
while placed < 8:
    x, y = rnd.randrange(92, W - 6), rnd.randrange(30, H - 6)
    if g[y][x] in ".," and abs(x - RUINS[0]) + abs(y - RUINS[1]) > 25:
        g[y][x] = "S"
        placed += 1

text = "\n".join("".join(r) for r in g)
open(sys.argv[1], "w").write(text + "\n")
print(text)
