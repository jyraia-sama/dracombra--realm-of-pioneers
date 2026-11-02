class_name Hurtbox
extends Area2D
## Zone qui peut être touchée par une Hitbox.
## Transmet les dégâts au HealthComponent indiqué.

signal hit_received(hitbox: Hitbox)

## Les points de vie qui encaissent les coups reçus par cette zone.
@export var health: HealthComponent
## Facultatif : modifie les dégâts reçus (défense, parade...). Reçoit les dégâts du coup,
## renvoie ceux à encaisser ; 0 = coup paré (pas de dégâts ni de recul).
var damage_filter: Callable
## Dégâts réellement encaissés au dernier coup.
var last_amount: int = 0


func _ready() -> void:
	# Une hurtbox n'a pas besoin de détecter : ce sont les hitbox qui la trouvent.
	monitoring = false


## Appelé par une Hitbox. Renvoie true si le coup a bien été encaissé.
func receive_hit(hitbox: Hitbox) -> bool:
	if health == null or health.is_dead() or health.is_invulnerable():
		return false
	# Les dégâts du coup, augmentés selon le niveau de celui qui frappe (voir Combat).
	var amount := Combat.hit_amount(hitbox)
	if damage_filter.is_valid():
		amount = int(damage_filter.call(amount))
		if amount <= 0:
			return true
	last_amount = amount
	health.take_damage(amount)
	hit_received.emit(hitbox)
	return true
