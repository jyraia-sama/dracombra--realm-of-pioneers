extends CanvasLayer
## Interface provisoire : affiche les points de vie du guerrier.
## Elle sera remplacée par de vrais cœurs en pixel art.

@onready var health_label: Label = $HealthLabel


func _ready() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		health_label.text = ""
		return
	player.health.health_changed.connect(_on_health_changed)
	_on_health_changed(player.health.current_health, player.health.max_health)


func _on_health_changed(current: int, maximum: int) -> void:
	health_label.text = "PV : %d / %d" % [current, maximum]
