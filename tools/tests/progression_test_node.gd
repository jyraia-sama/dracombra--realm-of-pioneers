extends Node
## Test de la progression : XP, niveaux (max 100), caractéristiques, techniques et sorts,
## fiche du personnage, sauvegarde.

var failures := 0


func _ready() -> void:
	_start.call_deferred()


func _start() -> void:
	reparent(get_tree().root)
	get_tree().current_scene = null
	await _run()
	print("TOTAL FAILURES: %d" % failures)
	get_tree().quit()


func _check(cond: bool, label: String) -> void:
	print(("OK   " if cond else "FAIL ") + label)
	if not cond:
		failures += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _until(cond: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await get_tree().physics_frame
	return cond.call()


func _goto(path: String) -> Node:
	get_tree().change_scene_to_file(path)
	await _until(func(): return get_tree().current_scene != null and get_tree().current_scene.scene_file_path == path, 120)
	await _frames(3)
	return get_tree().current_scene


func _g(n: String) -> Node:
	return get_tree().root.get_node(n)


func _run() -> void:
	var Game_ := _g("Game")
	var HeroA := _g("Hero")
	var SaveA := _g("Save")
	Game_.reset()
	HeroA.reset()
	HeroA.hero_name = "Testeur"
	SaveA.delete_save()
	Game_.set_flag(&"prologue_done")
	var city := await _goto("res://scenes/levels/dracombra/dracombra.tscn")
	var player: Player = city.get_node("Player")

	# --- Niveaux et XP
	_check(HeroA.xp_to_next(1) == 8 and HeroA.xp_to_next(50) > HeroA.xp_to_next(10), "xp : la courbe monte (%d, %d, %d)" % [HeroA.xp_to_next(1), HeroA.xp_to_next(10), HeroA.xp_to_next(50)])
	_check(HeroA.known_skills().size() == 1 and HeroA.slots()[0] == &"power_strike", "techniques : Frappe puissante connue et placée sur R au niveau 1")
	HeroA.gain_xp(8)
	_check(HeroA.level() == 2 and HeroA.free_points() == 2, "niveau 2 : 2 points à répartir")
	var hp_before: int = player.health.max_health
	HeroA.spend_point(&"vit")
	HeroA.spend_point(&"vit")
	_check(HeroA.allocated(&"vit") == 2 and HeroA.free_points() == 0, "caractéristiques : 2 points en vitalité")
	_check(player.health.max_health == hp_before + 1, "vitalité : les PV max montent (%d -> %d)" % [hp_before, player.health.max_health])
	HeroA.reset_points()
	_check(HeroA.free_points() == 2 and HeroA.allocated(&"vit") == 0, "caractéristiques : on peut redistribuer")
	var total := 0
	for l in range(2, 101):
		total += HeroA.xp_to_next(l)
	HeroA.gain_xp(total * 2)
	_check(HeroA.level() == 100, "niveau maximum : 100 (%d)" % HeroA.level())
	_check(HeroA.known_skills().size() == 6, "niveau 100 : les 6 techniques du guerrier sont connues")
	_check(HeroA.slots().size() == 3 and not HeroA.slots().has(&""), "les 3 emplacements de techniques sont remplis")
	_check(HeroA.damage() > 5 and player.health.max_health > 30, "niveau 100 : dégâts %d, PV %d" % [HeroA.damage(), player.health.max_health])

	# --- Chaque technique de chaque classe se lance sans erreur
	for cls in HeroA.ORDER:
		HeroA.unlock(cls)
		HeroA.levels[cls] = 100
		HeroA.switch_to(cls)
		if cls == &"warrior":
			HeroA.energy = HeroA.energy_max()
		await _frames(2)
		for id in SkillBook.of_class(cls):
			HeroA.energy = HeroA.energy_max()
			player.skills.cooldowns.clear()
			player.state = Player.State.NORMAL
			player.global_position = city.get_node("Guild").global_position + Vector2(0, 6 * 16)
			player.face(Vector2.DOWN)
			var before: float = HeroA.energy
			var ok: bool = player.skills.try_cast(id)
			await _frames(40)
			_check(ok and HeroA.energy < before + 0.5 and player.skills.cooldown_left(id) > 0.0, "%s : %s" % [HeroA.info()["name"], SkillBook.SKILLS[id]["name"]])
		await _frames(30)
	HeroA.switch_to(&"warrior")
	player.state = Player.State.NORMAL
	HeroA.energy = 0.0
	_check(not player.skills.try_cast(&"power_strike"), "sans endurance, pas de technique")
	await _frames(60)
	_check(HeroA.energy > 0.0, "l'endurance remonte toute seule")

	# --- Protection : Peau de fer
	HeroA.add_buff(&"guard", 0.0, 2.0)
	_check(player._filter_damage(3) == 0, "bouclier : aucun dégât")
	HeroA.clear_buffs()
	var dealt: int = player._filter_damage(3)
	_check(dealt >= 0 and dealt <= 3, "défense : dégâts réduits ou parés (%d)" % dealt)

	# --- Fiche du personnage
	var menu := _g("GameMenu")
	menu.open(1)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(menu._sheet.text.contains("niveau 100"), "fiche : le niveau s'affiche")
	_check(menu._skill_box.get_child_count() == 6, "fiche : les 6 techniques sont listées")
	menu._select_skill(&"whirlwind")
	menu._slot_buttons[0].pressed.emit()
	_check(HeroA.slots()[0] == &"whirlwind", "fiche : on place le Tourbillon sur R")
	HeroA.unspent[&"warrior"] = 1
	menu._refresh_sheet()
	menu._stat_rows[&"str"]["plus"].pressed.emit()
	_check(HeroA.allocated(&"str") == 1, "fiche : le bouton + dépense un point")
	menu.close()

	# --- Combat : le Tourbillon touche un sanglier
	var sylve := await _goto("res://scenes/levels/sylve/sylve.tscn")
	player = sylve.get_node("Player")
	var boar: Boar = null
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Boar:
			boar = e
			break
	if boar:
		player.health.set_invulnerable(999.0)
		var hp: int = boar.health.current_health
		player.global_position = boar.global_position + Vector2(-10, 4)
		player.state = Player.State.NORMAL
		player.skills.cooldowns.clear()
		HeroA.energy = HeroA.energy_max()
		player.skills.try_cast(&"whirlwind")
		await _frames(20)
		_check(boar.health.current_health < hp or boar.state == Boar.State.DEAD, "tourbillon : le sanglier est touché")
	else:
		_check(false, "sylve : un sanglier pour tester")

	# --- Sauvegarde
	SaveA.save_game()
	var lvl: int = HeroA.level()
	HeroA.reset()
	SaveA.load_game()
	await _until(func(): return get_tree().current_scene != null and not _g("Transition").is_busy and HeroA.level() == lvl, 400)
	_check(HeroA.level() == 100 and HeroA.allocated(&"str") == 1 and HeroA.slots()[0] == &"whirlwind", "chargement : niveau, points et techniques restaurés")
	SaveA.delete_save()
