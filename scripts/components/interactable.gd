class_name Interactable
extends Node2D
## Quelque chose avec quoi le héros peut interagir (touche E / bouton X) :
## dormir, déposer des matériaux, améliorer la guilde...
## Le plus proche à portée est mis en avant (voir l'autoload Interaction).

signal interacted

## Texte affiché à l'écran quand le héros est assez près (« Dormir », « Déposer »...).
@export var prompt: String = "Interagir"
## Portée, en tiles (depuis les pieds du héros).
@export var radius_tiles: float = 1.6
@export var enabled: bool = true


func _ready() -> void:
	add_to_group("interactables")


func in_range(feet: Vector2) -> bool:
	return enabled and is_visible_in_tree() and feet.distance_to(global_position) <= radius_tiles * Game.TILE_SIZE
