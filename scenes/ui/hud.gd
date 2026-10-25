extends CanvasLayer
## Interface provisoire : points de vie, classe et jour, ressources, invite d'interaction.
## Elle sera remplacée par de vrais cœurs et une vraie barre d'objets en pixel art.

@onready var health_label: Label = $HealthLabel
@onready var items_box: HBoxContainer = $Items

## Une étiquette par objet affiché, indexée par l'identifiant de l'objet.
var _item_labels: Dictionary[StringName, Label] = {}
var _info: Label
var _prompt: Label
var _objective: Label


func _ready() -> void:
	_info = _make_label(Vector2(8, 22), 10)
	_objective = _make_label(Vector2(8, 36), 10)
	_objective.add_theme_color_override("font_color", Color(1.0, 0.86, 0.5))
	_prompt = _make_label(Vector2(0, 0), 12)
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.offset_top = -52
	_prompt.offset_bottom = -36
	_prompt.offset_left = -200
	_prompt.offset_right = 200
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		health_label.text = ""
	else:
		player.health.health_changed.connect(_on_health_changed)
		_on_health_changed(player.health.current_health, player.health.max_health)

	Inventory.item_changed.connect(_on_item_changed)
	for item in Inventory.get_items():
		_on_item_changed(item, Inventory.get_count(item.id))
	Interaction.focus_changed.connect(_on_focus)
	Game.day_changed.connect(func(_d: int) -> void: _refresh_info())
	Hero.class_changed.connect(func(_c: StringName) -> void: _refresh_info())
	Hero.xp_changed.connect(func(_c: StringName, _l: int, _x: int) -> void: _refresh_info())
	_refresh_info()


func _make_label(at: Vector2, size: int) -> Label:
	var label := Label.new()
	label.position = at
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	add_child(label)
	return label


func _process(_delta: float) -> void:
	_objective.text = Quests.objective_text()


func _refresh_info() -> void:
	if not Game.has_flag(&"prologue_done"):
		_info.text = ""
		return
	_info.text = "%s · %s niv. %d · Jour %d" % [Hero.hero_name, Hero.info()["name"], Hero.level(), Game.day]


func _on_focus(target: Interactable) -> void:
	_prompt.text = "" if target == null else "E : %s" % target.prompt


func _on_health_changed(current: int, maximum: int) -> void:
	health_label.text = "PV : %d / %d" % [current, maximum]


func _on_item_changed(item: ItemData, count: int) -> void:
	if not _item_labels.has(item.id):
		var icon := TextureRect.new()
		icon.texture = item.icon
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icon.tooltip_text = item.display_name
		items_box.add_child(icon)
		var label := Label.new()
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 4)
		items_box.add_child(label)
		_item_labels[item.id] = label
	_item_labels[item.id].text = "%d" % count
	# Les objets épuisés disparaissent de la barre.
	var idx := _item_labels[item.id].get_index()
	items_box.get_child(idx - 1).visible = count > 0
	_item_labels[item.id].visible = count > 0
