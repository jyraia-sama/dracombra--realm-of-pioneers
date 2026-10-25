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
	box.offset_left = -200
	box.offset_right = 200
	box.offset_top = -64
	box.offset_bottom = -8
	box.alignment = BoxContainer.ALIGNMENT_END
	add_child(box)
	_update_label = Label.new()
	_update_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_update_label.add_theme_font_size_override("font_size", 10)
	_update_label.add_theme_color_override("font_color", Color(0.7, 0.66, 0.78))
	_update_label.text = "Version %s" % Updater.version()
	box.add_child(_update_label)
	_update_bar = ProgressBar.new()
	_update_bar.custom_minimum_size = Vector2(220, 6)
	_update_bar.show_percentage = false
	_update_bar.max_value = 1.0
	_update_bar.visible = false
	box.add_child(_update_bar)
	_update_button = Button.new()
	_update_button.visible = false
	_update_button.add_theme_font_size_override("font_size", 11)
	box.add_child(_update_button)
	Updater.status_changed.connect(func(t: String) -> void: _update_label.text = t)
	Updater.progress.connect(func(r: float) -> void:
		_update_bar.visible = true
		_update_bar.value = r)
	Updater.update_available.connect(func(v: String, notes: String) -> void:
		if notes != "":
			_update_label.text += "\n" + notes
		_set_update_button("Mettre à jour (%s)" % v, func() -> void:
			_update_button.disabled = true
			Updater.download()))
	Updater.ready_to_restart.connect(func() -> void:
		_update_bar.visible = false
		_set_update_button("Redémarrer le jeu", Updater.restart))
	Updater.status_changed.connect(func(t: String) -> void:
		# Un échec : on peut réessayer.
		if t.contains("Réessayez") or t.contains("Impossible"):
			_update_button.disabled = false)
	Updater.check()


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
