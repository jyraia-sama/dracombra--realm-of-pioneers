extends CanvasLayer
## Menu du jeu (Échap / Start) : Sac, Personnage, Carte, Système.
## Raccourcis : I (ou LB) ouvre le sac, M (ou Select) ouvre la carte.
## Le jeu est en pause tant que le menu est ouvert.

const TABS := ["Sac", "Personnage", "Carte", "Système"]

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
	_build_map()
	_build_system()
	_tabs.tab_changed.connect(func(_i: int) -> void: _refresh())
	_root.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if Choice.is_open:
		return
	if is_open:
		if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel") \
				or (event.is_action_pressed("bag") and _tabs.current_tab == 0) \
				or (event.is_action_pressed("map") and _tabs.current_tab == 2):
			get_viewport().set_input_as_handled()
			close()
		elif event.is_action_pressed("move_left") and not _bag_list.has_focus():
			_tabs.current_tab = posmod(_tabs.current_tab - 1, TABS.size())
		elif event.is_action_pressed("move_right") and not _bag_list.has_focus():
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
		tab = 2
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
		2:
			_refresh_map()
		3:
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
	_bag_list.item_selected.connect(_on_bag_selected)
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
	_bag_info.text = text
	_bag_use.visible = item.use_heal > 0


func _on_bag_use() -> void:
	var sel := _bag_list.get_selected_items()
	if sel.is_empty():
		return
	var item := Inventory.item_by_id(_bag_ids[sel[0]])
	var player := get_tree().get_first_node_in_group("player") as Player
	if item.use_heal > 0 and player and player.health.current_health < player.health.max_health:
		Inventory.remove_item(item, 1)
		player.health.heal(item.use_heal)
	var keep := sel[0]
	_refresh_bag()
	if keep < _bag_ids.size():
		_bag_list.select(keep)
		_on_bag_selected(keep)


# ------------------------------------------------------------------ la fiche du personnage

func _build_sheet() -> void:
	var box := VBoxContainer.new()
	box.name = "Personnage"
	_tabs.add_child(box)
	_sheet = RichTextLabel.new()
	_sheet.bbcode_enabled = true
	_sheet.fit_content = false
	_sheet.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sheet.add_theme_font_size_override("normal_font_size", 12)
	_sheet.add_theme_font_size_override("bold_font_size", 12)
	box.add_child(_sheet)
	_class_box = HBoxContainer.new()
	box.add_child(_class_box)


func _refresh_sheet() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	var lines: Array[String] = []
	lines.append("[b]%s[/b] — ancien capitaine d'Elysia, fondateur de la guilde." % Hero.hero_name)
	if player:
		lines.append("PV : %d / %d    Dégâts : %d" % [player.health.current_health, player.health.max_health, Hero.damage()])
	lines.append("Jour %d    Dracombra : %s (%s)" % [Game.day, Town.tier_name(), Town.guild_name()])
	lines.append("")
	lines.append("[b]Classes[/b] (chacune a son propre niveau) :")
	for id in Hero.ORDER:
		var c: Dictionary = Hero.CLASSES[id]
		if Hero.unlocked.has(id):
			var mark := "  ◄ actuelle" if id == Hero.current else ""
			lines.append("• %s — niveau %d (%d / %d XP) — %s%s" % [c["name"], Hero.level(id), int(Hero.xp.get(id, 0)), Hero.xp_to_next(Hero.level(id)), c["role"], mark])
		else:
			var item := Inventory.item_by_id(c["item"])
			var recipe := ""
			for r in Crafting.RECIPES:
				if r["out"] == c["item"]:
					recipe = Building.cost_text(r["in"])
			lines.append("• [color=#8a8494]%s — à débloquer : %s (établi : %s)[/color]" % [c["name"], item.display_name if item else "?", recipe])
	lines.append("")
	lines.append("On change de classe seulement à Dracombra (ici, ou au feu de camp de la guilde).")
	_sheet.text = "\n".join(lines)
	for child in _class_box.get_children():
		child.queue_free()
	var can_switch := Hero.can_switch_here()
	for id in Hero.ORDER:
		if not Hero.unlocked.has(id):
			continue
		var b := Button.new()
		b.text = Hero.CLASSES[id]["name"]
		b.disabled = not can_switch or id == Hero.current
		b.pressed.connect(func() -> void:
			Hero.switch_to(id)
			_refresh_sheet())
		_class_box.add_child(b)


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
	_map_scale = maxf(1.0, floorf(minf(avail.x / img.get_width(), avail.y / img.get_height())))
	if img.get_width() * _map_scale > avail.x:
		_map_scale = minf(avail.x / img.get_width(), avail.y / img.get_height())
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
