extends Node
## Mode admin (tests) : touche F9 pour ouvrir le menu, partout après le prologue.
## Changer de classe à volonté (l'arme suit), se soigner, devenir invincible, gagner des
## niveaux ou des ressources, aller directement à un étage du donjon, passer un jour.

const RESOURCES := [&"wood", &"stone", &"flax", &"herb", &"hide", &"leather", &"rope", &"cloth", &"gem", &"slime_gel", &"obsidian_shard",
	&"iron_ore", &"iron_ingot", &"chitin", &"silk", &"silk_cloth", &"mana_crystal", &"gold",
	&"silver_ore", &"silver_ingot", &"ancient_bone", &"crypt_leather", &"spectral_essence", &"linen_wraps"]

var invincible := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(func(n: Node) -> void:
		# Seulement si l'invincibilité est active : certains niveaux règlent eux-mêmes min_health.
		if n is Player and invincible:
			_apply_invincible.call_deferred(n))


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_F9:
		return
	get_viewport().set_input_as_handled()
	if not Game.has_flag(&"prologue_done") or Choice.is_open or Transition.is_busy:
		return
	open_menu()


func open_menu() -> void:
	var options := [
		"Changer de classe",
		"Soigner (PV, endurance, mana)",
		"Invincible : %s" % ("OUI" if invincible else "non"),
		"Niveau +5 (classe actuelle)",
		"+50 de chaque ressource",
		"Aller au donjon (choisir l'étage)",
		"Passer au jour suivant",
		"Guilde : passer au palier suivant (actuel : %s)" % Town.tier_name(),
		"Enregistrement pour les rapports (F8) : %s" % ("OUI" if BugReport.recording else "non"),
		"Fermer",
	]
	var i := await Choice.ask("Mode admin", "Outils de test (F9). F8 : rapport de bug.", options)
	match i:
		0:
			await _pick_class()
		1:
			_heal()
		2:
			invincible = not invincible
			_apply_invincible(get_tree().get_first_node_in_group("player") as Player)
			Narration.say("Invincible : %s" % ("oui" if invincible else "non"), 1.5)
		3:
			for n in 5:
				Hero.gain_xp(Hero.xp_to_next(Hero.level()) - int(Hero.xp.get(Hero.current, 0)))
		4:
			for id in RESOURCES:
				var item := Inventory.item_by_id(id)
				if item:
					Inventory.add_item(item, 50)
			Narration.say("+50 de chaque ressource.", 1.5)
		5:
			await _pick_floor()
		6:
			Game.sleep()
		7:
			if Town.tier + 1 < Town.TIERS.size():
				Town.tier += 1
				Town.guild_upgrade = {}
				Town.changed.emit()
				Narration.say("La guilde passe au palier : %s." % Town.tier_name(), 2.0)
		8:
			BugReport.set_recording(not BugReport.recording)
			Narration.say("Enregistrement : %s. F8 : rapport avec les 12 dernières secondes." % ("oui" if BugReport.recording else "non"), 2.5)


func _pick_class() -> void:
	var options: Array[String] = []
	for id in Hero.ORDER:
		options.append("%s%s" % [Hero.CLASSES[id]["name"], " (actuelle)" if id == Hero.current else ""])
	options.append("Fermer")
	var i := await Choice.ask("Changer de classe", "Sans condition (mode admin).", options)
	if i < 0 or i >= Hero.ORDER.size():
		return
	var id: StringName = Hero.ORDER[i]
	Hero.unlock(id)
	if Hero.switch_to(id):
		Narration.say("%s : %s" % [Hero.CLASSES[id]["name"], Hero.CLASSES[id]["role"]], 2.0)


func _pick_floor() -> void:
	var names: Array[String] = []
	for f in range(1, 8):
		names.append("Étage %d%s" % [f, " (cryptes)" if f >= 4 else ""])
	names.append("Fermer")
	var i := await Choice.ask("Donjon", "Aller directement à l'étage :", names)
	if i < 0 or i > 6:
		return
	Game.dungeon_floor = i + 1
	Transition.change_scene("res://scenes/levels/dungeon/dungeon.tscn")


func _heal() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player:
		player.health.heal(player.health.max_health)
	Hero.refill_energy()
	Narration.say("Soigné.", 1.0)


func _apply_invincible(player: Player) -> void:
	if player and is_instance_valid(player):
		player.health.min_health = 1 if invincible else 0
