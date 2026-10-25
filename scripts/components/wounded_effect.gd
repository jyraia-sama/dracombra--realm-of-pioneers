class_name WoundedEffect
extends Node2D
## Le héros est gravement blessé : il boite en se tenant le flanc, ne peut plus ni frapper
## ni rouler, et laisse une traînée de sang derrière lui.
## Sert aussi aux poses de cinématique (s'effondrer, allongé, assis au feu, se relever).
## À ajouter dans le niveau :
##     var wound := WoundedEffect.new()
##     add_child(wound)
##     wound.start(player)

const SHEET := preload("res://assets/sprites/hero/warrior_wounded.png")
const BLOOD_COLORS: Array[Color] = [Color(0.74, 0.08, 0.1), Color(0.56, 0.05, 0.08), Color(0.86, 0.16, 0.12)]
## Planche warrior_wounded.png (regard vers la droite) : [ligne, nombre d'images, durée d'une image].
const ANIMS := {
	&"limp": [0, 6, 0.14],
	&"collapse": [1, 5, 0.15],
	&"lying": [2, 4, 0.6],
	&"sit": [3, 4, 0.7],
	&"rise": [4, 5, 0.18],
}
const COLUMNS := 6

## Vitesse du héros blessé (part de sa vitesse normale).
@export var wounded_speed: float = 0.42
## Distance parcourue entre deux gouttes de sang, en pixels.
@export var blood_step: float = 7.0
## Nombre maximum de gouttes au sol.
@export var max_drops: int = 260

var player: Player
var active := false

var _sprite: Sprite2D
var _textures: Array[Texture2D] = []
var _drops: Array[Node2D] = []
var _last_feet := Vector2.INF
var _distance := 0.0
var _time := 0.0
## Pose de cinématique en cours (vide : marche ou attente normale).
var _pose: StringName = &""
var _pose_time := 0.0
var _pose_loop := false


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
	_attach_sprite()


func _attach_sprite() -> void:
	if _sprite != null:
		return
	_sprite = Sprite2D.new()
	_sprite.name = "WoundSprite"
	_sprite.texture = SHEET
	_sprite.centered = false
	_sprite.hframes = COLUMNS
	_sprite.vframes = 5
	_sprite.scale = Vector2(0.5, 0.5)  # dessin HD
	_sprite.offset = Vector2(-31, -54)
	player.visual.add_child(_sprite)
	player.sprite.visible = false


## Les blessures se sont refermées. La pose en cours (assis, allongé) reste affichée
## jusqu'à `release_pose()`.
func heal() -> void:
	active = false
	if not is_instance_valid(player):
		return
	player.speed_multiplier = 1.0
	player.actions_locked = false
	player.health.min_health = 0
	player.health.heal(player.health.max_health)
	if _sprite != null:
		_sprite.self_modulate = Color.WHITE
	if _pose == &"":
		_detach_sprite()


func _detach_sprite() -> void:
	if _sprite != null:
		_sprite.queue_free()
		_sprite = null
	if is_instance_valid(player):
		player.sprite.visible = true


## Joue une animation de cinématique. Une animation en boucle (allongé, assis) reste
## jusqu'à la suivante ; les autres restent sur leur dernière image.
func play(anim: StringName, loop: bool = false) -> void:
	_attach_sprite()
	_pose = anim
	_pose_time = 0.0
	_pose_loop = loop
	if not loop:
		var count: int = ANIMS[anim][1]
		await get_tree().create_timer(count * float(ANIMS[anim][2])).timeout


## Fige une image précise d'une animation (par exemple, à genoux).
func hold(anim: StringName, index: int) -> void:
	_attach_sprite()
	_pose = anim
	_pose_loop = false
	_pose_time = index * float(ANIMS[anim][2])


## Fin de la pose : retour à la marche (blessé) ou au sprite normal (guéri).
func release_pose() -> void:
	_pose = &""
	if not active:
		_detach_sprite()


func _process(delta: float) -> void:
	if not is_instance_valid(player) or _sprite == null:
		return
	_time += delta
	_pose_time += delta
	# La planche regarde à droite ; on garde le dernier sens horizontal.
	if absf(player.facing.x) > 0.1:
		_sprite.flip_h = player.facing.x < 0.0
	if _pose != &"":
		_sprite.frame = _frame(_pose, _pose_time, _pose_loop)
	elif player.velocity.length() > 1.0:
		_sprite.frame = _frame(&"limp", _time, true)
	else:
		# À l'arrêt : il reste plié, une main sur le flanc.
		_sprite.frame = _frame(&"limp", 0.0, false)
	if active:
		var pulse := 0.5 + 0.5 * sin(_time * 3.0)
		_sprite.self_modulate = Color(1.0, 0.9 - pulse * 0.08, 0.9 - pulse * 0.1)
		_bleed()


func _frame(anim: StringName, t: float, loop: bool) -> int:
	var row: int = ANIMS[anim][0]
	var count: int = ANIMS[anim][1]
	var i := int(t / float(ANIMS[anim][2]))
	i = i % count if loop else mini(i, count - 1)
	return row * COLUMNS + i


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
