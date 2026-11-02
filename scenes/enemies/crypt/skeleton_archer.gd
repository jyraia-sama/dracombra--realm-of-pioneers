class_name SkeletonArcher
extends CryptMonster
## Squelette archer : garde ses distances (4 à 7 cases) et tire des flèches d'os.

const ARROW_SPEED := 11.0


func _configure() -> void:
	sheet_path = "res://assets/sprites/enemies/crypt/skeleton_archer.png"
	move_speed_tiles = 2.2
	attack_range_tiles = 7.5
	windup_time = 0.6
	act_time = 0.1
	recover_time = 0.5
	attack_cooldown = 1.6
	attack_damage = 10
	contact_damage = 6


func _chase(_delta: float) -> void:
	var to := _target.global_position - global_position
	var d := to.length() / Game.TILE_SIZE
	var dir := to.normalized()
	_facing = dir
	if d < 3.5:
		velocity = -dir * move_speed_tiles * Game.TILE_SIZE  # recule
	elif d > 6.5:
		velocity = dir * move_speed_tiles * Game.TILE_SIZE
	else:
		# De côté, pour ne pas rester planté.
		velocity = dir.orthogonal() * move_speed_tiles * 0.6 * Game.TILE_SIZE * (1.0 if int(_t) % 4 < 2 else -1.0)


func _can_attack() -> bool:
	return not _within(1.5)


func _attack() -> void:
	if not is_instance_valid(_target):
		return
	var from := global_position + Vector2(0, -14)
	var aim := (_target.global_position + Vector2(0, -10)) - from
	var arrow := EnemyArrow.create(from, aim, attack_damage, self)
	get_parent().add_child(arrow)
