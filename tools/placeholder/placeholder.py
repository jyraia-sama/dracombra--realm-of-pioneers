#!/usr/bin/env python3
"""Générateur d'assets PROVISOIRES pour Dracombra (voir REGLES_ASSETS.md).

Dessine par le code, sans IA d'image : des formes simples, lisibles, à la bonne taille,
avec un code couleur par catégorie. Chaque planche est écrite avec son .json (case, ancre,
animations) : le jour où le vrai dessin arrive, on écrase le PNG et le .json, rien d'autre.

Exemples (depuis la racine du projet) :
    python tools/placeholder/placeholder.py perso loup_garou --cat ennemi
    python tools/placeholder/placeholder.py perso bran --cat membre --classe archer
    python tools/placeholder/placeholder.py creature loup --taille 72x44 --couleur "#8a4a4a"
    python tools/placeholder/placeholder.py batiment forge --cases 3x2 --fonction production
    python tools/placeholder/placeholder.py ressource minerai_fer --type pierre
    python tools/placeholder/placeholder.py tout          # régénère tout catalogue.json

Sortie par défaut : assets/sprites/<dossier>/<nom>/<nom>.png (+ .json), et une ligne
PROVISOIRE dans assets/ETAT_ASSETS.md. Option --out pour choisir un autre dossier.
Dépendance : Pillow (pip install pillow).
"""
from __future__ import annotations

import argparse
import datetime
import json
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
STATE_FILE = ROOT / "assets" / "ETAT_ASSETS.md"
CATALOGUE = Path(__file__).with_name("catalogue.json")

OUTLINE = (28, 20, 34, 255)
SKIN = (240, 196, 160, 255)

# Code couleur par catégorie (REGLES_ASSETS.md §5) : (corps, accent).
CATEGORIES = {
    "heros": ((70, 110, 200), (230, 230, 240)),
    "membre": ((80, 130, 210), (230, 230, 240)),
    "pnj": ((225, 190, 70), (120, 80, 40)),
    "ennemi": ((200, 60, 60), (90, 30, 50)),
    "boss": ((150, 50, 170), (255, 210, 80)),
}
# Accent par classe (lumières de l'Atelier : doré clerc, cyan mage...).
CLASSES = {
    "guerrier": (175, 185, 200),
    "archer": (90, 170, 80),
    "mage": (80, 210, 230),
    "clerc": (240, 200, 70),
}
RESOURCES = {
    "bois": [(110, 70, 40), (150, 100, 55), (60, 140, 60), (95, 180, 75)],
    "pierre": [(95, 95, 105), (140, 140, 150), (185, 185, 195), (70, 70, 80)],
    "plante": [(60, 140, 60), (110, 190, 80), (170, 220, 110), (230, 210, 90)],
    "minerai": [(95, 95, 105), (140, 140, 150), (90, 210, 230), (200, 245, 255)],
}
ROOFS = {
    "production": (190, 90, 50),
    "logement": (70, 120, 190),
    "defense": (110, 110, 120),
    "guilde": (150, 60, 160),
    "commerce": (220, 170, 60),
}
DIRS = ["bas", "haut", "droite"]


# ------------------------------------------------------------------ outils de dessin

def shade(c, f):
    """Assombrit (f < 1) ou éclaircit (f > 1) une couleur."""
    r, g, b = c[:3]
    if f >= 1:
        return (int(r + (255 - r) * (f - 1)), int(g + (255 - g) * (f - 1)), int(b + (255 - b) * (f - 1)), 255)
    return (int(r * f), int(g * f), int(b * f), 255)


def rect(d: ImageDraw.ImageDraw, x0, y0, x1, y1, fill, outline=True):
    x0, y0, x1, y1 = (int(round(v)) for v in (x0, y0, x1, y1))
    if outline:
        d.rectangle((x0 - 1, y0 - 1, x1 + 1, y1 + 1), fill=OUTLINE)
    d.rectangle((x0, y0, x1, y1), fill=fill)


def ellipse(d: ImageDraw.ImageDraw, cx, cy, rx, ry, fill, outline=True):
    box = (int(round(cx - rx)), int(round(cy - ry)), int(round(cx + rx)), int(round(cy + ry)))
    if outline:
        d.ellipse((box[0] - 1, box[1] - 1, box[2] + 1, box[3] + 1), fill=OUTLINE)
    d.ellipse(box, fill=fill)


def save(img: Image.Image, meta: dict, out_dir: Path, name: str, statut_note: str):
    out_dir.mkdir(parents=True, exist_ok=True)
    png = out_dir / f"{name}.png"
    img.save(png)
    (out_dir / f"{name}.json").write_text(json.dumps(meta, ensure_ascii=False, indent=1), encoding="utf-8")
    register(png, statut_note)
    print(f"  {png.relative_to(ROOT) if png.is_relative_to(ROOT) else png}  ({img.width}×{img.height})")


def register(png: Path, note: str):
    """Ajoute (ou met à jour) la ligne PROVISOIRE de l'asset dans ETAT_ASSETS.md."""
    if not png.is_relative_to(ROOT / "assets") or not STATE_FILE.exists():
        return
    rel = "res://" + png.relative_to(ROOT).as_posix()
    today = datetime.date.today().isoformat()
    line = f"| `{rel}` | PROVISOIRE | {today} | {note} |"
    lines = STATE_FILE.read_text(encoding="utf-8").splitlines()
    for i, l in enumerate(lines):
        if f"`{rel}`" in l:
            if "| FINAL |" in l:
                print(f"  ⚠ {rel} est FINAL : la ligne n'est pas modifiée (le fichier a quand même été écrit !)")
                return
            lines[i] = line
            break
    else:
        # Insère à la fin du tableau des provisoires (marqueur dans le fichier).
        idx = next((i for i, l in enumerate(lines) if l.strip() == "<!-- fin provisoires -->"), len(lines))
        lines.insert(idx, line)
    STATE_FILE.write_text("\n".join(lines) + "\n", encoding="utf-8")


# ------------------------------------------------------------------ personnage (48×64)

PERSO_ANIMS = {  # nom: (images, fps, boucle)
    "idle": (2, 3, True),
    "walk": (4, 8, True),
    "attack": (3, 0, False),
    "harvest": (2, 0, False),
    "hurt": (1, 8, False),
    "death": (2, 5, False),
}


def draw_person(d, cx, foot, direction, anim, i, body, accent, size=1.0):
    """Petit personnage chibi, mains vides (l'outil est posé par le jeu)."""
    bob = 0
    leg_l = leg_r = 0
    arm = 0
    lean = 0
    if anim == "idle":
        bob = i % 2
    elif anim == "walk":
        bob = 1 if i % 2 else 0
        leg_l = [2, 0, -2, 0][i]
        leg_r = -leg_l
    elif anim in ("attack", "harvest"):
        arm = [-6, 6, 3][i] if anim == "attack" else [-5, 5][i]
        lean = [-1, 2, 1][i] if anim == "attack" else [-1, 1][i]
    elif anim == "hurt":
        lean = -3
    s = size
    hx = cx + (lean if direction == "droite" else 0)
    # Jambes
    for dx, off in ((-3, leg_l), (3, leg_r)):
        lx = cx + dx * s + (off if direction == "droite" else 0)
        ly = foot - (abs(off) // 2 if direction != "droite" else 0)
        rect(d, lx - 1.5 * s, ly - 9 * s, lx + 1.5 * s, ly, shade(body, 0.55))
    # Buste
    top = foot - 25 * s + bob
    rect(d, hx - 7 * s, top, hx + 7 * s, foot - 9 * s, body)
    rect(d, hx - 7 * s, foot - 12 * s, hx + 7 * s, foot - 10 * s, shade(accent, 0.9), outline=False)  # ceinture
    d.line((hx - 6 * s, top + 1, hx - 6 * s, foot - 13 * s), fill=shade(body, 1.3))  # reflet
    # Bras (le bras « avant » bouge pendant l'action)
    if direction == "droite":
        ax = hx + 2 * s + max(arm, 0)
        ay = top + 4 * s + (min(arm, 0) if arm < 0 else 0)
        rect(d, ax - 1.5 * s, ay, ax + 1.5 * s, ay + 9 * s, shade(body, 0.8))
        rect(d, ax - 1.5 * s, ay + 9 * s, ax + 1.5 * s, ay + 11 * s, SKIN)
    else:
        for side in (-1, 1):
            ax = hx + side * 9 * s
            lift = arm if side == 1 else 0
            ay = top + 3 * s - max(lift, 0)
            rect(d, ax - 1.5 * s, ay, ax + 1.5 * s, ay + 9 * s, shade(body, 0.8))
            rect(d, ax - 1.5 * s, ay + 9 * s, ax + 1.5 * s, ay + 11 * s, SKIN)
    # Tête
    hy = top - 9 * s
    ellipse(d, hx, hy, 9 * s, 9 * s, SKIN)
    # Cheveux / capuche à la couleur d'accent
    if direction == "haut":
        ellipse(d, hx, hy, 9 * s, 9 * s, accent)
    elif direction == "droite":
        d.pieslice((hx - 9 * s, hy - 9 * s, hx + 9 * s, hy + 9 * s), 150, 330, fill=accent)
        d.rectangle((hx + 4 * s, hy - 1, hx + 5 * s, hy + 1), fill=OUTLINE)  # œil
    else:
        d.pieslice((hx - 9 * s, hy - 9 * s, hx + 9 * s, hy + 9 * s), 180, 360, fill=accent)
        for ex in (-3, 3):
            d.rectangle((hx + ex * s, hy + 1, hx + ex * s + 1, hy + 3), fill=OUTLINE)


def perso(name: str, cat: str, classe: str | None, out: Path | None):
    body, accent = CATEGORIES[cat]
    if classe:
        accent = CLASSES[classe]
    cw, ch = 48, 64
    anims = list(PERSO_ANIMS.items())
    cols = max(n for n, _, _ in PERSO_ANIMS.values())
    rows = len(anims) * len(DIRS)
    img = Image.new("RGBA", (cw * cols, ch * rows), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    meta_anims = {}
    row = 0
    for anim, (count, fps, loop) in anims:
        meta_anims[anim] = {"row": row, "frames": count, "fps": fps, "loop": loop}
        for direction in DIRS:
            for i in range(count):
                ox, oy = i * cw, row * ch
                if anim == "death" and i == count - 1:
                    # Couché sur le côté.
                    tmp = Image.new("RGBA", (ch, ch), (0, 0, 0, 0))
                    draw_person(ImageDraw.Draw(tmp), ch // 2, ch - 2, "droite", "hurt", 0, body, accent)
                    tmp = tmp.rotate(90, expand=False).crop((0, 0, cw, ch))
                    img.alpha_composite(tmp, (ox, oy + 8))
                else:
                    a = "hurt" if anim == "death" else anim
                    draw_person(d, ox + cw // 2, oy + ch - 2, direction, a, i, body, accent)
            row += 1
    meta = {
        "cell": [cw, ch], "anchor": [cw // 2, ch - 2], "scale": 0.5, "dirs": DIRS,
        "anims": meta_anims, "provisoire": True,
    }
    save(img, meta, out or ROOT / "assets/sprites" / folder_for(cat) / name, name,
         f"perso {cat}{' ' + classe if classe else ''} (généré)")


def folder_for(cat):
    return {"heros": "hero", "membre": "guild", "pnj": "npc", "ennemi": "enemies", "boss": "bosses"}[cat]


# ------------------------------------------------------------------ créature (vue de profil, regard à droite)

def creature(name: str, size: str, color: str, out: Path | None):
    cw, ch = (int(v) for v in size.lower().split("x"))
    base = hex_color(color)
    anims = {"walk": (4, 8, True), "attack": (3, 0, False), "hurt": (1, 8, False), "death": (2, 5, False)}
    cols = 4
    img = Image.new("RGBA", (cw * cols, ch * len(anims)), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    meta_anims = {}
    for row, (anim, (count, fps, loop)) in enumerate(anims.items()):
        meta_anims[anim] = {"row": row, "frames": count, "fps": fps, "loop": loop}
        for i in range(count):
            ox, oy = i * cw, row * ch
            foot = oy + ch - 2
            bw, bh = cw * 0.32, ch * 0.24
            cx = ox + cw * 0.48 + ([0, 0, 4, 1][i] if anim == "attack" else 0)
            cy = foot - ch * 0.38 + (1 if anim == "walk" and i % 2 else 0)
            dead = anim == "death" and i == count - 1
            if dead:
                cy = foot - bh * 0.6
            if not dead:
                for k, lx in enumerate((-0.6, -0.25, 0.25, 0.6)):
                    sw = ([2, -2, 2, -2][k] * (1 if i % 2 else -1)) if anim == "walk" else 0
                    x = cx + lx * bw + sw
                    rect(d, x - 1.5, cy + bh * 0.5, x + 1.5, foot, shade(base, 0.55))
            ellipse(d, cx, cy, bw, bh, base)
            ellipse(d, cx - bw * 0.2, cy - bh * 0.35, bw * 0.5, bh * 0.25, shade(base, 1.25), outline=False)
            hx, hy = cx + bw * 0.95, cy - bh * 0.3
            ellipse(d, hx, hy, bh * 0.75, bh * 0.7, shade(base, 0.9))
            if not dead:
                d.rectangle((hx + bh * 0.25, hy - 2, hx + bh * 0.25 + 1, hy - 1), fill=(255, 240, 120, 255))
    meta = {"cell": [cw, ch], "anchor": [cw // 2, ch - 2], "scale": 0.5, "dirs": ["droite"],
            "anims": meta_anims, "provisoire": True}
    save(img, meta, out or ROOT / "assets/sprites/enemies" / name, name, f"créature {size} (générée)")


# ------------------------------------------------------------------ bâtiment

def batiment(name: str, cases: str, fonction: str, out: Path | None):
    w, h = (int(v) for v in cases.lower().split("x"))
    tw = w * 32
    wall_h = max(28, h * 22)
    roof_h = int(tw * 0.38)
    iw, ih = tw + 8, wall_h + roof_h + 6
    img = Image.new("RGBA", (iw, ih), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    wall = (222, 205, 170)
    roof = ROOFS.get(fonction, ROOFS["production"])
    x0, x1 = 4 + 2, iw - 4 - 3
    foot = ih - 2
    rect(d, x0, foot - wall_h, x1, foot, wall)
    for yy in range(foot - wall_h + 6, foot, 7):  # rangées de pierres
        d.line((x0, yy, x1, yy), fill=shade(wall, 0.85))
    door_w = 10
    dx = (x0 + x1) // 2
    rect(d, dx - door_w // 2, foot - 16, dx + door_w // 2, foot, (110, 70, 40))
    if w >= 2:
        for wx in (x0 + 8, x1 - 16):
            rect(d, wx, foot - wall_h + 8, wx + 7, foot - wall_h + 15, (120, 170, 210))
    d.polygon([(2, foot - wall_h + 2), (iw - 3, foot - wall_h + 2), (iw // 2, foot - wall_h - roof_h)],
              fill=OUTLINE)
    d.polygon([(4, foot - wall_h), (iw - 5, foot - wall_h), (iw // 2, foot - wall_h - roof_h + 3)], fill=roof)
    d.line((iw // 2, foot - wall_h - roof_h + 4, 6, foot - wall_h - 1), fill=shade(roof, 1.3))
    meta = {"cell": [iw, ih], "anchor": [iw // 2, ih - 2], "scale": 0.5, "footprint": [w, h],
            "fonction": fonction, "provisoire": True}
    save(img, meta, out or ROOT / "assets/sprites/buildings" / name, name, f"bâtiment {cases} {fonction} (généré)")


# ------------------------------------------------------------------ ressource récoltable

def ressource(name: str, kind: str, out: Path | None):
    pal = RESOURCES[kind]
    states = ["plein", "abime", "recolte"]
    cw, ch = (64, 80) if kind == "bois" else (32, 32)
    img = Image.new("RGBA", (cw * len(states), ch), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rnd = random.Random(name)
    for i, st in enumerate(states):
        ox = i * cw
        foot = ch - 2
        cx = ox + cw // 2
        if kind == "bois":
            if st == "recolte":
                ellipse(d, cx, foot - 4, 8, 4, pal[1])  # souche
                continue
            rect(d, cx - 4, foot - 26, cx + 4, foot, pal[0])
            r = 20 if st == "plein" else 15
            for k in range(5):
                a = k / 5 * math.tau
                ellipse(d, cx + math.cos(a) * r * 0.5, foot - 40 + math.sin(a) * r * 0.35, r * 0.6, r * 0.5, pal[2])
            ellipse(d, cx - 4, foot - 44, r * 0.5, r * 0.4, pal[3], outline=False)
        else:
            if st == "recolte":
                for _ in range(3):
                    x = cx + rnd.randint(-8, 8)
                    rect(d, x, foot - 2, x + 1, foot, pal[0], outline=False)
                continue
            r = 11 if st == "plein" else 8
            if kind == "plante":
                for k in range(6):
                    a = -math.pi / 2 + (k - 2.5) * 0.35
                    d.line((cx, foot, cx + math.cos(a) * r * 1.3, foot + math.sin(a) * r * 1.6), fill=pal[k % 2], width=2)
                ellipse(d, cx + 3, foot - r * 1.4, 2, 2, pal[3])
            else:
                ellipse(d, cx, foot - r * 0.7, r, r * 0.75, pal[1])
                ellipse(d, cx - 3, foot - r, r * 0.45, r * 0.3, pal[2], outline=False)
                if kind == "minerai":
                    for _ in range(3):
                        x, y = cx + rnd.randint(-6, 6), foot - rnd.randint(3, 12)
                        d.rectangle((x, y, x + 1, y + 1), fill=pal[rnd.choice((2, 3))])
    meta = {"cell": [cw, ch], "anchor": [cw // 2, ch - 2], "scale": 0.5, "states": states,
            "resource": kind, "provisoire": True}
    save(img, meta, out or ROOT / "assets/sprites/props" / name, name, f"ressource {kind} (générée)")


def hex_color(s: str):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16))


# ------------------------------------------------------------------ catalogue

def tout():
    data = json.loads(CATALOGUE.read_text(encoding="utf-8")) if CATALOGUE.exists() else {"assets": []}
    entries = data.get("assets", [])
    if not entries:
        print("catalogue.json est vide : rien à générer.")
    for e in entries:
        run(e)


def run(e: dict):
    out = Path(e["out"]) if e.get("out") else None
    kind = e["genre"]
    if kind == "perso":
        perso(e["nom"], e.get("cat", "ennemi"), e.get("classe"), out)
    elif kind == "creature":
        creature(e["nom"], e.get("taille", "64x48"), e.get("couleur", "#c84040"), out)
    elif kind == "batiment":
        batiment(e["nom"], e.get("cases", "2x2"), e.get("fonction", "production"), out)
    elif kind == "ressource":
        ressource(e["nom"], e.get("type", "pierre"), out)
    else:
        raise SystemExit(f"genre inconnu : {kind}")


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="genre", required=True)
    a = sub.add_parser("perso"); a.add_argument("nom"); a.add_argument("--cat", default="ennemi", choices=CATEGORIES)
    a.add_argument("--classe", choices=CLASSES); a.add_argument("--out")
    a = sub.add_parser("creature"); a.add_argument("nom"); a.add_argument("--taille", default="64x48")
    a.add_argument("--couleur", default="#c84040"); a.add_argument("--out")
    a = sub.add_parser("batiment"); a.add_argument("nom"); a.add_argument("--cases", default="2x2")
    a.add_argument("--fonction", default="production", choices=ROOFS); a.add_argument("--out")
    a = sub.add_parser("ressource"); a.add_argument("nom"); a.add_argument("--type", default="pierre", choices=RESOURCES)
    a.add_argument("--out")
    sub.add_parser("tout")
    args = vars(p.parse_args())
    if args["genre"] == "tout":
        tout()
    else:
        run({k: v for k, v in args.items() if v is not None})


if __name__ == "__main__":
    main()
