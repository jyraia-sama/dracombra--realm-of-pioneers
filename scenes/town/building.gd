class_name Building
extends Node2D
## Un bâtiment posé à Dracombra, ou son chantier tant qu'il n'est pas terminé.
## Créé par TownLayer à partir d'un enregistrement de Town.sites.

const SCAFFOLD := preload("res://assets/sprites/buildings/scaffold.png")

var data: BuildingData
var record: Dictionary

var _sprite: Sprite2D
var _label: Label
var _interact: Interactable


## Le pied du bâtiment est au bas de son emprise ; l'emprise est centrée sur la case.
static func footprint_rect(building: BuildingData, cell: Vector2i) -> Rect2:
	var t := float(Game.TILE_SIZE)
	var size := Vector2(building.size) * t
	var left := (cell.x - (building.size.x - 1) / 2) * t
	var top := (cell.y - building.size.y + 1) * t
	return Rect2(Vector2(left, top), size)


func setup(building: BuildingData, site: Dictionary) -> void:
	data = building
	record = site
	var rect := footprint_rect(data, Town.site_cell(record))
	position = Vector2(rect.get_center().x, rect.end.y)

	var body := StaticBody2D.new()
	body.name = "Body"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size - Vector2(2, 2)
	shape.shape = box
	shape.position = Vector2(0, -rect.size.y / 2.0)
	body.add_child(shape)
	add_child(body)

	_sprite = Sprite2D.new()
	_sprite.centered = false
	add_child(_sprite)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 8)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 3)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.size = Vector2(80, 12)
	_label.position = Vector2(-40, 2)
	add_child(_label)

	_interact = Interactable.new()
	_interact.radius_tiles = 1.2 + maxf(data.size.x, data.size.y) * 0.5
	_interact.position = Vector2(0, -rect.size.y / 2.0)
	add_child(_interact)
	_interact.interacted.connect(_on_interacted)
	refresh()


func refresh() -> void:
	var built: bool = record["built"]
	_sprite.texture = data.texture if built else SCAFFOLD
	if _sprite.texture:
		_sprite.offset = Vector2(-_sprite.texture.get_width() / 2.0, -_sprite.texture.get_height())
	var need := Town.missing(data.cost, record["delivered"])
	if built:
		_label.text = ""
		var station := Crafting.STATION_NAMES.has(data.id)
		_interact.prompt = "Dormir" if data.can_sleep else data.display_name
		_interact.enabled = data.can_sleep or station
	elif need.is_empty():
		_label.text = "%s : %d / %d jours" % [data.display_name, int(record["days"]), data.build_days]
		_interact.enabled = false
	else:
		_label.text = "%s : %s" % [data.display_name, cost_text(need)]
		_interact.prompt = "Déposer les matériaux"
		_interact.enabled = true


func _on_interacted() -> void:
	if record["built"]:
		if data.can_sleep:
			Game.sleep()
		elif Crafting.STATION_NAMES.has(data.id):
			Crafting.open(data.id)
		return
	if Town.deliver(data.cost, record["delivered"]) == 0:
		Emote.show(get_tree().get_first_node_in_group("player"), "?", Color(1, 0.85, 0.4))
		Narration.say("Il manque : %s." % cost_text(Town.missing(data.cost, record["delivered"])), 2.2)
	elif Town.missing(data.cost, record["delivered"]).is_empty():
		Narration.say("Tout est là. Le chantier avancera chaque jour : dormez pour le voir grandir.", 3.0)
	refresh()


## « 3 bois, 2 pierre »
static func cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for id in cost:
		var item := Inventory.item_by_id(id)
		parts.append("%d %s" % [int(cost[id]), item.display_name.to_lower() if item else String(id)])
	return ", ".join(parts)
