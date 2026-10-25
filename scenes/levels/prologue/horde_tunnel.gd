extends Level
## Le couloir de la horde (prologue), entre la caverne et la tanière de Solakor.
## 1. Jouable : les monstres surgissent des fissures, de plus en plus nombreux.
## 2. Cinématique : débordé, le héros s'enfuit vers l'est, poursuivi par la horde.
## 3. Cinématique : un grondement venu de la tanière terrifie les monstres,
##    qui se figent, crient et rebroussent chemin. Le héros reprend la main.

enum Phase { HORDE, FLIGHT, SCARE, DONE }

const SLIME_SCENE := preload("res://scenes/enemies/slime/slime.tscn")
const GOBLIN_SCENE := preload("res://scenes/enemies/rock_goblin/rock_goblin.tscn")
const SPIDER_SCENE := preload("res://scenes/enemies/obsidian_spider/obsidian_spider.tscn")
const DUST_SCENE := preload("res://scenes/props/dust_puff.tscn")

## Le calque qui sert à placer les fissures (cases de sol).
@export var ground_layer: TileMapLayer
## Les fissures d'où surgissent les monstres.
@export var spawn_cells: Array[Vector2i] = []
## Le chemin que suit le héros pendant la fuite (centre du couloir).
@export var flight_path: PackedVector2Array = PackedVector2Array()

@export_group("Horde")
## Durée de la partie jouable, en secondes.
@export var horde_duration: float = 25.0
## Si le héros fonce vers l'est, la fuite commence dès cette abscisse (pixels).
@export var flee_trigger_x: float = 960.0
## Temps entre deux apparitions au début, puis à la fin de la partie jouable.
@export var spawn_interval_start: float = 2.2
@export var spawn_interval_end: float = 0.6
## Nombre maximum de monstres en même temps.
@export var max_alive: int = 14
## Part de gobelins parmi les apparitions (le reste : araignées et slimes).
@export_range(0.0, 1.0) var goblin_ratio: float = 0.25
## Part d'araignées d'obsidienne parmi les apparitions.
@export_range(0.0, 1.0) var spider_ratio: float = 0.25

@export_group("Peur")
## Abscisse (pixels) où le grondement de la tanière terrifie la horde.
@export var scare_x: float = 1400.0

var phase: Phase = Phase.HORDE

var _time: float = 0.0
var _spawn_timer: float = 1.0
var _path_index: int = 0
## Pendant la fuite : détection d'un héros bloqué (rocher, monstre...).
var _stuck_timer: float = 0.0
var _last_pos := Vector2.ZERO
var _flight_time: float = 0.0


func _ready() -> void:
	super()
	var player := get_player()
	# Le héros ne peut pas mourir ici : il doit fuir, pas tomber.
	player.health.min_health = 1
	_intro.call_deferred()


func _intro() -> void:
	await Narration.say("Le passage s'enfonçait dans la montagne. Des grattements montaient des parois...", 3.2)
	if phase == Phase.HORDE:
		Narration.say("Les créatures nées du mana sortaient de partout !", 2.5)


func _process(delta: float) -> void:
	super(delta)
	var player := get_player()
	if player == null:
		return
	match phase:
		Phase.HORDE:
			_time += delta
			_tick_spawns(delta, player, false)
			if _time >= horde_duration or player.global_position.x >= flee_trigger_x:
				_start_flight()
		Phase.FLIGHT:
			_flight_time += delta
			_unstick(player, delta)
			_steer(player)
			_tick_spawns(delta, player, true)
			if player.global_position.x >= scare_x:
				_scare()


# ------------------------------------------------------------------ la horde

func _tick_spawns(delta: float, player: Player, ahead_only: bool) -> void:
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	var t := clampf(_time / horde_duration, 0.0, 1.0)
	_spawn_timer = lerpf(spawn_interval_start, spawn_interval_end, t) * (0.6 if ahead_only else 1.0)
	if get_tree().get_nodes_in_group("enemies").size() >= max_alive:
		return
	var cell := _pick_spawn_cell(player.global_position, ahead_only)
	if cell != Vector2i(-1, -1):
		_spawn_monster(cell)


## Une fissure proche du héros, mais pas collée à lui.
func _pick_spawn_cell(from: Vector2, ahead_only: bool) -> Vector2i:
	var tile := float(Game.TILE_SIZE)
	var candidates: Array[Vector2i] = []
	for cell in spawn_cells:
		var pos := cell_to_world(ground_layer, cell)
		var dist := pos.distance_to(from)
		if dist < tile * 3.0 or dist > tile * 10.0:
			continue
		if ahead_only and pos.x < from.x + tile * 2.0:
			continue
		candidates.append(cell)
	if candidates.is_empty():
		return Vector2i(-1, -1)
	return candidates.pick_random()


func _spawn_monster(cell: Vector2i) -> void:
	var roll := randf()
	var scene := SLIME_SCENE
	if roll < goblin_ratio:
		scene = GOBLIN_SCENE
	elif roll < goblin_ratio + spider_ratio:
		scene = SPIDER_SCENE
	var monster: CharacterBody2D = scene.instantiate()
	monster.position = cell_to_world(ground_layer, cell) + Vector2(0.0, Game.TILE_SIZE / 2.0)
	# Ils sortent enragés : ils repèrent le héros de loin.
	monster.set("detection_radius_tiles", 30.0)
	monster.set("lose_interest_radius_tiles", 40.0)
	if phase == Phase.FLIGHT:
		monster.set("move_speed_tiles", monster.get("move_speed_tiles") * 1.6)
	add_child(monster)
	var dust: Node2D = DUST_SCENE.instantiate()
	dust.position = monster.position
	add_child(dust)
	# Il émerge de la fissure.
	var visual := monster.get_node("Visual") as Node2D
	visual.modulate.a = 0.0
	visual.scale = Vector2(1.0, 0.2)
	var tween := monster.create_tween().set_parallel()
	tween.tween_property(visual, "modulate:a", 1.0, 0.3)
	tween.tween_property(visual, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ------------------------------------------------------------------ la fuite

func _start_flight() -> void:
	phase = Phase.FLIGHT
	var player := get_player()
	player.input_locked = true
	player.scripted_direction = Vector2.ZERO
	# Plus rien ne peut l'arrêter : il traverse la horde.
	player.health.set_invulnerable(999.0)
	player.collision_mask = 1
	# La horde s'emballe.
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.set("move_speed_tiles", enemy.get("move_speed_tiles") * 1.6)
	# Premier point du chemin devant le héros.
	_path_index = 0
	while _path_index < flight_path.size() - 1 and flight_path[_path_index].x <= player.global_position.x:
		_path_index += 1
	_last_pos = player.global_position
	_stuck_timer = 0.0
	_flight_time = 0.0
	Narration.cinematic(true)
	Narration.say("Ils étaient trop nombreux. Épuisé, le héros n'avait plus qu'une issue : fuir !", 3.0)


## Si le héros n'avance plus (coincé contre un rocher), il passe à travers le temps de
## rejoindre le point suivant du chemin. En dernier recours, la suite se déclenche.
func _unstick(player: Player, delta: float) -> void:
	if player.global_position.distance_to(_last_pos) > 1.5:
		_last_pos = player.global_position
		_stuck_timer = 0.0
		return
	_stuck_timer += delta
	if _stuck_timer > 0.35:
		player.collision_mask = 0
	if _flight_time > 15.0 and phase == Phase.FLIGHT:
		# Toujours bloqué : on le pose sur le chemin, juste après le point du grondement.
		var spot := flight_path[flight_path.size() - 1] if not flight_path.is_empty() else player.global_position
		for p in flight_path:
			if p.x >= scare_x:
				spot = p
				break
		player.global_position = Vector2(maxf(spot.x, scare_x + 1.0), spot.y)


func _steer(player: Player) -> void:
	if _path_index >= flight_path.size():
		player.scripted_direction = Vector2.RIGHT
		return
	var target := flight_path[_path_index]
	if player.global_position.distance_to(target) < 6.0:
		_path_index += 1
		# Point atteint : il est de nouveau dans le couloir, les collisions reviennent.
		player.collision_mask = 1
		return
	player.scripted_direction = player.global_position.direction_to(target)


# ------------------------------------------------------------------ la peur

func _scare() -> void:
	phase = Phase.SCARE
	var player := get_player()
	player.scripted_direction = Vector2.ZERO
	player.collision_mask = 1

	# Le grondement de la tanière.
	shake_camera(6.0, 1.8)
	var darkness := get_node_or_null("Darkness") as CanvasModulate
	if darkness:
		var base := darkness.color
		var tween := create_tween()
		tween.tween_property(darkness, "color", Color(0.45, 0.12, 0.1), 0.25)
		tween.tween_property(darkness, "color", base, 1.2)
	Narration.say("Un grondement sourd fit trembler toute la montagne.", 2.6)
	await get_tree().create_timer(0.5).timeout

	# La horde se fige, crie de terreur, et rebrousse chemin.
	var lair_side := player.global_position + Vector2(Game.TILE_SIZE * 20.0, 0.0)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var fear := enemy.get_node_or_null("Fear") as Fear
		if fear != null:
			fear.scare(lair_side)
	await get_tree().create_timer(1.0).timeout
	player.face(Vector2.LEFT)
	await Narration.say("Les créatures se figèrent... puis s'enfuirent en hurlant de terreur.", 3.0)
	player.face(Vector2.RIGHT)
	await Narration.say("Quoi qui se cache plus loin, même les monstres de la caverne le craignaient.", 3.2)

	# Le héros reprend la main.
	await Narration.cinematic(false)
	player.health.clear_invulnerable()
	player.collision_mask = 5
	player.input_locked = false
	phase = Phase.DONE
	Game.set_flag(&"prologue_horde_done")
