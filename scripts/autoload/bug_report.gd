extends Node
## Rapports de bug (F8) : capture d'écran + fiche texte (version, niveau, héros, monstres
## proches, journal des dernières secondes), rangés dans Documents/Dracombra/rapports.
## Le dossier s'ouvre tout seul : il suffit de glisser les fichiers dans la conversation.
##
## Option « enregistrement » (menu admin F9) : une image par seconde est gardée en mémoire ;
## le rapport ajoute alors une planche des 12 dernières secondes.

const LOG_SECONDS := 30.0
const FILM_FRAMES := 12

## Journal : [temps (s), texte].
var _log: Array = []
var _sample := 0.0
var recording := false
var _film: Array[Image] = []
var _film_timer := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Transition.scene_changed.connect(func() -> void:
		var s := get_tree().current_scene
		log_event("Niveau : %s" % (s.scene_file_path.get_file() if s else "?")))


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_F8:
		get_viewport().set_input_as_handled()
		save_report()


## Ajoute une ligne au journal (appelé par Fx, Choice, le donjon...).
func log_event(text: String) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	_log.append([now, text])
	while not _log.is_empty() and now - float(_log[0][0]) > LOG_SECONDS:
		_log.pop_front()


func _process(delta: float) -> void:
	# Position et état du héros toutes les demi-secondes.
	_sample -= delta
	if _sample <= 0.0:
		_sample = 0.5
		var p := get_tree().get_first_node_in_group("player") as Player
		if p:
			log_event("héros %s état=%s PV=%d/%d vitesse=%d" % [_v(p.global_position), Player.State.keys()[p.state],
				p.health.current_health, p.health.max_health, int(p.velocity.length())])
	if recording:
		_film_timer -= delta
		if _film_timer <= 0.0:
			_film_timer = 1.0
			var img := get_viewport().get_texture().get_image()
			img.resize(480, 270, Image.INTERPOLATE_BILINEAR)
			_film.append(img)
			while _film.size() > FILM_FRAMES:
				_film.pop_front()


func set_recording(on: bool) -> void:
	recording = on
	_film.clear()
	_film_timer = 0.0


func save_report() -> void:
	var dir := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS).path_join("Dracombra").path_join("rapports")
	if DirAccess.make_dir_recursive_absolute(dir) != OK:
		dir = OS.get_user_data_dir().path_join("rapports")
		DirAccess.make_dir_recursive_absolute(dir)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var base := dir.path_join("rapport_%s" % stamp)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(base + ".png")
	if recording and not _film.is_empty():
		_save_film(base + "_film.png")
	var f := FileAccess.open(base + ".txt", FileAccess.WRITE)
	if f:
		f.store_string(_report_text())
		f.close()
	Narration.say("Rapport enregistré (Documents/Dracombra/rapports).", 2.5)
	OS.shell_open(dir)


func _save_film(path: String) -> void:
	var cols := 4
	var rows := ceili(_film.size() / float(cols))
	var sheet := Image.create(480 * cols, 270 * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.BLACK)
	for i in _film.size():
		var img := _film[i]
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(0, 0, 480, 270), Vector2i((i % cols) * 480, (i / cols) * 270))
	sheet.save_png(path)


func _report_text() -> String:
	var lines: Array[String] = []
	lines.append("Dracombra %s — rapport du %s" % [Updater.version(), Time.get_datetime_string_from_system()])
	var scene := get_tree().current_scene
	lines.append("Niveau : %s" % (scene.scene_file_path if scene else "?"))
	if Game.dungeon_floor > 0:
		lines.append("Donjon : étage %d" % Game.dungeon_floor)
	lines.append("Jour %d · palier de la guilde %d" % [Game.day, Town.tier])
	var p := get_tree().get_first_node_in_group("player") as Player
	if p:
		lines.append("Héros : %s, %s niveau %d, PV %d/%d, état %s, regard %s, position %s, bloqué=%s, actions bloquées=%s" % [
			Hero.hero_name, Hero.info()["name"], Hero.level(), p.health.current_health, p.health.max_health,
			Player.State.keys()[p.state], _v(p.facing), _v(p.global_position), p.input_locked, p.actions_locked])
		lines.append("")
		lines.append("Monstres proches (moins de 12 cases) :")
		for e in get_tree().get_nodes_in_group("enemies"):
			var en := e as Node2D
			if en == null:
				continue
			var d := en.global_position.distance_to(p.global_position) / Game.TILE_SIZE
			if d > 12.0:
				continue
			var h := en.get_node_or_null("Health") as HealthComponent
			var st = en.get("state")
			lines.append("  - %s à %.1f cases, position %s, PV %s, état %s" % [en.name, d, _v(en.global_position),
				"%d/%d" % [h.current_health, h.max_health] if h else "?", str(st)])
	lines.append("")
	lines.append("Journal des %d dernières secondes :" % int(LOG_SECONDS))
	var now := Time.get_ticks_msec() / 1000.0
	for entry in _log:
		lines.append("  -%5.1f s  %s" % [now - float(entry[0]), entry[1]])
	lines.append("")
	lines.append("Ce qui s'est passé (à compléter) : ")
	return "\n".join(lines)


func _v(v: Vector2) -> String:
	return "(%d, %d)" % [int(v.x), int(v.y)] if absf(v.x) > 1.5 or absf(v.y) > 1.5 else "(%.1f, %.1f)" % [v.x, v.y]
