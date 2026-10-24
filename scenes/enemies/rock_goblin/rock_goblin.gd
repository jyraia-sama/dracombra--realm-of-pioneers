class_name RockGoblin
extends CharacterBody2D
## Gobelin des roches : garde ses distances et lance des pierres.
## Si le guerrier s'approche trop, il fonce sur lui.

enum State { IDLE, POSITION, AIM, CHARGE_WINDUP, CHARGE, RECOVER, HURT, DEAD }

const ROCK_SCENE := preload("res://scenes/enemies/rock_goblin/thrown_rock.tscn")

@export_group("Déplacement")
## Vitesse de déplacement, en tiles par seconde.
@export var move_speed_tiles: float = 2.8
## Distance à laquelle il repère le guerrier, en tiles.
@export var detection_radius_tiles: float = 7.0
## Au-delà de cette distance, il abandonne, en tiles.
@export var lose_interest_radius_tiles: float = 10.0
## Distance qu'il essaie de garder avec le guerrier, en tiles.
@export var preferred_distance_tiles: float = 4.0

@export_group("Lancer de pierre")
## Temps pendant lequel il lève sa pierre avant de lancer, en secondes.
@export var aim_duration: float = 0.6
## Temps minimum entre deux lancers, en secondes.
@export var throw_cooldown: float = 1.8
## Vitesse de la pierre, en tiles par seconde.
@export var rock_speed_tiles: float = 7.0
@export var rock_damage: int = 1

@export_group("Charge")
## En dessous de cette distance, il fonce sur le guerrier, en tiles.
@export var charge_trigger_tiles: float = 2.0
## Temps d'annonce avant de foncer, en secondes.
@export var charge_windup: float = 0.35
## Distance parcourue pendant la charge, en tiles.
@export var charge_distance_tiles: float = 3.5
@export var charge_duration: float = 0.3
## Temps pendant lequel il reprend son souffle après une charge, en secondes.
@export var charge_recover: float = 0.7
@export var charge_cooldown: float = 2.5
@export var charge_damage: int = 1

@export_group("Dégâts reçus")
@export var hurt_duration: float = 0.2

var state: State = State.IDLE

var _state_timer: float = 0.0
var _throw_timer: float = 0.8
var _charge_timer: float = 0.0
var _charge_velocity: Vector2 = Vector2.ZERO
var _target: Node2D

@onready var visual: Node2D = $Visual
@onready var sprite: Sprite2D = $Visual/Sprite
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var health: HealthComponent = $Health
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var hurtbox_shape: CollisionShape2D = $Hurtbox/CollisionShape2D
@onready var charge_hitbox: Hitbox = $ChargeHitbox
@onready var charge_hitbox_shape: CollisionShape2D = $ChargeHitbox/CollisionShape2D
@onready var loot: LootDropper = $Loot
@onready var fear: Fear = $Fear


func _ready() -> void:
	add_to_group("enemies")
	var tile := float(Game.TILE_SIZE)
	collision_shape.shape.size = Vector2(tile * 0.625, tile * 0.5)
	collision_shape.position = Vector2(0.0, -tile * 0.25)
	hurtbox_shape.shape.size = Vector2(tile * 0.75, tile * 1.125)
	hurtbox_shape.position = Vector2(0.0, -tile * 0.6)
	charge_hitbox_shape.shape.size = Vector2(tile, tile)
	charge_hitbox_shape.position = Vector2(0.0, -tile * 0.5)
	charge_hitbox.damage = charge_damage
	charge_hitbox.knockback_tiles = 1.5
	charge_hitbox.source = self
	charge_hitbox.active = false
	hurtbox.hit_received.connect(_on_hit_received)
	health.died.connect(_on_died)


## Planche : [ligne, nombre d'images, durée d'une image].
const ANIMS := {
	&"idle": [0, 4, 0.18],
	&"run": [1, 6, 0.09],
	&"throw": [2, 5, 0.12],
	&"charge": [3, 4, 0.1],
	&"death": [4, 4, 0.12],
}
const COLUMNS := 6

var _anim_time: float = 0.0
var _last_state: State = State.IDLE
## Temps restant sur la pose « pierre lâchée » après un lancer.
var _release_time: float = 0.0


func _process(delta: float) -> void:
	if state != _last_state:
		_last_state = state
		_anim_time = 0.0
	_anim_time += delta
	_release_time = maxf(_release_time - delta, 0.0)
	if fear.is_scared and state != State.DEAD:
		sprite.frame = SheetAnimation.frame(ANIMS, &"run", COLUMNS, Time.get_ticks_msec() / 1000.0, true)
		return
	if is_instance_valid(_target) and state != State.CHARGE and state != State.DEAD:
		sprite.flip_h = _target.global_position.x < global_position.x
	# Il tremble pendant qu'il prépare sa charge.
	visual.position.x = randf_range(-1.0, 1.0) if state == State.CHARGE_WINDUP else 0.0
	sprite.frame = _current_frame()


func _current_frame() -> int:
	var throw_row: int = ANIMS[&"throw"][0] * COLUMNS
	var charge_row: int = ANIMS[&"charge"][0] * COLUMNS
	match state:
		State.DEAD:
			return SheetAnimation.frame(ANIMS, &"death", COLUMNS, _anim_time, false)
		State.AIM:
			# Il lève sa pierre en 3 temps pendant la visée.
			return throw_row + mini(int(_anim_time / aim_duration * 3.0), 2)
		State.CHARGE_WINDUP:
			return charge_row
		State.CHARGE:
			return charge_row + 1 + int(_anim_time / 0.08) % 2
		State.RECOVER:
			return charge_row + 3
	if _release_time > 0.0:
		# Bras tendu juste après le lancer, puis il se reprend.
		return throw_row + (3 if _release_time > 0.15 else 4)
	var now := Time.get_ticks_msec() / 1000.0
	if velocity.length() > 1.0:
		return SheetAnimation.frame(ANIMS, &"run", COLUMNS, now, true)
	return SheetAnimation.frame(ANIMS, &"idle", COLUMNS, now, true)


func _physics_process(delta: float) -> void:
	if fear.is_scared and state != State.DEAD:
		# La peur pilote sa vitesse : il ne blesse plus personne.
		charge_hitbox.active = false
		move_and_slide()
		return
	_throw_timer = maxf(_throw_timer - delta, 0.0)
	_charge_timer = maxf(_charge_timer - delta, 0.0)

	match state:
		State.IDLE:
			velocity = Vector2.ZERO
			_target = get_tree().get_first_node_in_group("player") as Node2D
			if _is_target_within(detection_radius_tiles):
				state = State.POSITION
		State.POSITION:
			_process_position()
		State.AIM:
			velocity = Vector2.ZERO
			_tick(delta, _throw)
		State.CHARGE_WINDUP:
			velocity = Vector2.ZERO
			_tick(delta, _start_charge)
		State.CHARGE:
			velocity = _charge_velocity
			_tick(delta, _end_charge)
		State.RECOVER:
			velocity = Vector2.ZERO
			_tick(delta, func() -> void: state = State.POSITION)
		State.HURT:
			_tick(delta, func() -> void: state = State.POSITION)
		State.DEAD:
			velocity = Vector2.ZERO

	move_and_slide()


func _tick(delta: float, on_done: Callable) -> void:
	_state_timer -= delta
	if _state_timer <= 0.0:
		on_done.call()


func _process_position() -> void:
	if not _is_target_within(lose_interest_radius_tiles):
		state = State.IDLE
		return
	var to_target := _target.global_position - global_position
	var distance_tiles := to_target.length() / Game.TILE_SIZE

	if distance_tiles < charge_trigger_tiles and _charge_timer <= 0.0:
		_state_timer = charge_windup
		state = State.CHARGE_WINDUP
		return
	if _throw_timer <= 0.0 and distance_tiles <= detection_radius_tiles:
		_state_timer = aim_duration
		state = State.AIM
		return

	# Garde la bonne distance : avance si trop loin, recule si trop près.
	var direction := to_target.normalized()
	if distance_tiles > preferred_distance_tiles + 0.75:
		velocity = direction * move_speed_tiles * Game.TILE_SIZE
	elif distance_tiles < preferred_distance_tiles - 0.75:
		velocity = -direction * move_speed_tiles * 0.8 * Game.TILE_SIZE
	else:
		velocity = Vector2.ZERO


func _throw() -> void:
	_throw_timer = throw_cooldown
	_release_time = 0.3
	state = State.POSITION
	if not is_instance_valid(_target):
		return
	var hand := global_position + Vector2(0.0, -Game.TILE_SIZE * 0.75)
	var aim_point := _target.global_position + Vector2(0.0, -Game.TILE_SIZE * 0.75)
	var rock: ThrownRock = ROCK_SCENE.instantiate()
	rock.velocity = hand.direction_to(aim_point) * rock_speed_tiles * Game.TILE_SIZE
	rock.damage = rock_damage
	rock.source = self
	rock.position = hand
	get_tree().current_scene.add_child(rock)


func _start_charge() -> void:
	var direction := global_position.direction_to(_target.global_position) \
		if is_instance_valid(_target) else Vector2.RIGHT
	var speed: float = charge_distance_tiles * Game.TILE_SIZE / charge_duration
	_charge_velocity = direction * speed
	charge_hitbox.active = true
	_state_timer = charge_duration
	state = State.CHARGE


func _end_charge() -> void:
	charge_hitbox.active = false
	_charge_timer = charge_cooldown
	_state_timer = charge_recover
	state = State.RECOVER


func _is_target_within(radius_tiles: float) -> bool:
	if not is_instance_valid(_target):
		return false
	var radius: float = radius_tiles * Game.TILE_SIZE
	return global_position.distance_squared_to(_target.global_position) <= radius * radius


func _on_hit_received(hitbox: Hitbox) -> void:
	_flash()
	if state == State.DEAD:
		return
	# Un coup interrompt la visée ou la charge.
	charge_hitbox.active = false
	var knockback_speed: float = hitbox.knockback_tiles * Game.TILE_SIZE / hurt_duration
	velocity = hitbox.get_knockback_direction(global_position) * knockback_speed
	_state_timer = hurt_duration
	state = State.HURT


func _on_died() -> void:
	state = State.DEAD
	loot.drop(global_position)
	Hero.reward_kill(self)
	charge_hitbox.active = false
	hurtbox.set_deferred("monitorable", false)
	collision_shape.set_deferred("disabled", true)
	# Il s'effondre en tas de cailloux (animation de mort), puis s'efface.
	var tween := create_tween()
	tween.tween_interval(0.9)
	tween.tween_property(visual, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)


func _flash() -> void:
	sprite.self_modulate = Color(1.0, 0.35, 0.35)
	var tween := create_tween()
	tween.tween_property(sprite, "self_modulate", Color.WHITE, 0.2)
