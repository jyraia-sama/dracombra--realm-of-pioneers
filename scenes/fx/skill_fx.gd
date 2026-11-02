class_name SkillFx
extends Node2D
## Effet visuel sans dégâts : un anneau qui s'élargit puis s'efface (soin, bénédiction,
## cri de guerre, téléportation...). Provisoire, en attendant des effets en pixel art.

var radius := 12.0
var color := Color.WHITE
var duration := 0.45
var _time := 0.0
## Éclair : points de la ligne brisée (vide = anneau).
var _bolt := PackedVector2Array()


static func ring(parent: Node, at: Vector2, radius_px: float, col: Color, time: float = 0.45) -> SkillFx:
	var fx := SkillFx.new()
	fx.position = at
	fx.radius = radius_px
	fx.color = col
	fx.duration = time
	fx.z_index = 6
	parent.add_child(fx)
	return fx


## Éclair en zigzag entre deux points (chaîne d'éclairs).
static func bolt(parent: Node, from: Vector2, to: Vector2, col: Color, time: float = 0.3) -> SkillFx:
	var fx := SkillFx.new()
	fx.color = col
	fx.duration = time
	fx.z_index = 7
	var pts := PackedVector2Array([from])
	var steps := maxi(3, int(from.distance_to(to) / 10.0))
	var side := (to - from).orthogonal().normalized()
	for i in range(1, steps):
		pts.append(from.lerp(to, float(i) / steps) + side * randf_range(-5.0, 5.0))
	pts.append(to)
	fx._bolt = pts
	parent.add_child(fx)
	return fx


func _process(delta: float) -> void:
	_time += delta
	if _time >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var p := _time / duration
	if not _bolt.is_empty():
		draw_polyline(_bolt, Color(color, 1.0 - p), 3.0)
		draw_polyline(_bolt, Color(1, 1, 1, 1.0 - p), 1.0)
		return
	draw_arc(Vector2.ZERO, radius * (0.4 + 0.6 * p), 0.0, TAU, 28, Color(color, 1.0 - p), 2.0)
	draw_circle(Vector2.ZERO, radius * (0.4 + 0.6 * p), Color(color, 0.25 * (1.0 - p)))
