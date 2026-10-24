extends Level
## Le passage après la crevasse : gravement blessé par Solakor, le héros se traîne
## vers la sortie en laissant une traînée de sang. Il ne peut plus ni frapper ni rouler.
## À mi-chemin, il doit s'arrêter pour reprendre son souffle.
## Au bout : la lumière du jour, et la Sylve des Dracombres.

## Où le héros s'arrête pour souffler (pied du héros).
@export var rest_point: Vector2 = Vector2.ZERO
## Abscisses (pixels) entre lesquelles l'obscurité s'éclaircit vers la sortie.
@export var light_from_x: float = 0.0
@export var light_to_x: float = 0.0
## La lumière du jour à la sortie.
@export var daylight: PointLight2D

var wound: WoundedEffect

var _rested := false
var _saw_light := false
var _darkness: CanvasModulate
var _dark_color: Color


func _ready() -> void:
	super()
	_darkness = get_node_or_null("Darkness") as CanvasModulate
	if _darkness:
		_dark_color = _darkness.color
	wound = WoundedEffect.new()
	wound.name = "Wound"
	add_child(wound)
	wound.start(get_player())
	_intro.call_deferred()


func _intro() -> void:
	var player := get_player()
	player.input_locked = true
	player.face(Vector2.RIGHT)
	await Narration.say("Il glissa dans la crevasse et roula jusqu'au fond d'un étroit boyau.", 3.0)
	player.input_locked = false
	if not _rested:
		Narration.say("Chaque pas lui arrachait un gémissement. Sa blessure saignait abondamment.", 3.4)


func _process(delta: float) -> void:
	super(delta)
	var player := get_player()
	if player == null:
		return
	_update_light(player)
	if not _rested and rest_point != Vector2.ZERO and player.global_position.distance_to(rest_point) < 24.0:
		_rest()
	if not _saw_light and player.global_position.x > lerpf(light_from_x, light_to_x, 0.55):
		_saw_light = true
		Narration.say("De l'air frais... une lueur, au bout du passage. Une sortie !", 3.2)


## À bout de forces, il s'affaisse contre la paroi, puis repart.
func _rest() -> void:
	_rested = true
	var player := get_player()
	player.input_locked = true
	player.scripted_direction = Vector2.ZERO
	# Il tombe à genoux, une main au sol.
	wound.hold(&"collapse", 0)
	for i in 3:
		wound.drop_blood(player.global_position + Vector2(randf_range(-5.0, 5.0), randf_range(-2.0, 2.0)), true)
	await Narration.say("À bout de forces, il dut s'adosser à la paroi pour reprendre son souffle...", 3.4)
	await Narration.say("« Pas ici... Je ne mourrai pas ici. »", 2.4)
	await wound.play(&"rise")
	wound.release_pose()
	player.input_locked = false


## L'obscurité se dissipe à l'approche de la sortie.
func _update_light(player: Player) -> void:
	if light_to_x <= light_from_x:
		return
	var t := clampf((player.global_position.x - light_from_x) / (light_to_x - light_from_x), 0.0, 1.0)
	t = t * t
	if _darkness:
		_darkness.color = _dark_color.lerp(Color(0.8, 0.76, 0.7), t)
	if daylight:
		daylight.energy = lerpf(0.4, 1.6, t)
