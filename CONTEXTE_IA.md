# Dracombra + Atelier Dracombra — fiche technique pour une IA (Tiamat, Claude Code)

À lire en premier par toute session qui n'a pas accès aux deux programmes Windows
(`Dracombra.exe`, le jeu, et `AtelierDracombra.exe`, l'outil de pixel art).
Tout le code des deux est ici : le jeu à la racine de ce dépôt, l'Atelier dans `atelier/`.

Dépôt public : `https://github.com/jyraia-sama/dracombra--realm-of-pioneers`
- `main` : le jeu Godot + `atelier/` (sources de l'Atelier, ignorées par Godot grâce à `.gdignore`)
- `atelier-updates` : versions publiées de l'Atelier (`atelier-index.html` = page complète, `AtelierDracombra.exe`, `releases.json`). Ne pas fusionner.
- `updates` : canal de mises à jour du jeu.

Lecture seule suffit : `git clone --depth 1 https://github.com/jyraia-sama/dracombra--realm-of-pioneers`.

---

## 1. Le jeu (Godot 4.7, GDScript)

Guilde + city builder + action + farm, pixel art « HD » visant le rendu de Romestead. Monde d'Aethelgard, contrée de la
Sylve des Dracombres. Le héros (nom = pseudo du joueur) est un capitaine déserteur d'Elysia ; prologue dans une caverne
jusqu'au dragon Solakor, réveil à Dracombra (ville bâtie sur les ruines de l'ancienne capitale humains/dragons), soigné
par l'herboriste Ysolde (tuto).

- Fenêtre : viewport 640×360, affiché en 1920×1080 plein écran. Scène de départ : `res://scenes/ui/title_screen.tscn`.
- Export Windows : `build/Dracombra.exe` (préréglage « Windows »).
- Autoloads : `Updater`, `Game` (constantes, drapeaux, jours ; `Game.TILE_SIZE = 16`, passera à 32 au remaster),
  `Inventory`, `Hero`, `Town`, `Save`, `Interaction`, `Narration`, `Transition`, `Choice`, `Crafting`, `Quests`, `GameMenu`.
- Dossiers : `scenes/` (levels/prologue, levels/sylve, levels/dracombra, player, town, ui, enemies, bosses, npc, props),
  `scripts/` (autoload, components — harvestable, hitbox, hurtbox, health, sheet_animation…, data — item/building/loot/skill),
  `data/` (items .tres, buildings), `assets/sprites/` (hero, npc, enemies, bosses, props, buildings, weapons, items), `assets/tilesets/`.
- `tools/` : scripts Python qui ont servi à préparer les images ChatGPT (`tools/art/`, `tools/city/`, `tools/prologue/`).
- Héros : 4 classes de base (guerrier, archer, mage, clerc), 8 directions, outil équipé visible en main (héros dessiné mains vides,
  outil posé par le jeu).

## 2. L'Atelier Dracombra (outil de pixel art, v1.10.0)

Transforme les planches ChatGPT (fond magenta) en sprites propres pour Godot, avec retouche.

- Page web unique : `atelier/src.html` (tout le code JS : détourage, grille, palette, découpe, retouche, calques, animation,
  objets, tuiles, bâtiments, décors, scène d'essai, export Godot, format .atelier).
- Lanceur Windows en Go : `atelier/main.go`, `files.go`, `update.go` (sert la page sur `http://127.0.0.1:47613`).
- Détails de fabrication et de l'API : `atelier/BUILD.md`. Côté Godot : `atelier/GODOT.md`.

### Chaîne de traitement d'une planche
1. **Fond** : couleur détectée sur les bords (magenta `#FF00FF`), tolérance 90, retrait du liseré rose (150).
2. **Grille pixel** : taille d'un « gros pixel » ChatGPT détectée par analyse de Fourier (souvent ≈ 10 px réels), décalage X/Y.
3. **Réduction** : médiane de chaque case → image basse résolution. Puis **couleurs** : éclat (+20), luminosité, k-means
   (24 couleurs par défaut) ou palette Dracombra enregistrée, retrait des pixels isolés.
4. **Découpe** : « Sprites séparés » (composantes connexes, pieds alignés en bas) ou « Grille fixe » colonnes × lignes.
   Cases : 16×16, 32×32, 16×32, 32×48, **48×64 (perso HD, la norme actuelle)**, 64×96, ou sur mesure.
5. **Retouche** puis **export** (PNG + .tres + .tscn + .json, voir GODOT.md).

### Conventions à respecter pour toute image produite pour l'Atelier
- Fond uni magenta pur `#FF00FF`, aucune couleur rose/magenta dans le sujet (lumières : doré pour le clerc, cyan pour le mage, vert pour Ysolde).
- Pixels nets, aucun anti-aliasing, contour sombre de 1 px, 3–4 tons par couleur, palette chatoyante et saturée.
- Vue de dessus en trois quarts façon Romestead, proportions légèrement chibi.
- Personnages : ~55–56 px de haut (Ysolde ~52), case 48×64, pieds sur la dernière ligne, mains vides.
- Fiche de référence = 3 vues (face, dos, profil droit) ; marche = 4 images ; action = 3 images ; profil gauche = miroir.
- Tuiles de sol : 32×32. Outils : dessinés verticaux, manche en bas.
- Noms : animation + direction en minuscules sans accents (`marche_bas`, `frappe_droite`, `idle_haut`).
  Directions : `bas, bas_droite, droite, haut_droite, haut, haut_gauche, gauche, bas_gauche`.
  États de décor : `plein, abime, recolte, pousse1, pousse2, pousse3`.

### Format des projets (`.atelier` = JSON ; identique dans `%APPDATA%\AtelierDracombra\projets\<nom>.json`)
```jsonc
{
  "app": "atelier-dracombra", "version": 3,
  "type": "perso" | "objets" | "tuiles" | "batiments" | "decors",   // "scene" pour une scène d'essai
  "name": "heros", "savedAt": "ISO-8601", "thumb": "data:image/png;base64,…",
  "cellW": 48, "cellH": 64, "sel": 0, "cur": 0,
  "settings": { "tol": "90", "edge": "150", "gsize": "10", "vib": "20", "ncol": "24", "expName": "heros",
                "expPath": "res://assets/sprites/", "expFps": "6", "projType": "perso", "tileSize": "32", … },
  "sheets": [ { "id": 1, "name": "fiche.png", "src": "data:image/png;base64,…",   // planche ChatGPT d'origine
                "key": [255,0,255], "grid": {"s":10,"ox":0,"oy":0}, "sliceMode": "auto"|"grid", "settings": {…} } ],
  "frames": [ {
      "anim": "marche", "dir": "bas", "w": 48, "h": 64, "dur": 1, "sheet": 1, "uid": "…",
      "anchor": {"x":30,"y":40,"angle":0,"front":true,"flip":false} | null,   // main (perso), prise (objet), pied (décor)
      "coll": {"x":…,"y":…,"w":…,"h":…} | null,                                 // collision (décors)
      "pivots": {"3":[x,y]} | null, "parts": "base64 Uint8[w*h]" | null,        // parties : 1 tête 2 buste 3 bras G 4 bras D 5 jambe G 6 jambe D
      "bits": null | 0..15, "terr": null | ["terre","herbe"],                   // tuiles de raccord
      "active": 0,
      "layers": [ { "name": "Base", "visible": true, "data": "base64 RGBA brut, w*h*4 octets" } ]
  } ],
  "decors": { "chene": {"res":"bois","qty":4,"hits":4,"tool":"hache","regrow":10,"blockAfter":true,"solid":true} },
  "buildings": [ { "name":"maison","w":8,"h":7,"stage":0,"stages":[{"items":[{"uid":"…","x":0,"y":0,"flip":false}]}],
                   "foot":[0,1,…],"block":[0,1,…],"door":{"x":3,"y":6} } ], "bcur": 0
}
```
L'image visible d'une frame = calques visibles superposés dans l'ordre (le dernier par-dessus, pixel opaque remplace).

### Lire / écrire une frame en Python
```python
import json, base64
from PIL import Image
p = json.load(open("heros.atelier", encoding="utf-8"))
f = p["frames"][0]
img = Image.new("RGBA", (f["w"], f["h"]))
for L in f["layers"]:
    if L["visible"]:
        lay = Image.frombytes("RGBA", (f["w"], f["h"]), base64.b64decode(L["data"]))
        img.alpha_composite(lay)
img.save("frame0.png")
# retouche, puis réécriture d'un calque :
f["layers"][0]["data"] = base64.b64encode(img.convert("RGBA").tobytes()).decode()
json.dump(p, open("heros.atelier", "w", encoding="utf-8"))
```
Garder la même taille `w×h`, des alphas 0 ou 255 et peu de couleurs. Pour ajouter une retouche sans écraser, ajouter un
calque `{"name":"Tiamat","visible":true,"data":…}`.

### Brancher Tiamat sur l'Atelier en marche
- `GET http://127.0.0.1:47613/api/info` → `{"app":true,"version":"1.10.0",…}` si l'Atelier est ouvert.
- `GET /api/projects` (liste), `GET /api/projects/<nom>`, `PUT /api/projects/<nom>` (corps = le JSON ci-dessus) :
  pas d'en-tête spécial. Après un PUT, rouvrir le projet dans l'Atelier (Fichier > Projets rangés dans l'Atelier…).
- Les routes `/api/file/*` sont réservées à la page de l'Atelier (en-tête `X-Atelier: 1` + chemins choisis par l'utilisateur) :
  pour un fichier `.atelier` sur le disque, le lire/écrire directement.
- Sans Atelier ouvert : modifier le `.atelier` ou `%APPDATA%\AtelierDracombra\projets\<nom>.json` directement,
  ou produire une planche PNG sur fond magenta que l'utilisateur ouvre dans l'Atelier.

## 3. Matériel de l'utilisateur
Windows 11 Pro, i5-13600KF, 32 Go de RAM, RTX 4070 (12 Go VRAM) : de quoi faire tourner une IA d'image locale
(Stable Diffusion / SDXL avec un modèle ou LoRA pixel art) pour Tiamat.
