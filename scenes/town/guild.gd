class_name Guild
extends Node2D
## Le cœur de Dracombra : d'abord un simple feu de camp, puis la tente de guilde,
## la maison, le hall et enfin la citadelle. On l'améliore ici même.

const CAMPFIRE := preload("res://scenes/props/sylve/campfire.tscn")
const GUILD_TENT := preload("res://assets/sprites/buildings/guild_tent.png")

var _visual: Node2D
var _body: StaticBody2D
var _shape: RectangleShape2D
var _interact: Interactable


func _ready() -> void:
	add_to_group("guild")
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
	if Town.tier == 0:
		_visual = CAMPFIRE.instantiate()
		_shape.size = Vector2(t * 0.8, t * 0.4)
		_interact.radius_tiles = 1.8
		_interact.prompt = "Feu de camp"
	else:
		# En attendant les vrais sprites, les paliers supérieurs agrandissent la tente.
		var sprite := Sprite2D.new()
		sprite.texture = GUILD_TENT
		sprite.centered = false
		sprite.offset = Vector2(-GUILD_TENT.get_width() / 2.0, -GUILD_TENT.get_height())
		var k := 1.0 + 0.25 * (Town.tier - 1)
		sprite.scale = Vector2(k, k)
		_visual = sprite
		_shape.size = Vector2(t * 3.0 * k, t * 1.0)
		_interact.radius_tiles = 2.6 * k
		_interact.prompt = Town.guild_name()
	add_child(_visual)
	move_child(_visual, 0)
	_body.get_child(0).position = Vector2(0, -_shape.size.y / 2.0)
	_interact.position = Vector2(0, -4)


func _on_interacted() -> void:
	var options := ["Dormir jusqu'au lendemain", "Améliorer la guilde", "Fermer"]
	var choice := await Choice.ask(Town.guild_name(), _status_text(), options)
	match choice:
		0:
			Game.sleep()
		1:
			_upgrade()


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
		Narration.say("Il faut d'abord construire les bâtiments demandés.", 2.6)
		return
	var moved := Town.deliver(up["cost"], Town.guild_upgrade["delivered"])
	var need := Town.missing(up["cost"], Town.guild_upgrade["delivered"])
	if need.is_empty():
		Narration.say("Les matériaux sont réunis. Les travaux de la guilde avancent chaque jour.", 3.0)
	elif moved > 0:
		Narration.say("Matériaux déposés. Il manque encore : %s." % Building.cost_text(need), 3.0)
	else:
		Narration.say("Il manque : %s." % Building.cost_text(need), 2.6)
