class_name SheetAnimation
extends RefCounted
## Animations rangées en lignes dans une planche de sprites (une ligne = une animation).
## Exemple :
##     const ANIMS := {&"idle": [0, 4, 0.16], &"run": [1, 6, 0.08]}  # [ligne, images, durée d'une image]
##     sprite.frame = SheetAnimation.frame(ANIMS, &"run", 6, temps_écoulé, true)


## Numéro d'image de `sprite.frame` pour l'animation `anim` après `elapsed` secondes.
## `columns` est le nombre de colonnes de la planche (`hframes`).
static func frame(anims: Dictionary, anim: StringName, columns: int, elapsed: float, loop: bool) -> int:
	var data: Array = anims[anim]
	var row: int = data[0]
	var count: int = data[1]
	var frame_time: float = data[2]
	var index := int(elapsed / frame_time)
	index = index % count if loop else mini(index, count - 1)
	return row * columns + index


# ------------------------------------------------------------------ planches décrites par un .json
# Règle des assets (voir REGLES_ASSETS.md) : chaque planche a un .json du même nom qui donne
# la case, l'ancre et les animations. Le code lit ce fichier au lieu d'avoir les valeurs en dur :
# remplacer un sprite provisoire par le sprite final = écraser le PNG et son .json.
#
#     { "cell": [64, 56], "anchor": [32, 54], "scale": 0.5, "dirs": ["bas", "haut", "droite"],
#       "anims": { "walk": {"row": 3, "frames": 6, "fps": 10, "loop": true}, ... } }
#
# fps = 0 : la durée est calée sur l'action (roulade, attaque...), comme dans le code existant.


## Lit le .json d'une planche ({} s'il manque ou est illisible).
static func load_sheet(json_path: String) -> Dictionary:
	if not FileAccess.file_exists(json_path):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	return data if data is Dictionary else {}


## Convertit le bloc « anims » du .json au format [ligne, images, durée d'une image].
## Les animations absentes du .json gardent la valeur de `fallback`.
static func anims_from(sheet: Dictionary, fallback: Dictionary = {}) -> Dictionary:
	var out := fallback.duplicate()
	var anims = sheet.get("anims", {})
	if not anims is Dictionary:
		return out
	for key in anims:
		var a = anims[key]
		if not a is Dictionary or not a.has("row") or not a.has("frames"):
			continue
		var fps := float(a.get("fps", 0.0))
		out[StringName(key)] = [int(a["row"]), maxi(1, int(a["frames"])), 1.0 / fps if fps > 0.0 else 0.0]
	return out


## Règle un Sprite2D d'après la planche : découpe (hframes/vframes), échelle, ancre aux pieds.
## Renvoie le nombre de colonnes.
static func apply_to(sprite: Sprite2D, texture: Texture2D, sheet: Dictionary) -> int:
	sprite.texture = texture
	sprite.centered = false
	var cell: Array = sheet.get("cell", [texture.get_width(), texture.get_height()])
	var columns := maxi(1, int(texture.get_width() / float(cell[0])))
	sprite.hframes = columns
	sprite.vframes = maxi(1, int(texture.get_height() / float(cell[1])))
	var s := float(sheet.get("scale", 0.5))
	sprite.scale = Vector2(s, s)
	var anchor: Array = sheet.get("anchor", [float(cell[0]) / 2.0, float(cell[1])])
	sprite.offset = Vector2(-float(anchor[0]), -float(anchor[1]))
	return columns
