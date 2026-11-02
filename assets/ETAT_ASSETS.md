# État des assets graphiques

Voir `REGLES_ASSETS.md` (dans le Project) : **FINAL** = dessiné et validé, on le garde ;
**PROVISOIRE** = généré par `tools/placeholder/placeholder.py`, régénérable ; **À DESSINER** = gameplay stable,
le vrai dessin peut être commandé. Pour remplacer un provisoire : écraser le PNG **et** son .json, puis passer la ligne en FINAL.

## Provisoires et à dessiner

| Fichier | Statut | Date | Remarque |
| --- | --- | --- | --- |
| `scenes/levels/dungeon/dungeon_gate.gd` | PROVISOIRE | 2026-11-01 | herse d'éclats d'obsidienne des salles de combat (dessinée par le code) |
| `scenes/levels/dungeon/dungeon_stairs.gd` | PROVISOIRE | 2026-11-01 | escaliers du donjon (dessinés par le code) |
| `scenes/levels/dracombra/dungeon_approach.gd` | PROVISOIRE | 2026-11-01 | bâtiment d'entrée des Abysses : escalier dessiné + piliers et braseros existants |
| `res://assets/sprites/npc/marchand/marchand.png` | PROVISOIRE | 2026-11-01 | perso pnj (généré) |
| `res://assets/sprites/items/gold.png` | PROVISOIRE | 2026-11-01 | icône pièces d'or (dessinée par le code) |
| `res://assets/sprites/items/potion_heal.png` | PROVISOIRE | 2026-11-01 | icône potion de soin (dessinée par le code) |
| `res://assets/sprites/items/potion_mana.png` | PROVISOIRE | 2026-11-02 | icône potion de mana (potion de soin recolorée en bleu) |
| `res://assets/sprites/items/potion_stamina.png` | PROVISOIRE | 2026-11-02 | icône potion de vigueur (potion de soin recolorée en orange) |
| `res://assets/sprites/items/items_p1.png` | PROVISOIRE | 2026-11-01 | icônes du palier 1 (tools/placeholder/palier1.py) |
| `res://assets/sprites/weapons/book.png` | PROVISOIRE | 2026-11-01 | livre sacré du clerc, tenu en main (dessiné par le code) |
| `scenes/bosses/queen_spider/queen_spider.gd` | PROVISOIRE | 2026-11-01 | reine araignée : planche de l'araignée d'obsidienne agrandie ×2 et teintée |
| `scenes/bosses/queen_spider/web_shot.gd` | PROVISOIRE | 2026-11-01 | jet de toile (dessiné par le code) |
| `res://assets/sprites/guild/membre_*/` | PROVISOIRE | 2026-11-01 | membres combattants (silhouette bleue + couleur de classe, générés) |
| `res://assets/sprites/guild/artisan/artisan.png` | PROVISOIRE | 2026-11-01 | membres artisans (générés) |
| `scenes/levels/guild_hall/guild_hall.gd` | PROVISOIRE | 2026-11-01 | salle de la guilde : plancher, murs, tapis, pupitre, tableau (dessinés par le code) |
| `res://assets/sprites/npc/lysia/lysia.png` | PROVISOIRE | 2026-11-01 | perso pnj (généré) |
| `res://assets/sprites/npc/lysia/lysia.png` | PROVISOIRE | 2026-11-01 | Lysia, intendante de la guilde (PNJ généré, teinté lavande en jeu) |
| `res://assets/sprites/buildings/work/hutte_bucheron.png` | PROVISOIRE | 2026-11-02 | bâtiment 2x2 production (généré) |
| `res://assets/sprites/buildings/work/carriere.png` | PROVISOIRE | 2026-11-02 | bâtiment 2x2 defense (généré) |
| `res://assets/sprites/buildings/work/cabane_chasseur.png` | PROVISOIRE | 2026-11-02 | bâtiment 2x2 commerce (généré) |
| `res://assets/sprites/buildings/work/jardin_herbes.png` | PROVISOIRE | 2026-11-02 | bâtiment 2x1 logement (généré) |
| `res://assets/sprites/buildings/work/*.png` | PROVISOIRE | 2026-11-02 | bâtiments de travail : hutte du bûcheron, carrière, cabane du chasseur, jardin d'herbes (générés) |
| `res://assets/sprites/buildings/work/entrepot.png` | PROVISOIRE | 2026-11-02 | bâtiment 3x2 commerce (généré) |
<!-- fin provisoires -->

## Existants au 2026-11-01 (version 0.4.1)

Tous marqués FINAL par défaut : passer une ligne en À DESSINER si l'asset doit être refait.

| Fichier | Statut | Date | Remarque |
| --- | --- | --- | --- |
| `res://assets/sprites/bosses/solakor.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/buildings/chest.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/buildings/drying_rack.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/buildings/guild_0.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/buildings/guild_1.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/buildings/guild_2.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/buildings/guild_3.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/buildings/guild_4.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/buildings/scaffold.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/buildings/tent.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/buildings/workbench.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/enemies/boar.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/enemies/obsidian_spider.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/enemies/rock_goblin.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/enemies/slime.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/enemies/thrown_rock.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/hero/archer.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/hero/v2/reference_back.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/hero/v2/reference_front.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/hero/v2/reference_side.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/hero/warrior.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/hero/warrior_hd.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/hero/warrior_wounded.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/items/items.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/npc/ysolde.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/cave/boulder.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/cave/cave_rubble.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/cave/crystal_blue.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/cave/crystal_blue_b.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/cave/crystal_blue_large.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/cave/crystal_blue_large_b.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/cave/crystal_blue_small.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/cave/crystal_blue_small_b.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/cave/crystal_purple.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/cave/crystal_purple_b.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/cave/crystal_purple_large.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/cave/crystal_purple_large_b.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/cave/crystal_purple_small.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/cave/crystal_purple_small_b.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/cave/dark_pool.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/cave/fallen_adventurer.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/cave/mushrooms.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/cave/mushrooms_large.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/cave/rock_fragments.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/cave/rocks.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/cave/rocks_brown.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/cave/rocks_small.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/cave/roots_a.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/cave/roots_b.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/cave/roots_wide.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/cave/skull_bones.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/cave/stalagmite.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/cave/stalagmite_large.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/cave/stalagmite_small.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/city/dracombra_gate.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/city/rubble_blocks.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/city/rubble_column.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/city/rubble_dragon.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/city/rubble_pillar.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/city/rubble_slab.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/city/rubble_small.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/city/rubble_wing.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/city/ruin_arch.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/city/ruin_arch_dragon.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/city/ruin_column.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/city/ruin_pillar_small.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/city/ruin_pillars.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/city/ruin_wall.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/falling_rock.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/lair/claw_marks_a.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/lair/claw_marks_b.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/lair/claw_marks_c.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/lair/cracked_floor.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/lair/dragon_nest.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/lair/dragon_scales.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/lair/embers.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/lair/embers_large.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/lair/embers_small.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/lair/fallen_banner.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/lair/lava_crack.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/lair/lava_crack_small.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/lair/melted_armor.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/lair/scorched_ground.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/lair/scorched_ground_small.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/ruins/ancient_arch.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/ruins/ancient_stairs.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/ruins/carved_slab.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/ruins/carved_tablet.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/ruins/dragon_head_statue.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/ruins/pillar.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/ruins/pillar_broken.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/ruins/pillar_stump.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/ruins/rune_brazier.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/ruins/rune_stone.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/ruins/rune_stones.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/ruins/stone_wing.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/sylve/bedroll.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/sylve/bush.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/sylve/bush_berries.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/sylve/campfire.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/sylve/cave_mouth.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/sylve/flax_plant.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/sylve/flowers_pink.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/sylve/flowers_white.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/sylve/flowers_yellow.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/sylve/gem_rock.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/sylve/log.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/sylve/oak_a.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/sylve/oak_b.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/sylve/oak_big.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/sylve/oak_c.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/sylve/pebbles.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/sylve/pine_a.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/sylve/pine_b.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/sylve/rock_grey.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/sylve/rock_grey_big.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/sylve/stump.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/sylve/tall_grass.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/props/sylve/tall_grass_b.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/weapons/axe.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/weapons/bow.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/weapons/hero_sword.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/weapons/hero_sword_large.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/weapons/mace.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/weapons/pickaxe.png` | FINAL | 2026-11-01 | |
| `res://assets/sprites/weapons/staff.png` | FINAL | 2026-11-01 | |
| `res://assets/tilesets/cave_tiles.png` | FINAL | 2026-11-01 | |
| `res://assets/tilesets/dracombra_tiles.png` | FINAL | 2026-11-01 | |
| `res://assets/tilesets/sylve_tiles.png` | FINAL | 2026-11-01 | |
