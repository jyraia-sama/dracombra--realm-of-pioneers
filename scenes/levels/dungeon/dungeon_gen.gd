class_name DungeonGen
extends RefCounted
## Tire au sort le plan d'un étage du donjon : des salles posées sur une grille,
## reliées par des portes. Ne crée aucun nœud : le niveau (dungeon.gd) lit le résultat.
##
## Chaque salle occupe une case de la grille (SLOT_W × SLOT_H cases de tuiles, à peu près
## un écran). Le sol de la salle est un rectangle aux bords grignotés au hasard (pas d'effet
## « carré »). Deux salles voisines reliées ont un passage de 3 cases au milieu du mur commun.

## Taille d'une salle en cases (16 px) : 512 × 320 px, un peu plus qu'un écran (480 × 270).
const SLOT_W := 32
const SLOT_H := 20
## Épaisseur minimum du mur autour du sol d'une salle, en cases.
const MARGIN := 2
## Profondeur maximum des bords grignotés, en cases.
const BITE := 2
## Largeur d'un passage entre deux salles, en cases (impair : centré).
const DOOR := 3
## Taille de la grille des salles.
const GRID := Vector2i(6, 6)

enum Kind { START, COMBAT, CALM, STAIRS }

const DIRS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

## Salles : position sur la grille -> {"kind": Kind, "dist": distance au départ, "doors": [Vector2i…]}.
var rooms: Dictionary = {}
## Cases de sol (Vector2i -> true), en coordonnées de tuiles.
var floor_cells: Dictionary = {}
## Cases de passage entre salles (portes) : utile pour ne rien poser dessus.
var lane_cells: Dictionary = {}
var start: Vector2i
var stairs: Vector2i

var _rng: RandomNumberGenerator


## room_count : nombre de salles voulu ; loops : chance d'ajouter un passage en plus (boucle).
func generate(rng: RandomNumberGenerator, room_count: int, loops: float = 0.2) -> void:
	# On retire au sort tant que l'escalier est trop près du départ (étage trop court).
	for attempt in 30:
		_generate_once(rng, room_count, loops)
		if rooms[stairs]["dist"] >= mini(room_count - 2, ceili(room_count / 2.0)):
			return


func _generate_once(rng: RandomNumberGenerator, room_count: int, loops: float) -> void:
	_rng = rng
	rooms.clear()
	floor_cells.clear()
	lane_cells.clear()
	start = Vector2i(GRID.x / 2, GRID.y - 2)
	rooms[start] = {"kind": Kind.START, "dist": 0, "doors": [], "shrink": Vector2i.ZERO}
	# Croissance au hasard depuis la salle de départ : chaque nouvelle salle est reliée
	# à celle d'où elle part (un arbre), donc tout l'étage est accessible.
	var guard := 0
	while rooms.size() < room_count and guard < 1000:
		guard += 1
		var keys := rooms.keys()
		var from: Vector2i = keys[_rng.randi() % keys.size()]
		var dir: Vector2i = DIRS[_rng.randi() % 4]
		var to := from + dir
		if rooms.has(to) or not _inside(to):
			continue
		# Évite les gros paquets : refuse une salle qui aurait déjà 3 voisins.
		if _neighbours(to) >= 3:
			continue
		# Tailles variées : certaines salles sont plus petites (jusqu'à 6 cases de moins).
		var shrink := Vector2i(_rng.randi_range(0, 3), _rng.randi_range(0, 2)) if _rng.randf() < 0.6 else Vector2i.ZERO
		rooms[to] = {"kind": Kind.COMBAT, "dist": 0, "doors": [], "shrink": shrink}
		_link(from, to)
	# Quelques passages en plus entre salles voisines, pour faire des boucles.
	for pos in rooms:
		for dir in [Vector2i.RIGHT, Vector2i.DOWN]:
			var other: Vector2i = pos + dir
			if rooms.has(other) and not rooms[pos]["doors"].has(dir) and _rng.randf() < loops:
				_link(pos, other)
	_compute_distances()
	# L'escalier : la salle la plus éloignée du départ.
	stairs = start
	for pos in rooms:
		if rooms[pos]["dist"] > rooms[stairs]["dist"]:
			stairs = pos
	rooms[stairs]["kind"] = Kind.STAIRS
	# Environ une salle sur quatre est calme (décor seulement), jamais l'escalier ni le départ.
	for pos in rooms:
		if rooms[pos]["kind"] == Kind.COMBAT and _rng.randf() < 0.25:
			rooms[pos]["kind"] = Kind.CALM
	for pos in rooms:
		_carve_room(pos)
	for pos in rooms:
		for dir in rooms[pos]["doors"]:
			if dir == Vector2i.RIGHT or dir == Vector2i.DOWN:
				_carve_lane(pos, dir)


func _inside(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < GRID.x and p.y < GRID.y


func _neighbours(p: Vector2i) -> int:
	var n := 0
	for d in DIRS:
		if rooms.has(p + d):
			n += 1
	return n


func _link(a: Vector2i, b: Vector2i) -> void:
	var dir := b - a
	rooms[a]["doors"].append(dir)
	rooms[b]["doors"].append(-dir)


func _compute_distances() -> void:
	for pos in rooms:
		rooms[pos]["dist"] = -1
	rooms[start]["dist"] = 0
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var p: Vector2i = queue.pop_front()
		for dir in rooms[p]["doors"]:
			var q: Vector2i = p + dir
			if rooms[q]["dist"] < 0:
				rooms[q]["dist"] = rooms[p]["dist"] + 1
				queue.append(q)


# ------------------------------------------------------------------ géométrie

## Rectangle (en cases de tuiles) occupé par une salle de la grille.
static func slot_rect(pos: Vector2i) -> Rect2i:
	return Rect2i(pos.x * SLOT_W, pos.y * SLOT_H, SLOT_W, SLOT_H)


## Rectangle intérieur maximum du sol d'une salle.
static func inner_rect(pos: Vector2i) -> Rect2i:
	return slot_rect(pos).grow(-MARGIN)


## Centre d'une salle, en cases de tuiles.
static func slot_center(pos: Vector2i) -> Vector2i:
	var r := slot_rect(pos)
	return r.position + r.size / 2


## Salle de la grille qui contient une case de tuile.
static func slot_of(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(float(cell.x) / SLOT_W), floori(float(cell.y) / SLOT_H))


func _carve_room(pos: Vector2i) -> void:
	var shrink: Vector2i = rooms[pos].get("shrink", Vector2i.ZERO)
	var r := inner_rect(pos).grow_individual(-shrink.x, -shrink.y, -shrink.x, -shrink.y)
	var center := slot_center(pos)
	# Profondeur de grignotage le long de chaque bord : une « onde » lissée, pas du bruit pur.
	var top := _wavy(r.size.x)
	var bottom := _wavy(r.size.x)
	var left := _wavy(r.size.y)
	var right := _wavy(r.size.y)
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var lx := x - r.position.x
			var ly := y - r.position.y
			if ly < top[lx] or (r.size.y - 1 - ly) < bottom[lx]:
				continue
			if lx < left[ly] or (r.size.x - 1 - lx) < right[ly]:
				continue
			floor_cells[Vector2i(x, y)] = true
	# Le centre et les axes vers les portes restent toujours libres.
	for dir in rooms[pos]["doors"]:
		var c := center
		while slot_rect(pos).has_point(c + dir) and inner_rect(pos).has_point(c):
			for k in range(-(DOOR / 2), DOOR / 2 + 1):
				var side := Vector2i(-dir.y, dir.x) * k
				floor_cells[c + side] = true
			c += dir


func _wavy(length: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(length)
	var depth := _rng.randi_range(0, BITE)
	for i in length:
		# Change de profondeur de temps en temps, d'une case à la fois.
		if _rng.randf() < 0.18:
			depth = clampi(depth + (1 if _rng.randf() < 0.5 else -1), 0, BITE)
		out[i] = depth
	# Les coins sont un peu plus arrondis.
	for i in mini(3, length):
		out[i] = maxi(out[i], 3 - i)
		out[length - 1 - i] = maxi(out[length - 1 - i], 3 - i)
	return out


## Passage entre la salle `pos` et sa voisine dans la direction `dir` (droite ou bas).
func _carve_lane(pos: Vector2i, dir: Vector2i) -> void:
	var a := slot_center(pos)
	var b := slot_center(pos + dir)
	var c := a
	while c != b:
		c += dir
		for k in range(-(DOOR / 2), DOOR / 2 + 1):
			var cell := c + Vector2i(-dir.y, dir.x) * k
			if not floor_cells.has(cell):
				lane_cells[cell] = true
			floor_cells[cell] = true


## Cases du passage d'une salle vers sa voisine dans la direction `dir`, côté de cette salle :
## là où se pose la grille qui ferme la porte pendant un combat.
static func door_cells(pos: Vector2i, dir: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var r := slot_rect(pos)
	var c := slot_center(pos)
	var edge: Vector2i
	match dir:
		Vector2i.RIGHT:
			edge = Vector2i(r.end.x - MARGIN, c.y)
		Vector2i.LEFT:
			edge = Vector2i(r.position.x + MARGIN - 1, c.y)
		Vector2i.DOWN:
			edge = Vector2i(c.x, r.end.y - MARGIN)
		_:
			edge = Vector2i(c.x, r.position.y + MARGIN - 1)
	for k in range(-(DOOR / 2), DOOR / 2 + 1):
		out.append(edge + Vector2i(-dir.y, dir.x) * k)
	return out
