class_name Hitbox
extends Area2D
## Zone qui inflige des dégâts aux Hurtbox qu'elle chevauche.
## Sert aussi bien à l'attaque du guerrier qu'aux dégâts de contact d'un monstre.

signal hit_landed(hurtbox: Hurtbox)

var _already_hit: Array[Hurtbox] = []

## Dégâts infligés par coup.
@export var damage: int = 1
## Distance de recul infligée à la cible, en tiles.
@export var knockback_tiles: float = 1.0
## Si true, chaque cible n'est touchée qu'une fois par activation
## (une attaque = un coup). Si false, la hitbox frappe en continu,
## et c'est l'invincibilité de la cible qui espace les coups.
@export var once_per_activation: bool = false
## La hitbox ne frappe que lorsqu'elle est active.
@export var active: bool = true:
	set(value):
		active = value
		_already_hit.clear()

## Le personnage qui porte la hitbox. Sert à calculer la direction du recul.
var source: Node2D


func _ready() -> void:
	# Une hitbox détecte, mais n'a pas besoin d'être détectée.
	monitorable = false


func _physics_process(_delta: float) -> void:
	if not active:
		return
	for area in get_overlapping_areas():
		var hurtbox := area as Hurtbox
		if hurtbox == null:
			continue
		if once_per_activation and _already_hit.has(hurtbox):
			continue
		if hurtbox.receive_hit(self):
			_already_hit.append(hurtbox)
			hit_landed.emit(hurtbox)


## Direction dans laquelle repousser une cible située en `target_position`.
func get_knockback_direction(target_position: Vector2) -> Vector2:
	# La source a pu disparaître entre-temps (pierre lancée par un gobelin mort...).
	var origin := source.global_position if is_instance_valid(source) else global_position
	var direction := target_position - origin
	if direction == Vector2.ZERO:
		return Vector2.DOWN
	return direction.normalized()
