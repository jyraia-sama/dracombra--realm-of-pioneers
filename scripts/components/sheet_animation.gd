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
