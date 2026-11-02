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
		"back": "Retourner voir Dame Ombeline (Chevalier)",
		"thanks": "Vous avez tenu la ligne sans reculer. Relevez-vous, chevalier. Ce grand bouclier vous revient."},
	&"paladin": {"title": "Le bouclier sacré",
		"pitch": "Le bouclier béni des pionniers repose dans une salle oubliée des cryptes, derrière un mur fissuré (étages 5 à 7 des Abysses).",
		"hint": ["Cherchez un mur fissuré : un filet de poussière tombe de ses fentes. Brisez-le.",
			"Et méfiez-vous : les gardiens de l'autel ne dorment que d'un œil."],
		"objective": "Trouver le bouclier sacré dans une salle secrète des cryptes (étages 5 à 7)",
		"back": "Rapporter le bouclier sacré à Dame Ombeline (Paladin)",
		"thanks": "Le bouclier des pionniers... Sa lumière vous a choisi. Gardez-le : il est à vous, paladin."},
	&"marksman": {"title": "Le mousquet des pionniers",
		"pitch": "Les pionniers avaient une arme à poudre. Ses plans dorment dans des ruines au sud-est de la Sylve. Rapportez-les, faites forger le mousquet, et montrez-le-moi.",
		"hint": ["Sortez par la grande porte et filez vers le sud-est, jusqu'au bout de la forêt. Des gobelins campent dans ces ruines.",
			"Ensuite, la forge : du fer, un peu d'argent, du bois. Les plans, eux, ne s'usent pas."],
		"objective": "Trouver les plans du mousquet dans des ruines au sud-est de la Sylve",
		"back": "Montrer le mousquet à Dame Ombeline (Tireur d'élite)",
		"thanks": "Une arme qui crache le tonnerre... Les pionniers savaient y faire. Tireur d'élite : visez juste, et rarement à côté."},
	&"elementalist": {"title": "Les trois foyers",
		"pitch": "Trois foyers élémentaires dorment dans la Sylve : le feu au nord, la glace à l'ouest, la foudre à l'est. Rallumez-les avec votre magie.",
		"hint": ["Frappez chaque foyer avec un sort ou un tir de mage. Ils sont gardés : des esprits s'éveillent quand on approche.",
			"Les trois brûleront ensemble, et vous comprendrez."],
		"objective": "Rallumer les trois foyers élémentaires de la Sylve",
		"back": "Retourner voir Dame Ombeline (Élémentaliste)",
		"thanks": "Je les ai vus briller depuis la ville. Le feu, la glace et la foudre vous répondent maintenant, élémentaliste."},
}

## Lieux des quêtes dans la Sylve (en pixels).
const RUINS_AT := Vector2(2232, 1336)
const SHRINES := {&"fire": Vector2(2008, 152), &"ice": Vector2(184, 408), &"spark": Vector2(2232, 568)}
const SHRINE_NAMES := {&"fire": "feu (nord)", &"ice": "glace (ouest)", &"spark": "foudre (est)"}
const SHRINE_COLORS := {&"fire": Color(1.0, 0.55, 0.25), &"ice": Color(0.55, 0.85, 1.0), &"spark": Color(1.0, 0.95, 0.45)}

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
		if Game.has_flag(flag(id, "ready")):
			return "Objectif : %s" % q["back"]
		if id == &"marksman" and Inventory.get_count(&"musket_plans") > 0:
			return "Objectif : forger le mousquet (forge : plans + 3 lingots de fer, 1 d'argent, 2 bois)"
		if id == &"elementalist":
			return "Objectif : %s (%d / 3)" % [q["objective"], lit_count()]
		return "Objectif : %s" % q["objective"]
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


# ------------------------------------------------------------------ Tireur d'élite, Élémentaliste : la Sylve

## Le mousquet forgé pendant la quête : l'épreuve est réussie.
static func on_crafted(id: StringName) -> void:
	if id == &"musket" and active(&"marksman"):
		Game.set_flag(flag(&"marksman", "ready"))
		Narration.say("Le mousquet est forgé ! Dame Ombeline voudra le voir.", 3.0)


static func lit_count() -> int:
	var n := 0
	for k in SHRINES:
		if Game.has_flag(StringName("cq_elementalist_%s" % k)):
			n += 1
	return n


## Pose les lieux des quêtes en cours dans la Sylve (appelé par sylve.gd).
static func setup_sylve(level: Node2D) -> void:
	var props := level.get_node("Props")
	if active(&"marksman") and Inventory.get_count(&"musket_plans") <= 0 and not Game.has_flag(flag(&"marksman", "ready")):
		_ruins(props)
	if active(&"elementalist") and not Game.has_flag(flag(&"elementalist", "ready")):
		for k in SHRINES:
			props.add_child(ElementShrine.make(k))


static func _ruins(props: Node) -> void:
	for o in [Vector2(-40, -26), Vector2(38, -30), Vector2(-46, 24), Vector2(44, 20)]:
		var p: Node2D = load("res://scenes/props/ruins/pillar_broken.tscn").instantiate()
		p.position = RUINS_AT + o
		props.add_child(p)
	var chest := Node2D.new()
	chest.name = "CoffrePlans"
	chest.position = RUINS_AT
	var sprite := Sprite2D.new()
	sprite.texture = load("res://assets/sprites/buildings/chest.png")
	sprite.scale = Vector2(0.5, 0.5)
	sprite.centered = false
	sprite.offset = Vector2(-sprite.texture.get_width() / 2.0, -sprite.texture.get_height())
	chest.add_child(sprite)
	var it := Interactable.new()
	it.prompt = "Fouiller le vieux coffre"
	it.radius_tiles = 1.8
	chest.add_child(it)
	props.add_child(chest)
	it.interacted.connect(func() -> void:
		it.enabled = false
		sprite.modulate = Color(0.6, 0.55, 0.5)
		Inventory.add_item(Inventory.item_by_id(&"musket_plans"), 1)
		Narration.say("Les plans du mousquet ! Il faut maintenant les porter à la forge.", 3.5))
	# Le camp de gobelins qui garde les ruines.
	for i in 4:
		var e: Node2D = load(SCENES[&"goblin"] if i < 3 else SCENES[&"boar"]).instantiate()
		Combat.set_level(e, 14)
		e.position = RUINS_AT + Vector2.from_angle(TAU * i / 4.0) * 70.0
		props.get_parent().add_child.call_deferred(e)


class ElementShrine extends Node2D:
	var element: StringName
	var _woke := false
	var _sprite: Node2D

	static func make(k: StringName) -> ElementShrine:
		var s := ElementShrine.new()
		s.element = k
		s.name = "Foyer_%s" % k
		s.position = ClassQuests.SHRINES[k]
		return s

	func _ready() -> void:
		_sprite = load("res://scenes/props/ruins/rune_brazier.tscn").instantiate()
		add_child(_sprite)
		_sprite.modulate = Color(0.55, 0.55, 0.6) if not _lit() else ClassQuests.SHRINE_COLORS[element]
		var health := HealthComponent.new()
		health.name = "Health"
		health.max_health = 9999
		add_child(health)
		var hurt := Hurtbox.new()
		hurt.collision_layer = 16
		hurt.collision_mask = 0
		hurt.health = health
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(22, 28)
		cs.shape = r
		cs.position = Vector2(0, -14)
		hurt.add_child(cs)
		add_child(hurt)
		hurt.hit_received.connect(_on_hit)

	func _lit() -> bool:
		return Game.has_flag(StringName("cq_elementalist_%s" % element))

	func _process(_delta: float) -> void:
		if _woke or _lit():
			return
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player and player.global_position.distance_to(global_position) < Game.TILE_SIZE * 7.0:
			_woke = true
			Narration.say("Le foyer du %s s'éveille... ses gardiens aussi !" % ClassQuests.SHRINE_NAMES[element], 2.5)
			for i in 2:
				var w := Wisp.new()
				Combat.set_level(w, 14)
				w.position = global_position + Vector2.from_angle(TAU * i / 2.0) * 40.0 + Vector2(0, -10)
				get_parent().add_child(w)

	func _on_hit(h: Hitbox) -> void:
		if _lit():
			return
		# Seule la magie le rallume (tir ou sort d'une classe de mage).
		if not Hero.bases_of(Hero.current).has(&"mage"):
			Emote.show(self, "Il faut de la magie...", Color(0.8, 0.8, 1.0), 40.0)
			return
		Game.set_flag(StringName("cq_elementalist_%s" % element))
		_sprite.modulate = ClassQuests.SHRINE_COLORS[element]
		PixelBurst.spawn(get_parent(), global_position + Vector2(0, -20), PixelBurst.SMOKE, Vector2.ZERO, 1.5)
		Fx.shake(1.5, 0.2)
		var n := ClassQuests.lit_count()
		if n >= 3:
			Game.set_flag(ClassQuests.flag(&"elementalist", "ready"))
			Narration.say("Les trois foyers brûlent ensemble ! Dame Ombeline vous attend.", 3.5)
		else:
			Narration.say("Foyer du %s rallumé (%d / 3)." % [ClassQuests.SHRINE_NAMES[element], n], 2.5)


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
