#!/usr/bin/env python3
"""Importe un dessin de bâtiment ChatGPT (fond magenta) dans le jeu, sans passer par l'Atelier.

    python tools/art/import_building.py image.png house_1 --cases 3x2
    python tools/art/import_building.py image.png guild_0 --cases 4x4

1. Retire le fond magenta (et le liseré rose laissé par l'anticrénelage).
2. Recadre sur le dessin.
3. Réduit l'image pour que sa largeur fasse l'emprise : cases × 32 px HD (3x2 → 96 px, 4x4 → 128 px).
   Les « gros pixels » de ChatGPT font ~10 px : on réduit par blocs (couleur majoritaire du bloc),
   ce qui garde des pixels nets au lieu d'un flou.
4. Écrit assets/sprites/buildings/<nom>.png (+ .json) et passe la ligne de ETAT_ASSETS.md en FINAL.
Le bas de l'image est le bas de l'emprise (voir TAILLES.md §6).
"""
from __future__ import annotations

import argparse
import datetime
import json
from collections import Counter
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]


def magenta_score(r: int, g: int, b: int) -> float:
    """1 = magenta pur, 0 = rien à voir."""
    m = min(r, b) - g
    return max(0.0, min(1.0, (m - 40) / 120.0))


def key_out(img: Image.Image) -> Image.Image:
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            s = magenta_score(r, g, b)
            if s > 0.55:
                px[x, y] = (0, 0, 0, 0)
            elif s > 0.0:
                # Liseré : on retire la part de magenta de la couleur.
                k = s * 0.9
                px[x, y] = (int(max(0, r - (r - g) * k)), g, int(max(0, b - (b - g) * k)), a)
    return img


def block_reduce(img: Image.Image, out_w: int) -> Image.Image:
    w, h = img.size
    f = w / out_w
    out_h = max(1, round(h / f))
    out = Image.new("RGBA", (out_w, out_h), (0, 0, 0, 0))
    src = img.load()
    dst = out.load()
    for oy in range(out_h):
        y0, y1 = int(oy * f), max(int(oy * f) + 1, int((oy + 1) * f))
        for ox in range(out_w):
            x0, x1 = int(ox * f), max(int(ox * f) + 1, int((ox + 1) * f))
            cols = Counter()
            opaque = 0
            total = 0
            # On échantillonne le cœur du bloc (les bords mélangent deux gros pixels).
            m = max(0, int((x1 - x0) * 0.2))
            for y in range(y0 + m, min(h, y1 - m) if y1 - m > y0 + m else min(h, y1)):
                for x in range(x0 + m, min(w, x1 - m) if x1 - m > x0 + m else min(w, x1)):
                    r, g, b, a = src[x, y]
                    total += 1
                    if a > 0:
                        opaque += 1
                        cols[(r >> 3, g >> 3, b >> 3)] += 1
            if total == 0 or opaque * 2 < total:
                continue
            (qr, qg, qb), _ = cols.most_common(1)[0]
            # Moyenne des pixels de la couleur majoritaire (plus juste que le quantifié).
            sr = sg = sb = n = 0
            for y in range(y0, min(h, y1)):
                for x in range(x0, min(w, x1)):
                    r, g, b, a = src[x, y]
                    if a > 0 and (r >> 3, g >> 3, b >> 3) == (qr, qg, qb):
                        sr += r; sg += g; sb += b; n += 1
            dst[ox, oy] = (sr // max(1, n), sg // max(1, n), sb // max(1, n), 255)
    return out


def register(rel: str, note: str) -> None:
    state = ROOT / "assets" / "ETAT_ASSETS.md"
    if not state.exists():
        return
    line = f"| `{rel}` | FINAL | {datetime.date.today().isoformat()} | {note} |"
    lines = state.read_text(encoding="utf-8").splitlines()
    for i, l in enumerate(lines):
        if l.startswith(f"| `{rel}` |"):
            lines[i] = line
            break
    else:
        lines.append(line)
    state.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("image")
    ap.add_argument("nom")
    ap.add_argument("--cases", default="3x2")
    a = ap.parse_args()
    cw, ch = (int(v) for v in a.cases.lower().split("x"))
    img = key_out(Image.open(a.image))
    img = img.crop(img.getbbox())
    out = block_reduce(img, cw * 32)
    out = out.crop(out.getbbox())
    dst = ROOT / "assets/sprites/buildings" / f"{a.nom}.png"
    out.save(dst)
    meta = {"cell": [out.width, out.height], "anchor": [out.width // 2, out.height], "scale": 0.5,
            "footprint": [cw, ch], "source": "ChatGPT", "provisoire": False}
    dst.with_suffix(".json").write_text(json.dumps(meta, ensure_ascii=False, indent=1), encoding="utf-8")
    register("res://" + dst.relative_to(ROOT).as_posix(), f"bâtiment {cw}x{ch} (dessin ChatGPT)")
    print(f"{dst.relative_to(ROOT)}  {out.width}×{out.height}")


if __name__ == "__main__":
    main()
