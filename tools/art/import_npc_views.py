#!/usr/bin/env python3
"""Importe une fiche de référence ChatGPT (3 vues côte à côte : face, dos, profil droit, fond magenta)
comme planche de PNJ immobile, sans passer par l'Atelier.

    python tools/art/import_npc_views.py fiche.png assets/sprites/npc/ysolde/ysolde.png --hauteur 52

Planche écrite : 4 colonnes × 3 lignes (face, dos, profil droit), cases de 48 × 64 px HD, pieds en bas au
centre. Chaque ligne : 2 images normales puis 2 images « respiration » (le haut du corps descend d'1 px).
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from import_building import block_reduce, key_out  # noqa: E402

CELL = (48, 64)


def split_views(img: Image.Image, n: int = 3) -> list[Image.Image]:
    a = img.getchannel("A")
    w, h = img.size
    cols = [any(a.getpixel((x, y)) for y in range(0, h, 3)) for x in range(w)]
    spans, start = [], None
    for x, c in enumerate(cols + [False]):
        if c and start is None:
            start = x
        elif not c and start is not None:
            if x - start > w * 0.05:
                spans.append((start, x))
            start = None
    spans = sorted(spans, key=lambda s: s[1] - s[0], reverse=True)[:n]
    spans.sort()
    return [img.crop((x0, 0, x1, h)).crop(img.crop((x0, 0, x1, h)).getbbox()) for x0, x1 in spans]


def breathe(fr: Image.Image) -> Image.Image:
    """Le haut du corps (au-dessus de la taille) descend d'1 pixel."""
    out = fr.copy()
    cut = int(fr.height * 0.55)
    top = fr.crop((0, 0, fr.width, cut))
    out.paste((0, 0, 0, 0), (0, 0, fr.width, cut))
    out.alpha_composite(top, (0, 1))
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("image")
    ap.add_argument("sortie")
    ap.add_argument("--hauteur", type=int, default=52)
    a = ap.parse_args()
    views = split_views(key_out(Image.open(a.image)))
    if len(views) != 3:
        sys.exit(f"3 vues attendues, {len(views)} trouvées")
    tallest = max(v.height for v in views)
    sheet = Image.new("RGBA", (CELL[0] * 4, CELL[1] * 3), (0, 0, 0, 0))
    for row, v in enumerate(views):
        # Même échelle pour les 3 vues : la plus grande fait `hauteur` px.
        f = tallest / a.hauteur
        small = block_reduce(v, max(1, round(v.width / f)))
        small = small.crop(small.getbbox())
        frames = [small, small, breathe(small), breathe(small)]
        for col, fr in enumerate(frames):
            x = col * CELL[0] + (CELL[0] - fr.width) // 2
            y = row * CELL[1] + CELL[1] - fr.height
            sheet.alpha_composite(fr, (x, y))
    out = Path(a.sortie)
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out)
    meta = {"cell": list(CELL), "anchor": [CELL[0] // 2, CELL[1]], "scale": 0.5, "dirs": ["bas", "haut", "droite"],
            "anims": {"idle": {"row": 0, "frames": 4, "fps": 2.5, "loop": True}}, "source": "ChatGPT"}
    out.with_suffix(".json").write_text(json.dumps(meta, ensure_ascii=False, indent=1), encoding="utf-8")
    print(out, sheet.size, [v.size for v in views])


if __name__ == "__main__":
    main()
