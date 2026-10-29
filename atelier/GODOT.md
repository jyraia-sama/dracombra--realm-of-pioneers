# Atelier Dracombra → Godot 4 : ce qu'il faut faire

Version de l'Atelier : 1.6.0 et suivantes. Projet Godot : Dracombra (Godot 4.7).

## Une seule fois dans le projet Godot

1. **Pixel art net partout** : Projet > Paramètres du projet > Rendu > Textures > *Default Texture Filter* = **Nearest**.
2. **Dossier des sprites** : par exemple `res://assets/sprites/`. Dans l'Atelier .exe, « Choisir le dossier… » sur ce dossier : le chemin `res://` se remplit seul.
3. **Fichiers .json dans le jeu exporté** : Projet > Exporter > préréglage > Ressources > *Filtres pour exporter des fichiers non-ressources* : ajouter `*.json`.

## Personnage (projet de type « Personnage »)

L'export écrit dans le dossier : `nom.png`, `nom.tres` (SpriteFrames), `nom.tscn` (scène prête), `nom.json` (mains/angles), `porte_outil.gd`.

1. Glisser `nom.tscn` dans la scène du joueur. C'est un **AnimatedSprite2D** : filtre Nearest, pieds sur l'origine du nœud, première animation lancée.
2. Animations nommées `action_direction` : `idle_bas`, `marche_droite`, `frappe_haut`… Script : `$Heros.play("marche_" + direction)`.
3. Gauche = profil droit passé au « Miroir » dans l'Atelier (pas de `flip_h` dans Godot).

## Outils et armes (projet de type « Objets », nommé « outils »)

Un PNG par objet (`hache.png`, `hache_fer.png`…) et `outils.json` avec le point de prise de chacun, **dans le même dossier** que les personnages.

## Sols (projet de type « Tuiles »)

`nom.png` (atlas), `nom.tres` (TileSet avec Terrain Set 0, mode coins), `nom.json`. TileMapLayer > Tile Set = `nom.tres`, onglet Terrains pour peindre. Tuiles 32×32 par défaut.

## Bâtiments (projet de type « Bâtiments »)

Pour chaque bâtiment : `nom.png` (terminé), `nom_etape1.png`… (chantier), `nom.tscn`, plus `batiment.gd` et un `.json`.
- Node2D, origine = **coin bas-gauche de l'empreinte** ; *Y Sort* sur le parent.
- Enfants : `Image` (Sprite2D), `Collision` (StaticBody2D), `Porte` (Marker2D).
- `etape = 0` à la pose, `avancer()` à chaque palier (true = terminé), `etape = -1` = terminé. `cases_occupees(case_haut_gauche)`, `taille_empreinte`, `case_porte`.

## Décors et ressources (projet de type « Décors »)

Pour chaque décor : `nom.png`, `nom_abime.png`, `nom_recolte.png`, `nom_pousse1.png`… (si dessinés), `nom.tscn`, plus `ressource.gd` et un `.json`.
- Node2D, origine = **pied** du décor ; *Y Sort* sur le parent.
- `var n = decor.frapper("hache_fer")` : `n > 0` = récolté (signal `recolte(ressource, quantite)`). Groupe `ressources`. Repousse auto (`repousse_secondes`). Sauvegarde : `etat_sauvegarde()` / `charger(d)`.

## porte_outil.gd

Inspecteur : **Donnees Perso** = `res://…/nom.json`, **Donnees Outils** = `res://…/outils.json`, **Outil Equipe** = ex. `hache_fer`.
En jeu : `$Heros.equiper("pioche")`, `$Heros.equiper("")` pour ranger.

## Si quelque chose cloche

- Outil invisible : vérifier les deux chemins .json, le nom exact (sans .png), et que la main est placée sur les images de l'animation.
- Image floue : filtre Nearest.
- Outil décalé d'un pixel : régler le point de prise (outil « Prise ») dans le projet « outils », réexporter.
