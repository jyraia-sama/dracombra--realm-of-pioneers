extends Level
## La Sylve des Dracombres : la grande zone sauvage au sortir de la montagne.
## Bois, pierre, herbes, lin, pierres précieuses, sangliers... et la porte de Dracombra.
##
## Fin du prologue : le héros, blessé, sort de la grotte au soir tombant et se traîne
## jusqu'aux ruines. Il s'effondre au pied d'un grand chêne, devant la porte de Dracombra.
## Fondu au noir : il se réveillera quelques jours plus tard, à l'intérieur (dracombra.gd).

enum Phase { ARRIVAL, COLLAPSE, FREE }

const EVENING := Color(1.0, 0.78, 0.64)
const DAY := Color(1.0, 0.98, 0.94)
const DRACOMBRA := "res://scenes/levels/dracombra/dracombra.tscn"

## Là où il s'effondre (au pied du grand chêne, près des ruines).
@export var rest_point: Vector2 = Vector2.ZERO
## Le cœur des ruines, devant la porte de Dracombra.
@export var ruins_point: Vector2 = Vector2.ZERO
## Distance au point de repos qui déclenche l'effondrement, en tiles.
@export var collapse_radius_tiles: float = 2.5

var phase: Phase = Phase.ARRIVAL
var wound: WoundedEffect

@onready var daylight: CanvasModulate = $Daylight


func _ready() -> void:
	super()
	# Sol aux bords organiques (plus d'effet de grille).
	GroundPainter.apply(self, $Ground, &"sylve")
	var gate := get_node_or_null("ExitToDracombra") as LevelExit
	if Game.has_flag(&"prologue_done"):
		_start_free_play()
		return
	# Pendant l'arrivée, la porte reste fermée : il s'effondre avant.
	if gate:
		gate.enabled = false
	daylight.color = EVENING
	# Pendant l'arrivée, le héros est à bout de forces : pas de combat possible.
	# Les bêtes de la Sylve ne sortiront qu'une fois le prologue terminé.
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	wound = WoundedEffect.new()
	wound.name = "Wound"
	add_child(wound)
	wound.start(get_player())
	_arrival.call_deferred()


func _arrival() -> void:
	var player := get_player()
	player.input_locked = true
	player.face(Vector2.DOWN)
	await Narration.say("La lumière du soir l'aveugla. Il était de l'autre côté de la montagne.", 3.0)
	if phase != Phase.ARRIVAL:
		return
	await Narration.title_card("SYLVE DES DRACOMBRES", "Aethelgard")
	player.input_locked = false
	if phase == Phase.ARRIVAL:
		Narration.say("Il lui fallait un abri... Là-bas, en contrebas : des pierres taillées ?", 3.6)


func _process(delta: float) -> void:
	super(delta)
	if phase != Phase.ARRIVAL:
		return
	var player := get_player()
	if player != null and rest_point != Vector2.ZERO \
			and player.global_position.distance_to(rest_point) < collapse_radius_tiles * Game.TILE_SIZE:
		_collapse()


func _collapse() -> void:
	phase = Phase.COLLAPSE
	var player := get_player()
	player.input_locked = true
	player.scripted_direction = Vector2.ZERO
	Narration.hide_all()
	await wound.play(&"collapse")
	wound.play(&"lying", true)
	Level.shake(self, 2.0, 0.2)
	for i in 4:
		wound.drop_blood(player.global_position + Vector2(randf_range(-6.0, 10.0), randf_range(-3.0, 2.0)), true)
	await Narration.say("Ses jambes cédèrent. Il s'effondra au pied du grand chêne, devant une arche de pierre.", 3.2)
	await Transition.fade_out(1.6)
	await Transition.story_text("Des pas dans l'herbe. Une silhouette encapuchonnée se pencha sur lui.", 3.0)
	await Transition.story_text("« Encore vivant... Tiens bon, étranger. »", 2.4)
	await Transition.story_text("On le traîna à travers l'arche. Puis vinrent la fièvre, l'odeur des herbes, et le sommeil.", 3.4)
	await Transition.story_text("Quelques jours plus tard...", 2.2)
	# Le réveil se joue à l'intérieur de Dracombra (l'écran reste noir pendant le chargement).
	Game.set_flag(&"wake_in_dracombra")
	Game.next_spawn = &"camp"
	get_tree().change_scene_to_file(DRACOMBRA)


func _start_free_play() -> void:
	phase = Phase.FREE
	daylight.color = DAY
	var player := get_player()
	player.input_locked = false
	player.actions_locked = false
	player.speed_multiplier = 1.0
