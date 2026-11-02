class_name Skeleton
extends CryptMonster
## Squelette guerrier des cryptes : épée rouillée, coup lourd après une courte préparation.
## À 0 PV, il s'effondre en tas d'os : s'il n'est pas achevé (un coup sur le tas) dans les
## 3 secondes, il se relève avec la moitié de ses PV. La deuxième chute est la bonne.

const RISE_TIME := 3.0

var _risen := false


func _configure() -> void:
	sheet_path = "res://assets/sprites/enemies/crypt/skeleton.png"
	move_speed_tiles = 2.4
	attack_range_tiles = 1.4
	windup_time = 0.5
	attack_damage = 16
	contact_damage = 8


func _ready() -> void:
	super()
	# Ne meurt pas à la première chute : il s'effondre (voir _collapse).
	health.min_health = 1
	health.health_changed.connect(_on_health_changed)


func _on_health_changed(current: int, _maximum: int) -> void:
	if current <= 1 and not _risen and state != State.DOWN and state != State.DEAD:
		_collapse()


func _attack() -> void:
	super()
	attack_hitbox.heavy = true


func _collapse() -> void:
	state = State.DOWN
	attack_hitbox.active = false
	contact_hitbox.active = false
	_play(&"death")
	Emote.show(self, "...", Color(0.85, 0.85, 0.75), 26.0)
	var tag := Time.get_ticks_msec()
	set_meta(&"collapse", tag)
	get_tree().create_timer(RISE_TIME).timeout.connect(func() -> void:
		if is_instance_valid(self) and state == State.DOWN and get_meta(&"collapse", 0) == tag:
			_rise())


## Un coup sur le tas d'os l'achève.
func _on_hit_received(hitbox: Hitbox) -> void:
	if state == State.DOWN:
		health.min_health = 0
		health.clear_invulnerable()
		health.take_damage(9999)
		return
	super(hitbox)


func _rise() -> void:
	_risen = true
	health.min_health = 0
	health.set_health(maxi(1, health.max_health / 2))
	contact_hitbox.active = true
	state = State.CHASE
	_play(&"walk")
	Emote.show(self, "Il se relève !", Color(0.9, 0.95, 0.8), 30.0)
	PixelBurst.spawn(get_parent(), global_position, PixelBurst.DUST, Vector2.ZERO, 2.0)
