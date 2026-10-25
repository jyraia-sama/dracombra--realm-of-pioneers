extends Node
## Les quêtes guidées d'Ysolde, l'herboriste qui a recueilli le héros : elles servent
## de tutoriel (récolte, construction, artisanat, nuits, guilde).
## L'objectif en cours s'affiche à l'écran. Certaines étapes se valident en parlant à Ysolde.

signal step_changed(step: int)

## Chaque étape : titre, texte d'aide, condition (méthode de ce script), cible,
## talk = il faut ensuite aller parler à Ysolde pour valider.
const STEPS: Array[Dictionary] = [
	{"title": "Parler à Ysolde", "hint": "Elle se tient près du feu de camp.", "check": "", "talk": true},
	{"title": "Cueillir des herbes médicinales", "hint": "Frappez les buissons et les hautes herbes.", "check": "has_items", "items": {&"herb": 3}, "talk": false},
	{"title": "Ramasser du bois et de la pierre", "hint": "Frappez un arbre et des décombres. Sans outil, c'est long !", "check": "has_items", "items": {&"wood": 6, &"stone": 5}, "talk": true},
	{"title": "Fabriquer une hache et une pioche", "hint": "Au feu de camp (E) : « Fabriquer des outils ».", "check": "has_items", "items": {&"axe": 1, &"pickaxe": 1}, "talk": true},
	{"title": "Réunir de quoi bâtir", "hint": "Avec la hache et la pioche, tout va deux fois plus vite.", "check": "has_items", "items": {&"wood": 18, &"stone": 6}, "talk": false},
	{"title": "Construire une tente", "hint": "B pour construire, posez la tente, E pour y déposer les matériaux, puis dormez au feu de camp.", "check": "built", "building": &"tent", "n": 1, "talk": false},
	{"title": "Construire un établi", "hint": "B pour construire. Il faut du bois et de la pierre.", "check": "built", "building": &"workbench", "n": 1, "talk": true},
	{"title": "Fabriquer un baume de soin", "hint": "À l'établi : 3 herbes médicinales donnent un baume.", "check": "has_items", "items": {&"balm": 1}, "talk": true},
	{"title": "Élever la guilde au rang de Village", "hint": "Parlez à la guilde (le feu de camp) pour voir ce qu'il faut.", "check": "tier", "n": 1, "talk": true},
]

## Étape en cours (STEPS.size() = tout est terminé).
var step: int = 0
## La condition de l'étape est remplie, il reste à parler à Ysolde.
var ready_to_report := false


func reset() -> void:
	step = 0
	ready_to_report = false
	step_changed.emit(step)


func active() -> bool:
	return Game.has_flag(&"prologue_done") and step < STEPS.size()


func current() -> Dictionary:
	return STEPS[step] if step < STEPS.size() else {}


## Texte affiché à l'écran.
func objective_text() -> String:
	if not active():
		return ""
	var s := current()
	var text := "Objectif : %s" % s["title"]
	var progress := _progress(s)
	if progress != "":
		text += " (%s)" % progress
	if ready_to_report:
		text = "Objectif : retourner voir Ysolde"
	return text


func _progress(s: Dictionary) -> String:
	match s["check"]:
		"has_items":
			var parts: Array[String] = []
			for id in s["items"]:
				var item := Inventory.item_by_id(id)
				parts.append("%s %d / %d" % [item.display_name.to_lower() if item else String(id), mini(Inventory.get_count(id), s["items"][id]), s["items"][id]])
			return ", ".join(parts)
		"built":
			return "%d / %d" % [mini(Town.count_built(s["building"]), s["n"]), s["n"]]
	return ""


func _met(s: Dictionary) -> bool:
	match s["check"]:
		"has_items":
			for id in s["items"]:
				if Inventory.get_count(id) < int(s["items"][id]):
					return false
			return true
		"built":
			return Town.count_built(s["building"]) >= int(s["n"])
		"tier":
			return Town.tier >= int(s["n"])
	return false


func _process(_delta: float) -> void:
	if not active() or ready_to_report:
		return
	var s := current()
	if s["check"] == "" or not _met(s):
		return
	if s["talk"]:
		ready_to_report = true
		Narration.say("Objectif accompli : %s. Retournez voir Ysolde." % s["title"], 3.0)
		step_changed.emit(step)
	else:
		Narration.say("Objectif accompli : %s." % s["title"], 2.4)
		advance()


## Ysolde valide l'étape (appelé depuis son dialogue).
## XP gagnée à chaque étape accomplie.
const STEP_XP := 6


func advance() -> void:
	if step > 0:
		Hero.gain_xp(STEP_XP)
	step += 1
	ready_to_report = false
	step_changed.emit(step)
	Save.save_game()


func serialize() -> Dictionary:
	return {"step": step, "ready": ready_to_report}


func deserialize(data: Dictionary) -> void:
	step = int(data.get("step", 0))
	ready_to_report = bool(data.get("ready", false))
	step_changed.emit(step)
