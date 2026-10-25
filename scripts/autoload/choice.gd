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
	_buttons = VBoxContainer.new()
	box.add_child(_buttons)
	_panel.visible = false


func ask(title: String, body: String, options: Array) -> int:
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
		_buttons.add_child(b)
	_panel.visible = true
	# Le panneau se recentre une fois sa taille connue.
	await get_tree().process_frame
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	if _buttons.get_child_count() > 0:
		(_buttons.get_child(0) as Button).grab_focus()
	var index: int = await _picked
	_panel.visible = false
	is_open = false
	if player and is_instance_valid(player):
		player.input_locked = was_locked
	# Laisse passer l'image pour que la touche de validation ne déclenche rien d'autre.
	await get_tree().process_frame
	Interaction.blocked = false
	return index


func _unhandled_input(event: InputEvent) -> void:
	if is_open and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		get_viewport().set_input_as_handled()
		_picked.emit(-1)
	elif is_open and UiNav.handle(event, get_viewport()):
		get_viewport().set_input_as_handled()
