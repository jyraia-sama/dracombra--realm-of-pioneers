# Dracombra — toutes les tailles en pixels (relevées dans le code, version 0.4.1)

Pour le pont Tiamat ↔ Atelier Dracombra. Sources : `project.godot`, `scripts/autoload/game.gd`,
`scenes/player/player.gd`, les scènes `.tscn` et les images de `assets/`.

## 0. La règle de base : deux unités de pixels

| Unité | Définition | Où |
| --- | --- | --- |
| **px monde** | 1 pixel du monde de jeu. `Game.TILE_SIZE = 16` px monde par case. | positions, collisions, cartes, tuiles |
| **px HD** | pixel dessiné dans les images « HD ». **2 px HD = 1 px monde.** | héros, PNJ, ennemis, armes, décors, bâtiments |

Toute image HD est affichée avec `scale = Vector2(0.5, 0.5)` et `texture_filter = Nearest`.
Donc **une case de 16 px monde = 32 px HD**. Tout ce que l'Atelier ou Tiamat produit pour le jeu se dessine en px HD.

Écran : viewport 640×360, étiré (`canvas_items`) en 1920×1080 plein écran ; caméra du héros `zoom = 1.333`
→ on voit **480×270 px monde** (30 × ~17 cases). À l'écran : 1 px monde = 4 px réels, 1 px HD = 2 px réels.
`TILE_SIZE` passera à 32 au « remaster » prévu : tout ce qui dépend des cases doit utiliser `Game.TILE_SIZE`.

## 1. Personnages

| Élément | Case (px HD) | Hauteur du perso | Affiché (px monde) | Origine / ancre |
| --- | --- | --- | --- | --- |
| Héros (toutes classes, `warrior_hd.png` 384×1008) | **64 × 56**, 6 colonnes × 18 lignes | 45 à 51 px HD (≈ 23–26 px monde, ~1,5 case) | 32 × 28 | pieds au point **(32, 54)** de la case |
| Ysolde (`ysolde.png` 294×408) | 49 × 51, 6 colonnes × 8 lignes | ~50 px HD | ~25 × 26 | offset (-24, -50) → pieds en bas au centre |
| Atelier, preset « Perso HD 48×64 » (prompts actuels) | **48 × 64** | ~55–56 px HD visés (Ysolde ~52) | 24 × 32 | pieds sur la dernière ligne, centré |

Planche du héros (`player.gd`, `ANIMS`) : 3 lignes par animation, dans l'ordre **face, dos, profil droit** (gauche = miroir) :
`idle` lignes 0–2 (4 images, 0,22 s), `walk` 3–5 (6 images, 0,1 s), `roll` 6–8 (6), `attack` 9–11 (5), `hurt` 12–14 (2, 0,08 s), `death` 15–17 (4, 0,15 s).
Mains : `warrior_hd.json` → `"hands": {"walk_0": [[x, y, angle], …]}` en px HD relatifs à l'ancre (dir 0 face, 1 dos, 2 profil).

Collisions du héros (px monde) : corps 12 × 8 (`0,75 × 0,5` case), zone de dégâts 12 × 24 (`0,75 × 1,5` case).

⚠ Écart à régler : l'Atelier exporte des cases **48×64** alors que la planche du jeu est en **64×56** avec l'ancre en (32, 54).
Les deux sont en px HD ; seule la case diffère (le perso doit faire ~45–56 px HD de haut dans les deux cas).

## 2. Armes et outils (px HD, affichés à 0,5)

| Arme | Image | | Arme | Image |
| --- | --- | --- | --- | --- |
| épée | 8 × 26 | | hache | 12 × 23 |
| grande épée | 15 × 51 | | pioche | 17 × 20 |
| arc | 9 × 36 | | masse | 11 × 20 |
| bâton (mage) | 10 × 46 | | | |

Dessinées verticales, manche en bas ; le point de prise est donné en px HD de l'image.

## 3. Ennemis et boss

| Créature | Case (px HD) | Grille | Échelle | Affiché (px monde) |
| --- | --- | --- | --- | --- |
| Sanglier (`boar.png` 522×192) | 87 × 48 | 6 × 4 | 0,5 | ~43 × 24 |
| Gobelin de roche (528×335) | 88 × 67 | 6 × 5 | 0,5 | 44 × 33 |
| Slime (260×128) | 65 × 32 | 4 × 4 | 0,5 | 32 × 16 |
| Araignée d'obsidienne (426×260) | voir sa scène | | 0,5 | |
| Solakor, boss (1020×652) | 204 × 163 | 5 × 4 | **0,75** | 153 × 122 |

Origine de chaque scène : sous les pieds (le `offset` du Sprite2D remonte l'image).

## 4. Tuiles et cartes

- **Tuiles des TileSet : 16 × 16 px monde** (taille par défaut, non HD). Atlas : `sylve_tiles.png` 128×128 (8×8 tuiles),
  `cave_tiles.png` 128×128, `dracombra_tiles.png` 128×64 (8×4).
- Le sol est redessiné par `scripts/world/ground_painter.gd` (shader `organic_ground`, bords ondulés), rendu en **HD = 32 px par case**,
  par morceaux de 12 × 12 cases. Le TileMapLayer « Ground » reste là, invisible, pour les collisions et la construction.
- ⚠ L'onglet Tuiles de l'Atelier travaille en **32 × 32** par défaut et exporte un TileSet à `tile_size` 32 :
  c'est la bonne taille HD, mais pour le jeu actuel (cases de 16) il faut soit réduire à 16, soit poser le calque à l'échelle 0,5.

| Carte | Taille (cases) | Taille (px monde) |
| --- | --- | --- |
| Sylve des Dracombres | 150 × 96 | 2400 × 1536 |
| Dracombra (ville) | 200 × 150 | 3200 × 2400 |
| Prologue — entrée de la caverne | 73 × 30 | 1168 × 480 |
| Prologue — couloir de la horde | 114 × 30 | 1824 × 480 |
| Prologue — passage du blessé | 76 × 26 | 1216 × 416 |
| Prologue — tanière de Solakor | 60 × 40 | 960 × 640 |

## 5. Décors et ressources (px HD, échelle 0,5, origine au pied)

Exemples relevés : chêne 120×118 (gros chêne 189×180), pin 58×118 / 29×59, buisson 40×35, lin 35×39, souche 37×28,
rocher gris 15×12 / 24×21, rocher à gemme 20×20, herbes hautes 38×32, fleurs ~32×25, feu de camp 92×29 (4 images),
cristaux 10×12 → 44×53, stalagmites 15×21 → 40×51, statue tête de dragon 160×108, porte de Dracombra 222×166.
Un arbre fait donc ~60 px monde de haut (≈ 4 cases), un buisson ~18 px monde.

## 6. Bâtiments (px HD, échelle 0,5) — nouveau système du 3 novembre 2026

Chaque bâtiment **réserve dès sa pose l'emprise de son dernier palier** ; tous ses paliers ont donc la même taille au sol.
Le vide des petits paliers est comblé dans le dessin (barrière, caisses, tonneaux, herbe).

| Bâtiment | Empreinte (cases) | Image (largeur) | Fichiers |
| --- | --- | --- | --- |
| Guilde | 4 × 4 | 128 px | `guild_0` … `guild_4` (5 paliers) |
| Logement (tente → cabane → maison) | 3 × 2 | 96 px | `house_0` … `house_2` |
| Forge | 3 × 2 | 96 px | `forge_0` … `forge_2` |
| Scierie (ex-hutte du bûcheron) | 3 × 2 | 96 px | `sawmill_0` … `sawmill_2` |
| Tannerie (ex-séchoir) | 3 × 2 | 96 px | `tannery_0`, `tannery_1` |
| Entrepôt | 3 × 2 | 96 px | `warehouse_0` … `warehouse_2` |
| Établi, jardin d'herbes, cabane du chasseur, carrière | 3 × 2 | 96 px | `<art>_0` |
| Coffre | 1 × 1 | 39 px | `chest` |
| Chantiers | 3 × 2 et 4 × 4 | 96 / 128 px | `chantier_3x2_0` (fondations), `chantier_3x2_1` (structure) |
| Chemins (gravier, pavés, dalles) | 1 × 1 | 4 tuiles de 32 × 32 côte à côte | `assets/sprites/town/path_gravel.png`… |

Tous dans `assets/sprites/buildings/` (le code charge `<art>_<palier>.png` ; s'il manque, il prend le palier d'en dessous).
Le sol de l'emprise est dessiné en bas de l'image (cases × 32 px de profondeur) ; le bâtiment peut monter au-dessus.
La porte est toujours en bas au centre de la façade. Dessins ChatGPT importés avec `tools/art/import_building.py`
(retire le magenta, recadre, réduit par blocs à la largeur de l'emprise) ; les autres restent PROVISOIRES
(`tools/placeholder/construction.py`). En jeu, le tri avec le héros se fait sur la ligne de façade (45 % de la profondeur
depuis le bas, 1,8 case pour la guilde) et seul l'arrière de l'emprise est solide : on marche dans la cour.

## 7. Interface

- Icônes d'objets : `items.png` 864 × 32, icônes de **32 × 32** px HD sur une ligne.
- HUD dessiné dans le viewport 640 × 360.

## 8. Planches ChatGPT (avant passage dans l'Atelier)

Images 1536×1024 ou 1672×941 (16:9) environ, fond magenta `#FF00FF`, « gros pixel » d'environ 10 px réels
→ après réduction dans l'Atelier, un personnage de ~56 px HD de haut.
