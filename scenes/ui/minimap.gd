class_name Minimap
extends Control
## Mini-carte en haut à droite : les environs du héros, centrés sur lui.
## Blanc : vous · rouge : monstres · violet : escaliers · or : guilde · orange : bâtiments.
## Respecte le brouillard du donjon (LevelMap.hidden_rects).

## Taille à l'écran (pixels du viewport 640 × 360) et pixels par case.
const SIZE := Vector2(112, 70)
const ZOOM := 2.0
const BG := Color(0.05, 0.05, 0.07)

var _tex: ImageTexture
var _rect := Rect2i()
var _scene: Node
var _retry := 0.0
var _hidden: Array = []


func _ready() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	var scene := get_tree().current_scene
	if scene != _scene:
		_scene = scene
		_tex = null
		_retry = 0.0
	# Le sol dessiné n'est prêt qu'après quelques images : on reconstruit tant qu'il manque.
	_retry -= delta
	if (_tex == null or not _painted) and _retry <= 0.0:
		_rebuild()
		_retry = 1.0
	_hidden = LevelMap.hidden_rects(_scene)
	visible = _tex != null and Game.has_flag(&"prologue_done")
	queue_redraw()


var _painted := false


func _rebuild() -> void:
	var data := LevelMap.build(_scene)
	if data.is_empty():
		_tex = null
		return
	_rect = data["rect"]
	_painted = data["painted"]
	_tex = ImageTexture.create_from_image(data["image"])


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), BG)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if _tex == null or player == null:
		return
	var t := float(Game.TILE_SIZE)
	var center_cell := player.global_position / t
	# Coin haut-gauche de la carte (en pixels de la mini-carte) pour centrer le héros.
	var origin := SIZE / 2.0 - (center_cell - Vector2(_rect.position)) * ZOOM
	origin = origin.round()
	draw_texture_rect(_tex, Rect2(origin, Vector2(_tex.get_size()) * ZOOM), false)
	var to_map := func(world: Vector2) -> Vector2:
		return origin + (world / t - Vector2(_rect.position)) * ZOOM
	for r in _hidden:
		var rr := r as Rect2i
		draw_rect(Rect2(origin + Vector2(rr.position - _rect.position) * ZOOM, Vector2(rr.size) * ZOOM), BG)
	var scene := _scene
	if scene:
		for b in scene.find_children("*", "Building", true, false):
			draw_rect(Rect2((to_map.call(b.global_position) as Vector2) - Vector2(1.5, 1.5), Vector2(3, 3)), Color(1, 0.6, 0.2))
		var guild := scene.get_node_or_null("Guild") as Node2D
		if guild:
			draw_circle(to_map.call(guild.global_position), 2.5, Color(1, 0.85, 0.3))
		for s in scene.find_children("*", "DungeonStairs", true, false):
			if _is_shown(s.global_position):
				draw_rect(Rect2((to_map.call(s.global_position) as Vector2) - Vector2(2, 2), Vector2(4, 4)), Color(0.75, 0.55, 1.0))
		for exit in scene.find_children("*", "LevelExit", true, false):
			draw_circle(to_map.call(exit.global_position), 2.0, Color(1, 0.25, 0.25))
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Node2D
		if en and _is_shown(en.global_position):
			var h := en.get_node_or_null("Health") as HealthComponent
			if h == null or not h.is_dead():
				draw_rect(Rect2((to_map.call(en.global_position) as Vector2) - Vector2(1, 1), Vector2(2, 2)), Color(1, 0.3, 0.3))
	var p := (to_map.call(player.global_position) as Vector2).round()
	draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), Color.BLACK)
	draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color.WHITE)
	# Cadre.
	draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0.55, 0.45, 0.7), false, 1.0)


func _is_shown(world: Vector2) -> bool:
	var cell := Vector2i((world / float(Game.TILE_SIZE)).floor())
	for r in _hidden:
		if (r as Rect2i).has_point(cell):
			return false
	return true
