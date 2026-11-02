class_name Wisp
extends CryptMonster
## Feu follet : flotte à travers les décors et les murs, ondule autour de sa cible et fonce
## sur elle. À chaque contact, il vole du mana (mage, clerc) ou de la vigueur (guerrier,
## archer) au lieu de faire de gros dégâts.

const DRAIN := 6.0


func _configure() -> void:
	sheet_path = "res://assets/sprites/enemies/crypt/wisp.png"
	anims = {&"idle": [0, 4, 0.12], &"walk": [0, 4, 0.1], &"attack": [0, 4, 0.06], &"death": [1, 4, 0.1]}
	flying = true
	move_speed_tiles = 3.0
	attack_range_tiles = 3.0
	windup_time = 0.35
	act_time = 0.35
	recover_time = 0.4
	attack_cooldown = 1.4
	attack_damage = 6
	contact_damage = 4
	overhead_height = 34.0
	hurt_size = Vector2(1.0, 1.2)


func _ready() -> void:
	super()
	contact_hitbox.hit_landed.connect(_drain)
	attack_hitbox.hit_landed.connect(_drain)
	var light := PointLight2D.new()
	light.texture = load("res://assets/lights/light_radial.tres")
	light.color = Color(0.5, 1.0, 0.95)
	light.texture_scale = 0.6
	light.energy = 0.8
	light.position = Vector2(0, -16)
	add_child(light)


func _chase(_delta: float) -> void:
	var to := _target.global_position - global_position
	var dir := to.normalized()
	# Ondule en approchant.
	var wave := dir.orthogonal() * sin(_t * 3.0) * 0.8
	velocity = (dir + wave).normalized() * move_speed_tiles * Game.TILE_SIZE
	_facing = dir


func _attack() -> void:
	# Fonce sur la cible : le coup est porté par la zone d'attaque collée à lui.
	velocity = _facing * Game.TILE_SIZE * 9.0
	attack_hitbox.position = Vector2(0, -12)
	attack_hitbox.damage = attack_damage
	attack_hitbox.knockback_tiles = 0.5
	attack_hitbox.active = true


func _drain(h: Hurtbox) -> void:
	var who := h.get_parent()
	if who is Player:
		var lost := minf(Hero.energy, DRAIN)
		if lost > 0.0:
			Hero.energy -= lost
			Hero.energy_changed.emit(Hero.energy, Hero.energy_max())
			Emote.show(who, "−%d %s" % [int(lost), Hero.resource_name().to_lower()], Color(0.6, 1.0, 0.95), 40.0)
	elif who is Companion:
		(who as Companion).mana = maxf(0.0, (who as Companion).mana - DRAIN)
