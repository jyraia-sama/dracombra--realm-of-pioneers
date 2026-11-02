class_name GuildOrders
extends RefCounted
## Les commandes de la guilde (voir ECONOMIE.md) : on commande des armes, armures, potions…
## Les matériaux sont pris tout de suite dans la réserve (sac + entrepôt + stocks des ateliers) ;
## les artisans affectés à l'atelier (forgerons à la forge, artisans à l'établi) fabriquent
## chaque matin. Ce qui est prêt va à l'entrepôt (ou dans le sac s'il n'y en a pas).
##
## Commande (dans Town.orders) : {"out": objet, "station": atelier, "total": n, "done": n déjà faits}

## Ateliers qui prennent des commandes, et le métier de ceux qui y travaillent.
const STATIONS := {&"forge": &"forgeron", &"workbench": &"tisserand"}


static func pending_count() -> int:
	return Town.orders.size()


## Objets fabriqués par jour et par travailleur (selon son niveau de métier).
static func per_worker(m: Dictionary) -> int:
	return 1 + int(m.get("job_level", 1)) / 2


## Travailleurs en forme de tous les ateliers d'un type.
static func workers_for(station: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r in Town.sites:
		if r["built"] and StringName(r["id"]) == station:
			for m in Roster.workers_of(int(r["uid"])):
				if m["state"] == "ok":
					out.append(m)
	return out


## Chaque matin : les artisans avancent les commandes, dans l'ordre. Renvoie ce qui est livré.
static func work_day() -> Dictionary:
	var made := {}
	for station in STATIONS:
		var capacity := 0
		for m in workers_for(station):
			capacity += per_worker(m)
		for o in Town.orders:
			if capacity <= 0:
				break
			if StringName(o["station"]) != station:
				continue
			var n := mini(capacity, int(o["total"]) - int(o["done"]))
			if n <= 0:
				continue
			o["done"] = int(o["done"]) + n
			capacity -= n
			_deliver(StringName(o["out"]), n)
			made[StringName(o["out"])] = int(made.get(StringName(o["out"]), 0)) + n
	Town.orders = Town.orders.filter(func(o): return int(o["done"]) < int(o["total"]))
	return made


static func _deliver(id: StringName, n: int) -> void:
	var item := Inventory.item_by_id(id)
	if item == null:
		return
	if Town.has_warehouse():
		Town.store(id, n)
	else:
		Inventory.add_item(item, n)


static func station_built(station: StringName) -> bool:
	return Town.count_built(station) > 0


static func order_text(o: Dictionary) -> String:
	var item := Inventory.item_by_id(StringName(o["out"]))
	return "%s : %d / %d" % [item.display_name if item else String(o["out"]), int(o["done"]), int(o["total"])]


## Menu des commandes (comptoir de Lysia, feu de la guilde, ateliers).
static func open() -> void:
	while true:
		var lines: Array[String] = []
		for station in STATIONS:
			var name: String = Crafting.STATION_NAMES.get(station, String(station))
			if not station_built(station):
				lines.append("%s : pas encore construite." % name)
				continue
			var w := workers_for(station)
			var cap := 0
			for m in w:
				cap += per_worker(m)
			lines.append("%s : %s" % [name, "%d %s, %d objet%s par jour" % [w.size(), Roster.JOBS[STATIONS[station]].to_lower() + ("s" if w.size() > 1 else ""), cap, "s" if cap > 1 else ""]
				if not w.is_empty() else "personne n'y travaille (affectez un %s)." % Roster.JOBS[STATIONS[station]].to_lower()])
		lines.append("Livraison : %s." % ("à l'entrepôt" if Town.has_warehouse() else "dans votre sac"))
		var options: Array[String] = ["Nouvelle commande"]
		for o in Town.orders:
			options.append("Annuler : %s" % order_text(o))
		options.append("Fermer")
		var i := await Choice.ask("Commandes de la guilde", "\n".join(lines), options)
		if i < 0 or i == options.size() - 1:
			return
		if i == 0:
			await _new_order()
		else:
			await _cancel(i - 1)


static func _new_order() -> void:
	var stations: Array[StringName] = []
	var names: Array[String] = []
	for station in STATIONS:
		if station_built(station):
			stations.append(station)
			names.append(Crafting.STATION_NAMES.get(station, String(station)))
	if stations.is_empty():
		Narration.say("Il faut d'abord un établi ou une forge.", 2.2)
		return
	names.append("Retour")
	var s := await Choice.ask("Nouvelle commande", "À quel atelier ?", names)
	if s < 0 or s >= stations.size():
		return
	var station := stations[s]
	var all := Crafting.recipes_for(station)
	var cats: Array[String] = []
	for r in all:
		if not cats.has(Crafting.category_of(r)):
			cats.append(Crafting.category_of(r))
	var list := all
	if cats.size() > 1:
		var copts := cats.duplicate()
		copts.append("Retour")
		var c := await Choice.ask(Crafting.STATION_NAMES.get(station, ""), "Quelle rubrique ?", copts)
		if c < 0 or c >= cats.size():
			return
		list = all.filter(func(r): return Crafting.category_of(r) == cats[c])
	var ropts: Array[String] = []
	for r in list:
		var item := Inventory.item_by_id(r["out"])
		ropts.append("%s ← %s · %d possible%s" % [item.display_name, Building.cost_text(r["in"]), _max_count(r),
			"s" if _max_count(r) > 1 else ""])
	ropts.append("Retour")
	var k := await Choice.ask(Crafting.STATION_NAMES.get(station, ""), "Que commander ? (matériaux pris dans le sac, l'entrepôt et les ateliers)", ropts)
	if k < 0 or k >= list.size():
		return
	var recipe: Dictionary = list[k]
	var most := _max_count(recipe)
	if most <= 0:
		Narration.say("Il manque : %s." % Crafting.missing_text(recipe), 2.4)
		return
	var counts: Array[int] = []
	for n in [1, 2, 3, 5, 10]:
		if n <= most:
			counts.append(n)
	var qopts: Array[String] = []
	for n in counts:
		var cost := {}
		for id in recipe["in"]:
			cost[id] = int(recipe["in"][id]) * n
		qopts.append("%d × %s ← %s" % [n * int(recipe["n"]), Inventory.item_by_id(recipe["out"]).display_name, Building.cost_text(cost)])
	qopts.append("Annuler")
	var q := await Choice.ask("Combien ?", "Les matériaux sont pris tout de suite (rendus si vous annulez).", qopts)
	if q < 0 or q >= counts.size():
		return
	var times := counts[q]
	for id in recipe["in"]:
		Town.consume(id, int(recipe["in"][id]) * times)
	Town.orders.append({"out": String(recipe["out"]), "station": String(station), "total": times * int(recipe["n"]), "done": 0})
	Town.changed.emit()
	var who := workers_for(station)
	Narration.say("Commande passée.%s" % ("" if not who.is_empty() else " Personne ne travaille encore à cet atelier !"), 2.4)


static func _max_count(recipe: Dictionary) -> int:
	var most := 99
	for id in recipe["in"]:
		most = mini(most, Town.amount_of(id) / maxi(1, int(recipe["in"][id])))
	return most


static func _cancel(index: int) -> void:
	if index < 0 or index >= Town.orders.size():
		return
	var o: Dictionary = Town.orders[index]
	var i := await Choice.ask("Annuler la commande", "%s\nLes matériaux de ce qui n'est pas encore fait vous sont rendus." % order_text(o),
		["Annuler la commande", "Garder"])
	if i != 0:
		return
	var left := int(o["total"]) - int(o["done"])
	for r in Crafting.RECIPES:
		if String(r["out"]) == String(o["out"]) and String(r["station"]) == String(o["station"]):
			var times := ceili(float(left) / maxf(1.0, float(r["n"])))
			for id in r["in"]:
				_deliver(StringName(id), int(r["in"][id]) * times)
			break
	Town.orders.remove_at(index)
	Town.changed.emit()
