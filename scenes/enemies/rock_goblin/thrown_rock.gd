class_name ThrownRock
extends Hitbox
## Pierre lancée par un gobelin des roches.
## Se brise contre les murs ou en touchant le guerrier.

## Vitesse et direction, en pixels par seconde (réglée par le lanceur).
var velocity: Vector2 = Vector2.ZERO
## Durée de vie maximale, en secondes.
var lifetime: float = 3.0

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	super()
	body_entered.connect(_on_body_entered)
	hit_landed.connect(func(_hurtbox: Hurtbox) -> void: _shatter())


func _physics_process(delta: float) -> void:
	position += velocity * delta
	sprite.rotation += delta * 12.0
	lifetime -= delta
	if lifetime <= 0.0:
		_shatter()
		return
	super(delta)


func _on_body_entered(_body: Node2D) -> void:
	# Les seuls corps détectés sont les murs (couche "world").
	_shatter()


func _shatter() -> void:
	if not active:
		return
	active = false
	velocity = Vector2.ZERO
	set_deferred("monitoring", false)
	var tween := create_tween().set_parallel()
	tween.tween_property(sprite, "scale", Vector2(1.6, 1.6), 0.12)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.12)
	tween.chain().tween_callback(queue_free)
