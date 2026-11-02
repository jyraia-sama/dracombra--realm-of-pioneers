class_name ClassQuests
extends RefCounted
## Les quêtes des classes mixtes (CLASSES.md) : une par classe. Dame Ombeline, maîtresse
## d'armes, arrive à Dracombra dès qu'une classe atteint le niveau demandé et donne la quête.
## Les quêtes peuvent se passer en ville, dehors ou dans un donjon.
##
## État (drapeaux de Game) : cq_<id>_active (acceptée), cq_<id>_ready (épreuve réussie,
## il reste à revenir voir Ombeline), cq_<id>_done (classe débloquée).

const QUESTS := {
	&"knight": {"title": "Le serment du bouclier",
		"pitch": "Des gobelins des collines rôdent autour de Dracombra. Tenez la ligne devant la guilde, vague après vague, sans reculer.",
		"objective": "Repousser l'attaque des gobelins (parler à Ombeline pour commencer)",
		"back": "Retourner voir Dame Ombeline (Chevalier)"},
	&"paladin": {"title": "Le bouclier sacré",
		"pitch": "Le bouclier béni des pionniers repose dans une salle oubliée des cryptes, derrière un mur fissuré (étages 5 à 7 des Abysses).",
		"objective": "Trouver le bouclier sacré dans une salle secrète des cryptes (étages 5 à 7)",
		"back": "Rapporter le bouclier sacré à Dame Ombeline (Paladin)"},
}

const WAVES := [
	[[&"goblin", 3], [&"slime", 2]],
	[[&"goblin", 4], [&"boar", 1]],
	[[&"goblin", 5], [&"boar", 2]],
]
const SCENES := {&"goblin": "res://scenes/enemies/rock_goblin/rock_goblin.tscn",
	&"boar": "res://scenes/enemies/boar/boar.tscn", &"slime": "res://scenes/enemies/slime/slime.tscn"}


static func flag(id: StringName, what: String) -> StringName:
	return StringName("cq_%s_%s" % [id, what])


## Les classes d'origine ont-elles le niveau demandé ?
static func requirements_met(id: StringName) -> bool:
	var data: Dictionary = Hero.MIXED[id]
	for b in data["bases"]:
		if not Hero.unlocked.has(b) or Hero.level(b) < int(data["unlock_level"]):
			return false
	return true


static func available(id: StringName) -> bool:
	return requirements_met(id) and not Game.has_flag(flag(id, "done"))


static func active(id: StringName) -> bool:
	return Game.has_flag(flag(id, "active")) and not Game.has_flag(flag(id, "done"))


static func requirement_text(id: StringName) -> String:
	var data: Dictionary = Hero.MIXED[id]
	var parts: Array[String] = []
	for b in data["bases"]:
		parts.append("%s niv. %d" % [Hero.class_data(b)["name"], int(data["unlock_level"])])
	return " et ".join(parts)


## Après chaque niveau gagné : Ombeline arrive quand une quête devient possible.
static func on_level_up() -> void:
	for id in Hero.MIXED_ORDER:
		if available(id) and not Game.has_flag(flag(id, "offered")):
			Game.set_flag(flag(id, "offered"))
			Game.set_flag(&"ombeline_arrived")
			Narration.say("Une voyageuse en armure vous attend à la guilde : Dame Ombeline, maîtresse d'armes. Elle a une épreuve pour vous (%s)." % Hero.MIXED[id]["name"], 5.0)
			return


## Objectif affiché à l'écran (après les quêtes d'Ysolde).
static func objective_text() -> String:
	for id in Hero.MIXED_ORDER:
		if not active(id):
			continue
		var q: Dictionary = QUESTS[id]
		return "Objectif : %s" % (q["back"] if Game.has_flag(flag(id, "ready")) else q["objective"])
	for id in Hero.MIXED_ORDER:
		if available(id) and not active(id):
			return "Objectif : parler à Dame Ombeline, à la guilde (classe %s)" % Hero.MIXED[id]["name"]
	return ""


# ------------------------------------------------------------------ Chevalier : la défense

## Lance l'attaque des gobelins autour du héros (en ville).
static func start_defense(level: Node2D) -> void:
	var ev := DefenseEvent.new()
	ev.name = "DefenseEvent"
	level.add_child(ev)


class DefenseEvent extends Node:
	var wave := -1
	var alive: Array[Node2D] = []
	var _pause := 2.0

	func _ready() -> void:
		Narration.say("Les voilà ! Tenez la ligne devant la guilde !", 2.5)
		var player := get_tree().get_first_node_in_group("player") as Player
		if player:
			player.health.died.connect(_fail, CONNECT_ONE_SHOT)

	func _process(delta: float) -> void:
		alive = alive.filter(func(e): return is_instance_valid(e) and not e.get_node("Health").is_dead())
		if not alive.is_empty():
			return
		_pause -= delta
		if _pause > 0.0:
			return
		wave += 1
		if wave >= ClassQuests.WAVES.size():
			Game.set_flag(ClassQuests.flag(&"knight", "ready"))
			Narration.say("La dernière vague recule ! Dame Ombeline vous attend.", 3.5)
			queue_free()
			return
		_pause = 3.0
		_spawn(ClassQuests.WAVES[wave])

	func _spawn(groups: Array) -> void:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player == null:
			return
		Narration.say("Vague %d / %d" % [wave + 1, ClassQuests.WAVES.size()], 2.0)
		var base_angle := randf() * TAU
		var i := 0
		for g in groups:
			for k in int(g[1]):
				var e: Node2D = load(ClassQuests.SCENES[g[0]]).instantiate()
				Combat.set_level(e, 12 + wave * 2)
				var ang := base_angle + randf_range(-0.6, 0.6)
				e.position = player.global_position + Vector2.from_angle(ang) * Game.TILE_SIZE * randf_range(8.0, 11.0)
				for prop in ["detection_radius_tiles", "lose_interest_radius_tiles"]:
					if prop in e:
						e.set(prop, 30.0)
				get_parent().add_child(e)
				PixelBurst.spawn(get_parent(), e.position, PixelBurst.DUST, Vector2.ZERO, 2.0)
				alive.append(e)
				i += 1

	func _fail() -> void:
		for e in alive:
			if is_instance_valid(e):
				e.queue_free()
		Game.pending_message = "Les gobelins ont percé la ligne... Dame Ombeline vous attend pour réessayer."
		queue_free()


# ------------------------------------------------------------------ Paladin : l'autel

## L'autel du bouclier sacré (salle secrète des cryptes, quand la quête est en cours).
static func shrine() -> Node2D:
	var root := Node2D.new()
	root.name = "AutelSacre"
	var altar := Sprite2D.new()
	altar.texture = load("res://assets/sprites/props/crypt/sarcophagus.png")
	altar.scale = Vector2(0.5, 0.5)
	altar.centered = false
	altar.offset = Vector2(-36, -48)
	altar.modulate = Color(1.15, 1.1, 0.9)
	root.add_child(altar)
	var shield := Sprite2D.new()
	shield.texture = Inventory.item_by_id(&"sacred_shield").icon
	shield.position = Vector2(0, -26)
	shield.scale = Vector2(0.6, 0.6)
	root.add_child(shield)
	var light := PointLight2D.new()
	light.texture = load("res://assets/lights/light_radial.tres")
	light.color = Color(1.0, 0.92, 0.6)
	light.energy = 1.2
	light.position = Vector2(0, -24)
	root.add_child(light)
	var it := Interactable.new()
	it.prompt = "Prendre le bouclier sacré"
	it.radius_tiles = 2.0
	root.add_child(it)
	it.interacted.connect(func() -> void:
		it.enabled = false
		shield.queue_free()
		Inventory.add_item(Inventory.item_by_id(&"sacred_shield"), 1)
		Game.set_flag(ClassQuests.flag(&"paladin", "ready"))
		Narration.say("Le bouclier sacré ! ... Des os craquent dans l'ombre : les gardiens de l'autel se relèvent !", 3.5)
		Fx.shake(2.0, 0.3)
		for i in 3:
			var s := Skeleton.new()
			Combat.set_level(s, maxi(5, Game.dungeon_floor))
			s.position = root.position + Vector2.from_angle(TAU * i / 3.0 + 0.4) * 44.0
			root.get_parent().add_child(s)
			PixelBurst.spawn(root.get_parent(), s.position, PixelBurst.SMOKE, Vector2.ZERO, 1.0))
	return root


## Récompense : la classe est débloquée (et, pour le chevalier, un grand bouclier offert).
static func complete(id: StringName) -> void:
	Game.set_flag(flag(id, "done"))
	Hero.unlock(id)
	if id == &"knight":
		Inventory.add_item(Inventory.item_by_id(&"tower_shield"), 1)
	Narration.say("Nouvelle classe mixte : %s ! Changez de classe à la guilde (ou au feu de camp)." % Hero.MIXED[id]["name"], 4.5)
