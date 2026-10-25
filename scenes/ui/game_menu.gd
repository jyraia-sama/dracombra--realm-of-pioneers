extends CanvasLayer
## Menu du jeu (Échap / Start) : Sac, Personnage, Équipement, Carte, Système.
## Raccourcis : I (ou LB) ouvre le sac, M (ou Select) ouvre la carte.
## Le jeu est en pause tant que le menu est ouvert.

const TABS := ["Sac", "Personnage", "Équipement", "Carte", "Système"]
const TAB_BAG := 0
const TAB_HERO := 1
const TAB_GEAR := 2
const TAB_MAP := 3
const TAB_SYSTEM := 4

var is_open := false

var _root: PanelContainer
var _tabs: TabContainer
# Sac
var _bag_list: ItemList
var _bag_info: Label
var _bag_use: Button
var _bag_ids: Array[StringName] = []
# Personnage
var _sheet: RichTextLabel
var _class_box: HBoxContainer
var _stat_rows: Dictionary = {}
var _derived: Label
var _reset_points: Button
var _skill_title: Label
var _skill_box: VBoxContainer
var _skill_info: Label
var _slot_buttons: Array[Button] = []
var _selected_skill: StringName = &""
# Équipement
var _gear_buttons: Dictionary = {}
var _gear_slot: StringName = &"head"
var _gear_title: Label
var _gear_info: Label
var _gear_choices: VBoxContainer
var _gear_total: Label
var _gear_portrait: TextureRect
# Carte
var _map_view: TextureRect
var _map_marker: Control
var _map_title: Label
var _map_rect := Rect2i()
var _map_scale := 1.0
# Système
var _save_button: Button

var _color_cache := {}


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.06, 0.09, 0.96)
	style.border_color = Color(0.55, 0.45, 0.7)
	style.set_border_width_all(1)
	style.set_content_margin_all(8)
	_root.add_theme_stylebox_override("panel", style)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.offset_left = 24
	_root.offset_right = -24
	_root.offset_top = 16
	_root.offset_bottom = -16
	add_child(_root)
	_tabs = TabContainer.new()
	_tabs.add_theme_font_size_override("font_size", 12)
	_root.add_child(_tabs)
	_build_bag()
	_build_sheet()
	_build_gear()
	_build_map()
	_build_system()
	_tabs.tab_changed.connect(func(_i: int) -> void: _refresh())
	_root.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if Choice.is_open:
		return
	if is_open:
		if UiNav.handle(event, get_viewport()):
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel") \
				or (event.is_action_pressed("bag") and _tabs.current_tab == TAB_BAG) \
				or (event.is_action_pressed("map") and _tabs.current_tab == TAB_MAP):
			get_viewport().set_input_as_handled()
			close()
		elif event.is_action_pressed("move_left"):
			get_viewport().set_input_as_handled()
			_tabs.current_tab = posmod(_tabs.current_tab - 1, TABS.size())
		elif event.is_action_pressed("move_right"):
			get_viewport().set_input_as_handled()
			_tabs.current_tab = posmod(_tabs.current_tab + 1, TABS.size())
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or player.input_locked or Transition.is_busy:
		return
	var tab := -1
	if event.is_action_pressed("pause"):
		tab = 0
	elif event.is_action_pressed("bag"):
		tab = 0
	elif event.is_action_pressed("map"):
		tab = TAB_MAP
	if tab >= 0:
		get_viewport().set_input_as_handled()
		open(tab)


func open(tab: int = 0) -> void:
	is_open = true
	get_tree().paused = true
	_root.visible = true
	_tabs.current_tab = tab
	_build_minimap()
	_refresh()


func close() -> void:
	is_open = false
	_root.visible = false
	get_tree().paused = false


func _refresh() -> void:
	match _tabs.current_tab:
		0:
			_refresh_bag()
			_bag_list.grab_focus()
		1:
			_refresh_sheet()
			await get_tree().process_frame
			for b in _skill_box.get_children():
				if b is Button and not b.disabled:
					b.grab_focus()
					break
		TAB_GEAR:
			_refresh_gear()
			_gear_buttons[_gear_slot].grab_focus()
		TAB_MAP:
			_refresh_map()
		TAB_SYSTEM:
			_save_button.disabled = not Game.has_flag(&"prologue_done")
			_save_button.text = "Sauvegarder" if not _save_button.disabled else "Sauvegarder (après le prologue)"
			_save_button.grab_focus()


# ------------------------------------------------------------------ le sac

func _build_bag() -> void:
	var box := HBoxContainer.new()
	box.name = "Sac"
	_tabs.add_child(box)
	_bag_list = ItemList.new()
	_bag_list.custom_minimum_size = Vector2(300, 0)
	_bag_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bag_list.max_columns = 0
	_bag_list.same_column_width = true
	_bag_list.fixed_column_width = 140
	_bag_list.add_theme_font_size_override("font_size", 11)
	_bag_list.fixed_icon_size = Vector2i(16, 16)
	_bag_list.item_selected.connect(_on_bag_selected)
	_bag_list.item_activated.connect(func(_i: int) -> void: _on_bag_use())
	box.add_child(_bag_list)
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(side)
	_bag_info = Label.new()
	_bag_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bag_info.add_theme_font_size_override("font_size", 12)
	_bag_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(_bag_info)
	_bag_use = Button.new()
	_bag_use.text = "Utiliser"
	_bag_use.pressed.connect(_on_bag_use)
	side.add_child(_bag_use)


func _refresh_bag() -> void:
	_bag_list.clear()
	_bag_ids.clear()
	var items := Inventory.get_items()
	items.sort_custom(func(a, b): return String(a.category) + a.display_name < String(b.category) + b.display_name)
	for item in items:
		_bag_list.add_item("%s ×%d" % [item.display_name, Inventory.get_count(item.id)], item.icon)
		_bag_ids.append(item.id)
	if _bag_ids.is_empty():
		_bag_info.text = "Le sac est vide.\n\nCoupez des arbres, cassez des rochers, cueillez herbes et lin : frappez-les avec votre arme."
		_bag_use.visible = false
	else:
		_bag_list.select(0)
		_on_bag_selected(0)


func _on_bag_selected(index: int) -> void:
	if index < 0 or index >= _bag_ids.size():
		return
	var item := Inventory.item_by_id(_bag_ids[index])
	var text := "%s\n\n%s" % [item.display_name, item.description]
	if item.use_heal > 0:
		text += "\n\nRend %d PV." % item.use_heal
	for cls in Hero.CLASSES:
		if Hero.CLASSES[cls]["item"] == item.id:
			text += "\n\nDébloque la classe %s." % Hero.CLASSES[cls]["name"]
	if item.slot != &"":
		text += "\n\n%s : %s" % [Hero.GEAR_NAMES.get(item.slot, ""), bonus_text(item)]
		if not item.classes.is_empty():
			var names: Array[String] = []
			for c in item.classes:
				names.append(Hero.CLASSES[c]["name"])
			text += "\nClasses : %s" % ", ".join(names)
	_bag_info.text = text
	_bag_use.text = "Porter" if item.slot != &"" else "Utiliser"
	_bag_use.visible = item.use_heal > 0 or item.slot != &""
	_bag_use.disabled = item.slot != &"" and not Hero.can_wear(item)


func _on_bag_use() -> void:
	var sel := _bag_list.get_selected_items()
	if sel.is_empty():
		return
	var item := Inventory.item_by_id(_bag_ids[sel[0]])
	var player := get_tree().get_first_node_in_group("player") as Player
	if item.slot != &"":
		Hero.wear(item.id)
	elif item.use_heal > 0 and player and player.health.current_health < player.health.max_health:
		Inventory.remove_item(item, 1)
		player.health.heal(item.use_heal)
	var keep := sel[0]
	_refresh_bag()
	if keep < _bag_ids.size():
		_bag_list.select(keep)
		_on_bag_selected(keep)


# ------------------------------------------------------------------ la fiche du personnage

func _small(text: String, size: int = 11) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	return l


func _small_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 11)
	return b


func _build_sheet() -> void:
	var box := VBoxContainer.new()
	box.name = "Personnage"
	box.add_theme_constant_override("separation", 4)
	_tabs.add_child(box)
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 10)
	box.add_child(cols)

	# Colonne de gauche : identité, caractéristiques, valeurs dérivées.
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(250, 0)
	left.add_theme_constant_override("separation", 2)
	cols.add_child(left)
	_sheet = RichTextLabel.new()
	_sheet.bbcode_enabled = true
	_sheet.fit_content = true
	_sheet.scroll_active = false
	_sheet.add_theme_font_size_override("normal_font_size", 11)
	_sheet.add_theme_font_size_override("bold_font_size", 11)
	left.add_child(_sheet)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 0)
	left.add_child(grid)
	for k in Hero.STATS:
		var name := _small("%s" % Hero.STAT_NAMES[k])
		name.custom_minimum_size = Vector2(80, 0)
		name.tooltip_text = Hero.STAT_HELP[k]
		name.mouse_filter = Control.MOUSE_FILTER_PASS
		grid.add_child(name)
		var value := _small("")
		value.custom_minimum_size = Vector2(60, 0)
		grid.add_child(value)
		var plus := _small_button("+")
		plus.custom_minimum_size = Vector2(20, 0)
		plus.tooltip_text = Hero.STAT_HELP[k]
		plus.pressed.connect(func() -> void:
			Hero.spend_point(k)
			_refresh_sheet())
		grid.add_child(plus)
		_stat_rows[k] = {"value": value, "plus": plus}
	_derived = _small("", 10)
	_derived.add_theme_color_override("font_color", Color(0.8, 0.78, 0.86))
	left.add_child(_derived)
	_reset_points = _small_button("Redistribuer les points")
	_reset_points.pressed.connect(func() -> void:
		Hero.reset_points()
		_refresh_sheet())
	left.add_child(_reset_points)

	# Colonne de droite : techniques ou sorts, et leur place dans la barre.
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 2)
	cols.add_child(right)
	_skill_title = _small("", 12)
	_skill_title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.45))
	right.add_child(_skill_title)
	_skill_box = VBoxContainer.new()
	_skill_box.add_theme_constant_override("separation", 1)
	right.add_child(_skill_box)
	_skill_info = _small("", 10)
	_skill_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_skill_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_skill_info)
	var slots := HBoxContainer.new()
	right.add_child(slots)
	for i in Hero.SKILL_SLOTS:
		var b := _small_button("")
		b.pressed.connect(func() -> void:
			if _selected_skill != &"":
				Hero.equip(i, _selected_skill)
				_refresh_sheet())
		slots.add_child(b)
		_slot_buttons.append(b)

	_class_box = HBoxContainer.new()
	box.add_child(_class_box)


func _refresh_sheet() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	var c: Dictionary = Hero.info()
	var lvl := Hero.level()
	var need := Hero.xp_to_next(lvl)
	var lines: Array[String] = []
	lines.append("[b]%s[/b] — %s, niveau %d / %d" % [Hero.hero_name, c["name"], lvl, Hero.MAX_LEVEL])
	lines.append("XP : %s" % ("niveau maximum" if need == 0 else "%d / %d" % [int(Hero.xp.get(Hero.current, 0)), need]))
	if player:
		var res := "PV : %d / %d    Endurance : %d / %d" % [player.health.current_health, player.health.max_health,
			int(Hero.stamina), int(Hero.stamina_max())]
		if Hero.uses_mana():
			res += "    Mana : %d / %d" % [int(Hero.mana), int(Hero.mana_max())]
		lines.append(res)
	var pts := Hero.free_points()
	lines.append("[color=#ffd36e]Points à répartir : %d[/color]" % pts if pts > 0 else "Points à répartir : 0 (+%d par niveau)" % Hero.POINTS_PER_LEVEL)
	_sheet.text = "\n".join(lines)
	for k in Hero.STATS:
		var row: Dictionary = _stat_rows[k]
		var extra := Hero.allocated(k)
		var main := "  ★" if c["main"] == k else ""
		row["value"].text = "%d%s%s" % [Hero.stat(k), " (+%d)" % extra if extra > 0 else "", main]
		row["plus"].disabled = pts <= 0
	_derived.text = "Dégâts %d · Défense %d · Parade %d %% · Critique %d %% · %s +%.1f/s" % [
		Hero.damage(), Hero.defense(), int(Hero.parry_chance()), int(Hero.crit_chance()), c["resource"], Hero.energy_regen()]
	var spent := 0
	for k in Hero.STATS:
		spent += Hero.allocated(k)
	_reset_points.disabled = spent == 0

	# Techniques
	_skill_title.text = "%s du %s" % [c["skill_word"], String(c["name"]).to_lower()]
	for child in _skill_box.get_children():
		_skill_box.remove_child(child)
		child.queue_free()
	var known := Hero.known_skills()
	var slots := Hero.slots()
	var list := SkillBook.of_class(Hero.current)
	if _selected_skill == &"" or not list.has(_selected_skill):
		_selected_skill = list[0]
	for id in list:
		var sk: Dictionary = SkillBook.SKILLS[id]
		var b := _small_button("")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var where := slots.find(id)
		var tag := "  [%s]" % Hotbar.SKILL_KEYS[where] if where >= 0 else ""
		if known.has(id):
			b.text = "Niv. %d · %s%s" % [sk["level"], sk["name"], tag]
		else:
			b.text = "Niv. %d · ???" % sk["level"]
			b.modulate = Color(1, 1, 1, 0.45)
		b.toggle_mode = true
		b.button_pressed = id == _selected_skill
		b.focus_entered.connect(func() -> void: _select_skill(id))
		b.pressed.connect(func() -> void: _select_skill(id))
		_skill_box.add_child(b)
	_select_skill(_selected_skill, false)

	# Classes
	for child in _class_box.get_children():
		_class_box.remove_child(child)
		child.queue_free()
	var can_switch := Hero.can_switch_here()
	var summary: Array[String] = []
	for id in Hero.ORDER:
		var cd: Dictionary = Hero.CLASSES[id]
		if Hero.unlocked.has(id):
			summary.append("%s niv. %d" % [cd["name"], Hero.level(id)])
			var b := _small_button("%s (niv. %d)" % [cd["name"], Hero.level(id)])
			b.disabled = not can_switch or id == Hero.current
			b.tooltip_text = cd["role"]
			b.pressed.connect(func() -> void:
				Hero.switch_to(id)
				_selected_skill = &""
				_refresh_sheet())
			_class_box.add_child(b)
		else:
			var item := Inventory.item_by_id(cd["item"])
			var l := _small("%s : %s" % [cd["name"], ("fabriquer " + item.display_name) if item else "?"], 10)
			l.add_theme_color_override("font_color", Color(0.55, 0.52, 0.6))
			_class_box.add_child(l)
	_sheet.text += "\nClasses : " + ", ".join(summary)
	if not can_switch:
		var l := _small("  (changer de classe : à Dracombra)", 10)
		l.add_theme_color_override("font_color", Color(0.55, 0.52, 0.6))
		_class_box.add_child(l)


func _select_skill(id: StringName, refresh_buttons: bool = true) -> void:
	_selected_skill = id
	var sk: Dictionary = SkillBook.SKILLS[id]
	var known := Hero.known_skills().has(id)
	var c := Hero.info()
	if known:
		_skill_info.text = "%s — %s %d · recharge %ss\n%s" % [sk["name"], c["resource"], sk["cost"],
			String.num(float(sk["cooldown"]), 1).trim_suffix(".0"), sk["desc"]]
	else:
		_skill_info.text = "%s — appris au niveau %d.\n%s" % [sk["name"], sk["level"], sk["desc"]]
	for i in _slot_buttons.size():
		var b := _slot_buttons[i]
		var current: StringName = Hero.slots()[i]
		var cur_name := "vide" if current == &"" else String(SkillBook.SKILLS[current]["name"])
		b.text = "%s : %s" % [Hotbar.SKILL_KEYS[i], cur_name]
		b.tooltip_text = "Placer %s sur la touche %s" % [sk["name"], Hotbar.SKILL_KEYS[i]]
		b.disabled = not known or current == id
	if refresh_buttons:
		for b in _skill_box.get_children():
			if b is Button:
				b.set_pressed_no_signal(b.get_index() == SkillBook.of_class(Hero.current).find(id))


# ------------------------------------------------------------------ la carte

func _build_map() -> void:
	var box := VBoxContainer.new()
	box.name = "Carte"
	_tabs.add_child(box)
	_map_title = Label.new()
	_map_title.add_theme_font_size_override("font_size", 12)
	box.add_child(_map_title)
	var holder := CenterContainer.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(holder)
	var frame := Control.new()
	holder.add_child(frame)
	_map_view = TextureRect.new()
	_map_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.add_child(_map_view)
	_map_marker = Control.new()
	_map_marker.draw.connect(_draw_markers)
	frame.add_child(_map_marker)
	_map_view.set_meta("frame", frame)


## Dessine la carte du niveau : une couleur moyenne par case (sol, murs, eau...).
func _build_minimap() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var layers: Array[TileMapLayer] = []
	for n in ["Ground", "Walls"]:
		var l := scene.get_node_or_null(n) as TileMapLayer
		if l:
			layers.append(l)
	if layers.is_empty():
		_map_view.texture = null
		return
	_map_rect = layers[0].get_used_rect()
	for l in layers:
		_map_rect = _map_rect.merge(l.get_used_rect())
	var img := Image.create(_map_rect.size.x, _map_rect.size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.05, 0.05, 0.07))
	# Le sol dessiné (bords naturels, falaises) donne les vraies couleurs ; sinon, les tuiles.
	var painter := scene.get_node_or_null("OrganicGround") as GroundPainter
	var painted: Image = painter.cell_colors() if painter else null
	if painted:
		var at := painter.origin_cell - _map_rect.position
		for y in painted.get_height():
			for x in painted.get_width():
				var c := painted.get_pixel(x, y)
				var p := Vector2i(x, y) + at
				if c.a > 0.5 and p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height():
					img.set_pixelv(p, Color(c.r, c.g, c.b))
	else:
		for l in layers:
			for cell in l.get_used_cells():
				var col := _tile_color(l, cell)
				if col.a > 0.0:
					img.set_pixelv(cell - _map_rect.position, col)
	# Les arbres et les décors qui bloquent assombrissent la carte.
	var props := scene.get_node_or_null("Props")
	if props:
		var t := float(Game.TILE_SIZE)
		for p in props.get_children():
			if p is Node2D and p.visible and p.get_node_or_null("Body") != null:
				var c := Vector2i(floori(p.global_position.x / t), floori((p.global_position.y - 1.0) / t)) - _map_rect.position
				if c.x >= 0 and c.y >= 0 and c.x < img.get_width() and c.y < img.get_height():
					img.set_pixelv(c, img.get_pixelv(c).darkened(0.35))
	var avail := Vector2(560, 250)
	_map_scale = minf(avail.x / img.get_width(), avail.y / img.get_height())
	if _map_scale >= 2.0:
		_map_scale = floorf(_map_scale)
	_map_view.texture = ImageTexture.create_from_image(img)
	_map_view.size = Vector2(img.get_size()) * _map_scale
	_map_view.stretch_mode = TextureRect.STRETCH_SCALE
	var frame: Control = _map_view.get_meta("frame")
	frame.custom_minimum_size = _map_view.size
	_map_marker.size = _map_view.size


func _tile_color(layer: TileMapLayer, cell: Vector2i) -> Color:
	var src := layer.get_cell_source_id(cell)
	var coords := layer.get_cell_atlas_coords(cell)
	var key := "%s:%d:%s" % [layer.tile_set.resource_path, src, coords]
	if _color_cache.has(key):
		return _color_cache[key]
	var col := Color(0, 0, 0, 0)
	var atlas := layer.tile_set.get_source(src) as TileSetAtlasSource
	if atlas and atlas.texture:
		var img := atlas.texture.get_image()
		var region := atlas.get_tile_texture_region(coords)
		var sum := Vector3.ZERO
		var n := 0
		for y in range(region.position.y, region.end.y, 2):
			for x in range(region.position.x, region.end.x, 2):
				var c := img.get_pixel(x, y)
				if c.a > 0.5:
					sum += Vector3(c.r, c.g, c.b)
					n += 1
		if n > 0:
			sum /= n
			col = Color(sum.x, sum.y, sum.z)
	_color_cache[key] = col
	return col


func _refresh_map() -> void:
	var scene := get_tree().current_scene
	var zone := "?"
	if scene:
		zone = {"CaveEntrance": "Caverne des Telles-Ombrages", "HordeTunnel": "Galeries des Telles-Ombrages",
			"SolakorLair": "Tanière de Solakor", "WoundedPassage": "Boyau de la crevasse",
			"Sylve": "Sylve des Dracombres", "Dracombra": "Dracombra"}.get(String(scene.name), String(scene.name))
	_map_title.text = "%s    (blanc : vous · rouge : sorties · or : guilde · orange : bâtiments)" % zone
	_map_marker.queue_redraw()


func _draw_markers() -> void:
	var scene := get_tree().current_scene
	if scene == null or _map_view.texture == null:
		return
	var t := float(Game.TILE_SIZE)
	var to_map := func(world: Vector2) -> Vector2:
		return (world / t - Vector2(_map_rect.position)) * _map_scale
	for exit in scene.find_children("*", "LevelExit", true, false):
		_map_marker.draw_circle(to_map.call(exit.global_position), 3.0, Color(1, 0.25, 0.25))
	for b in scene.find_children("*", "Building", true, false):
		_map_marker.draw_rect(Rect2(to_map.call(b.global_position) - Vector2(2, 2), Vector2(4, 4)), Color(1, 0.6, 0.2))
	var guild := scene.get_node_or_null("Guild") as Node2D
	if guild:
		_map_marker.draw_circle(to_map.call(guild.global_position), 4.0, Color(1, 0.85, 0.3))
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		var p: Vector2 = to_map.call(player.global_position)
		_map_marker.draw_circle(p, 4.0, Color.BLACK)
		_map_marker.draw_circle(p, 3.0, Color.WHITE)


# ------------------------------------------------------------------ l'équipement

func _build_gear() -> void:
	var box := HBoxContainer.new()
	box.name = "Équipement"
	box.add_theme_constant_override("separation", 10)
	_tabs.add_child(box)
	# Les six emplacements.
	var slots := VBoxContainer.new()
	slots.custom_minimum_size = Vector2(190, 0)
	slots.add_theme_constant_override("separation", 3)
	box.add_child(slots)
	for slot in Hero.GEAR_SLOTS:
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 11)
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 16)
		b.custom_minimum_size = Vector2(0, 22)
		b.focus_entered.connect(func() -> void: _select_gear(slot))
		b.pressed.connect(func() -> void:
			_select_gear(slot)
			for c in _gear_choices.get_children():
				if c is Button and not c.disabled:
					c.grab_focus()
					return)
		slots.add_child(b)
		_gear_buttons[slot] = b
	# Au milieu : le héros et le total des bonus.
	var mid := VBoxContainer.new()
	mid.custom_minimum_size = Vector2(130, 0)
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(mid)
	_gear_portrait = TextureRect.new()
	_gear_portrait.custom_minimum_size = Vector2(128, 112)
	_gear_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_gear_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_gear_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mid.add_child(_gear_portrait)
	_gear_total = _small("", 10)
	_gear_total.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_gear_total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gear_total.add_theme_color_override("font_color", Color(0.8, 0.78, 0.86))
	mid.add_child(_gear_total)
	# À droite : ce qu'on peut porter à l'emplacement choisi.
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.custom_minimum_size = Vector2(180, 0)
	right.add_theme_constant_override("separation", 3)
	box.add_child(right)
	_gear_title = _small("", 12)
	_gear_title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.45))
	right.add_child(_gear_title)
	_gear_info = _small("", 10)
	_gear_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_gear_info)
	_gear_choices = VBoxContainer.new()
	_gear_choices.add_theme_constant_override("separation", 2)
	right.add_child(_gear_choices)


static func bonus_text(item: ItemData, short: bool = false) -> String:
	var parts: Array[String] = []
	var names: Dictionary = Hero.BONUS_SHORT if short else Hero.BONUS_NAMES
	for k in item.bonus:
		parts.append("+%d %s" % [int(item.bonus[k]), names.get(k, String(k))])
	return ", ".join(parts)


var _blank: Texture2D


## Case vide d'un emplacement (pour aligner le texte).
func _empty_icon() -> Texture2D:
	if _blank == null:
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		for i in 16:
			for j in [0, 15]:
				img.set_pixel(i, j, Color(1, 1, 1, 0.25))
				img.set_pixel(j, i, Color(1, 1, 1, 0.25))
		_blank = ImageTexture.create_from_image(img)
	return _blank


func _class_weapon() -> ItemData:
	var ids := {&"warrior": &"sword", &"archer": &"bow", &"mage": &"staff", &"cleric": &"holy_symbol"}
	return Inventory.item_by_id(ids.get(Hero.current, &"sword"))


func _refresh_gear() -> void:
	for slot in Hero.GEAR_SLOTS:
		var b: Button = _gear_buttons[slot]
		var item := Hero.worn(slot)
		if slot == &"main" and item == null:
			item = _class_weapon()
		b.icon = item.icon if item else _empty_icon()
		b.text = "%s : %s" % [Hero.GEAR_NAMES[slot], item.display_name if item else "—"]
		var active := item == null or slot == &"main" or Hero.can_wear(item)
		b.modulate = Color.WHITE if active else Color(1, 1, 1, 0.5)
	# Portrait : la première image du héros (de face).
	var player := get_tree().get_first_node_in_group("player") as Player
	if player and player.sprite.texture:
		var atlas := AtlasTexture.new()
		atlas.atlas = player.sprite.texture
		var w := player.sprite.texture.get_width() / player.sprite.hframes
		var h := player.sprite.texture.get_height() / player.sprite.vframes
		atlas.region = Rect2(0, 0, w, h)
		_gear_portrait.texture = atlas
	var totals: Array[String] = ["Défense %d" % Hero.defense(), "Parade %d %%" % int(Hero.parry_chance()),
		"Critique %d %%" % int(Hero.crit_chance()), "Endurance %d" % int(Hero.stamina_max())]
	if Hero.uses_mana():
		totals.append("Mana %d" % int(Hero.mana_max()))
	_gear_total.text = "%s · %s\n%s\n%s" % [totals[0], totals[1], totals[2], " · ".join(totals.slice(3))]
	_select_gear(_gear_slot)


func _select_gear(slot: StringName) -> void:
	_gear_slot = slot
	_gear_title.text = Hero.GEAR_NAMES[slot]
	for c in _gear_choices.get_children():
		c.queue_free()
	var worn := Hero.worn(slot)
	var info := ""
	if slot == &"main" and worn == null:
		var w := _class_weapon()
		info = "%s — l'arme du %s.\nL'arme principale suit la classe : changez de classe à la guilde de Dracombra." % [
			w.display_name if w else "?", String(Hero.info()["name"]).to_lower()]
	elif worn:
		info = "Porté : %s\n%s" % [worn.display_name, bonus_text(worn)]
		if not Hero.can_wear(worn):
			info += "\n(sans effet pour un %s)" % String(Hero.info()["name"]).to_lower()
		var off := _small_button("Retirer (ranger dans le sac)")
		off.alignment = HORIZONTAL_ALIGNMENT_LEFT
		off.pressed.connect(func() -> void:
			Hero.take_off(slot)
			_refresh_gear()
			_gear_buttons[slot].grab_focus())
		_gear_choices.add_child(off)
	else:
		info = "Rien de porté."
	var found := 0
	for item in Inventory.get_items():
		if item.slot != slot:
			continue
		found += 1
		var b := _small_button("%s  %s" % [item.display_name, bonus_text(item, true)])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.icon = item.icon
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 16)
		b.disabled = not Hero.can_wear(item)
		if b.disabled:
			b.tooltip_text = "Pas pour cette classe."
		b.pressed.connect(func() -> void:
			Hero.wear(item.id)
			_refresh_gear()
			_gear_buttons[slot].grab_focus())
		_gear_choices.add_child(b)
	if found == 0 and slot != &"main":
		info += "\n\nRien dans le sac pour cet emplacement. Fabriquez-en à l'établi (cuir, bois, toile...)."
	_gear_info.text = info


# ------------------------------------------------------------------ système

func _build_system() -> void:
	var box := VBoxContainer.new()
	box.name = "Système"
	box.add_theme_constant_override("separation", 6)
	_tabs.add_child(box)
	var resume := Button.new()
	resume.text = "Reprendre"
	resume.pressed.connect(close)
	box.add_child(resume)
	_save_button = Button.new()
	_save_button.text = "Sauvegarder"
	_save_button.pressed.connect(func() -> void:
		Save.save_game()
		_save_button.text = "Partie sauvegardée !")
	box.add_child(_save_button)
	var title := Button.new()
	title.text = "Retour au menu principal"
	title.pressed.connect(func() -> void:
		close()
		Transition.change_scene("res://scenes/ui/title_screen.tscn"))
	box.add_child(title)
	var quit := Button.new()
	quit.text = "Quitter le jeu"
	quit.pressed.connect(func() -> void: get_tree().quit())
	box.add_child(quit)
	var help := Label.new()
	help.add_theme_font_size_override("font_size", 11)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.text = "Commandes : ZQSD/flèches se déplacer · J/clic attaquer et récolter · Espace esquiver · E interagir · B construire (à Dracombra) · I sac · M carte · Échap menu.\nLe prologue n'est pas sauvegardé ; la partie l'est automatiquement à chaque changement de zone et chaque nuit."
	box.add_child(help)
