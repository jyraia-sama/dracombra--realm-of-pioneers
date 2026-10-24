class_name Slime
extends CharacterBody2D
## Premier ennemi : poursuit le guerrier quand il s'approche
## et le blesse au contact.

enum State { IDLE, CHASE, HURT, DEAD }

@export_group("Déplacement")
## Vitesse de poursuite, en tiles par seconde.
@export var move_speed_tiles: float = 2.5
## Distance à laquelle le slime repère le guerrier, en tiles.
@export var detection_radius_tiles: float = 6.0
## Au-delà de cette distance, le slime abandonne la poursuite, en tiles.
@export var lose_interest_radius_tiles: float = 9.0

@export_group("Combat")
## Dégâts infligés au contact.
@export var contact_damage: int = 1
## Recul infligé au guerrier, en tiles.
@export var contact_knockback_tiles: float = 1.5
## Durée pendant laquelle le slime est repoussé après un coup, en secondes.
@export var hurt_duration: float = 0.2

var state: State = State.IDLE

var _state_timer: float = 0.0
var _target: Node2D

@onready var visual: Node2D = $Visual
@onready var sprite: Sprite2D = $Visual/Sprite
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

	collision_shape.shape.size = Vector2(tile * 0.75, tile * 0.5)
	collision_shape.position = Vector2(0.0, -tile * 0.25)

	hurtbox_shape.shape.size = Vector2(tile * 0.875, tile * 0.875)
	hurtbox_shape.position = Vector2(0.0, -tile * 0.5)

	contact_hitbox_shape.shape.size = Vector2(tile, tile * 0.75)
	contact_hitbox_shape.position = Vector2(0.0, -tile * 0.5)
	contact_hitbox.damage = contact_damage
	contact_hitbox.knockback_tiles = contact_knockback_tiles
	contact_hitbox.source = self

	hurtbox.hit_received.connect(_on_hit_received)
	health.died.connect(_on_died)


## Planche : [ligne, nombre d'images, durée d'une image].
const ANIMS := {
	&"idle": [0, 4, 0.16],
	&"hop": [1, 5, 0.09],
	&"hurt": [2, 2, 0.08],
	&"death": [3, 4, 0.1],
}
const COLUMNS := 5

var _death_time: float = 0.0


func _process(delta: float) -> void:
	if fear.is_scared and state != State.DEAD:
		sprite.frame = SheetAnimation.frame(ANIMS, &"hop", COLUMNS, Time.get_ticks_msec() / 1000.0, true)
		return
	if is_instance_valid(_target) and state != State.DEAD:
		sprite.flip_h = _target.global_position.x < global_position.x
	var now := Time.get_ticks_msec() / 1000.0
	match state:
		State.IDLE:
			sprite.frame = SheetAnimation.frame(ANIMS, &"idle", COLUMNS, now, true)
		State.CHASE:
			sprite.frame = SheetAnimation.frame(ANIMS, &"hop", COLUMNS, now, true)
		State.HURT:
			sprite.frame = SheetAnimation.frame(ANIMS, &"hurt", COLUMNS, now, true)
		State.DEAD:
			_death_time += delta
			sprite.frame = SheetAnimation.frame(ANIMS, &"death", COLUMNS, _death_time, false)


func _physics_process(delta: float) -> void:
	if fear.is_scared and state != State.DEAD:
		# La peur pilote sa vitesse : il ne blesse plus personne.
		contact_hitbox.active = false
		move_and_slide()
		return
	match state:
		State.IDLE:
			_process_idle()
		State.CHASE:
			_process_chase()
		State.HURT:
			_process_hurt(delta)
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
	var direction := global_position.direction_to(_target.global_position)
	velocity = direction * move_speed_tiles * Game.TILE_SIZE


func _process_hurt(delta: float) -> void:
	# La vitesse de recul a été fixée au moment du coup.
	_state_timer -= delta
	if _state_timer <= 0.0:
		state = State.CHASE


func _is_target_within(radius_tiles: float) -> bool:
	if not is_instance_valid(_target):
		return false
	var radius: float = radius_tiles * Game.TILE_SIZE
	return global_position.distance_squared_to(_target.global_position) <= radius * radius


func _on_hit_received(hitbox: Hitbox) -> void:
	_flash()
	if state == State.DEAD:
		return
	var knockback_speed: float = hitbox.knockback_tiles * Game.TILE_SIZE / hurt_duration
	velocity = hitbox.get_knockback_direction(global_position) * knockback_speed
	_state_timer = hurt_duration
	state = State.HURT


func _on_died() -> void:
	state = State.DEAD
	loot.drop(global_position)
	Hero.reward_kill(self)
	contact_hitbox.active = false
	hurtbox.set_deferred("monitorable", false)
	collision_shape.set_deferred("disabled", true)
	# Le slime s'aplatit et disparaît.
	# Il s'écrase en flaque (animation de mort), puis s'efface.
	var tween := create_tween()
	tween.tween_interval(0.6)
	tween.tween_property(visual, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)


func _flash() -> void:
	sprite.self_modulate = Color(1.0, 0.35, 0.35)
	var tween := create_tween()
	tween.tween_property(sprite, "self_modulate", Color.WHITE, 0.2)
