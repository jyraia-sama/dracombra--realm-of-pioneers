extends Node
## Inventaire global du joueur : les ressources ramassées (gelée, pierre...).
## Accessible partout avec Inventory.add_item(...), Inventory.get_count(...).

signal item_changed(item: ItemData, count: int)

var _counts: Dictionary[StringName, int] = {}
var _items: Dictionary[StringName, ItemData] = {}
var _db: Dictionary[StringName, ItemData] = {}


func add_item(item: ItemData, amount: int = 1) -> void:
	_items[item.id] = item
	_counts[item.id] = get_count(item.id) + amount
	item_changed.emit(item, _counts[item.id])


## Retire des objets. Renvoie false s'il n'y en a pas assez (rien n'est retiré).
func remove_item(item: ItemData, amount: int = 1) -> bool:
	if get_count(item.id) < amount:
		return false
	_counts[item.id] -= amount
	item_changed.emit(item, _counts[item.id])
	return true


func get_count(id: StringName) -> int:
	return _counts.get(id, 0)


## Les objets possédés, dans l'ordre où ils ont été obtenus.
func get_items() -> Array[ItemData]:
	var out: Array[ItemData] = []
	for id in _items:
		if get_count(id) > 0:
			out.append(_items[id])
	return out


## Retrouve un objet par son identifiant (tous les fichiers de data/items).
func item_by_id(id: StringName) -> ItemData:
	if _db.is_empty():
		for file in ResourceLoader.list_directory("res://data/items/"):
			if file.ends_with(".tres") or file.ends_with(".res"):
				var item := load("res://data/items/" + file) as ItemData
				if item != null:
					_db[item.id] = item
	return _db.get(id)


## Pour la sauvegarde : { identifiant : quantité }.
func serialize() -> Dictionary:
	var out := {}
	for id in _counts:
		if _counts[id] > 0:
			out[String(id)] = _counts[id]
	return out


func deserialize(data: Dictionary) -> void:
	clear()
	for id in data:
		var item := item_by_id(StringName(id))
		if item != null:
			add_item(item, int(data[id]))


func clear() -> void:
	_counts.clear()
	_items.clear()
