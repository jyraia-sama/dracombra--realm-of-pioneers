class_name EnemyArrow
extends Hitbox
## Flèche d'os tirée par un squelette archer (coup léger). Se brise contre les murs.
## Dessinée par le code (PROVISOIRE).

var velocity := Vector2.ZERO
var lifetime := 1.4
var _t := 0.0


static func create(from: Vector2, direction: Vector2, dmg: int, shooter: Node2D) -> EnemyArrow:
	var a := EnemyArrow.new()
	a.collision_layer = 0
	a.collision_mask = 8 | 1
	a.damage = dmg
	a.knockback_tiles = 0.4
	a.once_per_activation = true
	a.source = shooter
	a.position = from
	a.velocity = direction.normalized() * Game.TILE_SIZE * SkeletonArcher.ARROW_SPEED
	a.rotation = direction.angle()
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 3.0
	shape.shape = c
	a.add_child(shape)
	return a


func _ready() -> void:
	super()
	hit_landed.connect(func(_h: Hurtbox) -> void: _break())
	body_entered.connect(func(_b: Node) -> void: _break())


func _physics_process(delta: float) -> void:
	super(delta)
	position += velocity * delta
	_t += delta
	if _t >= lifetime:
		_break()


func _break() -> void:
	if is_queued_for_deletion():
		return
	PixelBurst.spawn(get_parent(), global_position, PixelBurst.DUST, Vector2.ZERO, 0.8)
	queue_free()


func _draw() -> void:
	draw_line(Vector2(-7, 0), Vector2(5, 0), Color(0.86, 0.82, 0.7), 1.5)
	draw_line(Vector2(5, 0), Vector2(2, -2), Color(0.95, 0.95, 0.9), 1.0)
	draw_line(Vector2(5, 0), Vector2(2, 2), Color(0.95, 0.95, 0.9), 1.0)
	draw_line(Vector2(-7, 0), Vector2(-9, -2), Color(0.7, 0.3, 0.3), 1.0)
	draw_line(Vector2(-7, 0), Vector2(-9, 2), Color(0.7, 0.3, 0.3), 1.0)
