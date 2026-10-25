extends Control
## Écran titre : continuer la partie sauvegardée, ou en commencer une nouvelle
## (en choisissant le nom du héros).

const FIRST_LEVEL := "res://scenes/levels/prologue/cave_entrance.tscn"

var _menu: VBoxContainer
var _name_box: VBoxContainer
var _name_edit: LineEdit


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.07)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Le bas de l'écran est réservé aux mises à jour (version, nouveautés, bouton).
	center.offset_bottom = -92
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)
	var title := Label.new()
	title.text = "DRACOMBRA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.95, 0.72, 0.38))
	title.add_theme_color_override("font_outline_color", Color(0.2, 0.08, 0.05))
	title.add_theme_constant_override("outline_size", 6)
	box.add_child(title)
	var sub := Label.new()
	sub.text = "Realm of Pioneers"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color(0.8, 0.75, 0.9))
	box.add_child(sub)
	box.add_child(Control.new())

	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 6)
	box.add_child(_menu)
	if Save.has_save():
		_add_button(_menu, "Continuer", _on_continue)
	_add_button(_menu, "Nouvelle partie", _on_new)
	_add_button(_menu, "Quitter", func() -> void: get_tree().quit())

	_name_box = VBoxContainer.new()
	_name_box.visible = false
	box.add_child(_name_box)
	var ask := Label.new()
	ask.text = "Quel est le nom du héros ?"
	ask.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_box.add_child(ask)
	_name_edit = LineEdit.new()
	_name_edit.text = "Heros"
	_name_edit.max_length = 16
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_edit.text_submitted.connect(func(_t: String) -> void: _start())
	_name_box.add_child(_name_edit)
	_add_button(_name_box, "Commencer", _start)
	(_menu.get_child(0) as Button).grab_focus()
	_build_updates()


# ------------------------------------------------------------------ mises à jour

var _update_label: Label
var _update_button: Button
var _update_bar: ProgressBar


## En bas de l'écran : la version, et un bouton quand une mise à jour est disponible.
func _build_updates() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	box.offset_left = -190
	box.offset_right = 190
	box.offset_top = -8
	box.offset_bottom = -8
	# Le bloc grandit vers le haut, jamais sur les côtés.
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.alignment = BoxContainer.ALIGNMENT_END
	box.add_theme_constant_override("separation", 3)
	add_child(box)
	_update_label = Label.new()
	_update_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_update_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_update_label.custom_minimum_size = Vector2(380, 0)
	# Au plus 4 lignes : les nouveautés trop longues sont coupées.
	_update_label.max_lines_visible = 4
	_update_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_update_label.add_theme_font_size_override("font_size", 10)
	_update_label.add_theme_color_override("font_color", Color(0.7, 0.66, 0.78))
	_update_label.text = "Version %s" % Updater.version()
	box.add_child(_update_label)
	_update_bar = ProgressBar.new()
	_update_bar.custom_minimum_size = Vector2(220, 6)
	_update_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_update_bar.show_percentage = false
	_update_bar.max_value = 1.0
	_update_bar.visible = false
	box.add_child(_update_bar)
	_update_button = Button.new()
	_update_button.visible = false
	_update_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_update_button.custom_minimum_size = Vector2(220, 0)
	_update_button.add_theme_font_size_override("font_size", 11)
	box.add_child(_update_button)
	# Liaisons vers l'Updater (qui reste chargé) : coupées quand l'écran titre disparaît,
	# sinon un retour au menu garderait celles de l'ancien écran.
	_link(Updater.status_changed, _on_update_status)
	_link(Updater.progress, _on_update_progress)
	_link(Updater.update_available, _on_update_available)
	_link(Updater.ready_to_restart, _on_ready_to_restart)
	# Lancé depuis Téléchargements ou le Bureau : on propose de l'installer d'abord.
	if Updater.can_install():
		_update_label.text = "Version %s — installez le jeu pour recevoir les mises à jour." % Updater.version()
		_set_update_button("Installer le jeu sur ce PC", func() -> void:
			_update_button.disabled = true
			var err := Updater.install()
			if err != "":
				_update_label.text = err
				_update_button.disabled = false)
		return
	Updater.check()


var _links: Array = []


func _link(sig: Signal, callable: Callable) -> void:
	sig.connect(callable)
	_links.append([sig, callable])


func _exit_tree() -> void:
	for l in _links:
		if (l[0] as Signal).is_connected(l[1]):
			(l[0] as Signal).disconnect(l[1])
	_links.clear()


func _on_update_status(t: String) -> void:
	_update_label.text = t
	# Un échec : on peut réessayer.
	if t.contains("Réessayez") or t.contains("Impossible"):
		_update_button.disabled = false


func _on_update_progress(r: float) -> void:
	_update_bar.visible = true
	_update_bar.value = r


func _on_update_available(v: String, notes: String) -> void:
	if notes != "":
		_update_label.text += "\n" + notes
	_set_update_button("Mettre à jour (%s)" % v, func() -> void:
		_update_button.disabled = true
		Updater.download())


func _on_ready_to_restart() -> void:
	_update_bar.visible = false
	_set_update_button("Redémarrer le jeu", Updater.restart)


func _set_update_button(text: String, action: Callable) -> void:
	_update_button.text = text
	_update_button.disabled = false
	_update_button.visible = true
	for c in _update_button.pressed.get_connections():
		_update_button.pressed.disconnect(c["callable"])
	_update_button.pressed.connect(action)


func _add_button(parent: Control, text: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(220, 0)
	b.pressed.connect(action)
	parent.add_child(b)


func _on_continue() -> void:
	Save.load_game()


func _on_new() -> void:
	_menu.visible = false
	_name_box.visible = true
	_name_edit.grab_focus()
	_name_edit.select_all()


func _start() -> void:
	Game.reset()
	Hero.reset()
	var name := _name_edit.text.strip_edges()
	Hero.hero_name = name if name != "" else "Heros"
	Transition.change_scene(FIRST_LEVEL)


func _unhandled_input(event: InputEvent) -> void:
	# Pendant la saisie du nom, les lettres vont dans le champ (pas de navigation ZQSD).
	if _name_edit.has_focus():
		return
	if UiNav.handle(event, get_viewport()):
		get_viewport().set_input_as_handled()
