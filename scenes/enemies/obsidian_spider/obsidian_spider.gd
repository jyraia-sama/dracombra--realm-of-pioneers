class_name ObsidianSpider
extends CharacterBody2D
## Araignée d'obsidienne : rapide et fragile. Elle fonce sur le guerrier,
## se ramasse un court instant (le signal pour esquiver), puis bondit.
## Après le bond, elle reste un moment vulnérable.

enum State { IDLE, CHASE, WINDUP, LEAP, RECOVER, HURT, DEAD }

@export_group("Déplacement")
## Vitesse de course, en tiles par seconde.
@export var move_speed_tiles: float = 3.6
## Distance à laquelle l'araignée repère le guerrier, en tiles.
@export var detection_radius_tiles: float = 7.0
## Au-delà de cette distance, elle abandonne la poursuite, en tiles.
@export var lose_interest_radius_tiles: float = 10.0

@export_group("Bond")
## Elle bondit quand le guerrier est plus près que cette distance, en tiles.
@export var leap_range_tiles: float = 3.0
## Temps pendant lequel elle se ramasse avant de bondir (fenêtre d'esquive), en secondes.
@export var windup_time: float = 0.45
## Distance parcourue par le bond, en tiles.
@export var leap_distance_tiles: float = 3.5
## Durée du bond, en secondes.
@export var leap_time: float = 0.28
## Temps où elle reste immobile après le bond, en secondes.
@export var recover_time: float = 0.6
## Temps minimum entre deux bonds, en secondes.
@export var leap_cooldown: float = 1.4

@export_group("Combat")
## Dégâts au contact.
@export var contact_damage: int = 1
## Dégâts du bond.
@export var leap_damage: int = 2
## Recul infligé au guerrier, en tiles.
@export var contact_knockback_tiles: float = 1.5
## Durée pendant laquelle l'araignée est repoussée après un coup, en secondes.
@export var hurt_duration: float = 0.2

## Planche : [ligne, nombre d'images, durée d'une image].
const ANIMS := {
	&"idle": [0, 4, 0.15],
	&"run": [1, 6, 0.06],
	&"leap": [2, 5, 0.0],
	&"hurt": [3, 2, 0.08],
	&"death": [4, 4, 0.1],
}
const COLUMNS := 6

var state: State = State.IDLE

var _state_timer: float = 0.0
var _cooldown: float = 0.0
var _leap_direction: Vector2 = Vector2.RIGHT
var _death_time: float = 0.0
var _target: Node2D

@onready var visual: Node2D = $Visual
@onready var sprite: Sprite2D = $Visual/Sprite
@onready var eye_light: PointLight2D = $Visual/EyeLight
@onready var loot: LootDropper = $Loot
@onready var fear: Fear = $Fear
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var health: HealthComponent = $Health
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var hurtbox_shape: CollisionShape2D = $Hurtbox/CollisionShape2D
@onready var contact_hitbox: Hitbox = $ContactHitbox
@onready var contact_hitbox_shape: CollisionShape2D = $ContactHitbox/CollisionShape2D


func _ready() -> void:
	add_to_group("enemies")
	var tile := float(Game.TILE_SIZE)

	collision_shape.shape.size = Vector2(tile * 0.875, tile * 0.5)
	collision_shape.position = Vector2(0.0, -tile * 0.25)

	hurtbox_shape.shape.size = Vector2(tile * 1.25, tile * 0.875)
	hurtbox_shape.position = Vector2(0.0, -tile * 0.45)

	contact_hitbox_shape.shape.size = Vector2(tile * 1.25, tile * 0.75)
	contact_hitbox_shape.position = Vector2(0.0, -tile * 0.4)
	contact_hitbox.damage = contact_damage
	contact_hitbox.knockback_tiles = contact_knockback_tiles
	contact_hitbox.source = self

	hurtbox.hit_received.connect(_on_hit_received)
	health.died.connect(_on_died)
	_cooldown = randf_range(0.3, 1.0)


func _process(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if fear.is_scared and state != State.DEAD:
		sprite.frame = SheetAnimation.frame(ANIMS, &"run", COLUMNS, now, true)
		sprite.flip_h = velocity.x < 0.0
		return
	# La planche regarde vers la droite.
	if state in [State.IDLE, State.CHASE] and is_instance_valid(_target):
		sprite.flip_h = _target.global_position.x < global_position.x
	visual.position = Vector2.ZERO
	match state:
		State.IDLE:
			sprite.frame = SheetAnimation.frame(ANIMS, &"idle", COLUMNS, now, true)
		State.CHASE:
			sprite.frame = SheetAnimation.frame(ANIMS, &"run", COLUMNS, now, true)
		State.WINDUP:
			# Elle se ramasse et tremble : c'est le moment d'esquiver.
			sprite.frame = _leap_frame(0 if _state_timer > windup_time * 0.5 else 1)
			visual.position.x = sin(now * 70.0) * 0.8
		State.LEAP:
			var t := 1.0 - _state_timer / leap_time
			sprite.frame = _leap_frame(2 if t < 0.6 else 3)
			# Petite parabole : elle décolle du sol.
			visual.position.y = -sin(t * PI) * Game.TILE_SIZE * 0.6
		State.RECOVER:
			sprite.frame = _leap_frame(4)
		State.HURT:
			sprite.frame = SheetAnimation.frame(ANIMS, &"hurt", COLUMNS, now, true)
		State.DEAD:
			_death_time += delta
			sprite.frame = SheetAnimation.frame(ANIMS, &"death", COLUMNS, _death_time, false)
	# Ses yeux s'embrasent pendant le bond.
	var glow := 1.4 if state in [State.WINDUP, State.LEAP] else 0.6
	eye_light.energy = lerpf(eye_light.energy, glow, minf(1.0, delta * 10.0))


func _leap_frame(index: int) -> int:
	return int(ANIMS[&"leap"][0]) * COLUMNS + index


func _physics_process(delta: float) -> void:
	if fear.is_scared and state != State.DEAD:
		contact_hitbox.active = false
		move_and_slide()
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	match state:
		State.IDLE:
			_process_idle()
		State.CHASE:
			_process_chase()
		State.WINDUP:
			velocity = Vector2.ZERO
			_state_timer -= delta
			if _state_timer <= 0.0:
				_start_leap()
		State.LEAP:
			_state_timer -= delta
			if _state_timer <= 0.0:
				_end_leap()
		State.RECOVER:
			velocity = velocity.move_toward(Vector2.ZERO, Game.TILE_SIZE * 40.0 * delta)
			_state_timer -= delta
			if _state_timer <= 0.0:
				state = State.CHASE
		State.HURT:
			_state_timer -= delta
			if _state_timer <= 0.0:
				state = State.CHASE
		State.DEAD:
			velocity = Vector2.ZERO
	move_and_slide()


func _process_idle() -> void:
	velocity = Vector2.ZERO
	_target = get_tree().get_first_node_in_group("player") as Node2D
	if _is_target_within(detection_radius_tiles):
		state = State.CHASE


func _process_chase() -> void:
	if not _is_target_within(lose_interest_radius_tiles):
		state = State.IDLE
		return
	if _cooldown <= 0.0 and _is_target_within(leap_range_tiles):
		state = State.WINDUP
		_state_timer = windup_time
		_leap_direction = global_position.direction_to(_target.global_position)
		sprite.flip_h = _leap_direction.x < 0.0
		return
	var direction := global_position.direction_to(_target.global_position)
	velocity = direction * move_speed_tiles * Game.TILE_SIZE


func _start_leap() -> void:
	state = State.LEAP
	_state_timer = leap_time
	# Elle vise l'endroit où se trouve le guerrier au dernier moment.
	if is_instance_valid(_target):
		_leap_direction = global_position.direction_to(_target.global_position)
	velocity = _leap_direction * leap_distance_tiles * Game.TILE_SIZE / leap_time
	contact_hitbox.damage = leap_damage
	contact_hitbox.active = true


func _end_leap() -> void:
	state = State.RECOVER
	_state_timer = recover_time
	_cooldown = leap_cooldown
	contact_hitbox.damage = contact_damage
	contact_hitbox.active = true


func _is_target_within(radius_tiles: float) -> bool:
	if not is_instance_valid(_target):
		return false
	var radius: float = radius_tiles * Game.TILE_SIZE
	return global_position.distance_squared_to(_target.global_position) <= radius * radius


func _on_hit_received(hitbox: Hitbox) -> void:
	_flash()
	if state == State.DEAD:
		return
	contact_hitbox.damage = contact_damage
	var knockback_speed: float = hitbox.knockback_tiles * Game.TILE_SIZE / hurt_duration
	velocity = hitbox.get_knockback_direction(global_position) * knockback_speed
	_state_timer = hurt_duration
	_cooldown = maxf(_cooldown, 0.5)
	state = State.HURT


func _on_died() -> void:
	state = State.DEAD
	loot.drop(global_position)
	contact_hitbox.active = false
	hurtbox.set_deferred("monitorable", false)
	collision_shape.set_deferred("disabled", true)
	# Elle éclate en morceaux d'obsidienne, puis s'efface.
	var tween := create_tween()
	tween.tween_property(eye_light, "energy", 0.0, 0.4)
	tween.tween_interval(0.3)
	tween.tween_property(visual, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)


func _flash() -> void:
	sprite.self_modulate = Color(1.0, 0.35, 0.35)
	var tween := create_tween()
	tween.tween_property(sprite, "self_modulate", Color.WHITE, 0.2)
