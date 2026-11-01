class_name LevelMap
extends RefCounted
## Image de la carte du niveau courant : une couleur par case (sol, murs, eau...).
## Utilisée par la carte du menu et par la mini-carte du HUD.
##
## Brouillard : si le niveau a une méthode `map_hidden_rects() -> Array[Rect2i]`
## (en cases), ces zones sont masquées (salles du donjon pas encore visitées).

static var _color_cache := {}


## Renvoie {"image": Image, "rect": Rect2i (cases couvertes), "painted": bool} ou {}.
static func build(scene: Node) -> Dictionary:
	if scene == null:
		return {}
	var layers: Array[TileMapLayer] = []
	for n in ["Ground", "Walls"]:
		var l := scene.get_node_or_null(n) as TileMapLayer
		if l:
			layers.append(l)
	if layers.is_empty():
		return {}
	var rect := layers[0].get_used_rect()
	for l in layers:
		rect = rect.merge(l.get_used_rect())
	if rect.size.x <= 0 or rect.size.y <= 0:
		return {}
	var img := Image.create(rect.size.x, rect.size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.05, 0.05, 0.07))
	# Le sol dessiné (bords naturels, falaises) donne les vraies couleurs ; sinon, les tuiles.
	var painter := scene.get_node_or_null("OrganicGround") as GroundPainter
	var painted: Image = painter.cell_colors() if painter else null
	if painted:
		var at := painter.origin_cell - rect.position
		for y in painted.get_height():
			for x in painted.get_width():
				var c := painted.get_pixel(x, y)
				var p := Vector2i(x, y) + at
				if c.a > 0.5 and p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height():
					img.set_pixelv(p, Color(c.r, c.g, c.b))
	else:
		for l in layers:
			for cell in l.get_used_cells():
				var col := tile_color(l, cell)
				if col.a > 0.0:
					img.set_pixelv(cell - rect.position, col)
	# Les arbres et les décors qui bloquent assombrissent la carte.
	var props := scene.get_node_or_null("Props")
	if props:
		var t := float(Game.TILE_SIZE)
		for p in props.get_children():
			if p is Node2D and p.visible and p.get_node_or_null("Body") != null:
				var c := Vector2i(floori(p.global_position.x / t), floori((p.global_position.y - 1.0) / t)) - rect.position
				if c.x >= 0 and c.y >= 0 and c.x < img.get_width() and c.y < img.get_height():
					img.set_pixelv(c, img.get_pixelv(c).darkened(0.35))
	return {"image": img, "rect": rect, "painted": painted != null or painter == null}


## Zones à masquer (brouillard), en cases.
static func hidden_rects(scene: Node) -> Array:
	if scene and scene.has_method("map_hidden_rects"):
		return scene.map_hidden_rects()
	return []


static func tile_color(layer: TileMapLayer, cell: Vector2i) -> Color:
	var src := layer.get_cell_source_id(cell)
	var coords := layer.get_cell_atlas_coords(cell)
	var key := "%s:%d:%s" % [layer.tile_set.resource_path, src, coords]
	if _color_cache.has(key):
		return _color_cache[key]
	var col := Color(0, 0, 0, 0)
	var atlas := layer.tile_set.get_source(src) as TileSetAtlasSource
	if atlas and atlas.texture:
		var img := atlas.texture.get_image()
		var region := atlas.get_tile_texture_region(coords)
		var sum := Vector3.ZERO
		var n := 0
		for y in range(region.position.y, region.end.y, 2):
			for x in range(region.position.x, region.end.x, 2):
				var c := img.get_pixel(x, y)
				if c.a > 0.5:
					sum += Vector3(c.r, c.g, c.b)
					n += 1
		if n > 0:
			sum /= n
			col = Color(sum.x, sum.y, sum.z)
	_color_cache[key] = col
	return col
