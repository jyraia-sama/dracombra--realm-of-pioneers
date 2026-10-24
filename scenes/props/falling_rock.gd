class_name FallingRock
extends Node2D
## Rocher qui tombe du plafond : son ombre grandit au sol pour prévenir,
## puis il s'écrase, fait trembler l'écran et blesse ce qui est dessous.

signal landed

## Durée de la chute, en secondes : c'est le temps laissé pour s'écarter.
@export var fall_time: float = 0.9
## Hauteur de départ du rocher, en tiles.
@export var fall_height_tiles: float = 11.0
## Dégâts infligés à l'impact (0 = aucun).
@export var damage: int = 1
## Force du tremblement de caméra à l'impact, en pixels.
@export var shake_strength: float = 3.0
## Si true, le rocher reste au sol après l'impact (pour former un éboulis).
@export var stays: bool = false

@onready var shadow: Polygon2D = $Shadow
@onready var rock: Sprite2D = $Rock
@onready var hitbox: Hitbox = $Hitbox
@onready var hitbox_shape: CollisionShape2D = $Hitbox/CollisionShape2D
@onready var dust: CPUParticles2D = $Dust


func _ready() -> void:
	var tile := float(Game.TILE_SIZE)
	# Ombre elliptique au sol.
	var points := PackedVector2Array()
	for i in 16:
		var angle := TAU * i / 16.0
		points.append(Vector2(cos(angle) * tile * 0.45, sin(angle) * tile * 0.2))
	shadow.polygon = points
	shadow.scale = Vector2(0.3, 0.3)

	hitbox_shape.shape.size = Vector2(tile * 0.9, tile * 0.7)
	hitbox.damage = damage
	hitbox.knockback_tiles = 1.0
	hitbox.active = false

	rock.position.y = -fall_height_tiles * tile
	var tween := create_tween().set_parallel()
	tween.tween_property(rock, "position:y", -tile * 0.5, fall_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(shadow, "scale", Vector2.ONE, fall_time)
	tween.tween_property(shadow, "color:a", 0.55, fall_time)
	tween.chain().tween_callback(_land)


func _land() -> void:
	Level.shake(self, shake_strength, 0.25)
	dust.restart()
	if damage > 0:
		hitbox.active = true
		await get_tree().create_timer(0.12).timeout
		hitbox.active = false
	landed.emit()
	if stays:
		return
	# Le rocher éclate et disparaît.
	var tween := create_tween().set_parallel()
	tween.tween_property(rock, "scale", Vector2(1.3, 0.6), 0.25)
	tween.tween_property(rock, "modulate:a", 0.0, 0.35)
	tween.tween_property(shadow, "color:a", 0.0, 0.35)
	tween.chain().tween_interval(0.4)
	tween.chain().tween_callback(queue_free)
