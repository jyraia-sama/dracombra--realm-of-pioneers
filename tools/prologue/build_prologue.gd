extends SceneTree
## Construit le TileSet de caverne, les décors lumineux et les deux niveaux du prologue.
## Usage : godot --headless --path <projet> -s res://_build.gd -- <caverne.txt> <taniere.txt>

const T := 16
const TILES_PNG := "res://assets/tilesets/cave_tiles.png"
const LIGHT_TEX := "res://assets/lights/light_radial.tres"
const TILESET := "res://assets/tilesets/cave_tileset.tres"
const CAVE := "res://scenes/levels/prologue/cave_entrance.tscn"
const LAIR := "res://scenes/levels/prologue/solakor_lair.tscn"
const TUNNEL := "res://scenes/levels/prologue/horde_tunnel.tscn"
const PASSAGE := "res://scenes/levels/prologue/wounded_passage.tscn"
const SYLVE := "res://scenes/levels/sylve/sylve.tscn"

const ALT_MASKS := [4, 4, 4, 0, 0, 5, 6, 12]

var rng := RandomNumberGenerator.new()
var light_tex: Texture2D
var props_spec: Dictionary = {}
var prop_scenes: Dictionary = {}


func _initialize() -> void:
	rng.seed = 42
	var args := OS.get_cmdline_user_args()
	var cave_rows := FileAccess.get_file_as_string(args[0]).strip_edges().split("\n")
	var lair_rows := FileAccess.get_file_as_string(args[1]).strip_edges().split("\n")
	var tunnel_rows := FileAccess.get_file_as_string(args[2]).strip_edges().split("\n")
	var tunnel_path: Array = JSON.parse_string(FileAccess.get_file_as_string(args[3]))

	props_spec = JSON.parse_string(FileAccess.get_file_as_string(args[4]))
	var passage_rows := FileAccess.get_file_as_string(args[5]).strip_edges().split("\n")
	var sylve_rows := FileAccess.get_file_as_string(args[6]).strip_edges().split("\n")
	props_spec.merge(JSON.parse_string(FileAccess.get_file_as_string(args[7])))

	var tex: Texture2D = load(TILES_PNG)
	light_tex = _make_light_texture()
	for prop_name in props_spec:
		prop_scenes[prop_name] = _make_prop_scene(prop_name, props_spec[prop_name])
	var ts := _make_tileset(tex)
	_build_cave(cave_rows, ts)
	_build_lair(lair_rows, ts)
	_build_tunnel(tunnel_rows, tunnel_path, ts)
	_build_passage(passage_rows, ts)
	_build_sylve(sylve_rows, tex)
	print("BUILD OK")
	quit()


# ------------------------------------------------------------------ ressources

func _make_light_texture() -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 128
	t.height = 128
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	ResourceSaver.save(t, LIGHT_TEX, ResourceSaver.FLAG_CHANGE_PATH)
	return load(LIGHT_TEX)


## Une scène par décor : image posée au pied du décor, collision à sa base,
## lumière éventuelle. Origine de la scène = le point du sol sous le décor.
func _make_prop_scene(prop_name: String, spec: Dictionary) -> PackedScene:
	var group: String = spec["group"]
	var w: int = int(spec["size"][0])
	var h: int = int(spec["size"][1])
	var kind: String = spec["kind"]
	var root := Node2D.new()
	root.name = prop_name.to_pascal_case()
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = load("res://assets/sprites/props/%s/%s.png" % [group, prop_name])
	sprite.centered = false
	var frames: int = int(spec.get("frames", 1))
	if frames > 1:
		sprite.hframes = frames
		sprite.set_script(load("res://scenes/props/sprite_cycle.gd"))
	match kind:
		"decal":
			# À plat sur le sol, sous les personnages.
			sprite.offset = Vector2(-(w / 2), -(h / 2))
			root.z_index = -1
		"hanging":
			# Pend du haut de la paroi : l'origine est au pied de la paroi.
			sprite.offset = Vector2(-(w / 2), -12)
		_:
			sprite.offset = Vector2(-(w / 2), -h)
	root.add_child(sprite)
	sprite.owner = root

	if spec["collision"] != null:
		var body := StaticBody2D.new()
		body.name = "Body"
		body.collision_layer = 1
		body.collision_mask = 0
		root.add_child(body)
		body.owner = root
		var shape := CollisionShape2D.new()
		shape.name = "CollisionShape2D"
		var rect := RectangleShape2D.new()
		rect.size = Vector2(spec["collision"][0], spec["collision"][1])
		shape.shape = rect
		shape.position = Vector2(0, -rect.size.y / 2.0)
		body.add_child(shape)
		shape.owner = root

	if spec["light"] != null:
		var l: Array = spec["light"]
		var light := PointLight2D.new()
		light.name = "Light"
		light.texture = light_tex
		light.color = Color(l[0][0], l[0][1], l[0][2])
		light.texture_scale = float(l[1]) * 2.0 / 128.0
		light.energy = float(l[2])
		light.position = Vector2(0, 0) if kind == "decal" else Vector2(0, -h * 0.4)
		if l[3]:
			light.set_script(load("res://scenes/props/flicker_light.gd"))
		root.add_child(light)
		light.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	var path := "res://scenes/props/%s/%s.tscn" % [group, prop_name]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	ResourceSaver.save(packed, path)
	root.free()
	return load(path)


# ------------------------------------------------------------------ placement des décors

## Contexte de placement d'un niveau.
class Scatter:
	var rows: PackedStringArray
	var w: int
	var h: int
	var props: Node2D
	var keep := {}      # cases à laisser libres (passages, apparitions, scènes)
	var used := {}      # cases déjà occupées par un décor
	var blocked := {}   # cases bloquées par la collision d'un décor
	var start: Vector2i
	var goals: Array = []
	## false : pas de vérification de passage (forêts denses, déjà hors des chemins).
	var check_paths := true

	func is_floor(c: Vector2i) -> bool:
		return c.x >= 0 and c.y >= 0 and c.x < w and c.y < h and rows[c.y][c.x] != "#"

	func is_rock(c: Vector2i) -> bool:
		return not is_floor(c)

	func near_wall(c: Vector2i) -> bool:
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if is_rock(c + d):
				return true
		return false

	func open(c: Vector2i, radius: int) -> bool:
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if is_rock(c + Vector2i(dx, dy)):
					return false
		return true

	## Le départ mène-t-il toujours à chacun des buts (sorties, lieux de l'histoire) ?
	func connected() -> bool:
		var seen := {start: true}
		var queue: Array[Vector2i] = [start]
		var remaining := {}
		for g in goals:
			remaining[g] = true
		while not queue.is_empty():
			var c: Vector2i = queue.pop_back()
			if remaining.erase(c) and remaining.is_empty():
				return true
			for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var n: Vector2i = c + d
				if not seen.has(n) and is_floor(n) and not blocked.has(n):
					seen[n] = true
					queue.append(n)
		return false


func _new_scatter(root: Node2D, rows: PackedStringArray, sp: Dictionary) -> Scatter:
	var sc := Scatter.new()
	sc.rows = rows
	sc.h = rows.size()
	sc.w = rows[0].length()
	sc.start = sp["P"][0]
	sc.goals = sp["E"]
	var props := Node2D.new()
	props.name = "Props"
	props.y_sort_enabled = true
	_add(root, props)
	sc.props = props
	for c in sp["E"]:
		_keep(sc, c, 2)
	_keep(sc, sc.start, 2)
	return sc


func _keep(sc: Scatter, c: Vector2i, radius: int) -> void:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			sc.keep[c + Vector2i(dx, dy)] = true


## Pose un décor sur une case (pied du décor au bas de la case). Renvoie false si
## la place manque, si la case doit rester libre, ou si cela boucherait le passage.
func _place(sc: Scatter, prop_name: String, cell: Vector2i, ignore_keep := false) -> bool:
	var spec: Dictionary = props_spec[prop_name]
	var kind: String = spec["kind"]
	var bw: int = 0 if spec["collision"] == null else 1
	var pw: int = int(spec["size"][0])
	var ph: int = int(spec["size"][1])
	if kind == "hanging":
		# Au pied d'une paroi (case de roche avec du sol juste en dessous).
		if not (sc.is_rock(cell) and sc.is_floor(cell + Vector2i.DOWN)) or sc.used.has(cell):
			return false
		_instance(sc, prop_name, Vector2(cell.x * T + T / 2.0, cell.y * T + T + 1))
		sc.used[cell] = true
		return true

	# Cases couvertes par l'image (au sol) et par la collision.
	var span: int = maxi(1, int(ceil(pw / float(T))))
	var first := cell.x - (span - 1) / 2
	var center_x := (first + span / 2.0) * T
	var covered: Array[Vector2i] = []
	for i in span:
		covered.append(Vector2i(first + i, cell.y))
	if kind == "decal":
		for dy in range(1, int(ceil(ph / float(T)))):
			for i in span:
				covered.append(Vector2i(first + i, cell.y - dy))
	var footprint: Array[Vector2i] = []
	if spec["collision"] != null:
		var half: float = float(spec["collision"][0]) / 2.0
		for x in range(int(floor((center_x - half) / T)), int(floor((center_x + half - 0.01) / T)) + 1):
			footprint.append(Vector2i(x, cell.y))
	for c in footprint:
		if not sc.is_floor(c):
			return false
	for c in covered:
		if not sc.is_floor(c) or sc.used.has(c):
			return false
		if not ignore_keep and sc.keep.has(c) and (bw > 0 or kind != "decal"):
			return false
	# Les grands décors ne doivent pas avoir de roche juste au-dessus de leur image.
	if kind == "object" and ph > T + 4:
		for c in covered:
			if sc.is_rock(c + Vector2i.UP) and ph > T * 2:
				return false
	for c in footprint:
		sc.blocked[c] = true
	if footprint.size() > 0 and sc.check_paths and not sc.connected():
		for c in footprint:
			sc.blocked.erase(c)
		return false
	var y := cell.y * T + (T / 2.0 if kind == "decal" else T - 2.0)
	_instance(sc, prop_name, Vector2(center_x, y))
	for c in covered:
		sc.used[c] = true
	return true


func _instance(sc: Scatter, prop_name: String, at: Vector2) -> void:
	var node: Node2D = (prop_scenes[prop_name] as PackedScene).instantiate()
	node.position = at
	if rng.randf() < 0.5 and not prop_name.begins_with("dragon_head") and not prop_name.begins_with("ancient"):
		node.scale = Vector2(-1, 1)
	sc.props.add_child(node)
	node.owner = sc.props.owner
	node.name = prop_name.to_pascal_case() + str(sc.props.get_child_count())


## Remplace un caractère de la carte par l'un des décors proposés (le plus grand qui rentre).
func _convert(sc: Scatter, sp: Dictionary, ch: String, choices: Array) -> void:
	for cell in sp.get(ch, []):
		var options := choices.duplicate()
		options.shuffle()
		# Toujours une solution de repli sans collision en dernier.
		options.sort_custom(func(a, b): return int(props_spec[a]["block"][0]) > int(props_spec[b]["block"][0]))
		for prop_name in options:
			if _place(sc, prop_name, cell, true):
				break


## Sème `count` décors parmi les cases qui vérifient `filter`.
func _sow(sc: Scatter, names: Array, count: int, filter: Callable) -> void:
	var cells: Array[Vector2i] = []
	for y in sc.h:
		for x in sc.w:
			var c := Vector2i(x, y)
			if filter.call(c):
				cells.append(c)
	_shuffle(cells)
	var placed := 0
	for c in cells:
		if placed >= count:
			return
		if _place(sc, names[rng.randi_range(0, names.size() - 1)], c):
			placed += 1


func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func _floor_picker(rows_weights: Array) -> Callable:
	# rows_weights : [[Vector2i(x, ligne), poids], ...]
	return func(_cell: Vector2i) -> Vector2i:
		var total := 0
		for e in rows_weights:
			total += int(e[1])
		var r := rng.randi_range(1, total)
		for e in rows_weights:
			r -= int(e[1])
			if r <= 0:
				return e[0]
		return rows_weights[0][0]


const CAVE_FLOOR := [[Vector2i(0, 2), 6], [Vector2i(1, 2), 6], [Vector2i(2, 2), 6], [Vector2i(3, 2), 6],
	[Vector2i(4, 2), 2], [Vector2i(5, 2), 2], [Vector2i(6, 2), 0], [Vector2i(7, 2), 0]]
const LAIR_FLOOR := [[Vector2i(0, 5), 6], [Vector2i(1, 5), 6], [Vector2i(2, 5), 6], [Vector2i(3, 5), 4],
	[Vector2i(4, 5), 4], [Vector2i(6, 5), 1]]

const CRYSTALS_BLUE := ["crystal_blue_large", "crystal_blue", "crystal_blue_small"]
const CRYSTALS_PURPLE := ["crystal_purple_large", "crystal_purple", "crystal_purple_small"]
const MUSHROOMS := ["mushrooms_large", "mushrooms"]
const EMBERS := ["embers_large", "embers", "embers_small"]
const STALAGMITES := ["stalagmite_large", "stalagmite", "stalagmite_small"]
const ROCKS := ["rocks_small", "rocks", "rocks_brown"]
const ROOTS := ["roots_a", "roots_b", "roots_wide"]
const CLAWS := ["claw_marks_a", "claw_marks_b", "claw_marks_c"]
const BURNS := ["scorched_ground", "scorched_ground_small", "lava_crack_small", "cracked_floor"]


func _convert_common(sc: Scatter, sp: Dictionary) -> void:
	_convert(sc, sp, "c", CRYSTALS_BLUE)
	_convert(sc, sp, "p", CRYSTALS_PURPLE)
	_convert(sc, sp, "m", MUSHROOMS)
	_convert(sc, sp, "e", EMBERS)
	_convert(sc, sp, "s", STALAGMITES)
	_convert(sc, sp, "b", ["skull_bones"])



func _rock_coords(mask: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = [Vector2i(mask % 8, mask / 8)]
	for i in ALT_MASKS.size():
		if ALT_MASKS[i] == mask:
			out.append(Vector2i(i, 4))
	return out


func _make_tileset(tex: Texture2D) -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(T, T)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)
	ts.add_terrain_set()
	ts.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_SIDES)
	ts.add_terrain(0)
	ts.set_terrain_name(0, 0, "Roche")
	ts.set_terrain_color(0, 0, Color(0.55, 0.45, 0.7))

	var src := TileSetAtlasSource.new()
	src.resource_name = "Caverne"
	src.texture = tex
	src.texture_region_size = Vector2i(T, T)
	ts.add_source(src, 0)

	var full := PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])
	for mask in 16:
		var coords := _rock_coords(mask)
		for i in coords.size():
			var c: Vector2i = coords[i]
			src.create_tile(c)
			var d := src.get_tile_data(c, 0)
			d.terrain_set = 0
			d.terrain = 0
			d.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_SIDE, -1 if mask & 1 else 0)
			d.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_RIGHT_SIDE, -1 if mask & 2 else 0)
			d.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_SIDE, -1 if mask & 4 else 0)
			d.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_LEFT_SIDE, -1 if mask & 8 else 0)
			d.probability = 1.0 if i == 0 else 0.6
			d.y_sort_origin = 8
			d.add_collision_polygon(0)
			d.set_collision_polygon_points(0, 0, full)

	# Sols : ligne 2 (caverne) et ligne 5 (tanière).
	for row in [2, 5]:
		for x in 8:
			src.create_tile(Vector2i(x, row))
	# Falaises hautes : ligne 6 (moitié haute), ligne 7 (moitié basse).
	for row in [6, 7]:
		for x in 8:
			var c := Vector2i(x, row)
			src.create_tile(c)
			var d := src.get_tile_data(c, 0)
			d.y_sort_origin = 8
			d.add_collision_polygon(0)
			d.set_collision_polygon_points(0, 0, full)

	# Éboulis (les autres décors sont des scènes, voir _make_prop_scene).
	var decor := {
		Vector2i(3, 3): PackedVector2Array([Vector2(-6, 0), Vector2(6, 0), Vector2(6, 6), Vector2(-6, 6)]),
		Vector2i(6, 3): full,
		Vector2i(7, 3): full,
	}
	for c in decor:
		src.create_tile(c)
		var d := src.get_tile_data(c, 0)
		d.y_sort_origin = 8 if decor[c] == full else 6
		d.add_collision_polygon(0)
		d.set_collision_polygon_points(0, 0, decor[c])

	ResourceSaver.save(ts, TILESET, ResourceSaver.FLAG_CHANGE_PATH)
	return load(TILESET)


# ------------------------------------------------------------------ niveaux

## Peint les trois calques et renvoie les cases spéciales, par caractère.
func _paint(root: Node2D, rows: PackedStringArray, ts: TileSet, darkness: Color, floor_fn: Callable) -> Dictionary:
	var h := rows.size()
	var w := rows[0].length()
	var is_rock := func(x: int, y: int) -> bool:
		return x < 0 or y < 0 or x >= w or y >= h or rows[y][x] == "#"

	var modulate := CanvasModulate.new()
	modulate.name = "Darkness"
	modulate.color = darkness
	_add(root, modulate)

	var ground := TileMapLayer.new()
	ground.name = "Ground"
	ground.tile_set = ts
	ground.z_index = -1
	_add(root, ground)
	var walls := TileMapLayer.new()
	walls.name = "Walls"
	walls.tile_set = ts
	walls.y_sort_enabled = true
	_add(root, walls)
	var decor := TileMapLayer.new()
	decor.name = "Decor"
	decor.tile_set = ts
	decor.y_sort_enabled = true
	_add(root, decor)
	root.set("bounds_layer", walls)

	var special := {}
	for y in h:
		for x in w:
			var ch := rows[y][x]
			var cell := Vector2i(x, y)
			if ch == "#":
				var mask := 0
				if not is_rock.call(x, y - 1): mask |= 1
				if not is_rock.call(x + 1, y): mask |= 2
				if not is_rock.call(x, y + 1): mask |= 4
				if not is_rock.call(x - 1, y): mask |= 8
				# Paroi de deux cases quand la roche est assez épaisse.
				if mask & 4 and not mask & 1:
					var lower_index: int = [4, 6, 12, 14].find(mask & 14)
					walls.set_cell(cell, 0, Vector2i(lower_index * 2 + rng.randi_range(0, 1), 7))
					continue
				if not mask & 4 and not is_rock.call(x, y + 2):
					var bits := (mask & 1) | (2 if mask & 2 else 0) | (4 if mask & 8 else 0)
					walls.set_cell(cell, 0, Vector2i(bits, 6))
					continue
				var options := _rock_coords(mask)
				var pick: Vector2i = options[0] if options.size() == 1 or rng.randf() < 0.45 \
					else options[rng.randi_range(1, options.size() - 1)]
				walls.set_cell(cell, 0, pick)
				continue
			ground.set_cell(cell, 0, floor_fn.call(cell))
			match ch:
				"r": decor.set_cell(cell, 0, Vector2i(3, 3))
				"R", "X": decor.set_cell(cell, 0, Vector2i(6 + rng.randi_range(0, 1), 3))
			if not special.has(ch):
				special[ch] = []
			special[ch].append(cell)
	return special


func _feet(cell: Vector2i) -> Vector2:
	return Vector2(cell * T) + Vector2(T / 2.0, T)


func _add_player(root: Node2D, at: Vector2) -> Node2D:
	var player: Node2D = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.name = "Player"
	player.position = at
	_add(root, player)
	var torch := PointLight2D.new()
	torch.name = "HeroLight"
	torch.texture = light_tex
	torch.color = Color(1.0, 0.86, 0.7)
	torch.energy = 1.0
	torch.texture_scale = 2.0
	torch.position = Vector2(0, -16)
	player.add_child(torch)
	torch.owner = root
	return player


func _add_exit(root: Node2D, cells: Array, target: String, node_name: String) -> Node:
	var rect := Rect2(Vector2(cells[0] * T), Vector2(T, T))
	for c in cells:
		rect = rect.merge(Rect2(Vector2(c * T), Vector2(T, T)))
	var exit := Area2D.new()
	exit.name = node_name
	exit.set_script(load("res://scenes/levels/level_exit.gd"))
	exit.set("target_scene", target)
	exit.collision_layer = 0
	exit.collision_mask = 2
	exit.monitorable = false
	exit.position = rect.get_center()
	_add(root, exit)
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var rs := RectangleShape2D.new()
	rs.size = rect.size
	shape.shape = rs
	exit.add_child(shape)
	shape.owner = root
	return exit


func _add_enemies(root: Node2D, cells: Array, scene_path: String, base_name: String) -> void:
	var scene: PackedScene = load(scene_path)
	for i in cells.size():
		var enemy: Node2D = scene.instantiate()
		enemy.name = base_name if i == 0 else "%s%d" % [base_name, i + 1]
		enemy.position = _feet(cells[i])
		_add(root, enemy)


func _add_hud(root: Node2D) -> void:
	_add(root, (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate())


func _build_cave(rows: PackedStringArray, ts: TileSet) -> void:
	var root := Node2D.new()
	root.name = "CaveEntrance"
	root.y_sort_enabled = true
	root.set_script(load("res://scenes/levels/prologue/cave_entrance.gd"))
	var sp := _paint(root, rows, ts, Color(0.36, 0.33, 0.46), _floor_picker(CAVE_FLOOR))
	_decorate_cave(root, rows, sp)

	# Départ de l'introduction : l'éboulis le plus à l'ouest, sur la ligne du point P.
	var spawn: Vector2i = sp["P"][0]
	var rubble: Array = sp["R"]
	var start: Vector2i = rubble[0]
	for c in rubble:
		if c.y == spawn.y and (start.y != spawn.y or c.x < start.x):
			start = c
	_add_player(root, _feet(start))
	_add_enemies(root, sp.get("S", []), "res://scenes/enemies/slime/slime.tscn", "Slime")
	_add_enemies(root, sp.get("G", []), "res://scenes/enemies/rock_goblin/rock_goblin.tscn", "RockGoblin")
	_add_exit(root, sp["E"], TUNNEL, "ExitToTunnel")
	_add_hud(root)

	var rubble_cells: Array[Vector2i] = []
	for c in rubble:
		rubble_cells.append(c)
	root.set("decor_layer", root.get_node("Decor"))
	root.set("rubble_cells", rubble_cells)
	root.set("respawn_position", _feet(spawn))
	_save(root, CAVE)


func _build_lair(rows: PackedStringArray, ts: TileSet) -> void:
	var root := Node2D.new()
	root.name = "SolakorLair"
	root.y_sort_enabled = true
	root.set_script(load("res://scenes/levels/prologue/solakor_lair.gd"))
	var sp := _paint(root, rows, ts, Color(0.3, 0.24, 0.3), _floor_picker(LAIR_FLOOR))
	_decorate_lair(root, rows, sp)

	_add_player(root, _feet(sp["P"][0]))
	var dragon: Node2D = (load("res://scenes/bosses/solakor/solakor.tscn") as PackedScene).instantiate()
	dragon.name = "Solakor"
	dragon.position = _feet(sp["D"][0])
	_add(root, dragon)

	var light := PointLight2D.new()
	light.name = "CrevasseLight"
	light.texture = light_tex
	light.color = Color(0.75, 0.85, 1.0)
	light.energy = 0.0
	light.texture_scale = 1.6
	light.position = Vector2(sp["L"][0] * T) + Vector2(T / 2.0, T / 2.0)
	_add(root, light)

	var exit := _add_exit(root, sp["E"], PASSAGE, "CrevasseExit")
	_add_hud(root)

	var crevasse_cells: Array[Vector2i] = []
	for c in sp["X"]:
		crevasse_cells.append(c)
	root.set("dragon", dragon)
	root.set("decor_layer", root.get_node("Decor"))
	root.set("crevasse_cells", crevasse_cells)
	root.set("crevasse_exit", exit)
	root.set("crevasse_light", light)
	_save(root, LAIR)


func _build_tunnel(rows: PackedStringArray, path: Array, ts: TileSet) -> void:
	var root := Node2D.new()
	root.name = "HordeTunnel"
	root.y_sort_enabled = true
	root.set_script(load("res://scenes/levels/prologue/horde_tunnel.gd"))
	var near_lair := 86
	var cave_floor := _floor_picker(CAVE_FLOOR)
	var lair_floor := _floor_picker(LAIR_FLOOR)
	var sp := _paint(root, rows, ts, Color(0.34, 0.31, 0.43),
		func(c: Vector2i) -> Vector2i: return lair_floor.call(c) if c.x >= near_lair + rng.randi_range(-3, 3) else cave_floor.call(c))
	_decorate_tunnel(root, rows, sp, path, near_lair)
	_add_player(root, _feet(sp["P"][0]))
	_add_exit(root, sp["E"], LAIR, "ExitToLair")
	_add_hud(root)

	var spawn_cells: Array[Vector2i] = []
	for c in sp["K"]:
		spawn_cells.append(c)
	var flight := PackedVector2Array()
	for p in path:
		flight.append(Vector2(p[0], p[1]))
	root.set("ground_layer", root.get_node("Ground"))
	root.set("spawn_cells", spawn_cells)
	root.set("flight_path", flight)
	root.set("flee_trigger_x", 58.0 * T)
	root.set("scare_x", 88.0 * T)
	_save(root, TUNNEL)


func _build_passage(rows: PackedStringArray, ts: TileSet) -> void:
	var root := Node2D.new()
	root.name = "WoundedPassage"
	root.y_sort_enabled = true
	root.set_script(load("res://scenes/levels/prologue/wounded_passage.gd"))
	var sp := _paint(root, rows, ts, Color(0.26, 0.24, 0.32), _floor_picker(CAVE_FLOOR))
	var sc := _new_scatter(root, rows, sp)
	_keep(sc, sp["H"][0], 2)
	_convert_common(sc, sp)
	var wall := func(c: Vector2i) -> bool: return sc.is_floor(c) and sc.near_wall(c)
	_sow(sc, ROOTS, 12, func(c): return sc.is_rock(c))
	_sow(sc, ROCKS, 5, wall)
	_sow(sc, STALAGMITES, 4, wall)
	_sow(sc, ["fallen_adventurer"], 1, func(c): return c.x > 40 and wall.call(c))
	# Des racines plus nombreuses près de la sortie : la surface est proche.
	_sow(sc, ROOTS, 8, func(c): return c.x > 58 and sc.is_rock(c))
	_add_player(root, _feet(sp["P"][0]))
	_add_exit(root, sp["E"], SYLVE, "ExitToSylve")
	_add_hud(root)

	var light := PointLight2D.new()
	light.name = "Daylight"
	light.texture = light_tex
	light.color = Color(1.0, 0.92, 0.75)
	light.energy = 0.4
	light.texture_scale = 3.0
	light.position = Vector2(sp["O"][0] * T) + Vector2(T, T / 2.0)
	_add(root, light)

	root.set("rest_point", _feet(sp["H"][0]))
	root.set("light_from_x", float(sp["P"][0].x * T))
	root.set("light_to_x", float(sp["O"][0].x * T))
	root.set("daylight", light)
	_save(root, PASSAGE)


func _decorate_cave(root: Node2D, rows: PackedStringArray, sp: Dictionary) -> void:
	var sc := _new_scatter(root, rows, sp)
	for ch in ["R", "S", "G"]:
		for c in sp.get(ch, []):
			_keep(sc, c, 1)
	_convert_common(sc, sp)
	var wall := func(c: Vector2i) -> bool: return sc.is_floor(c) and sc.near_wall(c)
	# Les ruines de l'ancienne Dracombra affleurent dans la grande salle et la salle violette.
	var big_hall := func(c: Vector2i) -> bool: return c.x >= 26 and c.x <= 50 and c.y >= 12 and sc.is_floor(c)
	var east_hall := func(c: Vector2i) -> bool: return c.x >= 52 and sc.is_floor(c)
	_sow(sc, ["pillar"], 1, func(c): return big_hall.call(c) and sc.open(c, 1))
	_sow(sc, ["pillar_broken", "pillar_stump"], 2, func(c): return big_hall.call(c) and wall.call(c))
	_sow(sc, ["stone_wing"], 1, func(c): return big_hall.call(c) and wall.call(c))
	_sow(sc, ["rune_stones", "rune_stone"], 1, func(c): return big_hall.call(c) and sc.open(c, 1))
	_sow(sc, ["carved_tablet", "rune_stone", "pillar_broken"], 3, func(c): return east_hall.call(c) and wall.call(c))
	_sow(sc, ["fallen_adventurer"], 1, func(c): return big_hall.call(c) and wall.call(c))
	_sow(sc, ["dark_pool"], 1, func(c): return big_hall.call(c) and sc.open(c, 1))
	_sow(sc, ["boulder"], 3, wall)
	_sow(sc, ROCKS, 7, wall)
	_sow(sc, STALAGMITES, 5, wall)
	_sow(sc, MUSHROOMS, 4, wall)
	_sow(sc, CRYSTALS_BLUE, 2, wall)
	_sow(sc, ROOTS, 10, func(c): return sc.is_rock(c))


func _decorate_tunnel(root: Node2D, rows: PackedStringArray, sp: Dictionary, path: Array, near_lair: int) -> void:
	var sc := _new_scatter(root, rows, sp)
	for c in sp.get("K", []):
		_keep(sc, c, 1)
	# Le chemin de fuite reste dégagé.
	var pts: Array[Vector2] = [Vector2(_feet(sc.start))]
	for p in path:
		pts.append(Vector2(p[0], p[1]))
	for i in pts.size() - 1:
		var steps := int(pts[i].distance_to(pts[i + 1]) / 4.0) + 1
		for k in steps + 1:
			var q := pts[i].lerp(pts[i + 1], k / float(steps))
			_keep(sc, Vector2i(int(q.x / T), int(q.y / T)), 1)
	_convert_common(sc, sp)
	var wall := func(c: Vector2i) -> bool: return sc.is_floor(c) and sc.near_wall(c)
	var cave_part := func(c: Vector2i) -> bool: return c.x < near_lair - 4
	var lair_part := func(c: Vector2i) -> bool: return c.x >= near_lair - 2
	# Des vestiges de Dracombra le long du couloir.
	_sow(sc, ["dragon_head_statue"], 1, func(c): return c.x > 30 and c.x < 50 and sc.is_floor(c))
	_sow(sc, ["pillar_broken", "pillar_stump", "rune_stone", "carved_tablet"], 4,
		func(c): return cave_part.call(c) and c.x > 20 and wall.call(c))
	_sow(sc, ROCKS, 8, func(c): return cave_part.call(c) and wall.call(c))
	_sow(sc, STALAGMITES, 5, func(c): return cave_part.call(c) and wall.call(c))
	_sow(sc, ROOTS, 14, func(c): return cave_part.call(c) and sc.is_rock(c))
	# Les abords de la tanière : griffures, brûlures, restes d'aventuriers.
	_sow(sc, ["melted_armor", "fallen_banner"], 2, func(c): return lair_part.call(c) and wall.call(c))
	_sow(sc, ["fallen_adventurer"], 1, func(c): return lair_part.call(c) and wall.call(c))
	_sow(sc, CLAWS, 3, func(c): return lair_part.call(c) and sc.is_floor(c))
	_sow(sc, BURNS, 3, func(c): return lair_part.call(c) and sc.is_floor(c))
	_sow(sc, ["dragon_scales"], 1, func(c): return lair_part.call(c) and sc.is_floor(c))


func _decorate_lair(root: Node2D, rows: PackedStringArray, sp: Dictionary) -> void:
	var sc := _new_scatter(root, rows, sp)
	var d: Vector2i = sp["D"][0]
	# Le nid de Solakor, sous le dragon.
	_instance(sc, "dragon_nest", Vector2(_feet(d)) + Vector2(0, -26))
	for y in range(d.y - 6, d.y + 3):
		for x in range(d.x - 6, d.x + 7):
			sc.used[Vector2i(x, y)] = true
			sc.keep[Vector2i(x, y)] = true
	for ch in ["X", "L"]:
		for c in sp.get(ch, []):
			_keep(sc, c, 2)
	# Le combat se joue autour du dragon : on garde le centre dégagé.
	for y in range(d.y - 2, d.y + 9):
		for x in range(d.x - 9, d.x + 10):
			sc.keep[Vector2i(x, y)] = true
	_convert_common(sc, sp)
	var wall := func(c: Vector2i) -> bool: return sc.is_floor(c) and sc.near_wall(c)
	_sow(sc, ["melted_armor", "fallen_banner"], 3, wall)
	_sow(sc, ["fallen_adventurer"], 2, wall)
	_sow(sc, ["pillar_broken", "pillar_stump", "stone_wing"], 3, wall)
	_sow(sc, ["rune_brazier"], 2, wall)
	_sow(sc, STALAGMITES, 4, wall)
	_sow(sc, ROCKS, 4, wall)
	_sow(sc, ROOTS, 8, func(c): return sc.is_rock(c))
	_sow(sc, CLAWS, 4, func(c): return sc.is_floor(c))
	_sow(sc, BURNS, 4, func(c): return sc.is_floor(c))
	_sow(sc, ["lava_crack"], 1, func(c): return sc.is_floor(c))
	_sow(sc, ["dragon_scales"], 2, func(c): return sc.is_floor(c))


# ------------------------------------------------------------------ la Sylve des Dracombres

const SYLVE_TILES := "res://assets/tilesets/sylve_tiles.png"
const SYLVE_TILESET := "res://assets/tilesets/sylve_tileset.tres"
const GRASS_W := [[Vector2i(0, 0), 5], [Vector2i(1, 0), 5], [Vector2i(2, 0), 5], [Vector2i(3, 0), 5],
	[Vector2i(4, 0), 3], [Vector2i(5, 0), 3], [Vector2i(6, 0), 3], [Vector2i(7, 0), 3], [Vector2i(6, 2), 1], [Vector2i(7, 2), 1]]
const FLOWER_W := [[Vector2i(0, 1), 1], [Vector2i(1, 1), 1], [Vector2i(2, 1), 1], [Vector2i(3, 1), 1], [Vector2i(0, 0), 2]]
const FOREST_W := [[Vector2i(4, 1), 1], [Vector2i(5, 1), 1], [Vector2i(6, 1), 1], [Vector2i(7, 1), 1]]
const OAKS := ["oak_a", "oak_b", "oak_c"]
const PINES := ["pine_a", "pine_b"]


func _make_sylve_tileset(cave_tex: Texture2D) -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(T, T)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)
	var full := PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])

	var src := TileSetAtlasSource.new()
	src.resource_name = "Sylve"
	src.texture = load(SYLVE_TILES)
	src.texture_region_size = Vector2i(T, T)
	ts.add_source(src, 0)
	for row in 8:
		for x in 8:
			var c := Vector2i(x, row)
			src.create_tile(c)
			# L'eau bloque (sauf le gué, ligne 2).
			if row >= 3 and row <= 5:
				var d := src.get_tile_data(c, 0)
				d.add_collision_polygon(0)
				d.set_collision_polygon_points(0, 0, full)
	# Lisière : sous-bois infranchissable (tuile alternative avec collision).
	var alt := src.create_alternative_tile(Vector2i(4, 1))
	var ad := src.get_tile_data(Vector2i(4, 1), alt)
	ad.add_collision_polygon(0)
	ad.set_collision_polygon_points(0, 0, full)

	# La montagne : les roches de la caverne.
	var rock := TileSetAtlasSource.new()
	rock.resource_name = "Montagne"
	rock.texture = cave_tex
	rock.texture_region_size = Vector2i(T, T)
	ts.add_source(rock, 1)
	for row in [0, 1, 4, 6, 7]:
		for x in 8:
			var c := Vector2i(x, row)
			rock.create_tile(c)
			var d := rock.get_tile_data(c, 0)
			d.y_sort_origin = 8
			d.add_collision_polygon(0)
			d.set_collision_polygon_points(0, 0, full)
	ResourceSaver.save(ts, SYLVE_TILESET, ResourceSaver.FLAG_CHANGE_PATH)
	return load(SYLVE_TILESET)


func _build_sylve(rows: PackedStringArray, cave_tex: Texture2D) -> void:
	var ts := _make_sylve_tileset(cave_tex)
	var h := rows.size()
	var w := rows[0].length()
	var at := func(x: int, y: int) -> String:
		if x < 0 or y < 0 or x >= w or y >= h:
			return "X"
		return rows[y][x]
	var is_rock := func(x: int, y: int) -> bool: return at.call(x, y) == "#" or at.call(x, y) == "M"

	var root := Node2D.new()
	root.name = "Sylve"
	root.y_sort_enabled = true
	root.set_script(load("res://scenes/levels/sylve/sylve.gd"))
	var daylight := CanvasModulate.new()
	daylight.name = "Daylight"
	daylight.color = Color(1, 1, 1)
	_add(root, daylight)
	var ground := TileMapLayer.new()
	ground.name = "Ground"
	ground.tile_set = ts
	ground.z_index = -1
	_add(root, ground)
	var walls := TileMapLayer.new()
	walls.name = "Walls"
	walls.tile_set = ts
	walls.y_sort_enabled = true
	_add(root, walls)
	root.set("bounds_layer", ground)

	var grass := _floor_picker(GRASS_W)
	var flowers := _floor_picker(FLOWER_W)
	var forest := _floor_picker(FOREST_W)
	var special := {}
	for y in h:
		for x in w:
			var ch: String = rows[y][x]
			var cell := Vector2i(x, y)
			match ch:
				"#", "M":
					ground.set_cell(cell, 0, forest.call(cell))
					var mask := 0
					if not is_rock.call(x, y - 1): mask |= 1
					if not is_rock.call(x + 1, y): mask |= 2
					if not is_rock.call(x, y + 1): mask |= 4
					if not is_rock.call(x - 1, y): mask |= 8
					if mask & 4 and not mask & 1:
						var lower_index: int = [4, 6, 12, 14].find(mask & 14)
						walls.set_cell(cell, 1, Vector2i(lower_index * 2 + rng.randi_range(0, 1), 7))
					elif not mask & 4 and not is_rock.call(x, y + 2):
						var bits := (mask & 1) | (2 if mask & 2 else 0) | (4 if mask & 8 else 0)
						walls.set_cell(cell, 1, Vector2i(bits, 6))
					else:
						walls.set_cell(cell, 1, Vector2i(mask % 8, mask / 8))
				"w":
					var m := _side_mask(at, x, y, ["w", "g"])
					ground.set_cell(cell, 0, Vector2i(rng.randi_range(0, 3), 3) if m == 0 else Vector2i(m % 8, 4 + m / 8))
				"g":
					ground.set_cell(cell, 0, Vector2i(4 + rng.randi_range(0, 1), 2))
				"d", "R":
					var m := _side_mask(at, x, y, ["d", "R", "g", "w"])
					ground.set_cell(cell, 0, Vector2i(rng.randi_range(0, 3), 2) if m == 0 else Vector2i(m % 8, 6 + m / 8))
				"f":
					ground.set_cell(cell, 0, forest.call(cell))
				"X":
					ground.set_cell(cell, 0, Vector2i(4, 1), 1)
				",":
					ground.set_cell(cell, 0, flowers.call(cell))
				_:
					ground.set_cell(cell, 0, grass.call(cell))
			if not special.has(ch):
				special[ch] = []
			special[ch].append(cell)

	# Pour le placement des décors : l'eau et la lisière comptent comme de la roche.
	var solid := PackedStringArray()
	for row in rows:
		solid.append(row.replace("w", "#").replace("X", "#").replace("M", "#"))
	var sp := special.duplicate()
	sp["E"] = [sp["Z"][0], sp["R"][0]] + sp["g"].slice(0, 1)
	var sc := _new_scatter(root, solid, sp)
	_decorate_sylve(sc, sp, rows)

	var player := _add_player(root, _feet(sp["P"][0]))
	(player.get_node("HeroLight") as PointLight2D).enabled = false
	_add_enemies(root, sp.get("S", []), "res://scenes/enemies/slime/slime.tscn", "Slime")
	_add_hud(root)
	root.set("rest_point", _feet(sp["Z"][0]))
	root.set("ruins_point", _feet(sp["R"][0]))
	_save(root, SYLVE)


## Côtés d'une case qui ne touchent pas une case du même genre (N=1, E=2, S=4, O=8).
func _side_mask(at: Callable, x: int, y: int, same: Array) -> int:
	var m := 0
	if not same.has(at.call(x, y - 1)): m |= 1
	if not same.has(at.call(x + 1, y)): m |= 2
	if not same.has(at.call(x, y + 1)): m |= 4
	if not same.has(at.call(x - 1, y)): m |= 8
	return m


func _decorate_sylve(sc: Scatter, sp: Dictionary, rows: PackedStringArray) -> void:
	for c in sp.get("d", []):
		sc.keep[c] = true
	for ch in ["P", "Z", "C", "R"]:
		_keep(sc, sp[ch][0], 2)
	for c in sp.get("S", []):
		_keep(sc, c, 1)
	for c in sp.get("g", []):
		_keep(sc, c, 1)

	# L'entrée de la grotte, dans la falaise.
	var mouth: Vector2i = sp["M"][0]
	var mouth_node := _instance_named(sc, "cave_mouth", Vector2(mouth.x * T + T / 2.0, mouth.y * T + T + 3), "CaveMouth")
	mouth_node.scale = Vector2.ONE

	# Les ruines de Dracombra autour du parvis.
	var r: Vector2i = sp["R"][0]
	var ruins := [
		["dragon_head_statue", Vector2i(0, -5)], ["ancient_stairs", Vector2i(0, -3)],
		["ancient_arch", Vector2i(-7, 1)], ["carved_slab", Vector2i(5, 4)],
		["rune_brazier", Vector2i(-3, -3)], ["rune_brazier", Vector2i(3, -3)],
		["stone_wing", Vector2i(-6, 4)], ["carved_tablet", Vector2i(8, -1)],
		["rune_stones", Vector2i(-2, 6)], ["rune_stone", Vector2i(9, 3)],
	]
	for i in 10:
		var a := TAU * i / 10.0
		ruins.append([["pillar", "pillar_broken", "pillar_stump"][i % 3], Vector2i(roundi(cos(a) * 10.0), roundi(sin(a) * 7.0))])
	for item in ruins:
		var base: Vector2i = r + item[1]
		for tries in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(2, 1)]:
			if _place(sc, item[0], base + tries, true):
				break

	# Le grand chêne sous lequel il s'effondrera, et le campement du réveil.
	var z: Vector2i = sp["Z"][0]
	_place(sc, "oak_big", z + Vector2i(-1, -1), true)
	var fire := _instance_named(sc, "campfire", _feet(sp["C"][0]) + Vector2(0, -2), "Campfire")
	var bed := _instance_named(sc, "bedroll", _feet(z) + Vector2(-2, -10), "Bedroll")
	sc.props.get_parent().set("campfire", fire)
	sc.props.get_parent().set("bedroll", bed)

	# La forêt : dense, sans vérifier les passages (elle est hors des chemins).
	sc.check_paths = false
	var forest_cells: Array[Vector2i] = []
	for c in sp.get("f", []):
		forest_cells.append(c)
	_shuffle(forest_cells)
	for c in forest_cells:
		if rng.randf() < 0.55:
			var pick: String = (PINES if rng.randf() < 0.45 else OAKS)[rng.randi() % 2]
			_place(sc, pick, c)
	for c in forest_cells:
		if rng.randf() < 0.12:
			_place(sc, ["bush", "tall_grass", "stump", "flowers_white"][rng.randi() % 4], c)
	# Des pins sur la montagne, au-dessus des falaises.
	for y in rows.size():
		for x in rows[0].length():
			var c := Vector2i(x, y)
			if rows[y][x] == "#" and sc.is_rock(c + Vector2i(0, 1)) and sc.is_rock(c + Vector2i(0, 2)) \
					and sc.is_rock(c + Vector2i(0, 3)) and rng.randf() < 0.45:
				_instance(sc, PINES[rng.randi() % 2], Vector2(x * T + T / 2.0 + rng.randf_range(-4, 4), y * T + T - 2))
	sc.check_paths = true

	# La prairie.
	var meadow := func(c: Vector2i) -> bool: return sc.is_floor(c) and (rows[c.y][c.x] == "." or rows[c.y][c.x] == ",")
	_sow(sc, OAKS, 70, meadow)
	_sow(sc, PINES, 20, meadow)
	_sow(sc, ["bush", "bush", "bush_berries"], 60, meadow)
	_sow(sc, ["rock_grey", "rock_grey", "rock_grey_big"], 35, meadow)
	_sow(sc, ["log", "stump"], 22, meadow)
	sc.check_paths = false
	_sow(sc, ["flowers_white", "flowers_yellow", "flowers_pink"], 260, meadow)
	_sow(sc, ["tall_grass", "tall_grass_b"], 260, meadow)
	_sow(sc, ["mushrooms"], 10, func(c): return rows[c.y][c.x] == "f")


func _instance_named(sc: Scatter, prop_name: String, at: Vector2, node_name: String) -> Node2D:
	var node: Node2D = (prop_scenes[prop_name] as PackedScene).instantiate()
	node.position = at
	node.name = node_name
	sc.props.add_child(node)
	node.owner = sc.props.owner
	return node


func _save(root: Node, path: String) -> void:
	var packed := PackedScene.new()
	var err := packed.pack(root)
	assert(err == OK)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	ResourceSaver.save(packed, path)
	root.free()


func _add(root: Node, child: Node) -> void:
	root.add_child(child)
	child.owner = root


func _weighted(weights: Array) -> int:
	var total := 0
	for v in weights:
		total += v
	var r := rng.randi_range(1, total)
	for i in weights.size():
		r -= weights[i]
		if r <= 0:
			return i
	return 0
