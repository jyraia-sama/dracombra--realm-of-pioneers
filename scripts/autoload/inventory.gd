extends Node
## Inventaire global du joueur : les ressources ramassées (gelée, pierre...).
## Accessible partout avec Inventory.add_item(...), Inventory.get_count(...).

signal item_changed(item: ItemData, count: int)

var _counts: Dictionary[StringName, int] = {}
var _items: Dictionary[StringName, ItemData] = {}


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


func clear() -> void:
	_counts.clear()
	_items.clear()
