class_name GroundPainter
extends Sprite2D
## Remplace l'affichage du calque Ground par un sol aux bords organiques (shader
## organic_ground). Le calque reste en place, invisible : il garde les collisions (eau,
## lisière), la carte, la construction... Seul le dessin change.
##
## Chaque tuile est rangée dans un « matériau » (herbe, terre, eau...). Les tuiles de bord
## dessinées dans l'atlas (berges, bords de chemin) sont remplacées par la tuile pleine :
## c'est le shader qui dessine les bords, en ondulant.

const SHADER := preload("res://assets/shaders/organic_ground.gdshader")

enum Mat { NONE, GRASS, FOREST, DIRT, WATER, FORD, PAVING, SLABS, RUBBLE, ROCK, CAVE, LAIR }

## Petits décors déplacés de quelques pixels, pour casser l'alignement sur la grille.
const JITTER_PREFIXES := ["Deco", "TallGrass", "Bush", "Flowers", "FlaxPlant", "Mushroom", "Herb", "Fern", "Pebble", "Stone"]

var _layer: TileMapLayer
var _walls: TileMapLayer

## Couleurs des falaises et du sol de grotte selon le lieu.
const LOOKS := {
	&"sylve": {"rock_top": Color8(58, 82, 48), "rock_top_light": Color8(70, 96, 54),
		"rock_face": Color8(132, 124, 112), "rock_face_dark": Color8(98, 90, 84), "rock_face_light": Color8(168, 160, 142)},
	&"cave": {"rock_top": Color8(34, 30, 42), "rock_top_light": Color8(44, 40, 54),
		"rock_face": Color8(104, 94, 112), "rock_face_dark": Color8(76, 68, 86), "rock_face_light": Color8(140, 128, 146),
		"cave_floor": Color8(110, 94, 88), "cave_floor_dark": Color8(98, 82, 78), "cave_floor_light": Color8(122, 106, 98)},
}


## Pose le sol organique sous `layer`. tileset_kind : &"sylve" ou &"city".
## walls : facultatif, le calque des falaises (roche), dessinées elles aussi.
static func apply(level: Node2D, layer: TileMapLayer, tileset_kind: StringName, walls: TileMapLayer = null) -> GroundPainter:
	var p := GroundPainter.new()
	p.name = "OrganicGround"
	p._layer = layer
	p._walls = walls
	p._build(tileset_kind)
	level.add_child(p)
	level.move_child(p, layer.get_index() + 1)
	layer.self_modulate.a = 0.0
	if walls:
		walls.self_modulate.a = 0.0
	_jitter_props(level)
	return p


func _build(kind: StringName) -> void:
	var used := _layer.get_used_rect()
	if _walls:
		used = used.merge(_walls.get_used_rect())
	var img := Image.create(used.size.x, used.size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for cell in _layer.get_used_cells():
		var src := _layer.get_cell_source_id(cell)
		var at := _layer.get_cell_atlas_coords(cell)
		var picked := _classify(kind, src, at, rng)
		var mat: int = picked[0]
		var coords: Vector2i = picked[1]
		var c := cell - used.position
		img.set_pixel(c.x, c.y, Color8(src, coords.x, coords.y, mat + 1 if mat != Mat.NONE else 0))
	if _walls:
		for cell in _walls.get_used_cells():
			var c := cell - used.position
			img.set_pixel(c.x, c.y, Color8(0, 0, 0, Mat.ROCK + 1))
	texture = ImageTexture.create_from_image(img)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	centered = false
	var t := _layer.tile_set.tile_size
	scale = Vector2(t)
	position = _layer.position + Vector2(used.position * t)
	z_index = _layer.z_index
	var sm := ShaderMaterial.new()
	sm.shader = SHADER
	sm.set_shader_parameter("tile", t.x)
	sm.set_shader_parameter("types", texture)
	for i in 2:
		var source := _layer.tile_set.get_source(_layer.tile_set.get_source_id(i)) as TileSetAtlasSource \
			if i < _layer.tile_set.get_source_count() else null
		if source:
			sm.set_shader_parameter("atlas%d" % _layer.tile_set.get_source_id(i), source.texture)
	var look: Dictionary = LOOKS.get(kind, {})
	sm.set_shader_parameter("face_height", 22 if kind == &"cave" else 18)
	for key in look:
		var col: Color = look[key]
		sm.set_shader_parameter(key, Vector3(col.r, col.g, col.b))
	material = sm
	# Découpe en morceaux de 12 x 12 cases : Godot n'applique qu'un nombre limité de
	# lumières à chaque objet dessiné. Un seul grand sol recevait toutes les lumières du
	# niveau (cristaux, braises), et celle du héros finissait par sauter.
	_split_in_chunks(used.size, sm)


const CHUNK := 12


func _split_in_chunks(cells: Vector2i, sm: ShaderMaterial) -> void:
	var tex := texture
	texture = null
	for cy in range(0, cells.y, CHUNK):
		for cx in range(0, cells.x, CHUNK):
			var part := Sprite2D.new()
			part.texture = tex
			part.centered = false
			part.region_enabled = true
			part.region_rect = Rect2(cx, cy, mini(CHUNK, cells.x - cx), mini(CHUNK, cells.y - cy))
			part.position = Vector2(cx, cy)
			part.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			part.material = sm
			add_child(part)
	material = null


## [matériau, coordonnées de la tuile à dessiner].
func _classify(kind: StringName, src: int, at: Vector2i, rng: RandomNumberGenerator) -> Array:
	if kind != &"cave" and src == 0:
		# Atlas de la Sylve (aussi utilisé pour l'herbe de Dracombra).
		match at.y:
			0:
				return [Mat.GRASS, at]
			1:
				return [Mat.GRASS if at.x < 4 else Mat.FOREST, at]
			2:
				if at.x < 4:
					return [Mat.DIRT, at]
				if at.x < 6:
					return [Mat.FORD, at]
				return [Mat.GRASS, at]
			3:
				return [Mat.WATER, at]
			4, 5:
				return [Mat.WATER, Vector2i(rng.randi_range(0, 3), 3)]
			6, 7:
				return [Mat.DIRT, Vector2i(rng.randi_range(0, 3), 2)]
	elif kind == &"cave":
		return [Mat.LAIR if at.y == 5 else Mat.CAVE, at]
	elif kind == &"city" and src == 1:
		match at.y:
			0, 1:
				return [Mat.PAVING, at]
			2:
				return [Mat.SLABS, at]
			3:
				return [Mat.RUBBLE, at]
	return [Mat.NONE, at]


## Décale légèrement les petits décors (herbes hautes, fleurs, buissons) : ils ne sont
## plus tous au centre de leur case. Décalage fixe (calculé d'après le nom).
static func _jitter_props(level: Node2D) -> void:
	var props := level.get_node_or_null("Props")
	if props == null:
		return
	for p in props.get_children():
		var n2 := p as Node2D
		if n2 == null:
			continue
		var name := String(p.name)
		var ok := false
		for prefix in JITTER_PREFIXES:
			if name.begins_with(prefix):
				ok = true
				break
		if not ok:
			continue
		var h := absi(name.hash())
		n2.position += Vector2(float(h % 11) - 5.0, float((h / 11) % 9) - 4.0)
