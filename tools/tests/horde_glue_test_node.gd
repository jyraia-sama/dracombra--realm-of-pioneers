extends Node
## Pendant la fuite, aucun monstre ne doit rester collé au héros.

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

func _run() -> void:
	var path := "res://scenes/levels/prologue/horde_tunnel.tscn"
	for run in 3:
		get_tree().change_scene_to_file(path)
		for i in 10: await get_tree().physics_frame
		var tunnel := get_tree().current_scene
		var player: Player = tunnel.get_node("Player")
		tunnel.horde_duration = 4.0
		tunnel.spawn_interval_end = 0.3
		while tunnel.phase == 0:
			await get_tree().physics_frame
		var streak := {}
		var worst := 0
		var frames := 0
		while tunnel.phase == 1 and frames < 2400:
			frames += 1
			for e in get_tree().get_nodes_in_group("enemies"):
				var close: bool = e.global_position.distance_to(player.global_position) < 10.0
				streak[e] = (int(streak.get(e, 0)) + 1) if close else 0
				worst = maxi(worst, int(streak[e]))
			await get_tree().physics_frame
		_check(worst < 30, "fuite %d : aucun monstre ne reste collé (pire : %d images)" % [run, worst])
