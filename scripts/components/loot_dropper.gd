class_name LootDropper
extends Node
## Fait apparaître le butin d'un ennemi à sa mort.

const PICKUP_SCENE := preload("res://scenes/items/pickup.tscn")

## La table de butin : chaque ligne est tirée indépendamment.
@export var entries: Array[LootEntry] = []
## Rayon de dispersion des objets, en tiles.
@export var scatter_tiles: float = 0.75


func drop(at: Vector2) -> void:
	var level := get_tree().current_scene
	if level == null:
		return
	for entry in entries:
		if entry == null or entry.item == null or randf() > entry.chance:
			continue
		for i in randi_range(entry.min_amount, entry.max_amount):
			var pickup: Pickup = PICKUP_SCENE.instantiate()
			pickup.item = entry.item
			var offset := Vector2.from_angle(randf() * TAU) * randf() * scatter_tiles * Game.TILE_SIZE
			pickup.position = at + offset
			level.add_child.call_deferred(pickup)
			pickup.ready.connect(pickup.pop_from.bind(at), CONNECT_ONE_SHOT)
