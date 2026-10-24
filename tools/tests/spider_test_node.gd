extends Node
## Test de l'araignée d'obsidienne (dans la grande salle de la caverne).

var failures := 0


func _ready() -> void:
	_start.call_deferred()


func _start() -> void:
	reparent(get_tree().root)
	get_tree().current_scene = null
	get_tree().root.get_node("Game").set_flag(&"prologue_intro_done")
	get_tree().change_scene_to_file("res://scenes/levels/prologue/cave_entrance.tscn")
	await _until(func(): return get_tree().current_scene != null, 60)
	await _frames(2)
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
	return false


func _run() -> void:
	var level := get_tree().current_scene
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await _frames(2)
	var player: Player = level.get_node("Player")
	player.global_position = Vector2(36 * 16 + 8, 18 * 16 + 14)
	player.input_locked = true
	var spider: ObsidianSpider = load("res://scenes/enemies/obsidian_spider/obsidian_spider.tscn").instantiate()
	spider.position = player.global_position + Vector2(5 * 16, 0)
	level.add_child(spider)
	await _frames(2)
	_check(spider.health.current_health == 2, "araignée : 2 PV")
	_check(await _until(func(): return spider.state == ObsidianSpider.State.CHASE, 30), "elle repère le guerrier et court")
	_check(await _until(func(): return spider.state == ObsidianSpider.State.WINDUP, 120), "elle se ramasse avant de bondir")
	var hp := player.health.current_health
	_check(await _until(func(): return spider.state == ObsidianSpider.State.LEAP, 60), "elle bondit")
	_check(await _until(func(): return player.health.current_health < hp, 40), "le bond blesse le guerrier")
	_check(hp - player.health.current_health == 2, "le bond fait 2 dégâts (%d)" % (hp - player.health.current_health))
	_check(await _until(func(): return spider.state == ObsidianSpider.State.RECOVER, 40), "elle reste vulnérable après le bond")

	# Esquive : un guerrier qui roule pendant le bond n'est pas touché.
	player.health.heal(5)
	await _frames(60)
	player.input_locked = false
	_check(await _until(func(): return spider.state == ObsidianSpider.State.WINDUP, 200), "nouveau bond annoncé")
	hp = player.health.current_health
	await _until(func(): return spider.state == ObsidianSpider.State.LEAP, 60)
	Input.action_press("dodge")
	Input.action_press("move_down")
	await _frames(3)
	Input.action_release("dodge")
	await _until(func(): return spider.state != ObsidianSpider.State.LEAP, 40)
	Input.action_release("move_down")
	_check(player.health.current_health == hp, "la roulade évite le bond")

	# Deux coups d'épée la tuent ; elle lâche des éclats d'obsidienne.
	player.health.set_invulnerable(999.0)
	var inv := get_tree().root.get_node("Inventory")
	var shards: int = inv.get_count(&"obsidian_shard")
	await _frames(40)
	var swings := 0
	while spider.state != ObsidianSpider.State.DEAD and swings < 4:
		swings += 1
		var i := swings - 1
		player.global_position = spider.global_position + Vector2(-14, 0)
		player.face(Vector2.RIGHT)
		player.perform_attack()
		await _frames(25)
		print("   PV araignée après le coup %d : %d (état %d)" % [i + 1, spider.health.current_health, spider.state])
	_check(spider.state == ObsidianSpider.State.DEAD and swings <= 3, "quelques coups d'épée la tuent (%d)" % swings)
	var death_pos := spider.global_position
	await _frames(90)
	for p in level.find_children("*", "Area2D", true, false):
		if p.get_script() != null and str(p.get_script().resource_path).ends_with("pickup.gd"):
			player.global_position = p.global_position
			await _frames(8)
	print("   objets : ", inv.get_items())
	print("   éclats ramassés : %d (80 %% de chances)" % (inv.get_count(&"obsidian_shard") - shards))
	_check(not is_instance_valid(spider), "l'araignée disparaît")
