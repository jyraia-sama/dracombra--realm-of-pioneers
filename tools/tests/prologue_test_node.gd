extends Node
## Test automatique du prologue complet (en accéléré).

var failures := 0


func _ready() -> void:
	Engine.time_scale = 4.0
	# Le testeur survit aux changements de scène.
	_start.call_deferred()


func _start() -> void:
	reparent(get_tree().root)
	get_tree().current_scene = null
	_run()


func _check(cond: bool, label: String) -> void:
	print(("OK   " if cond else "FAIL ") + label)
	if not cond:
		failures += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _wait_until(cond: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await get_tree().physics_frame
	return cond.call()


func _goto(path: String) -> Node:
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	return get_tree().current_scene


func _player() -> Player:
	return get_tree().current_scene.get_node("Player") as Player


func _run() -> void:
	# ---------------------------------------------------------------- 1. Introduction
	var cave := await _goto("res://scenes/levels/prologue/cave_entrance.tscn")
	var decor: TileMapLayer = cave.get_node("Decor")
	var rubble: Array = cave.get("rubble_cells")
	await _frames(3)
	_check(rubble.size() > 5, "intro : %d cases d'éboulement prévues" % rubble.size())
	_check(rubble.all(func(c): return decor.get_cell_source_id(c) == -1), "intro : l'entrée est ouverte au début")
	_check(_player().input_locked, "intro : commandes bloquées pendant la cinématique")
	var ok := await _wait_until(func(): return get_tree().root.get_node("Game").has_flag(&"prologue_intro_done"), 1500)
	_check(ok, "intro : cinématique terminée")
	_check(rubble.all(func(c): return decor.get_cell_source_id(c) == 0), "intro : tous les éboulis sont tombés")
	_check(not _player().input_locked, "intro : le joueur reprend la main")
	var p := _player()
	var start_x := p.global_position.x
	Input.action_press("move_left")
	await _frames(90)
	Input.action_release("move_left")
	_check(p.global_position.x > Vector2(rubble[0] * 16).x, "intro : l'éboulement bloque le retour (x=%.0f)" % p.global_position.x)

	# ---------------------------------------------------------------- 2. Gobelin des roches
	var goblin: RockGoblin = cave.get_node("RockGoblin")
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != goblin:
			e.global_position = Vector2(-4000, -4000)
	p.global_position = goblin.global_position + Vector2(-5 * 16, 0)
	p.health.set_health(5)
	var thrown := await _wait_until(func(): return get_tree().current_scene.find_children("*", "ThrownRock", true, false).size() > 0, 400)
	_check(thrown, "gobelin : lance une pierre")
	var hp_before := p.health.current_health
	var hit := await _wait_until(func(): return p.health.current_health < hp_before, 400)
	_check(hit, "gobelin : la pierre blesse le guerrier")
	await _wait_until(func(): return not p.health.is_invulnerable(), 300)
	p.global_position = goblin.global_position + Vector2(-1.2 * 16, 0)
	var charged := await _wait_until(func(): return goblin.state == RockGoblin.State.CHARGE_WINDUP or goblin.state == RockGoblin.State.CHARGE, 200)
	_check(charged, "gobelin : fonce quand le guerrier est trop près")
	# On l'achève.
	var stones_before: int = get_tree().root.get_node("Inventory").get_count(&"stone")
	for i in 3:
		await _wait_until(func(): return p.state == Player.State.NORMAL, 200)
		if not is_instance_valid(goblin):
			break
		goblin.state = RockGoblin.State.RECOVER
		goblin._state_timer = 2.0
		goblin.charge_hitbox.active = false
		p.global_position = goblin.global_position + Vector2(-14, 0)
		p.health.set_invulnerable(2.0)
		p.facing = Vector2.RIGHT
		p.perform_attack()
		await _frames(30)
	await _frames(60)
	_check(not is_instance_valid(goblin), "gobelin : vaincu en 3 coups")
	var pickups := get_tree().current_scene.find_children("*", "Pickup", true, false)
	var already: int = get_tree().root.get_node("Inventory").get_count(&"stone") - stones_before
	_check(pickups.size() + already >= 1, "gobelin : laisse du butin (%d au sol, %d déjà ramassé)" % [pickups.size(), already])
	for pk in pickups:
		if is_instance_valid(pk) and pk.item.id == &"stone":
			p.global_position = pk.global_position
			await _frames(30)
	_check(get_tree().root.get_node("Inventory").get_count(&"stone") > stones_before, "butin : %d pierre(s) dans l'inventaire" % get_tree().root.get_node("Inventory").get_count(&"stone"))
	var hud_items: HBoxContainer = get_tree().current_scene.get_node("HUD/Items")
	_check(hud_items.get_child_count() >= 2, "HUD : la pierre est affichée")

	# ---------------------------------------------------------------- 3. Slime et gelée
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.name != "Slime":
			e.global_position = Vector2(-4000, -4000)
	var slime: Slime = cave.get_node("Slime")
	# Terrain dégagé au centre de la salle des slimes.
	p.global_position = Vector2(37 * 16 + 8, 18 * 16 + 16)
	slime.global_position = p.global_position + Vector2(14, 0)
	for i in 6:
		await _wait_until(func(): return p.state == Player.State.NORMAL, 200)
		if not is_instance_valid(slime):
			break
		slime.state = Slime.State.IDLE
		slime.global_position = p.global_position + Vector2(14, 0)
		p.health.set_invulnerable(2.0)
		p.facing = Vector2.RIGHT
		p.perform_attack()
		await _frames(30)
	await _frames(40)
	print("DEBUG slime valide=", is_instance_valid(slime), " pickups=", get_tree().current_scene.find_children("*", "Pickup", true, false).map(func(x): return x.item.id))
	for pk in get_tree().current_scene.find_children("*", "Pickup", true, false):
		if is_instance_valid(pk) and pk.item.id == &"slime_gel":
			p.global_position = pk.global_position
			await _frames(30)
	_check(get_tree().root.get_node("Inventory").get_count(&"slime_gel") >= 1, "butin : %d gelée(s) de slime" % get_tree().root.get_node("Inventory").get_count(&"slime_gel"))

	# ---------------------------------------------------------------- 4. Le couloir de la horde
	var exit: LevelExit = cave.get_node("ExitToTunnel")
	p.global_position = exit.global_position
	var in_tunnel := await _wait_until(func(): return get_tree().current_scene != null and get_tree().current_scene.name == "HordeTunnel", 600)
	_check(in_tunnel, "sortie : arrivée dans le couloir de la horde")
	if not in_tunnel:
		_end()
		return
	await _frames(5)
	var tunnel := get_tree().current_scene
	tunnel.horde_duration = 6.0
	p = _player()
	_check(not p.input_locked, "horde : le joueur contrôle le héros au début")
	var spawned := await _wait_until(func(): return get_tree().get_nodes_in_group("enemies").size() >= 2, 600)
	_check(spawned, "horde : les monstres surgissent des fissures (%d)" % get_tree().get_nodes_in_group("enemies").size())
	var flight := await _wait_until(func(): return tunnel.phase == 1, 900)
	_check(flight, "horde : bascule en fuite après la partie jouable")
	_check(p.input_locked, "fuite : cinématique, le joueur ne contrôle plus")
	var bars: ColorRect = get_tree().root.get_node("Narration/TopBar")
	await _frames(40)
	_check(bars.offset_bottom > 20.0, "fuite : bandes noires de cinéma affichées")
	var scared := await _wait_until(func(): return tunnel.phase >= 2, 2400)
	_check(scared, "fuite : le héros atteint les abords de la tanière (x=%.0f)" % p.global_position.x)
	var n_before: int = get_tree().get_nodes_in_group("enemies").size()
	await _frames(30)
	var fearful := get_tree().get_nodes_in_group("enemies").filter(func(e): return e.get_node("Fear").is_scared)
	_check(n_before == 0 or fearful.size() == get_tree().get_nodes_in_group("enemies").size(), "peur : tous les monstres sont terrifiés (%d)" % fearful.size())
	var done := await _wait_until(func(): return tunnel.phase == 3, 1500)
	_check(done, "peur : la cinématique se termine")
	_check(not p.input_locked, "peur : le joueur reprend la main")
	var gone := await _wait_until(func(): return get_tree().get_nodes_in_group("enemies").size() == 0, 900)
	_check(gone, "peur : la horde a disparu")
	_check(bars.offset_bottom < 1.0, "peur : bandes noires retirées")
	_check(p.collision_mask == 5, "peur : collisions du héros rétablies")

	var exit2: LevelExit = tunnel.get_node("ExitToLair")
	p.global_position = exit2.global_position
	var arrived := await _wait_until(func(): return get_tree().current_scene != null and get_tree().current_scene.name == "SolakorLair", 600)
	_check(arrived, "sortie : arrivée dans la tanière de Solakor")
	if not arrived:
		_end()
		return
	await _frames(5)
	var lair := get_tree().current_scene
	_check(get_tree().root.get_node("Inventory").get_count(&"stone") > 0, "inventaire conservé en changeant de niveau")

	# ---------------------------------------------------------------- 5. Solakor
	lair.fight_duration = 6.0
	var dragon: Solakor = lair.get_node("Solakor")
	p = _player()
	_check(not dragon.awake, "Solakor : endormi à l'arrivée")
	_check(not lair.crevasse_exit.enabled, "crevasse : fermée au début")
	p.global_position = dragon.global_position + Vector2(0, 5 * 16)
	var woke := await _wait_until(func(): return dragon.awake, 120)
	_check(woke, "Solakor : se réveille quand le héros approche")
	_check(lair.phase == 1, "combat : phase de combat")
	await _wait_until(func(): return not p.input_locked, 600)
	# On frappe le dragon : aucun effet.
	p.global_position = dragon.global_position + Vector2(0, 2.5 * 16)
	p.facing = Vector2.UP
	p.perform_attack()
	await _frames(20)
	_check(dragon.get_node("Health").current_health == 999 or dragon.get_node("Health").current_health >= 998, "combat : les coups n'entament pas Solakor")
	var lowest := p.health.max_health
	for i in 600:
		lowest = mini(lowest, p.health.current_health)
		if lair.phase != 1:
			break
		await get_tree().physics_frame
	_check(lowest < p.health.max_health, "combat : Solakor blesse le héros (PV min %d)" % lowest)
	_check(p.health.current_health >= 1 and p.state != Player.State.DEAD, "combat : le héros ne peut pas mourir ici")
	var escaped := await _wait_until(func(): return lair.phase == 3, 1500)
	_check(escaped, "climax : la fuite commence")
	_check(p.health.current_health == 1, "griffe incandescente : héros à 1 PV")
	var dec: TileMapLayer = lair.get_node("Decor")
	_check(lair.crevasse_cells.all(func(c): return dec.get_cell_source_id(c) == -1), "crevasse : les éboulis ont été détruits")
	_check(lair.crevasse_exit.enabled, "crevasse : sortie ouverte")
	_check(is_equal_approx(p.speed_multiplier, lair.wounded_speed), "fuite : le héros blessé avance plus lentement")

	# On rampe jusqu'à la sortie par le chemin (test de collision du passage).
	var target: Vector2 = lair.crevasse_exit.global_position
	p.global_position = Vector2(lair.crevasse_light.global_position.x - 4 * 16, target.y)
	_crawl_target = target
	var reached_end := await _wait_until(_crawl_step, 1500)
	Input.action_release("move_right")
	Input.action_release("move_down")
	Input.action_release("move_up")
	var in_passage := await _wait_until(func(): return _scene_is("WoundedPassage"), 400)
	_check(reached_end and in_passage, "passage : le héros tombe dans le boyau après la crevasse")
	await _frames(10)
	var passage := get_tree().current_scene
	p = passage.get_node("Player")
	_check(p.health.current_health == 1, "passage : le héros n'a plus qu'1 PV")
	_check(p.actions_locked and p.speed_multiplier < 0.5, "passage : il ne peut ni frapper ni rouler, et avance lentement")
	await _wait_until(func(): return not p.input_locked, 400)
	var start_drops: int = passage.wound.drop_count()
	await _walk_to(p, p.global_position + Vector2(60, 0), 300)
	_check(passage.wound.drop_count() > start_drops + 3, "passage : il laisse une traînée de sang (%d gouttes)" % passage.wound.drop_count())
	p.global_position = passage.rest_point + Vector2(-30, 0)
	var paused := false
	for i in 300:
		if p.input_locked:
			paused = true
			break
		await _walk_to(p, passage.rest_point, 1)
	_check(paused, "passage : il s'arrête pour reprendre son souffle")
	var resumed := await _wait_until(func(): return not p.input_locked, 1200)
	_check(resumed, "passage : puis il repart")
	var exit_node: Area2D = passage.get_node("ExitToSylve")
	p.global_position = exit_node.global_position + Vector2(-5 * 16, 0)
	await _walk_to(p, exit_node.global_position + Vector2(16, 0), 600)
	var in_sylve := await _wait_until(func(): return _scene_is("Sylve"), 400)
	_check(in_sylve, "sylve : la sortie mène à la Sylve des Dracombres")
	await _frames(10)
	var sylve := get_tree().current_scene
	p = sylve.get_node("Player")
	_check(sylve.phase == 0 and sylve.wound.active, "sylve : il arrive toujours blessé")
	await _wait_until(func(): return not p.input_locked, 1200)

	# La rivière bloque le passage, sauf au gué.
	var ground: TileMapLayer = sylve.get_node("Ground")
	var water_cell := Vector2i(-1, -1)
	for x in range(60, 140):
		var c := Vector2i(x, 30)
		var ac := ground.get_cell_atlas_coords(c)
		if ac.y >= 3 and ac.y <= 5:
			water_cell = c
			break
	var saved := p.global_position
	p.global_position = Vector2((water_cell.x - 2) * 16 + 8, water_cell.y * 16 + 12)
	await _walk_to(p, p.global_position + Vector2(80, 0), 80)
	_check(water_cell.x > 0 and p.global_position.x < water_cell.x * 16 + 4, "sylve : on ne traverse pas la rivière à la nage")
	p.global_position = saved

	# Il atteint les ruines et s'effondre.
	p.global_position = sylve.rest_point + Vector2(-60, -30)
	await _walk_to(p, sylve.rest_point, 400)
	var collapsed := await _wait_until(func(): return sylve.phase == 1, 200)
	_check(collapsed, "sylve : il s'effondre au pied du grand chêne")
	var dark := false
	for i in 800:
		if Transition.curtain.color.a > 0.98:
			dark = true
			break
		await get_tree().physics_frame
	_check(dark, "sylve : fondu au noir (rideau %.2f, phase %d)" % [Transition.curtain.color.a, sylve.phase])
	var in_city := await _wait_until(func(): return _scene_is("Dracombra"), 3000)
	_check(in_city, "réveil : quelques jours plus tard, il se réveille à Dracombra")
	var city := get_tree().current_scene
	p = city.get_node("Player")
	var free := await _wait_until(func(): return city.phase == 1 and not p.input_locked, 3000)
	_check(free, "réveil : il se relève, le chapitre 1 commence")
	_check(p.global_position.distance_to(city.get_node("Guild").global_position) < 64.0, "réveil : près du feu de camp de la future guilde")
	_check(p.health.current_health == p.health.max_health, "réveil : ses blessures sont guéries (%d PV)" % p.health.current_health)
	_check(p.health.max_health == 12, "réveil : la blessure de Solakor lui a coûté des PV max (%d = 10 + 2 du guerrier)" % p.health.max_health)
	_check(p.sprite.visible and p.get_node_or_null("Visual/WoundSprite") == null, "réveil : il a retrouvé son allure normale")
	_check(not p.actions_locked and is_equal_approx(p.speed_multiplier, 1.0), "réveil : il peut de nouveau marcher, frapper et rouler")
	_check(get_tree().root.get_node("Game").has_flag(&"prologue_done"), "réveil : le prologue est terminé, l'histoire commence")
	_check(get_tree().root.get_node("Save").has_save(), "réveil : première sauvegarde automatique")
	var before := p.global_position
	await _walk_to(p, before + Vector2(0, 40), 60)
	_check(p.global_position.distance_to(before) > 20.0, "réveil : il marche à pleine vitesse")
	get_tree().root.get_node("Save").delete_save()
	_end()


var _crawl_target := Vector2.ZERO


func _scene_is(scene_name: String) -> bool:
	return get_tree().current_scene != null and get_tree().current_scene.name == scene_name


## Marche vers `target` avec les touches de déplacement.
func _walk_to(pl: Player, target: Vector2, max_frames: int) -> void:
	for i in max_frames:
		if not is_instance_valid(pl) or pl.global_position.distance_to(target) < 5.0 or (i > 0 and pl.input_locked):
			break
		var d := pl.global_position.direction_to(target)
		_hold("move_left", d.x < -0.3)
		_hold("move_right", d.x > 0.3)
		_hold("move_up", d.y < -0.3)
		_hold("move_down", d.y > 0.3)
		await get_tree().physics_frame
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)


func _hold(action: String, on: bool) -> void:
	if on:
		Input.action_press(action)
	else:
		Input.action_release(action)


var _dbg := 0
func _crawl_step() -> bool:
	if get_tree().current_scene == null or get_tree().current_scene.name != "SolakorLair":
		return true
	var pl := get_tree().current_scene.get_node("Player") as Player
	_dbg += 1
	if _dbg % 100 == 1:
		print("DEBUG crawl pos=", pl.global_position, " state=", pl.state, " locked=", pl.input_locked, " target=", _crawl_target)
	Input.action_press("move_right")
	var dy := _crawl_target.y - pl.global_position.y
	if absf(dy) > 4.0:
		Input.action_press("move_down" if dy > 0 else "move_up")
	else:
		Input.action_release("move_down")
		Input.action_release("move_up")
	return false


func _end() -> void:
	print("TOTAL FAILURES: %d" % failures)
	get_tree().quit(1 if failures > 0 else 0)
