"""Extrait chaque décor des planches ChatGPT, à l'échelle du jeu, et écrit props.json.

Pour chaque décor : image PNG, taille, collision (en pixels, au pied du décor),
cases bloquées (pour vérifier qu'on ne bouche pas un passage), lumière éventuelle,
et type : "object" (posé au sol, trié en profondeur), "decal" (à plat sur le sol),
"hanging" (pend d'une paroi).
"""
import json
import os
import sys
sys.path.insert(0, '.')
sys.path.insert(0, '../assets2')
from seg import segment
from slice import downscale, quantize
import numpy as np
from PIL import Image

OUT = sys.argv[1]  # dossier assets/sprites/props du projet

BLUE, PURPLE, TEAL = [0.45, 0.75, 1.0], [0.78, 0.5, 1.0], [0.4, 1.0, 0.9]
ORANGE, LAVA, WATER = [1.0, 0.5, 0.18], [1.0, 0.4, 0.15], [0.5, 0.7, 1.0]

# nom : (indices, type, collision [w, h] ou None, cases bloquées [w, h], lumière [couleur, rayon, énergie, vacille])
CAVE = {
    "crystal_blue_large": ([0], "object", [20, 8], [1, 1], [BLUE, 72, 1.0, False]),
    "crystal_purple_large": ([1], "object", [20, 8], [1, 1], [PURPLE, 72, 1.0, False]),
    "crystal_blue": ([2], "object", [12, 6], [1, 1], [BLUE, 56, 0.9, False]),
    "crystal_blue_small": ([3], "object", None, [0, 0], [BLUE, 40, 0.7, False]),
    "crystal_purple": ([4], "object", [12, 6], [1, 1], [PURPLE, 64, 1.0, False]),
    "crystal_purple_small": ([5], "object", None, [0, 0], [PURPLE, 40, 0.7, False]),
    "stalagmite_large": ([6], "object", [20, 8], [1, 1], None),
    "stalagmite": ([7], "object", [12, 6], [1, 1], None),
    "stalagmite_small": ([8], "object", [8, 4], [1, 1], None),
    "mushrooms_large": ([9], "object", None, [0, 0], [TEAL, 48, 0.7, False]),
    "mushrooms": ([10], "object", None, [0, 0], [TEAL, 32, 0.6, False]),
    "skull_bones": ([11], "object", None, [0, 0], None),
    "boulder": ([12], "object", [26, 12], [2, 1], None),
    "fallen_adventurer": ([13], "object", None, [0, 0], None),
    "rocks_small": ([14], "object", [14, 6], [1, 1], None),
    "rocks": ([15], "object", [16, 6], [1, 1], None),
    "rocks_brown": ([16], "object", [16, 6], [1, 1], None),
    "rock_fragments": ([17], "decal", None, [0, 0], None),
    "roots_a": ([18], "hanging", None, [0, 0], None),
    "roots_b": ([19], "hanging", None, [0, 0], None),
    "roots_wide": ([20], "hanging", None, [0, 0], None),
    "dark_pool": ([21], "object", [38, 12], [3, 1], [WATER, 32, 0.3, False]),
}
RUINS = {
    "pillar": ([0], "object", [24, 10], [2, 1], None),
    "pillar_broken": ([1], "object", [12, 8], [1, 1], None),
    "dragon_head_statue": ([2], "object", [64, 18], [4, 1], None),
    "pillar_stump": ([3], "object", [18, 8], [1, 1], None),
    "ancient_arch": ([4], "object", [40, 8], [3, 1], None),
    "carved_slab": ([5], "object", [44, 14], [3, 1], None),
    "ancient_stairs": ([6], "object", [44, 14], [3, 1], None),
    "rune_brazier": ([7], "object", [14, 8], [1, 1], [PURPLE, 64, 1.0, True]),
    "stone_wing": ([8], "object", [26, 10], [2, 1], None),
    "rune_stone": ([9], "object", [12, 6], [1, 1], [PURPLE, 24, 0.4, False]),
    "rune_stones": ([10, 11, 13], "object", [24, 6], [2, 1], [PURPLE, 28, 0.4, False]),
    "carved_tablet": ([12], "object", [20, 8], [1, 1], None),
}
LAIR = {
    "dragon_nest": ([0], "decal", None, [0, 0], [LAVA, 120, 0.6, True]),
    "embers_large": ([1], "object", None, [0, 0], [ORANGE, 56, 1.0, True]),
    "embers": ([2], "object", None, [0, 0], [ORANGE, 48, 0.9, True]),
    "embers_small": ([3], "object", None, [0, 0], [ORANGE, 36, 0.8, True]),
    "claw_marks_a": ([4], "decal", None, [0, 0], None),
    "claw_marks_b": ([5], "decal", None, [0, 0], None),
    "claw_marks_c": ([6], "decal", None, [0, 0], None),
    "lava_crack": ([7], "decal", None, [0, 0], [LAVA, 48, 0.7, True]),
    "lava_crack_small": ([8], "decal", None, [0, 0], [LAVA, 40, 0.6, True]),
    "melted_armor": ([9], "object", [24, 8], [2, 1], None),
    "fallen_banner": ([10], "object", [20, 6], [1, 1], None),
    "scorched_ground": ([11], "decal", None, [0, 0], None),
    "scorched_ground_small": ([12], "decal", None, [0, 0], None),
    "cracked_floor": ([13], "decal", None, [0, 0], [LAVA, 28, 0.4, True]),
    "dragon_scales": ([14], "decal", None, [0, 0], None),
}
SHEETS = [
    ("cave", "6f8a7666-image.png", CAVE, 10, 0.1, {"skull_bones": 0.08}),
    ("ruins", "5c27de79-image.png", RUINS, 3, 0.1, {}),
    ("lair", "8d90410a-image.png", LAIR, 10, 0.1, {"dragon_nest": 0.2, "melted_armor": 0.065, "fallen_banner": 0.07}),
]

spec = {}
for group, file, props, dilate, scale, overrides in SHEETS:
    rgba, objs = segment(file, dilate=dilate)
    images, names = [], []
    for name, (idx, kind, col, block, light) in props.items():
        y0 = min(objs[i][0] for i in idx); x0 = min(objs[i][1] for i in idx)
        y1 = max(objs[i][2] for i in idx); x1 = max(objs[i][3] for i in idx)
        crop = Image.fromarray(rgba[y0:y1, x0:x1], 'RGBA')
        images.append(downscale(crop, overrides.get(name, scale)))
        names.append(name)
    images = quantize(images, 48)
    os.makedirs(os.path.join(OUT, group), exist_ok=True)
    for name, img in zip(names, images):
        a = np.asarray(img)
        ys, xs = np.where(a[..., 3] > 0)
        img = Image.fromarray(a[ys.min():ys.max() + 1, xs.min():xs.max() + 1], 'RGBA')
        path = os.path.join(OUT, group, name + ".png")
        img.save(path)
        idx, kind, col, block, light = props[name]
        spec[name] = {"group": group, "size": list(img.size), "kind": kind, "collision": col,
                      "block": block, "light": light}
        print(f"{group:6} {name:24} {img.size}")
json.dump(spec, open("props.json", "w"), indent=1)
