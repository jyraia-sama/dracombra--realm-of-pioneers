extends Node
## Inventaire global du joueur : les ressources ramassées (gelée, pierre...).
## Accessible partout avec Inventory.add_item(...), Inventory.get_count(...).

signal item_changed(item: ItemData, count: int)

var _counts: Dictionary[StringName, int] = {}
var _items: Dictionary[StringName, ItemData] = {}
var _db: Dictionary[StringName, ItemData] = {}
## Objets uniques (butin rare…) : identifiant -> {"base", "rarity", "bonus"}.
var _uniques: Dictionary = {}
var _next_uid := 1


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


## Crée un objet unique à partir d'un objet de base, avec sa rareté et ses bonus en plus.
## L'objet est connu de item_by_id comme n'importe quel autre.
func register_unique(base_id: StringName, rarity: int, extra: Dictionary, uid: String = "") -> ItemData:
	var base := item_by_id(base_id)
	if base == null:
		return null
	if uid == "":
		uid = "u%d" % _next_uid
		_next_uid += 1
	else:
		_next_uid = maxi(_next_uid, int(uid.trim_prefix("u")) + 1)
	var item := base.duplicate() as ItemData
	item.id = StringName(uid)
	item.base_id = base_id
	item.rarity = rarity
	var bonus := base.bonus.duplicate()
	for k in extra:
		bonus[k] = int(bonus.get(k, 0)) + int(extra[k])
	item.bonus = bonus
	_db[item.id] = item
	_uniques[uid] = {"base": String(base_id), "rarity": rarity, "bonus": extra.duplicate()}
	return item


## Pour la sauvegarde : { identifiant : quantité }, plus les objets uniques ("__uniques").
func serialize() -> Dictionary:
	var out := {}
	for id in _counts:
		if _counts[id] > 0:
			out[String(id)] = _counts[id]
	var keep := {}
	var worn: Array = Hero.gear.values().map(func(v): return String(v))
	for uid in _uniques:
		if get_count(StringName(uid)) > 0 or worn.has(uid):
			keep[uid] = _uniques[uid]
	if not keep.is_empty():
		out["__uniques"] = keep
	return out


func deserialize(data: Dictionary) -> void:
	clear()
	var uniques: Dictionary = data.get("__uniques", {})
	for uid in uniques:
		var u: Dictionary = uniques[uid]
		register_unique(StringName(u["base"]), int(u["rarity"]), u.get("bonus", {}), String(uid))
	for id in data:
		if String(id).begins_with("__"):
			continue
		var item := item_by_id(StringName(id))
		if item != null:
			add_item(item, int(data[id]))


func clear() -> void:
	_counts.clear()
	_items.clear()
	for uid in _uniques:
		_db.erase(StringName(uid))
	_uniques.clear()
