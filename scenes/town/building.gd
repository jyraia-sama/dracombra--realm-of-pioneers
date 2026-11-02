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
	_sprite.scale = Vector2(0.5, 0.5)  # dessins HD
	_sprite.centered = false
	add_child(_sprite)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 8)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 3)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.size = Vector2(170, 12)
	_label.position = Vector2(-85, 2)
	# Au-dessus des décors (un pilier devant le chantier cachait le texte).
	_label.z_index = 50
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
		_interact.enabled = data.can_sleep or station or data.job != &"" or data.id == &"warehouse"
		if data.id == &"warehouse":
			var total := 0
			for k in Town.warehouse:
				total += int(Town.warehouse[k])
			_label.text = "Entrepôt · %d objets" % total
		if data.job != &"":
			var stock: Dictionary = record.get("stock", {})
			var n := Roster.workers_of(int(record["uid"])).size()
			_label.text = "%s · %d/%d trav.%s" % [data.display_name, n, data.workers,
				(" · " + _stock_text(stock)) if not stock.is_empty() else ""]
	elif need.is_empty():
		_label.text = "%s : %d / %d jours" % [data.display_name, int(record["days"]), data.build_days]
		_interact.enabled = false
	else:
		_label.text = "%s : %s" % [data.display_name, cost_text(need)]
		_interact.prompt = "Déposer les matériaux"
		_interact.enabled = true


func _on_interacted() -> void:
	if record["built"]:
		if data.id == &"warehouse":
			await _warehouse_menu()
			refresh()
			return
		if data.job != &"":
			await _workplace_menu()
			refresh()
			return
		if data.can_sleep:
			var i := await Choice.ask(data.display_name, "Dormir jusqu'au lendemain ?", ["Dormir", "Annuler"])
			if i == 0:
				Game.sleep()
		elif Crafting.STATION_NAMES.has(data.id):
			Crafting.open(data.id)
		return
	var need := Town.missing(data.cost, record["delivered"])
	var have := {}
	for id in need:
		var n := mini(int(need[id]), Town.amount_of(id))
		if n > 0:
			have[id] = n
	if not have.is_empty():
		var body := "Déposer %s ?" % cost_text(have)
		var rest := _minus(need, have)
		if not rest.is_empty():
			body += "\nIl faudra encore : %s." % cost_text(rest)
		var j := await Choice.ask("Chantier : %s" % data.display_name, body, ["Déposer", "Annuler"])
		if j != 0:
			return
	if Town.deliver(data.cost, record["delivered"]) == 0:
		Emote.show(get_tree().get_first_node_in_group("player"), "?", Color(1, 0.85, 0.4))
		Narration.say("Il manque : %s." % cost_text(Town.missing(data.cost, record["delivered"])), 2.2)
	elif Town.missing(data.cost, record["delivered"]).is_empty():
		Narration.say("Tout est là. Le chantier avancera chaque jour : dormez pour le voir grandir.", 3.0)
	refresh()


static func _stock_text(stock: Dictionary) -> String:
	var d := {}
	for k in stock:
		if int(stock[k]) > 0:
			d[StringName(k)] = int(stock[k])
	return cost_text(d)


## Bâtiment de travail : récupérer le stock, affecter ou retirer des travailleurs.
func _workplace_menu() -> void:
	while true:
		var uid := int(record["uid"])
		var stock: Dictionary = record.get("stock", {})
		var workers := Roster.workers_of(uid)
		var names: Array[String] = []
		for m in workers:
			names.append("%s (%s)" % [m["name"], Roster.specialty(m)])
		var body := "%s\nTravailleurs (%d/%d) : %s.\nProduction par travailleur et par jour : %s." % [data.description,
			workers.size(), data.workers, ", ".join(names) if not names.is_empty() else "personne",
			cost_text(data.produces)]
		var options: Array[String] = []
		var acts: Array = []
		var has_stock := not _stock_text(stock).is_empty()
		if has_stock:
			options.append("Récupérer : %s" % _stock_text(stock))
			acts.append(["take"])
		for m in Roster.living():
			if m["kind"] == "artisan" and String(m["job"]) == String(data.job) and int(m.get("work", 0)) != uid \
					and workers.size() < data.workers:
				options.append("Affecter %s (%s)" % [m["name"], Roster.specialty(m)])
				acts.append(["add", int(m["id"])])
		for m in workers:
			options.append("Retirer %s du travail" % m["name"])
			acts.append(["remove", int(m["id"])])
		options.append("Fermer")
		acts.append(["close"])
		var i := await Choice.ask(data.display_name, body, options)
		if i < 0 or acts[i][0] == "close":
			return
		match acts[i][0]:
			"take":
				var got := {}
				for k in stock:
					var n := int(stock[k])
					if n > 0:
						var item := Inventory.item_by_id(StringName(k))
						if item:
							Inventory.add_item(item, n)
							got[StringName(k)] = n
				record["stock"] = {}
				Narration.say("Récupéré : %s." % cost_text(got), 2.0)
			"add":
				Roster.assign(Roster.by_id(acts[i][1]), uid)
			"remove":
				Roster.unassign(Roster.by_id(acts[i][1]))
		refresh()


## Entrepôt : voir le stock, y déposer les ressources du sac, en retirer.
func _warehouse_menu() -> void:
	while true:
		var ids: Array = Town.warehouse.keys()
		ids.sort()
		var lines: Array[String] = []
		for k in ids:
			var item := Inventory.item_by_id(StringName(k))
			lines.append("%s ×%d" % [item.display_name if item else k, int(Town.warehouse[k])])
		var body := "Stock : %s.\nL'établi, la forge et les chantiers puisent ici directement." % (", ".join(lines) if not lines.is_empty() else "vide")
		var options: Array[String] = ["Déposer toutes mes ressources", "Retirer un objet", "Fermer"]
		var i := await Choice.ask("Entrepôt", body, options)
		match i:
			0:
				var moved := {}
				for item in Inventory.get_items():
					if item.category == &"resource":
						var n := Inventory.get_count(item.id)
						Inventory.remove_item(item, n)
						Town.store(item.id, n)
						moved[item.id] = n
				Narration.say("Déposé : %s." % cost_text(moved) if not moved.is_empty() else "Rien à déposer.", 2.0)
			1:
				if ids.is_empty():
					continue
				var opts: Array[String] = []
				for k in ids:
					var item := Inventory.item_by_id(StringName(k))
					opts.append("%s ×%d" % [item.display_name if item else k, int(Town.warehouse[k])])
				opts.append("Retour")
				var j := await Choice.ask("Retirer", "Quel objet ?", opts)
				if j < 0 or j >= ids.size():
					continue
				var id := StringName(ids[j])
				var have := int(Town.warehouse[ids[j]])
				var amounts: Array[int] = []
				for n in [1, 5, 10]:
					if n < have:
						amounts.append(n)
				amounts.append(have)
				var aopts: Array[String] = []
				for n in amounts:
					aopts.append("%s%d" % ["Tout : " if n == have else "", n])
				aopts.append("Retour")
				var k := await Choice.ask("Retirer", "Combien ?", aopts)
				if k >= 0 and k < amounts.size():
					Town.consume_from_warehouse(id, amounts[k])
					Inventory.add_item(Inventory.item_by_id(id), amounts[k])
			_:
				return
		refresh()


static func _minus(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := {}
	for id in a:
		var left := int(a[id]) - int(b.get(id, 0))
		if left > 0:
			out[id] = left
	return out


## « 3 bois, 2 pierre »
static func cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for id in cost:
		var item := Inventory.item_by_id(id)
		parts.append("%d %s" % [int(cost[id]), item.display_name.to_lower() if item else String(id)])
	return ", ".join(parts)
