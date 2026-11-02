class_name SkillCaster
extends Node
## Lance les techniques et les sorts du héros (touches R, F, C ; gâchettes et R3 à la
## manette). Gère aussi l'endurance ou le mana, les temps de recharge et les effets
## temporaires qui agissent dans la durée (régénération de la bénédiction).

signal cast(id: StringName)

const ACTIONS: Array[StringName] = [&"skill_1", &"skill_2", &"skill_3"]

## Temps de recharge restant par technique, en secondes.
var cooldowns: Dictionary = {}

var _regen_hp := 0.0

@onready var player: Player = get_parent()


func _physics_process(delta: float) -> void:
	for id in cooldowns.keys():
		cooldowns[id] = float(cooldowns[id]) - delta
		if cooldowns[id] <= 0.0:
			cooldowns.erase(id)
	if not Game.has_flag(&"prologue_done") or player.state == Player.State.DEAD:
		return
	Hero.regen_energy(delta)
	var regen := Hero.buff(&"regen", 0.0)
	if regen > 0.0:
		_regen_hp += regen * delta
		if _regen_hp >= 1.0:
			_regen_hp -= 1.0
			if player.health.current_health < player.health.max_health:
				player.health.heal(1)
	if player.input_locked or player.actions_locked or get_tree().paused:
		return
	for i in ACTIONS.size():
		if Input.is_action_just_pressed(ACTIONS[i]):
			use_slot(i)


func use_slot(i: int) -> bool:
	var s := Hero.slots()
	if i >= s.size() or s[i] == &"":
		return false
	return try_cast(s[i])


func cooldown_left(id: StringName) -> float:
	return float(cooldowns.get(id, 0.0))


## Ce qui empêche de lancer la technique, ou "" si c'est possible.
func blocked_reason(id: StringName) -> String:
	var s := SkillBook.get_skill(id)
	if s.is_empty() or not Hero.known_skills().has(id):
		return "inconnue"
	if not Game.has_flag(&"prologue_done"):
		return "prologue"
	if player.state != Player.State.NORMAL:
		return "occupé"
	if cooldown_left(id) > 0.0:
		return "recharge"
	if Hero.energy < float(s["cost"]):
		return Hero.resource_name()
	return ""


func try_cast(id: StringName) -> bool:
	var why := blocked_reason(id)
	if why != "":
		if why == "Mana" or why == "Vigueur":
			Emote.show(player, "%s !" % why, Color(0.6, 0.75, 1.0), 34.0)
		return false
	var s := SkillBook.get_skill(id)
	Hero.use_energy(float(s["cost"]))
	cooldowns[id] = float(s["cooldown"])
	_execute(id, s)
	cast.emit(id)
	return true


func _execute(id: StringName, s: Dictionary) -> void:
	var t := float(Game.TILE_SIZE)
	var body := player.global_position + Vector2(0, -t * 0.5)
	var col: Color = s.get("color", Color.WHITE)
	var level := player.get_parent()
	match String(s["type"]):
		"strike":
			player.start_attack(float(s["mult"]), float(s.get("knock", -1.0)))
		"dash":
			var trail := SkillArea.create(body, t * 0.8, Hero.hit_damage(float(s["mult"]), Hero.roll_crit()), 2.0, col, player)
			trail.follow = player
			trail.ticks = 4
			trail.interval = 0.06
			level.add_child(trail)
			player.dash(float(s["dist"]), 0.22)
		"nova":
			player.play_cast(0.3)
			var nova := SkillArea.create(body, float(s["radius"]) * t, Hero.hit_damage(float(s["mult"]), Hero.roll_crit()),
				float(s.get("knock", 1.5)), col, player)
			level.add_child(nova)
		"area":
			player.play_cast(0.3)
			var at := body + player.facing * float(s.get("dist", 0.0)) * t
			var area := SkillArea.create(at, float(s["radius"]) * t, Hero.hit_damage(float(s["mult"]), Hero.roll_crit()), 1.0, col, player)
			area.delay = float(s.get("delay", 0.0))
			area.slows = bool(s.get("slow", false))
			area.ticks = int(s.get("ticks", 1))
			area.interval = float(s.get("interval", 0.0))
			if s.get("follow", false):
				area.follow = player
			level.add_child(area)
		"projectile":
			player.play_cast(0.3)
			_shoot(s)
		"buff":
			for k in s["buff"]:
				Hero.add_buff(StringName(k), float(s["buff"][k]), float(s["duration"]))
			if s.get("group", false) and s["buff"].has("guard"):
				for c in _near_companions():
					c.add_guard(float(s["buff"]["guard"]), float(s["duration"]))
					SkillFx.ring(level, c.global_position + Vector2(0, -t * 0.5), t, col, 0.5)
			if s.has("heal"):
				player.health.heal(int(ceil(player.health.max_health * float(s["heal"]))))
			player.play_cast(0.3)
			SkillFx.ring(level, body, t * 1.4, col, 0.6)
		"heal":
			var amount := int(ceil(player.health.max_health * float(s["heal"])))
			player.health.heal(amount)
			if s.get("group", false):
				for c in _near_companions():
					var ch: HealthComponent = c.health
					var n := int(ceil(ch.max_health * float(s["heal"])))
					ch.heal(n)
					Emote.show(c, "+%d" % n, Color(0.5, 1.0, 0.5), 34.0)
					SkillFx.ring(level, c.global_position + Vector2(0, -t * 0.5), t, col, 0.5)
			player.play_cast(0.3)
			SkillFx.ring(level, body, t * 1.2, col, 0.6)
			Emote.show(player, "+%d" % amount, Color(0.5, 1.0, 0.5), 34.0)
		"chain":
			player.play_cast(0.3)
			_chain(s, body, col)
		"revive":
			player.play_cast(0.4)
			player.health.heal(int(ceil(player.health.max_health * 0.1)))
			SkillFx.ring(level, body, t * 1.4, col, 0.6)
			var n := 0
			for c in get_tree().get_nodes_in_group("companions"):
				var comp := c as Companion
				if comp and comp.global_position.distance_to(player.global_position) < float(s["range"]) * t \
						and comp.revive(float(s["heal"])):
					n += 1
					SkillFx.ring(level, comp.global_position + Vector2(0, -t * 0.5), t, col, 0.6)
			if n == 0:
				Emote.show(player, "Personne à relever", Color(0.9, 0.9, 0.8), 34.0)
		"slow_field":
			player.play_cast(0.3)
			SkillFx.ring(level, body, float(s["radius"]) * t, col, 0.8)
			for e in get_tree().get_nodes_in_group("enemies"):
				var en := e as Node2D
				if en and en.global_position.distance_to(player.global_position) < float(s["radius"]) * t:
					Combat.slow(en, float(s["factor"]), float(s["duration"]))
		"blink":
			SkillFx.ring(level, body, t, col, 0.35)
			player.blink(float(s["dist"]))
			SkillFx.ring(level, player.global_position + Vector2(0, -t * 0.5), t, col, 0.35)
			var then: StringName = s.get("then", &"")
			if then != &"":
				# La technique qui suit est offerte (ni coût ni recharge).
				_execute(then, SkillBook.get_skill(then))


## Chaîne d'éclairs : frappe l'ennemi le plus proche, puis saute vers le plus proche suivant.
func _chain(s: Dictionary, from: Vector2, col: Color) -> void:
	var level := player.get_parent()
	var hb := Hitbox.new()
	hb.source = player
	hb.knockback_tiles = 0.6
	hb.active = false
	level.add_child(hb)
	var hit: Array[Node2D] = []
	var at := from
	for i in int(s["jumps"]) + 1:
		var best: Node2D = null
		var best_d := float(s["range"]) * Game.TILE_SIZE
		for e in get_tree().get_nodes_in_group("enemies"):
			var en := e as Node2D
			if en == null or hit.has(en):
				continue
			var h := en.get_node_or_null("Health") as HealthComponent
			if h == null or h.is_dead():
				continue
			var d := en.global_position.distance_to(at)
			if d < best_d:
				best_d = d
				best = en
		if best == null:
			break
		hit.append(best)
		var target := best.global_position + Vector2(0, -10)
		SkillFx.bolt(level, at, target, col)
		var hurt := best.get_node_or_null("Hurtbox") as Hurtbox
		if hurt:
			best.get_node("Health").clear_invulnerable()
			hb.global_position = target
			hb.damage = Hero.hit_damage(float(s["mult"]), Hero.roll_crit())
			hurt.receive_hit(hb)
		at = target
	hb.queue_free()


## Compagnons debout à moins de 6 cases du héros (techniques de groupe).
func _near_companions() -> Array[Companion]:
	var out: Array[Companion] = []
	for c in get_tree().get_nodes_in_group("companions"):
		var comp := c as Companion
		if comp and comp.can_be_targeted() and comp.global_position.distance_to(player.global_position) < Game.TILE_SIZE * 6.0:
			out.append(comp)
	return out


func _shoot(s: Dictionary) -> void:
	var count := int(s.get("count", 1))
	var spread := deg_to_rad(float(s.get("spread", 0.0)))
	var interval := float(s.get("interval", 0.0))
	var facing := player.facing
	for i in count:
		if interval > 0.0 and i > 0:
			await get_tree().create_timer(interval).timeout
			if not is_instance_valid(player) or player.state == Player.State.DEAD:
				return
		var offset := 0.0
		if count > 1:
			offset = lerpf(-spread, spread, float(i) / float(count - 1)) if interval <= 0.0 else randf_range(-spread, spread)
		var dir := facing.rotated(offset)
		var from := player.global_position + Vector2(0, -Game.TILE_SIZE) + dir * 6.0
		var shot := HeroProjectile.create(StringName(s.get("kind", &"bolt")), from, dir,
			Hero.hit_damage(float(s["mult"]), bool(s.get("crit", false)) or Hero.roll_crit()), player)
		shot.pierce = bool(s.get("pierce", false))
		var sc := float(s.get("scale", 1.0))
		shot.scale = Vector2(sc, sc)
		if s.has("explode"):
			shot.explode_radius = float(s["explode"]) * Game.TILE_SIZE
			shot.explode_color = s.get("color", Color(1.0, 0.55, 0.2))
		player.get_parent().add_child(shot)
