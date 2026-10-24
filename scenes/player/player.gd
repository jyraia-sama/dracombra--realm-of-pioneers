class_name Player
extends CharacterBody2D
## Le guerrier contrôlé par le joueur.
## Toutes les distances sont exprimées en tiles (Game.TILE_SIZE),
## pour que le remaster en 32x32 ne demande aucun changement ici.

enum State { NORMAL, DODGE, ATTACK }

@export_group("Déplacement")
## Vitesse de marche, en tiles par seconde.
@export var walk_speed_tiles: float = 5.0

@export_group("Esquive")
## Distance parcourue pendant une esquive, en tiles.
@export var dodge_distance_tiles: float = 3.0
## Durée de l'esquive, en secondes.
@export var dodge_duration: float = 0.25
## Temps d'attente avant la prochaine esquive, en secondes.
@export var dodge_cooldown: float = 0.4

@export_group("Attaque")
## Durée d'une attaque, en secondes.
@export var attack_duration: float = 0.25
## Portée de l'attaque, en tiles.
@export var attack_range_tiles: float = 1.0

var state: State = State.NORMAL
## Direction regardée, toujours l'une des 8 directions.
var facing: Vector2 = Vector2.DOWN

var _state_timer: float = 0.0
var _dodge_cooldown_timer: float = 0.0
var _dodge_velocity: Vector2 = Vector2.ZERO

@onready var visual: Node2D = $Visual
@onready var body: ColorRect = $Visual/Body
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var attack_pivot: Node2D = $AttackPivot
@onready var attack_fx: ColorRect = $AttackPivot/AttackFx


func _ready() -> void:
	var tile := float(Game.TILE_SIZE)

	# Corps provisoire : 1 tile de large, 2 de haut, posé sur les pieds.
	body.size = Vector2(tile, tile * 2.0)
	body.position = Vector2(-tile / 2.0, -tile * 2.0)
	body.color = Color("9aa6b8")

	# Collision aux pieds seulement, pour passer derrière les objets.
	collision_shape.shape.size = Vector2(tile * 0.75, tile * 0.5)
	collision_shape.position = Vector2(0.0, -tile * 0.25)

	# Zone d'attaque : part du centre du corps vers la droite,
	# puis tourne avec AttackPivot vers la direction regardée.
	attack_pivot.position = Vector2(0.0, -tile)
	attack_fx.size = Vector2(attack_range_tiles * tile, tile)
	attack_fx.position = Vector2(tile * 0.25, -tile / 2.0)
	attack_fx.color = Color(1.0, 0.85, 0.3, 0.6)
	attack_fx.visible = false


func _physics_process(delta: float) -> void:
	_dodge_cooldown_timer = maxf(_dodge_cooldown_timer - delta, 0.0)

	match state:
		State.NORMAL:
			_process_normal()
		State.DODGE:
			_process_dodge(delta)
		State.ATTACK:
			_process_attack(delta)

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
	var dodge_speed := dodge_distance_tiles * Game.TILE_SIZE / dodge_duration
	_dodge_velocity = dodge_direction.normalized() * dodge_speed
	_state_timer = dodge_duration
	state = State.DODGE
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
	_state_timer = attack_duration
	state = State.ATTACK


func _process_attack(delta: float) -> void:
	velocity = Vector2.ZERO
	_state_timer -= delta
	if _state_timer <= 0.0:
		state = State.NORMAL
		attack_fx.visible = false


func _get_input_direction() -> Vector2:
	# Gère clavier et manette, et ralentit les diagonales
	# pour qu'elles ne soient pas plus rapides que les lignes droites.
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


func _snap_to_8_directions(direction: Vector2) -> Vector2:
	var angle := snappedf(direction.angle(), PI / 4.0)
	return Vector2.RIGHT.rotated(angle)
