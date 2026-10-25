class_name Boar
extends CharacterBody2D
## Sanglier de la Sylve : il fouille tranquillement le sol. Si on l'attaque, ou si l'on
## s'approche trop, il charge droit devant lui. Donne une peau (pour le cuir) et de la viande.

enum State { WANDER, IDLE, ALERT, CHARGE, HURT, DEAD }

@export var wander_speed_tiles: float = 1.2
@export var charge_speed_tiles: float = 8.0
## Distance à laquelle il se sent menacé, en tiles.
@export var alert_radius_tiles: float = 2.5
@export var charge_damage: int = 2
@export var hurt_duration: float = 0.2

## Planche boar.png (regard vers la droite) : marche, charge, puis touché (2) et mort (2).
const ANIMS := {&"walk": [0, 4, 0.16], &"charge": [1, 4, 0.08], &"hurt": [2, 2, 0.1]}
const COLUMNS := 4

var state: State = State.IDLE
var _timer := 1.0
var _dir := Vector2.RIGHT
var _angry := false
var _time := 0.0

@onready var visual: Node2D = $Visual
@onready var sprite: Sprite2D = $Visual/Sprite
@onready var health: HealthComponent = $Health
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var contact: Hitbox = $ContactHitbox
@onready var loot: LootDropper = $Loot
@onready var collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("enemies")
	var t := float(Game.TILE_SIZE)
	collision.shape.size = Vector2(t * 1.2, t * 0.5)
	collision.position = Vector2(0, -t * 0.25)
	($Hurtbox/CollisionShape2D as CollisionShape2D).shape.size = Vector2(t * 1.6, t * 0.9)
	($Hurtbox/CollisionShape2D as CollisionShape2D).position = Vector2(0, -t * 0.5)
	($ContactHitbox/CollisionShape2D as CollisionShape2D).shape.size = Vector2(t * 1.6, t * 0.8)
	($ContactHitbox/CollisionShape2D as CollisionShape2D).position = Vector2(0, -t * 0.45)
	contact.damage = charge_damage
	contact.knockback_tiles = 2.0
	contact.source = self
	contact.active = false
	hurtbox.hit_received.connect(_on_hit)
	health.died.connect(_on_died)
	_timer = randf_range(0.5, 2.5)


func _process(delta: float) -> void:
	_time += delta
	if absf(velocity.x) > 1.0:
		sprite.flip_h = velocity.x < 0.0
	match state:
		State.CHARGE:
			sprite.frame = SheetAnimation.frame(ANIMS, &"charge", COLUMNS, _time, true)
		State.ALERT:
			sprite.frame = SheetAnimation.frame(ANIMS, &"charge", COLUMNS, 0.0, false)
			visual.position.x = sin(_time * 60.0) * 0.7
		State.DEAD:
			pass
		State.HURT:
			sprite.frame = SheetAnimation.frame(ANIMS, &"hurt", COLUMNS, _time, true)
		_:
			visual.position.x = 0.0
			var moving := velocity.length() > 1.0
			sprite.frame = SheetAnimation.frame(ANIMS, &"walk", COLUMNS, _time if moving else 0.0, true)


func _physics_process(delta: float) -> void:
	var t := float(Game.TILE_SIZE)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	_timer -= delta
	match state:
		State.IDLE, State.WANDER:
			if state == State.WANDER:
				velocity = _dir * wander_speed_tiles * t
			else:
				velocity = Vector2.ZERO
			if _timer <= 0.0:
				_pick_wander()
			if player and global_position.distance_to(player.global_position) < alert_radius_tiles * t:
				_alert(player)
		State.ALERT:
			velocity = Vector2.ZERO
			if _timer <= 0.0:
				state = State.CHARGE
				_timer = 0.55
				contact.active = true
		State.CHARGE:
			velocity = _dir * charge_speed_tiles * t
			if _timer <= 0.0 or get_slide_collision_count() > 0:
				contact.active = false
				state = State.IDLE
				_timer = 1.2
				if _angry and player and global_position.distance_to(player.global_position) < 7.0 * t:
					_alert(player)
		State.HURT:
			if _timer <= 0.0:
				if player:
					_alert(player)
				else:
					state = State.IDLE
		State.DEAD:
			velocity = Vector2.ZERO
	move_and_slide()


func _pick_wander() -> void:
	if state == State.WANDER or randf() < 0.4:
		state = State.IDLE
		_timer = randf_range(1.0, 3.0)
	else:
		state = State.WANDER
		_dir = Vector2.from_angle(randf() * TAU)
		_timer = randf_range(1.0, 2.5)


## Il gratte le sol, puis fonce vers l'endroit où se trouve le héros.
func _alert(target: Node2D) -> void:
	state = State.ALERT
	_timer = 0.45
	_dir = global_position.direction_to(target.global_position)
	sprite.flip_h = _dir.x < 0.0
	Emote.show(self, "!", Color(1.0, 0.45, 0.3), 22.0)


func _on_hit(hitbox: Hitbox) -> void:
	sprite.self_modulate = Color(1.0, 0.4, 0.4)
	create_tween().tween_property(sprite, "self_modulate", Color.WHITE, 0.2)
	if state == State.DEAD:
		return
	_angry = true
	contact.active = false
	velocity = hitbox.get_knockback_direction(global_position) * hitbox.knockback_tiles * Game.TILE_SIZE / hurt_duration
	state = State.HURT
	_timer = hurt_duration


func _on_died() -> void:
	state = State.DEAD
	contact.active = false
	loot.drop(global_position)
	Hero.reward_kill(self)
	hurtbox.set_deferred("monitorable", false)
	collision.set_deferred("disabled", true)
	var tween := create_tween()
	for i in [0, 1, 2, 3]:
		tween.tween_callback(func(): sprite.frame = 2 * COLUMNS + i)
		tween.tween_interval(0.12 if i < 2 else 0.2)
	tween.tween_interval(0.5)
	tween.tween_property(visual, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)
