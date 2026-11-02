class_name CryptRat
extends CryptMonster
## Rat des cryptes : petit, rapide, arrive en groupe. Mord au contact, bondit un peu.


func _configure() -> void:
	sheet_path = "res://assets/sprites/enemies/crypt/crypt_rat.png"
	anims = {&"idle": [0, 4, 0.12], &"walk": [0, 4, 0.06], &"attack": [0, 4, 0.05], &"death": [1, 4, 0.1]}
	move_speed_tiles = 4.6
	attack_range_tiles = 1.6
	windup_time = 0.2
	act_time = 0.2
	recover_time = 0.35
	attack_cooldown = 0.9
	attack_damage = 7
	contact_damage = 5
	overhead_height = 18.0
	body_size = Vector2(0.6, 0.35)
	hurt_size = Vector2(1.0, 0.8)


func _chase(_delta: float) -> void:
	var dir := global_position.direction_to(_target.global_position)
	# Zigzague un peu.
	var zig := dir.orthogonal() * sin(_t * 9.0 + float(get_instance_id() % 7)) * 0.5
	velocity = (dir + zig).normalized() * move_speed_tiles * Game.TILE_SIZE
	_facing = dir


func _attack() -> void:
	velocity = _facing * Game.TILE_SIZE * 7.0
	attack_hitbox.position = _facing * 6.0 + Vector2(0, -6)
	attack_hitbox.damage = attack_damage
	attack_hitbox.knockback_tiles = 0.6
	attack_hitbox.active = true


func _acting(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
