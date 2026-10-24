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
@onready var body: ColorRect = $Visual/Body
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var health: HealthComponent = $Health
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var hurtbox_shape: CollisionShape2D = $Hurtbox/CollisionShape2D
@onready var contact_hitbox: Hitbox = $ContactHitbox
@onready var contact_hitbox_shape: CollisionShape2D = $ContactHitbox/CollisionShape2D


func _ready() -> void:
	add_to_group("enemies")
	var tile := float(Game.TILE_SIZE)

	# Corps provisoire : 1 tile sur 1 tile, posé sur le sol.
	body.size = Vector2(tile, tile)
	body.position = Vector2(-tile / 2.0, -tile)
	body.color = Color("6cc24a")

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


func _physics_process(delta: float) -> void:
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
	contact_hitbox.active = false
	hurtbox.set_deferred("monitorable", false)
	collision_shape.set_deferred("disabled", true)
	# Le slime s'aplatit et disparaît.
	var tween := create_tween().set_parallel()
	tween.tween_property(visual, "scale", Vector2(1.6, 0.3), 0.3)
	tween.tween_property(visual, "modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(queue_free)


func _flash() -> void:
	body.self_modulate = Color(1.0, 0.35, 0.35)
	var tween := create_tween()
	tween.tween_property(body, "self_modulate", Color.WHITE, 0.2)
