class_name HealthComponent
extends Node
## Points de vie réutilisables : guerrier, membres de la guilde, monstres...
## Gère aussi une courte invincibilité après un coup.

signal health_changed(current: int, maximum: int)
signal damaged(amount: int)
signal died

## Points de vie maximum.
@export var max_health: int = 3
## Durée d'invincibilité après avoir reçu un coup, en secondes.
@export var invulnerability_duration: float = 0.0

var current_health: int = 0

var _invulnerability_timer: float = 0.0


func _ready() -> void:
	current_health = max_health


func _physics_process(delta: float) -> void:
	if _invulnerability_timer > 0.0:
		_invulnerability_timer = maxf(_invulnerability_timer - delta, 0.0)


func is_dead() -> bool:
	return current_health <= 0


func is_invulnerable() -> bool:
	return _invulnerability_timer > 0.0


## Rend invincible pendant au moins `duration` secondes (esquive, par exemple).
func set_invulnerable(duration: float) -> void:
	_invulnerability_timer = maxf(_invulnerability_timer, duration)


func take_damage(amount: int) -> void:
	if is_dead() or is_invulnerable():
		return
	current_health = maxi(current_health - amount, 0)
	_invulnerability_timer = invulnerability_duration
	damaged.emit(amount)
	health_changed.emit(current_health, max_health)
	if current_health == 0:
		died.emit()


func heal(amount: int) -> void:
	if is_dead():
		return
	current_health = mini(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)
