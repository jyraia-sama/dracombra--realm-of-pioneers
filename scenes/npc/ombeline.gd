class_name Ombeline
extends Node2D
## Dame Ombeline, maîtresse d'armes : la dernière chevalière de l'Ordre du Bouclier, l'ordre
## qui protégeait les pionniers de l'ancienne Dracombra. Elle a entendu parler de la nouvelle
## guilde et vient voir si quelqu'un mérite encore les vieux serments. Elle donne les quêtes
## des classes mixtes (ClassQuests) dès qu'une classe atteint le niveau demandé.
##
## Dessin PROVISOIRE : planche de PNJ générée (tools/placeholder/placeholder.py), teintée acier.

const BASE := "res://assets/sprites/npc/ombeline/ombeline"
const TINT := Color(0.85, 0.9, 1.05)

var _sprite: Sprite2D
var _anims: Dictionary
var _t := 0.0
var _talking := false


func _ready() -> void:
	add_to_group("npc")
	var sheet := SheetAnimation.load_sheet(BASE + ".json")
	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	SheetAnimation.apply_to(_sprite, load(BASE + ".png"), sheet)
	_sprite.modulate = TINT
	add_child(_sprite)
	_anims = SheetAnimation.anims_from(sheet)
	var it := Interactable.new()
	it.prompt = "Parler à Dame Ombeline"
	it.radius_tiles = 2.2
	it.position = Vector2(0, 14)
	add_child(it)
	it.interacted.connect(talk)


func _process(delta: float) -> void:
	_t += delta
	if _anims.has(&"idle"):
		var a: Array = _anims[&"idle"]
		_sprite.frame = int(a[0]) * _sprite.hframes + int(_t / 0.5) % int(a[1])


func talk() -> void:
	if _talking:
		return
	_talking = true
	await _menu()
	_talking = false


func _menu() -> void:
	var hero := Hero.hero_name
	if not Game.has_flag(&"ombeline_intro_done"):
		Game.set_flag(&"ombeline_intro_done")
		await Ysolde.lines("Dame Ombeline", ["Alors c'est vous, %s, qui relevez Dracombra ? On en parle jusque dans les collines." % hero,
			"Je suis Ombeline, la dernière de l'Ordre du Bouclier. Nous gardions les pionniers, autrefois... avant que la ville tombe.",
			"Je cherche quelqu'un qui mérite nos vieux serments. Un guerrier peut devenir chevalier ; un guerrier qui prie, paladin.",
			"Ce sont des classes mixtes : on garde tout ce qu'on sait, et on y ajoute autre chose. Mais il faut faire ses preuves."])
	while true:
		var options: Array[String] = []
		var acts: Array = []
		for id in Hero.MIXED_ORDER:
			var q: Dictionary = ClassQuests.QUESTS[id]
			var name: String = Hero.MIXED[id]["name"]
			if Game.has_flag(ClassQuests.flag(id, "done")):
				continue
			if ClassQuests.active(id) and Game.has_flag(ClassQuests.flag(id, "ready")):
				options.append("%s : l'épreuve est réussie" % name)
				acts.append(["finish", id])
			elif ClassQuests.active(id):
				options.append("%s : %s (en cours)" % [name, q["title"]])
				acts.append(["remind", id])
			elif ClassQuests.available(id):
				options.append("%s : %s" % [name, q["title"]])
				acts.append(["offer", id])
			else:
				options.append("%s (il faut %s)" % [name, ClassQuests.requirement_text(id)])
				acts.append(["info", id])
		options.append("Les classes mixtes ?")
		acts.append(["explain"])
		options.append("Au revoir")
		acts.append(["bye"])
		var i := await Choice.ask("Dame Ombeline, maîtresse d'armes", "« Les vieux serments attendent ceux qui les méritent. »", options)
		if i < 0 or acts[i][0] == "bye":
			return
		var id: StringName = acts[i][1] if acts[i].size() > 1 else &""
		match acts[i][0]:
			"explain":
				await Ysolde.lines("Dame Ombeline", ["Une classe mixte garde le niveau et les techniques de ses classes d'origine, et en apprend trois nouvelles.",
					"Elle a ses propres armes : l'épée longue du chevalier, le bouclier sacré du paladin...",
					"Quand vous aurez prêté serment, vos compagnons de la guilde pourront suivre la même voie, s'ils en ont le niveau."])
			"info":
				await Ysolde.lines("Dame Ombeline", ["Le %s ? Revenez quand vous aurez atteint : %s." % [String(Hero.MIXED[id]["name"]).to_lower(), ClassQuests.requirement_text(id)]])
			"offer":
				await _offer(id)
			"remind":
				await _remind(id)
			"finish":
				await _finish(id)


func _offer(id: StringName) -> void:
	var q: Dictionary = ClassQuests.QUESTS[id]
	await Ysolde.lines("Dame Ombeline", [q["pitch"]])
	var i := await Choice.ask(q["title"], "Accepter l'épreuve du %s ?" % String(Hero.MIXED[id]["name"]).to_lower(), ["J'accepte", "Plus tard"])
	if i != 0:
		return
	Game.set_flag(ClassQuests.flag(id, "active"))
	if id == &"knight":
		await _defense_now()
	elif id == &"spellblade":
		await _duel_now()
	else:
		await Ysolde.lines("Dame Ombeline", q.get("hint", [q["pitch"]]))


func _remind(id: StringName) -> void:
	if id == &"knight":
		await _defense_now()
	elif id == &"spellblade":
		await _duel_now()
	else:
		var q: Dictionary = ClassQuests.QUESTS[id]
		await Ysolde.lines("Dame Ombeline", [q["pitch"]] + Array(q.get("hint", [])))


func _defense_now() -> void:
	var level := get_tree().current_scene as Node2D
	if level == null or level.get_node_or_null("DefenseEvent") != null:
		return
	var i := await Choice.ask("Le serment du bouclier", "Les gobelins attendent votre signal. Prêt ? (trois vagues, ici même)", ["En garde !", "Pas encore"])
	if i != 0:
		return
	await Ysolde.lines("Dame Ombeline", ["Bouclier haut. Ne reculez pas d'un pas."])
	ClassQuests.start_defense(level)


func _duel_now() -> void:
	var level := get_tree().current_scene as Node2D
	if level == null or level.get_node_or_null("ChevalierSpectral") != null:
		return
	var i := await Choice.ask("Le chevalier spectral", "Appeler le chevalier spectral pour le duel ? (ici même)", ["Qu'il vienne !", "Pas encore"])
	if i != 0:
		return
	await Ysolde.lines("Dame Ombeline", ["Frère d'armes, entends-moi : voici qui te libérera.", "Méfiez-vous de son bouclier : frappez-le de dos, ou quand il manque son coup."])
	ClassQuests.start_duel(level)


func _finish(id: StringName) -> void:
	await Ysolde.lines("Dame Ombeline", [ClassQuests.QUESTS[id]["thanks"]])
	ClassQuests.complete(id)
