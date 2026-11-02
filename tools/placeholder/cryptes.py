#!/usr/bin/env python3
"""Zone 2 des Abysses, les cryptes des pionniers : décors et monstres PROVISOIRES dessinés par
le code (HD : affichés à l'échelle 0,5). Voir REGLES_ASSETS.md et assets/ETAT_ASSETS.md.
    python tools/placeholder/cryptes.py

Sorties :
  assets/sprites/props/crypt/*.png + scenes/props/crypt/*.tscn
  assets/sprites/enemies/crypt/{skeleton,skeleton_archer,wisp,crypt_rat,crypt_guardian}.png
"""
import math
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
O = (24, 18, 30, 255)

STONE = [(70, 72, 86), (104, 106, 122), (140, 142, 158), (176, 178, 192)]
BONE = [(120, 110, 90), (190, 180, 152), (232, 226, 206), (250, 248, 236)]
RUST = [(90, 50, 40), (140, 80, 50), (180, 120, 80)]
WAX = [(200, 190, 160), (236, 228, 200)]
FLAME = [(255, 170, 60), (255, 230, 140)]
WEB = (220, 220, 230, 150)
CLAY = [(110, 70, 52), (150, 98, 70), (186, 130, 96)]
GHOST = [(60, 150, 150), (120, 220, 210), (210, 255, 248)]
FUR = [(56, 46, 46), (86, 72, 70), (120, 104, 98)]


def rgba(t, a=255):
    return tuple(t[:3]) + (a,)


def new(w, h):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def outline(img):
    """Contour sombre d'un pixel autour de tout ce qui est dessiné."""
    src = img.copy()
    px = src.load()
    out = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            if px[x, y][3] > 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] > 200:
                    out[x, y] = O
                    break
    return img


# ------------------------------------------------------------------ décors

def sarcophagus(open_lid=False):
    img, d = new(72, 52)
    d.rectangle((6, 18, 66, 48), fill=rgba(STONE[1]))
    d.rectangle((6, 18, 66, 22), fill=rgba(STONE[2]))
    d.rectangle((6, 44, 66, 48), fill=rgba(STONE[0]))
    if open_lid:
        d.rectangle((10, 20, 62, 30), fill=(30, 26, 36, 255))
        d.polygon([(2, 12), (50, 4), (54, 12), (6, 20)], fill=rgba(STONE[2]))
        d.line((4, 15, 52, 8), fill=rgba(STONE[3]), width=2)
        d.ellipse((18, 21, 26, 28), fill=rgba(BONE[2]))
    else:
        d.polygon([(4, 10), (68, 10), (66, 20), (6, 20)], fill=rgba(STONE[2]))
        d.line((6, 11, 66, 11), fill=rgba(STONE[3]), width=2)
        d.rectangle((30, 12, 42, 18), fill=rgba(STONE[1]))
        d.line((36, 12, 36, 18), fill=rgba(STONE[3]))
    for x in (14, 58):
        d.line((x, 26, x, 42), fill=rgba(STONE[0]), width=2)
    return outline(img)


def candles():
    img, d = new(36, 40)
    for x, h in ((8, 18), (17, 26), (26, 14)):
        d.rectangle((x - 3, 38 - h, x + 3, 38), fill=rgba(WAX[0]))
        d.rectangle((x - 3, 38 - h, x - 1, 38), fill=rgba(WAX[1]))
        d.ellipse((x - 3, 30 - h, x + 3, 38 - h), fill=rgba(FLAME[0]))
        d.ellipse((x - 1, 32 - h, x + 1, 37 - h), fill=rgba(FLAME[1]))
    d.ellipse((2, 34, 34, 40), fill=rgba(WAX[0], 200))
    return outline(img)


def candelabra():
    img, d = new(36, 76)
    d.line((18, 20, 18, 70), fill=rgba(RUST[1]), width=3)
    d.polygon([(8, 74), (28, 74), (18, 64)], fill=rgba(RUST[0]))
    d.arc((6, 10, 30, 30), 0, 180, fill=rgba(RUST[1]), width=3)
    for x in (6, 18, 30):
        d.rectangle((x - 2, 8, x + 2, 20), fill=rgba(WAX[1]))
        d.ellipse((x - 3, 0, x + 3, 9), fill=rgba(FLAME[0]))
        d.ellipse((x - 1, 2, x + 1, 8), fill=rgba(FLAME[1]))
    return outline(img)


def cobweb():
    img, d = new(48, 48)
    for a in range(0, 91, 18):
        r = math.radians(a)
        d.line((0, 0, int(46 * math.cos(r)), int(46 * math.sin(r))), fill=WEB, width=1)
    for rad in (12, 22, 32, 42):
        pts = [(int(rad * math.cos(math.radians(a))), int(rad * math.sin(math.radians(a)))) for a in range(0, 91, 18)]
        d.line(pts, fill=WEB, width=1)
    return img


def bone_pile():
    img, d = new(44, 26)
    for (x1, y1, x2, y2) in ((4, 20, 30, 14), (12, 12, 38, 22), (8, 22, 40, 18)):
        d.line((x1, y1, x2, y2), fill=rgba(BONE[1]), width=4)
        for x, y in ((x1, y1), (x2, y2)):
            d.ellipse((x - 3, y - 3, x + 3, y + 3), fill=rgba(BONE[2]))
    d.ellipse((24, 2, 38, 16), fill=rgba(BONE[2]))
    d.rectangle((27, 9, 29, 11), fill=O)
    d.rectangle((33, 9, 35, 11), fill=O)
    return outline(img)


def pillar_broken():
    img, d = new(40, 76)
    d.rectangle((8, 20, 32, 70), fill=rgba(STONE[1]))
    d.rectangle((8, 20, 14, 70), fill=rgba(STONE[2]))
    d.rectangle((28, 20, 32, 70), fill=rgba(STONE[0]))
    d.polygon([(8, 20), (14, 10), (20, 16), (26, 6), (32, 18)], fill=rgba(STONE[2]))
    d.rectangle((4, 66, 36, 74), fill=rgba(STONE[2]))
    for y in (32, 46, 58):
        d.line((10, y, 30, y + 2), fill=rgba(STONE[0]))
    d.polygon([(30, 70), (40, 74), (34, 66)], fill=rgba(STONE[1]))
    return outline(img)


def urn():
    img, d = new(28, 40)
    d.ellipse((2, 10, 26, 38), fill=rgba(CLAY[1]))
    d.rectangle((8, 4, 20, 14), fill=rgba(CLAY[1]))
    d.rectangle((6, 2, 22, 6), fill=rgba(CLAY[2]))
    d.arc((4, 14, 24, 34), 200, 300, fill=rgba(CLAY[2]), width=2)
    d.line((5, 24, 23, 24), fill=rgba(CLAY[0]), width=2)
    return outline(img)


def cracked_wall():
    """Pan de mur fissuré (la salle secrète est derrière)."""
    img, d = new(64, 64)
    for row in range(4):
        off = 0 if row % 2 == 0 else 10
        for col in range(-1, 4):
            x = col * 20 + off
            y = row * 16
            d.rectangle((x + 1, y + 1, x + 19, y + 15), fill=rgba(STONE[1 + (row + col) % 2]))
    d.line((30, 2, 24, 18, 34, 30, 26, 44, 36, 62), fill=O, width=3)
    d.line((34, 30, 46, 36), fill=O, width=2)
    d.line((24, 18, 14, 22), fill=O, width=2)
    return outline(img)


PROPS = {
    "sarcophagus": (sarcophagus, False),
    "sarcophagus_open": (lambda: sarcophagus(True), False),
    "candles": (candles, True),
    "candelabra": (candelabra, True),
    "cobweb": (cobweb, False),
    "bone_pile": (bone_pile, False),
    "pillar_broken": (pillar_broken, False),
    "urn": (urn, False),
    "cracked_wall": (cracked_wall, False),
}

SCENE = """[gd_scene format=3]

[ext_resource type="Texture2D" path="res://assets/sprites/props/crypt/{name}.png" id="1_tex"]
{light_res}
[node name="{node}" type="Node2D"]

[node name="Sprite2D" type="Sprite2D" parent="."]
scale = Vector2(0.5, 0.5)
texture = ExtResource("1_tex")
centered = false
offset = Vector2({ox}, {oy})
{light_node}"""

LIGHT_RES = '[ext_resource type="Texture2D" path="res://assets/lights/light_radial.tres" id="2_light"]\n'
LIGHT_NODE = """
[node name="Light" type="PointLight2D" parent="."]
position = Vector2(0, {ly})
color = Color(1, 0.72, 0.42, 1)
energy = 0.9
texture = ExtResource("2_light")
texture_scale = 0.9
"""


def make_props():
    out_png = ROOT / "assets/sprites/props/crypt"
    out_tscn = ROOT / "scenes/props/crypt"
    out_png.mkdir(parents=True, exist_ok=True)
    out_tscn.mkdir(parents=True, exist_ok=True)
    for name, (fn, lit) in PROPS.items():
        img = fn()
        img.save(out_png / f"{name}.png")
        w, h = img.size
        node = "".join(p.capitalize() for p in name.split("_"))
        ox, oy = (0, 0) if name == "cobweb" else (-w // 2, -h + 4)
        light_node = LIGHT_NODE.format(ly=-h // 4) if lit else ""
        (out_tscn / f"{name}.tscn").write_text(SCENE.format(
            name=name, node=node, ox=ox, oy=oy, light_res=LIGHT_RES if lit else "", light_node=light_node), encoding="utf-8")
    print(f"{len(PROPS)} décors")


# ------------------------------------------------------------------ monstres

def skeleton_frame(d, cx, base, t, pose, archer=False):
    """Squelette debout, pieds à `base`. pose : idle, walk, attack, down."""
    bone, light = rgba(BONE[1]), rgba(BONE[2])
    if pose == "down":
        # S'effondre en tas d'os.
        k = t / 3.0
        top = int(base - 40 * (1 - k)) - 8
        for i in range(3):
            y = base - 4 - i * 3
            d.line((cx - 12 + i * 3, y, cx + 12 - i * 2, y - 2), fill=bone, width=3)
        d.ellipse((cx - 7 + int(8 * k), top, cx + 7 + int(8 * k), top + 14), fill=light)
        d.rectangle((cx - 3 + int(8 * k), top + 5, cx - 1 + int(8 * k), top + 7), fill=O)
        d.rectangle((cx + 2 + int(8 * k), top + 5, cx + 4 + int(8 * k), top + 7), fill=O)
        return
    bob = (t % 2) if pose in ("idle", "walk") else 0
    hip = base - 18
    sh = base - 34 + bob
    # Jambes.
    step = [-5, 0, 5, 0][t] if pose == "walk" else 0
    d.line((cx - 3, hip, cx - 4 + step, base), fill=bone, width=3)
    d.line((cx + 3, hip, cx + 4 - step, base), fill=bone, width=3)
    # Bassin, colonne, côtes.
    d.rectangle((cx - 6, hip - 2, cx + 6, hip + 2), fill=bone)
    d.line((cx, hip, cx, sh), fill=bone, width=2)
    for i in range(3):
        y = sh + 3 + i * 4
        d.arc((cx - 8, y - 3, cx + 8, y + 5), 200, 340, fill=light, width=2)
    # Crâne.
    d.ellipse((cx - 8, sh - 16, cx + 8, sh), fill=light)
    d.rectangle((cx - 5, sh - 4, cx + 5, sh + 1), fill=bone)
    d.rectangle((cx - 5, sh - 11, cx - 2, sh - 7), fill=O)
    d.rectangle((cx + 2, sh - 11, cx + 5, sh - 7), fill=O)
    if archer:
        # Arc tenu devant lui ; en attaque, la corde se tend.
        pull = [0, 4, 8, 0][t] if pose == "attack" else 0
        d.arc((cx + 4, sh - 6, cx + 20, sh + 22), 270, 90, fill=rgba(RUST[1]), width=2)
        d.line((cx + 12, sh - 5, cx + 12 - pull, sh + 8), fill=(230, 230, 230, 255))
        d.line((cx + 12 - pull, sh + 8, cx + 12, sh + 21), fill=(230, 230, 230, 255))
        d.line((cx, sh + 4, cx + 8 - pull, sh + 8), fill=bone, width=2)
        return
    # Bras et épée rouillée.
    angle = {"idle": 60, "walk": 60 + (t % 2) * 8}.get(pose, [10, -40, 80, 60][t])
    r = math.radians(angle)
    hx, hy = cx + 8 + int(10 * math.cos(r)), sh + 4 + int(10 * math.sin(r))
    d.line((cx + 6, sh + 2, hx, hy), fill=bone, width=2)
    r2 = math.radians(angle - 70)
    tx, ty = hx + int(20 * math.cos(r2)), hy + int(20 * math.sin(r2))
    d.line((hx, hy, tx, ty), fill=rgba(RUST[2]), width=3)
    d.line((cx - 6, sh + 2, cx - 9, sh + 14), fill=bone, width=2)


def sheet(rows, cols, cell, draw_fn):
    img = Image.new("RGBA", (cols * cell, rows * cell), (0, 0, 0, 0))
    for r in range(rows):
        for t in range(cols):
            tile, d = new(cell, cell)
            draw_fn(d, r, t, cell)
            outline(tile)
            img.alpha_composite(tile, (t * cell, r * cell))
    return img


def make_monsters():
    out = ROOT / "assets/sprites/enemies/crypt"
    out.mkdir(parents=True, exist_ok=True)
    poses = ["idle", "walk", "attack", "down"]
    sheet(4, 4, 64, lambda d, r, t, s: skeleton_frame(d, 30, 60, t, poses[r])).save(out / "skeleton.png")
    sheet(4, 4, 64, lambda d, r, t, s: skeleton_frame(d, 28, 60, t, poses[r], archer=True)).save(out / "skeleton_archer.png")

    def wisp(d, r, t, s):
        cy = 30 + [0, -2, -3, -2][t]
        if r == 1:
            k = 1.0 - t / 4.0
            rad = int(12 * k) + 2
            d.ellipse((32 - rad, cy - rad, 32 + rad, cy + rad), fill=rgba(GHOST[1], int(200 * k) + 40))
            return
        d.polygon([(22, cy), (32, cy - 24 + t), (42, cy)], fill=rgba(GHOST[0], 200))
        d.ellipse((20, cy - 10, 44, cy + 14), fill=rgba(GHOST[0], 210))
        d.ellipse((24, cy - 6, 40, cy + 10), fill=rgba(GHOST[1], 230))
        d.ellipse((28, cy - 2, 36, cy + 6), fill=rgba(GHOST[2]))
        for i in range(3):
            x = 24 + i * 8 + (t + i) % 2 * 2
            d.line((x, cy + 12, x - 2 + (t % 2) * 4, cy + 20), fill=rgba(GHOST[1], 160), width=2)
    sheet(2, 4, 64, wisp).save(out / "wisp.png")

    def rat(d, r, t, s):
        base = 52
        if r == 1:
            d.ellipse((14, base - 10, 44, base), fill=rgba(FUR[1]))
            d.line((14, base - 4, 4, base - 8 + t), fill=rgba((180, 120, 120)), width=2)
            return
        leg = [0, 3, 0, -3][t]
        d.line((44, base - 6, 58, base - 12 + leg), fill=rgba((180, 120, 120)), width=2)
        d.ellipse((16, base - 18, 46, base - 2), fill=rgba(FUR[1]))
        d.ellipse((20, base - 16, 40, base - 8), fill=rgba(FUR[2]))
        d.polygon([(16, base - 14), (4, base - 8), (16, base - 4)], fill=rgba(FUR[1]))
        d.ellipse((14, base - 20, 22, base - 12), fill=rgba(FUR[2]))
        d.rectangle((9, base - 12, 11, base - 10), fill=(220, 60, 60, 255))
        for x in (20, 40):
            d.line((x, base - 4, x + leg, base), fill=rgba(FUR[0]), width=2)
    sheet(2, 4, 64, rat).save(out / "crypt_rat.png")

    def guardian(d, r, t, s):
        cx, base = 64, 124
        # Grand chevalier squelette : armure rouillée, grand bouclier, épée large.
        bob = t % 2 if r in (0, 1) else 0
        step = [-8, 0, 8, 0][t] if r == 1 else 0
        hip, sh = base - 36, base - 70 + bob
        bone, light = rgba(BONE[1]), rgba(BONE[2])
        d.line((cx - 7, hip, cx - 9 + step, base), fill=rgba(RUST[0]), width=8)
        d.line((cx + 7, hip, cx + 9 - step, base), fill=rgba(RUST[0]), width=8)
        d.polygon([(cx - 22, sh), (cx + 22, sh), (cx + 16, hip + 4), (cx - 16, hip + 4)], fill=rgba(RUST[1]))
        d.polygon([(cx - 22, sh), (cx + 22, sh), (cx + 18, sh + 10), (cx - 18, sh + 10)], fill=rgba(RUST[2]))
        d.ellipse((cx - 14, sh - 30, cx + 14, sh + 2), fill=light)
        d.polygon([(cx - 16, sh - 18), (cx, sh - 42), (cx + 16, sh - 18)], fill=rgba(RUST[1]))
        d.rectangle((cx - 9, sh - 18, cx - 3, sh - 11), fill=(140, 230, 220, 255))
        d.rectangle((cx + 3, sh - 18, cx + 9, sh - 11), fill=(140, 230, 220, 255))
        # Bouclier à gauche.
        d.polygon([(cx - 46, sh), (cx - 20, sh - 4), (cx - 20, hip + 10), (cx - 33, hip + 26), (cx - 46, hip + 10)],
                  fill=rgba(STONE[1]))
        d.line((cx - 33, sh, cx - 33, hip + 20), fill=rgba(STONE[3]), width=3)
        d.line((cx - 44, sh + 18, cx - 22, sh + 16), fill=rgba(STONE[3]), width=3)
        # Épée : levée en attaque (r == 2), sinon tenue basse.
        angle = [20, -80, -120, 40][t] if r == 2 else (30 + bob * 4)
        a = math.radians(angle)
        hx, hy = cx + 26, sh + 16
        tx, ty = hx + int(52 * math.cos(a)), hy + int(52 * math.sin(a))
        d.line((cx + 18, sh + 6, hx, hy), fill=bone, width=5)
        d.line((hx, hy, tx, ty), fill=rgba(STONE[2]), width=7)
        d.line((hx, hy, tx, ty), fill=rgba(STONE[3]), width=2)
        if r == 3:
            # Invocation : runes vertes au sol.
            for i in range(6):
                ang = math.radians(i * 60 + t * 15)
                x, y = cx + int(40 * math.cos(ang)), base - 6 + int(10 * math.sin(ang))
                d.ellipse((x - 4, y - 3, x + 4, y + 3), fill=rgba(GHOST[2], 220))
    sheet(4, 4, 128, guardian).save(out / "crypt_guardian.png")
    print("5 planches de monstres")


if __name__ == "__main__":
    make_props()
    make_monsters()
