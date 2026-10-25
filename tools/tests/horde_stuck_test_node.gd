extends Node
## La fuite de la horde ne doit jamais rester bloquée derrière un rocher.

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

func _until(cond: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await get_tree().physics_frame
	return cond.call()

func _run() -> void:
	var path := "res://scenes/levels/prologue/horde_tunnel.tscn"
	var rocks: Array[Vector2] = []
	get_tree().change_scene_to_file(path)
	await _until(func(): return get_tree().current_scene != null and get_tree().current_scene.scene_file_path == path, 120)
	for p in get_tree().current_scene.get_node("Props").get_children():
		if p.name.begins_with("Rock") and p.global_position.x < 1350.0 and p.global_position.x > 150.0:
			rocks.append(p.global_position)
	print("rochers testés : %d" % rocks.size())
	var i := 0
	for r in rocks:
		get_tree().change_scene_to_file(path)
		await _until(func(): return get_tree().current_scene != null and get_tree().current_scene.scene_file_path == path and get_tree().current_scene.get_node_or_null("Player") != null, 120)
		await get_tree().physics_frame
		var tunnel := get_tree().current_scene
		var player: Player = tunnel.get_node("Player")
		player.global_position = r + Vector2(-12, 2)
		await get_tree().physics_frame
		tunnel._start_flight()
		var ok := false
		for f in 1300:
			if tunnel.phase >= 2:
				ok = true
				break
			if f % 60 == 0 and i in [4, 6]:
				print("   f%d pos %s idx %d mask %d stuck %.2f" % [f, player.global_position, tunnel._path_index, player.collision_mask, tunnel._stuck_timer])
			await get_tree().physics_frame
		_check(ok, "rocher %d (%.0f, %.0f) : la fuite atteint la tanière (héros x=%.0f)" % [i, r.x, r.y, player.global_position.x])
		i += 1
