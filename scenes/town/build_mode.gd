class_name BuildMode
extends Node2D
## Mode construction de Dracombra (touche B / bouton Y).
##
## 1. Un menu s'ouvre en haut à gauche : les bâtiments par rubrique, les chemins, et un aperçu
##    du bâtiment choisi (dessin, emprise, paliers, coût).
## 2. On choisit : un damier apparaît et la caméra devient libre. C'est le joueur qui pose, pas
##    le héros : on déplace la vue (ZQSD, flèches, stick) ou on vise à la souris.
## 3. E / clic gauche pose le chantier (ou peint le chemin tant qu'on maintient). Espace / clic
##    droit revient au menu ; B ou Échap quitte le mode.
##
## Chaque bâtiment réserve dès sa pose l'emprise de son dernier palier (BuildingData.size), et la
## guilde ses 4 × 4 cases : on ne peut jamais construire sur un futur agrandissement.

enum State { OFF, MENU, PLACE }

const GOOD := Color(0.45, 1.0, 0.5)
const BAD := Color(1.0, 0.35, 0.35)
const CAMERA_SPEED := 260.0
const ZOOMS: Array[float] = [0.75, 1.0, 1.3333334]

var state: State = State.OFF
## Ce qu'on place : un bâtiment, un chemin (niveau 1 à 3) ou la gomme à chemins.
var data: BuildingData
var path_level := 0
var erasing := false
var demolishing := false
## Bâtiment visé par la démolition.
var target: Dictionary = {}
## Case visée (pour un bâtiment : la case du pied, au bas-centre de l'emprise).
var cell := Vector2i.ZERO
var valid := false
var reason := ""
## Point visé dans le monde (centre de la vue, ou la souris).
var cursor := Vector2.ZERO

var active: bool:
	get:
		return state != State.OFF

var _cam: Camera2D
var _player_cam: Camera2D
var _zoom_index := 1
var _mouse_aim := false
var _painting := false
var _last_painted := Vector2i(-99999, -99999)
var _occupied: Dictionary = {}

var _ghost: Sprite2D
var _ui: CanvasLayer
var _panel: PanelContainer
var _title: Label
var _list: VBoxContainer
var _scroll: ScrollContainer
var _preview: TextureRect
var _info_name: Label
var _info: Label
var _hint: Label
var _entries: Array[Dictionary] = []
var _rows: Array[Button] = []
var _selected := 0


func _ready() -> void:
	z_index = 5
	_ghost = Sprite2D.new()
	_ghost.scale = Vector2(0.5, 0.5)  # dessins HD
	_ghost.centered = false
	_ghost.visible = false
	add_child(_ghost)
	_cam = Camera2D.new()
	_cam.name = "BuildCamera"
	_cam.enabled = false
	add_child(_cam)
	_build_ui()
	Town.changed.connect(_refresh_occupied)


# ------------------------------------------------------------------ entrées / sorties

func _unhandled_input(event: InputEvent) -> void:
	if Choice.is_open or GameMenu.is_open:
		return
	match state:
		State.OFF:
			if event.is_action_pressed("build"):
				var player := _player()
				if player and not player.input_locked and Game.has_flag(&"prologue_done"):
					get_viewport().set_input_as_handled()
					open()
		State.MENU:
			_menu_input(event)
		State.PLACE:
			_place_input(event)


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


## Ouvre le mode construction sur le menu.
func open() -> void:
	if state == State.OFF:
		_enter()
	state = State.MENU
	_ghost.visible = false
	_painting = false
	_fill_menu()
	_panel.visible = true
	_hint.visible = false
	queue_redraw()


## Passe directement au placement d'un bâtiment (aussi utilisé par les tests).
func start(building: BuildingData) -> void:
	if state == State.OFF:
		_enter()
	data = building
	path_level = 0
	erasing = false
	demolishing = false
	_begin_place()


func start_path(level: int) -> void:
	if state == State.OFF:
		_enter()
	data = null
	path_level = level
	erasing = false
	demolishing = false
	_begin_place()


func start_erase() -> void:
	if state == State.OFF:
		_enter()
	data = null
	path_level = 0
	erasing = true
	demolishing = false
	_begin_place()


func start_demolish() -> void:
	if state == State.OFF:
		_enter()
	data = null
	path_level = 0
	erasing = false
	demolishing = true
	_begin_place()


## Quitte complètement le mode construction.
func stop() -> void:
	if state == State.OFF:
		return
	state = State.OFF
	_ghost.visible = false
	_panel.visible = false
	_hint.visible = false
	_painting = false
	Interaction.blocked = false
	var player := _player()
	if player:
		player.input_locked = false
		player.actions_locked = false
	_cam.enabled = false
	_set_hud(true)
	if _player_cam:
		_player_cam.enabled = true
		_player_cam.make_current()
		_player_cam.reset_smoothing()
	queue_redraw()


## Le cadre du héros (en haut à gauche) laisse la place au menu de construction.
func _set_hud(shown: bool) -> void:
	var hud := get_parent().get_node_or_null("HUD") as CanvasLayer
	if hud:
		hud.visible = shown


func _enter() -> void:
	Interaction.blocked = true
	_set_hud(false)
	var player := _player()
	if player:
		player.input_locked = true
		player.actions_locked = true
		player.scripted_direction = Vector2.ZERO
	_player_cam = get_viewport().get_camera_2d()
	_cam.global_position = _player_cam.get_screen_center_position() if _player_cam else (player.global_position if player else Vector2.ZERO)
	if _player_cam:
		_cam.limit_left = _player_cam.limit_left
		_cam.limit_right = _player_cam.limit_right
		_cam.limit_top = _player_cam.limit_top
		_cam.limit_bottom = _player_cam.limit_bottom
		_zoom_index = 0
		for i in ZOOMS.size():
			if absf(ZOOMS[i] - _player_cam.zoom.x) < absf(ZOOMS[_zoom_index] - _player_cam.zoom.x):
				_zoom_index = i
	# On recule un peu la vue pour mieux voir la ville.
	_zoom_index = maxi(0, _zoom_index - 1)
	_cam.zoom = Vector2.ONE * ZOOMS[_zoom_index]
	_cam.enabled = true
	_cam.make_current()
	cursor = _cam.global_position
	_mouse_aim = false
	_refresh_occupied()


func _begin_place() -> void:
	state = State.PLACE
	_panel.visible = false
	_hint.visible = true
	_painting = false
	_last_painted = Vector2i(-99999, -99999)
	if data:
		var tex := data.texture_for(1)
		_ghost.texture = tex
		if tex:
			_ghost.offset = Vector2(-tex.get_width() / 2.0, -tex.get_height())
		_ghost.visible = tex != null
	else:
		_ghost.visible = false
	queue_redraw()


# ------------------------------------------------------------------ le menu

func _menu_input(event: InputEvent) -> void:
	if event.is_action_pressed("build") or event.is_action_pressed("pause") or event.is_action_pressed("dodge") \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		get_viewport().set_input_as_handled()
		stop()
	elif event.is_action_pressed("move_up", true) or event.is_action_pressed("ui_up", true):
		get_viewport().set_input_as_handled()
		_select(_step(-1))
	elif event.is_action_pressed("move_down", true) or event.is_action_pressed("ui_down", true):
		get_viewport().set_input_as_handled()
		_select(_step(1))
	elif event.is_action_pressed("interact") or event.is_action_pressed("attack") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_choose(_selected)


func _step(dir: int) -> int:
	var i := _selected
	for n in _entries.size():
		i = posmod(i + dir, _entries.size())
		if _entries[i]["kind"] != "header":
			return i
	return _selected


func _entries_list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var all: Array[BuildingData] = []
	all.append_array(Town.all_buildings())
	all.sort_custom(func(a, b): return a.tier_required < b.tier_required or (a.tier_required == b.tier_required and a.display_name < b.display_name))
	for cat in BuildingData.CATEGORIES:
		var items: Array[Dictionary] = []
		for b in all:
			if b.category == cat:
				var locked := "" if b.tier_required <= Town.tier or Admin.free_build else "Palier « %s » requis" % Town.tier_name(mini(b.tier_required, Town.TIERS.size() - 1))
				items.append({"kind": "building", "data": b, "title": b.display_name, "locked": locked})
		if not items.is_empty():
			out.append({"kind": "header", "title": BuildingData.CATEGORY_NAMES.get(cat, String(cat))})
			out.append_array(items)
	out.append({"kind": "header", "title": "Chemins"})
	for i in Town.PATHS.size():
		var p: Dictionary = Town.PATHS[i]
		var locked := "" if int(p["tier"]) <= Town.tier or Admin.free_build else "Palier « %s » requis" % Town.tier_name(int(p["tier"]))
		out.append({"kind": "path", "level": i + 1, "title": p["name"], "locked": locked})
	out.append({"kind": "erase", "title": "Effacer un chemin", "locked": ""})
	out.append({"kind": "header", "title": "Outils"})
	out.append({"kind": "demolish", "title": "Démolir un bâtiment", "locked": ""})
	return out


func _fill_menu() -> void:
	var keep: Dictionary = _entries[_selected] if _selected < _entries.size() else {}
	_entries = _entries_list()
	for r in _rows:
		r.queue_free()
	_rows.clear()
	for i in _entries.size():
		var e: Dictionary = _entries[i]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var clear := StyleBoxFlat.new()
		clear.bg_color = Color(0, 0, 0, 0)
		clear.set_content_margin_all(1)
		for st in ["normal", "hover", "pressed", "disabled", "focus"]:
			b.add_theme_stylebox_override(st, clear)
		b.add_theme_font_size_override("font_size", 9)
		b.custom_minimum_size.y = 12
		if e["kind"] == "header":
			b.text = String(e["title"]).to_upper()
			b.disabled = true
			b.add_theme_color_override("font_disabled_color", Color(1.0, 0.82, 0.45))
		else:
			b.text = "  " + e["title"] + ("  (verrouillé)" if e["locked"] != "" else "")
			b.add_theme_color_override("font_color", Color(0.55, 0.52, 0.6) if e["locked"] != "" else Color(0.92, 0.9, 0.95))
			b.mouse_entered.connect(_select.bind(i))
			b.pressed.connect(_choose.bind(i))
		_list.add_child(b)
		_rows.append(b)
	_title.text = "Construction — %s%s" % [Town.tier_name(), " · admin : gratuit" if Admin.free_build else ""]
	var idx := 1
	for i in _entries.size():
		if not keep.is_empty() and _entries[i]["kind"] == keep.get("kind") and _entries[i]["title"] == keep.get("title"):
			idx = i
	_select(idx if _entries[idx]["kind"] != "header" else _step_from(idx))


func _step_from(i: int) -> int:
	_selected = i
	return _step(1)


func _select(i: int) -> void:
	if i < 0 or i >= _entries.size() or _entries[i]["kind"] == "header":
		return
	_selected = i
	for k in _rows.size():
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0.55, 0.45, 0.7, 0.45) if k == i else Color(0, 0, 0, 0)
		st.set_content_margin_all(1)
		_rows[k].add_theme_stylebox_override("normal", st)
		_rows[k].add_theme_stylebox_override("hover", st)
		_rows[k].add_theme_stylebox_override("pressed", st)
	_scroll.ensure_control_visible.call_deferred(_rows[i])
	_show_preview(_entries[i])


func _show_preview(e: Dictionary) -> void:
	var lines: Array[String] = []
	match e["kind"]:
		"building":
			var b: BuildingData = e["data"]
			_preview.texture = b.texture_for(b.max_level())
			_info_name.text = b.display_name
			lines.append("Emprise : %d × %d cases" % [b.size.x, b.size.y])
			if b.max_level() > 1:
				lines.append("Paliers : %s" % " → ".join(b.level_names))
			lines.append("Coût : %s · %d j" % [_cost_with_stock(b.cost), b.build_days])
			lines.append(b.description)
		"path":
			var p: Dictionary = Town.PATHS[int(e["level"]) - 1]
			var path := "res://assets/sprites/town/%s.png" % p["art"]
			_preview.texture = load(path) if ResourceLoader.exists(path) else null
			_info_name.text = p["name"]
			lines.append("Coût : %s par case" % _cost_with_stock(p["cost"]))
			lines.append("Maintenez E (ou le clic) en bougeant pour tracer. Le chemin remplace celui qui était là.")
		"erase":
			_preview.texture = null
			_info_name.text = "Effacer un chemin"
			lines.append("Maintenez E (ou le clic) en bougeant : la pierre revient dans votre sac.")
		"demolish":
			_preview.texture = null
			_info_name.text = "Démolir un bâtiment"
			if Admin.free_build:
				lines.append("Mode admin : le bâtiment visé disparaît tout de suite, sans rien rendre.")
			else:
				lines.append("Visez un bâtiment ou un chantier : après confirmation, ses matériaux et son stock reviennent dans votre sac. Ses travailleurs quittent leur poste.")
	if e.get("locked", "") != "":
		lines.append("Verrouillé : " + e["locked"] + ".")
	_info.text = "\n".join(lines)


## « 8 bois (12), 2 pierre (0) » : coût avec ce qu'on possède entre parenthèses.
func _cost_with_stock(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for id in cost:
		var item := Inventory.item_by_id(id)
		parts.append("%d %s (%d)" % [int(cost[id]), item.display_name.to_lower() if item else String(id), Town.amount_of(id)])
	return ", ".join(parts)


func _choose(i: int) -> void:
	if i < 0 or i >= _entries.size():
		return
	_select(i)
	var e: Dictionary = _entries[i]
	if e["kind"] == "header":
		return
	if e.get("locked", "") != "":
		Narration.say(e["locked"] + ".", 2.0)
		return
	match e["kind"]:
		"building":
			start(e["data"])
		"path":
			start_path(int(e["level"]))
		"erase":
			start_erase()
		"demolish":
			start_demolish()


# ------------------------------------------------------------------ le placement

func _place_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_aim = true
	elif event is InputEventMouseButton and event.pressed:
		_mouse_aim = true
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				get_viewport().set_input_as_handled()
				_press()
			MOUSE_BUTTON_RIGHT:
				get_viewport().set_input_as_handled()
				open()
			MOUSE_BUTTON_WHEEL_UP:
				_set_zoom(_zoom_index + 1)
			MOUSE_BUTTON_WHEEL_DOWN:
				_set_zoom(_zoom_index - 1)
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_painting = false
	elif event.is_action_pressed("build") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		stop()
	elif event.is_action_pressed("dodge"):
		get_viewport().set_input_as_handled()
		open()
	elif event.is_action_pressed("interact") or event.is_action_pressed("attack"):
		get_viewport().set_input_as_handled()
		_press()
	elif event.is_action_released("interact") or event.is_action_released("attack"):
		_painting = false
	elif event.is_action_pressed("map"):
		get_viewport().set_input_as_handled()
		_set_zoom(_zoom_index - 1 if _zoom_index > 0 else ZOOMS.size() - 1)


func _set_zoom(i: int) -> void:
	_zoom_index = clampi(i, 0, ZOOMS.size() - 1)
	_cam.zoom = Vector2.ONE * ZOOMS[_zoom_index]


func _press() -> void:
	if demolishing:
		_demolish()
	elif data:
		_confirm()
	else:
		_painting = true
		_last_painted = Vector2i(-99999, -99999)
		_paint()


func _process(delta: float) -> void:
	if state == State.OFF:
		return
	if state == State.PLACE:
		var move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if move != Vector2.ZERO:
			_mouse_aim = false
			_cam.global_position += move * CAMERA_SPEED * delta / _cam.zoom.x
			_clamp_camera()
	if state != State.PLACE:
		queue_redraw()
		return
	cursor = get_global_mouse_position() if _mouse_aim else _cam.get_screen_center_position()
	var t := float(Game.TILE_SIZE)
	if data:
		# La case visée est le centre de l'emprise.
		var top_left := Vector2i(roundi(cursor.x / t - data.size.x / 2.0), roundi(cursor.y / t - data.size.y / 2.0))
		cell = Vector2i(top_left.x + (data.size.x - 1) / 2, top_left.y + data.size.y - 1)
		var rect := Building.footprint_rect(data, cell)
		_ghost.position = Vector2(rect.get_center().x, rect.end.y)
		_check_building()
		_ghost.modulate = Color(GOOD, 0.8) if valid else Color(BAD, 0.7)
		_hint.text = ("%s — E / clic : poser · Espace : menu · B : quitter" % data.display_name) if valid else reason
	elif demolishing:
		cell = Vector2i(floori(cursor.x / t), floori(cursor.y / t))
		target = Town.site_at(cell)
		valid = not target.is_empty()
		reason = "Visez un bâtiment ou un chantier."
		_hint.text = ("Démolir : %s — E / clic · Espace : menu" % Town.site_name(target)) if valid else reason
	else:
		cell = Vector2i(floori(cursor.x / t), floori(cursor.y / t))
		_check_path()
		if _painting:
			_paint()
		var what := "Effacer un chemin" if erasing else String(Town.PATHS[path_level - 1]["name"])
		_hint.text = ("%s — maintenez E / clic pour tracer · Espace : menu" % what) if valid else reason
	queue_redraw()


func _clamp_camera() -> void:
	var half := get_viewport_rect().size / (2.0 * _cam.zoom)
	var p := _cam.global_position
	p.x = clampf(p.x, _cam.limit_left + half.x, maxf(_cam.limit_left + half.x, _cam.limit_right - half.x))
	p.y = clampf(p.y, _cam.limit_top + half.y, maxf(_cam.limit_top + half.y, _cam.limit_bottom - half.y))
	_cam.global_position = p


func _refresh_occupied() -> void:
	_occupied = Town.occupied_cells()


## Une case est-elle libre pour construire ? "" si oui, sinon la raison.
func _cell_block(c: Vector2i) -> String:
	if not Town.is_unlocked(c) and not Admin.free_build:
		return "Quartier encore en ruines : il faut une guilde de palier « %s »." % Town.tier_name(Town.district_of(c))
	if c in Town.guild_cells():
		return "Cet espace est réservé à la guilde et à ses agrandissements."
	if _occupied.has(c):
		return "Un bâtiment (ou son futur agrandissement) occupe déjà cette place."
	return ""


## Décombres, arbres, eau... dans un rectangle du monde ?
func _obstructed(rect: Rect2) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size - Vector2(2, 2)
	query.shape = shape
	query.transform = Transform2D(0.0, rect.get_center())
	query.collision_mask = 1 | 4
	query.collide_with_areas = false
	return not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func _check_building() -> void:
	valid = false
	for c in Town.footprint_cells(data, cell):
		var why := _cell_block(c)
		if why != "":
			reason = why
			return
	if _obstructed(Building.footprint_rect(data, cell)):
		reason = "Place occupée : déblayez d'abord (décombres, arbres...)."
		return
	valid = true


func _check_path() -> void:
	valid = false
	if not erasing:
		var p: Dictionary = Town.PATHS[path_level - 1]
		var why := _cell_block(cell)
		if why != "":
			reason = why
			return
		var t := float(Game.TILE_SIZE)
		if _obstructed(Rect2(Vector2(cell) * t, Vector2(t, t))):
			reason = "Place occupée : déblayez d'abord (décombres, arbres...)."
			return
		if Town.path_level(cell) == path_level:
			reason = "%s — déjà tracé ici." % p["name"]
			valid = true  # rien à faire, mais pas une erreur
			return
		for id in p["cost"]:
			if Town.amount_of(id) < int(p["cost"][id]) and not Admin.free_build:
				reason = "Pas assez de pierre (%d par case)." % int(p["cost"][id])
				return
	elif Town.path_level(cell) == 0:
		reason = "Pas de chemin ici."
		valid = true
		return
	valid = true


func _paint() -> void:
	if cell == _last_painted:
		return
	_last_painted = cell
	_check_path()
	if not valid:
		return
	if erasing:
		Town.remove_path(cell, not Admin.free_build)
		return
	if Town.path_level(cell) == path_level:
		return
	if Town.path_level(cell) > 0:
		Town.remove_path(cell, not Admin.free_build)
	var cost: Dictionary = Town.PATHS[path_level - 1]["cost"]
	if not Admin.free_build:
		for id in cost:
			Town.consume(id, int(cost[id]))
	Town.set_path(cell, path_level)


func _demolish() -> void:
	if target.is_empty():
		Narration.say(reason, 1.6)
		return
	var record := target
	var nm := Town.site_name(record)
	if Admin.free_build:
		Town.demolish(record, false)
		Narration.say("Démoli (admin) : %s." % nm, 1.4)
		return
	var back := Town.site_refund(record)
	var parts := {}
	for k in back:
		parts[StringName(k)] = int(back[k])
	var body := "Démolir %s ?\n%s" % [nm, ("Vous récupérez : %s." % Building.cost_text(parts)) if not parts.is_empty() else "Rien à récupérer."]
	if await Choice.ask("Démolir", body, ["Démolir", "Annuler"]) != 0:
		return
	Town.demolish(record, true)
	Narration.say("%s démoli." % nm, 1.8)


func _confirm() -> void:
	if not valid:
		Narration.say(reason, 2.0)
		return
	var rect := Building.footprint_rect(data, cell)
	var record := Town.add_site(data.id, cell)
	if Admin.free_build:
		record["built"] = true
		Town.changed.emit()
	# Le héros ne doit pas rester coincé dans le chantier.
	var player := _player()
	if player and rect.grow(4.0).has_point(player.global_position):
		player.global_position = Vector2(player.global_position.x, rect.end.y + 10.0)
	if Admin.free_build:
		Narration.say("Construit (admin) : %s." % data.level_name(1), 1.6)
	else:
		Narration.say("Chantier posé : %s. Déposez-y les matériaux (E)." % data.display_name, 2.6)
	open()


# ------------------------------------------------------------------ dessin du damier

func _draw() -> void:
	if state == State.OFF:
		return
	var t := float(Game.TILE_SIZE)
	var center := _cam.get_screen_center_position()
	var half := get_viewport_rect().size / (2.0 * _cam.zoom) + Vector2(t, t)
	var c0 := Vector2i(floori((center.x - half.x) / t), floori((center.y - half.y) / t))
	var c1 := Vector2i(ceili((center.x + half.x) / t), ceili((center.y + half.y) / t))
	for y in range(c0.y, c1.y + 1):
		for x in range(c0.x, c1.x + 1):
			var c := Vector2i(x, y)
			var r := Rect2(Vector2(c) * t, Vector2(t, t))
			if not Town.is_unlocked(c):
				draw_rect(r, Color(0.8, 0.15, 0.15, 0.16))
			elif _occupied.has(c):
				draw_rect(r, Color(1.0, 0.6, 0.2, 0.2))
			elif (x + y) % 2 == 0:
				draw_rect(r, Color(1, 1, 1, 0.06))
	var line := Color(1, 1, 1, 0.14)
	for x in range(c0.x, c1.x + 1):
		draw_line(Vector2(x * t, c0.y * t), Vector2(x * t, (c1.y + 1) * t), line, 1.0)
	for y in range(c0.y, c1.y + 1):
		draw_line(Vector2(c0.x * t, y * t), Vector2((c1.x + 1) * t, y * t), line, 1.0)
	# Contour de la zone constructible du palier actuel.
	var rad: float = Town.TIERS[Town.tier]["radius"]
	if rad < 500.0:
		var mid := (Vector2(Town.center) + Vector2(0.5, 0.5)) * t
		var pts := PackedVector2Array()
		for i in 97:
			var a := TAU * i / 96.0
			pts.append(mid + Vector2(cos(a) * rad * t, sin(a) * rad * t / Town.DISTRICT_ASPECT))
		draw_polyline(pts, Color(1.0, 0.9, 0.5, 0.7), 1.0)
	if state != State.PLACE:
		return
	var col := GOOD if valid else BAD
	if demolishing:
		if not target.is_empty():
			var rect := Building.footprint_rect(Town.building(StringName(target["id"])), Town.site_cell(target))
			draw_rect(rect, Color(BAD, 0.35))
			draw_rect(rect, Color(BAD, 0.95), false, 1.0)
		else:
			draw_rect(Rect2(Vector2(cell) * t, Vector2(t, t)), Color(1, 1, 1, 0.6), false, 1.0)
	elif data:
		var rect := Building.footprint_rect(data, cell)
		draw_rect(rect, Color(col, 0.28))
		draw_rect(rect, Color(col, 0.95), false, 1.0)
	else:
		var r := Rect2(Vector2(cell) * t, Vector2(t, t))
		draw_rect(r, Color(col, 0.3))
		draw_rect(r, Color(col, 0.95), false, 1.0)


# ------------------------------------------------------------------ interface

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 15
	add_child(_ui)
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.1, 0.92)
	style.border_color = Color(0.55, 0.45, 0.7)
	style.set_border_width_all(1)
	style.set_content_margin_all(6)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.position = Vector2(6, 6)
	_panel.custom_minimum_size = Vector2(200, 0)
	_panel.visible = false
	_ui.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	_panel.add_child(box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 11)
	_title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.45))
	box.add_child(_title)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(188, 112)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 0)
	_scroll.add_child(_list)
	var sep := HSeparator.new()
	box.add_child(sep)
	_preview = TextureRect.new()
	_preview.custom_minimum_size = Vector2(188, 54)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	box.add_child(_preview)
	_info_name = Label.new()
	_info_name.add_theme_font_size_override("font_size", 11)
	_info_name.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
	box.add_child(_info_name)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(188, 0)
	_info.add_theme_font_size_override("font_size", 8)
	_info.add_theme_constant_override("line_spacing", -2)
	box.add_child(_info)
	var footer := Label.new()
	footer.text = "↑↓ choisir · E / clic : placer · B / Échap : quitter"
	footer.add_theme_font_size_override("font_size", 8)
	footer.add_theme_color_override("font_color", Color(0.7, 0.68, 0.78))
	box.add_child(footer)
	_hint = Label.new()
	_hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_hint.offset_top = 6
	_hint.offset_left = 60
	_hint.offset_right = -120  # la mini-carte est en haut à droite
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 10)
	_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	_hint.add_theme_constant_override("outline_size", 4)
	_hint.visible = false
	_ui.add_child(_hint)
