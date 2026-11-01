class_name GuildRegistry
extends RefCounted
## Menus du registre de la guilde (fenêtres de choix) : membres, fiches, candidats du jour.
## Utilisés au feu de camp (palier Camp) puis dans la salle de la guilde (pupitre, tableau).


static func beds_text() -> String:
	return "Logements : %d / %d occupés (une tente loge 2 membres)." % [Roster.living().size(), Roster.capacity()]


## Liste des membres ; on choisit un membre pour voir sa fiche et agir.
static func open_members() -> void:
	while true:
		var list := Roster.living()
		var options: Array[String] = []
		for m in list:
			options.append("%s — %s (%s)" % [m["name"], Roster.specialty(m), Roster.state_text(m)])
		options.append("Fermer")
		var body := beds_text()
		if list.is_empty():
			body += "\nPersonne n'a encore rejoint la guilde. Des candidats se présentent chaque matin."
		var i := await Choice.ask("Registre de la guilde", body, options)
		if i < 0 or i >= list.size():
			return
		await member_sheet(int(list[i]["id"]))


static func member_sheet(id: int) -> void:
	while true:
		var m := Roster.by_id(id)
		if m.is_empty():
			return
		var options: Array[String] = []
		var actions: Array[String] = []
		if m["kind"] == "combat":
			options.append("Comportement au combat : %s" % Roster.STANCES.get(m["stance"], "Équilibré"))
			actions.append("stance")
		options.append("Renvoyer de la guilde")
		actions.append("dismiss")
		options.append("Retour")
		actions.append("back")
		var i := await Choice.ask(m["name"], Roster.sheet(m), options)
		if i < 0 or actions[i] == "back":
			return
		match actions[i]:
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
