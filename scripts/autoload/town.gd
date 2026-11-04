extends Node
## La ville de Dracombra : la guilde au centre, ses paliers, les quartiers qu'elle
## débloque, et les bâtiments posés (chantiers compris).
## Accessible partout avec Town.tier, Town.add_site(...), Town.advance_day()...
##
## Les quartiers sont des anneaux autour de la guilde : chaque palier en débloque un.

signal changed
## Les chemins ont changé (posés, effacés, rechargés).
signal paths_changed

## Les paliers de la guilde. radius : rayon (en cases) de la zone constructible.
## upgrade : ce qu'il faut pour passer à CE palier depuis le précédent.
const TIERS: Array[Dictionary] = [
	{"name": "Camp", "guild": "Feu de camp", "radius": 11.0},
	{"name": "Village", "guild": "Tente de guilde", "radius": 24.0,
		"upgrade": {"cost": {&"wood": 20, &"stone": 12}, "days": 2, "requires": {&"workbench": 1, &"tent": 1}}},
	{"name": "Bourg", "guild": "Maison de guilde", "radius": 40.0,
		"upgrade": {"cost": {&"wood": 60, &"stone": 40}, "days": 3, "requires": {&"tent": 4}}},
	{"name": "Ville", "guild": "Hall de guilde", "radius": 58.0,
		"upgrade": {"cost": {&"wood": 120, &"stone": 120}, "days": 5, "requires": {}}},
	{"name": "Cité", "guild": "Citadelle de la guilde", "radius": 999.0,
		"upgrade": {"cost": {&"wood": 250, &"stone": 300}, "days": 8, "requires": {}}},
]
## Les quartiers sont des ellipses : un peu plus larges que hautes, comme l'écran.
const DISTRICT_ASPECT := 4.0 / 3.0
## Version du système de construction. On l'augmente SEULEMENT quand une mise à jour change les
## emprises, la grille ou le placement : au chargement d'une sauvegarde plus ancienne, les bâtiments
## sont alors retirés et leurs matériaux rendus (voir _rebuild_reset). Sinon, on n'y touche pas.
const BUILD_VERSION := 2
## Emprise de la guilde, en cases (réservée dès le camp pour ses agrandissements).
const GUILD_SIZE := Vector2i(4, 4)
## Les chemins en pierre : un niveau par revêtement. cost : pierre par case.
const PATHS: Array[Dictionary] = [
	{"name": "Chemin de gravier", "art": "path_gravel", "cost": {&"stone": 1}, "tier": 0},
	{"name": "Chemin pavé", "art": "path_cobble", "cost": {&"stone": 3}, "tier": 1},
	{"name": "Dalles taillées", "art": "path_slab", "cost": {&"stone": 6}, "tier": 2},
]

## Palier actuel de la guilde (0 = camp).
var tier: int = 0
## Case de la guilde, au centre de la ville (fixée par la carte de Dracombra).
var center: Vector2i = Vector2i.ZERO
## Bâtiments posés : { "id", "cell": [x, y], "delivered": {objet: n}, "days": n, "built": bool }.
var sites: Array[Dictionary] = []
## Amélioration de la guilde en cours (vide s'il n'y en a pas).
var guild_upgrade: Dictionary = {}
## Chemins posés : { Vector2i case : niveau (1 = gravier, 2 = pavés, 3 = dalles) }.
var paths: Dictionary = {}

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
	warehouse = {}
	orders = []
	guild_upgrade = {}
	paths = {}
	changed.emit()
	paths_changed.emit()


func building(id: StringName) -> BuildingData:
	return _db.get(id)


func all_buildings() -> Array[BuildingData]:
	var out: Array[BuildingData] = []
	out.assign(_db.values())
	return out


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
	var record := {"uid": uid, "id": String(id), "cell": [cell.x, cell.y], "delivered": {}, "days": 0, "built": false,
		"level": 1}
	sites.append(record)
	# Un bâtiment posé sur un chemin le remplace (la pierre est rendue).
	var data := building(id)
	if data:
		for c in footprint_cells(data, cell):
			if paths.has(c):
				remove_path(c)
	changed.emit()
	return record


## Les cases couvertes par un bâtiment posé sur `cell` (même règle que Building.footprint_rect).
func footprint_cells(data: BuildingData, cell: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var left := cell.x - (data.size.x - 1) / 2
	var top := cell.y - data.size.y + 1
	for y in data.size.y:
		for x in data.size.x:
			out.append(Vector2i(left + x, top + y))
	return out


## Les cases réservées à la guilde (4 × 4, la case centrale est celle du pied de la guilde).
func guild_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in GUILD_SIZE.y:
		for x in GUILD_SIZE.x:
			out.append(Vector2i(center.x - GUILD_SIZE.x / 2 + x, center.y - GUILD_SIZE.y + 1 + y))
	return out


## { case : true } de toutes les cases prises par la guilde et les bâtiments (chantiers compris).
func occupied_cells() -> Dictionary:
	var out := {}
	for c in guild_cells():
		out[c] = true
	for r in sites:
		var data := building(StringName(r["id"]))
		if data:
			for c in footprint_cells(data, site_cell(r)):
				out[c] = true
	return out


# ------------------------------------------------------------------ paliers des bâtiments

func level_of(record: Dictionary) -> int:
	return int(record.get("level", 1))


## Nom du bâtiment à son palier actuel (« Cabane »).
func site_name(record: Dictionary) -> String:
	var data := building(StringName(record["id"]))
	return data.level_name(level_of(record)) if data else String(record["id"])


func housing_of(record: Dictionary) -> int:
	var data := building(StringName(record["id"]))
	return data.housing * level_of(record) if data else 0


func workers_max(record: Dictionary) -> int:
	var data := building(StringName(record["id"]))
	if data == null or data.workers <= 0:
		return 0
	return data.workers + level_of(record) - 1


func stock_cap(record: Dictionary) -> int:
	var data := building(StringName(record["id"]))
	return data.stock_cap * level_of(record) if data else 40


## Pourquoi on ne peut pas encore améliorer ce bâtiment ("" si c'est possible).
func upgrade_block(record: Dictionary) -> String:
	var data := building(StringName(record["id"]))
	if data == null or not record["built"]:
		return "Le bâtiment n'est pas terminé."
	var next := level_of(record) + 1
	if next > data.max_level():
		return "Ce bâtiment est à son dernier palier."
	if tier < data.tier_for_level(next):
		return "Il faut une guilde de palier « %s »." % tier_name(mini(data.tier_for_level(next), TIERS.size() - 1))
	return ""


func start_site_upgrade(record: Dictionary) -> bool:
	if upgrade_block(record) != "" or record.has("upgrade"):
		return false
	record["upgrade"] = {"delivered": {}, "days": 0}
	changed.emit()
	return true


# ------------------------------------------------------------------ chemins

func path_level(cell: Vector2i) -> int:
	return int(paths.get(cell, 0))


func set_path(cell: Vector2i, level: int) -> void:
	paths[cell] = level
	paths_changed.emit()


## Retire un chemin et rend sa pierre dans le sac (sauf `refund` à false).
func remove_path(cell: Vector2i, refund: bool = true) -> void:
	var level := path_level(cell)
	if level <= 0:
		return
	paths.erase(cell)
	if not refund:
		paths_changed.emit()
		return
	var cost: Dictionary = PATHS[level - 1]["cost"]
	for id in cost:
		var item := Inventory.item_by_id(id)
		if item:
			Inventory.add_item(item, int(cost[id]))
	paths_changed.emit()


func remove_site(record: Dictionary) -> void:
	sites.erase(record)
	changed.emit()


## Ce que rend un bâtiment démoli : son coût et ses améliorations s'il est terminé (sinon ce qui a
## été déposé sur le chantier), plus le stock qu'il gardait.
func site_refund(r: Dictionary) -> Dictionary:
	var refund := {}
	var add := func(items: Dictionary, times: int = 1) -> void:
		for k in items:
			refund[String(k)] = int(refund.get(String(k), 0)) + int(items[k]) * times
	var data := building(StringName(r["id"]))
	if data == null:
		return refund
	if r["built"]:
		add.call(data.cost)
		for l in range(2, level_of(r) + 1):
			add.call(data.upgrade_cost(l))
		if r.has("upgrade"):
			add.call(r["upgrade"].get("delivered", {}))
	else:
		add.call(r.get("delivered", {}))
	add.call(r.get("stock", {}))
	return refund


## Le bâtiment (ou chantier) qui couvre une case, ou {}.
func site_at(cell: Vector2i) -> Dictionary:
	for r in sites:
		var data := building(StringName(r["id"]))
		if data and cell in footprint_cells(data, site_cell(r)):
			return r
	return {}


## Démolit un bâtiment : ses travailleurs quittent leur poste, ses matériaux reviennent dans le sac
## (sauf `refund` à false, en mode admin). Renvoie ce qui a été rendu.
func demolish(record: Dictionary, refund: bool = true) -> Dictionary:
	var back := site_refund(record) if refund else {}
	for k in back:
		var item := Inventory.item_by_id(StringName(k))
		if item and int(back[k]) > 0:
			Inventory.add_item(item, int(back[k]))
	for m in Roster.members:
		if int(m.get("work", 0)) == int(record["uid"]):
			m["work"] = 0
	sites.erase(record)
	changed.emit()
	return back


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


# ------------------------------------------------------------------ l'entrepôt
## Stock commun de la ville : { identifiant : quantité }. Rempli par la production une fois
## l'entrepôt construit ; l'établi, la forge et les chantiers y puisent (après le sac).
var warehouse: Dictionary = {}
## Commandes de la guilde en cours (voir GuildOrders).
var orders: Array = []


func has_warehouse() -> bool:
	return count_built(&"warehouse") > 0


func stored(id: StringName) -> int:
	return int(warehouse.get(String(id), 0)) if has_warehouse() else 0


func store(id: StringName, n: int) -> void:
	warehouse[String(id)] = int(warehouse.get(String(id), 0)) + n
	changed.emit()


## Ce que gardent les bâtiments de travail (avant l'entrepôt, ou en attendant le transport du matin).
func in_workshops(id: StringName) -> int:
	var n := 0
	for r in sites:
		n += int(r.get("stock", {}).get(String(id), 0))
	return n


## Quantité disponible pour fabriquer et bâtir : sac du héros + entrepôt + stocks des bâtiments.
## Tous les ateliers (établi, forge, séchoir, chantiers, commandes) puisent dans cette réserve.
func amount_of(id: StringName) -> int:
	return Inventory.get_count(id) + int(warehouse.get(String(id), 0)) + in_workshops(id)


## Détail de la réserve, pour l'affichage : « 3 (sac 1, entrepôt 2) ».
func amount_text(id: StringName) -> String:
	var parts: Array[String] = []
	var bag := Inventory.get_count(id)
	var ware := int(warehouse.get(String(id), 0))
	var shops := in_workshops(id)
	if bag > 0:
		parts.append("sac %d" % bag)
	if ware > 0:
		parts.append("entrepôt %d" % ware)
	if shops > 0:
		parts.append("ateliers %d" % shops)
	return "%d%s" % [bag + ware + shops, " (%s)" % ", ".join(parts) if parts.size() > 1 else ""]


## Prend `n` objets : d'abord dans le sac, puis dans l'entrepôt, puis dans les stocks des
## bâtiments. false (rien pris) s'il en manque.
func consume(id: StringName, n: int) -> bool:
	if amount_of(id) < n:
		return false
	var item := Inventory.item_by_id(id)
	var from_bag := mini(Inventory.get_count(id), n)
	if from_bag > 0:
		Inventory.remove_item(item, from_bag)
	var rest := n - from_bag
	var key := String(id)
	if rest > 0 and int(warehouse.get(key, 0)) > 0:
		var take := mini(int(warehouse[key]), rest)
		warehouse[key] = int(warehouse[key]) - take
		if int(warehouse[key]) <= 0:
			warehouse.erase(key)
		rest -= take
	for r in sites:
		if rest <= 0:
			break
		var st: Dictionary = r.get("stock", {})
		if int(st.get(key, 0)) > 0:
			var take := mini(int(st[key]), rest)
			st[key] = int(st[key]) - take
			rest -= take
	changed.emit()
	return true


func consume_from_warehouse(id: StringName, n: int) -> void:
	warehouse[String(id)] = int(warehouse.get(String(id), 0)) - n
	if int(warehouse[String(id)]) <= 0:
		warehouse.erase(String(id))
	changed.emit()


## Dépose ce que le héros possède (et ce qu'il y a à l'entrepôt). Renvoie le nombre d'objets déposés.
func deliver(cost: Dictionary, delivered: Dictionary) -> int:
	var moved := 0
	var need := missing(cost, delivered)
	for id in need:
		var n := mini(amount_of(id), int(need[id]))
		if n > 0 and consume(id, n):
			delivered[String(id)] = int(delivered.get(String(id), 0)) + n
			moved += n
	if moved > 0:
		changed.emit()
	return moved


func site_by_uid(uid: int) -> Dictionary:
	for r in sites:
		if int(r["uid"]) == uid:
			return r
	return {}


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
			if record.has("upgrade"):
				var bd := building(StringName(record["id"]))
				var next := level_of(record) + 1
				if bd and missing(bd.upgrade_cost(next), record["upgrade"]["delivered"]).is_empty():
					record["upgrade"]["days"] = int(record["upgrade"]["days"]) + 1
					if int(record["upgrade"]["days"]) >= bd.upgrade_days(next):
						record["level"] = next
						record.erase("upgrade")
						messages.append("Amélioration terminée : %s." % bd.level_name(next))
			continue
		var data := building(StringName(record["id"]))
		if data == null or not missing(data.cost, record["delivered"]).is_empty():
			continue
		record["days"] = int(record["days"]) + 1
		if int(record["days"]) >= data.build_days:
			record["built"] = true
			messages.append("Construction terminée : %s." % data.level_name(level_of(record)))
	if not guild_upgrade.is_empty():
		var up := next_upgrade()
		if missing(up["cost"], guild_upgrade["delivered"]).is_empty():
			guild_upgrade["days"] = int(guild_upgrade["days"]) + 1
			if int(guild_upgrade["days"]) >= int(up["days"]):
				tier += 1
				guild_upgrade = {}
				messages.append("La guilde devient : %s. Dracombra est maintenant un %s !" % [guild_name(), tier_name().to_lower()])
				messages.append("Un nouveau quartier peut être déblayé.")
	# Les artisans avancent les commandes de la guilde.
	var made := GuildOrders.work_day()
	if not made.is_empty():
		messages.append("Commandes prêtes (%s) : %s." % ["à l'entrepôt" if has_warehouse() else "dans votre sac", Building.cost_text(made)])
	changed.emit()
	return messages


# ------------------------------------------------------------------ sauvegarde

func serialize() -> Dictionary:
	var path_list := []
	for c in paths:
		path_list.append([c.x, c.y, int(paths[c])])
	return {"tier": tier, "sites": sites.duplicate(true), "guild_upgrade": guild_upgrade.duplicate(true),
		"warehouse": warehouse.duplicate(), "orders": orders.duplicate(true), "paths": path_list,
		"build_version": BUILD_VERSION}


func deserialize(data: Dictionary) -> void:
	rebuilt_after_update = false
	tier = int(data.get("tier", 0))
	sites.clear()
	# Les identifiants sont gardés (les habitants y sont affectés) ; anciens enregistrements numérotés.
	var uid := 1
	for record in data.get("sites", []):
		uid = maxi(uid, int(record.get("uid", 0)) + 1)
	for record in data.get("sites", []):
		if int(record.get("uid", 0)) <= 0:
			record["uid"] = uid
			uid += 1
		else:
			record["uid"] = int(record["uid"])
		sites.append(record)
	guild_upgrade = data.get("guild_upgrade", {})
	warehouse = data.get("warehouse", {}).duplicate()
	orders = data.get("orders", []).duplicate(true)
	paths = {}
	for p in data.get("paths", []):
		paths[Vector2i(int(p[0]), int(p[1]))] = int(p[2])
	for r in sites:
		r["level"] = int(r.get("level", 1))
	# Sauvegarde d'avant un changement du système de construction : on repart d'une ville vide.
	if int(data.get("build_version", 1)) < BUILD_VERSION and not sites.is_empty():
		_rebuild_reset()
	changed.emit()
	paths_changed.emit()


## Retire tous les bâtiments et chemins, et rend au héros (dans son sac) tout ce qu'ils avaient coûté,
## ainsi que les stocks des bâtiments et de l'entrepôt. La guilde et son palier sont gardés.
## Appelé uniquement quand BUILD_VERSION a augmenté depuis la sauvegarde.
func _rebuild_reset() -> void:
	var refund := {}
	var add := func(items: Dictionary, times: int = 1) -> void:
		for k in items:
			refund[String(k)] = int(refund.get(String(k), 0)) + int(items[k]) * times
	for r in sites:
		var data := building(StringName(r["id"]))
		if data == null:
			continue
		if r["built"]:
			add.call(data.cost)
			for l in range(2, level_of(r) + 1):
				add.call(data.upgrade_cost(l))
			if r.has("upgrade"):
				add.call(r["upgrade"].get("delivered", {}))
		else:
			add.call(r.get("delivered", {}))
		add.call(r.get("stock", {}))
	for c in paths:
		add.call(PATHS[int(paths[c]) - 1]["cost"])
	add.call(warehouse)
	var n := 0
	for k in refund:
		var item := Inventory.item_by_id(StringName(k))
		if item and int(refund[k]) > 0:
			Inventory.add_item(item, int(refund[k]))
			n += int(refund[k])
	sites.clear()
	paths = {}
	warehouse = {}
	rebuilt_after_update = true
	Game.pending_message = ("Mise à jour : la construction a changé (mode construction, nouvelles emprises). " +
		"Vos bâtiments ont été retirés et leurs matériaux rendus dans votre sac (%d objets). " +
		"Appuyez sur B pour reconstruire.") % n


## true si le dernier chargement a vidé la ville (les membres doivent quitter leur travail).
var rebuilt_after_update := false
