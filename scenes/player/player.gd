class_name Player
extends CharacterBody2D
## Le guerrier contrôlé par le joueur.
## Toutes les distances sont exprimées en tiles (Game.TILE_SIZE),
## pour que le remaster en 32x32 ne demande aucun changement ici.

enum State { NORMAL, DODGE, ATTACK, HURT, DEAD }

@export_group("Déplacement")
## Vitesse de marche, en tiles par seconde.
@export var walk_speed_tiles: float = 5.0

@export_group("Esquive")
## Distance parcourue pendant une esquive, en tiles.
@export var dodge_distance_tiles: float = 3.0
## Durée de l'esquive, en secondes. Le guerrier est invincible pendant ce temps.
@export var dodge_duration: float = 0.25
## Temps d'attente avant la prochaine esquive, en secondes.
@export var dodge_cooldown: float = 0.4

@export_group("Attaque")
## Durée d'une attaque, en secondes.
@export var attack_duration: float = 0.25
## Portée de l'attaque, en tiles.
@export var attack_range_tiles: float = 1.0
## Dégâts infligés par l'attaque.
@export var attack_damage: int = 1
## Recul infligé aux ennemis touchés, en tiles.
@export var attack_knockback_tiles: float = 1.5

@export_group("Dégâts reçus")
## Durée pendant laquelle le guerrier est repoussé après un coup, en secondes.
@export var hurt_duration: float = 0.15
## Durée d'invincibilité après un coup, en secondes.
@export var hurt_invulnerability: float = 0.8
## Délai avant de recommencer après la mort, en secondes.
@export var respawn_delay: float = 1.2

var state: State = State.NORMAL
## Direction regardée, toujours l'une des 8 directions.
var facing: Vector2 = Vector2.DOWN

var _state_timer: float = 0.0
var _dodge_cooldown_timer: float = 0.0
var _dodge_velocity: Vector2 = Vector2.ZERO

@onready var visual: Node2D = $Visual
@onready var sprite: Sprite2D = $Visual/Sprite
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var health: HealthComponent = $Health
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var hurtbox_shape: CollisionShape2D = $Hurtbox/CollisionShape2D
@onready var attack_pivot: Node2D = $AttackPivot
@onready var attack_fx: ColorRect = $AttackPivot/AttackFx
@onready var attack_hitbox: Hitbox = $AttackPivot/AttackHitbox
@onready var attack_hitbox_shape: CollisionShape2D = $AttackPivot/AttackHitbox/CollisionShape2D


func _ready() -> void:
	add_to_group("player")
	var tile := float(Game.TILE_SIZE)

	# Collision aux pieds seulement, pour passer derrière les objets.
	collision_shape.shape.size = Vector2(tile * 0.75, tile * 0.5)
	collision_shape.position = Vector2(0.0, -tile * 0.25)

	# Zone où le guerrier peut être touché : le corps entier.
	hurtbox_shape.shape.size = Vector2(tile * 0.75, tile * 1.5)
	hurtbox_shape.position = Vector2(0.0, -tile * 0.75)

	# Zone d'attaque : part du centre du corps vers la droite,
	# puis tourne avec AttackPivot vers la direction regardée.
	attack_pivot.position = Vector2(0.0, -tile)
	attack_fx.size = Vector2(attack_range_tiles * tile, tile)
	attack_fx.position = Vector2(tile * 0.25, -tile / 2.0)
	attack_fx.color = Color(1.0, 0.85, 0.3, 0.6)
	attack_fx.visible = false

	# La hitbox d'attaque couvre exactement la zone jaune.
	attack_hitbox_shape.shape.size = attack_fx.size
	attack_hitbox_shape.position = attack_fx.position + attack_fx.size / 2.0
	attack_hitbox.damage = attack_damage
	attack_hitbox.knockback_tiles = attack_knockback_tiles
	attack_hitbox.source = self
	attack_hitbox.active = false

	health.invulnerability_duration = hurt_invulnerability
	hurtbox.hit_received.connect(_on_hit_received)
	health.died.connect(_on_died)


func _process(_delta: float) -> void:
	_update_sprite()
	# Clignotement pendant l'invincibilité qui suit un coup.
	if state == State.DODGE or state == State.DEAD:
		return
	var blink := health.is_invulnerable() and int(Time.get_ticks_msec() / 80.0) % 2 == 0
	visual.modulate.a = 0.35 if blink else 1.0


func _physics_process(delta: float) -> void:
	_dodge_cooldown_timer = maxf(_dodge_cooldown_timer - delta, 0.0)

	match state:
		State.NORMAL:
			_process_normal()
		State.DODGE:
			_process_dodge(delta)
		State.ATTACK:
			_process_attack(delta)
		State.HURT:
			_process_hurt(delta)
		State.DEAD:
			velocity = Vector2.ZERO

	move_and_slide()


func _process_normal() -> void:
	var direction := _get_input_direction()
	velocity = direction * walk_speed_tiles * Game.TILE_SIZE

	if direction != Vector2.ZERO:
		facing = _snap_to_8_directions(direction)

	if Input.is_action_just_pressed("dodge") and _dodge_cooldown_timer <= 0.0:
		_start_dodge(direction)
	elif Input.is_action_just_pressed("attack"):
		_start_attack()


func _start_dodge(direction: Vector2) -> void:
	# Sans direction, on esquive vers l'endroit regardé.
	var dodge_direction := direction if direction != Vector2.ZERO else facing
	var dodge_speed: float = dodge_distance_tiles * Game.TILE_SIZE / dodge_duration
	_dodge_velocity = dodge_direction.normalized() * dodge_speed
	_state_timer = dodge_duration
	state = State.DODGE
	health.set_invulnerable(dodge_duration)
	visual.modulate = Color(1.0, 1.0, 1.0, 0.5)


func _process_dodge(delta: float) -> void:
	velocity = _dodge_velocity
	_state_timer -= delta
	if _state_timer <= 0.0:
		state = State.NORMAL
		_dodge_cooldown_timer = dodge_cooldown
		visual.modulate = Color.WHITE


func _start_attack() -> void:
	attack_pivot.rotation = facing.angle()
	attack_fx.visible = true
	attack_hitbox.active = true
	_state_timer = attack_duration
	state = State.ATTACK


func _process_attack(delta: float) -> void:
	velocity = Vector2.ZERO
	_state_timer -= delta
	if _state_timer <= 0.0:
		_end_attack()
		state = State.NORMAL


func _end_attack() -> void:
	attack_fx.visible = false
	attack_hitbox.active = false


func _process_hurt(delta: float) -> void:
	# La vitesse de recul a été fixée au moment du coup.
	_state_timer -= delta
	if _state_timer <= 0.0:
		state = State.NORMAL


func _on_hit_received(hitbox: Hitbox) -> void:
	_flash()
	if state == State.DEAD or health.is_dead():
		return
	# Un coup interrompt l'action en cours.
	_end_attack()
	visual.modulate = Color.WHITE
	var knockback_speed: float = hitbox.knockback_tiles * Game.TILE_SIZE / hurt_duration
	velocity = hitbox.get_knockback_direction(global_position) * knockback_speed
	_state_timer = hurt_duration
	state = State.HURT


func _on_died() -> void:
	state = State.DEAD
	_end_attack()
	visual.modulate = Color(1.0, 0.3, 0.3)
	# Prototype : on recommence la salle après un court délai.
	get_tree().create_timer(respawn_delay).timeout.connect(_respawn)


func _respawn() -> void:
	get_tree().reload_current_scene()


func _flash() -> void:
	sprite.self_modulate = Color(1.0, 0.35, 0.35)
	var tween := create_tween()
	tween.tween_property(sprite, "self_modulate", Color.WHITE, 0.2)


func _update_sprite() -> void:
	# Le dessin regarde vers la droite : on le retourne quand le guerrier va à gauche.
	if facing.x < -0.1:
		sprite.flip_h = true
	elif facing.x > 0.1:
		sprite.flip_h = false
	# Petit rebond pendant la marche, en attendant de vraies animations.
	var walking := state == State.NORMAL and velocity.length() > 1.0
	var bob_up := walking and int(Time.get_ticks_msec() / 120.0) % 2 == 0
	visual.position.y = -1.0 if bob_up else 0.0


func _get_input_direction() -> Vector2:
	# Gère clavier et manette, et ralentit les diagonales
	# pour qu'elles ne soient pas plus rapides que les lignes droites.
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


func _snap_to_8_directions(direction: Vector2) -> Vector2:
	var angle := snappedf(direction.angle(), PI / 4.0)
	return Vector2.RIGHT.rotated(angle)
