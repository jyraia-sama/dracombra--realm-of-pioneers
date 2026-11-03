class_name PathLayer
extends Node2D
## Dessine les chemins en pierre de Town.paths, juste au-dessus du sol de Dracombra.
##
## Chaque revêtement est une planche de tuiles répétables de 32 × 32 px HD posées côte à côte
## (assets/sprites/town/path_gravel.png...). La variante de chaque case est tirée de sa position,
## pour éviter l'effet de grille. Les bords sans voisin sont grignotés par de l'herbe : le chemin
## ne fait pas de « marches » carrées. (Un vrai shader de bords, comme le sol, viendra plus tard.)

const TILE_HD := 32
const EDGE := Color(0.24, 0.33, 0.17, 1.0)
const EDGE_DARK := Color(0.16, 0.2, 0.12, 0.55)

var _tex: Array[Texture2D] = []


static func apply(level: Node2D, ground: Node2D) -> PathLayer:
	var layer := PathLayer.new()
	layer.name = "Paths"
	layer.z_index = ground.z_index
	layer.z_as_relative = ground.z_as_relative
	level.add_child(layer)
	return layer


func _ready() -> void:
	for p in Town.PATHS:
		var path := "res://assets/sprites/town/%s.png" % p["art"]
		_tex.append(load(path) if ResourceLoader.exists(path) else null)
	Town.paths_changed.connect(queue_redraw)
	queue_redraw()


static func _hash(c: Vector2i) -> int:
	return absi((c.x * 73856093) ^ (c.y * 19349663))


func _draw() -> void:
	var t := float(Game.TILE_SIZE)
	for c: Vector2i in Town.paths:
		var level := int(Town.paths[c])
		var tex: Texture2D = _tex[level - 1] if level - 1 < _tex.size() else null
		var rect := Rect2(Vector2(c) * t, Vector2(t, t))
		if tex:
			var variants := maxi(1, tex.get_width() / TILE_HD)
			var v := _hash(c) % variants
			draw_texture_rect_region(tex, rect, Rect2(v * TILE_HD, 0, TILE_HD, TILE_HD))
		else:
			draw_rect(rect, Color(0.6, 0.58, 0.52))
	# Bords : là où il n'y a pas de chemin voisin, quelques pixels d'herbe mordent le bord.
	for c: Vector2i in Town.paths:
		var o := Vector2(c) * t
		var h := _hash(c)
		for side in 4:
			var dir: Vector2i = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT][side]
			if Town.paths.has(c + dir):
				continue
			for i in int(t):
				var bite := 1 + int(((h >> (i % 16)) ^ (i * 7 + side)) % 3 == 0)
				var p: Vector2
				var s: Vector2
				match side:
					0: p = o + Vector2(i, 0); s = Vector2(1, bite)
					1: p = o + Vector2(i, t - bite); s = Vector2(1, bite)
					2: p = o + Vector2(0, i); s = Vector2(bite, 1)
					_: p = o + Vector2(t - bite, i); s = Vector2(bite, 1)
				draw_rect(Rect2(p, s), EDGE)
				# Une ligne d'ombre juste à l'intérieur, pour décoller le chemin de l'herbe.
				var inner: Vector2
				match side:
					0: inner = p + Vector2(0, bite)
					1: inner = p - Vector2(0, 1)
					2: inner = p + Vector2(bite, 0)
					_: inner = p - Vector2(1, 0)
				draw_rect(Rect2(inner, Vector2(1, 1)), EDGE_DARK)
