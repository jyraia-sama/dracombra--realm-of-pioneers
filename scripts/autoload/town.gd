extends Node
## La ville de Dracombra : la guilde au centre, ses paliers, les quartiers qu'elle
## débloque, et les bâtiments posés (chantiers compris).
## Accessible partout avec Town.tier, Town.add_site(...), Town.advance_day()...
##
## Les quartiers sont des anneaux autour de la guilde : chaque palier en débloque un.

signal changed

## Les paliers de la guilde. radius : rayon (en cases) de la zone constructible.
## upgrade : ce qu'il faut pour passer à CE palier depuis le précédent.
const TIERS: Array[Dictionary] = [
	{"name": "Camp", "guild": "Feu de camp", "radius": 11.0},
	{"name": "Village", "guild": "Tente de guilde", "radius": 24.0,
		"upgrade": {"cost": {&"wood": 20, &"stone": 12}, "days": 2, "requires": {&"workbench": 1, &"tent": 2}}},
	{"name": "Bourg", "guild": "Maison de guilde", "radius": 40.0,
		"upgrade": {"cost": {&"wood": 60, &"stone": 40}, "days": 3, "requires": {&"tent": 4}}},
	{"name": "Ville", "guild": "Hall de guilde", "radius": 58.0,
		"upgrade": {"cost": {&"wood": 120, &"stone": 120}, "days": 5, "requires": {}}},
	{"name": "Cité", "guild": "Citadelle de la guilde", "radius": 999.0,
		"upgrade": {"cost": {&"wood": 250, &"stone": 300}, "days": 8, "requires": {}}},
]
## Les quartiers sont des ellipses : un peu plus larges que hautes, comme l'écran.
const DISTRICT_ASPECT := 4.0 / 3.0

## Palier actuel de la guilde (0 = camp).
var tier: int = 0
## Case de la guilde, au centre de la ville (fixée par la carte de Dracombra).
var center: Vector2i = Vector2i.ZERO
## Bâtiments posés : { "id", "cell": [x, y], "delivered": {objet: n}, "days": n, "built": bool }.
var sites: Array[Dictionary] = []
## Amélioration de la guilde en cours (vide s'il n'y en a pas).
var guild_upgrade: Dictionary = {}

var _db: Dictionary[StringName, BuildingData] = {}


func _ready() -> void:
	for file in ResourceLoader.list_directory("res://data/buildings/"):
		if file.ends_with(".tres") or file.ends_with(".res"):
			var data := load("res://data/buildings/" + file) as BuildingData
			if data != null:
				_db[data.id] = data


func reset() -> void:
	tier = 0
	sites.clear()
	guild_upgrade = {}
	changed.emit()


func building(id: StringName) -> BuildingData:
	return _db.get(id)


## Les bâtiments déjà débloqués, du moins cher au plus cher.
func available() -> Array[BuildingData]:
	var out: Array[BuildingData] = []
	for data in _db.values():
		if data.tier_required <= tier:
			out.append(data)
	out.sort_custom(func(a, b): return a.tier_required < b.tier_required or (a.tier_required == b.tier_required and String(a.id) < String(b.id)))
	return out


func tier_name(t: int = -1) -> String:
	return TIERS[tier if t < 0 else t]["name"]


func guild_name(t: int = -1) -> String:
	return TIERS[tier if t < 0 else t]["guild"]


# ------------------------------------------------------------------ quartiers

## Distance « elliptique » d'une case au centre, en cases.
func district_distance(cell: Vector2i) -> float:
	var d := Vector2(cell - center)
	return Vector2(d.x, d.y * DISTRICT_ASPECT).length()


## Le palier qu'il faut pour construire sur cette case.
func district_of(cell: Vector2i) -> int:
	var dist := district_distance(cell)
	for i in TIERS.size():
		if dist <= float(TIERS[i]["radius"]):
			return i
	return TIERS.size() - 1


func is_unlocked(cell: Vector2i) -> bool:
	return district_of(cell) <= tier


# ------------------------------------------------------------------ chantiers

func add_site(id: StringName, cell: Vector2i) -> Dictionary:
	var uid := 1
	for r in sites:
		uid = maxi(uid, int(r.get("uid", 0)) + 1)
	var record := {"uid": uid, "id": String(id), "cell": [cell.x, cell.y], "delivered": {}, "days": 0, "built": false}
	sites.append(record)
	changed.emit()
	return record


func remove_site(record: Dictionary) -> void:
	sites.erase(record)
	changed.emit()


func site_cell(record: Dictionary) -> Vector2i:
	return Vector2i(int(record["cell"][0]), int(record["cell"][1]))


## Ce qu'il reste à déposer : { objet : quantité }.
func missing(cost: Dictionary, delivered: Dictionary) -> Dictionary:
	var out := {}
	for item in cost:
		var left: int = int(cost[item]) - int(delivered.get(String(item), 0))
		if left > 0:
			out[item] = left
	return out


## Dépose ce que le héros possède. Renvoie le nombre d'objets déposés.
func deliver(cost: Dictionary, delivered: Dictionary) -> int:
	var moved := 0
	var need := missing(cost, delivered)
	for id in need:
		var item := Inventory.item_by_id(id)
		if item == null:
			continue
		var n := mini(Inventory.get_count(id), int(need[id]))
		if n > 0 and Inventory.remove_item(item, n):
			delivered[String(id)] = int(delivered.get(String(id), 0)) + n
			moved += n
	if moved > 0:
		changed.emit()
	return moved


func count_built(id: StringName) -> int:
	var n := 0
	for record in sites:
		if record["id"] == String(id) and record["built"]:
			n += 1
	return n


# ------------------------------------------------------------------ la guilde

## Ce qu'il faut pour le palier suivant, ou {} si la guilde est au maximum.
func next_upgrade() -> Dictionary:
	if tier + 1 >= TIERS.size():
		return {}
	return TIERS[tier + 1]["upgrade"]


## Les bâtiments qui manquent encore pour améliorer la guilde : { id : manquants }.
func missing_buildings() -> Dictionary:
	var out := {}
	var up := next_upgrade()
	for id in up.get("requires", {}):
		var left: int = int(up["requires"][id]) - count_built(id)
		if left > 0:
			out[id] = left
	return out


func start_guild_upgrade() -> bool:
	if next_upgrade().is_empty() or not guild_upgrade.is_empty() or not missing_buildings().is_empty():
		return false
	guild_upgrade = {"delivered": {}, "days": 0}
	changed.emit()
	return true


# ------------------------------------------------------------------ les jours

## Un jour passe : les chantiers approvisionnés avancent.
## Renvoie les messages à afficher (« La tente est terminée ! »...).
func advance_day() -> Array[String]:
	var messages: Array[String] = []
	for record in sites:
		if record["built"]:
			continue
		var data := building(StringName(record["id"]))
		if data == null or not missing(data.cost, record["delivered"]).is_empty():
			continue
		record["days"] = int(record["days"]) + 1
		if int(record["days"]) >= data.build_days:
			record["built"] = true
			messages.append("Construction terminée : %s." % data.display_name)
	if not guild_upgrade.is_empty():
		var up := next_upgrade()
		if missing(up["cost"], guild_upgrade["delivered"]).is_empty():
			guild_upgrade["days"] = int(guild_upgrade["days"]) + 1
			if int(guild_upgrade["days"]) >= int(up["days"]):
				tier += 1
				guild_upgrade = {}
				messages.append("La guilde devient : %s. Dracombra est maintenant un %s !" % [guild_name(), tier_name().to_lower()])
				messages.append("Un nouveau quartier peut être déblayé.")
	changed.emit()
	return messages


# ------------------------------------------------------------------ sauvegarde

func serialize() -> Dictionary:
	return {"tier": tier, "sites": sites.duplicate(true), "guild_upgrade": guild_upgrade.duplicate(true)}


func deserialize(data: Dictionary) -> void:
	tier = int(data.get("tier", 0))
	sites.clear()
	var uid := 1
	for record in data.get("sites", []):
		record["uid"] = uid
		uid += 1
		sites.append(record)
	guild_upgrade = data.get("guild_upgrade", {})
	changed.emit()
