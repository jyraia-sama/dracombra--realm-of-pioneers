class_name PixelBurst
extends Node2D
## Gerbe de petits pixels qui jaillissent puis retombent au sol : copeaux de bois, éclats de
## pierre, étincelles, fumée, poussière de pas... Aucune image : tout est dessiné par le code,
## donc l'effet reste valable quels que soient les sprites (provisoires ou finaux).
##
## Vue de dessus : chaque pixel a une position au sol et une hauteur (z). Le nœud est posé
## au sol (pied du décor ou du personnage) pour être bien trié avec les autres objets.
##
##     PixelBurst.spawn(self, global_position, PixelBurst.WOOD, Vector2.RIGHT)

## Préréglages. Clés possibles :
##   count, colors, speed [min, max] (px monde/s au sol), up [min, max] (vitesse verticale),
##   gravity (négatif = monte, pour la fumée), life [min, max] (s), size [min, max] (px monde),
##   spread (radians autour de la direction donnée ; TAU = toutes directions),
##   height (hauteur de départ), drag (freinage au sol, 0..1 par seconde), bounce (0..1)
const WOOD := {
	"count": 9, "colors": [Color("8a5a2b"), Color("b07a3e"), Color("d9a86c"), Color("5e3b1c")],
	"speed": [25.0, 70.0], "up": [50.0, 110.0], "gravity": 260.0, "life": [0.5, 0.9],
	"size": [1.5, 2.5], "spread": 1.6, "height": 8.0, "drag": 2.5, "bounce": 0.3,
}
const STONE := {
	"count": 9, "colors": [Color("7d7d86"), Color("a3a3ad"), Color("5a5a63"), Color("c9c9d1")],
	"speed": [25.0, 65.0], "up": [45.0, 100.0], "gravity": 300.0, "life": [0.45, 0.8],
	"size": [1.5, 2.5], "spread": 1.6, "height": 5.0, "drag": 3.0, "bounce": 0.35,
}
const GEM := {
	"count": 8, "colors": [Color("5fe0e8"), Color("b8f6ff"), Color("2aa6c0"), Color.WHITE],
	"speed": [25.0, 70.0], "up": [40.0, 90.0], "gravity": 280.0, "life": [0.5, 0.9],
	"size": [1.0, 2.0], "spread": 1.8, "height": 6.0, "drag": 3.0, "bounce": 0.4,
}
const PLANT := {
	"count": 6, "colors": [Color("6bbf3f"), Color("a4e070"), Color("3f8a2a"), Color("d8f0a0")],
	"speed": [15.0, 45.0], "up": [30.0, 60.0], "gravity": 120.0, "life": [0.6, 1.1],
	"size": [1.0, 1.5], "spread": 2.2, "height": 6.0, "drag": 3.5, "bounce": 0.1,
}
const SPARK := {
	"count": 6, "colors": [Color.WHITE, Color("fff3b0"), Color("ffd15a")],
	"speed": [60.0, 130.0], "up": [-20.0, 30.0], "gravity": 80.0, "life": [0.15, 0.3],
	"size": [1.0, 2.0], "spread": 1.2, "height": 12.0, "drag": 6.0, "bounce": 0.0,
}
const BLOOD := {
	"count": 7, "colors": [Color("ff5a5a"), Color("c22f3a"), Color.WHITE],
	"speed": [40.0, 90.0], "up": [20.0, 60.0], "gravity": 240.0, "life": [0.25, 0.45],
	"size": [1.0, 1.5], "spread": 1.4, "height": 12.0, "drag": 4.0, "bounce": 0.0,
}
const SMOKE := {
	"count": 10, "colors": [Color("e8e2d8"), Color("c9c2b6"), Color("a8a196")],
	"speed": [8.0, 28.0], "up": [8.0, 20.0], "gravity": -12.0, "life": [0.5, 0.9],
	"size": [2.0, 4.0], "spread": TAU, "height": 6.0, "drag": 2.0, "bounce": 0.0,
	"grow": 1.5,
}
const DUST := {
	"count": 3, "colors": [Color("cdb89a"), Color("b9a37f"), Color("e0d2b8")],
	"speed": [6.0, 16.0], "up": [4.0, 12.0], "gravity": -4.0, "life": [0.25, 0.45],
	"size": [1.0, 2.0], "spread": TAU, "height": 0.5, "drag": 4.0, "bounce": 0.0,
	"grow": 1.0,
}

var _p: Array[Dictionary] = []
var _cfg: Dictionary


## Crée une gerbe au point `at` (coordonnées du monde, au sol). `direction` oriente la gerbe
## (Vector2.ZERO = toutes directions). `scale_count` multiplie le nombre de pixels.
## Variante d'un préréglage qui monte plus haut (décor abattu, explosion...).
static func higher(preset: Dictionary, factor: float = 1.6) -> Dictionary:
	var p := preset.duplicate()
	p["up"] = [preset["up"][0] * factor, preset["up"][1] * factor]
	p["height"] = preset.get("height", 0.0) * factor + 6.0
	p["life"] = [preset["life"][0] * 1.3, preset["life"][1] * 1.3]
	return p


static func spawn(from: Node, at: Vector2, preset: Dictionary, direction: Vector2 = Vector2.ZERO,
		scale_count: float = 1.0) -> PixelBurst:
	var scene := from.get_tree().current_scene
	if scene == null:
		return null
	var burst := PixelBurst.new()
	burst.name = "PixelBurst"
	burst.global_position = at
	burst._setup(preset, direction, scale_count)
	scene.add_child(burst)
	return burst


func _setup(cfg: Dictionary, direction: Vector2, scale_count: float) -> void:
	_cfg = cfg
	var spread: float = cfg.get("spread", TAU)
	var base_angle := direction.angle() if direction != Vector2.ZERO else 0.0
	if direction == Vector2.ZERO:
		spread = TAU
	var colors: Array = cfg["colors"]
	for i in maxi(1, int(round(cfg["count"] * scale_count))):
		var angle := base_angle + randf_range(-spread / 2.0, spread / 2.0)
		var life := randf_range(cfg["life"][0], cfg["life"][1])
		_p.append({
			"pos": Vector2(randf_range(-2.0, 2.0), randf_range(-1.0, 1.0)),
			"vel": Vector2.from_angle(angle) * randf_range(cfg["speed"][0], cfg["speed"][1]) * Vector2(1.0, 0.6),
			"z": cfg.get("height", 0.0) + randf_range(-1.0, 1.0),
			"vz": randf_range(cfg["up"][0], cfg["up"][1]),
			"life": life, "max": life,
			"size": randf_range(cfg["size"][0], cfg["size"][1]),
			"color": colors[randi() % colors.size()],
		})


func _process(delta: float) -> void:
	var gravity: float = _cfg.get("gravity", 200.0)
	var drag: float = _cfg.get("drag", 2.0)
	var bounce: float = _cfg.get("bounce", 0.0)
	var alive := 0
	for p in _p:
		if p["life"] <= 0.0:
			continue
		p["life"] -= delta
		alive += 1
		p["vz"] -= gravity * delta
		p["z"] += p["vz"] * delta
		var vel: Vector2 = p["vel"]
		if p["z"] <= 0.0 and gravity > 0.0:
			# Touche le sol : rebondit un peu et glisse en freinant.
			p["z"] = 0.0
			p["vz"] = -p["vz"] * bounce if absf(p["vz"]) > 20.0 else 0.0
			vel = vel.lerp(Vector2.ZERO, clampf(drag * 2.0 * delta, 0.0, 1.0))
		else:
			vel = vel.lerp(Vector2.ZERO, clampf(drag * 0.3 * delta, 0.0, 1.0))
		p["vel"] = vel
		p["pos"] += vel * delta
	if alive == 0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var grow: float = _cfg.get("grow", 0.0)
	for p in _p:
		if p["life"] <= 0.0:
			continue
		var t: float = 1.0 - p["life"] / p["max"]
		var s: float = roundf(p["size"] * (1.0 + grow * t))
		var at: Vector2 = (p["pos"] - Vector2(0.0, p["z"])).round()
		var c: Color = p["color"]
		# Disparaît sur le dernier tiers de sa vie.
		c.a *= clampf((1.0 - t) * 3.0, 0.0, 1.0)
		draw_rect(Rect2(at - Vector2(s, s) * 0.5, Vector2(s, s)), c)
