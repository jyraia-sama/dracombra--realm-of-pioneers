extends Node
## Sauvegarde de la partie dans user://save.json.
## Le prologue n'est pas sauvegardé : on commence à sauvegarder au réveil à Dracombra.

const PATH := "user://save.json"
const VERSION := 1


func has_save() -> bool:
	return FileAccess.file_exists(PATH)


func save_game() -> void:
	if not Game.has_flag(&"prologue_done"):
		return
	var scene := get_tree().current_scene
	var player := get_tree().get_first_node_in_group("player") as Player
	var data := {
		"version": VERSION,
		"scene": scene.scene_file_path if scene else "",
		"position": [player.global_position.x, player.global_position.y] if player else null,
		"game": Game.serialize(),
		"inventory": Inventory.serialize(),
		"town": Town.serialize(),
		"hero": Hero.serialize(),
		"quests": Quests.serialize(),
	}
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))


## Charge la sauvegarde et rejoint le niveau où l'on était.
func load_game() -> bool:
	if not has_save():
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(data) != TYPE_DICTIONARY:
		return false
	Game.reset()
	Game.deserialize(data.get("game", {}))
	Inventory.deserialize(data.get("inventory", {}))
	Town.deserialize(data.get("town", {}))
	Hero.deserialize(data.get("hero", {}))
	Quests.deserialize(data.get("quests", {}))
	var pos = data.get("position")
	if pos != null:
		Game.pending_position = Vector2(pos[0], pos[1])
	var scene: String = data.get("scene", "")
	if scene == "" or not ResourceLoader.exists(scene):
		scene = "res://scenes/levels/dracombra/dracombra.tscn"
	Transition.change_scene(scene)
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
