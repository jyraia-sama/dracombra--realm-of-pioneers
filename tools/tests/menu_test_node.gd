extends Node
## Test des menus au clavier (ZQSD + E), comme un joueur.
var failures := 0
func _ready() -> void:
	_start.call_deferred()
func _start() -> void:
	reparent(get_tree().root)
	get_tree().current_scene = null
	await _run()
	print("TOTAL FAILURES: %d" % failures)
	get_tree().quit()
func _check(cond: bool, label: String) -> void:
	print(("OK   " if cond else "FAIL ") + label)
	if not cond:
		failures += 1
func _key(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame
	await get_tree().process_frame
func _run() -> void:
	var G := get_tree().root.get_node("Game")
	G.reset(); G.set_flag(&"prologue_done")
	get_tree().change_scene_to_file("res://scenes/levels/dracombra/dracombra.tscn")
	await get_tree().create_timer(1.0).timeout
	var menu := get_tree().root.get_node("GameMenu")
	await _key("pause")
	_check(menu.is_open and get_tree().paused, "Échap ouvre le menu et met le jeu en pause")
	await _key("move_right"); await _key("move_right"); await _key("move_right"); await _key("move_right")
	_check(menu._tabs.current_tab == 4, "D change d'onglet jusqu'à Système (%d)" % menu._tabs.current_tab)
	var focus := get_viewport().gui_get_focus_owner() as Button
	_check(focus != null and focus.text.begins_with("Sauvegarder"), "le bouton Sauvegarder a le focus")
	await _key("move_down")
	focus = get_viewport().gui_get_focus_owner() as Button
	_check(focus != null and focus.text.begins_with("Retour"), "S descend sur « Retour au menu principal » (%s)" % (focus.text if focus else "rien"))
	await _key("interact")
	var ok := false
	for i in 200:
		await get_tree().process_frame
		if get_tree().current_scene and get_tree().current_scene.name == "TitleScreen":
			ok = true
			break
	_check(ok and not get_tree().paused, "E valide : retour à l'écran titre")
	await get_tree().create_timer(0.5).timeout
	focus = get_viewport().gui_get_focus_owner() as Button
	_check(focus != null, "écran titre : un bouton a le focus")
	await _key("move_down")
	var f2 := get_viewport().gui_get_focus_owner() as Button
	_check(f2 != null and f2 != focus, "écran titre : S passe au bouton suivant")
