#!/usr/bin/env python3
"""Assets PROVISOIRES du nouveau système de construction (3 novembre 2026).

Génère, aux bonnes emprises et sous les noms des futurs dessins ChatGPT
(voir claude/prompts-batiments-*.md dans le projet) :

  assets/sprites/buildings/<art>_<palier>.png   bâtiments, un fichier par palier
  assets/sprites/buildings/chantier_3x2_0.png   chantiers (0 = fondations, 1 = structure)
  assets/sprites/town/path_gravel.png ...       chemins : 4 tuiles répétables de 32 × 32 côte à côte

Règle des emprises : l'image fait la largeur de l'emprise (cases × 32 px HD) ; le sol de toute
l'emprise est dessiné en bas de l'image (cases × 32 de profondeur) ; le bâtiment monte au-dessus.
Les petits paliers comblent le vide avec des caisses, tonneaux et piquets.

    python tools/placeholder/construction.py
Le jour où le vrai dessin arrive, on écrase le PNG : rien à changer dans le code.
"""
from __future__ import annotations

import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).parent))
from placeholder import OUTLINE, ROOT, rect, save, shade  # noqa: E402

GROUND = (118, 150, 78)
DIRT = (150, 118, 80)
WOOD = (150, 100, 58)
PLANK = (178, 128, 74)
STONE = (150, 150, 158)
PLASTER = (226, 210, 176)
CLOTH = (222, 208, 170)
ROOF = {
    "logement": (70, 120, 190),
    "production": (190, 92, 50),
    "artisanat": (210, 160, 60),
    "stockage": (120, 120, 132),
}

# art, cases, rubrique, nombre de paliers, style du premier palier
BUILDINGS = [
    ("house", (3, 2), "logement", 3, "tente"),
    ("forge", (3, 2), "artisanat", 3, "abri"),
    ("sawmill", (3, 2), "production", 3, "abri"),
    ("tannery", (3, 2), "artisanat", 2, "abri"),
    ("warehouse", (3, 2), "stockage", 3, "tente"),
    ("workbench", (3, 2), "artisanat", 1, "abri"),
    ("herb_garden", (3, 2), "production", 1, "abri"),
    ("hunter_cabin", (3, 2), "production", 1, "bois"),
    ("quarry", (3, 2), "production", 1, "abri"),
]


def ground(d: ImageDraw.ImageDraw, w: int, h: int, top: int, rnd: random.Random):
    """Le sol de toute l'emprise, aux bords un peu irréguliers."""
    d.rounded_rectangle((1, top + 1, w - 2, top + h - 2), radius=6, fill=OUTLINE)
    d.rounded_rectangle((2, top + 2, w - 3, top + h - 3), radius=6, fill=GROUND)
    for _ in range(w * h // 60):
        x, y = rnd.randint(6, w - 7), rnd.randint(top + 5, top + h - 6)
        d.point((x, y), fill=shade(GROUND, rnd.choice([0.8, 1.15])))
    # Une allée de terre devant la porte (bas, au centre).
    d.rectangle((w // 2 - 6, top + int(h * 0.62), w // 2 + 5, top + h - 3), fill=DIRT)


def filler(d: ImageDraw.ImageDraw, x0: int, x1: int, y_foot: int, rnd: random.Random):
    """Comble une bande vide de l'emprise : caisses, tonneaux, piquets."""
    x = x0 + 3
    while x < x1 - 8:
        kind = rnd.choice(["caisse", "tonneau", "piquet", "piquet"])
        y = y_foot - rnd.randint(0, 10)
        if kind == "caisse":
            rect(d, x, y - 8, x + 8, y, PLANK)
            d.line((x, y - 4, x + 8, y - 4), fill=shade(PLANK, 0.75))
            x += 12
        elif kind == "tonneau":
            rect(d, x, y - 9, x + 6, y, WOOD)
            d.line((x, y - 6, x + 6, y - 6), fill=(90, 90, 96))
            x += 10
        else:
            rect(d, x, y - 12, x + 1, y, WOOD)
            x += 6


def building(art: str, cases: tuple[int, int], cat: str, level: int, first: str) -> Image.Image:
    cw, ch = cases
    w, gh = cw * 32, ch * 32
    bh = 30 + level * 12  # hauteur du bâtiment au-dessus de son pied
    img = Image.new("RGBA", (w, gh + bh + 10), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rnd = random.Random(f"{art}{level}")
    top = img.height - gh
    ground(d, w, gh, top, rnd)
    roof = ROOF[cat]
    frac = [0.62, 0.8, 0.94][level]
    bw = int(w * frac)
    bx0 = (w - bw) // 2
    bx1 = bx0 + bw
    foot = top + int(gh * 0.62)  # le pied du bâtiment : au fond de l'emprise, l'allée devant
    wall_h = 12 + level * 6
    style = first if level == 0 else ("bois" if level == 1 else "pierre")
    if style == "tente":
        d.polygon([(bx0, foot), (bx1, foot), ((bx0 + bx1) // 2, foot - bh + 4)], fill=OUTLINE)
        d.polygon([(bx0 + 2, foot - 1), (bx1 - 2, foot - 1), ((bx0 + bx1) // 2, foot - bh + 7)], fill=CLOTH)
        d.polygon([(w // 2 - 6, foot - 1), (w // 2 + 6, foot - 1), (w // 2, foot - 16)], fill=(70, 50, 40))
    elif style == "abri":
        for px in (bx0 + 3, bx1 - 5):
            rect(d, px, foot - wall_h - 6, px + 2, foot, WOOD)
        rect(d, bx0, foot - wall_h - 14, bx1, foot - wall_h - 6, roof)
        d.line((bx0, foot - wall_h - 11, bx1, foot - wall_h - 11), fill=shade(roof, 1.25))
        rect(d, w // 2 - 7, foot - 8, w // 2 + 7, foot, (110, 110, 118))  # établi / billot / enclume
    else:
        wall = WOOD if style == "bois" else PLASTER
        rect(d, bx0 + 2, foot - wall_h, bx1 - 2, foot, wall)
        if style == "bois":
            for yy in range(foot - wall_h + 4, foot, 4):
                d.line((bx0 + 2, yy, bx1 - 2, yy), fill=shade(wall, 0.8))
        else:
            rect(d, bx0 + 2, foot - 6, bx1 - 2, foot, STONE)  # soubassement
            for xx in (bx0 + 10, bx1 - 12):
                rect(d, xx, foot - wall_h + 4, xx + 6, foot - wall_h + 10, (250, 220, 130))  # fenêtres éclairées
            rect(d, bx1 - 18, foot - wall_h - bh + 18, bx1 - 12, foot - wall_h - 8, STONE)  # cheminée
        roof_h = bh - wall_h - 2
        d.polygon([(bx0 - 2, foot - wall_h + 1), (bx1 + 1, foot - wall_h + 1), ((bx0 + bx1) // 2, foot - wall_h - roof_h)],
                  fill=OUTLINE)
        d.polygon([(bx0, foot - wall_h - 1), (bx1 - 1, foot - wall_h - 1), ((bx0 + bx1) // 2, foot - wall_h - roof_h + 3)],
                  fill=roof)
        d.line(((bx0 + bx1) // 2, foot - wall_h - roof_h + 4, bx0 + 2, foot - wall_h - 2), fill=shade(roof, 1.3))
        rect(d, w // 2 - 4, foot - 11, w // 2 + 4, foot, (100, 64, 36))  # porte en bas au centre
    # Le vide autour du bâtiment est comblé.
    filler(d, 4, bx0, top + gh - 6, rnd)
    filler(d, bx1, w - 4, top + gh - 6, rnd)
    return img


def chantier(cases: tuple[int, int], stage: int) -> Image.Image:
    cw, ch = cases
    w, gh = cw * 32, ch * 32
    bh = 20 if stage == 0 else 44
    img = Image.new("RGBA", (w, gh + bh), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rnd = random.Random(f"chantier{cw}{ch}{stage}")
    top = img.height - gh
    d.rounded_rectangle((1, top + 1, w - 2, top + gh - 2), radius=4, fill=OUTLINE)
    d.rounded_rectangle((2, top + 2, w - 3, top + gh - 3), radius=4, fill=DIRT)
    # Piquets et cordeaux qui délimitent l'emprise.
    for x in (4, w - 6):
        for y in (top + 5, top + gh - 4):
            rect(d, x, y - 8, x + 1, y, WOOD)
    d.line((5, top + 0, w - 5, top + 0), fill=(240, 230, 200))
    d.line((5, top + gh - 9, w - 5, top + gh - 9), fill=(240, 230, 200))
    foot = top + gh - 14
    if stage == 0:
        for i in range(cw * 2):  # pierres de fondation
            x = 8 + i * (w - 16) // (cw * 2)
            rect(d, x, foot - 4, x + 6, foot, STONE)
    else:
        for x in range(8, w - 8, 14):  # charpente
            rect(d, x, foot - bh + 6, x + 2, foot, PLANK)
        rect(d, 6, foot - bh + 4, w - 6, foot - bh + 6, PLANK)
        rect(d, 6, foot - bh // 2, w - 6, foot - bh // 2 + 1, PLANK)
    filler(d, w - 30, w - 6, top + gh - 6, rnd)
    return img


def path_tiles(kind: str) -> Image.Image:
    img = Image.new("RGBA", (128, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for v in range(4):
        rnd = random.Random(f"{kind}{v}")
        ox = v * 32
        if kind == "gravel":
            d.rectangle((ox, 0, ox + 31, 31), fill=(176, 160, 128))
            for _ in range(70):
                x, y = rnd.randrange(32), rnd.randrange(32)
                c = rnd.choice([(200, 196, 186), (150, 136, 110), (214, 200, 166), (128, 118, 100)])
                for dx, dy in ((0, 0), (1, 0), (0, 1)) if rnd.random() < 0.4 else ((0, 0),):
                    d.point((ox + (x + dx) % 32, (y + dy) % 32), fill=c)
        elif kind == "cobble":
            d.rectangle((ox, 0, ox + 31, 31), fill=(92, 78, 62))
            for row in range(4):
                shift = 4 if row % 2 else 0
                for col in range(4):
                    x = (col * 8 + shift + rnd.randint(0, 1)) % 32
                    y = row * 8
                    c = rnd.choice([(150, 150, 156), (168, 166, 170), (136, 136, 144)])
                    for yy in range(y + 1, y + 7):
                        for xx in range(x + 1, x + 7):
                            if (xx - x in (1, 6)) and (yy - y in (1, 6)):
                                continue
                            d.point((ox + xx % 32, yy), fill=c)
                    d.point((ox + (x + 2) % 32, y + 2), fill=shade(c, 1.2))
            if rnd.random() < 0.7:
                d.point((ox + rnd.randrange(32), rnd.randrange(32)), fill=(90, 140, 70))
        else:
            d.rectangle((ox, 0, ox + 31, 31), fill=(120, 112, 100))
            for sy in (0, 16):
                for sx in (0, 16):
                    c = rnd.choice([(206, 198, 180), (196, 188, 170), (214, 206, 190)])
                    d.rectangle((ox + sx + 1, sy + 1, ox + sx + 15, sy + 15), fill=c)
                    if rnd.random() < 0.35:  # fissure
                        x, y = sx + rnd.randint(4, 11), sy + rnd.randint(4, 11)
                        for k in range(4):
                            d.point((ox + x + k, y + (k % 2)), fill=shade(c, 0.7))
                    if rnd.random() < 0.2:  # écailles gravées
                        for k in range(3):
                            d.arc((ox + sx + 4 + k * 3, sy + 6, ox + sx + 8 + k * 3, sy + 10), 0, 180, fill=shade(c, 0.78))
    return img


def main():
    out = ROOT / "assets/sprites/buildings"
    for art, cases, cat, levels, first in BUILDINGS:
        for lv in range(levels):
            img = building(art, cases, cat, lv, first)
            meta = {"cell": [img.width, img.height], "anchor": [img.width // 2, img.height], "scale": 0.5,
                    "footprint": list(cases), "palier": lv, "provisoire": True}
            save(img, meta, out, f"{art}_{lv}", f"bâtiment {cases[0]}x{cases[1]} palier {lv} (généré, emprise réservée)")
    for cases in ((3, 2), (4, 4)):
        for st in (0, 1):
            img = chantier(cases, st)
            meta = {"cell": [img.width, img.height], "anchor": [img.width // 2, img.height], "scale": 0.5,
                    "footprint": list(cases), "provisoire": True}
            save(img, meta, out, f"chantier_{cases[0]}x{cases[1]}_{st}",
                 f"chantier {cases[0]}x{cases[1]} {'fondations' if st == 0 else 'structure'} (généré)")
    for kind in ("gravel", "cobble", "slab"):
        img = path_tiles(kind)
        meta = {"tile": [32, 32], "variants": 4, "scale": 0.5, "provisoire": True}
        save(img, meta, ROOT / "assets/sprites/town", f"path_{kind}", f"chemin {kind} : 4 tuiles répétables (généré)")


if __name__ == "__main__":
    main()
