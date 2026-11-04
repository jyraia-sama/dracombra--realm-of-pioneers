class_name Guild
extends Node2D
## Le cœur de Dracombra : d'abord un simple feu de camp, puis la tente de guilde,
## la maison, le hall et enfin la citadelle. On l'améliore ici même.

## Un sprite par palier (feu de camp, tente, maison, hall, citadelle).
const TEXTURES: Array[Texture2D] = [
	preload("res://assets/sprites/buildings/guild_0.png"), preload("res://assets/sprites/buildings/guild_1.png"),
	preload("res://assets/sprites/buildings/guild_2.png"), preload("res://assets/sprites/buildings/guild_3.png"),
	preload("res://assets/sprites/buildings/guild_4.png"),
]
## Partie solide de chaque palier, en cases, contre le fond des 4 × 4 réservés : la cour devant
## la porte reste praticable.
const FOOTPRINTS: Array[Vector2] = [Vector2(3.0, 1.6), Vector2(3.0, 1.8), Vector2(3.6, 2.0), Vector2(3.8, 2.2), Vector2(3.8, 2.5)]
## Ligne de façade (tri avec le héros), en cases au-dessus du bas de l'emprise.
const FACADE := 1.8
## Le feu de camp du palier 0, par rapport au pied de la guilde (dessin guild_0).
const CAMPFIRE := Vector2(-13, -22)

var _visual: Node2D
var _body: StaticBody2D
var _shape: RectangleShape2D
var _interact: Interactable


func _ready() -> void:
	add_to_group("guild")
	y_sort_enabled = true
	# Calée sur la grille : son emprise de 4 × 4 cases (Town.guild_cells) tombe pile sur les cases.
	var t := float(Game.TILE_SIZE)
	position = Vector2(floorf(position.x / t), roundf(position.y / t)) * t
	_body = StaticBody2D.new()
	_body.collision_layer = 1
	_body.collision_mask = 0
	var cs := CollisionShape2D.new()
	_shape = RectangleShape2D.new()
	cs.shape = _shape
	_body.add_child(cs)
	add_child(_body)
	_interact = Interactable.new()
	_interact.prompt = "Guilde"
	add_child(_interact)
	_interact.interacted.connect(_on_interacted)
	Town.changed.connect(refresh)
	refresh()


func refresh() -> void:
	if _visual != null:
		_visual.queue_free()
	var t := float(Game.TILE_SIZE)
	var tier: int = clampi(Town.tier, 0, TEXTURES.size() - 1)
	var root := Node2D.new()
	var sprite := Sprite2D.new()
	sprite.texture = TEXTURES[tier]
	sprite.centered = false
	# Dessin HD : deux pixels dessinés par pixel du monde.
	sprite.scale = Vector2(0.5, 0.5)
	# Le bas de l'image est le bas des 4 × 4 cases ; le tri se fait sur la ligne de façade.
	root.position = Vector2(0, -FACADE * t)
	sprite.offset = Vector2(-sprite.texture.get_width() / 2.0, -sprite.texture.get_height() + FACADE * t * 2.0)
	root.add_child(sprite)
	# Le feu (ou les braseros) éclaire les alentours.
	var light := PointLight2D.new()
	light.texture = load("res://assets/lights/light_radial.tres")
	light.color = Color(1.0, 0.62, 0.3)
	light.energy = 0.9 if tier == 0 else 0.6
	light.texture_scale = 1.2 + tier * 0.4
	light.position = (CAMPFIRE if tier == 0 else Vector2(0, -6)) - root.position
	light.set_script(load("res://scenes/props/flicker_light.gd"))
	root.add_child(light)
	_visual = root
	_shape.size = FOOTPRINTS[tier] * t
	_interact.radius_tiles = 1.8 + FOOTPRINTS[tier].x * 0.45
	_interact.prompt = Town.guild_name()
	add_child(_visual)
	move_child(_visual, 0)
	_body.get_child(0).position = Vector2(0, -Town.GUILD_SIZE.y * t + _shape.size.y / 2.0)
	_interact.position = Vector2(0, -4)


## La zone réservée à la guilde (4 × 4 cases), en coordonnées du monde.
func reserved_rect() -> Rect2:
	var t := float(Game.TILE_SIZE)
	var cells := Town.guild_cells()
	return Rect2(Vector2(cells[0]) * t, Vector2(Town.GUILD_SIZE) * t)


func _on_interacted() -> void:
	# Au palier Camp, le registre est au feu ; ensuite, on entre dans la salle de la guilde.
	var hall := Town.tier >= 1
	var options: Array[String] = []
	var ids: Array[String] = []
	if hall:
		options.append("Entrer dans la salle de la guilde")
		ids.append("hall")
	else:
		options.append("Registre de la guilde (%d membres)" % Roster.living().size())
		ids.append("members")
		options.append("Candidats du jour (%d)" % Roster.candidates.size())
		ids.append("candidates")
		options.append("Commandes (%d en cours)" % GuildOrders.pending_count())
		ids.append("orders")
	for pair in [["Dormir jusqu'au lendemain", "sleep"], ["Fabriquer des outils", "craft"], ["Améliorer la guilde", "upgrade"],
			["Changer de classe", "class"], ["Fermer", "close"]]:
		options.append(pair[0])
		ids.append(pair[1])
	var choice := await Choice.ask(Town.guild_name(), _status_text(), options)
	if choice < 0:
		return
	match ids[choice]:
		"hall":
			Game.next_spawn = &"entrance"
			Transition.change_scene("res://scenes/levels/guild_hall/guild_hall.tscn")
		"members":
			await GuildRegistry.open_members()
		"candidates":
			await GuildRegistry.open_candidates()
		"sleep":
			var i := await Choice.ask(Town.guild_name(), "Dormir jusqu'au lendemain matin ? (%s)" % Game.clock_text(), ["Dormir", "Annuler"])
			if i == 0:
				Game.sleep()
		"orders":
			await GuildOrders.open()
		"craft":
			Crafting.open(&"camp")
		"upgrade":
			_upgrade()
		"class":
			_change_class()


func _status_text() -> String:
	var lines: Array[String] = ["%s — palier %d : %s." % [Town.guild_name(), Town.tier + 1, Town.tier_name()]]
	var up := Town.next_upgrade()
	if up.is_empty():
		lines.append("La guilde est à son apogée.")
		return "\n".join(lines)
	lines.append("Prochain palier : %s (%s)." % [Town.guild_name(Town.tier + 1), Town.tier_name(Town.tier + 1)])
	var need_b := Town.missing_buildings()
	if not need_b.is_empty():
		var parts: Array[String] = []
		for id in need_b:
			var data := Town.building(id)
			parts.append("%d %s" % [int(need_b[id]), data.display_name.to_lower() if data else String(id)])
		lines.append("Bâtiments à construire : %s." % ", ".join(parts))
	if Town.guild_upgrade.is_empty():
		lines.append("Matériaux : %s, puis %d jours de travaux." % [Building.cost_text(up["cost"]), int(up["days"])])
	else:
		var need := Town.missing(up["cost"], Town.guild_upgrade["delivered"])
		if need.is_empty():
			lines.append("Travaux en cours : jour %d / %d." % [int(Town.guild_upgrade["days"]), int(up["days"])])
		else:
			lines.append("Il manque : %s." % Building.cost_text(need))
	return "\n".join(lines)


func _upgrade() -> void:
	var up := Town.next_upgrade()
	if up.is_empty():
		return
	if Town.guild_upgrade.is_empty() and not Town.start_guild_upgrade():
		Narration.say(_missing_buildings_text(), 4.0)
		return
	var moved := Town.deliver(up["cost"], Town.guild_upgrade["delivered"])
	var need := Town.missing(up["cost"], Town.guild_upgrade["delivered"])
	if need.is_empty():
		Narration.say("Les matériaux sont réunis. Les travaux de la guilde avancent chaque jour.", 3.0)
	elif moved > 0:
		Narration.say("Matériaux déposés. Il manque encore : %s." % Building.cost_text(need), 3.0)
	else:
		Narration.say("Il manque : %s." % Building.cost_text(need), 2.6)


## « Il faut encore : 1 tente (2 demandées, 1 terminée, 1 en chantier). »
func _missing_buildings_text() -> String:
	var parts: Array[String] = []
	var up := Town.next_upgrade()
	for id in Town.missing_buildings():
		var data := Town.building(id)
		var label := data.display_name.to_lower() if data else String(id)
		var wanted := int(up["requires"][id])
		var built := Town.count_built(id)
		var placed := 0
		for r in Town.sites:
			if r["id"] == String(id):
				placed += 1
		var detail := "%d demandé%s, %d terminé%s" % [wanted, "s" if wanted > 1 else "", built, "s" if built > 1 else ""]
		if placed > built:
			detail += ", %d en chantier (dormez pour le terminer)" % (placed - built)
		parts.append("%s (%s)" % [label, detail])
	return "Il faut encore : %s." % "; ".join(parts)


func _change_class() -> void:
	var ids: Array[StringName] = []
	var options: Array[String] = []
	for id in Hero.all_classes():
		if Hero.unlocked.has(id):
			ids.append(id)
			var mark := " (actuelle)" if id == Hero.current else ""
			options.append("%s — niveau %d%s" % [Hero.class_data(id)["name"], Hero.level(id), mark])
	options.append("Fermer")
	var body := "Fabriquez l'équipement d'une classe à l'établi pour la débloquer."
	var choice := await Choice.ask("Changer de classe", body, options)
	if choice >= 0 and choice < ids.size() and Hero.switch_to(ids[choice]):
		Narration.say("%s : %s" % [Hero.class_data(ids[choice])["name"], Hero.class_data(ids[choice])["role"]], 2.6)
