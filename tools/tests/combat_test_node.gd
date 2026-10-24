extends Node

var room: Node
var failures := 0


func _ready() -> void:
	_start.call_deferred()


func _start() -> void:
	reparent(get_tree().root)
	room = load("res://scenes/test/test_room.tscn").instantiate()
	get_tree().root.add_child(room)
	get_tree().current_scene = room
	_run()


func _check(cond: bool, label: String) -> void:
	print(("OK   " if cond else "FAIL ") + label)
	if not cond:
		failures += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _press(action: String) -> void:
	Input.action_press(action)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(action)


func _run() -> void:
	await _frames(2)
	var player: Player = room.get_node("Player")
	var s1: Slime = room.get_node("Slime")
	var s2: Slime = room.get_node("Slime2")
	var s3: Slime = room.get_node("Slime3")
	_check(player.health.current_health == 20 and player.health.max_health == 20, "guerrier : 20 PV au départ (prologue)")
	_check(get_tree().get_nodes_in_group("enemies").size() == 3, "3 slimes dans la salle")
	_check(room.get_node("HUD/HealthLabel").text == "PV : 20 / 20", "HUD affiche PV : 20 / 20")

	var p0 := s1.global_position
	await _frames(30)
	_check(s1.global_position == p0 and s1.state == Slime.State.IDLE, "slime immobile hors de portée")

	# Eloigner les autres slimes pour isoler le test.
	s2.global_position = Vector2(400, 300)
	s3.global_position = Vector2(-400, 300)

	player.global_position = Vector2(-50, -80)
	await _frames(5)
	_check(s1.state == Slime.State.CHASE, "slime poursuit quand le guerrier approche")
	var d_before := s1.global_position.distance_to(player.global_position)
	await _frames(10)
	var d_after := s1.global_position.distance_to(player.global_position)
	_check(d_after < d_before, "slime se rapproche (%.1f -> %.1f px)" % [d_before, d_after])

	for i in 180:
		await get_tree().physics_frame
		if player.health.current_health < 20:
			break
	_check(player.health.current_health == 19, "contact : guerrier perd 1 PV")
	_check(player.health.is_invulnerable(), "guerrier invincible juste après le coup")
	_check(player.state == Player.State.HURT, "guerrier repoussé (état HURT)")
	_check(room.get_node("HUD/HealthLabel").text == "PV : 19 / 20", "HUD mis à jour : PV : 19 / 20")
	await _frames(8)
	_check(player.health.current_health == 19, "pas de deuxième coup pendant l'invincibilité")

	# Attaque : 3 coups pour tuer le slime.
	for hit in 3:
		while player.state != Player.State.NORMAL:
			await get_tree().physics_frame
		s1.state = Slime.State.IDLE
		s1.global_position = player.global_position + Vector2(14, 0)
		player.health.set_invulnerable(1.0)
		player.facing = Vector2.RIGHT
		await _press("attack")
		await _frames(16)
		_check(s1.health.current_health == 2 - hit, "attaque %d : slime à %d PV" % [hit + 1, 2 - hit])
		await _frames(12)
	await _frames(80)
	_check(not is_instance_valid(s1), "slime mort puis supprimé")
	_check(get_tree().get_nodes_in_group("enemies").size() == 2, "il reste 2 slimes")

	# Attaque dans le vide dans la mauvaise direction : pas de dégât.
	while player.state != Player.State.NORMAL:
		await get_tree().physics_frame
	s2.state = Slime.State.IDLE
	s2.global_position = player.global_position + Vector2(-14, 0)
	player.facing = Vector2.RIGHT
	player.health.set_invulnerable(1.0)
	await _press("attack")
	await _frames(16)
	_check(s2.health.current_health == 3, "attaque vers la droite ne touche pas un slime à gauche")
	s2.global_position = Vector2(400, 300)
	await _frames(40)

	# Esquive : invincible pendant la roulade.
	while player.state != Player.State.NORMAL or player.health.is_invulnerable():
		await get_tree().physics_frame
	await _press("dodge")
	_check(player.state == Player.State.DODGE, "esquive déclenchée")
	_check(player.health.is_invulnerable(), "invincible pendant l'esquive")
	s3.state = Slime.State.CHASE
	s3.global_position = player.global_position
	var hp := player.health.current_health
	await _frames(5)
	_check(player.health.current_health >= hp, "aucun dégât pendant l'esquive")
	s3.global_position = Vector2(-400, 300)
	s3.state = Slime.State.IDLE
	await _frames(40)

	# Mort du guerrier puis rechargement de la salle.
	while player.health.is_invulnerable():
		await get_tree().physics_frame
	player.health.current_health = 1
	s3.global_position = player.global_position
	s3.state = Slime.State.CHASE
	for i in 60:
		await get_tree().physics_frame
		if player.state == Player.State.DEAD:
			break
	_check(player.state == Player.State.DEAD, "guerrier mort à 0 PV")
	var old_room := get_tree().current_scene
	await _frames(100)
	_check(get_tree().current_scene != old_room and get_tree().current_scene != null, "salle rechargée après la mort")
	if get_tree().current_scene:
		var new_player: Player = get_tree().current_scene.get_node("Player")
		_check(new_player.health.current_health == 20, "nouveau guerrier à 20 PV")

	print("TOTAL FAILURES: %d" % failures)
	get_tree().quit(1 if failures > 0 else 0)
