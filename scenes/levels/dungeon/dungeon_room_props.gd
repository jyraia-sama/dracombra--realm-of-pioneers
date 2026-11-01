class_name DungeonRoomProps
extends RefCounted
## Le contenu des salles spéciales du donjon : feu de camp (repos), marchand ambulant,
## coffre au trésor, filons de ressources. Chaque fonction renvoie un nœud prêt à poser.

const CAMPFIRE := preload("res://scenes/props/sylve/campfire.tscn")
const GEM_ROCK := preload("res://scenes/props/sylve/gem_rock.tscn")
const ROCK := preload("res://scenes/props/sylve/rock_grey.tscn")
const ROCK_BIG := preload("res://scenes/props/sylve/rock_grey_big.tscn")
const CRYSTAL := preload("res://scenes/props/cave/crystal_purple_large.tscn")
const CRYSTAL_BLUE := preload("res://scenes/props/cave/crystal_blue_large.tscn")
const CHEST_TEX := preload("res://assets/sprites/buildings/chest.png")
const MERCHANT_TEX := preload("res://assets/sprites/npc/marchand/marchand.png")
const PICKUP := preload("res://scenes/items/pickup.tscn")

## Ce que vend le marchand : [objet, prix en or].
const SHOP := [[&"potion_heal", 25], [&"balm", 10]]
## Ce qu'il rachète : [objet, prix en or par unité].
const BUYBACK := [[&"slime_gel", 2], [&"obsidian_shard", 3], [&"gem", 8]]


# ------------------------------------------------------------------ repos

## Feu de camp : se reposer une fois rend tous les PV, l'endurance et le mana.
static func campfire() -> Node2D:
	var fire: Node2D = CAMPFIRE.instantiate()
	var body := fire.get_node_or_null("Body")
	if body:
		fire.remove_child(body)
		body.free()
	var it := Interactable.new()
	it.prompt = "Se reposer"
	it.radius_tiles = 2.0
	fire.add_child(it)
	it.interacted.connect(func() -> void:
		var i := await Choice.ask("Feu de camp", "Se reposer un moment près des flammes ?\n(PV, endurance et mana au maximum, une seule fois.)", ["Se reposer", "Plus tard"])
		if i != 0:
			return
		var player := fire.get_tree().get_first_node_in_group("player") as Player
		await Transition.fade_out(0.4)
		if player:
			player.health.heal(player.health.max_health)
		Hero.refill_energy()
		it.enabled = false
		it.prompt = "Braises"
		await Transition.fade_in(0.4)
		Narration.say("Reposé. Le feu n'est plus que braises.", 2.0))
	return fire


# ------------------------------------------------------------------ marchand ambulant

static func merchant() -> Node2D:
	var m := Node2D.new()
	m.name = "Marchand"
	m.add_to_group("npc")
	var sheet := SheetAnimation.load_sheet("res://assets/sprites/npc/marchand/marchand.json")
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	SheetAnimation.apply_to(sprite, MERCHANT_TEX, sheet)
	m.add_child(sprite)
	# Petite respiration (2 images de l'animation « idle », face).
	var anims := SheetAnimation.anims_from(sheet)
	var t := Timer.new()
	t.wait_time = 0.45
	t.autostart = true
	m.add_child(t)
	var frame := [0]
	t.timeout.connect(func() -> void:
		frame[0] = (frame[0] + 1) % int(anims[&"idle"][1])
		sprite.frame = int(anims[&"idle"][0]) * sprite.hframes + frame[0])
	var it := Interactable.new()
	it.prompt = "Parler au marchand"
	it.radius_tiles = 1.8
	m.add_child(it)
	it.interacted.connect(func() -> void: shop(m))
	return m


static func shop(_m: Node) -> void:
	while true:
		var gold := Inventory.get_count(&"gold")
		var options: Array[String] = []
		for entry in SHOP:
			var item := Inventory.item_by_id(entry[0])
			options.append("Acheter : %s — %d or" % [item.display_name, int(entry[1])])
		options.append("Vendre mon butin")
		options.append("Au revoir")
		var i := await Choice.ask("Marchand ambulant", "« Des potions, des baumes... et je rachète ce que tu trouves en bas. »\nVous avez %d pièces d'or." % gold, options)
		if i < 0 or i >= options.size() - 1:
			return
		if i < SHOP.size():
			var item := Inventory.item_by_id(SHOP[i][0])
			var price: int = SHOP[i][1]
			if gold < price:
				Narration.say("Pas assez d'or (%d / %d)." % [gold, price], 1.8)
				continue
			Inventory.remove_item(Inventory.item_by_id(&"gold"), price)
			Inventory.add_item(item, 1)
			Narration.say("%s achetée." % item.display_name if item.id == &"potion_heal" else "%s acheté." % item.display_name, 1.5)
		else:
			await _sell()


## Vente : choisir l'objet, puis la quantité (1, 5, 10 ou tout). B / Échap revient en arrière.
static func _sell() -> void:
	while true:
		var options: Array[String] = []
		var ids: Array[StringName] = []
		for entry in BUYBACK:
			var n := Inventory.get_count(entry[0])
			if n <= 0:
				continue
			var item := Inventory.item_by_id(entry[0])
			ids.append(entry[0])
			options.append("%s ×%d — %d or pièce" % [item.display_name, n, int(entry[1])])
		if ids.is_empty():
			Narration.say("« Rien qui m'intéresse pour l'instant. »", 2.0)
			return
		options.append("Retour")
		var i := await Choice.ask("Vendre", "Le marchand rachète la gelée de slime, les éclats d'obsidienne et les gemmes.", options)
		if i < 0 or i >= ids.size():
			return
		await _sell_amount(ids[i])


static func _sell_amount(id: StringName) -> void:
	var item := Inventory.item_by_id(id)
	var price := 0
	for entry in BUYBACK:
		if entry[0] == id:
			price = entry[1]
	var have := Inventory.get_count(id)
	var amounts: Array[int] = []
	for n in [1, 5, 10]:
		if n < have:
			amounts.append(n)
	amounts.append(have)
	var options: Array[String] = []
	for n in amounts:
		options.append("%s%d — %d or" % ["Tout : " if n == have else "", n, n * price])
	options.append("Retour")
	var i := await Choice.ask("Vendre : %s" % item.display_name, "Vous en avez %d. Combien en vendre ?" % have, options)
	if i < 0 or i >= amounts.size():
		return
	var n: int = amounts[i]
	Inventory.remove_item(item, n)
	Inventory.add_item(Inventory.item_by_id(&"gold"), n * price)
	Narration.say("Vendu : %d %s (+%d or)." % [n, item.display_name.to_lower(), n * price], 1.8)


# ------------------------------------------------------------------ trésor

## Coffre : de l'or, des ressources, parfois une potion. floor : étage (plus de butin en bas).
static func chest(floor_number: int) -> Node2D:
	var c := Node2D.new()
	c.name = "Coffre"
	var sprite := Sprite2D.new()
	sprite.texture = CHEST_TEX
	sprite.scale = Vector2(0.5, 0.5)
	sprite.centered = false
	sprite.offset = Vector2(-CHEST_TEX.get_width() / 2.0, -CHEST_TEX.get_height())
	sprite.name = "Sprite2D"
	c.add_child(sprite)
	var light := PointLight2D.new()
	light.texture = preload("res://assets/lights/light_radial.tres")
	light.color = Color(1.0, 0.85, 0.45)
	light.texture_scale = 0.9
	light.energy = 0.8
	light.position = Vector2(0, -8)
	c.add_child(light)
	var it := Interactable.new()
	it.prompt = "Ouvrir le coffre"
	it.radius_tiles = 1.6
	c.add_child(it)
	it.interacted.connect(func() -> void:
		it.enabled = false
		light.enabled = false
		sprite.modulate = Color(0.6, 0.55, 0.5)
		Fx.squash(sprite as Node2D, Vector2(1.2, 0.85), 0.2)
		var loot := [[&"gold", 10 + 6 * floor_number, 20 + 10 * floor_number],
			[&"gem", 1, 2], [&"obsidian_shard", 2, 4]]
		if randf() < 0.5:
			loot.append([&"potion_heal", 1, 1])
		# Une chance sur trois de trouver une pièce d'équipement du palier 1.
		if randf() < 0.33:
			drop(c, Loot.piece(1, [45, 35, 20]), 1, c.global_position + Vector2(0, 6))
		for entry in loot:
			var item := Inventory.item_by_id(entry[0])
			if item == null:
				continue
			var n := randi_range(entry[1], entry[2])
			drop(c, item, n, c.global_position + Vector2(0, 6))
		Narration.say("Un coffre oublié des anciens !", 1.8))
	return c


## Fait jaillir `count` objets au sol (l'or par piles de 5 pour ne pas en semer 50).
static func drop(from: Node, item: ItemData, count: int, at: Vector2) -> void:
	var scene := from.get_tree().current_scene
	var piles := ceili(count / 5.0) if item.id == &"gold" else count
	var left := count
	for i in piles:
		var p: Pickup = PICKUP.instantiate()
		p.item = item
		p.amount = mini(5, left) if item.id == &"gold" else 1
		left -= p.amount
		p.position = at + Vector2.from_angle(randf() * TAU) * randf_range(4.0, 14.0)
		scene.add_child.call_deferred(p)
		p.ready.connect(p.pop_from.bind(at), CONNECT_ONE_SHOT)


# ------------------------------------------------------------------ filons

## Filon tiré au hasard : pierre, gemme ou cristal d'obsidienne. Pas de collision, pas de
## mémoire d'un jour à l'autre (persistent = false).
## Filon tiré au hasard, en grand format et signalé par un OreMarker (étincelles + icône).
## Pas de collision, pas de mémoire d'un passage à l'autre (persistent = false).
static func ore(rng: RandomNumberGenerator) -> Node2D:
	var roll := rng.randf()
	var node: Node2D
	var color := Color.WHITE
	var height := 22.0
	if roll < 0.3:
		# Filon de fer : gros rocher veiné de rouille (teinte provisoire).
		node = ROCK_BIG.instantiate()
		node.scale = Vector2(1.5, 1.5)
		(node.get_node("Sprite2D") as CanvasItem).modulate = Color(1.0, 0.68, 0.5)
		_set_harvest(node, &"iron_ore", 1, 2, 4)
		color = Color(1.0, 0.6, 0.3)
	elif roll < 0.5:
		node = CRYSTAL_BLUE.instantiate()
		_add_harvest(node, &"mana_crystal", 1, 2, 3)
		color = Color(0.5, 0.85, 1.0)
		height = 28.0
	elif roll < 0.72:
		node = CRYSTAL.instantiate()
		_add_harvest(node, &"obsidian_shard", 1, 3, 3)
		color = Color(0.8, 0.55, 1.0)
		height = 28.0
	elif roll < 0.88:
		node = ROCK_BIG.instantiate()
		node.scale = Vector2(1.5, 1.5)
		color = Color(0.85, 0.85, 0.9)
	else:
		node = GEM_ROCK.instantiate()
		node.scale = Vector2(1.5, 1.5)
		color = Color(0.5, 0.9, 1.0)
	var body := node.get_node_or_null("Body")
	if body:
		node.remove_child(body)
		body.free()
	var item_id := &""
	for c in node.get_children():
		if c is Harvestable:
			(c as Harvestable).persistent = false
			(c as Harvestable).regrow_days = 0
			item_id = (c as Harvestable).item_id
	var marker := OreMarker.new()
	marker.name = "OreMarker"
	marker.color = color
	marker.height = height / node.scale.y
	var item := Inventory.item_by_id(item_id)
	marker.icon = item.icon if item else null
	node.add_child(marker)
	return node


static func _add_harvest(node: Node2D, item: StringName, lo: int, hi: int, hits: int) -> void:
	var h := Harvestable.new()
	h.name = "Harvest"
	node.add_child(h)
	_set_harvest(node, item, lo, hi, hits)


static func _set_harvest(node: Node2D, item: StringName, lo: int, hi: int, hits: int) -> void:
	var h := node.get_node("Harvest") as Harvestable
	h.item_id = item
	h.min_amount = lo
	h.max_amount = hi
	h.hits = hits
	h.hit_size = Vector2(16, 16)
