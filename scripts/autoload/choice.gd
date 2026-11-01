extends CanvasLayer
## Petite fenêtre de choix, au clavier ou à la manette :
##     var i := await Choice.ask("Guilde", "Que faire ?", ["Dormir", "Améliorer", "Fermer"])
## Renvoie l'indice choisi, ou -1 si on ferme (Échap / bouton B).

signal _picked(index: int)

var is_open := false

var _panel: PanelContainer
var _title: Label
var _body: Label
var _buttons: VBoxContainer
var _scroll: ScrollContainer


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.1, 0.94)
	style.border_color = Color(0.55, 0.45, 0.7)
	style.set_border_width_all(1)
	style.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(300, 0)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_panel.add_child(box)
	_title = Label.new()
	_title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.45))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("font_size", 12)
	_body.custom_minimum_size = Vector2(280, 0)
	box.add_child(_body)
	# Les longues listes (recettes de l'établi) défilent au lieu de sortir de l'écran.
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	box.add_child(_scroll)
	_buttons = VBoxContainer.new()
	_buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_buttons)
	_panel.visible = false
	_make_button_styles()


## Styles des boutons : le cadre de focus par défaut de Godot dépassait du bouton et était
## coupé par la zone de défilement (traits blancs bizarres). Ici, le bouton choisi est
## simplement surligné, dans le cadre.
var _styles := {}


func _make_button_styles() -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.13, 0.12, 0.16)
	normal.set_content_margin_all(4)
	normal.set_corner_radius_all(2)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.2, 0.17, 0.27)
	var focus := normal.duplicate() as StyleBoxFlat
	focus.bg_color = Color(0.3, 0.23, 0.42)
	focus.border_color = Color(1.0, 0.82, 0.45)
	focus.set_border_width_all(1)
	var pressed := focus.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.38, 0.29, 0.52)
	_styles = {"normal": normal, "hover": hover, "pressed": pressed, "disabled": normal,
		"focus": StyleBoxEmpty.new()}
	_styles["_focus_bg"] = focus


func _style_button(b: Button) -> void:
	for key in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(key, _styles[key])
	b.add_theme_color_override("font_focus_color", Color(1.0, 0.86, 0.5))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.85))
	# Le bouton qui a le focus (clavier / manette) prend le fond surligné.
	b.focus_entered.connect(func() -> void: b.add_theme_stylebox_override("normal", _styles["_focus_bg"]); b.add_theme_stylebox_override("hover", _styles["_focus_bg"]))
	b.focus_exited.connect(func() -> void: b.add_theme_stylebox_override("normal", _styles["normal"]); b.add_theme_stylebox_override("hover", _styles["hover"]))


## bottom = true : en bas de l'écran (dialogues), pour ne pas cacher les personnages.
func ask(title: String, body: String, options: Array, bottom: bool = false) -> int:
	if is_open:
		return -1
	is_open = true
	Interaction.blocked = true
	var player := get_tree().get_first_node_in_group("player") as Player
	var was_locked := player.input_locked if player else false
	if player:
		player.input_locked = true
	_title.text = title
	_body.text = body
	_body.visible = body != ""
	for child in _buttons.get_children():
		child.queue_free()
	for i in options.size():
		var b := Button.new()
		b.text = options[i]
		b.pressed.connect(func(): _picked.emit(i))
		_style_button(b)
		if options.size() > 7:
			b.add_theme_font_size_override("font_size", 12)
		_buttons.add_child(b)
	_scroll.custom_minimum_size = Vector2.ZERO
	_scroll.scroll_vertical = 0
	_panel.visible = true
	# Le panneau se recentre une fois sa taille connue.
	await get_tree().process_frame
	_scroll.custom_minimum_size = Vector2(0, minf(_buttons.get_combined_minimum_size().y, 230.0))
	_panel.reset_size()
	if bottom:
		_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 10)
	else:
		_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	if _buttons.get_child_count() > 0:
		(_buttons.get_child(0) as Button).grab_focus()
	var index: int = await _picked
	BugReport.log_event("Choix « %s » : %s" % [title, options[index] if index >= 0 and index < options.size() else "fermé"])
	_panel.visible = false
	is_open = false
	if player and is_instance_valid(player):
		player.input_locked = was_locked
	# Laisse passer l'image pour que la touche de validation ne déclenche rien d'autre.
	await get_tree().process_frame
	Interaction.blocked = false
	return index


## Retour / fermeture en priorité (avant le reste du jeu) : Échap, B (clavier), bouton B.
func _input(event: InputEvent) -> void:
	if is_open and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") \
			or event.is_action_pressed("build")):
		get_viewport().set_input_as_handled()
		_picked.emit(-1)


func _unhandled_input(event: InputEvent) -> void:
	if is_open and UiNav.handle(event, get_viewport()):
		get_viewport().set_input_as_handled()
