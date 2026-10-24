class_name WoundedEffect
extends Node2D
## Le héros est gravement blessé : il boite, pâlit, ne peut plus ni frapper ni rouler,
## et laisse une traînée de sang derrière lui.
## À ajouter dans le niveau :
##     var wound := WoundedEffect.new()
##     add_child(wound)
##     wound.start(player)

const BLOOD_COLORS: Array[Color] = [Color(0.74, 0.08, 0.1), Color(0.56, 0.05, 0.08), Color(0.86, 0.16, 0.12)]

## Vitesse du héros blessé (part de sa vitesse normale).
@export var wounded_speed: float = 0.42
## Distance parcourue entre deux gouttes de sang, en pixels.
@export var blood_step: float = 7.0
## Nombre maximum de gouttes au sol.
@export var max_drops: int = 260

var player: Player
var active := false

var _textures: Array[Texture2D] = []
var _drops: Array[Node2D] = []
var _last_feet := Vector2.INF
var _distance := 0.0
var _time := 0.0


func _ready() -> void:
	# Les gouttes sont posées à plat sur le sol, sous les personnages.
	z_index = -1
	_make_textures()


func start(target: Player) -> void:
	player = target
	active = true
	player.speed_multiplier = wounded_speed
	player.actions_locked = true
	player.health.min_health = 1
	player.health.set_health(1)


## Les blessures se sont refermées.
func heal() -> void:
	active = false
	if not is_instance_valid(player):
		return
	player.speed_multiplier = 1.0
	player.actions_locked = false
	player.health.min_health = 0
	player.health.heal(player.health.max_health)
	player.visual.position = Vector2.ZERO
	player.visual.rotation = 0.0
	player.visual.scale = Vector2.ONE
	player.sprite.self_modulate = Color.WHITE


func _process(delta: float) -> void:
	if not active or not is_instance_valid(player):
		return
	_time += delta
	_limp()
	_bleed()


## Il boite : son corps penche et sautille quand il avance. Il pâlit.
func _limp() -> void:
	var moving := player.velocity.length() > 1.0
	var target := Vector2.ZERO
	var tilt := 0.0
	if moving:
		var phase := _time * 7.0
		target.y = absf(sin(phase)) * 1.5
		tilt = sin(phase) * 0.06
	player.visual.position = player.visual.position.lerp(target, 0.4).round()
	player.visual.rotation = lerpf(player.visual.rotation, tilt, 0.3)
	var pulse := 0.5 + 0.5 * sin(_time * 3.0)
	player.sprite.self_modulate = Color(1.0, 0.86 - pulse * 0.08, 0.86 - pulse * 0.1)


func _bleed() -> void:
	var feet := player.global_position
	if _last_feet == Vector2.INF:
		_last_feet = feet
		return
	_distance += feet.distance_to(_last_feet)
	_last_feet = feet
	if _distance < blood_step:
		return
	_distance = 0.0
	drop_blood(feet + Vector2(randf_range(-3.0, 3.0), randf_range(-2.0, 1.0)), randf() < 0.15)


## Une goutte (ou une petite flaque si `big`) à cet endroit du monde.
func drop_blood(at: Vector2, big: bool) -> void:
	var drop := Sprite2D.new()
	drop.texture = _textures[randi_range(3, 5) if big else randi_range(0, 2)]
	drop.global_position = at.round()
	drop.rotation = [0.0, PI * 0.5, PI, PI * 1.5][randi() % 4]
	drop.scale = Vector2.ZERO
	add_child(drop)
	drop.global_position = at.round()
	_drops.append(drop)
	var tween := drop.create_tween()
	tween.tween_property(drop, "scale", Vector2.ONE, 0.12)
	if _drops.size() > max_drops:
		_drops.pop_front().queue_free()


func drop_count() -> int:
	return _drops.size()


## Petites taches de sang dessinées à la volée (gouttes, puis flaques).
func _make_textures() -> void:
	var shapes := [
		["X"],
		["XX", "X."],
		[".X.", "XXX"],
		[".XX.", "XXXX", ".XX."],
		["XXX..", "XXXXX", ".XXX."],
		[".XX..", "XXXX.", "XXXXX", "..XX."],
	]
	for shape in shapes:
		var h: int = shape.size()
		var w: int = (shape[0] as String).length()
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for y in h:
			for x in w:
				if (shape[y] as String)[x] == "X":
					img.set_pixel(x, y, BLOOD_COLORS[(x + y * 2) % BLOOD_COLORS.size()])
		_textures.append(ImageTexture.create_from_image(img))
