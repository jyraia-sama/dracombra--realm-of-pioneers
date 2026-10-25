class_name Solakor
extends Node2D
## Solakor, dragon millénaire, gardien des Telles-Ombrages.
## Combat du prologue : impossible à vaincre, il s'agit de survivre.
## Le déroulement (réveil, griffe incandescente, fuite) est piloté par le niveau.

signal hit_by_player

const FALLING_ROCK := preload("res://scenes/props/falling_rock.tscn")

@export_group("Attaques")
## Temps entre deux attaques, en secondes.
@export var attack_interval: float = 1.7
## Distance (en tiles) en dessous de laquelle il utilise ses griffes.
@export var claw_reach_tiles: float = 5.0
## Temps d'annonce d'un coup de griffe, en secondes.
@export var claw_telegraph: float = 0.8
@export var claw_damage: int = 2
## Nombre de rochers par chute.
@export var rocks_per_volley: int = 4
## Rayon de la zone de chute des rochers autour du guerrier, en tiles.
@export var rock_spread_tiles: float = 2.5

## Pendant la fuite, il ne fait plus que tomber des rochers, plus lentement.
var escape_mode: bool = false
var awake: bool = false

var _attacking: bool = false
var _busy: bool = false
var _attack_timer: float = 1.2
var _time: float = 0.0

@onready var visual: Node2D = $Visual
@onready var body_sprite: Sprite2D = $Visual/Body
## Temps écoulé dans le coup de griffe (-1 = pas de coup en cours).
var _claw_time := -1.0

@onready var eye_light: PointLight2D = $Visual/EyeLight
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var claw: Node2D = $Claw
@onready var claw_warning: Polygon2D = $Claw/Warning
@onready var claw_hitbox: Hitbox = $Claw/Hitbox
@onready var claw_shape: CollisionShape2D = $Claw/Hitbox/CollisionShape2D


func _ready() -> void:
	var tile := float(Game.TILE_SIZE)
	# Zone de griffe : 4 tiles de large, 2,5 de haut.
	var half := Vector2(tile * 2.0, tile * 1.25)
	claw_warning.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y)])
	claw_shape.shape.size = half * 2.0
	claw_hitbox.damage = claw_damage
	claw_hitbox.knockback_tiles = 2.5
	claw_hitbox.source = self
	claw_hitbox.active = false
	claw.visible = false
	_set_eyes_open(false)
	eye_light.energy = 0.0
	hurtbox.hit_received.connect(_on_hit_received)


func _process(delta: float) -> void:
	_time += delta
	# Respiration lente quand il dort, plus profonde et rapide une fois réveillé.
	var breath := sin(_time * (3.0 if awake else 1.3)) * (0.02 if awake else 0.012)
	visual.scale = Vector2(1.0 - breath * 0.5, 1.0 + breath)
	# solakor.png (5 colonnes) : respiration 4 images, griffe 5, cabré 4, rugissement 3.
	if _claw_time >= 0.0:
		_claw_time += delta
		body_sprite.frame = 5 + mini(int(_claw_time / (claw_telegraph / 4.0)), 4)
	elif awake:
		body_sprite.frame = int(_time / 0.22) % 4
	else:
		body_sprite.frame = 0


func _physics_process(delta: float) -> void:
	if not _attacking or _busy:
		return
	_attack_timer -= delta
	if _attack_timer > 0.0:
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return
	_attack_timer = attack_interval * (1.4 if escape_mode else 1.0)
	var offset := player.global_position - global_position
	var in_reach := offset.length() <= claw_reach_tiles * Game.TILE_SIZE and offset.y > 0.0
	if in_reach and not escape_mode and randf() < 0.65:
		claw_attack(player.global_position)
	else:
		rock_volley(player.global_position)


func wake() -> void:
	awake = true
	_set_eyes_open(true)
	var tween := create_tween()
	tween.tween_property(eye_light, "energy", 1.6, 0.6)
	Level.shake(self, 4.0, 1.5)


func start_attacks() -> void:
	_attacking = true
	_attack_timer = 1.0


func stop_attacks() -> void:
	_attacking = false


## Coup de griffe : la zone rougeoie, puis frappe. Attendre la fin avec `await`.
## Avec `limit_reach` à false, la griffe frappe où que soit la cible (cinématique).
func claw_attack(target: Vector2, color := Color(1.0, 0.15, 0.1, 0.35), limit_reach := true) -> void:
	_busy = true
	_claw_time = 0.0
	var tile := float(Game.TILE_SIZE)
	var local := to_local(target)
	if limit_reach:
		# La griffe ne frappe que devant le dragon, à portée de patte.
		local.x = clampf(local.x, -tile * 3.0, tile * 3.0)
		local.y = clampf(local.y, tile * 1.5, tile * 4.0)
	claw.position = local
	claw.visible = true
	claw_warning.color = color
	var pulse := create_tween().set_loops(4)
	pulse.tween_property(claw_warning, "color:a", color.a * 1.8, claw_telegraph / 8.0)
	pulse.tween_property(claw_warning, "color:a", color.a, claw_telegraph / 8.0)
	await get_tree().create_timer(claw_telegraph).timeout
	pulse.kill()
	claw_warning.color.a = 0.8
	claw_hitbox.active = true
	Level.shake(self, 4.0, 0.3)
	await get_tree().create_timer(0.15).timeout
	claw_hitbox.active = false
	claw.visible = false
	_claw_time = -1.0
	_busy = false


## Fait tomber des rochers autour d'une position (toujours un pile dessus).
func rock_volley(center: Vector2) -> void:
	var level := get_tree().current_scene
	var tile := float(Game.TILE_SIZE)
	for i in rocks_per_volley:
		var rock: FallingRock = FALLING_ROCK.instantiate()
		var spread := Vector2.ZERO if i == 0 else \
			Vector2.from_angle(randf() * TAU) * randf_range(1.0, rock_spread_tiles) * tile
		rock.position = center + spread
		rock.fall_time = randf_range(0.8, 1.1)
		rock.damage = 1
		level.add_child(rock)


func _set_eyes_open(_open: bool) -> void:
	# Endormi : image fixe ; éveillé : il respire (voir _process).
	body_sprite.frame = 0


func _on_hit_received(hitbox: Hitbox) -> void:
	# Seuls les coups du guerrier comptent : les rochers ne font rien au dragon.
	if not (hitbox.source is Player):
		return
	body_sprite.self_modulate = Color(1.6, 1.4, 1.4)
	create_tween().tween_property(body_sprite, "self_modulate", Color.WHITE, 0.15)
	hit_by_player.emit()
