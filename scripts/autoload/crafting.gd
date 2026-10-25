extends Node
## Les recettes de fabrication, par atelier (établi, séchoir...).
##     Crafting.open(&"workbench")  -> menu des recettes de l'établi

const RECIPES: Array[Dictionary] = [
	{"out": &"axe", "n": 1, "station": &"camp", "in": {&"wood": 3, &"stone": 2}},
	{"out": &"pickaxe", "n": 1, "station": &"camp", "in": {&"wood": 3, &"stone": 3}},
	{"out": &"rope", "n": 1, "station": &"workbench", "in": {&"flax": 3}},
	{"out": &"cloth", "n": 1, "station": &"workbench", "in": {&"flax": 4}},
	{"out": &"balm", "n": 1, "station": &"workbench", "in": {&"herb": 3}},
	{"out": &"bow", "n": 1, "station": &"workbench", "in": {&"wood": 4, &"rope": 1, &"leather": 2}},
	{"out": &"staff", "n": 1, "station": &"workbench", "in": {&"wood": 3, &"gem": 1, &"cloth": 2}},
	{"out": &"holy_symbol", "n": 1, "station": &"workbench", "in": {&"wood": 2, &"cloth": 2, &"balm": 1}},
	{"out": &"leather", "n": 1, "station": &"drying_rack", "in": {&"hide": 1}},
]
const STATION_NAMES := {&"workbench": "Établi", &"drying_rack": "Séchoir à peaux", &"camp": "Feu de camp"}


func recipes_for(station: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r in RECIPES:
		if r["station"] == station:
			out.append(r)
	return out


func can_craft(recipe: Dictionary) -> bool:
	for id in recipe["in"]:
		if Inventory.get_count(id) < int(recipe["in"][id]):
			return false
	return true


func craft(recipe: Dictionary) -> bool:
	if not can_craft(recipe):
		return false
	for id in recipe["in"]:
		Inventory.remove_item(Inventory.item_by_id(id), int(recipe["in"][id]))
	var item := Inventory.item_by_id(recipe["out"])
	Inventory.add_item(item, int(recipe["n"]))
	# L'équipement d'une classe la débloque.
	for cls in Hero.CLASSES:
		if Hero.CLASSES[cls]["item"] == recipe["out"] and Hero.unlock(cls):
			Narration.say("Nouvelle classe débloquée : %s ! Changez de classe au feu de camp ou à la guilde." % Hero.CLASSES[cls]["name"], 4.0)
	return true


## Menu de l'atelier : on fabrique tant qu'on veut, puis « Fermer ».
func open(station: StringName) -> void:
	while true:
		var list := recipes_for(station)
		var options: Array[String] = []
		for r in list:
			var item := Inventory.item_by_id(r["out"])
			var mark := "" if can_craft(r) else "  (manque)"
			options.append("%s ← %s%s" % [item.display_name, Building.cost_text(r["in"]), mark])
		options.append("Fermer")
		var choice := await Choice.ask(STATION_NAMES.get(station, "Atelier"), "Que fabriquer ?", options)
		if choice < 0 or choice >= list.size():
			return
		var r: Dictionary = list[choice]
		if craft(r):
			var item := Inventory.item_by_id(r["out"])
			Emote.show(get_tree().get_first_node_in_group("player"), "+1", Color(0.6, 1.0, 0.6))
			if not Narration.box.modulate.a > 0.5:
				Narration.say("Fabriqué : %s." % item.display_name, 1.8)
		else:
			Narration.say("Il manque des matériaux.", 1.6)
