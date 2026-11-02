#!/usr/bin/env python3
"""Objets du palier 2 (cryptes des pionniers, zone 2 des Abysses) : icônes PROVISOIRES
dessinées par le code (atlas assets/sprites/items/items_p2.png, cases de 32 px) et fichiers
data/items/*.tres. Les recettes sont dans crafting.gd.
    python tools/placeholder/palier2.py
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import palier1  # noqa: E402  (mêmes dessins d'objets)
from palier1 import O, c  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
ATLAS = "res://assets/sprites/items/items_p2.png"

SILVER = [(132, 140, 156), (190, 198, 214), (240, 244, 252)]
SILVER_ORE = [(70, 72, 84), (110, 112, 126), (226, 232, 246)]
BONE = [(150, 138, 110), (210, 200, 172), (244, 238, 220)]
LEATHER = [(70, 54, 46), (108, 86, 70), (150, 124, 100)]
WRAPS = [(150, 140, 112), (200, 190, 160), (232, 226, 204)]
SPECTRAL = [(60, 120, 120), (110, 210, 200), (200, 255, 246)]

ITEMS = [
    # Ressources
    ("silver_ore", "Minerai d'argent", "resource", "", {}, [], "Roche striée d'argent, arrachée aux murs des cryptes. À fondre à la forge.", "ore", SILVER_ORE),
    ("silver_ingot", "Lingot d'argent", "resource", "", {}, [], "Argent fondu à la forge. Armes et armures lourdes ; béni, il blesse les morts.", "ingot", SILVER),
    ("ancient_bone", "Os anciens", "resource", "", {}, [], "Os durcis par les siècles, laissés par les squelettes des cryptes. Arcs et armures de cuir.", "bones", BONE),
    ("crypt_leather", "Cuir tanné des cryptes", "resource", "", {}, [], "Peau sombre et souple des rats des cryptes. Armures de cuir.", "plate", LEATHER),
    ("spectral_essence", "Essence spectrale", "resource", "", {}, [], "Lueur froide laissée par un feu follet. Bâtons, livres, robes.", "wisp", SPECTRAL),
    ("linen_wraps", "Bandelettes de lin", "resource", "", {}, [], "Bandelettes funéraires des pionniers, encore solides. Robes et étoffes.", "cloth", WRAPS),
    # Lourd (guerrier)
    ("silver_helmet", "Casque d'argent", "equipment", "head", {"def": 3, "vit": 3}, ["warrior"], "Armure lourde du palier 2.", "helmet", SILVER),
    ("silver_armor", "Cuirasse d'argent", "equipment", "body", {"def": 6, "vit": 3}, ["warrior"], "Armure lourde du palier 2.", "chest", SILVER),
    ("silver_gauntlets", "Gantelets d'argent", "equipment", "hands", {"def": 2, "str": 3}, ["warrior"], "Armure lourde du palier 2.", "gloves", SILVER),
    ("silver_boots", "Bottes d'argent", "equipment", "feet", {"def": 3, "stamina": 8}, ["warrior"], "Armure lourde du palier 2.", "boots", SILVER),
    ("silver_sword", "Épée d'argent", "equipment", "main", {"dmg": 12, "str": 2}, ["warrior"], "Arme lourde du palier 2.", "sword", SILVER),
    ("silver_shield", "Bouclier d'argent", "equipment", "off", {"def": 4, "parry": 12}, ["warrior"], "Arme secondaire lourde du palier 2.", "shield", SILVER),
    # Cuir (archer)
    ("bone_hood", "Capuche d'os", "equipment", "head", {"def": 2, "dex": 3}, ["archer"], "Armure de cuir du palier 2.", "helmet", BONE),
    ("crypt_leather_armor", "Armure de cuir des cryptes", "equipment", "body", {"def": 5, "dex": 3}, ["archer"], "Armure de cuir du palier 2.", "chest", LEATHER),
    ("bone_bracers", "Brassards d'os", "equipment", "hands", {"dex": 2, "crit": 7}, ["archer"], "Armure de cuir du palier 2.", "gloves", BONE),
    ("crypt_boots", "Bottes des cryptes", "equipment", "feet", {"dex": 2, "stamina": 14}, ["archer"], "Armure de cuir du palier 2.", "boots", LEATHER),
    ("bone_bow", "Arc d'os", "equipment", "main", {"dmg": 12, "dex": 2}, ["archer"], "Arme de cuir du palier 2.", "bow", BONE),
    ("bone_quiver", "Carquois d'os", "equipment", "off", {"dex": 3, "crit": 10}, ["archer"], "Arme secondaire de cuir du palier 2.", "quiver", LEATHER),
    # Tissu (mage, clerc)
    ("wraps_hood", "Capuche de bandelettes", "equipment", "head", {"int": 2, "wis": 2, "mana": 10}, ["mage", "cleric"], "Armure de tissu du palier 2.", "hood", WRAPS),
    ("spectral_robe", "Robe spectrale", "equipment", "body", {"def": 3, "int": 2, "wis": 2, "mana": 16}, ["mage", "cleric"], "Armure de tissu du palier 2.", "robe", WRAPS),
    ("wraps_gloves", "Gants de bandelettes", "equipment", "hands", {"int": 3, "wis": 1}, ["mage", "cleric"], "Armure de tissu du palier 2.", "gloves", WRAPS),
    ("wraps_shoes", "Chaussons de bandelettes", "equipment", "feet", {"wis": 3, "mana": 10}, ["mage", "cleric"], "Armure de tissu du palier 2.", "boots", WRAPS),
    ("spectral_staff", "Bâton spectral", "equipment", "main", {"dmg": 24, "int": 2}, ["mage"], "Arme de tissu du palier 2 (mage).", "staff", SPECTRAL),
    ("spectral_tome", "Livre des pionniers", "equipment", "main", {"dmg": 8, "wis": 2}, ["cleric"], "Arme de tissu du palier 2 (clerc). Fermoir d'argent, pages qui luisent.", "book", SPECTRAL),
]


def draw(d: ImageDraw.ImageDraw, kind: str, pal):
    dark, mid, light = (c(p) for p in pal)
    if kind == "bones":
        for (x1, y1, x2, y2) in ((6, 22, 24, 10), (8, 10, 26, 22)):
            d.line((x1, y1, x2, y2), fill=O, width=6)
            d.line((x1, y1, x2, y2), fill=mid, width=3)
            for (x, y) in ((x1, y1), (x2, y2)):
                d.ellipse((x - 4, y - 4, x + 4, y + 4), fill=O)
                d.ellipse((x - 3, y - 3, x + 3, y + 3), fill=light)
    elif kind == "wisp":
        d.ellipse((7, 9, 25, 27), fill=O)
        d.polygon([(10, 14), (16, 2), (22, 14)], fill=O)
        d.ellipse((8, 10, 24, 26), fill=mid)
        d.polygon([(11, 15), (16, 4), (21, 15)], fill=mid)
        d.ellipse((12, 14, 20, 22), fill=light)
    else:
        palier1.draw(d, kind, pal)


def main():
    atlas = Image.new("RGBA", (32 * len(ITEMS), 32), (0, 0, 0, 0))
    for i, it in enumerate(ITEMS):
        tile = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        draw(ImageDraw.Draw(tile), it[7], it[8])
        atlas.alpha_composite(tile, (i * 32, 0))
    out = ROOT / "assets/sprites/items/items_p2.png"
    atlas.save(out)
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
    print(f"{len(ITEMS)} objets, atlas {out.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
