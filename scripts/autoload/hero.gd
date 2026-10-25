extends Node
## La fiche du héros : son nom (le pseudo du joueur), sa classe, et un niveau par classe
## (jusqu'au niveau 100). Chaque classe a ses caractéristiques, ses points à répartir et
## ses techniques ou sorts (voir SkillBook).
## On change de classe en fabriquant son équipement, puis seulement à Dracombra (au feu de
## camp ou à la guilde), jamais en pleine nature.

signal class_changed(id: StringName)
signal xp_changed(id: StringName, level: int, xp: int)
signal leveled_up(id: StringName, level: int)
signal stats_changed
signal skill_learned(id: StringName)
signal energy_changed(current: float, maximum: float)

## Niveau maximum de chaque classe (à ajuster plus tard).
const MAX_LEVEL := 100
## Points de caractéristiques gagnés à chaque niveau, à répartir dans la fiche.
const POINTS_PER_LEVEL := 2
## Les caractéristiques : FOR (force), DEX (dextérité), INT (intelligence), SAG (sagesse), VIT (vitalité).
const STATS: Array[StringName] = [&"str", &"dex", &"int", &"wis", &"vit"]
const STAT_NAMES := {&"str": "Force", &"dex": "Dextérité", &"int": "Intelligence", &"wis": "Sagesse", &"vit": "Vitalité"}
const STAT_SHORT := {&"str": "FOR", &"dex": "DEX", &"int": "INT", &"wis": "SAG", &"vit": "VIT"}
const STAT_HELP := {
	&"str": "Dégâts du guerrier et du clerc.",
	&"dex": "Dégâts de l'archer, coups critiques, parade.",
	&"int": "Dégâts et mana du mage.",
	&"wis": "Mana du clerc, récupération d'endurance et de mana.",
	&"vit": "PV max, défense, parade.",
}

## Les classes de base. attack : melee (épée, masse), arrow (flèches), bolt (projectile magique).
## stats : valeurs au niveau 1 ; growth : gain par niveau. main : la caractéristique qui fait
## les dégâts ; resource : endurance (techniques) ou mana (sorts), et la caractéristique qui la nourrit.
const CLASSES: Dictionary = {
	&"warrior": {"name": "Guerrier", "role": "Corps à corps. Encaisse les coups.", "attack": "melee",
		"damage": 1, "cooldown": 0.0, "item": &"", "tint": Color(1, 1, 1), "icon": 272,
		"stats": {&"str": 5, &"dex": 3, &"int": 1, &"wis": 2, &"vit": 5},
		"growth": {&"str": 0.6, &"dex": 0.3, &"int": 0.1, &"wis": 0.2, &"vit": 0.6},
		"main": &"str", "resource": "Endurance", "res_stat": &"vit", "skill_word": "Techniques",
		"sheet": "res://assets/sprites/hero/warrior.png"},
	&"archer": {"name": "Archer", "role": "Tire des flèches à distance. Fragile au contact.", "attack": "arrow",
		"damage": 1, "cooldown": 0.35, "item": &"bow", "tint": Color(1, 1, 1), "icon": 224,
		"stats": {&"str": 3, &"dex": 6, &"int": 2, &"wis": 2, &"vit": 3},
		"growth": {&"str": 0.3, &"dex": 0.7, &"int": 0.2, &"wis": 0.2, &"vit": 0.4},
		"main": &"dex", "resource": "Endurance", "res_stat": &"dex", "skill_word": "Techniques",
		"sheet": "res://assets/sprites/hero/archer.png"},
	&"mage": {"name": "Mage", "role": "Projectiles de mana lents mais puissants.", "attack": "bolt",
		"damage": 2, "cooldown": 0.7, "item": &"staff", "tint": Color(0.82, 0.85, 1.25), "icon": 240,
		"stats": {&"str": 1, &"dex": 3, &"int": 6, &"wis": 4, &"vit": 2},
		"growth": {&"str": 0.1, &"dex": 0.3, &"int": 0.8, &"wis": 0.4, &"vit": 0.3},
		"main": &"int", "resource": "Mana", "res_stat": &"int", "skill_word": "Sorts"},
	&"cleric": {"name": "Clerc", "role": "Frappe à la masse et referme lentement ses blessures.", "attack": "melee",
		"damage": 1, "cooldown": 0.0, "item": &"holy_symbol", "tint": Color(1.15, 1.08, 0.8), "icon": 256,
		"stats": {&"str": 4, &"dex": 2, &"int": 3, &"wis": 6, &"vit": 4},
		"growth": {&"str": 0.4, &"dex": 0.2, &"int": 0.3, &"wis": 0.7, &"vit": 0.5},
		"main": &"str", "resource": "Mana", "res_stat": &"wis", "skill_word": "Sorts",
		"regen": 8.0},
}
const ORDER: Array[StringName] = [&"warrior", &"archer", &"mage", &"cleric"]
## Nombre d'emplacements de techniques dans la barre (touches R, F, C).
const SKILL_SLOTS := 3
## XP rapportée par chaque ennemi vaincu.
const KILL_XP := {&"Slime": 2, &"RockGoblin": 4, &"ObsidianSpider": 3, &"Boar": 3}

var hero_name: String = "Heros"
var current: StringName = &"warrior"
var unlocked: Array[StringName] = [&"warrior"]
var levels: Dictionary = {&"warrior": 1}
var xp: Dictionary = {&"warrior": 0}
## Points répartis par classe : {classe: {stat: points}}.
var points: Dictionary = {}
## Points pas encore répartis, par classe.
var unspent: Dictionary = {}
## Techniques placées dans la barre, par classe : {classe: [id, id, id]}.
var equipped: Dictionary = {}
## Endurance ou mana actuelle (remplie à chaque chargement).
var energy: float = 0.0
## Effets temporaires : {stat: [valeur, fin en ms]}.
var _buffs: Dictionary = {}


func reset() -> void:
	current = &"warrior"
	unlocked = [&"warrior"]
	levels = {&"warrior": 1}
	xp = {&"warrior": 0}
	points = {}
	unspent = {}
	equipped = {}
	_buffs.clear()
	_auto_equip(&"warrior")
	energy = energy_max()


func info(id: StringName = &"") -> Dictionary:
	return CLASSES[current if id == &"" else id]


func level(id: StringName = &"") -> int:
	return int(levels.get(current if id == &"" else id, 1))


## XP nécessaire pour passer au niveau suivant (0 au niveau maximum).
func xp_to_next(lvl: int) -> int:
	if lvl >= MAX_LEVEL:
		return 0
	return int(round(8.0 * pow(float(lvl), 1.6)))


# ------------------------------------------------------------------ caractéristiques

## Valeur d'une caractéristique : base de la classe + croissance par niveau + points répartis.
func stat(key: StringName, cls: StringName = &"") -> int:
	var c := current if cls == &"" else cls
	var data: Dictionary = CLASSES[c]
	var base := float(data["stats"][key]) + float(data["growth"][key]) * (level(c) - 1)
	return int(floor(base)) + allocated(key, c)


func allocated(key: StringName, cls: StringName = &"") -> int:
	var c := current if cls == &"" else cls
	return int(points.get(c, {}).get(key, 0))


func free_points(cls: StringName = &"") -> int:
	return int(unspent.get(current if cls == &"" else cls, 0))


## Dépense un point de caractéristique de la classe actuelle.
func spend_point(key: StringName) -> bool:
	if free_points() <= 0 or not STATS.has(key):
		return false
	unspent[current] = free_points() - 1
	if not points.has(current):
		points[current] = {}
	points[current][key] = allocated(key) + 1
	_refresh_player(false)
	stats_changed.emit()
	return true


## Rend tous les points répartis de la classe actuelle (pour les redistribuer).
func reset_points() -> void:
	var total := 0
	for k in points.get(current, {}):
		total += int(points[current][k])
	points[current] = {}
	unspent[current] = free_points() + total
	_refresh_player(false)
	stats_changed.emit()


## PV max : pendant le prologue, ceux du capitaine ; ensuite 10 + VIT / 2.
func max_hp() -> int:
	if not Game.has_flag(&"prologue_done"):
		return Game.hero_max_health()
	return Game.hero_max_health() + stat(&"vit") / 2


## Ancien calcul gardé pour compatibilité : le bonus de PV au-delà de la base.
func hp_bonus() -> int:
	return max_hp() - Game.hero_max_health()


## Dégâts de base de l'arme : ceux de la classe, +1 tous les 5 points gagnés dans la
## caractéristique principale.
func damage() -> int:
	var data := info()
	var main: StringName = data["main"]
	var gain := maxi(stat(main) - int(data["stats"][main]), 0)
	return int(data["damage"]) + gain / 5


## Dégâts d'un coup, effets temporaires compris. crit : le coup est-il critique ?
func hit_damage(mult: float = 1.0, crit: bool = false) -> int:
	var d := float(damage()) * mult * buff(&"damage", 1.0)
	if crit:
		d *= 2.0
	return maxi(int(round(d)), 1)


## Réduction des dégâts reçus (toujours au moins 1 dégât).
func defense() -> int:
	return stat(&"vit") / 10


## Chance de parer complètement un coup, en %.
func parry_chance() -> float:
	return minf(25.0, stat(&"dex") * 0.25 + stat(&"vit") * 0.1)


## Chance de coup critique (double dégâts), en %.
func crit_chance() -> float:
	return minf(60.0, 2.0 + stat(&"dex") * 0.4 + buff(&"crit", 0.0))


func roll_crit() -> bool:
	return randf() * 100.0 < crit_chance()


func energy_max() -> float:
	return 10.0 + 2.0 * stat(info()["res_stat"])


## Endurance ou mana récupérée par seconde.
func energy_regen() -> float:
	return 1.0 + stat(&"wis") * 0.1


func use_energy(amount: float) -> bool:
	if energy < amount:
		return false
	energy -= amount
	energy_changed.emit(energy, energy_max())
	return true


func regen_energy(delta: float) -> void:
	var top := energy_max()
	if energy >= top:
		energy = top
		return
	energy = minf(energy + energy_regen() * delta, top)
	energy_changed.emit(energy, top)


# ------------------------------------------------------------------ effets temporaires

func add_buff(key: StringName, value: float, duration: float) -> void:
	_buffs[key] = [value, Time.get_ticks_msec() + int(duration * 1000.0)]
	stats_changed.emit()


func buff(key: StringName, default: float) -> float:
	if not _buffs.has(key):
		return default
	if Time.get_ticks_msec() > int(_buffs[key][1]):
		_buffs.erase(key)
		return default
	return float(_buffs[key][0])


func buff_time_left(key: StringName) -> float:
	if not _buffs.has(key):
		return 0.0
	return maxf((int(_buffs[key][1]) - Time.get_ticks_msec()) / 1000.0, 0.0)


func clear_buffs() -> void:
	_buffs.clear()


# ------------------------------------------------------------------ techniques et sorts

## Techniques connues par une classe à son niveau actuel.
func known_skills(cls: StringName = &"") -> Array[StringName]:
	var c := current if cls == &"" else cls
	var out: Array[StringName] = []
	for id in SkillBook.of_class(c):
		if int(SkillBook.SKILLS[id]["level"]) <= level(c):
			out.append(id)
	return out


func slots(cls: StringName = &"") -> Array:
	var c := current if cls == &"" else cls
	if not equipped.has(c):
		equipped[c] = []
	while equipped[c].size() < SKILL_SLOTS:
		equipped[c].append(&"")
	return equipped[c]


## Place une technique dans un emplacement de la barre (et la retire d'un autre).
func equip(slot: int, id: StringName) -> void:
	var s := slots()
	for i in s.size():
		if s[i] == id:
			s[i] = &""
	s[slot] = id
	stats_changed.emit()


func _auto_equip(cls: StringName) -> void:
	var s := slots(cls)
	for id in known_skills(cls):
		if s.has(id):
			continue
		var free := s.find(&"")
		if free < 0:
			return
		s[free] = id


func unlock(id: StringName) -> bool:
	if unlocked.has(id):
		return false
	unlocked.append(id)
	levels[id] = 1
	xp[id] = 0
	_auto_equip(id)
	return true


## Change de classe. Seulement à Dracombra (la carte de la ville).
func can_switch_here() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path.contains("dracombra")


func switch_to(id: StringName) -> bool:
	if not unlocked.has(id) or id == current:
		return false
	current = id
	_auto_equip(id)
	clear_buffs()
	energy = energy_max()
	class_changed.emit(id)
	var player := get_tree().get_first_node_in_group("player") as Player
	if player:
		player.apply_class()
	return true


func gain_xp(amount: int) -> void:
	if not Game.has_flag(&"prologue_done") or amount <= 0 or level() >= MAX_LEVEL:
		return
	xp[current] = int(xp.get(current, 0)) + amount
	while level() < MAX_LEVEL and int(xp[current]) >= xp_to_next(level()):
		xp[current] = int(xp[current]) - xp_to_next(level())
		levels[current] = level() + 1
		unspent[current] = free_points() + POINTS_PER_LEVEL
		var player := get_tree().get_first_node_in_group("player") as Player
		_refresh_player(true)
		energy = energy_max()
		if player:
			Emote.show(player, "Niv. %d" % level(), Color(1.0, 0.9, 0.4), 34.0)
		leveled_up.emit(current, level())
		for id in SkillBook.of_class(current):
			if int(SkillBook.SKILLS[id]["level"]) == level():
				_auto_equip(current)
				skill_learned.emit(id)
				Narration.say("Nouvelle %s : %s !" % ["technique" if info()["resource"] == "Endurance" else "formule",
					SkillBook.SKILLS[id]["name"]], 3.0)
	if level() >= MAX_LEVEL:
		xp[current] = 0
	xp_changed.emit(current, level(), int(xp[current]))
	stats_changed.emit()


func _refresh_player(refill: bool) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player:
		player.apply_class(refill)


## Appelé par les ennemis à leur mort.
func reward_kill(enemy: Node) -> void:
	var key := StringName(enemy.get_script().get_global_name()) if enemy.get_script() else &""
	gain_xp(int(KILL_XP.get(key, 1)))


func serialize() -> Dictionary:
	var lv := {}
	var x := {}
	for k in levels:
		lv[String(k)] = levels[k]
	for k in xp:
		x[String(k)] = xp[k]
	var u: Array = []
	for k in unlocked:
		u.append(String(k))
	var pts := {}
	for c in points:
		var one := {}
		for k in points[c]:
			one[String(k)] = int(points[c][k])
		pts[String(c)] = one
	var free := {}
	for c in unspent:
		free[String(c)] = int(unspent[c])
	var eq := {}
	for c in equipped:
		var ids: Array = []
		for id in equipped[c]:
			ids.append(String(id))
		eq[String(c)] = ids
	return {"name": hero_name, "current": String(current), "unlocked": u, "levels": lv, "xp": x,
		"points": pts, "unspent": free, "equipped": eq}


func deserialize(data: Dictionary) -> void:
	reset()
	hero_name = data.get("name", hero_name)
	unlocked.clear()
	for k in data.get("unlocked", ["warrior"]):
		unlocked.append(StringName(k))
	for k in data.get("levels", {}):
		levels[StringName(k)] = int(data["levels"][k])
	for k in data.get("xp", {}):
		xp[StringName(k)] = int(data["xp"][k])
	current = StringName(data.get("current", "warrior"))
	var pts: Dictionary = data.get("points", {})
	for c in pts:
		var one := {}
		for k in pts[c]:
			one[StringName(k)] = int(pts[c][k])
		points[StringName(c)] = one
	var free: Dictionary = data.get("unspent", {})
	for c in free:
		unspent[StringName(c)] = int(free[c])
	var eq: Dictionary = data.get("equipped", {})
	for c in eq:
		var ids: Array = []
		for id in eq[c]:
			ids.append(StringName(id))
		equipped[StringName(c)] = ids
	# Anciennes sauvegardes : les points des niveaux déjà gagnés.
	for c in unlocked:
		if not data.has("unspent"):
			unspent[c] = (level(c) - 1) * POINTS_PER_LEVEL
		_auto_equip(c)
	energy = energy_max()
