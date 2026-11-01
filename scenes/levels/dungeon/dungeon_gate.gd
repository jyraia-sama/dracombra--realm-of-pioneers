class_name DungeonGate
extends StaticBody2D
## Herse d'éclats d'obsidienne qui ferme un passage pendant un combat.
## Dessinée par le code (asset PROVISOIRE au sens de REGLES_ASSETS.md : pas d'image).
## Les éclats jaillissent du sol à la fermeture et s'y enfoncent à l'ouverture.

## Cases fermées (coordonnées de tuiles) et sens du passage (pour l'orientation).
var cells: Array[Vector2i] = []
var horizontal := true  # true : la herse barre un passage vertical (porte en haut ou en bas)

var _rise := 0.0  # 0 = sous terre, 1 = dressée
var _shards: Array[Dictionary] = []
var _shape: CollisionShape2D


func setup(door_cells: Array[Vector2i], dir: Vector2i) -> void:
	cells = door_cells
	horizontal = dir.y != 0
	collision_layer = 1
	collision_mask = 0
	var t := float(Game.TILE_SIZE)
	var first := Vector2(cells[0]) * t
	var last := Vector2(cells[cells.size() - 1]) * t
	var top_left := Vector2(minf(first.x, last.x), minf(first.y, last.y))
	var size := (Vector2(absf(last.x - first.x), absf(last.y - first.y)) + Vector2(t, t))
	position = top_left + Vector2(size.x / 2.0, size.y)  # origine au pied, pour le tri en y
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	_shape.position = Vector2(0, -size.y / 2.0)
	_shape.disabled = true
	add_child(_shape)
	# Éclats : rangée le long de la herse, tailles variées.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(cells[0])
	var count := int((size.x if horizontal else size.y) / 5.0)
	for i in count:
		var along := (float(i) + 0.5) / count
		var p := Vector2(lerpf(-size.x / 2.0, size.x / 2.0, along), 0.0) if horizontal \
			else Vector2(rng.randf_range(-3.0, 3.0), lerpf(-size.y, 0.0, along))
		_shards.append({"pos": p.round(), "h": rng.randf_range(10.0, 20.0), "w": rng.randf_range(3.0, 5.0),
			"delay": rng.randf_range(0.0, 0.25), "tone": rng.randi() % 3})
	_shards.sort_custom(func(a, b): return a["pos"].y < b["pos"].y)


func close() -> void:
	_shape.set_deferred("disabled", false)
	var tween := create_tween()
	tween.tween_method(_set_rise, _rise, 1.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	PixelBurst.spawn(self, global_position, PixelBurst.STONE, Vector2.ZERO, 1.5)
	PixelBurst.spawn(self, global_position, PixelBurst.DUST, Vector2.ZERO, 3.0)


func open() -> void:
	var tween := create_tween()
	tween.tween_method(_set_rise, _rise, 0.0, 0.5).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void: _shape.set_deferred("disabled", true))
	PixelBurst.spawn(self, global_position, PixelBurst.DUST, Vector2.ZERO, 3.0)


func _set_rise(v: float) -> void:
	_rise = v
	queue_redraw()


func _draw() -> void:
	if _rise <= 0.01:
		return
	var tones := [Color("2a2233"), Color("3b3048"), Color("54456a")]
	var glow := Color("b48cff")
	for s in _shards:
		var r := clampf((_rise - s["delay"]) / maxf(0.01, 1.0 - s["delay"]), 0.0, 1.0)
		if r <= 0.0:
			continue
		var h: float = roundf(s["h"] * r)
		var w: float = s["w"]
		var base: Vector2 = s["pos"]
		var pts := PackedVector2Array([base + Vector2(-w, 0), base + Vector2(0, -h), base + Vector2(w, 0)])
		draw_colored_polygon(pts, Color("140f1a"))
		var inner := PackedVector2Array([base + Vector2(-w + 1, 0), base + Vector2(0, -h + 2), base + Vector2(w - 1, 0)])
		draw_colored_polygon(inner, tones[s["tone"]])
		# Reflet violet sur l'arête.
		draw_line(base + Vector2(-1, -2), base + Vector2(0, -h + 3), glow * Color(1, 1, 1, 0.8), 1.0)
