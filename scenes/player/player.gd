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
@export var attack_duration: float = 0.3
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

## Pendant une cinématique, le joueur ne contrôle plus le guerrier.
var input_locked: bool = false
## Direction de marche imposée pendant une cinématique.
var scripted_direction: Vector2 = Vector2.ZERO
## Le guerrier peut marcher, mais ni frapper ni esquiver (trop blessé, par exemple).
var actions_locked: bool = false
## Multiplicateur de vitesse de marche (moins de 1 quand le guerrier est blessé).
var speed_multiplier: float = 1.0

var _state_timer: float = 0.0
var _shot_cooldown: float = 0.0
var _regen_timer: float = 0.0
var _dodge_cooldown_timer: float = 0.0
var _dodge_velocity: Vector2 = Vector2.ZERO
var _attack_crit := false
var _knock_default := 0.0

## Techniques et sorts (touches R, F, C).
var skills: SkillCaster

@onready var visual: Node2D = $Visual
@onready var sprite: Sprite2D = $Visual/Sprite
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var health: HealthComponent = $Health
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var hurtbox_shape: CollisionShape2D = $Hurtbox/CollisionShape2D
@onready var attack_pivot: Node2D = $AttackPivot
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
	var reach := Vector2(attack_range_tiles * tile, tile * 1.5)
	attack_hitbox_shape.shape.size = reach
	attack_hitbox_shape.position = Vector2(tile * 0.25 + reach.x / 2.0, 0.0)
	attack_hitbox.damage = attack_damage
	attack_hitbox.knockback_tiles = attack_knockback_tiles
	attack_hitbox.source = self
	attack_hitbox.active = false

	_knock_default = attack_knockback_tiles
	attack_hitbox.hit_landed.connect(_on_attack_landed)
	skills = SkillCaster.new()
	skills.name = "Skills"
	add_child(skills)
	hurtbox.damage_filter = _filter_damage

	health.set_max_health(Game.hero_max_health(), true)
	apply_class(true)
	health.invulnerability_duration = hurt_invulnerability
	hurtbox.hit_received.connect(_on_hit_received)
	health.died.connect(_on_died)


func _process(_delta: float) -> void:
	_update_sprite(_delta)
	# Clignotement pendant l'invincibilité qui suit un coup.
	if state == State.DODGE or state == State.DEAD:
		return
	var blink := health.is_invulnerable() and int(Time.get_ticks_msec() / 80.0) % 2 == 0
	visual.modulate.a = 0.35 if blink else 1.0


func _physics_process(delta: float) -> void:
	_dodge_cooldown_timer = maxf(_dodge_cooldown_timer - delta, 0.0)
	_shot_cooldown = maxf(_shot_cooldown - delta, 0.0)
	# Le clerc referme lentement ses blessures.
	var regen: float = Hero.info().get("regen", 0.0)
	if regen > 0.0 and Game.has_flag(&"prologue_done") and state != State.DEAD:
		_regen_timer += delta
		if _regen_timer >= regen:
			_regen_timer = 0.0
			if health.current_health < health.max_health:
				health.heal(1)

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
	var direction := scripted_direction if input_locked else _get_input_direction()
	velocity = direction * walk_speed_tiles * speed_multiplier * Game.TILE_SIZE

	if direction != Vector2.ZERO:
		facing = _snap_to_8_directions(direction)

	if input_locked or actions_locked:
		return
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


func _process_dodge(delta: float) -> void:
	velocity = _dodge_velocity
	_state_timer -= delta
	if _state_timer <= 0.0:
		state = State.NORMAL
		_dodge_cooldown_timer = dodge_cooldown
		visual.modulate = Color.WHITE


## Applique la classe du héros : PV max, dégâts, teinte provisoire du sprite.
func apply_class(refill: bool = false) -> void:
	var info: Dictionary = Hero.info()
	health.set_max_health(Hero.max_hp(), refill)
	attack_hitbox.damage = Hero.damage() if Game.has_flag(&"prologue_done") else attack_damage
	# Chaque classe a sa planche ; en attendant les leurs, mage et clerc gardent celle
	# du guerrier avec une teinte.
	var done := Game.has_flag(&"prologue_done")
	var sheet: String = info.get("sheet", "res://assets/sprites/hero/warrior.png") if done else "res://assets/sprites/hero/warrior.png"
	sprite.texture = load(sheet)
	sprite.modulate = info["tint"] if done else Color.WHITE


func _start_attack() -> void:
	start_attack()


## Une attaque de l'arme. mult : multiplicateur de dégâts (techniques) ; knock : recul en
## tiles (-1 = celui de l'arme).
func start_attack(mult: float = 1.0, knock: float = -1.0) -> void:
	var done := Game.has_flag(&"prologue_done")
	var kind: String = Hero.info()["attack"] if done else "melee"
	_state_timer = attack_duration
	state = State.ATTACK
	_attack_crit = done and Hero.roll_crit()
	var dmg := Hero.hit_damage(mult, _attack_crit) if done else attack_damage
	if kind == "melee":
		attack_hitbox.damage = dmg
		attack_hitbox.knockback_tiles = knock if knock >= 0.0 else _knock_default
		attack_pivot.rotation = facing.angle()
		attack_hitbox.active = true
		_play_lunge()
		return
	if _shot_cooldown > 0.0 and mult <= 1.0:
		state = State.NORMAL
		return
	_shot_cooldown = float(Hero.info()["cooldown"])
	var from := global_position + Vector2(0, -Game.TILE_SIZE) + facing * 6.0
	var shot := HeroProjectile.create(StringName(kind), from, facing, dmg, self)
	if _attack_crit:
		shot.hit_landed.connect(func(h: Hurtbox) -> void: _show_crit(h), CONNECT_ONE_SHOT)
	get_parent().add_child(shot)


func _on_attack_landed(h: Hurtbox) -> void:
	if _attack_crit:
		_show_crit(h)


func _show_crit(h: Hurtbox) -> void:
	var target := h.get_parent() as Node2D
	if target and is_instance_valid(target):
		Emote.show(target, "Critique !", Color(1.0, 0.6, 0.3), 26.0)


## Pose de lancement d'un sort ou d'une technique : le héros s'arrête un instant.
func play_cast(duration: float) -> void:
	if state == State.DEAD:
		return
	_state_timer = duration
	state = State.ATTACK
	attack_hitbox.active = false


## Ruée vers l'avant (Charge du guerrier) : invincible pendant la course.
func dash(distance_tiles: float, duration: float) -> void:
	_dodge_velocity = facing.normalized() * distance_tiles * Game.TILE_SIZE / duration
	_state_timer = duration
	state = State.DODGE
	health.set_invulnerable(duration + 0.1)


## Saut instantané (Clignement, Tir de repli) ; négatif = en arrière. S'arrête aux murs.
func blink(distance_tiles: float) -> void:
	var dir := facing.normalized() * signf(distance_tiles)
	var total := absf(distance_tiles) * Game.TILE_SIZE
	var step := 4.0
	var moved := 0.0
	while moved + step <= total:
		if test_move(global_transform, dir * step):
			break
		global_position += dir * step
		moved += step
	health.set_invulnerable(0.25)


## Défense, parade et effets protecteurs, appliqués à chaque coup reçu.
func _filter_damage(amount: int) -> int:
	if not Game.has_flag(&"prologue_done"):
		return amount
	if randf() * 100.0 < Hero.parry_chance():
		Emote.show(self, "Paré !", Color(0.8, 0.9, 1.0), 34.0)
		health.set_invulnerable(0.4)
		return 0
	var guard := Hero.buff(&"guard", 1.0)
	if guard <= 0.0:
		health.set_invulnerable(0.3)
		return 0
	var reduced := int(round(amount * guard)) - Hero.defense()
	return maxi(reduced, 1)


func _process_attack(delta: float) -> void:
	velocity = Vector2.ZERO
	_state_timer -= delta
	if _state_timer <= 0.0:
		_end_attack()
		state = State.NORMAL


func _end_attack() -> void:
	attack_hitbox.active = false
	visual.position = Vector2.ZERO
	visual.scale = Vector2.ONE


## Le coup d'épée : une petite fente vers l'avant (l'animation fait le reste).
func _play_lunge() -> void:
	var step := attack_duration / 3.0
	var tween := create_tween()
	tween.tween_property(visual, "position", facing * 3.0, step).set_ease(Tween.EASE_OUT)
	tween.tween_interval(step)
	tween.tween_property(visual, "position", Vector2.ZERO, step)


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
	# Après le prologue, le héros se réveille au camp, à Dracombra.
	if Game.has_flag(&"prologue_done"):
		Game.next_spawn = &"camp"
		Transition.change_scene("res://scenes/levels/dracombra/dracombra.tscn")
		return
	get_tree().reload_current_scene()


func _flash() -> void:
	sprite.self_modulate = Color(1.0, 0.35, 0.35)
	var tween := create_tween()
	tween.tween_property(sprite, "self_modulate", Color.WHITE, 0.2)


## Planche warrior.png : 6 colonnes, 3 lignes par animation (face, dos, profil).
## [première ligne, nombre d'images, durée d'une image (0 = calée sur la durée de l'action)]
const ANIMS := {
	&"idle": [0, 4, 0.22],
	&"walk": [3, 6, 0.1],
	&"roll": [6, 6, 0.0],
	&"attack": [9, 5, 0.0],
	&"hurt": [12, 2, 0.08],
	&"death": [15, 4, 0.15],
}
const COLUMNS := 6
const DIR_DOWN := 0
const DIR_UP := 1
const DIR_SIDE := 2

var _anim_time: float = 0.0
var _anim_state: State = State.NORMAL


func _update_sprite(delta: float) -> void:
	if state != _anim_state:
		_anim_state = state
		_anim_time = 0.0
	_anim_time += delta
	# Profil dès qu'il y a une part de mouvement horizontal, sinon face ou dos.
	var dir := DIR_SIDE
	if absf(facing.x) < 0.1:
		dir = DIR_UP if facing.y < 0.0 else DIR_DOWN
	sprite.flip_h = dir == DIR_SIDE and facing.x < 0.0

	var anim := &"idle"
	var index := 0
	match state:
		State.NORMAL:
			if velocity.length() > 1.0:
				anim = &"walk"
				index = _looped(anim, Time.get_ticks_msec() / 1000.0 * speed_multiplier)
			else:
				index = _looped(anim, Time.get_ticks_msec() / 1000.0)
		State.DODGE:
			anim = &"roll"
			index = _progress(anim, _anim_time / dodge_duration)
		State.ATTACK:
			anim = &"attack"
			index = _progress(anim, _anim_time / attack_duration)
		State.HURT:
			anim = &"hurt"
			index = _progress(anim, _anim_time / maxf(hurt_duration, 0.01))
		State.DEAD:
			anim = &"death"
			index = mini(int(_anim_time / ANIMS[anim][2]), ANIMS[anim][1] - 1)
	var first_row: int = ANIMS[anim][0]
	sprite.frame = (first_row + dir) * COLUMNS + index



func _looped(anim: StringName, elapsed: float) -> int:
	var count: int = ANIMS[anim][1]
	var frame_time: float = ANIMS[anim][2]
	return int(elapsed / frame_time) % count


## Image d'une animation calée sur l'avancement d'une action (0 = début, 1 = fin).
func _progress(anim: StringName, ratio: float) -> int:
	var count: int = ANIMS[anim][1]
	return clampi(int(ratio * count), 0, count - 1)


## Fait regarder le guerrier dans une direction (cinématiques).
func face(direction: Vector2) -> void:
	facing = _snap_to_8_directions(direction)


## Déclenche une attaque, même quand les commandes sont bloquées (cinématiques).
func perform_attack() -> void:
	if state == State.NORMAL:
		_start_attack()


func _get_input_direction() -> Vector2:
	# Gère clavier et manette, et ralentit les diagonales
	# pour qu'elles ne soient pas plus rapides que les lignes droites.
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


func _snap_to_8_directions(direction: Vector2) -> Vector2:
	var angle := snappedf(direction.angle(), PI / 4.0)
	return Vector2.RIGHT.rotated(angle)
