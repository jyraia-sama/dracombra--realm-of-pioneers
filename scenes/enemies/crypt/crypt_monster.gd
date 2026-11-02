class_name CryptMonster
extends CharacterBody2D
## Base des monstres des cryptes (zone 2 des Abysses). Tout est construit par le code dans
## _init (pas de .tscn) : le niveau peut régler le niveau du monstre (Combat.set_level) avant
## de l'ajouter à la scène. Planches PROVISOIRES : tools/placeholder/cryptes.py.
##
## Comportement de base : repère une cible (héros ou compagnon, Combat.pick_target), la
## poursuit, frappe quand elle est à portée (préparation visible, puis coup), recule quand
## on le touche. Les sous-classes changent l'attaque (_attack) et les déplacements.

enum State { IDLE, CHASE, WINDUP, ACT, RECOVER, HURT, DEAD, DOWN }

## Planche : chemin, taille d'une case (px HD), colonnes, animations {nom: [ligne, images, durée]}.
var sheet_path := ""
var cell := 64
var columns := 4
var anims := {&"idle": [0, 4, 0.2], &"walk": [1, 4, 0.12], &"attack": [2, 4, 0.1], &"death": [3, 4, 0.12]}

var move_speed_tiles := 2.6
var detection_radius_tiles := 14.0
var lose_interest_radius_tiles := 20.0
## Portée de l'attaque, en cases.
var attack_range_tiles := 1.3
var windup_time := 0.45
var act_time := 0.25
var recover_time := 0.6
var attack_cooldown := 1.2
var contact_damage := 8
var attack_damage := 12
var hurt_duration := 0.15
var overhead_height := 30.0
## Taille du corps (cases) pour les collisions.
var body_size := Vector2(0.7, 0.45)
var hurt_size := Vector2(0.9, 1.6)
## Vole à travers les décors et les murs (feu follet).
var flying := false

var state: State = State.IDLE
var _target: Node2D
var _timer := 0.0
var _cooldown := 0.6
var _t := 0.0
var _anim := &"idle"
var _anim_t := 0.0
var _facing := Vector2.DOWN

var visual: Node2D
var sprite: Sprite2D
var health: HealthComponent
var hurtbox: Hurtbox
var contact_hitbox: Hitbox
var attack_hitbox: Hitbox
var collision_shape: CollisionShape2D


func _init() -> void:
	_configure()
	collision_layer = 0 if flying else 4
	collision_mask = 0 if flying else 5
	visual = Node2D.new()
	visual.name = "Visual"
	add_child(visual)
	sprite = Sprite2D.new()
	sprite.name = "Sprite"
	sprite.centered = false
	sprite.scale = Vector2(0.5, 0.5)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visual.add_child(sprite)
	var t := float(Game.TILE_SIZE)
	collision_shape = CollisionShape2D.new()
	collision_shape.name = "CollisionShape2D"
	var r := RectangleShape2D.new()
	r.size = body_size * t
	collision_shape.shape = r
	collision_shape.position = Vector2(0, -r.size.y / 2.0)
	add_child(collision_shape)
	health = HealthComponent.new()
	health.name = "Health"
	health.max_health = int(Combat.MONSTERS.get(_key(), {}).get("hp", 30))
	health.invulnerability_duration = 0.1
	add_child(health)
	hurtbox = Hurtbox.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = 16
	hurtbox.collision_mask = 0
	hurtbox.health = health
	hurtbox.add_child(_box(hurt_size * t, Vector2(0, -hurt_size.y * t / 2.0)))
	add_child(hurtbox)
	contact_hitbox = Hitbox.new()
	contact_hitbox.name = "ContactHitbox"
	contact_hitbox.collision_layer = 0
	contact_hitbox.collision_mask = 8
	contact_hitbox.damage = contact_damage
	contact_hitbox.knockback_tiles = 1.0
	contact_hitbox.add_child(_box(Vector2(0.8, 0.8) * t, Vector2(0, -0.5 * t)))
	add_child(contact_hitbox)
	attack_hitbox = Hitbox.new()
	attack_hitbox.name = "AttackHitbox"
	attack_hitbox.collision_layer = 0
	attack_hitbox.collision_mask = 8
	attack_hitbox.once_per_activation = true
	attack_hitbox.active = false
	attack_hitbox.add_child(_box(Vector2(1.2, 1.2) * t, Vector2.ZERO))
	add_child(attack_hitbox)


## À surcharger : règle les variables ci-dessus (appelé au tout début de _init).
func _configure() -> void:
	pass


func _key() -> StringName:
	var s: Script = get_script()
	return StringName(s.get_global_name()) if s else &""


static func _box(size: Vector2, at: Vector2) -> CollisionShape2D:
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	cs.shape = r
	cs.position = at
	return cs


func _ready() -> void:
	add_to_group("enemies")
	if sheet_path != "":
		sprite.texture = load(sheet_path)
		sprite.hframes = columns
		sprite.vframes = maxi(1, sprite.texture.get_height() / cell)
		sprite.offset = Vector2(-cell / 2.0, -cell + 4)
	contact_hitbox.source = self
	attack_hitbox.source = self
	hurtbox.hit_received.connect(_on_hit_received)
	health.died.connect(_on_died)


func _process(delta: float) -> void:
	_t += delta
	_anim_t += delta
	if is_instance_valid(_target) and state != State.DEAD and state != State.DOWN:
		sprite.flip_h = _target.global_position.x < global_position.x
	_animate()


func _play(anim: StringName) -> void:
	if _anim != anim:
		_anim = anim
		_anim_t = 0.0


func _animate() -> void:
	if not anims.has(_anim) or sprite.texture == null:
		return
	var a: Array = anims[_anim]
	var n := int(a[1])
	var i := int(_anim_t / float(a[2]))
	var loop := _anim == &"idle" or _anim == &"walk"
	i = i % n if loop else mini(i, n - 1)
	sprite.frame = int(a[0]) * columns + i


func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	match state:
		State.IDLE:
			velocity = Vector2.ZERO
			_play(&"idle")
			_target = Combat.pick_target(self, _target)
			if _within(detection_radius_tiles):
				state = State.CHASE
		State.CHASE:
			_target = Combat.pick_target(self, _target)
			if not _within(lose_interest_radius_tiles):
				state = State.IDLE
			elif _cooldown <= 0.0 and _within(attack_range_tiles) and _can_attack():
				_start_windup()
			else:
				_chase(delta)
		State.WINDUP:
			velocity = Vector2.ZERO
			_timer -= delta
			if _timer <= 0.0:
				state = State.ACT
				_timer = act_time
				_attack()
		State.ACT:
			_timer -= delta
			_acting(delta)
			if _timer <= 0.0:
				attack_hitbox.active = false
				attack_hitbox.heavy = false
				state = State.RECOVER
				_timer = recover_time
				velocity = Vector2.ZERO
		State.RECOVER:
			velocity = velocity.move_toward(Vector2.ZERO, 400.0 * delta)
			_timer -= delta
			if _timer <= 0.0:
				_cooldown = attack_cooldown
				state = State.CHASE
		State.HURT:
			_timer -= delta
			if _timer <= 0.0:
				state = State.CHASE
		State.DEAD, State.DOWN:
			velocity = Vector2.ZERO
	if state == State.CHASE:
		_play(&"walk")
	elif state == State.WINDUP or state == State.ACT:
		_play(&"attack")
	elif state == State.RECOVER:
		_play(&"idle")
	if flying:
		position += velocity * delta
	else:
		move_and_slide()


## Approche par défaut : droit vers la cible.
func _chase(_delta: float) -> void:
	var dir := global_position.direction_to(_target.global_position)
	velocity = dir * move_speed_tiles * Game.TILE_SIZE
	_facing = dir


func _can_attack() -> bool:
	return true


func _start_windup() -> void:
	state = State.WINDUP
	_timer = windup_time
	_facing = global_position.direction_to(_target.global_position)
	Fx.squash(visual, Vector2(1.15, 0.85), windup_time)


## Attaque par défaut : coup de mêlée devant lui.
func _attack() -> void:
	attack_hitbox.position = _facing * Game.TILE_SIZE * 0.9 + Vector2(0, -10)
	attack_hitbox.damage = attack_damage
	attack_hitbox.knockback_tiles = 1.4
	attack_hitbox.active = true


func _acting(_delta: float) -> void:
	pass


func _within(tiles: float) -> bool:
	if not is_instance_valid(_target):
		return false
	var r := tiles * Game.TILE_SIZE
	return global_position.distance_squared_to(_target.global_position) <= r * r


func _on_hit_received(hitbox: Hitbox) -> void:
	_flash()
	if state == State.DEAD or state == State.DOWN:
		return
	# Interrompu seulement s'il n'est pas en train de frapper.
	if state == State.WINDUP or state == State.ACT:
		return
	velocity = hitbox.get_knockback_direction(global_position) * hitbox.knockback_tiles * Game.TILE_SIZE / maxf(hurt_duration, 0.05)
	_timer = hurt_duration
	state = State.HURT


func _on_died() -> void:
	state = State.DEAD
	attack_hitbox.active = false
	contact_hitbox.active = false
	hurtbox.set_deferred("monitorable", false)
	collision_shape.set_deferred("disabled", true)
	Hero.reward_kill(self)
	_play(&"death")
	var tween := create_tween()
	tween.tween_interval(0.6)
	tween.tween_property(visual, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)


func _flash() -> void:
	sprite.self_modulate = Color(1.0, 0.35, 0.35)
	var tween := create_tween()
	tween.tween_property(sprite, "self_modulate", Color.WHITE, 0.2)
