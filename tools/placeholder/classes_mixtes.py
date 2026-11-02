#!/usr/bin/env python3
"""Équipement des classes mixtes (CLASSES.md) : icônes PROVISOIRES dessinées par le code
(atlas assets/sprites/items/items_mx.png) et fichiers data/items/*.tres.
    python tools/placeholder/classes_mixtes.py
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import palier1  # noqa: E402
import palier2  # noqa: E402
from palier1 import O, c  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
ATLAS = "res://assets/sprites/items/items_mx.png"
STEEL = [(120, 128, 146), (186, 194, 210), (236, 240, 250)]
SACRED = [(176, 140, 60), (232, 200, 100), (255, 244, 190)]
TOWER = [(90, 96, 112), (140, 146, 162), (200, 206, 220)]
WOOD = [(96, 60, 34), (140, 92, 52), (184, 132, 80)]
PAPER = [(170, 150, 110), (226, 210, 170), (250, 244, 220)]
ELEM = [(150, 40, 30), (230, 120, 40), (120, 200, 250)]

ITEMS = [
    ("long_sword", "Épée longue", "equipment", "main", {"dmg": 16, "str": 3}, ["knight", "paladin"],
     "Lame longue des chevaliers de l'ancienne Dracombra. Chevalier et paladin.", "long_sword", STEEL),
    ("tower_shield", "Grand bouclier", "equipment", "off", {"def": 8, "parry": 15, "vit": 2}, ["knight"],
     "Un pavois qui couvre le chevalier de la tête aux genoux.", "shield", TOWER),
    ("sacred_shield", "Bouclier sacré", "equipment", "off", {"def": 6, "parry": 12, "wis": 3}, ["paladin"],
     "Le bouclier béni des pionniers. Sa lumière protège ceux qui combattent près du paladin.", "sacred_shield", SACRED),
    ("musket", "Mousquet des pionniers", "equipment", "main", {"dmg": 14, "dex": 2}, ["marksman"],
     "Arme à poudre forgée d'après les plans des pionniers. Tireur d'élite.", "musket", WOOD),
    ("musket_plans", "Plans du mousquet", "quest", "", {}, [],
     "Les plans d'une arme à poudre des pionniers. La forge peut s'en servir (ils ne s'usent pas).", "scroll", PAPER),
    ("elemental_scepter", "Sceptre élémentaire", "equipment", "main", {"dmg": 26, "int": 3}, ["elementalist"],
     "Trois cristaux — feu, glace, foudre — enchâssés dans le bois. Élémentaliste.", "scepter", ELEM),
    ("prayer_book", "Livre des prières", "equipment", "main", {"dmg": 12, "wis": 3}, ["priest"],
     "Les prières des pionniers, recopiées sur des bandelettes. Prêtre.", "book", [(200, 190, 150), (240, 230, 190), (255, 255, 230)]),
    ("hunter_bow", "Arc de chasse", "equipment", "main", {"dmg": 13, "dex": 2, "str": 1}, ["ranger"],
     "Un arc court et nerveux, une hachette à la ceinture. Rôdeur.", "bow", [(70, 90, 50), (110, 140, 70), (170, 200, 120)]),
    ("rune_sword", "Épée runique", "equipment", "main", {"dmg": 18, "str": 1, "int": 2}, ["spellblade"],
     "Des runes de mana courent le long de la lame. Lame-sort.", "long_sword", [(90, 70, 150), (150, 120, 220), (210, 190, 255)]),
    ("oracle_scepter", "Sceptre de l'oracle", "equipment", "main", {"dmg": 20, "int": 2, "wis": 2}, ["oracle"],
     "Un œil de cristal au bout d'un bâton d'argent. Oracle.", "scepter", [(120, 160, 240), (230, 230, 255), (200, 240, 255)]),
]


def draw(d, kind, pal):
    dark, mid, light = (c(p) for p in pal)
    if kind == "long_sword":
        d.polygon([(25, 2), (29, 6), (11, 24), (8, 21)], fill=O)
        d.polygon([(25, 4), (27, 6), (11, 22), (10, 21)], fill=light)
        d.line((5, 19, 13, 27), fill=O, width=3)
        d.line((5, 19, 13, 27), fill=c((200, 170, 80)), width=1)
        d.line((3, 29, 8, 24), fill=c((110, 70, 40)), width=3)
    elif kind == "sacred_shield":
        d.polygon([(6, 4), (26, 4), (26, 16), (16, 30), (6, 16)], fill=O)
        d.polygon([(7, 5), (25, 5), (25, 16), (16, 28), (7, 16)], fill=c((236, 236, 244)))
        d.rectangle((14, 7, 18, 24), fill=mid)
        d.rectangle((9, 11, 23, 15), fill=mid)
        d.line((7, 5, 25, 5), fill=light)
    elif kind == "musket":
        d.line((3, 25, 28, 6), fill=O, width=5)
        d.line((3, 25, 14, 17), fill=mid, width=3)
        d.line((13, 18, 28, 6), fill=c((150, 154, 168)), width=2)
        d.polygon([(2, 24), (8, 21), (9, 28), (4, 29)], fill=dark)
        d.rectangle((13, 17, 15, 21), fill=c((200, 170, 80)))
    elif kind == "scroll":
        d.rectangle((6, 8, 26, 24), fill=O)
        d.rectangle((7, 9, 25, 23), fill=mid)
        for y in (12, 15, 18):
            d.line((10, y, 22, y), fill=dark)
        d.line((14, 11, 20, 20), fill=c((60, 60, 70)))
        d.ellipse((4, 6, 9, 26), fill=light)
        d.ellipse((23, 6, 28, 26), fill=light)
    elif kind == "scepter":
        d.line((10, 29, 18, 12), fill=O, width=4)
        d.line((10, 29, 18, 12), fill=c(WOOD[1]), width=2)
        for (x, y), col in zip(((16, 6), (22, 9), (20, 3)), pal):
            d.ellipse((x - 3, y - 3, x + 3, y + 3), fill=O)
            d.ellipse((x - 2, y - 2, x + 2, y + 2), fill=c(col))
    else:
        palier2.draw(d, kind, pal)


def main():
    atlas = Image.new("RGBA", (32 * len(ITEMS), 32), (0, 0, 0, 0))
    for i, it in enumerate(ITEMS):
        tile = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        draw(ImageDraw.Draw(tile), it[7], it[8])
        atlas.alpha_composite(tile, (i * 32, 0))
    atlas.save(ROOT / "assets/sprites/items/items_mx.png")
    for i, (iid, name, cat, slot, bonus, classes, desc, _k, _p) in enumerate(ITEMS):
        b = ", ".join(f'&"{k}": {v}' for k, v in bonus.items())
        cl = ", ".join(f'&"{x}"' for x in classes)
        lines = [
            '[gd_resource type="Resource" script_class="ItemData" format=3]', "",
            '[ext_resource type="Script" path="res://scripts/data/item_data.gd" id="1_item"]',
            f'[ext_resource type="Texture2D" path="{ATLAS}" id="2_icons"]', "",
            '[sub_resource type="AtlasTexture" id="AtlasTexture_icon"]',
            'atlas = ExtResource("2_icons")', f"region = Rect2({i * 32}, 0, 32, 32)", "",
            "[resource]", 'script = ExtResource("1_item")', f'id = &"{iid}"', f'display_name = "{name}"',
            'icon = SubResource("AtlasTexture_icon")', f'description = "{desc}"', f'category = &"{cat}"',
        ]
        if slot:
            lines += [f'slot = &"{slot}"', f"bonus = {{{b}}}", f"classes = Array[StringName]([{cl}])"]
        (ROOT / f"data/items/{iid}.tres").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"{len(ITEMS)} objets")


if __name__ == "__main__":
    main()
