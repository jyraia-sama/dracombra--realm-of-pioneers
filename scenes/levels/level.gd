class_name Level
extends Node2D
## Script commun à tous les niveaux : limites et tremblement de la caméra.

## Le calque dont la zone peinte délimite le niveau (en général, les murs).
@export var bounds_layer: TileMapLayer

var _camera: Camera2D
var _shake_strength: float = 0.0
var _shake_time: float = 0.0
var _shake_duration: float = 0.0


## Fait trembler la caméra du niveau courant, depuis n'importe quel nœud.
static func shake(from: Node, strength: float, duration: float) -> void:
	var level := from.get_tree().current_scene as Level
	if level != null:
		level.shake_camera(strength, duration)


func _ready() -> void:
	var player := get_player()
	if player != null:
		_camera = player.get_node_or_null("Camera2D") as Camera2D
		_place_player(player)
	_limit_camera()
	# Sauvegarde automatique en arrivant dans un niveau (après le prologue).
	Save.save_game.call_deferred()


## Arrivée par une sortie (Marker2D « Spawns/<nom> ») ou depuis une sauvegarde.
func _place_player(player: Player) -> void:
	if Game.pending_position != null:
		player.global_position = Game.pending_position
		Game.pending_position = null
		Game.next_spawn = &""
	elif Game.next_spawn != &"":
		var marker := get_node_or_null("Spawns/" + String(Game.next_spawn)) as Node2D
		if marker != null:
			player.global_position = marker.global_position
		Game.next_spawn = &""
	if _camera != null:
		_camera.reset_smoothing.call_deferred()


func _process(delta: float) -> void:
	if _camera == null:
		return
	if _shake_time > 0.0:
		_shake_time -= delta
		var strength := _shake_strength * clampf(_shake_time / _shake_duration, 0.0, 1.0)
		_camera.offset = Vector2(randf_range(-strength, strength), randf_range(-strength, strength)).round()
	else:
		_camera.offset = Vector2.ZERO


func shake_camera(strength: float, duration: float) -> void:
	if strength >= _shake_strength * clampf(_shake_time / maxf(_shake_duration, 0.001), 0.0, 1.0):
		_shake_strength = strength
		_shake_duration = duration
		_shake_time = duration


func get_player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


## Centre d'une case d'un calque, en coordonnées du monde.
func cell_to_world(layer: TileMapLayer, cell: Vector2i) -> Vector2:
	return layer.to_global(layer.map_to_local(cell))


func _limit_camera() -> void:
	if _camera == null or bounds_layer == null:
		return
	var used: Rect2i = bounds_layer.get_used_rect()
	var tile_size: Vector2i = bounds_layer.tile_set.tile_size
	var top_left: Vector2 = bounds_layer.to_global(Vector2(used.position * tile_size))
	var bottom_right: Vector2 = bounds_layer.to_global(Vector2(used.end * tile_size))
	_camera.limit_left = int(top_left.x)
	_camera.limit_top = int(top_left.y)
	_camera.limit_right = int(bottom_right.x)
	_camera.limit_bottom = int(bottom_right.y)
