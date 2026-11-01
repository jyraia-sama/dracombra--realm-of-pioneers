class_name WebShot
extends Hitbox
## Jet de toile de la reine araignée : coup léger (1 dégât) qui ralentit le héros de moitié
## pendant 2 secondes. Dessiné par le code (PROVISOIRE). Se défait contre les murs.

const SLOW := 0.5
const SLOW_TIME := 2.0

var velocity := Vector2.ZERO
var lifetime := 1.6
var _t := 0.0


static func create(from: Vector2, direction: Vector2, shooter: Node2D) -> WebShot:
	var w := WebShot.new()
	w.collision_layer = 0
	w.collision_mask = 8 | 1  # héros (zone de dégâts) + murs
	w.damage = 1
	w.knockback_tiles = 0.0
	w.once_per_activation = true
	w.source = shooter
	w.position = from
	w.velocity = direction.normalized() * Game.TILE_SIZE * 6.0
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 5.0
	shape.shape = c
	w.add_child(shape)
	return w


func _ready() -> void:
	super()
	hit_landed.connect(_on_hit)
	body_entered.connect(func(_b: Node) -> void: _burst())


func _physics_process(delta: float) -> void:
	super(delta)
	position += velocity * delta
	_t += delta
	if _t >= lifetime:
		_burst()
	queue_redraw()


func _on_hit(h: Hurtbox) -> void:
	var player := h.get_parent() as Player
	if player:
		_slow(player)
	_burst()


static func _slow(player: Player) -> void:
	player.speed_multiplier = minf(player.speed_multiplier, SLOW)
	Emote.show(player, "Englué !", Color(0.9, 0.9, 1.0), 34.0)
	var tag := Time.get_ticks_msec()
	player.set_meta("web_slow", tag)
	player.get_tree().create_timer(SLOW_TIME).timeout.connect(func() -> void:
		if is_instance_valid(player) and player.get_meta("web_slow", 0) == tag:
			player.speed_multiplier = 1.0)


func _burst() -> void:
	if is_queued_for_deletion():
		return
	PixelBurst.spawn(self, global_position, PixelBurst.DUST, Vector2.ZERO, 1.5)
	queue_free()


func _draw() -> void:
	var spin := _t * 6.0
	var col := Color(0.92, 0.92, 1.0, 0.9)
	for i in 4:
		var a := spin + i * PI / 4.0
		draw_line(Vector2.from_angle(a) * -5.0, Vector2.from_angle(a) * 5.0, col, 1.0)
	draw_arc(Vector2.ZERO, 3.0, 0.0, TAU, 10, col, 1.0)
	draw_arc(Vector2.ZERO, 5.0, 0.0, TAU, 12, Color(col, 0.6), 1.0)
