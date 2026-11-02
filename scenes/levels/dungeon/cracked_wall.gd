class_name CrackedWall
extends StaticBody2D
## Pan de mur fissuré qui cache une salle secrète (cryptes). Il bouche un passage comme une
## grille ; quelques coups d'arme le font s'écrouler. Un filet de poussière tombe de ses
## fissures de temps en temps : c'est l'indice.

signal broken

const TEX := preload("res://assets/sprites/props/crypt/cracked_wall.png")
const HITS := 4

var cells: Array[Vector2i] = []
var _hits := 0
var _dust_t := 1.0
var _sprites: Array[Sprite2D] = []


## door_cells : cases du passage (DungeonGen.door_cells) ; cell_pos : position monde d'une case.
func setup(door_cells: Array[Vector2i], cell_pos: Callable) -> void:
	cells = door_cells
	collision_layer = 1
	collision_mask = 0
	var t := float(Game.TILE_SIZE)
	var first: Vector2 = cell_pos.call(cells[0])
	var last: Vector2 = cell_pos.call(cells[cells.size() - 1])
	position = (first + last) / 2.0 + Vector2(0, t / 2.0)
	var size := (last - first).abs() + Vector2(t, t)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = Vector2(0, -size.y / 2.0)
	add_child(shape)
	# Une image de mur par case (32 px de haut affichés pour 16 de large : il dépasse en hauteur).
	for c in cells:
		var s := Sprite2D.new()
		s.texture = TEX
		s.scale = Vector2(0.25, 0.5)
		s.centered = false
		s.offset = Vector2(-TEX.get_width() / 2.0, -TEX.get_height())
		s.position = cell_pos.call(c) - position + Vector2(0, t / 2.0)
		add_child(s)
		_sprites.append(s)
	var health := HealthComponent.new()
	health.name = "Health"
	health.max_health = 9999
	health.invulnerability_duration = 0.15
	add_child(health)
	var hurtbox := Hurtbox.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = 16
	hurtbox.collision_mask = 0
	hurtbox.health = health
	var hs := CollisionShape2D.new()
	var hr := RectangleShape2D.new()
	hr.size = size + Vector2(8, 8)
	hs.shape = hr
	hs.position = Vector2(0, -size.y / 2.0)
	hurtbox.add_child(hs)
	add_child(hurtbox)
	hurtbox.hit_received.connect(_on_hit)


func _process(delta: float) -> void:
	_dust_t -= delta
	if _dust_t <= 0.0 and is_inside_tree():
		_dust_t = randf_range(1.5, 3.0)
		PixelBurst.spawn(get_parent(), global_position + Vector2(randf_range(-16, 16), -26), PixelBurst.DUST, Vector2.ZERO, 0.4)


func _on_hit(_h: Hitbox) -> void:
	_hits += 1
	Fx.shake(1.0, 0.1)
	for s in _sprites:
		s.position.x += randf_range(-1.0, 1.0)
	PixelBurst.spawn(get_parent(), global_position + Vector2(0, -14), PixelBurst.STONE, Vector2.ZERO, 1.0)
	if _hits >= HITS:
		_break.call_deferred()


func _break() -> void:
	PixelBurst.spawn(get_parent(), global_position + Vector2(0, -12), PixelBurst.STONE, Vector2.ZERO, 3.0)
	PixelBurst.spawn(get_parent(), global_position, PixelBurst.DUST, Vector2.ZERO, 4.0)
	Fx.shake(3.0, 0.3)
	broken.emit()
	queue_free()
