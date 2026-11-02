extends Node
## Les recettes de fabrication, par atelier (établi, séchoir...).
##     Crafting.open(&"workbench")  -> menu des recettes de l'établi

const RECIPES: Array[Dictionary] = [
	{"out": &"axe", "n": 1, "station": &"camp", "in": {&"wood": 3, &"stone": 2}},
	{"out": &"pickaxe", "n": 1, "station": &"camp", "in": {&"wood": 3, &"stone": 3}},
	{"out": &"rope", "n": 1, "station": &"workbench", "in": {&"flax": 3}},
	{"out": &"cloth", "n": 1, "station": &"workbench", "in": {&"flax": 4}},
	{"out": &"balm", "n": 1, "station": &"workbench", "in": {&"herb": 3}},
	{"out": &"potion_stamina", "n": 1, "station": &"workbench", "in": {&"herb": 2, &"meat": 1}},
	{"out": &"potion_mana", "n": 1, "station": &"workbench", "in": {&"herb": 2, &"mana_crystal": 1}},
	{"out": &"short_sword", "n": 1, "station": &"workbench", "in": {&"wood": 2, &"stone": 4, &"leather": 1}},
	{"out": &"bow", "n": 1, "station": &"workbench", "in": {&"wood": 4, &"rope": 1, &"leather": 2}},
	{"out": &"staff", "n": 1, "station": &"workbench", "in": {&"wood": 3, &"gem": 1, &"cloth": 2}},
	{"out": &"holy_symbol", "n": 1, "station": &"workbench", "in": {&"wood": 2, &"cloth": 2, &"balm": 1}},
	{"out": &"leather", "n": 1, "station": &"drying_rack", "in": {&"hide": 1}},
	# Équipement (menu Équipement : Tête, Armure, Gants, Bottes, Arme secondaire).
	{"out": &"leather_hood", "n": 1, "station": &"workbench", "in": {&"leather": 2, &"cloth": 1}},
	{"out": &"leather_armor", "n": 1, "station": &"workbench", "in": {&"leather": 4, &"rope": 1}},
	{"out": &"leather_gloves", "n": 1, "station": &"workbench", "in": {&"leather": 2}},
	{"out": &"leather_boots", "n": 1, "station": &"workbench", "in": {&"leather": 2, &"hide": 1}},
	{"out": &"wooden_shield", "n": 1, "station": &"workbench", "in": {&"wood": 5, &"leather": 1, &"stone": 1}},
	{"out": &"quiver", "n": 1, "station": &"workbench", "in": {&"leather": 2, &"rope": 1, &"wood": 2}},
	{"out": &"spell_tome", "n": 1, "station": &"workbench", "in": {&"cloth": 2, &"leather": 1, &"gem": 1}},
	# ---- Palier 1 (caverne d'obsidienne), voir DONJON.md ----
	# Forge : lingots et équipement lourd (guerrier).
	{"out": &"iron_ingot", "n": 1, "station": &"forge", "in": {&"iron_ore": 2, &"wood": 1}},
	{"out": &"iron_sword", "n": 1, "station": &"forge", "in": {&"iron_ingot": 3, &"wood": 1}},
	{"out": &"iron_shield", "n": 1, "station": &"forge", "in": {&"iron_ingot": 3, &"wood": 2}},
	{"out": &"iron_helmet", "n": 1, "station": &"forge", "in": {&"iron_ingot": 2}},
	{"out": &"iron_armor", "n": 1, "station": &"forge", "in": {&"iron_ingot": 5, &"leather": 2}},
	{"out": &"iron_gauntlets", "n": 1, "station": &"forge", "in": {&"iron_ingot": 2, &"leather": 1}},
	{"out": &"iron_boots", "n": 1, "station": &"forge", "in": {&"iron_ingot": 2, &"leather": 1}},
	# Établi : étoffe de soie, équipement de cuir (archer) et de tissu (mage, clerc).
	{"out": &"silk_cloth", "n": 1, "station": &"workbench", "in": {&"silk": 3}},
	{"out": &"chitin_bow", "n": 1, "station": &"workbench", "in": {&"chitin": 3, &"silk": 3, &"wood": 2}},
	{"out": &"silk_quiver", "n": 1, "station": &"workbench", "in": {&"silk_cloth": 2, &"chitin": 2}},
	{"out": &"chitin_hood", "n": 1, "station": &"workbench", "in": {&"chitin": 3, &"silk_cloth": 1}},
	{"out": &"chitin_armor", "n": 1, "station": &"workbench", "in": {&"chitin": 6, &"leather": 2}},
	{"out": &"chitin_bracers", "n": 1, "station": &"workbench", "in": {&"chitin": 2, &"silk": 2}},
	{"out": &"chitin_boots", "n": 1, "station": &"workbench", "in": {&"chitin": 3, &"leather": 1}},
	{"out": &"crystal_staff", "n": 1, "station": &"workbench", "in": {&"wood": 3, &"mana_crystal": 2, &"silk_cloth": 1}},
	{"out": &"sacred_book", "n": 1, "station": &"workbench", "in": {&"silk_cloth": 2, &"mana_crystal": 2, &"leather": 1}},
	{"out": &"silk_hood", "n": 1, "station": &"workbench", "in": {&"silk_cloth": 2}},
	{"out": &"silk_robe", "n": 1, "station": &"workbench", "in": {&"silk_cloth": 4, &"mana_crystal": 1}},
	{"out": &"silk_gloves", "n": 1, "station": &"workbench", "in": {&"silk_cloth": 2}},
	{"out": &"silk_shoes", "n": 1, "station": &"workbench", "in": {&"silk_cloth": 2, &"leather": 1}},
	# ---- Palier 2 (cryptes des pionniers), voir DONJON.md ----
	# Forge : argent et équipement lourd.
	{"out": &"silver_ingot", "n": 1, "station": &"forge", "in": {&"silver_ore": 2, &"wood": 1}},
	{"out": &"silver_sword", "n": 1, "station": &"forge", "in": {&"silver_ingot": 3, &"iron_ingot": 1, &"wood": 1}},
	{"out": &"silver_shield", "n": 1, "station": &"forge", "in": {&"silver_ingot": 3, &"wood": 2}},
	{"out": &"silver_helmet", "n": 1, "station": &"forge", "in": {&"silver_ingot": 2, &"iron_ingot": 1}},
	{"out": &"silver_armor", "n": 1, "station": &"forge", "in": {&"silver_ingot": 5, &"crypt_leather": 2}},
	{"out": &"silver_gauntlets", "n": 1, "station": &"forge", "in": {&"silver_ingot": 2, &"crypt_leather": 1}},
	{"out": &"silver_boots", "n": 1, "station": &"forge", "in": {&"silver_ingot": 2, &"crypt_leather": 1}},
	# Établi : os et cuir des cryptes (archer), bandelettes et essence spectrale (mage, clerc).
	{"out": &"bone_bow", "n": 1, "station": &"workbench", "in": {&"ancient_bone": 4, &"silk": 3, &"crypt_leather": 1}},
	{"out": &"bone_quiver", "n": 1, "station": &"workbench", "in": {&"crypt_leather": 2, &"ancient_bone": 2}},
	{"out": &"bone_hood", "n": 1, "station": &"workbench", "in": {&"ancient_bone": 2, &"crypt_leather": 2}},
	{"out": &"crypt_leather_armor", "n": 1, "station": &"workbench", "in": {&"crypt_leather": 5, &"ancient_bone": 2}},
	{"out": &"bone_bracers", "n": 1, "station": &"workbench", "in": {&"ancient_bone": 3, &"crypt_leather": 1}},
	{"out": &"crypt_boots", "n": 1, "station": &"workbench", "in": {&"crypt_leather": 3, &"ancient_bone": 1}},
	{"out": &"wraps_hood", "n": 1, "station": &"workbench", "in": {&"linen_wraps": 3, &"spectral_essence": 1}},
	{"out": &"spectral_robe", "n": 1, "station": &"workbench", "in": {&"linen_wraps": 5, &"spectral_essence": 2, &"silk_cloth": 1}},
	{"out": &"wraps_gloves", "n": 1, "station": &"workbench", "in": {&"linen_wraps": 2, &"spectral_essence": 1}},
	{"out": &"wraps_shoes", "n": 1, "station": &"workbench", "in": {&"linen_wraps": 2, &"crypt_leather": 1}},
	{"out": &"spectral_staff", "n": 1, "station": &"workbench", "in": {&"wood": 2, &"spectral_essence": 3, &"mana_crystal": 2}},
	{"out": &"spectral_tome", "n": 1, "station": &"workbench", "in": {&"linen_wraps": 3, &"spectral_essence": 2, &"silver_ingot": 1}},
]
const STATION_NAMES := {&"workbench": "Établi", &"drying_rack": "Séchoir à peaux", &"camp": "Feu de camp", &"forge": "Forge"}


## Rubriques des longues listes (établi) : objet fabriqué -> rubrique. Défaut : « Matériaux ».
const CATEGORIES := {
	&"short_sword": "Armes de classe", &"bow": "Armes de classe", &"staff": "Armes de classe", &"holy_symbol": "Armes de classe",
	&"leather_hood": "Palier 0 · équipement", &"leather_armor": "Palier 0 · équipement",
	&"leather_gloves": "Palier 0 · équipement", &"leather_boots": "Palier 0 · équipement",
	&"wooden_shield": "Palier 0 · équipement", &"quiver": "Palier 0 · équipement", &"spell_tome": "Palier 0 · équipement",
	&"iron_sword": "Palier 1 · lourd (guerrier)", &"iron_shield": "Palier 1 · lourd (guerrier)",
	&"iron_helmet": "Palier 1 · lourd (guerrier)", &"iron_armor": "Palier 1 · lourd (guerrier)",
	&"iron_gauntlets": "Palier 1 · lourd (guerrier)", &"iron_boots": "Palier 1 · lourd (guerrier)",
	&"chitin_bow": "Palier 1 · cuir (archer)", &"silk_quiver": "Palier 1 · cuir (archer)",
	&"chitin_hood": "Palier 1 · cuir (archer)", &"chitin_armor": "Palier 1 · cuir (archer)",
	&"chitin_bracers": "Palier 1 · cuir (archer)", &"chitin_boots": "Palier 1 · cuir (archer)",
	&"crystal_staff": "Palier 1 · tissu (mage, clerc)", &"sacred_book": "Palier 1 · tissu (mage, clerc)",
	&"silk_hood": "Palier 1 · tissu (mage, clerc)", &"silk_robe": "Palier 1 · tissu (mage, clerc)",
	&"silk_gloves": "Palier 1 · tissu (mage, clerc)", &"silk_shoes": "Palier 1 · tissu (mage, clerc)",
	&"silver_sword": "Palier 2 · lourd (guerrier)", &"silver_shield": "Palier 2 · lourd (guerrier)",
	&"silver_helmet": "Palier 2 · lourd (guerrier)", &"silver_armor": "Palier 2 · lourd (guerrier)",
	&"silver_gauntlets": "Palier 2 · lourd (guerrier)", &"silver_boots": "Palier 2 · lourd (guerrier)",
	&"bone_bow": "Palier 2 · cuir (archer)", &"bone_quiver": "Palier 2 · cuir (archer)",
	&"bone_hood": "Palier 2 · cuir (archer)", &"crypt_leather_armor": "Palier 2 · cuir (archer)",
	&"bone_bracers": "Palier 2 · cuir (archer)", &"crypt_boots": "Palier 2 · cuir (archer)",
	&"spectral_staff": "Palier 2 · tissu (mage, clerc)", &"spectral_tome": "Palier 2 · tissu (mage, clerc)",
	&"wraps_hood": "Palier 2 · tissu (mage, clerc)", &"spectral_robe": "Palier 2 · tissu (mage, clerc)",
	&"wraps_gloves": "Palier 2 · tissu (mage, clerc)", &"wraps_shoes": "Palier 2 · tissu (mage, clerc)",
	&"potion_mana": "Potions", &"potion_stamina": "Potions",
}


func category_of(recipe: Dictionary) -> String:
	return CATEGORIES.get(recipe["out"], "Matériaux")


func recipes_for(station: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r in RECIPES:
		if r["station"] == station:
			out.append(r)
	return out


func can_craft(recipe: Dictionary) -> bool:
	for id in recipe["in"]:
		if Town.amount_of(id) < int(recipe["in"][id]):
			return false
	return true


func craft(recipe: Dictionary) -> bool:
	if not can_craft(recipe):
		return false
	for id in recipe["in"]:
		Town.consume(id, int(recipe["in"][id]))
	var item := Inventory.item_by_id(recipe["out"])
	Inventory.add_item(item, int(recipe["n"]))
	# L'équipement d'une classe la débloque.
	for cls in Hero.CLASSES:
		if Hero.CLASSES[cls]["item"] == recipe["out"] and Hero.unlock(cls):
			Narration.say("Nouvelle classe débloquée : %s ! Changez de classe au feu de camp ou à la guilde." % Hero.CLASSES[cls]["name"], 4.0)
	return true


## Menu de l'atelier : au-delà de 10 recettes, on choisit d'abord une rubrique.
func open(station: StringName) -> void:
	var all := recipes_for(station)
	var cats: Array[String] = []
	for r in all:
		if not cats.has(category_of(r)):
			cats.append(category_of(r))
	if all.size() <= 10 or cats.size() <= 1:
		await _open_list(station, all, "Que fabriquer ?")
		return
	while true:
		var options: Array[String] = []
		for c in cats:
			var n := 0
			for r in all:
				if category_of(r) == c and can_craft(r):
					n += 1
			options.append("%s%s" % [c, "  (%d possible%s)" % [n, "s" if n > 1 else ""] if n > 0 else ""])
		options.append("Fermer")
		var i := await Choice.ask(STATION_NAMES.get(station, "Atelier"), "Quelle rubrique ?", options)
		if i < 0 or i >= cats.size():
			return
		var list: Array[Dictionary] = []
		for r in all:
			if category_of(r) == cats[i]:
				list.append(r)
		await _open_list(station, list, cats[i])


## Liste de recettes : on fabrique tant qu'on veut, puis « Retour » / « Fermer ».
func _open_list(station: StringName, list: Array[Dictionary], body: String) -> void:
	while true:
		var options: Array[String] = []
		for r in list:
			var item := Inventory.item_by_id(r["out"])
			var mark := "" if can_craft(r) else "  (manque)"
			options.append("%s ← %s%s" % [item.display_name, Building.cost_text(r["in"]), mark])
		options.append("Retour")
		var choice := await Choice.ask(STATION_NAMES.get(station, "Atelier"), body, options)
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
