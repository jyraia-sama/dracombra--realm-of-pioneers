extends Level
## La Sylve des Dracombres : la grande zone ouverte au sortir de la montagne.
## Fin du prologue : le héros, blessé, sort de la grotte au soir tombant et se traîne
## jusqu'aux ruines. Il s'effondre au pied d'un grand chêne. Fondu au noir.
## Quelques jours plus tard, il se réveille près d'un feu : l'histoire principale commence.

enum Phase { ARRIVAL, COLLAPSE, FREE }

const EVENING := Color(1.0, 0.78, 0.64)
const MORNING := Color(1.0, 0.98, 0.94)

## Là où il s'effondre (au pied du grand chêne, près des ruines).
@export var rest_point: Vector2 = Vector2.ZERO
## Le cœur des ruines de Dracombra.
@export var ruins_point: Vector2 = Vector2.ZERO
## Distance au point de repos qui déclenche l'effondrement, en tiles.
@export var collapse_radius_tiles: float = 2.5
## Le feu de camp et la couche, qui n'apparaissent qu'au réveil.
@export var campfire: Node2D
@export var bedroll: Node2D

var phase: Phase = Phase.ARRIVAL
var wound: WoundedEffect

@onready var daylight: CanvasModulate = $Daylight


func _ready() -> void:
	super()
	if Game.has_flag(&"prologue_done"):
		_start_free_play()
		return
	daylight.color = EVENING
	_set_camp_visible(false)
	wound = WoundedEffect.new()
	wound.name = "Wound"
	add_child(wound)
	wound.start(get_player())
	_arrival.call_deferred()


func _set_camp_visible(on: bool) -> void:
	for node in [campfire, bedroll]:
		if node != null:
			node.visible = on
			var light := node.get_node_or_null("Light") as PointLight2D
			if light:
				light.enabled = on


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


# ------------------------------------------------------------------ l'effondrement

func _collapse() -> void:
	phase = Phase.COLLAPSE
	var player := get_player()
	player.input_locked = true
	player.scripted_direction = Vector2.ZERO
	Narration.hide_all()
	# Il tombe sur le côté.
	var fall := create_tween().set_parallel()
	fall.tween_property(player.visual, "rotation", PI * 0.5, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_property(player.visual, "position", Vector2(8, -2), 0.5)
	await fall.finished
	Level.shake(self, 2.0, 0.2)
	for i in 4:
		wound.drop_blood(player.global_position + Vector2(randf_range(-6.0, 10.0), randf_range(-3.0, 2.0)), true)
	await Narration.say("Ses jambes cédèrent. Il s'effondra au pied du grand chêne, près des ruines.", 3.2)
	await Transition.fade_out(1.6)
	await Transition.story_text("Il resta là plusieurs jours, entre fièvre et sommeil.", 2.6)
	await Transition.story_text("Les vieilles pierres l'abritaient du vent. La rivière, toute proche, étanchait sa soif.", 3.2)
	await Transition.story_text("Quelques jours plus tard...", 2.2)
	_wake_up()


func _wake_up() -> void:
	var player := get_player()
	wound.heal()
	# La pluie a lavé le sang.
	wound.queue_free()
	_set_camp_visible(true)
	daylight.color = MORNING
	if bedroll != null:
		player.global_position = bedroll.global_position + Vector2(0, 14)
	player.face(Vector2.DOWN)
	await Transition.fade_in(1.6)
	await Narration.say("Ses blessures s'étaient refermées. Il était vivant.", 2.8)
	player.face(Vector2.RIGHT if ruins_point.x >= player.global_position.x else Vector2.LEFT)
	await Narration.say("Autour de lui, des dragons sculptés dans la pierre... Se pourrait-il que ce soit... Dracombra ?", 3.8)
	await Narration.title_card("DRACOMBRA", "Chapitre 1 — Les Pionniers", 3.0)
	Game.set_flag(&"prologue_done")
	_start_free_play()
	Narration.say("Explorez la Sylve des Dracombres.", 3.5)


func _start_free_play() -> void:
	phase = Phase.FREE
	daylight.color = MORNING
	_set_camp_visible(true)
	var player := get_player()
	player.input_locked = false
	player.actions_locked = false
	player.speed_multiplier = 1.0
