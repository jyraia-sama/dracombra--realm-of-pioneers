"""Icônes provisoires des nouveaux objets (16 x 16), ajoutées à droite de items.png."""
import sys
import numpy as np
from PIL import Image
P = sys.argv[1]
T = 16
OUT = (40, 30, 34)

def new():
    return np.zeros((T, T, 4), np.uint8)

def put(a, pts, c):
    for x, y in pts:
        if 0 <= x < T and 0 <= y < T:
            a[y, x] = (*c, 255)

def fill(a, x0, y0, x1, y1, c):
    put(a, [(x, y) for y in range(y0, y1) for x in range(x0, x1)], c)

def outline(a, col=OUT):
    m = a[..., 3] > 0
    g = np.zeros_like(m)
    g[1:] |= m[:-1]; g[:-1] |= m[1:]; g[:, 1:] |= m[:, :-1]; g[:, :-1] |= m[:, 1:]
    a[g & ~m] = (*col, 255)
    return a

def from_art(rows, pal):
    a = new()
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch in pal:
                a[y + (T - len(rows)) // 2, x + (T - len(r)) // 2] = (*pal[ch], 255)
    return outline(a)

icons = {}
icons["herb"] = from_art([
    "...g...", "..gGg..", ".gGlGg.", "gGlGlGg", ".gGlGg.", "..gGg..", "...s...", "...s...", "..s.s.."],
    {"g": (60, 130, 60), "G": (90, 170, 80), "l": (150, 210, 110), "s": (70, 100, 50)})
icons["flax"] = from_art([
    ".b.b.b.", ".s.s.s.", "..sss..", "...s...", "..sss..", ".s.s.s.", "...s...", "...s...", "...s..."],
    {"b": (120, 150, 230), "s": (190, 170, 100)})
icons["hide"] = from_art([
    ".hh.hh.", "hHHHHHh", ".HHHHH.", ".HHdHH.", ".HHHHH.", "hHHHHHh", ".hh.hh."],
    {"h": (120, 84, 56), "H": (150, 108, 74), "d": (120, 84, 56)})
icons["meat"] = from_art([
    "..rrr...", ".rRRRr..", "rRRwRRr.", "rRRRRRr.", ".rRRRbb.", "..rr.bWb", ".....bb."],
    {"r": (150, 40, 44), "R": (200, 70, 70), "w": (240, 200, 200), "b": (220, 210, 190), "W": (250, 250, 240)})
icons["leather"] = from_art([
    "LLLLLLL", "LlllllL", "LlLLLlL", "LlllllL", "LLLLLLL", ".s...s."],
    {"L": (110, 70, 40), "l": (140, 94, 56), "s": (80, 50, 30)})
icons["rope"] = from_art([
    "..rrr..", ".r...r.", "r.rrr.r", "r.r.r.r", "r.rrr.r", ".r...r.", "..rrr.."],
    {"r": (200, 176, 110)})
icons["cloth"] = from_art([
    "CCCCCCC", "CcCcCcC", "CCCCCCC", "CcCcCcC", "CCCCCCC", ".C.C.C."],
    {"C": (220, 210, 190), "c": (190, 180, 160)})
icons["gem"] = from_art([
    "..ggg..", ".gGwGg.", "gGGGGGg", ".gGGGg.", "..gGg..", "...g..."],
    {"g": (40, 120, 200), "G": (80, 170, 240), "w": (230, 250, 255)})
icons["balm"] = from_art([
    "..ccc..", "..www..", ".wgggw.", ".wgGgw.", ".wgggw.", "..www.."],
    {"c": (150, 100, 60), "w": (220, 220, 210), "g": (90, 170, 90), "G": (170, 230, 150)})
icons["bow"] = from_art([
    "..w....", ".w.s...", "w...s..", "w....s.", "w....s.", "w...s..", ".w.s...", "..w...."],
    {"w": (150, 100, 60), "s": (220, 210, 180)})
icons["staff"] = from_art([
    "...gg..", "..gGGg.", "...gg..", "...w...", "...w...", "...w...", "...w...", "...w...", "...w..."],
    {"g": (120, 60, 200), "G": (200, 150, 255), "w": (130, 90, 56)})
icons["holy_symbol"] = from_art([
    "...y...", "..yYy..", "yyyYyyy", "..yYy..", "...Y...", "...y...", "...y..."],
    {"y": (210, 170, 70), "Y": (250, 230, 140)})
icons["sword"] = from_art([
    "......s", ".....sS", "....sS.", "...sS..", ".hsS...", "..h....", ".h.h..."],
    {"s": (160, 160, 170), "S": (220, 220, 230), "h": (120, 80, 50)})
order = ["herb", "flax", "hide", "meat", "leather", "rope", "cloth", "gem", "balm", "bow", "staff", "holy_symbol", "sword"]
items = Image.open(P + "/assets/sprites/items/items.png").convert("RGBA")
base = 80
out = Image.new("RGBA", (base + T * len(order), T))
out.paste(items.crop((0, 0, base, T)), (0, 0))
for i, k in enumerate(order):
    out.paste(Image.fromarray(icons[k], "RGBA"), (base + i * T, 0))
out.save(P + "/assets/sprites/items/items.png")
for i, k in enumerate(order):
    print(k, base + i * T)
