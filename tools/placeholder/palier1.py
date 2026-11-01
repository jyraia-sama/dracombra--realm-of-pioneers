#!/usr/bin/env python3
"""Objets du palier 1 (caverne d'obsidienne) : icônes PROVISOIRES dessinées par le code
(atlas assets/sprites/items/items_p1.png, cases de 32 px) et fichiers data/items/*.tres.

Relancer ce script régénère l'atlas et les .tres (les recettes sont dans crafting.gd).
    python tools/placeholder/palier1.py
"""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
ATLAS = "res://assets/sprites/items/items_p1.png"
O = (28, 20, 34, 255)

IRON = [(110, 116, 128), (160, 168, 180), (205, 212, 222)]
CHITIN = [(58, 40, 70), (96, 70, 112), (150, 120, 170)]
SILK = [(196, 186, 214), (226, 220, 240), (255, 255, 255)]
CRYSTAL = [(40, 120, 190), (80, 180, 240), (190, 240, 255)]
WOOD = [(110, 70, 40), (150, 100, 55), (190, 140, 80)]
ORE = [(90, 84, 80), (130, 122, 116), (200, 120, 70)]

# id, nom, catégorie, slot, bonus, classes, description, dessin, palette
ITEMS = [
    # Ressources
    ("iron_ore", "Minerai de fer", "resource", "", {}, [], "Roche veinée de rouille, arrachée aux parois des Abysses. À fondre à la forge.", "ore", ORE),
    ("iron_ingot", "Lingot de fer", "resource", "", {}, [], "Fer fondu et coulé à la forge. Sert aux armes et aux armures lourdes.", "ingot", IRON),
    ("chitin", "Chitine d'araignée", "resource", "", {}, [], "Plaque de carapace d'araignée d'obsidienne, légère et dure. Pour les armures de cuir.", "plate", CHITIN),
    ("silk", "Soie d'araignée", "resource", "", {}, [], "Fil d'araignée d'obsidienne, très solide. Cordes d'arc, étoffes.", "spool", SILK),
    ("silk_cloth", "Étoffe de soie", "resource", "", {}, [], "Soie tissée à l'établi. Pour les robes des mages et des clercs.", "cloth", SILK),
    ("mana_crystal", "Cristal de mana", "resource", "", {}, [], "Cristal bleu qui bourdonne de magie. Bâtons, livres sacrés, robes.", "crystal", CRYSTAL),
    # Lourd (guerrier)
    ("iron_helmet", "Casque de fer", "equipment", "head", {"def": 2, "vit": 2}, ["warrior"], "Armure lourde du palier 1.", "helmet", IRON),
    ("iron_armor", "Cuirasse de fer", "equipment", "body", {"def": 4, "vit": 2}, ["warrior"], "Armure lourde du palier 1.", "chest", IRON),
    ("iron_gauntlets", "Gantelets de fer", "equipment", "hands", {"def": 1, "str": 2}, ["warrior"], "Armure lourde du palier 1.", "gloves", IRON),
    ("iron_boots", "Bottes de fer", "equipment", "feet", {"def": 2, "stamina": 6}, ["warrior"], "Armure lourde du palier 1.", "boots", IRON),
    ("iron_sword", "Épée de fer", "equipment", "main", {"dmg": 2, "str": 1}, ["warrior"], "Arme lourde du palier 1.", "sword", IRON),
    ("iron_shield", "Bouclier de fer", "equipment", "off", {"def": 2, "parry": 10}, ["warrior"], "Arme secondaire lourde du palier 1.", "shield", IRON),
    # Cuir (archer)
    ("chitin_hood", "Capuche de chitine", "equipment", "head", {"def": 1, "dex": 2}, ["archer"], "Armure de cuir du palier 1.", "helmet", CHITIN),
    ("chitin_armor", "Armure de chitine", "equipment", "body", {"def": 3, "dex": 2}, ["archer"], "Armure de cuir du palier 1.", "chest", CHITIN),
    ("chitin_bracers", "Brassards de chitine", "equipment", "hands", {"dex": 1, "crit": 5}, ["archer"], "Armure de cuir du palier 1.", "gloves", CHITIN),
    ("chitin_boots", "Bottes de chitine", "equipment", "feet", {"dex": 1, "stamina": 10}, ["archer"], "Armure de cuir du palier 1.", "boots", CHITIN),
    ("chitin_bow", "Arc de chitine", "equipment", "main", {"dmg": 2, "dex": 1}, ["archer"], "Arme de cuir du palier 1. Corde en soie d'araignée.", "bow", CHITIN),
    ("silk_quiver", "Carquois de soie", "equipment", "off", {"dex": 2, "crit": 8}, ["archer"], "Arme secondaire de cuir du palier 1.", "quiver", CHITIN),
    # Tissu (mage, clerc)
    ("silk_hood", "Capuche de soie", "equipment", "head", {"int": 1, "wis": 1, "mana": 6}, ["mage", "cleric"], "Armure de tissu du palier 1.", "hood", SILK),
    ("silk_robe", "Robe de soie", "equipment", "body", {"def": 2, "int": 1, "wis": 1, "mana": 10}, ["mage", "cleric"], "Armure de tissu du palier 1.", "robe", SILK),
    ("silk_gloves", "Gants de soie", "equipment", "hands", {"int": 2}, ["mage", "cleric"], "Armure de tissu du palier 1.", "gloves", SILK),
    ("silk_shoes", "Chaussons de soie", "equipment", "feet", {"wis": 2, "mana": 6}, ["mage", "cleric"], "Armure de tissu du palier 1.", "boots", SILK),
    ("crystal_staff", "Bâton de cristal", "equipment", "main", {"dmg": 2, "int": 1}, ["mage"], "Arme de tissu du palier 1 (mage).", "staff", CRYSTAL),
    ("sacred_book", "Livre sacré", "equipment", "main", {"dmg": 2, "wis": 1}, ["cleric"], "Arme de tissu du palier 1 (clerc). Reliure de soie, fermoir de cristal.", "book", CRYSTAL),
]


def c(rgb):
    return tuple(rgb) + (255,)


def draw(d: ImageDraw.ImageDraw, kind: str, pal):
    dark, mid, light = (c(p) for p in pal)
    if kind == "ore":
        d.polygon([(5, 24), (9, 10), (18, 6), (27, 13), (26, 26)], fill=O)
        d.polygon([(7, 23), (10, 11), (18, 8), (25, 14), (24, 24)], fill=mid)
        for x, y in ((12, 14), (19, 18), (15, 21), (21, 12)):
            d.rectangle((x, y, x + 2, y + 1), fill=light)
    elif kind == "ingot":
        d.polygon([(4, 22), (9, 13), (27, 13), (28, 22)], fill=O)
        d.polygon([(6, 21), (10, 14), (26, 14), (26, 21)], fill=mid)
        d.polygon([(10, 14), (26, 14), (24, 17), (12, 17)], fill=light)
    elif kind == "plate":
        d.ellipse((5, 7, 27, 27), fill=O)
        d.ellipse((6, 8, 26, 26), fill=mid)
        for y in (12, 17, 22):
            d.line((8, y, 24, y), fill=dark)
        d.ellipse((9, 9, 15, 13), fill=light)
    elif kind == "spool":
        d.rectangle((8, 6, 24, 9), fill=O); d.rectangle((8, 23, 24, 26), fill=O)
        d.rectangle((10, 9, 22, 23), fill=O); d.rectangle((11, 9, 21, 23), fill=mid)
        for y in range(10, 23, 3):
            d.line((11, y, 21, y + 1), fill=light)
        d.rectangle((9, 7, 23, 8), fill=c(WOOD[1])); d.rectangle((9, 24, 23, 25), fill=c(WOOD[1]))
    elif kind == "cloth":
        d.polygon([(4, 10), (26, 6), (28, 22), (6, 26)], fill=O)
        d.polygon([(6, 11), (25, 8), (26, 21), (7, 24)], fill=mid)
        d.line((6, 16, 26, 13), fill=light); d.line((7, 20, 26, 17), fill=dark)
    elif kind == "crystal":
        d.polygon([(16, 3), (24, 12), (20, 29), (12, 29), (8, 12)], fill=O)
        d.polygon([(16, 5), (22, 12), (19, 27), (13, 27), (10, 12)], fill=mid)
        d.polygon([(16, 5), (16, 27), (13, 27), (10, 12)], fill=light)
    elif kind in ("helmet", "hood"):
        d.pieslice((5, 5, 27, 29), 180, 360, fill=O); d.rectangle((5, 16, 27, 25), fill=O)
        d.pieslice((6, 6, 26, 28), 180, 360, fill=mid); d.rectangle((6, 16, 26, 24), fill=mid)
        if kind == "helmet":
            d.rectangle((9, 15, 23, 18), fill=dark); d.line((16, 6, 16, 14), fill=light)
        else:
            d.ellipse((10, 13, 22, 25), fill=dark)
    elif kind in ("chest", "robe"):
        d.polygon([(4, 9), (11, 5), (21, 5), (28, 9), (25, 15), (23, 28), (9, 28), (7, 15)], fill=O)
        d.polygon([(6, 9), (12, 6), (20, 6), (26, 9), (23, 14), (22, 27), (10, 27), (9, 14)], fill=mid)
        d.line((16, 7, 16, 26), fill=dark)
        if kind == "robe":
            d.polygon([(10, 27), (8, 30), (24, 30), (22, 27)], fill=mid)
            d.rectangle((10, 17, 22, 18), fill=c(CRYSTAL[1]))
        else:
            d.line((11, 10, 21, 10), fill=light)
    elif kind == "gloves":
        d.rounded_rectangle((7, 8, 25, 26), 4, fill=O); d.rounded_rectangle((8, 9, 24, 25), 4, fill=mid)
        for x in (11, 15, 19):
            d.line((x, 9, x, 15), fill=dark)
        d.rectangle((8, 21, 24, 25), fill=light)
    elif kind == "boots":
        d.polygon([(8, 5), (17, 5), (17, 20), (27, 22), (27, 28), (8, 28)], fill=O)
        d.polygon([(9, 6), (16, 6), (16, 21), (26, 23), (26, 27), (9, 27)], fill=mid)
        d.rectangle((9, 24, 26, 27), fill=dark); d.line((10, 7, 10, 22), fill=light)
    elif kind == "sword":
        d.polygon([(22, 3), (26, 7), (12, 21), (9, 18)], fill=O)
        d.polygon([(22, 5), (24, 7), (12, 19), (11, 18)], fill=light)
        d.line((7, 17, 14, 24), fill=O, width=3); d.line((6, 26, 10, 22), fill=c(WOOD[1]), width=3)
    elif kind == "shield":
        d.polygon([(6, 5), (26, 5), (26, 16), (16, 29), (6, 16)], fill=O)
        d.polygon([(7, 6), (25, 6), (25, 16), (16, 27), (7, 16)], fill=mid)
        d.line((16, 7, 16, 25), fill=dark); d.line((8, 12, 24, 12), fill=dark)
        d.ellipse((13, 10, 19, 15), fill=light)
    elif kind == "bow":
        d.arc((4, 3, 26, 29), 270, 90, fill=O, width=4); d.arc((5, 4, 25, 28), 270, 90, fill=mid, width=2)
        d.line((15, 4, 15, 28), fill=c(SILK[2]))
    elif kind == "quiver":
        d.polygon([(10, 9), (20, 7), (24, 27), (14, 29)], fill=O)
        d.polygon([(11, 10), (19, 8), (23, 26), (15, 28)], fill=mid)
        for x in (12, 15, 18):
            d.line((x, 3, x + 1, 9), fill=c(WOOD[2])); d.rectangle((x - 1, 2, x + 1, 4), fill=c(SILK[1]))
    elif kind == "staff":
        d.line((10, 28, 20, 9), fill=O, width=4); d.line((10, 28, 20, 9), fill=c(WOOD[1]), width=2)
        d.polygon([(21, 2), (26, 7), (22, 13), (17, 8)], fill=O)
        d.polygon([(21, 4), (24, 7), (22, 11), (19, 8)], fill=light)
    elif kind == "book":
        d.rectangle((6, 6, 26, 27), fill=O); d.rectangle((7, 7, 25, 26), fill=c(SILK[0]))
        d.rectangle((7, 7, 10, 26), fill=dark)
        d.polygon([(17, 11), (19, 15), (17, 21), (15, 15)], fill=mid)
        d.rectangle((15, 15, 19, 16), fill=c((240, 200, 70)))


def main():
    atlas = Image.new("RGBA", (32 * len(ITEMS), 32), (0, 0, 0, 0))
    for i, it in enumerate(ITEMS):
        tile = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        draw(ImageDraw.Draw(tile), it[7], it[8])
        atlas.alpha_composite(tile, (i * 32, 0))
    out = ROOT / "assets/sprites/items/items_p1.png"
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
