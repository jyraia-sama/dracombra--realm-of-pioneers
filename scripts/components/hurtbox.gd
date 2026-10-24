class_name Hurtbox
extends Area2D
## Zone qui peut être touchée par une Hitbox.
## Transmet les dégâts au HealthComponent indiqué.

signal hit_received(hitbox: Hitbox)

## Les points de vie qui encaissent les coups reçus par cette zone.
@export var health: HealthComponent


func _ready() -> void:
	# Une hurtbox n'a pas besoin de détecter : ce sont les hitbox qui la trouvent.
	monitoring = false


## Appelé par une Hitbox. Renvoie true si le coup a bien été encaissé.
func receive_hit(hitbox: Hitbox) -> bool:
	if health == null or health.is_dead() or health.is_invulnerable():
		return false
	health.take_damage(hitbox.damage)
	hit_received.emit(hitbox)
	return true
