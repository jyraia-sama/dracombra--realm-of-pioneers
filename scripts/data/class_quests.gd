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
	&"priest": {"title": "L'épidémie",
		"pitch": "Une fièvre court dans Dracombra. Des villageois sont tombés près de la guilde. Soignez-les tous, avant qu'elle ne s'étende.",
		"hint": ["Un clerc peut les soigner par la prière (un peu de mana). Sinon, il faudra un baume de soin pour chacun.",
			"Ils sont cinq, quelque part autour de la guilde."],
		"objective": "Soigner les villageois fiévreux autour de la guilde",
		"back": "Retourner voir Dame Ombeline (Prêtre)",
		"thanks": "Plus un seul fiévreux. La ville vous doit beaucoup, prêtre. Vos prières portent loin, maintenant."},
	&"ranger": {"title": "La bête de la Sylve",
		"pitch": "Un sanglier énorme, Grand-Défense, ravage le sud de la Sylve. Les chasseurs n'osent plus sortir. Traquez-le.",
		"hint": ["Il rôde au sud de la forêt, loin de la porte. Il charge fort : esquivez, puis frappez.",
			"Un bon rôdeur se bat à l'arc comme à la hache. Vous aurez besoin des deux."],
		"objective": "Abattre Grand-Défense, la bête du sud de la Sylve",
		"back": "Retourner voir Dame Ombeline (Rôdeur)",
		"thanks": "Grand-Défense... Les chasseurs vont pouvoir ressortir. Bienvenue parmi les rôdeurs."},
	&"spellblade": {"title": "Le chevalier spectral",
		"pitch": "Un ancien de mon ordre erre encore, prisonnier de son serment. Il ne cède qu'à qui le bat en duel, l'épée et la magie à la main.",
		"objective": "Vaincre le chevalier spectral en duel (parler à Ombeline pour l'appeler)",
		"back": "Retourner voir Dame Ombeline (Lame-sort)",
		"thanks": "Il est enfin libre. Et vous... vous mêlez l'acier et les arcanes comme personne. Lame-sort."},
	&"oracle": {"title": "La vision",
		"pitch": "Je fais le même rêve chaque nuit : une lumière, tout au fond des cryptes, qui appelle quelqu'un qui voit plus loin que les autres. Suivez-la.",
		"hint": ["Descendez dans les cryptes, aux étages 6 ou 7. La lumière attend près d'un feu de camp.",
			"Ce qu'elle vous montrera... revenez me le raconter."],
		"objective": "Suivre la vision au fond des cryptes (étages 6 ou 7, près d'un feu de camp)",
		"back": "Raconter la vision à Dame Ombeline (Oracle)",
		"thanks": "Un cartographe, perdu plus bas ? Lysia devra le savoir. Vous voyez ce que les autres ne voient pas : oracle."},
}

## L'épidémie : où sont les fiévreux, autour de la guilde (en pixels).
const SICK := [Vector2(-90, 44), Vector2(84, 52), Vector2(-52, -70), Vector2(110, -34), Vector2(12, 96)]
## La bête de la Sylve.
const BEAST_AT := Vector2(1912, 1368)

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
		if id == &"priest":
			return "Objectif : %s (encore %d)" % [q["objective"], sick_left()]
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
	if active(&"ranger") and not Game.has_flag(flag(&"ranger", "ready")):
		_beast(level)


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


# ------------------------------------------------------------------ Prêtre : l'épidémie

static func sick_left() -> int:
	var n := 0
	for i in SICK.size():
		if not Game.has_flag(StringName("cq_priest_sick_%d" % i)):
			n += 1
	return n


## Pose les villageois fiévreux autour de la guilde (appelé par dracombra.gd).
static func setup_city(level: Node2D, guild_pos: Vector2) -> void:
	if not active(&"priest") or Game.has_flag(flag(&"priest", "ready")):
		return
	for i in SICK.size():
		if Game.has_flag(StringName("cq_priest_sick_%d" % i)):
			continue
		var s := SickVillager.new()
		s.index = i
		s.position = guild_pos + SICK[i]
		level.get_node("Props").add_child(s)


class SickVillager extends Node2D:
	var index := 0
	var _sprite: Sprite2D

	func _ready() -> void:
		add_to_group("npc")
		var base := Roster.ARTISAN_SPRITE
		var sheet := SheetAnimation.load_sheet(base + ".json")
		_sprite = Sprite2D.new()
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		SheetAnimation.apply_to(_sprite, load(base + ".png"), sheet)
		_sprite.modulate = Color(0.7, 0.95, 0.65)
		_sprite.rotation = PI / 2.0
		_sprite.position = Vector2(-8, -4)
		add_child(_sprite)
		var it := Interactable.new()
		it.prompt = "Soigner le fiévreux"
		it.radius_tiles = 1.8
		add_child(it)
		it.interacted.connect(_heal.bind(it))

	func _heal(it: Interactable) -> void:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if Hero.bases_of(Hero.current).has(&"cleric") and Hero.mana >= 10.0:
			Hero.mana -= 10.0
			Hero.energy_changed.emit(Hero.energy, Hero.energy_max())
		elif Inventory.get_count(&"balm") > 0:
			Inventory.remove_item(Inventory.item_by_id(&"balm"), 1)
		else:
			Narration.say("Il faudrait prier (clerc, 10 mana) ou un baume de soin.", 2.5)
			return
		it.enabled = false
		Game.set_flag(StringName("cq_priest_sick_%d" % index))
		SkillFx.ring(get_parent(), global_position, 20.0, Color(0.7, 1.0, 0.7), 0.6)
		Emote.show(self, "Merci...", Color(0.8, 1.0, 0.8), 20.0)
		var left := ClassQuests.sick_left()
		if left == 0:
			Game.set_flag(ClassQuests.flag(&"priest", "ready"))
			Narration.say("Tous les fiévreux sont soignés ! Dame Ombeline vous attend.", 3.0)
		else:
			Narration.say("Encore %d fiévreux." % left, 1.8)
		var tween := create_tween()
		tween.tween_interval(1.0)
		tween.tween_property(self, "modulate:a", 0.0, 0.6)
		tween.tween_callback(queue_free)


# ------------------------------------------------------------------ Lame-sort : le duel

## Appelle le chevalier spectral devant le héros.
static func start_duel(level: Node2D) -> void:
	var player := level.get_tree().get_first_node_in_group("player") as Player
	if player == null or level.get_node_or_null("ChevalierSpectral") != null:
		return
	var k := CryptGuardian.new()
	k.name = "ChevalierSpectral"
	k.can_summon = false
	Combat.set_level(k, 16)
	k.health.max_health = int(k.health.max_health * 0.6)
	k.health.current_health = k.health.max_health
	k.position = player.global_position + Vector2(0, -80)
	k.base_tint = Color(0.6, 0.8, 1.2, 0.85)
	level.add_child(k)
	var bar := BossBar.create("Le chevalier spectral", k.health)
	level.add_child(bar)
	PixelBurst.spawn(level, k.position, PixelBurst.SMOKE, Vector2.ZERO, 2.0)
	Narration.say("Un froid glacial... Le chevalier spectral lève son épée.", 2.5)
	k.health.died.connect(func() -> void:
		Game.set_flag(ClassQuests.flag(&"spellblade", "ready"))
		if is_instance_valid(bar):
			bar.queue_free()
		Narration.say("Le chevalier s'incline, puis s'efface. Dame Ombeline vous attend.", 3.5), CONNECT_ONE_SHOT)
	player.health.died.connect(func() -> void:
		if is_instance_valid(k):
			k.queue_free()
		if is_instance_valid(bar):
			bar.queue_free()
		Game.pending_message = "Le chevalier spectral vous a vaincu... Dame Ombeline vous attend pour réessayer.", CONNECT_ONE_SHOT)


# ------------------------------------------------------------------ Rôdeur : la bête

static func _beast(level: Node2D) -> void:
	var b: Node2D = load(SCENES[&"boar"]).instantiate()
	b.name = "GrandDefense"
	Combat.set_level(b, 18)
	var h := b.get_node("Health") as HealthComponent
	h.max_health = h.max_health * 5
	h.current_health = h.max_health
	b.scale = Vector2(1.7, 1.7)
	b.position = BEAST_AT
	b.set("alert_radius_tiles", 6.0)
	(b.get_node("Visual") as CanvasItem).modulate = Color(0.75, 0.62, 0.55)
	level.add_child.call_deferred(b)
	h.died.connect(func() -> void:
		Game.set_flag(ClassQuests.flag(&"ranger", "ready"))
		Narration.say("Grand-Défense est tombé ! Dame Ombeline voudra le savoir.", 3.5), CONNECT_ONE_SHOT)


# ------------------------------------------------------------------ Oracle : la vision

## La lumière de la vision (salle de repos des cryptes, étages 6 et 7).
static func vision() -> Node2D:
	var root := Node2D.new()
	root.name = "Vision"
	var light := PointLight2D.new()
	light.texture = load("res://assets/lights/light_radial.tres")
	light.color = Color(0.7, 0.85, 1.0)
	light.energy = 1.4
	light.texture_scale = 1.2
	root.add_child(light)
	var glow := SkillFx.new()
	glow.radius = 12.0
	glow.color = Color(0.75, 0.9, 1.0)
	glow.duration = 99999.0
	root.add_child(glow)
	var it := Interactable.new()
	it.prompt = "Toucher la lumière"
	it.radius_tiles = 1.8
	root.add_child(it)
	it.interacted.connect(func() -> void:
		it.enabled = false
		await Transition.fade_out(0.6)
		await Transition.story_text("Une galerie, très loin sous les cryptes. Un homme aux cartes déchirées trace un chemin à la craie.", 3.5)
		await Transition.story_text("Il ressemble à Lysia. « Aurèle... », murmure une voix. Puis l'ombre l'avale.", 3.5)
		await Transition.fade_in(0.6)
		Game.set_flag(ClassQuests.flag(&"oracle", "ready"))
		Game.set_flag(&"vision_aurele")
		Narration.say("La lumière s'éteint. Dame Ombeline doit entendre cela.", 3.0)
		root.queue_free())
	return root


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
