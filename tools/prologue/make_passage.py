"""Carte du passage du héros blessé (après la crevasse de la tanière).

Un boyau étroit et sinueux, une petite niche où il reprend son souffle,
puis une sortie vers la lumière du jour, à l'est.
Légende : # roche, . sol, P départ, H halte, E sortie, O lumière du jour,
c cristal, m champignon, b os, r petits éboulis.
"""
import math
import random
import sys

W, H = 76, 26
rnd = random.Random(7)
grid = [["#"] * W for _ in range(H)]
WAY = [(3, 13), (10, 12), (17, 15), (24, 16), (30, 12), (36, 10), (43, 12), (50, 15),
       (57, 14), (63, 11), (69, 12), (74, 12)]


def carve(x, y, r):
    for yy in range(int(y - r - 1), int(y + r + 2)):
        for xx in range(int(x - r - 1), int(x + r + 2)):
            if 1 <= xx < W - 1 and 2 <= yy < H - 2 and (xx - x) ** 2 + (yy - y) ** 2 <= r * r:
                grid[yy][xx] = "."


for (x0, y0), (x1, y1) in zip(WAY, WAY[1:]):
    steps = int(max(abs(x1 - x0), abs(y1 - y0)) * 3) + 1
    for i in range(steps + 1):
        t = i / steps
        carve(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, 1.6 + 0.5 * math.sin(i * 0.37))
# La niche de la halte, et la salle de sortie plus large.
for cx, cy, rx, ry in [(36, 9, 3.2, 2.4), (69, 12, 4.5, 3.4)]:
    for y in range(2, H - 2):
        for x in range(1, W - 1):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1:
                grid[y][x] = "."
for x in range(W - 1, W):
    for y in range(H):
        grid[y][x] = "#"


def floor(pred):
    return [(x, y) for y in range(H) for x in range(W) if grid[y][x] == "." and pred(x, y)]


def near_wall(x, y):
    return any(grid[y + dy][x + dx] == "#" for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))


def place(ch, cells, count, dist=4):
    rnd.shuffle(cells)
    done = []
    for x, y in cells:
        if len(done) >= count:
            break
        if grid[y][x] == "." and all(abs(x - a) + abs(y - b) >= dist for a, b in done):
            grid[y][x] = ch
            done.append((x, y))


grid[13][3] = "P"
grid[9][36] = "H"
place("c", floor(lambda x, y: 8 < x < 60 and near_wall(x, y)), 5, 9)
place("m", floor(lambda x, y: 8 < x < 64 and near_wall(x, y)), 6, 7)
place("b", floor(lambda x, y: 12 < x < 60 and near_wall(x, y)), 3, 12)
place("r", floor(lambda x, y: 5 < x < 64 and near_wall(x, y)), 5, 8)
ex = max(x for x, y in floor(lambda x, y: True))
for y in range(H):
    if grid[y][ex] == ".":
        grid[y][ex] = "E"
grid[12][ex - 1] = "O"
text = "\n".join("".join(r) for r in grid)
open(sys.argv[1], "w").write(text + "\n")
print(text)
