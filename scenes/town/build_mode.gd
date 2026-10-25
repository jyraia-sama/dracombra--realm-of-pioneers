class_name BuildMode
extends Node2D
## Mode construction (touche B / bouton Y) : on choisit un bâtiment, un aperçu le suit
## devant le héros sur la grille, vert si la place est libre, rouge sinon.
## « Interagir » pose le chantier, « Esquive » ou B annule.

const GOOD := Color(0.5, 1.0, 0.55, 0.75)
const BAD := Color(1.0, 0.4, 0.4, 0.75)

var active := false
var data: BuildingData
var cell := Vector2i.ZERO
var valid := false
var reason := ""

var _ghost: Sprite2D
var _hint: Label
var _hint_layer: CanvasLayer


func _ready() -> void:
	z_index = 5
	_ghost = Sprite2D.new()
	_ghost.scale = Vector2(0.5, 0.5)  # dessins HD
	_ghost.centered = false
	_ghost.visible = false
	add_child(_ghost)
	_hint_layer = CanvasLayer.new()
	_hint_layer.layer = 15
	add_child(_hint_layer)
	_hint = Label.new()
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_hint.position.y = 26
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 12)
	_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	_hint.add_theme_constant_override("outline_size", 4)
	_hint.visible = false
	_hint_layer.add_child(_hint)


func _unhandled_input(event: InputEvent) -> void:
	if Choice.is_open:
		return
	var player := _player()
	if player == null:
		return
	if not active and event.is_action_pressed("build") and not player.input_locked and Game.has_flag(&"prologue_done"):
		get_viewport().set_input_as_handled()
		_open_menu()
	elif active and (event.is_action_pressed("build") or event.is_action_pressed("dodge") or event.is_action_pressed("pause")):
		get_viewport().set_input_as_handled()
		stop()
	elif active and (event.is_action_pressed("interact") or event.is_action_pressed("attack")):
		get_viewport().set_input_as_handled()
		_confirm()


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


func _open_menu() -> void:
	var list := Town.available()
	var options: Array[String] = []
	for b in list:
		options.append("%s — %s (%d j)" % [b.display_name, Building.cost_text(b.cost), b.build_days])
	options.append("Fermer")
	var body := "Palier : %s. Choisissez un bâtiment, puis placez-le devant vous." % Town.tier_name()
	var choice := await Choice.ask("Construire", body, options)
	if choice >= 0 and choice < list.size():
		start(list[choice])


func start(building: BuildingData) -> void:
	data = building
	active = true
	Interaction.blocked = true
	var player := _player()
	if player:
		player.actions_locked = true
	_ghost.texture = data.texture
	_ghost.offset = Vector2(-data.texture.get_width() / 2.0, -data.texture.get_height())
	_ghost.visible = true
	_hint.visible = true
	queue_redraw()


func stop() -> void:
	active = false
	_ghost.visible = false
	_hint.visible = false
	Interaction.blocked = false
	var player := _player()
	if player:
		player.actions_locked = false
	queue_redraw()


func _process(_delta: float) -> void:
	if not active:
		return
	var player := _player()
	if player == null:
		return
	# L'aperçu se place deux cases devant le héros.
	var t := float(Game.TILE_SIZE)
	var ahead := player.global_position + player.facing.normalized() * t * (1.5 + data.size.y * 0.5)
	cell = Vector2i(floori(ahead.x / t), floori((ahead.y - 1.0) / t))
	var rect := Building.footprint_rect(data, cell)
	_ghost.position = Vector2(rect.get_center().x, rect.end.y)
	_check(rect, player)
	_ghost.modulate = GOOD if valid else BAD
	_hint.text = ("%s — E : construire, Espace : annuler" % data.display_name) if valid else reason
	queue_redraw()


func _check(rect: Rect2, player: Player) -> void:
	valid = false
	var t := float(Game.TILE_SIZE)
	for y in data.size.y:
		for x in data.size.x:
			var c := Vector2i(floori(rect.position.x / t) + x, floori(rect.position.y / t) + y)
			if not Town.is_unlocked(c):
				reason = "Quartier encore en ruines : il faut une guilde de palier « %s »." % Town.tier_name(Town.district_of(c))
				return
	if rect.grow(2.0).has_point(player.global_position):
		reason = "Reculez un peu."
		return
	# Rien ne doit gêner : décombres, arbres, autres bâtiments, eau...
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size - Vector2(2, 2)
	query.shape = shape
	query.transform = Transform2D(0.0, rect.get_center())
	query.collision_mask = 1 | 4
	query.collide_with_areas = false
	if not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
		reason = "Place occupée : déblayez d'abord (décombres, arbres...)."
		return
	var guild := get_tree().get_first_node_in_group("guild") as Guild
	if guild and rect.intersects(guild.reserved_rect()):
		reason = "Cet espace est réservé aux agrandissements de la guilde."
		return
	valid = true


func _confirm() -> void:
	if not valid:
		Narration.say(reason, 2.0)
		return
	Town.add_site(data.id, cell)
	Narration.say("Chantier posé : %s. Déposez-y les matériaux (E)." % data.display_name, 2.6)
	stop()


func _draw() -> void:
	if not active:
		return
	# Contour de la zone constructible du palier actuel.
	var t := float(Game.TILE_SIZE)
	var r: float = Town.TIERS[Town.tier]["radius"]
	if r > 500.0:
		return
	var c := (Vector2(Town.center) + Vector2(0.5, 0.5)) * t
	var pts := PackedVector2Array()
	for i in 97:
		var a := TAU * i / 96.0
		pts.append(c + Vector2(cos(a) * r * t, sin(a) * r * t / Town.DISTRICT_ASPECT))
	draw_polyline(pts, Color(1.0, 0.9, 0.5, 0.6), 1.0)
