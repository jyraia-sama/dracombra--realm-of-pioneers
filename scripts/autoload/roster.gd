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
	&"bucheron": "Bûcheron", &"mineur": "Mineur", &"chasseur": "Chasseur", &"herboriste": "Herboriste",
	&"forgeron": "Forgeron", &"fermier": "Fermier", &"tisserand": "Tisserand",
}
## Bâtiment de travail de chaque métier (vide = pas encore de bâtiment : forge sur commande,
## champs de l'étape 5, atelier de tissage plus tard).
const WORKPLACE := {&"bucheron": &"lumber_hut", &"mineur": &"quarry", &"chasseur": &"hunter_cabin",
	&"herboriste": &"herb_garden"}
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
## Le groupe d'aventure : identifiants des 2 compagnons (au plus) qui suivent le héros.
var party: Array[int] = []
const PARTY_SIZE := 2
var _next_id := 1


func _ready() -> void:
	Game.new_morning.connect(_on_new_morning)


func reset() -> void:
	members.clear()
	candidates.clear()
	party.clear()
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
	# Les artisans sans travail rejoignent un bâtiment de leur métier terminé entre-temps.
	for m in living():
		auto_assign(m)
	_produce()
	# Une nuit de repos : PV au maximum ; les blessés se reposent.
	for m in members:
		m["hp"] = 0
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
	# Tous les arrivants sont des villageois avec un métier ; on les forme ensuite au
	# combat à la guilde (voir ECONOMIE.md).
	var combat := false
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
	auto_assign(m)
	changed.emit()
	return true


func dismiss(id: int) -> void:
	members = members.filter(func(m): return int(m["id"]) != id)
	party.erase(id)
	changed.emit()


# ------------------------------------------------------------------ le groupe

func party_members() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in party:
		var m := by_id(id)
		if not m.is_empty() and m["state"] != "mort":
			out.append(m)
	return out


func set_party_slot(slot: int, id: int) -> void:
	party.erase(id)
	while party.size() <= slot:
		party.append(0)
	party[slot] = id
	party = party.filter(func(x): return x > 0)
	changed.emit()


## XP gagnée par le héros : les compagnons présents la gagnent aussi (classe actuelle).
func share_xp(amount: int) -> void:
	for m in party_members():
		var cls: String = m["cls"]
		var lvl := int(m["levels"].get(cls, 1))
		if lvl >= Hero.MAX_LEVEL:
			continue
		m["xp"] = int(m.get("xp", 0)) + amount
		while lvl < Hero.MAX_LEVEL and int(m["xp"]) >= Hero.xp_to_next(lvl):
			m["xp"] = int(m["xp"]) - Hero.xp_to_next(lvl)
			lvl += 1
			m["levels"][cls] = lvl
			Narration.say("%s passe niveau %d !" % [m["name"], lvl], 2.0)


## PV max d'un compagnon : comme le héros (10 + VIT / 2), avec la VIT de sa classe à son niveau.
func max_hp(m: Dictionary) -> int:
	return 10 + stat(m, &"vit") / 2 + int(gear_bonus(m, &"vit")) / 2


func stat(m: Dictionary, key: StringName) -> int:
	var info: Dictionary = Hero.CLASSES[StringName(m["cls"])]
	var lvl := int(m["levels"].get(m["cls"], 1))
	return int(info["stats"][key]) + int(floor(float(info["growth"][key]) * (lvl - 1)))


## Dégâts d'un coup : dégâts de la classe + 1 tous les 5 points de la caractéristique principale.
func damage(m: Dictionary) -> int:
	var info: Dictionary = Hero.CLASSES[StringName(m["cls"])]
	var main: StringName = info["main"]
	var gain := maxi(stat(m, main) - int(info["stats"][main]), 0)
	return int(info["damage"]) + gain / 5 + gear_bonus(m, &"dmg")


func gear_bonus(m: Dictionary, key: StringName) -> int:
	var total := 0
	for slot in m.get("gear", {}):
		var item := Inventory.item_by_id(StringName(m["gear"][slot]))
		if item and (item.classes.is_empty() or item.classes.has(StringName(m["cls"]))):
			total += int(item.bonus.get(key, 0))
	return total


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
		var want: StringName = WORKPLACE.get(StringName(m["job"]), &"")
		var work := Town.site_by_uid(int(m.get("work", 0)))
		if not work.is_empty():
			lines.append("Travaille à : %s." % Town.building(StringName(work["id"])).display_name)
		elif want != &"":
			lines.append("Sans travail : construisez un bâtiment « %s »." % Town.building(want).display_name)
		else:
			lines.append("Son métier servira bientôt (forge sur commande, champs, atelier de tissage).")
	if int(m["id"]) > 0:
		lines.append("État : %s · arrivé le jour %d." % [state_text(m), int(m["day"])])
	return "\n".join(lines)


func sprite_path(m: Dictionary) -> String:
	return CLASS_SPRITES.get(StringName(m["cls"]), ARTISAN_SPRITE) if m["kind"] == "combat" else ARTISAN_SPRITE


# ------------------------------------------------------------------ sauvegarde

func serialize() -> Dictionary:
	return {"members": members.duplicate(true), "candidates": candidates.duplicate(true), "next_id": _next_id,
		"party": party.duplicate()}


func deserialize(data: Dictionary) -> void:
	members.clear()
	candidates.clear()
	for m in data.get("members", []):
		members.append(m)
	for m in data.get("candidates", []):
		candidates.append(m)
	_next_id = int(data.get("next_id", members.size() + 1))
	party.clear()
	for id in data.get("party", []):
		party.append(int(id))
	changed.emit()


# ------------------------------------------------------------------ compagnons dans les niveaux

## Fait apparaître les compagnons du groupe près du héros (appelé par Level._ready).
func spawn_party(level: Node2D, player: Node2D) -> void:
	if not Game.has_flag(&"prologue_done") or player == null or level.has_method("is_guild_hall"):
		return
	var slot := 0
	for m in party_members():
		var c := Companion.create(m, slot)
		c.position = player.global_position + Vector2(-18 if slot == 0 else 18, 10)
		level.add_child.call_deferred(c)
		slot += 1


## Retour en ville : ceux qui sont tombés sont blessés (2 jours de repos).
func settle_after_outing() -> void:
	var hurt: Array[String] = []
	for m in members:
		if m.get("fell", false):
			m["fell"] = false
			if m["state"] != "mort":
				m["state"] = "blessé"
				m["rest"] = 2
				hurt.append(m["name"])
	if not hurt.is_empty():
		changed.emit()
		Narration.say("%s doi%s se reposer (blessé%s, 2 jours)." % [", ".join(hurt), "t" if hurt.size() == 1 else "vent",
			"" if hurt.size() == 1 else "s"], 4.0)


# ------------------------------------------------------------------ métiers et production

## Les travailleurs d'un bâtiment (site de Town.sites).
func workers_of(uid: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for m in living():
		if int(m.get("work", 0)) == uid:
			out.append(m)
	return out


## Place un artisan dans le premier bâtiment de son métier qui a de la place.
func auto_assign(m: Dictionary) -> bool:
	if m["kind"] != "artisan" or int(m.get("work", 0)) > 0:
		return false
	var want: StringName = WORKPLACE.get(StringName(m["job"]), &"")
	if want == &"":
		return false
	for r in Town.sites:
		if r["built"] and StringName(r["id"]) == want:
			var data := Town.building(want)
			if workers_of(int(r["uid"])).size() < data.workers:
				m["work"] = int(r["uid"])
				return true
	return false


func assign(m: Dictionary, uid: int) -> void:
	m["work"] = uid
	changed.emit()


func unassign(m: Dictionary) -> void:
	m["work"] = 0
	changed.emit()


## Chaque matin, les bâtiments de travail produisent selon leurs travailleurs en forme.
func _produce() -> void:
	var total := {}
	for r in Town.sites:
		if not r["built"]:
			continue
		var data := Town.building(StringName(r["id"]))
		if data == null or data.job == &"" or data.produces.is_empty():
			continue
		var stock: Dictionary = r.get("stock", {})
		for m in workers_of(int(r["uid"])):
			if m["state"] != "ok":
				continue
			var skill := 1.0 + 0.2 * (int(m.get("job_level", 1)) - 1)
			for id in data.produces:
				var n := int(round(float(data.produces[id]) * skill))
				var before := int(stock.get(String(id), 0))
				var after := mini(data.stock_cap, before + n)
				stock[String(id)] = after
				total[id] = int(total.get(id, 0)) + (after - before)
			# La carrière donne parfois une gemme.
			if data.id == &"quarry" and randf() < 0.12:
				stock["gem"] = mini(data.stock_cap, int(stock.get("gem", 0)) + 1)
				total[&"gem"] = int(total.get(&"gem", 0)) + 1
		r["stock"] = stock
	if total.is_empty():
		return
	Town.changed.emit()
	Narration.say("Production de la nuit : %s." % Building.cost_text(total), 3.5)


## Fait apparaître l'artisan près de son lieu de travail (rectangle autour du bâtiment), ou {}.
func work_area(m: Dictionary) -> Rect2:
	var r := Town.site_by_uid(int(m.get("work", 0)))
	if r.is_empty():
		return Rect2()
	var data := Town.building(StringName(r["id"]))
	var rect := Building.footprint_rect(data, Town.site_cell(r))
	var t := float(Game.TILE_SIZE)
	return Rect2(rect.position + Vector2(-t * 2, rect.size.y), Vector2(rect.size.x + t * 4, t * 3))
