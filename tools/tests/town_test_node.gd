extends Node
## Test de la ville et des systèmes de jeu : récolte, construction, nuits, guilde,
## artisanat et classes, sanglier, sauvegarde, menu, porte Sylve <-> Dracombra.

var failures := 0


func _ready() -> void:
	_start.call_deferred()


func _start() -> void:
	reparent(get_tree().root)
	get_tree().current_scene = null
	Engine.time_scale = 3.0
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


func _collect(level: Node, player: Player) -> void:
	await _frames(40)
	# Deux passages : un objet qui rebondit peut échapper au premier.
	for pass_i in 2:
		for p in level.find_children("*", "Pickup", true, false):
			if is_instance_valid(p):
				player.global_position = p.global_position
				await _frames(8)


func _hit(player: Player, target: Vector2, times: int) -> void:
	for i in times:
		player.global_position = target + Vector2(-14, 0)
		player.face(Vector2.RIGHT)
		player.perform_attack()
		await _frames(30)


func _run() -> void:
	var Game_ := _g("Game")
	var Inv := _g("Inventory")
	var TownA := _g("Town")
	var HeroA := _g("Hero")
	var SaveA := _g("Save")
	Game_.reset()
	HeroA.reset()
	HeroA.hero_name = "Testeur"
	SaveA.delete_save()
	Game_.set_flag(&"prologue_done")

	# --- Dracombra
	var city := await _goto("res://scenes/levels/dracombra/dracombra.tscn")
	var player: Player = city.get_node("Player")
	_check(city.get_node_or_null("Guild") != null, "dracombra : la guilde (feu de camp) est au centre")
	_check(TownA.center == city.center_cell, "dracombra : le centre de la ville est connu (%s)" % TownA.center)
	_check(player.health.max_health == 150, "héros : 120 PV + 6 par VIT pour le guerrier après le prologue (%d)" % player.health.max_health)
	_check(TownA.is_unlocked(TownA.center + Vector2i(3, 0)) and not TownA.is_unlocked(TownA.center + Vector2i(30, 0)), "dracombra : seul le quartier du camp est constructible")

	# --- Récolte : un arbre donne du bois
	var tree: Node2D = null
	for p in city.get_node("Props").get_children():
		var h := p.get_node_or_null("Harvest")
		if h and h.item_id == &"wood" and p.visible:
			if tree == null or p.global_position.distance_to(player.global_position) < tree.global_position.distance_to(player.global_position):
				tree = p
	_check(tree != null, "récolte : des arbres poussent dans les ruines")
	await _hit(player, tree.global_position, 3)
	_check(tree.visible, "récolte : sans hache, 3 coups ne suffisent pas")
	await _hit(player, tree.global_position, 3)
	await _frames(30)
	_check(not tree.visible, "récolte : sans hache, l'arbre tombe après 6 coups")
	await _collect(city, player)
	_check(Inv.get_count(&"wood") >= 1, "récolte : du bois dans le sac (%d)" % Inv.get_count(&"wood"))
	var debris: Node2D = null
	for p in city.get_node("Props").get_children():
		var h := p.get_node_or_null("Harvest")
		if h and h.item_id == &"stone" and p.visible:
			if debris == null or p.global_position.distance_to(player.global_position) < debris.global_position.distance_to(player.global_position):
				debris = p
	Inv.add_item(Inv.item_by_id(&"pickaxe"), 1)
	var hits_needed: int = debris.get_node("Harvest").hits
	await _hit(player, debris.global_position, hits_needed)
	await _frames(30)
	await _collect(city, player)
	_check(not debris.visible and Inv.get_count(&"stone") >= 1, "déblayage : des décombres donnent de la pierre (%d)" % Inv.get_count(&"stone"))

	# --- Construction d'une tente
	Inv.add_item(Inv.item_by_id(&"wood"), 80)
	Inv.add_item(Inv.item_by_id(&"stone"), 60)
	Inv.add_item(Inv.item_by_id(&"flax"), 20)
	var build: BuildMode = city.get_node("BuildMode")
	var guild_pos: Vector2 = city.get_node("Guild").global_position
	# Le menu s'ouvre, la caméra devient libre, le héros ne bouge plus.
	build.open()
	await _frames(2)
	_check(build.state == BuildMode.State.MENU and build._panel.visible, "construction : le menu s'ouvre (B)")
	_check(get_viewport().get_camera_2d() == build._cam and player.input_locked, "construction : caméra libre, héros immobile")
	_check(build._entries.size() > 8 and build._preview.texture != null, "construction : liste et aperçu du bâtiment")
	# La guilde garde ses 4 x 4 cases.
	build.start(TownA.building(&"tent"))
	build._cam.global_position = guild_pos + Vector2(0, -24)
	await _frames(3)
	_check(not build.valid and build.reason.contains("guilde"), "construction : impossible sur l'emprise de la guilde (%s)" % build.reason)
	build._cam.global_position = guild_pos + Vector2(0, 5 * 16)
	await _frames(3)
	var tries := 0
	while not build.valid and tries < 30:
		build._cam.global_position += Vector2(16, 0)
		await _frames(2)
		tries += 1
	_check(build.valid, "construction : un emplacement libre est trouvé (%s)" % build.reason)
	var placed_cell: Vector2i = build.cell
	build._confirm()
	_check(TownA.sites.size() == 1 and build.state == BuildMode.State.MENU, "construction : le chantier est posé, retour au menu")
	await _frames(3)
	var site: Building = city.get_node("Town").get_child(0)
	_check(site != null and site._sprite.texture.resource_path.contains("chantier_3x2"), "construction : le chantier 3 x 2 apparaît")
	# Le même emplacement est maintenant pris (emprise réservée).
	build.start(TownA.building(&"tent"))
	build._cam.global_position = Building.footprint_rect(TownA.building(&"tent"), placed_cell).get_center()
	await _frames(3)
	_check(not build.valid, "construction : on ne peut pas poser sur un autre bâtiment (%s)" % build.reason)
	# Chemins : on trace du gravier, on l'efface, la pierre revient.
	build.start_path(1)
	var stone_before: int = Inv.get_count(&"stone")
	var path_from: Vector2 = guild_pos + Vector2(-56, 24)
	build._cam.global_position = path_from
	await _frames(2)
	build._press()
	for i in 4:
		build._cam.global_position += Vector2(16, 0)
		await _frames(2)
	build._painting = false
	_check(TownA.paths.size() >= 4 and Inv.get_count(&"stone") < stone_before, "chemins : on trace un chemin de gravier (%d cases)" % TownA.paths.size())
	_check(city.get_node_or_null("Paths") != null, "chemins : la couche des chemins est dans la ville")
	var painted: int = TownA.paths.size()
	build.start_erase()
	build._cam.global_position = path_from
	await _frames(2)
	build._press()
	build._painting = false
	_check(TownA.paths.size() == painted - 1, "chemins : la gomme efface une case")
	build.stop()
	await _frames(2)
	_check(not build.active and not player.input_locked and get_viewport().get_camera_2d() != build._cam, "construction : on quitte, la caméra revient au héros")
	TownA.deliver(site.data.cost, site.record["delivered"])
	_check(TownA.missing(site.data.cost, site.record["delivered"]).is_empty(), "construction : les matériaux sont déposés")
	await Game_.sleep()
	_check(Game_.day == 2, "nuit : un jour a passé (jour %d)" % Game_.day)
	_check(TownA.sites[0]["built"], "construction : la tente est terminée le lendemain")
	_check(TownA.site_name(TownA.sites[0]) == "Tente" and TownA.housing_of(TownA.sites[0]) == 2, "paliers : palier 1 = Tente (2 places)")
	_check(TownA.upgrade_block(TownA.sites[0]).contains("Village"), "paliers : la cabane demande une guilde de village")

	# --- Artisanat et classes
	var workbench: Dictionary = TownA.add_site(&"workbench", TownA.center + Vector2i(-5, 3))
	workbench["built"] = true
	TownA.changed.emit()
	var rope_recipe: Dictionary = {}
	for r in _g("Crafting").RECIPES:
		if r["out"] == &"rope":
			rope_recipe = r
	_check(_g("Crafting").craft(rope_recipe), "établi : corde de lin fabriquée avec du lin")
	Inv.add_item(Inv.item_by_id(&"hide"), 2)
	var leather_recipe: Dictionary = {}
	var bow_recipe: Dictionary = {}
	for r in _g("Crafting").RECIPES:
		if r["out"] == &"leather":
			leather_recipe = r
		if r["out"] == &"bow":
			bow_recipe = r
	_g("Crafting").craft(leather_recipe)
	_g("Crafting").craft(leather_recipe)
	_check(Inv.get_count(&"leather") == 2, "séchoir : 2 peaux deviennent 2 cuirs")
	_check(_g("Crafting").craft(bow_recipe) and HeroA.unlocked.has(&"archer"), "établi : l'arc débloque la classe Archer")
	_check(HeroA.switch_to(&"archer") and HeroA.current == &"archer", "classes : on passe archer à Dracombra")
	player.perform_attack()
	await _frames(2)
	_check(city.find_children("*", "HeroProjectile", true, false).size() >= 1, "archer : l'attaque tire une flèche")
	HeroA.gain_xp(20)
	_check(HeroA.level(&"archer") == 2 and HeroA.level(&"warrior") == 1, "classes : chaque classe a son propre niveau")
	HeroA.switch_to(&"warrior")

	# --- La guilde passe au palier Village
	for i in 2:
		var t: Dictionary = TownA.add_site(&"tent", TownA.center + Vector2i(6 + i * 3, -4))
		t["built"] = true
	_check(TownA.start_guild_upgrade(), "guilde : les bâtiments requis sont là, les travaux commencent")
	TownA.deliver(TownA.next_upgrade()["cost"], TownA.guild_upgrade["delivered"])
	await Game_.sleep()
	await Game_.sleep()
	_check(TownA.tier == 1, "guilde : tente de guilde, Dracombra devient un village (palier %d)" % TownA.tier)
	_check(TownA.is_unlocked(TownA.center + Vector2i(20, 0)), "guilde : un nouveau quartier est constructible")
	var tent: Dictionary = TownA.sites[0]
	_check(TownA.start_site_upgrade(tent), "paliers : la tente peut devenir une cabane")
	TownA.deliver(TownA.building(&"tent").upgrade_cost(2), tent["upgrade"]["delivered"])
	await Game_.sleep()
	await Game_.sleep()
	_check(TownA.level_of(tent) == 2 and TownA.housing_of(tent) == 4, "paliers : cabane terminée, 4 places")

	# --- Menu
	var menu := _g("GameMenu")
	menu.open(0)
	await get_tree().process_frame
	_check(menu._bag_ids.size() >= 3, "menu : le sac liste les objets (%d)" % menu._bag_ids.size())
	menu._tabs.current_tab = 1
	await get_tree().process_frame
	_check(menu._sheet.text.contains("Testeur") and menu._sheet.text.contains("Archer"), "menu : fiche du personnage")
	menu._tabs.current_tab = 3
	await get_tree().process_frame
	_check(menu._map_view.texture != null, "menu : carte de Dracombra")
	menu.close()

	# --- Sauvegarde puis chargement
	SaveA.save_game()
	_check(SaveA.has_save(), "sauvegarde : fichier écrit")
	var sites_before: int = TownA.sites.size()
	TownA.reset()
	Inv.clear()
	SaveA.load_game()
	await _until(func(): return get_tree().current_scene != null and get_tree().current_scene.name == "Dracombra" and not _g("Transition").is_busy, 400)
	await _frames(5)
	_check(TownA.tier == 1 and TownA.sites.size() == sites_before, "chargement : la ville est restaurée")
	_check(Inv.get_count(&"wood") > 0 and HeroA.unlocked.has(&"archer"), "chargement : sac et classes restaurés")
	city = get_tree().current_scene
	_check(city.get_node("Town").get_child_count() == sites_before, "chargement : les bâtiments sont reconstruits")

	# --- Mise à jour d'une ancienne sauvegarde (avant le nouveau système de construction)
	var old_town: Dictionary = TownA.serialize()
	old_town.erase("build_version")
	var wood_before: int = Inv.get_count(&"wood")
	TownA.deserialize(old_town)
	_check(TownA.sites.is_empty() and TownA.paths.is_empty() and TownA.tier == 1, "mise à jour : bâtiments retirés, palier de la guilde gardé")
	_check(Inv.get_count(&"wood") > wood_before and Game_.pending_message.contains("reconstruire"), "mise à jour : matériaux rendus dans le sac, message affiché")
	Game_.pending_message = ""
	var same: Dictionary = TownA.serialize()
	TownA.add_site(&"tent", TownA.center + Vector2i(8, 6))
	same = TownA.serialize()
	TownA.deserialize(same)
	_check(TownA.sites.size() == 1, "mise à jour : une sauvegarde à jour garde ses bâtiments")

	# --- Démolition, et construction gratuite du mode admin
	var tent_cost: int = int(TownA.building(&"tent").cost[&"wood"])
	TownA.sites[0]["built"] = true
	var wood_now: int = Inv.get_count(&"wood")
	var refunded: Dictionary = TownA.demolish(TownA.sites[0])
	_check(TownA.sites.is_empty() and Inv.get_count(&"wood") == wood_now + tent_cost, "démolition : le logement disparaît, son bois revient (%s)" % refunded)
	var adm := _g("Admin")
	adm.free_build = true
	var bm: BuildMode = city.get_node("BuildMode")
	bm.start(TownA.building(&"forge"))
	bm._cam.global_position = city.get_node("Guild").global_position + Vector2(-90, 80)
	var tries2 := 0
	await _frames(3)
	while not bm.valid and tries2 < 30:
		bm._cam.global_position += Vector2(-16, 0)
		await _frames(2)
		tries2 += 1
	var stone_admin: int = Inv.get_count(&"stone")
	bm._confirm()
	_check(TownA.sites.size() == 1 and TownA.sites[0]["built"] and Inv.get_count(&"stone") == stone_admin, "admin : la forge est construite tout de suite, gratuitement")
	bm.start_demolish()
	bm._cam.global_position = Building.footprint_rect(TownA.building(&"forge"), TownA.site_cell(TownA.sites[0])).get_center()
	await _frames(3)
	bm._press()
	_check(TownA.sites.is_empty() and Inv.get_count(&"stone") == stone_admin, "admin : démolition instantanée, sans remboursement")
	bm.stop()
	adm.free_build = false

	# --- La porte vers la Sylve, et retour
	player = city.get_node("Player")
	var exit: Area2D = city.get_node("ExitToSylve")
	player.global_position = exit.global_position
	var in_sylve := await _until(func(): return get_tree().current_scene != null and get_tree().current_scene.name == "Sylve", 400)
	_check(in_sylve, "porte : on sort vers la Sylve")
	await _frames(10)
	var sylve := get_tree().current_scene
	player = sylve.get_node("Player")
	var gate: Area2D = sylve.get_node("ExitToDracombra")
	_check(player.global_position.distance_to(gate.global_position) < 80.0, "porte : on arrive devant l'arche de Dracombra")
	_check(gate.enabled, "porte : l'arche est ouverte après le prologue")

	# --- Sanglier
	var boar: Boar = null
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Boar:
			boar = e
			break
	_check(boar != null, "sylve : des sangliers dans les prairies")
	var hide_before: int = Inv.get_count(&"hide")
	player.health.set_invulnerable(999.0)
	for i in 8:
		if boar.state == Boar.State.DEAD:
			break
		player.global_position = boar.global_position + Vector2(-14, 0)
		player.face(Vector2.RIGHT)
		player.perform_attack()
		await _frames(25)
	_check(boar.state == Boar.State.DEAD, "sanglier : il tombe sous les coups")
	await _collect(sylve, player)
	_check(Inv.get_count(&"hide") > hide_before, "sanglier : une peau pour le cuir")
	var flax_plant: Node2D = null
	for p in sylve.get_node("Props").get_children():
		if p.name.begins_with("FlaxPlant") and p.visible:
			flax_plant = p
			break
	_check(flax_plant != null, "sylve : du lin pousse près de la rivière")
	player.global_position = gate.global_position
	var back := await _until(func(): return get_tree().current_scene != null and get_tree().current_scene.name == "Dracombra", 400)
	_check(back, "porte : retour à Dracombra par l'arche")
	SaveA.delete_save()
