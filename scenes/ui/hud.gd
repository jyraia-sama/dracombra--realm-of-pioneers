extends CanvasLayer
## Interface : cadre du héros (vie, endurance, mana, XP), classe et jour, objectif,
## ressources du sac et invite d'interaction.

@onready var health_label: Label = $HealthLabel
@onready var items_box: HBoxContainer = $Items

## Une étiquette par objet affiché, indexée par l'identifiant de l'objet.
var _item_labels: Dictionary[StringName, Label] = {}
var _info: Label
var _prompt: Label
var _objective: Label
var bars: StatBars
var _hp := Vector2i(0, 0)


func _ready() -> void:
	# Le texte « PV : x / y » reste calculé (tests), mais ce sont les barres qu'on voit.
	health_label.visible = false
	bars = StatBars.new()
	bars.name = "StatBars"
	bars.position = Vector2(7, 6)
	add_child(bars)
	_info = _make_label(Vector2(8, 40), 9)
	_objective = _make_label(Vector2(8, 52), 10)
	_objective.add_theme_color_override("font_color", Color(1.0, 0.86, 0.5))
	_prompt = _make_label(Vector2(0, 0), 12)
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.offset_top = -52
	_prompt.offset_bottom = -36
	_prompt.offset_left = -200
	_prompt.offset_right = 200
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Barre d'outils en bas, une fois le prologue terminé.
	var hotbar := Hotbar.new()
	hotbar.name = "Hotbar"
	hotbar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hotbar.offset_left = -Hotbar.width() / 2.0
	hotbar.offset_right = Hotbar.width() / 2.0
	hotbar.offset_top = -Hotbar.SLOT - 4
	hotbar.offset_bottom = -4
	hotbar.visible = Game.has_flag(&"prologue_done")
	# Sa propre couche, au-dessus des textes de narration.
	var bar_layer := CanvasLayer.new()
	bar_layer.name = "HotbarLayer"
	bar_layer.layer = 21
	add_child(bar_layer)
	bar_layer.add_child(hotbar)

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
	Hero.stats_changed.connect(_refresh_info)
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
	_refresh_health()
	_refresh_bars()
	var hotbar := get_node_or_null("HotbarLayer/Hotbar") as Control
	if hotbar:
		hotbar.visible = Game.has_flag(&"prologue_done")


func _refresh_info() -> void:
	if not Game.has_flag(&"prologue_done"):
		_info.text = ""
		return
	var pts := Hero.free_points()
	_info.text = "%s · %s · Jour %d%s" % [Hero.hero_name, Hero.info()["name"], Game.day,
		"  (+%d points : menu Personnage)" % pts if pts > 0 else ""]


func _on_focus(target: Interactable) -> void:
	_prompt.text = "" if target == null else "E : %s" % target.prompt


func _on_health_changed(current: int, maximum: int) -> void:
	_hp = Vector2i(current, maximum)
	_refresh_health()


func _refresh_health() -> void:
	if _hp.y == 0:
		return
	var text := "PV : %d / %d" % [_hp.x, _hp.y]
	if Game.has_flag(&"prologue_done"):
		text += "    %s : %d / %d" % [Hero.info()["resource"], int(Hero.energy), int(Hero.energy_max())]
	health_label.text = text


func _refresh_bars() -> void:
	var done := Game.has_flag(&"prologue_done")
	bars.visible = _hp.y > 0
	bars.show_resources = done
	bars.show_mana = done and Hero.uses_mana()
	bars.set_values(_hp.x, _hp.y, Hero.stamina, Hero.stamina_max(), Hero.mana, Hero.mana_max())
	var need := Hero.xp_to_next(Hero.level())
	bars.xp_ratio = 1.0 if need == 0 else clampf(float(Hero.xp.get(Hero.current, 0)) / need, 0.0, 1.0)
	bars.level = Hero.level()
	var key := int(Hero.info()["icon"]) if done else 272
	if bars.icon == null or bars.icon.get_meta("cell", -1) != key:
		var atlas := AtlasTexture.new()
		atlas.atlas = load("res://assets/sprites/items/items.png")
		atlas.region = Rect2(key * 2, 0, 32, 32)
		atlas.set_meta("cell", key)
		bars.icon = atlas


func _on_item_changed(item: ItemData, count: int) -> void:
	# L'équipement à porter ne s'affiche pas en haut de l'écran (il est dans le menu).
	if item.slot != &"":
		return
	if not _item_labels.has(item.id):
		var icon := TextureRect.new()
		icon.texture = item.icon
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.custom_minimum_size = Vector2(16, 16)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
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
