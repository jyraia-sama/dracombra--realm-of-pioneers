class_name Hotbar
extends HBoxContainer
## Barre d'outils en bas de l'écran : l'arme de la classe, la hache, la pioche, puis les
## soins (baume, viande). Touches 1 à 6 pour utiliser un consommable ; H (ou RB) prend
## le meilleur soin disponible. Les outils servent tout seuls quand on frappe.

const SLOTS: Array[StringName] = [&"__weapon", &"axe", &"pickaxe", &"balm", &"meat", &"herb"]
const SLOT := 22

var _cells: Array[Dictionary] = []
var _flash := -1


func _ready() -> void:
	add_theme_constant_override("separation", 2)
	for i in SLOTS.size():
		var panel := Panel.new()
		panel.custom_minimum_size = Vector2(SLOT, SLOT)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.16, 0.14, 0.2, 0.85)
		style.border_color = Color(0.45, 0.38, 0.55)
		style.set_border_width_all(1)
		panel.add_theme_stylebox_override("panel", style)
		var icon := TextureRect.new()
		icon.position = Vector2(3, 3)
		icon.size = Vector2(16, 16)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		panel.add_child(icon)
		var key := _label(str(i + 1), Vector2(1, -2), Color(0.85, 0.8, 0.9))
		panel.add_child(key)
		var count := _label("", Vector2(8, 11), Color.WHITE)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.size = Vector2(13, 10)
		panel.add_child(count)
		add_child(panel)
		_cells.append({"panel": panel, "style": style, "icon": icon, "count": count})
	Inventory.item_changed.connect(func(_item: ItemData, _n: int) -> void: refresh())
	Hero.class_changed.connect(func(_c: StringName) -> void: refresh())
	refresh()


func _label(text: String, at: Vector2, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = at
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 3)
	return l


func refresh() -> void:
	for i in SLOTS.size():
		var cell: Dictionary = _cells[i]
		var id := SLOTS[i]
		if id == &"__weapon":
			var atlas := AtlasTexture.new()
			atlas.atlas = load("res://assets/sprites/items/items.png")
			atlas.region = Rect2(int(Hero.info()["icon"]), 0, 16, 16)
			cell["icon"].texture = atlas
			cell["icon"].modulate = Color.WHITE
			cell["count"].text = ""
			continue
		var item := Inventory.item_by_id(id)
		var n := Inventory.get_count(id)
		cell["icon"].texture = item.icon if item else null
		# Ce qu'on ne possède pas encore apparaît en ombre.
		cell["icon"].modulate = Color.WHITE if n > 0 else Color(0.35, 0.35, 0.4, 0.6)
		cell["count"].text = str(n) if n > 0 and item.category != &"tool" else ""
		cell["panel"].tooltip_text = item.display_name if item else ""


func _unhandled_input(event: InputEvent) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or player.input_locked or get_tree().paused:
		return
	for i in SLOTS.size():
		if event.is_action_pressed("slot_%d" % (i + 1)):
			get_viewport().set_input_as_handled()
			use_slot(i)
			return
	if event.is_action_pressed("quick_heal"):
		get_viewport().set_input_as_handled()
		for i in [3, 4]:
			if use_slot(i):
				return


## Utilise l'objet de la case (s'il se consomme). Renvoie true s'il a servi.
func use_slot(i: int) -> bool:
	var id := SLOTS[i]
	var item := Inventory.item_by_id(id) if id != &"__weapon" else null
	var player := get_tree().get_first_node_in_group("player") as Player
	_blink(i)
	if item == null or player == null or item.use_heal <= 0 or Inventory.get_count(id) <= 0:
		return false
	if player.health.current_health >= player.health.max_health:
		Emote.show(player, "PV max", Color(0.7, 1.0, 0.7), 34.0)
		return false
	Inventory.remove_item(item, 1)
	player.health.heal(item.use_heal)
	Emote.show(player, "+%d" % item.use_heal, Color(0.5, 1.0, 0.5), 34.0)
	return true


func _blink(i: int) -> void:
	var style: StyleBoxFlat = _cells[i]["style"]
	style.border_color = Color(1.0, 0.85, 0.4)
	var tween := create_tween()
	tween.tween_property(style, "border_color", Color(0.45, 0.38, 0.55), 0.3)
