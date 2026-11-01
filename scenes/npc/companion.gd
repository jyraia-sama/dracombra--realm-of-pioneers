class_name Companion
extends CharacterBody2D
## Un compagnon du groupe d'aventure (voir GUILDE.md) : suit le héros et combat seul.
##
## Comportements (réglés dans le registre) :
##   agressif  : attaque l'ennemi le plus proche (jusqu'à 9 cases du héros) ;
##   equilibre : attaque, mais revient près du héros sous 40 % de PV ;
##   soins     : un clerc soigne d'abord (héros ou compagnon sous 70 %), puis attaque ;
##               les autres classes restent près du héros et défendent (ennemis à 4 cases).
## À 0 PV : à terre jusqu'à la fin du combat, puis se relève avec 1 PV et sera blessé au
## retour en ville. S'il était déjà blessé en partant : il meurt (deux étapes, GUILDE.md).

const ARROW_RANGE := 6.0
const MELEE_RANGE := 1.1

enum State { FOLLOW, FIGHT, DOWN, DEAD }

var member_id := 0
var state: State = State.FOLLOW
var health: HealthComponent
var hurtbox: Hurtbox
var _m: Dictionary
var _cls: StringName
var _sprite: Sprite2D
var _visual: Node2D
var _anims: Dictionary
var _dirs: Array = ["bas", "haut", "droite"]
var _facing := Vector2.DOWN
var _t := 0.0
var _cooldown := 0.5
var _heal_cd := 2.0
var _target: Node2D
var _melee: Hitbox
var _swing := 0.0
var _calm := 0.0
var _slot := 0  # 0 à gauche du héros, 1 à droite


static func create(m: Dictionary, slot: int) -> Companion:
	var c := Companion.new()
	c.member_id = int(m["id"])
	c._m = m
	c._slot = slot
	c.name = "Compagnon_%d" % c.member_id
	return c


func _ready() -> void:
	add_to_group("companions")
	_cls = StringName(_m["cls"])
	collision_layer = 0
	collision_mask = 1
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(10, 6)
	cs.shape = r
	cs.position = Vector2(0, -3)
	add_child(cs)
	_visual = Node2D.new()
	_visual.name = "Visual"
	add_child(_visual)
	var base := Roster.sprite_path(_m)
	var sheet := SheetAnimation.load_sheet(base + ".json")
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	SheetAnimation.apply_to(_sprite, load(base + ".png"), sheet)
	_anims = SheetAnimation.anims_from(sheet)
	_dirs = sheet.get("dirs", _dirs)
	_visual.add_child(_sprite)
	# PV et zone de dégâts : les monstres le touchent comme le héros (calque « player_hurtbox »).
	health = HealthComponent.new()
	health.name = "Health"
	health.max_health = Roster.max_hp(_m)
	health.invulnerability_duration = 0.6
	add_child(health)
	health.current_health = int(_m.get("hp", health.max_health)) if int(_m.get("hp", 0)) > 0 else health.max_health
	health.died.connect(_on_down)
	hurtbox = Hurtbox.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = 8
	hurtbox.collision_mask = 0
	hurtbox.health = health
	var hs := CollisionShape2D.new()
	var hr := RectangleShape2D.new()
	hr.size = Vector2(12, 22)
	hs.shape = hr
	hs.position = Vector2(0, -11)
	hurtbox.add_child(hs)
	add_child(hurtbox)
	hurtbox.hit_received.connect(func(_h: Hitbox) -> void: Fx.flash(_sprite, 0.1))
	# Coup de mêlée du guerrier.
	_melee = Hitbox.new()
	_melee.name = "Melee"
	_melee.collision_layer = 0
	_melee.collision_mask = 16
	_melee.once_per_activation = true
	_melee.active = false
	_melee.source = self
	_melee.knockback_tiles = 1.2
	var ms := CollisionShape2D.new()
	var mr := RectangleShape2D.new()
	mr.size = Vector2(18, 20)
	ms.shape = mr
	ms.position = Vector2(12, -10)
	_melee.add_child(ms)
	add_child(_melee)


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


func _physics_process(delta: float) -> void:
	_t += delta
	_cooldown = maxf(0.0, _cooldown - delta)
	_heal_cd = maxf(0.0, _heal_cd - delta)
	if _swing > 0.0:
		_swing -= delta
		if _swing <= 0.0:
			_melee.active = false
	var player := _player()
	if player == null or state == State.DEAD:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	if state == State.DOWN:
		velocity = Vector2.ZERO
		# Se relève quand plus aucun ennemi n'est proche depuis quelques secondes.
		_calm = _calm + delta if _nearest_enemy(player.global_position, 10.0) == null else 0.0
		if _calm > 4.0:
			_get_up()
		move_and_slide()
		_animate()
		return
	# Trop loin (changement d'étage, téléportation) : il rejoint le héros.
	if global_position.distance_to(player.global_position) > Game.TILE_SIZE * 14.0:
		global_position = player.global_position + _offset()
	var stance: String = Roster.by_id(member_id).get("stance", "equilibre")
	if _cls == &"cleric" and _heal_cd <= 0.0 and (stance == "soins" or stance == "equilibre"):
		if _try_heal(0.7 if stance == "soins" else 0.45):
			move_and_slide()
			_animate()
			return
	var reach := 9.0 if stance == "agressif" else (4.0 if stance == "soins" and _cls != &"cleric" else 7.0)
	var low := float(health.current_health) / health.max_health < 0.4
	if stance == "equilibre" and low:
		_target = null
	else:
		_target = _nearest_enemy(player.global_position, reach)
	if _target:
		_fight(delta)
	else:
		_follow(player)
	move_and_slide()
	_animate()


func _offset() -> Vector2:
	return Vector2(-18 if _slot == 0 else 18, 10)


func _follow(player: Player) -> void:
	state = State.FOLLOW
	var goal := player.global_position + _offset()
	var to := goal - global_position
	if to.length() > 6.0:
		var speed := 5.2 if to.length() > Game.TILE_SIZE * 4 else 4.0
		velocity = to.normalized() * Game.TILE_SIZE * speed
		_facing = to.normalized()
	else:
		velocity = Vector2.ZERO


func _fight(_delta: float) -> void:
	state = State.FIGHT
	var to := _target.global_position - global_position
	var dist := to.length() / Game.TILE_SIZE
	_facing = to.normalized()
	var ranged := _cls != &"warrior"
	var want := ARROW_RANGE * 0.7 if ranged else MELEE_RANGE * 0.8
	if dist > want:
		velocity = to.normalized() * Game.TILE_SIZE * 4.0
	elif ranged and dist < 2.0:
		velocity = -to.normalized() * Game.TILE_SIZE * 3.0  # garde ses distances
	else:
		velocity = Vector2.ZERO
	if _cooldown > 0.0:
		return
	if ranged and dist <= ARROW_RANGE:
		var kind: StringName = {&"archer": &"arrow", &"mage": &"bolt", &"cleric": &"holy"}.get(_cls, &"arrow")
		var shot := HeroProjectile.create(kind, global_position + Vector2(0, -10), _facing, Roster.damage(_m), self)
		get_parent().add_child(shot)
		_cooldown = float(Hero.CLASSES[_cls]["cooldown"]) + 0.35
	elif not ranged and dist <= MELEE_RANGE + 0.4:
		_melee.rotation = _facing.angle()
		_melee.damage = Roster.damage(_m)
		_melee.active = true
		_swing = 0.18
		_cooldown = 0.5
		var tween := create_tween()
		tween.tween_property(_visual, "position", _facing * 3.0, 0.08)
		tween.tween_property(_visual, "position", Vector2.ZERO, 0.1)


func _try_heal(threshold: float) -> bool:
	var player := _player()
	var hurt: Array = []
	if player and float(player.health.current_health) / player.health.max_health < threshold:
		hurt.append(player)
	for c in get_tree().get_nodes_in_group("companions"):
		var comp := c as Companion
		if comp.state != State.DOWN and comp.state != State.DEAD and float(comp.health.current_health) / comp.health.max_health < threshold:
			hurt.append(comp)
	if hurt.is_empty():
		return false
	var who: Node2D = hurt[0]
	var hp: HealthComponent = who.get("health")
	var amount := maxi(2, int(hp.max_health * 0.3))
	hp.heal(amount)
	Emote.show(who, "+%d" % amount, Color(0.6, 1.0, 0.6), 34.0)
	PixelBurst.spawn(who, who.global_position, PixelBurst.PLANT, Vector2.ZERO, 1.5)
	_heal_cd = 5.0
	velocity = Vector2.ZERO
	return true


func _nearest_enemy(around: Vector2, tiles: float) -> Node2D:
	var best: Node2D = null
	var best_d := tiles * Game.TILE_SIZE
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Node2D
		if en == null:
			continue
		var h := en.get_node_or_null("Health") as HealthComponent
		if h and h.is_dead():
			continue
		var d := en.global_position.distance_to(around)
		if d < best_d:
			best_d = d
			best = en
	return best


func _on_down() -> void:
	var m := Roster.by_id(member_id)
	if m.get("state", "") == "blessé":
		# Déjà blessé en partant : la deuxième chute est fatale.
		state = State.DEAD
		m["state"] = "mort"
		Roster.party.erase(member_id)
		Roster.changed.emit()
		Narration.say("%s est tombé pour de bon... Il était déjà blessé." % m["name"], 4.0)
		BugReport.log_event("Mort de %s" % m["name"])
		var tween := create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 1.5)
		tween.tween_callback(queue_free)
		return
	state = State.DOWN
	m["fell"] = true
	_calm = 0.0
	hurtbox.set_deferred("monitorable", false)
	_melee.active = false
	_visual.rotation = PI / 2.0
	_visual.modulate = Color(0.6, 0.6, 0.65)
	Narration.say("%s est à terre !" % m["name"], 2.0)


func _get_up() -> void:
	state = State.FOLLOW
	health.clear_invulnerable()
	health.set_health(1)
	health.current_health = 1
	hurtbox.set_deferred("monitorable", true)
	_visual.rotation = 0.0
	_visual.modulate = Color.WHITE
	Emote.show(self, "Je tiens bon...", Color(1, 0.9, 0.7), 30.0)


func _exit_tree() -> void:
	# Garde ses PV d'un niveau à l'autre.
	var m := Roster.by_id(member_id)
	if not m.is_empty() and health:
		m["hp"] = health.current_health


func _animate() -> void:
	if _anims.is_empty():
		return
	var moving := velocity.length() > 1.0
	var anim := &"walk" if moving else &"idle"
	if _swing > 0.0 and _anims.has(&"attack"):
		anim = &"attack"
	var dir := "droite" if absf(_facing.x) > absf(_facing.y) else ("haut" if _facing.y < 0.0 else "bas")
	var d := maxi(0, _dirs.find(dir))
	_sprite.flip_h = dir == "droite" and _facing.x < 0.0
	var data: Array = _anims[anim]
	var ft: float = data[2] if float(data[2]) > 0.0 else 0.12
	_sprite.frame = (int(data[0]) + d) * _sprite.hframes + int(_t / ft) % int(data[1])


func _draw() -> void:
	if state == State.DEAD:
		return
	# Petite barre de vie au-dessus de la tête.
	var w := 14.0
	var ratio := float(health.current_health) / maxf(1.0, health.max_health)
	draw_rect(Rect2(-w / 2 - 1, -33, w + 2, 3), Color(0.05, 0.05, 0.08, 0.8))
	draw_rect(Rect2(-w / 2, -32, w * ratio, 1), Color(0.4, 0.9, 0.5) if state != State.DOWN else Color(0.7, 0.3, 0.3))


func _process(_delta: float) -> void:
	queue_redraw()
