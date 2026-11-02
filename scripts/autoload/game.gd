extends Node
## Constantes, état global de la partie et passage des jours.
## Accessible partout avec Game.TILE_SIZE, Game.day, Game.sleep()...

## Taille d'une tile en pixels. Passera à 32 lors du remaster.
## Toutes les distances, vitesses et portées doivent en dépendre.
const TILE_SIZE: int = 16

## PV maximum du héros pendant le prologue : un capitaine aguerri.
const HERO_PROLOGUE_HEALTH: int = 200
## PV maximum après le prologue : la blessure de Solakor l'a durablement affaibli.
const HERO_BASE_HEALTH: int = 100

signal day_changed(day: int)

## Drapeaux de progression de l'histoire (intro vue, boss vaincu...).
## Conservés pendant toute la partie, même quand une salle est rechargée.
var flags: Dictionary[StringName, bool] = {}
## Jour de jeu (le premier jour est celui du réveil à Dracombra).
var day: int = 1
## Heure de la journée, en minutes (0 = minuit, 480 = 8 h). Une minute de jeu = une seconde réelle.
var time_minutes: float = 480.0
## Ressources récoltées : { "niveau:chemin du décor" : jour de la récolte }.
var harvested: Dictionary = {}
## Point d'arrivée dans le prochain niveau (nom d'un Marker2D sous « Spawns »).
var next_spawn: StringName = &""
## Position où replacer le héros au chargement d'une sauvegarde.
var pending_position: Variant = null
## Étage du donjon en cours (0 = hors du donjon). Pas sauvegardé : le donjon change à chaque entrée.
var dungeon_floor: int = 0
## Passage en cours dans le donjon : {"start": {objet: quantité}} au moment d'y entrer
## (pour la règle des 25 % à la mort). Vide hors du donjon.
var dungeon_run: Dictionary = {}
## Message à afficher à l'arrivée dans le prochain niveau (ex. pertes à la mort).
var pending_message: String = ""
## Nombre de fois où la reine araignée a été vaincue (le donjon durcit un peu à chaque fois).
var abyss_clears: int = 0

var _sleeping := false
## Le joueur utilise-t-il la manette (dernière touche pressée) ? Les aides affichent ses boutons.
var using_pad := false
signal input_device_changed(pad: bool)


# ------------------------------------------------------------------ jour et nuit
# Une journée dure 24 minutes réelles. Le jour change à l'aube (6 h) : en dormant (on se
# réveille à 7 h le lendemain) ou en restant debout toute la nuit. Les niveaux qui ont un
# CanvasModulate « Daylight » (Dracombra, Sylve) suivent la couleur du ciel.

const DAWN := 360.0
const WAKE := 420.0
## Couleur du ciel selon l'heure : [heure, couleur].
const SKY := [[0.0, Color(0.32, 0.36, 0.6)], [5.0, Color(0.32, 0.36, 0.6)], [6.5, Color(1.0, 0.8, 0.72)],
	[8.0, Color(1.0, 0.98, 0.94)], [17.5, Color(1.0, 0.98, 0.94)], [19.0, Color(1.0, 0.78, 0.6)],
	[20.5, Color(0.48, 0.47, 0.72)], [22.0, Color(0.32, 0.36, 0.6)], [24.0, Color(0.32, 0.36, 0.6)]]

signal new_morning(day: int)


func clock_text() -> String:
	var m := int(time_minutes)
	return "%02d:%02d" % [m / 60, m % 60]


func is_night() -> bool:
	return time_minutes >= 20.5 * 60.0 or time_minutes < 6.0 * 60.0


static func sky_color(minutes: float) -> Color:
	var h := minutes / 60.0
	for i in range(1, SKY.size()):
		if h <= SKY[i][0]:
			var a: Array = SKY[i - 1]
			var b: Array = SKY[i]
			return (a[1] as Color).lerp(b[1], (h - a[0]) / maxf(0.001, b[0] - a[0]))
	return SKY[0][1]


func _process(delta: float) -> void:
	if not has_flag(&"prologue_done") or get_tree().paused or _sleeping or Transition.is_busy:
		return
	var scene := get_tree().current_scene
	if scene == null or not (scene is Level):
		return
	var before := time_minutes
	time_minutes += delta
	if time_minutes >= 1440.0:
		time_minutes -= 1440.0
	# L'aube passe sans avoir dormi : nouveau jour quand même.
	if before < DAWN and time_minutes >= DAWN:
		_new_day(false)
	_apply_sky(scene)


func _apply_sky(scene: Node) -> void:
	var sky := scene.get_node_or_null("Daylight") as CanvasModulate
	if sky == null:
		return
	sky.color = sky_color(time_minutes)
	var player := scene.get_node_or_null("Player") as Node2D
	if player:
		var light := player.get_node_or_null("HeroLight") as PointLight2D
		if light == null:
			light = PointLight2D.new()
			light.name = "HeroLight"
			light.position = Vector2(0, -16)
			light.color = Color(1, 0.86, 0.7)
			light.texture = preload("res://assets/lights/light_radial.tres")
			light.texture_scale = 2.0
			player.add_child(light)
		light.enabled = is_night() or time_minutes > 19.5 * 60.0


## Un nouveau jour commence (à l'aube) : chantiers, arrivées à la guilde…
func _new_day(slept: bool) -> Array[String]:
	day += 1
	var messages := Town.advance_day()
	day_changed.emit(day)
	new_morning.emit(day)
	if not slept:
		Narration.say("L'aube se lève. Jour %d." % day, 3.0)
		for t in messages:
			Narration.say(t, 3.0)
	return messages


func _ready() -> void:
	# Godot ne relie pas la manette aux actions d'interface par défaut :
	# bouton A = valider, bouton B = retour (menus, fenêtres de choix).
	_add_joy(&"ui_accept", JOY_BUTTON_A)
	_add_joy(&"ui_cancel", JOY_BUTTON_B)


func _add_joy(action: StringName, button: JoyButton) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	if InputMap.has_action(action) and not InputMap.action_has_event(action, ev):
		InputMap.action_add_event(action, ev)


func has_flag(flag: StringName) -> bool:
	return flags.get(flag, false)


func set_flag(flag: StringName, value: bool = true) -> void:
	flags[flag] = value


## Le héros est-il dans les Abysses ? (L'endurance et le mana n'y remontent pas tout seuls.)
func in_dungeon() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path.contains("/dungeon/")


func hero_max_health() -> int:
	return HERO_BASE_HEALTH if has_flag(&"prologue_done") else HERO_PROLOGUE_HEALTH


## Nouvelle partie : tout est remis à zéro.
func reset() -> void:
	flags.clear()
	day = 1
	time_minutes = 480.0
	harvested.clear()
	abyss_clears = 0
	next_spawn = &""
	pending_position = null
	Inventory.clear()
	Town.reset()
	Quests.reset()
	Roster.reset()


# ------------------------------------------------------------------ récoltes

func is_harvested(key: String, regrow_days: int) -> bool:
	if not harvested.has(key):
		return false
	if regrow_days <= 0:
		return true
	if day - int(harvested[key]) >= regrow_days:
		harvested.erase(key)
		return false
	return true


func mark_harvested(key: String) -> void:
	harvested[key] = day


# ------------------------------------------------------------------ le sommeil

## Le héros dort : fondu au noir, un jour passe, les chantiers avancent, il récupère.
func sleep() -> void:
	if _sleeping:
		return
	_sleeping = true
	var player := get_tree().get_first_node_in_group("player") as Player
	if player:
		player.input_locked = true
	await Transition.fade_out(0.8)
	# On dort jusqu'au lendemain matin (le jour change à l'aube).
	var finished := _new_day(true)
	time_minutes = WAKE
	var scene := get_tree().current_scene
	if scene:
		_apply_sky(scene)
	if player:
		player.health.heal(player.health.max_health)
	await Transition.story_text("Jour %d — %s" % [day, clock_text()], 1.2)
	for text in finished:
		await Transition.story_text(text, 1.6)
	Save.save_game()
	await Transition.fade_in(0.8)
	if player:
		player.input_locked = false
	_sleeping = false


# ------------------------------------------------------------------ sauvegarde

func serialize() -> Dictionary:
	var f := {}
	for k in flags:
		f[String(k)] = flags[k]
	return {"flags": f, "day": day, "time": time_minutes, "harvested": harvested.duplicate(), "abyss_clears": abyss_clears}


func deserialize(data: Dictionary) -> void:
	flags.clear()
	for k in data.get("flags", {}):
		flags[StringName(k)] = bool(data["flags"][k])
	day = int(data.get("day", 1))
	time_minutes = float(data.get("time", 480.0))
	harvested = data.get("harvested", {}).duplicate()
	abyss_clears = int(data.get("abyss_clears", 0))


## F11 (ou Alt+Entrée) : plein écran. En 1080p plein écran, chaque pixel du dessin HD
## fait exactement 2 pixels d'écran.
func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_F11 or (key.keycode == KEY_ENTER and key.alt_pressed):
		var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	var pad := using_pad
	if event is InputEventJoypadButton and event.pressed:
		pad = true
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		pad = true
	elif (event is InputEventKey and event.pressed) or event is InputEventMouseButton:
		pad = false
	if pad != using_pad:
		using_pad = pad
		input_device_changed.emit(pad)
