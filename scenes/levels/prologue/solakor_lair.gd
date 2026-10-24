extends Level
## La tanière de Solakor (prologue).
## 1. Le dragon dort. 2. Il se réveille quand le héros approche.
## 3. Le héros survit à ses attaques. 4. La griffe incandescente le blesse.
## 5. Les rochers fendent la paroi : une crevasse s'ouvre, il faut fuir.

enum Phase { SLEEPING, FIGHT, CLIMAX, ESCAPE }

const FALLING_ROCK := preload("res://scenes/props/falling_rock.tscn")

@export var dragon: Solakor
## Le calque qui contient les éboulis bouchant la crevasse.
@export var decor_layer: TileMapLayer
## Les cases d'éboulis qui bouchent la crevasse.
@export var crevasse_cells: Array[Vector2i] = []
## La sortie au bout de la crevasse.
@export var crevasse_exit: LevelExit
## La lueur qui révèle la crevasse.
@export var crevasse_light: PointLight2D
## Distance au dragon (en tiles) qui le réveille.
@export var wake_distance_tiles: float = 7.0
## Durée du combat avant la griffe incandescente, en secondes.
@export var fight_duration: float = 20.0
## Vitesse du héros blessé pendant la fuite (1 = normale).
@export var wounded_speed: float = 0.55

var phase: Phase = Phase.SLEEPING

var _fight_time: float = 0.0
var _told_no_effect := false


func _ready() -> void:
	super()
	var player := get_player()
	# Le héros ne peut pas mourir ici : c'est une scène d'histoire.
	player.health.min_health = 1
	crevasse_exit.enabled = false
	crevasse_light.energy = 0.0
	dragon.hit_by_player.connect(_on_dragon_hit)
	_intro.call_deferred()


func _intro() -> void:
	await Narration.say("Puis, il atteignit la salle centrale.", 2.6)
	# Si le dragon s'est déjà réveillé, on n'empiète pas sur son entrée en scène.
	if phase == Phase.SLEEPING:
		Narration.say("Une masse sombre y dormait. Son simple souffle faisait vibrer les murs.", 3.5)


func _process(delta: float) -> void:
	super(delta)
	var player := get_player()
	if player == null:
		return
	match phase:
		Phase.SLEEPING:
			var reach: float = wake_distance_tiles * Game.TILE_SIZE
			if player.global_position.distance_to(dragon.global_position) < reach:
				_wake()
		Phase.FIGHT:
			_fight_time += delta
			if _fight_time >= fight_duration:
				_climax()


func _wake() -> void:
	phase = Phase.FIGHT
	var player := get_player()
	player.input_locked = true
	player.scripted_direction = Vector2.ZERO
	Narration.hide_all()
	dragon.wake()
	await get_tree().create_timer(0.8).timeout
	await Narration.title_card("SOLAKOR", "Dragon millénaire, gardien des Telles-Ombrages", 2.2)
	player.input_locked = false
	Narration.say("Le combat était perdu d'avance : trop puissant, trop vaste. Survivez !", 3.5)
	dragon.start_attacks()


func _on_dragon_hit() -> void:
	if not _told_no_effect:
		_told_no_effect = true
		Narration.say("Vos coups n'entament même pas ses écailles.", 2.5)


func _climax() -> void:
	phase = Phase.CLIMAX
	var player := get_player()
	dragon.stop_attacks()
	# Laisse les attaques en cours se terminer.
	await get_tree().create_timer(1.2).timeout
	player.input_locked = true
	player.scripted_direction = Vector2.ZERO
	player.face(dragon.global_position - player.global_position)
	Narration.say("Solakor leva une griffe incandescente...", 2.0)
	await get_tree().create_timer(0.6).timeout

	# La griffe incandescente : impossible à esquiver. Elle projette le héros
	# (recul normal, avec les collisions), puis le laisse à 1 PV.
	dragon.claw_hitbox.damage = 0
	player.health.clear_invulnerable()
	await dragon.claw_attack(player.global_position, Color(1.0, 0.55, 0.1, 0.4), false)
	player.health.set_health(1)
	player.health.set_invulnerable(1.5)
	shake_camera(7.0, 0.8)
	await Narration.say("Blessé grièvement, le héros fut projeté contre la roche.", 3.0)

	# La fureur du dragon fend la paroi : la crevasse s'ouvre.
	dragon.claw_hitbox.damage = dragon.claw_damage
	for cell in crevasse_cells:
		_smash_rubble(cell)
		await get_tree().create_timer(0.15).timeout
	await get_tree().create_timer(1.2).timeout
	create_tween().tween_property(crevasse_light, "energy", 1.2, 1.0)
	await Narration.say("Une crevasse ! La roche s'était fendue. C'était la seule issue.", 3.0)

	phase = Phase.ESCAPE
	player.speed_multiplier = wounded_speed
	player.input_locked = false
	crevasse_exit.enabled = true
	dragon.escape_mode = true
	dragon.start_attacks()
	Narration.say("Rampez jusqu'à la crevasse !", 3.0)


func _smash_rubble(cell: Vector2i) -> void:
	var rock: FallingRock = FALLING_ROCK.instantiate()
	rock.damage = 0
	rock.shake_strength = 4.0
	rock.fall_time = 0.7
	rock.position = cell_to_world(decor_layer, cell) + Vector2(0.0, Game.TILE_SIZE / 2.0)
	add_child(rock)
	rock.landed.connect(decor_layer.erase_cell.bind(cell), CONNECT_ONE_SHOT)
