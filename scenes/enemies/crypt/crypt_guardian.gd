class_name CryptGuardian
extends CryptMonster
## Boss de la zone 2 : le Gardien des cryptes, grand chevalier squelette au bouclier.
##
## - Son bouclier arrête les coups portés de face (presque aucun dégât, « Bloqué ! »).
##   On le blesse **de dos**, ou pendant qu'il récupère après un coup d'épée manqué (2 s).
## - Coup d'épée lourd (préparation bien visible), charge au bouclier quand on est loin.
## - Toutes les 12 s, il relève des squelettes (4 au plus en même temps).
## - Sous la moitié de ses PV, il enrage : plus rapide, invoque plus souvent.

signal spawned(node: Node2D)

const SUMMON_EVERY := 12.0
const MAX_MINIONS := 4
## Angle (degrés) entre son regard et le coup en dessous duquel le bouclier arrête le coup.
const SHIELD_ARC := 70.0

var _summon_t := 6.0
## false : n'invoque pas de squelettes (chevalier spectral de la quête de la Lame-sort).
var can_summon := true
## Teinte de base (chevalier spectral : bleuté, à moitié transparent).
var base_tint := Color.WHITE
var _enraged := false
var _minions: Array[Node2D] = []
var _charging := false
var _exposed := 0.0
var _hit := false


func _configure() -> void:
	sheet_path = "res://assets/sprites/enemies/crypt/crypt_guardian.png"
	cell = 128
	anims = {&"idle": [0, 4, 0.25], &"walk": [1, 4, 0.16], &"attack": [2, 4, 0.12], &"death": [2, 1, 1.0],
		&"summon": [3, 4, 0.12]}
	move_speed_tiles = 2.0
	attack_range_tiles = 2.4
	windup_time = 0.8
	act_time = 0.3
	recover_time = 0.6
	attack_cooldown = 1.0
	attack_damage = 30
	contact_damage = 12
	overhead_height = 70.0
	body_size = Vector2(1.6, 0.8)
	hurt_size = Vector2(2.0, 3.6)
	detection_radius_tiles = 30.0
	lose_interest_radius_tiles = 40.0


func _ready() -> void:
	super()
	contact_hitbox.get_child(0).shape.size = Vector2(1.6, 1.6) * Game.TILE_SIZE
	(attack_hitbox.get_child(0) as CollisionShape2D).shape.size = Vector2(2.6, 2.2) * Game.TILE_SIZE
	hurtbox.damage_filter = _shield
	attack_hitbox.hit_landed.connect(func(_h: Hurtbox) -> void: _hit = true)
	contact_hitbox.hit_landed.connect(func(_h: Hurtbox) -> void:
		if state == State.ACT:
			_hit = true)
	health.health_changed.connect(func(cur: int, mx: int) -> void:
		if not _enraged and cur <= mx / 2:
			_enraged = true
			move_speed_tiles *= 1.35
			windup_time *= 0.8
			Emote.show(self, "Les morts répondent à mon appel !", Color(0.6, 1.0, 0.9), 80.0)
			_summon(2))


## Le bouclier : un coup qui vient de face est arrêté (10 % des dégâts), sauf quand il est exposé.
func _shield(amount: int) -> int:
	if _exposed > 0.0 or state == State.DEAD:
		return amount
	var hb := hurtbox.current_hitbox
	if hb == null:
		return amount
	var from := hb.global_position - global_position
	if hb.source and is_instance_valid(hb.source) and not (hb is HeroProjectile):
		from = hb.source.global_position - global_position
	if from.length() < 1.0:
		return amount
	var angle := rad_to_deg(absf(_facing.angle_to(from)))
	if angle <= SHIELD_ARC:
		Emote.show(self, "Bloqué !", Color(0.75, 0.8, 0.9), 70.0)
		PixelBurst.spawn(get_parent(), global_position + from.normalized() * 20.0 + Vector2(0, -30), PixelBurst.STONE, Vector2.ZERO, 0.8)
		return maxi(1, amount / 10)
	return amount


func _physics_process(delta: float) -> void:
	_exposed = maxf(0.0, _exposed - delta)
	# Exposé : il clignote en doré.
	visual.modulate = Color(1.35, 1.2, 0.8) if _exposed > 0.0 and int(_t * 8.0) % 2 == 0 else base_tint
	if state != State.DEAD:
		_summon_t -= delta * (1.6 if _enraged else 1.0)
		if _summon_t <= 0.0 and state == State.CHASE:
			_summon_t = SUMMON_EVERY
			_summon(2)
	var was_acting := state == State.ACT
	super(delta)
	if was_acting and state == State.RECOVER:
		# Coup manqué : il reste exposé (le bouclier ne protège plus) pendant 2 s.
		if not _hit:
			_exposed = 2.0
			_timer = maxf(_timer, 2.0)
			Emote.show(self, "Il est ouvert !", Color(1.0, 0.9, 0.5), 76.0)
		_charging = false
		contact_hitbox.heavy = false
		contact_hitbox.damage = contact_damage


func _process(delta: float) -> void:
	super(delta)
	# Le bouclier est tenu du côté où il regarde (la planche le montre à gauche).
	if state != State.DEAD:
		sprite.flip_h = _facing.x > 0.0


func _chase(delta: float) -> void:
	# Il tourne lentement : on peut le contourner pour le frapper de dos.
	var want := global_position.direction_to(_target.global_position)
	_facing = _facing.slerp(want, clampf(delta * (2.2 if _enraged else 1.5), 0.0, 1.0)).normalized()
	velocity = want * move_speed_tiles * Game.TILE_SIZE
	# Loin de sa cible : charge au bouclier.
	if _cooldown <= 0.0 and not _within(5.0) and _within(9.0):
		_charging = true
		_start_windup()


func _attack() -> void:
	if _charging:
		velocity = _facing * Game.TILE_SIZE * 9.0
		contact_hitbox.heavy = true
		contact_hitbox.damage = attack_damage
		return
	attack_hitbox.position = _facing * Game.TILE_SIZE * 1.4 + Vector2(0, -20)
	attack_hitbox.damage = attack_damage
	attack_hitbox.knockback_tiles = 2.0
	attack_hitbox.heavy = true
	attack_hitbox.active = true
	Fx.shake(2.5, 0.2)


func _acting(delta: float) -> void:
	if _charging:
		velocity = velocity.move_toward(Vector2.ZERO, 300.0 * delta)


func _start_windup() -> void:
	super()
	_hit = false
	act_time = 0.6 if _charging else 0.3


func _on_hit_received(hitbox: Hitbox) -> void:
	_flash()
	# Le boss n'est pas repoussé.


func _summon(count: int) -> void:
	if not can_summon:
		return
	_minions = _minions.filter(func(n): return is_instance_valid(n) and not n.get_node("Health").is_dead())
	var free := MAX_MINIONS - _minions.size()
	if free <= 0 or not is_inside_tree():
		return
	_play(&"summon")
	Emote.show(self, "Relevez-vous...", Color(0.6, 1.0, 0.9), 76.0)
	for i in mini(count, free):
		var at := global_position + Vector2.from_angle(randf() * TAU) * randf_range(40.0, 70.0)
		PixelBurst.spawn(get_parent(), at, PixelBurst.SMOKE, Vector2.ZERO, 1.0)
		var s := Skeleton.new()
		Combat.set_level(s, Combat.monster_level(self))
		s.position = at
		get_parent().add_child(s)
		_minions.append(s)
		spawned.emit(s)


func _on_died() -> void:
	contact_hitbox.heavy = false
	for m in _minions:
		if is_instance_valid(m):
			var h := m.get_node_or_null("Health") as HealthComponent
			if h and not h.is_dead():
				h.min_health = 0
				h.take_damage(9999)
	super()
