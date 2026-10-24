extends Node
## Trouve l'objet interactif le plus proche du héros et le déclenche avec « interact ».
## L'interface lit Interaction.focused pour afficher l'invite (« E : Dormir »).

signal focus_changed(target: Interactable)

var focused: Interactable
## Bloque les interactions (mode construction, menus...).
var blocked := false


func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	var best: Interactable = null
	if player != null and not blocked and not player.input_locked:
		var best_d := INF
		for node in get_tree().get_nodes_in_group("interactables"):
			var it := node as Interactable
			if it != null and it.in_range(player.global_position):
				var d := player.global_position.distance_squared_to(it.global_position)
				if d < best_d:
					best_d = d
					best = it
	if best != focused:
		focused = best
		focus_changed.emit(focused)
	if focused != null and Input.is_action_just_pressed("interact"):
		focused.interacted.emit()
