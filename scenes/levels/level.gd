class_name Level
extends Node2D
## Script commun à tous les niveaux.
## Pour l'instant, il empêche la caméra de sortir de la zone peinte.

## Le calque dont la zone peinte délimite le niveau (en général, les murs).
@export var bounds_layer: TileMapLayer


func _ready() -> void:
	_limit_camera()


func _limit_camera() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or bounds_layer == null:
		return
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return
	var used: Rect2i = bounds_layer.get_used_rect()
	var tile_size: Vector2i = bounds_layer.tile_set.tile_size
	var top_left: Vector2 = bounds_layer.to_global(Vector2(used.position * tile_size))
	var bottom_right: Vector2 = bounds_layer.to_global(Vector2(used.end * tile_size))
	camera.limit_left = int(top_left.x)
	camera.limit_top = int(top_left.y)
	camera.limit_right = int(bottom_right.x)
	camera.limit_bottom = int(bottom_right.y)
