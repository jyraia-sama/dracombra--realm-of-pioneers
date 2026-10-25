class_name SkillArea
extends Hitbox
## Zone de dégâts d'une technique ou d'un sort : onde autour du héros, pluie de flèches,
## météore, consécration... Frappe `ticks` fois, toutes les `interval` secondes, après `delay`.
## Se dessine elle-même (cercle coloré) en attendant de vrais effets en pixel art.

var radius := 16.0
var color := Color.WHITE
var delay := 0.0
var ticks := 1
var interval := 0.0
## Si défini, la zone suit ce nœud (consécration autour du héros).
var follow: Node2D

var _time := 0.0
var _next_tick := 0.0
var _done := 0
var _flash := 0.0
var _active_left := 0.0
var _since_last := 0.0


static func create(at: Vector2, radius_px: float, dmg: int, knock_tiles: float, col: Color, src: Node2D) -> SkillArea:
	var a := SkillArea.new()
	a.collision_layer = 0
	a.collision_mask = 16
	a.once_per_activation = true
	a.damage = dmg
	a.knockback_tiles = knock_tiles
	a.source = src
	a.position = at
	a.radius = radius_px
	a.color = col
	a.active = false
	a.z_index = 5
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius_px
	shape.shape = circle
	a.add_child(shape)
	return a


func _ready() -> void:
	super()
	_next_tick = delay


func _physics_process(delta: float) -> void:
	if follow and is_instance_valid(follow):
		global_position = follow.global_position + Vector2(0, -Game.TILE_SIZE * 0.5)
	_time += delta
	_since_last += delta
	_flash = maxf(_flash - delta * 4.0, 0.0)
	if _active_left > 0.0:
		_active_left -= delta
		if _active_left <= 0.0:
			active = false
	if _done < ticks and _time >= _next_tick:
		_done += 1
		_next_tick += interval
		active = true
		_active_left = 0.1
		_since_last = 0.0
		_flash = 1.0
	super(delta)
	queue_redraw()
	if _done >= ticks and _since_last >= 0.35:
		queue_free()


func _draw() -> void:
	# Pendant l'attente : un cercle qui annonce l'impact.
	if _done == 0:
		var p := clampf(_time / maxf(delay, 0.01), 0.0, 1.0)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(color, 0.5), 1.0)
		draw_circle(Vector2.ZERO, radius * p, Color(color, 0.15))
		return
	draw_circle(Vector2.ZERO, radius, Color(color, 0.12 + 0.35 * _flash))
	draw_arc(Vector2.ZERO, radius * (1.0 - 0.15 * _flash), 0.0, TAU, 32, Color(color, 0.4 + 0.6 * _flash), 1.5)
