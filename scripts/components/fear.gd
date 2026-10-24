class_name Fear
extends Node
## Rend un ennemi capable d'être terrifié : il se fige, crie (« ! »),
## puis s'enfuit à toute vitesse et disparaît.
## L'ennemi doit avoir un nœud enfant « Visual » et vérifier `is_scared` dans son
## _physics_process (il laisse alors ce composant piloter sa vitesse).

## Durée pendant laquelle il reste figé de peur, en secondes.
@export var freeze_time: float = 0.6
## Vitesse de fuite, en tiles par seconde.
@export var flee_speed_tiles: float = 6.0
## Durée de la fuite avant de disparaître, en secondes.
@export var flee_time: float = 1.6

var is_scared: bool = false

var _body: CharacterBody2D
var _direction: Vector2 = Vector2.LEFT
var _time: float = 0.0


func _ready() -> void:
	_body = get_parent() as CharacterBody2D


## Terrifie l'ennemi, qui s'enfuira à l'opposé de `source`.
func scare(source: Vector2) -> void:
	if is_scared or _body == null:
		return
	is_scared = true
	_time = 0.0
	_direction = source.direction_to(_body.global_position)
	if _direction == Vector2.ZERO:
		_direction = Vector2.LEFT
	# Il ne bloque plus personne pendant sa fuite.
	_body.collision_mask = 1
	Emote.show(_body, "!", Color(1.0, 0.4, 0.3))


func _physics_process(delta: float) -> void:
	if not is_scared:
		return
	_time += delta
	var visual := _body.get_node_or_null("Visual") as Node2D
	if _time < freeze_time:
		# Il tremble de peur sur place.
		_body.velocity = Vector2.ZERO
		if visual:
			visual.position.x = randf_range(-1.5, 1.5)
		return
	if visual:
		visual.position.x = 0.0
		var sprite := visual.get_node_or_null("Sprite") as Sprite2D
		if sprite:
			sprite.flip_h = _direction.x < 0.0
	_body.velocity = _direction * flee_speed_tiles * Game.TILE_SIZE
	if _time > freeze_time + flee_time and visual and visual.modulate.a >= 1.0:
		var tween := _body.create_tween()
		tween.tween_property(visual, "modulate:a", 0.0, 0.4)
		tween.tween_callback(_body.queue_free)
		visual.modulate.a = 0.99
