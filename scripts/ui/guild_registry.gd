class_name GuildRegistry
extends RefCounted
## Menus du registre de la guilde (fenêtres de choix) : membres, fiches, candidats du jour.
## Utilisés au feu de camp (palier Camp) puis dans la salle de la guilde (pupitre, tableau).


static func party_text() -> String:
	var names: Array[String] = []
	for m in Roster.party_members():
		names.append("%s (%s)" % [m["name"], Roster.specialty(m)])
	return "Groupe d'aventure : %s." % (", ".join(names) if not names.is_empty() else "personne, le héros part seul")


## Composer le groupe : 2 places, des combattants vivants. Partir blessé est risqué.
static func open_party() -> void:
	while true:
		var current := Roster.party_members()
		var options: Array[String] = []
		for slot in Roster.PARTY_SIZE:
			var label := "— libre —"
			if slot < current.size():
				var m: Dictionary = current[slot]
				label = "%s — %s (%s)" % [m["name"], Roster.specialty(m), Roster.state_text(m)]
			options.append("Place %d : %s" % [slot + 1, label])
		options.append("Fermer")
		var body := "Deux compagnons suivent le héros et combattent selon leur comportement (registre).\nUn compagnon blessé qui tombe à nouveau meurt."
		var i := await Choice.ask("Groupe d'aventure", body, options)
		if i < 0 or i >= Roster.PARTY_SIZE:
			return
		var pool: Array[Dictionary] = []
		var labels: Array[String] = []
		for m in Roster.living():
			if m["kind"] != "combat" or Roster.party.has(int(m["id"])) or not Roster.has_weapon(m):
				continue
			pool.append(m)
			labels.append("%s — %s%s" % [m["name"], Roster.specialty(m), "  ⚠ blessé" if m["state"] == "blessé" else ""])
		if i < current.size():
			labels.append("Retirer %s du groupe" % current[i]["name"])
		labels.append("Retour")
		var j := await Choice.ask("Place %d" % (i + 1), "Choisir un combattant de la guilde (avec une arme)." if not pool.is_empty() else "Aucun combattant armé disponible. Formez un villageois au combat (registre), ou équipez une arme à un combattant.", labels)
		if j < 0:
			continue
		if j < pool.size():
			var chosen: Dictionary = pool[j]
			if chosen["state"] == "blessé":
				var k := await Choice.ask("%s est blessé" % chosen["name"], "S'il tombe encore au combat, il mourra. L'emmener quand même ?", ["L'emmener", "Annuler"])
				if k != 0:
					continue
			if i < current.size():
				Roster.party.erase(int(current[i]["id"]))
			Roster.party.append(int(chosen["id"]))
			Roster.changed.emit()
		elif i < current.size() and j == pool.size():
			Roster.party.erase(int(current[i]["id"]))
			Roster.changed.emit()


static func beds_text() -> String:
	return "Logements : %d / %d occupés (une tente loge 2 membres)." % [Roster.living().size(), Roster.capacity()]


## Liste des membres ; on choisit un membre pour voir sa fiche et agir.
static func open_members() -> void:
	while true:
		var list := Roster.living()
		var options: Array[String] = ["Groupe d'aventure…"]
		for m in list:
			options.append("%s — %s (%s)%s" % [m["name"], Roster.specialty(m), Roster.state_text(m),
				"  · groupe" if Roster.party.has(int(m["id"])) else ""])
		options.append("Fermer")
		var body := "%s\n%s" % [beds_text(), party_text()]
		if list.is_empty():
			body += "\nPersonne n'a encore rejoint la guilde. Des candidats se présentent chaque matin."
		var i := await Choice.ask("Registre de la guilde", body, options)
		if i == 0:
			await open_party()
			continue
		if i < 1 or i > list.size():
			return
		await member_sheet(int(list[i - 1]["id"]))


static func member_sheet(id: int) -> void:
	while true:
		var m := Roster.by_id(id)
		if m.is_empty():
			return
		var options: Array[String] = []
		var actions: Array[String] = []
		if m["kind"] == "combat":
			options.append("Équipement…")
			actions.append("gear")
			options.append("Comportement au combat : %s" % Roster.STANCES.get(m["stance"], "Équilibré"))
			actions.append("stance")
			options.append("Revenir à son métier (%s)" % String(Roster.JOBS.get(StringName(m.get("job", "")), "villageois")).to_lower())
			actions.append("back_to_work")
		else:
			options.append("Former au combat…")
			actions.append("train")
		options.append("Renvoyer de la guilde")
		actions.append("dismiss")
		options.append("Retour")
		actions.append("back")
		var i := await Choice.ask(m["name"], Roster.sheet(m), options)
		if i < 0 or actions[i] == "back":
			return
		match actions[i]:
			"gear":
				await _member_gear(m)
			"train":
				await _train(m)
			"back_to_work":
				var k := await Choice.ask("Revenir au métier ?", "%s rend son équipement (il revient dans votre sac) et reprend son métier. Ses niveaux de combat sont gardés." % m["name"], ["Confirmer", "Annuler"])
				if k == 0:
					Roster.back_to_work(m)
					Narration.say("%s reprend son métier." % m["name"], 2.0)
			"stance":
				var keys := Roster.STANCES.keys()
				var labels: Array[String] = []
				for k in keys:
					labels.append(Roster.STANCES[k])
				labels.append("Retour")
				var j := await Choice.ask("Comportement de %s" % m["name"],
					"Agressif : attaque l'ennemi le plus proche sans se ménager.\nÉquilibré : attaque, mais se met à l'abri quand il est blessé.\nSoins en premier : soigne le groupe avant d'attaquer (surtout utile pour un clerc).", labels)
				if j >= 0 and j < keys.size():
					m["stance"] = keys[j]
					Roster.changed.emit()
			"dismiss":
				var k := await Choice.ask("Renvoyer %s ?" % m["name"], "%s quittera Dracombra pour de bon." % m["name"], ["Renvoyer", "Annuler"])
				if k == 0:
					Roster.dismiss(id)
					Narration.say("%s a quitté la guilde." % m["name"], 2.0)
					return


## Former un villageois : choisir la classe, puis l'arme (prise dans le sac).
static func _train(m: Dictionary) -> void:
	var classes: Array = Hero.ORDER
	var opts: Array[String] = []
	for cls in classes:
		var n := Roster.weapons_in_bag(cls).size()
		var base := Inventory.item_by_id(Roster.CLASS_WEAPONS[cls])
		opts.append("%s — %s" % [Hero.CLASSES[cls]["name"], "%d arme%s dans le sac" % [n, "s" if n > 1 else ""] if n > 0 else "il faut : %s (ou une arme de la classe)" % base.display_name])
	opts.append("Retour")
	var bonus: Array = Roster.ORIGIN_BONUS.get(StringName(m.get("job", "")), [])
	var body := "%s quitte son métier et devient combattant. Il lui faut l'arme de sa classe (prise dans votre sac)." % m["name"]
	if not bonus.is_empty():
		body += "\nSon passé de %s lui donne +%d %s." % [String(Roster.JOBS.get(StringName(m["job"]), "")).to_lower(), int(bonus[1]), Hero.STAT_NAMES[bonus[0]]]
	var i := await Choice.ask("Former %s au combat" % m["name"], body, opts)
	if i < 0 or i >= classes.size():
		return
	var cls: StringName = classes[i]
	var weapons := Roster.weapons_in_bag(cls)
	if weapons.is_empty():
		Narration.say("Il faut d'abord fabriquer l'arme : %s (établi)." % Inventory.item_by_id(Roster.CLASS_WEAPONS[cls]).display_name, 3.0)
		return
	var wopts: Array[String] = []
	for w in weapons:
		wopts.append(Loot.label(w))
	wopts.append("Retour")
	var j := await Choice.ask("Arme de %s" % m["name"], "Quelle arme lui donner ?", wopts)
	if j < 0 or j >= weapons.size():
		return
	if Roster.train(m, cls, weapons[j]):
		Narration.say("%s devient %s !" % [m["name"], String(Hero.CLASSES[cls]["name"]).to_lower()], 3.0)


## Équipement d'un membre : chaque emplacement, objets du sac qui lui conviennent.
static func _member_gear(m: Dictionary) -> void:
	while true:
		var cls := StringName(m["cls"])
		var gear: Dictionary = m.get("gear", {})
		var opts: Array[String] = []
		for slot in Hero.GEAR_SLOTS:
			var it := Inventory.item_by_id(StringName(gear.get(String(slot), "")))
			opts.append("%s : %s" % [Hero.GEAR_NAMES[slot], Loot.label(it) if it else "—"])
		opts.append("Retour")
		var i := await Choice.ask("Équipement de %s" % m["name"], "Les objets viennent de votre sac et y reviennent quand on les retire.\nPV %d · dégâts %d" % [Roster.max_hp(m), Roster.damage(m)], opts)
		if i < 0 or i >= Hero.GEAR_SLOTS.size():
			return
		var slot: StringName = Hero.GEAR_SLOTS[i]
		var items: Array[ItemData] = []
		var labels: Array[String] = []
		for item in Inventory.get_items():
			var fits := Roster.weapon_fits(item, cls) if slot == &"main" else \
				(item.slot == slot and (item.classes.is_empty() or item.classes.has(cls)))
			if fits:
				items.append(item)
				labels.append("Équiper : %s  %s" % [Loot.label(item), GameMenu.bonus_text(item, true)])
		var has := gear.has(String(slot))
		if has:
			labels.append("Retirer")
		labels.append("Retour")
		var j := await Choice.ask(Hero.GEAR_NAMES[slot], "Rien dans le sac pour cet emplacement." if items.is_empty() else "Choisir un objet.", labels)
		if j < 0:
			continue
		if j < items.size():
			Roster.equip_member(m, items[j])
		elif has and j == items.size():
			Roster.unequip_member(m, slot)


## Candidats du jour : fiche et recrutement (gratuit s'il reste une place).
static func open_candidates() -> void:
	while true:
		var list := Roster.candidates
		var options: Array[String] = []
		for m in list:
			options.append("%s — %s · %s" % [m["name"], Roster.specialty(m), m["trait"]])
		options.append("Fermer")
		var body := beds_text()
		if list.is_empty():
			body += "\nAucun candidat aujourd'hui. Revenez demain matin."
		elif Roster.free_beds() <= 0:
			body += "\nPlus de place : construisez une tente pour accueillir quelqu'un."
		var i := await Choice.ask("Candidats du jour", body, options)
		if i < 0 or i >= list.size():
			return
		var m: Dictionary = list[i]
		var opts := ["Recruter %s" % m["name"], "Retour"] if Roster.free_beds() > 0 else ["Retour (plus de place)"]
		var j := await Choice.ask(m["name"], Roster.sheet(m), opts)
		if j == 0 and Roster.free_beds() > 0:
			var name: String = m["name"]
			if Roster.recruit(i):
				Narration.say("%s rejoint la guilde !" % name, 2.5)
