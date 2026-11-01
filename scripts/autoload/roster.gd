extends Node
## Les membres de la guilde (voir GUILDE.md) : habitants recrutés et candidats du jour.
##
## Membre : {
##   "id": int, "name": String, "kind": "combat" | "artisan",
##   "cls": classe (combattants) ou "" ; "job": métier (artisans) ou "",
##   "levels": {classe: niveau}, "trait": String, "state": "ok" | "blessé" | "mort",
##   "rest": jours de repos restants, "stance": "agressif" | "equilibre" | "soins",
##   "gear": {emplacement: objet}, "day": jour d'arrivée
## }

signal changed

const NAMES := ["Aldric", "Brune", "Cassien", "Daëlle", "Edmond", "Faïna", "Garrick", "Hélis", "Iselde", "Joran",
	"Kaelis", "Lysandre", "Maëlis", "Néron", "Odalie", "Perrin", "Quentyn", "Rozenn", "Sorën", "Thessa",
	"Ulric", "Vanya", "Wilhelm", "Ysaline", "Zéphyr", "Anwen", "Bertrand", "Clothilde", "Darian", "Elowen",
	"Fennic", "Gwenaël", "Hadrien", "Ilona", "Jasper", "Katell", "Loïc", "Mireille", "Nolwenn", "Osric"]
const TRAITS := ["Courageux", "Prudent", "Bavard", "Taciturne", "Gourmand", "Matinal", "Rêveur", "Têtu",
	"Loyal", "Curieux", "Rieur", "Ancien soldat d'Elysia", "Exilé du Nord", "Ancien bandit repenti",
	"Fils de forgeron", "Fille de marchands", "Superstitieux", "Infatigable"]
## Métiers des artisans (leurs effets arrivent avec les étapes 4 et 5).
const JOBS := {
	&"forgeron": "Forgeron", &"fermier": "Fermier", &"bucheron": "Bûcheron",
	&"mineur": "Mineur", &"tisserand": "Tisserand", &"herboriste": "Herboriste",
}
const STANCES := {"agressif": "Agressif", "equilibre": "Équilibré", "soins": "Soins en premier"}
const CLASS_SPRITES := {
	&"warrior": "res://assets/sprites/guild/membre_guerrier/membre_guerrier",
	&"archer": "res://assets/sprites/guild/membre_archer/membre_archer",
	&"mage": "res://assets/sprites/guild/membre_mage/membre_mage",
	&"cleric": "res://assets/sprites/guild/membre_clerc/membre_clerc",
}
const ARTISAN_SPRITE := "res://assets/sprites/guild/artisan/artisan"

var members: Array[Dictionary] = []
var candidates: Array[Dictionary] = []
var _next_id := 1


func _ready() -> void:
	Game.new_morning.connect(_on_new_morning)


func reset() -> void:
	members.clear()
	candidates.clear()
	_next_id = 1
	changed.emit()


# ------------------------------------------------------------------ logements

## Places de logement : somme des bâtiments terminés (une tente loge 2 membres).
func capacity() -> int:
	var total := 0
	for record in Town.sites:
		if record["built"]:
			var data := Town.building(StringName(record["id"]))
			if data:
				total += data.housing
	return total


func living() -> Array[Dictionary]:
	return members.filter(func(m): return m["state"] != "mort")


func free_beds() -> int:
	return capacity() - living().size()


# ------------------------------------------------------------------ candidats

func _on_new_morning(_day: int) -> void:
	# Les candidats de la veille repartent ; 1 ou 2 nouveaux se présentent.
	candidates.clear()
	for i in randi_range(1, 2):
		candidates.append(make_candidate())
	# Les blessés se reposent.
	for m in members:
		if m["state"] == "blessé":
			m["rest"] = int(m["rest"]) - 1
			if int(m["rest"]) <= 0:
				m["state"] = "ok"
	changed.emit()
	if free_beds() > 0:
		Narration.say("%s à la guilde." % ("Un candidat attend" if candidates.size() == 1 else "Deux candidats attendent"), 3.0)


func make_candidate() -> Dictionary:
	var taken: Array = members.map(func(m): return m["name"]) + candidates.map(func(m): return m["name"])
	var name: String = NAMES[randi() % NAMES.size()]
	for i in 10:
		if not taken.has(name):
			break
		name = NAMES[randi() % NAMES.size()]
	var combat := randf() < 0.55
	var cls: StringName = Hero.ORDER[randi() % Hero.ORDER.size()] if combat else &""
	var job: StringName = JOBS.keys()[randi() % JOBS.size()] if not combat else &""
	var lvl := randi_range(1, 3)
	var m := {
		"id": 0, "name": name, "kind": "combat" if combat else "artisan",
		"cls": String(cls), "job": String(job), "levels": {String(cls): lvl} if combat else {},
		"job_level": lvl if not combat else 0,
		"trait": TRAITS[randi() % TRAITS.size()], "state": "ok", "rest": 0,
		"stance": "soins" if cls == &"cleric" else "equilibre", "gear": {}, "day": Game.day,
	}
	return m


func recruit(index: int) -> bool:
	if index < 0 or index >= candidates.size() or free_beds() <= 0:
		return false
	var m: Dictionary = candidates[index]
	candidates.remove_at(index)
	m["id"] = _next_id
	_next_id += 1
	m["day"] = Game.day
	members.append(m)
	changed.emit()
	return true


func dismiss(id: int) -> void:
	members = members.filter(func(m): return int(m["id"]) != id)
	changed.emit()


func by_id(id: int) -> Dictionary:
	for m in members:
		if int(m["id"]) == id:
			return m
	return {}


# ------------------------------------------------------------------ affichage

func specialty(m: Dictionary) -> String:
	if m["kind"] == "combat":
		return "%s niv. %d" % [Hero.CLASSES[StringName(m["cls"])]["name"], level_of(m)]
	return "%s niv. %d" % [JOBS.get(StringName(m["job"]), "Artisan"), int(m.get("job_level", 1))]


func level_of(m: Dictionary) -> int:
	return int(m["levels"].get(m["cls"], 1)) if m["kind"] == "combat" else int(m.get("job_level", 1))


func state_text(m: Dictionary) -> String:
	match m["state"]:
		"blessé":
			return "blessé (repos : %d j)" % int(m["rest"])
		"mort":
			return "mort"
	return "en forme"


## Fiche complète d'un membre (ou d'un candidat).
func sheet(m: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("%s — %s" % [m["name"], specialty(m)])
	lines.append("Trait : %s." % m["trait"])
	if m["kind"] == "combat":
		var info: Dictionary = Hero.CLASSES[StringName(m["cls"])]
		lines.append("Combattant : %s" % info["role"])
		lines.append("Comportement au combat : %s." % STANCES.get(m["stance"], "Équilibré"))
	else:
		lines.append("Artisan : son métier servira quand la ville grandira (ateliers, champs…).")
	if int(m["id"]) > 0:
		lines.append("État : %s · arrivé le jour %d." % [state_text(m), int(m["day"])])
	return "\n".join(lines)


func sprite_path(m: Dictionary) -> String:
	return CLASS_SPRITES.get(StringName(m["cls"]), ARTISAN_SPRITE) if m["kind"] == "combat" else ARTISAN_SPRITE


# ------------------------------------------------------------------ sauvegarde

func serialize() -> Dictionary:
	return {"members": members.duplicate(true), "candidates": candidates.duplicate(true), "next_id": _next_id}


func deserialize(data: Dictionary) -> void:
	members.clear()
	candidates.clear()
	for m in data.get("members", []):
		members.append(m)
	for m in data.get("candidates", []):
		candidates.append(m)
	_next_id = int(data.get("next_id", members.size() + 1))
	changed.emit()
