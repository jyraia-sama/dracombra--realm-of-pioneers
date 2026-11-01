class_name OreMarker
extends Node2D
## Rend un filon reconnaissable au milieu du décor : petites étincelles de la couleur de la
## ressource, et l'icône de ce qu'il donne qui flotte au-dessus quand le héros approche.
## Disparaît avec le filon (il est enfant du décor récoltable).

## Hauteur de l'icône au-dessus du pied du filon, en px monde.
var height := 22.0
var color := Color.WHITE
var icon: Texture2D

var _t := 0.0
var _near := 0.0
var _sparks: Array[Dictionary] = []


func _ready() -> void:
	z_index = 20
	_t = randf() * 3.0


func _process(delta: float) -> void:
	_t += delta
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var close := player != null and player.global_position.distance_to(global_position) < Game.TILE_SIZE * 4.0
	_near = move_toward(_near, 1.0 if close else 0.0, delta * 4.0)
	# Une étincelle de temps en temps sur le filon.
	if randf() < delta * 2.2:
		_sparks.append({"pos": Vector2(randf_range(-7, 7), -randf_range(2, height - 6)).round(), "life": 0.5})
	for s in _sparks:
		s["life"] -= delta
	_sparks = _sparks.filter(func(s): return s["life"] > 0.0)
	queue_redraw()


func _draw() -> void:
	for s in _sparks:
		var a: float = clampf(s["life"] / 0.5, 0.0, 1.0)
		var p: Vector2 = s["pos"]
		var c := Color(color, a)
		var r := 2.0 if a > 0.5 else 1.0
		draw_rect(Rect2(p - Vector2(0.5, r + 0.5), Vector2(1, r * 2 + 1)), c)
		draw_rect(Rect2(p - Vector2(r + 0.5, 0.5), Vector2(r * 2 + 1, 1)), c)
	if icon and _near > 0.01:
		var bob := sin(_t * 3.0) * 1.5
		var size := Vector2(12, 12)
		var at := Vector2(-size.x / 2.0, -height - size.y + bob).round()
		draw_rect(Rect2(at - Vector2(2, 2), size + Vector2(4, 4)), Color(0.05, 0.04, 0.08, 0.7 * _near))
		draw_rect(Rect2(at - Vector2(2, 2), size + Vector2(4, 4)), Color(color, 0.9 * _near), false, 1.0)
		draw_texture_rect(icon, Rect2(at, size), false, Color(1, 1, 1, _near))
