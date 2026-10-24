extends Node
## La fiche du héros : son nom (le pseudo du joueur), sa classe, et un niveau par classe.
## On change de classe en fabriquant son équipement, puis seulement à Dracombra (au feu de
## camp ou à la guilde), jamais en pleine nature.

signal class_changed(id: StringName)
signal xp_changed(id: StringName, level: int, xp: int)
signal leveled_up(id: StringName, level: int)

## Les classes de base. attack : melee (épée, masse), arrow (flèches), bolt (projectile magique).
const CLASSES: Dictionary = {
	&"warrior": {"name": "Guerrier", "role": "Corps à corps. Encaisse les coups.", "attack": "melee",
		"damage": 1, "cooldown": 0.0, "hp": 2, "item": &"", "tint": Color(1, 1, 1), "icon": 272},
	&"archer": {"name": "Archer", "role": "Tire des flèches à distance. Fragile au contact.", "attack": "arrow",
		"damage": 1, "cooldown": 0.35, "hp": 0, "item": &"bow", "tint": Color(0.82, 1.0, 0.78), "icon": 224},
	&"mage": {"name": "Mage", "role": "Projectiles de mana lents mais puissants.", "attack": "bolt",
		"damage": 2, "cooldown": 0.7, "hp": -1, "item": &"staff", "tint": Color(0.82, 0.85, 1.25), "icon": 240},
	&"cleric": {"name": "Clerc", "role": "Frappe à la masse et referme lentement ses blessures.", "attack": "melee",
		"damage": 1, "cooldown": 0.0, "hp": 1, "item": &"holy_symbol", "tint": Color(1.15, 1.08, 0.8), "icon": 256,
		"regen": 8.0},
}
const ORDER: Array[StringName] = [&"warrior", &"archer", &"mage", &"cleric"]
## XP rapportée par chaque ennemi vaincu.
const KILL_XP := {&"Slime": 2, &"RockGoblin": 4, &"ObsidianSpider": 3, &"Boar": 3}

var hero_name: String = "Heros"
var current: StringName = &"warrior"
var unlocked: Array[StringName] = [&"warrior"]
var levels: Dictionary = {&"warrior": 1}
var xp: Dictionary = {&"warrior": 0}


func reset() -> void:
	current = &"warrior"
	unlocked = [&"warrior"]
	levels = {&"warrior": 1}
	xp = {&"warrior": 0}


func info(id: StringName = &"") -> Dictionary:
	return CLASSES[current if id == &"" else id]


func level(id: StringName = &"") -> int:
	return int(levels.get(current if id == &"" else id, 1))


## XP nécessaire pour passer au niveau suivant.
func xp_to_next(lvl: int) -> int:
	return 10 * lvl


## Bonus de PV max : la classe, plus 1 PV par niveau gagné.
func hp_bonus() -> int:
	if not Game.has_flag(&"prologue_done"):
		return 0
	return int(info()["hp"]) + level() - 1


func damage() -> int:
	return int(info()["damage"]) + (level() - 1) / 3


func unlock(id: StringName) -> bool:
	if unlocked.has(id):
		return false
	unlocked.append(id)
	levels[id] = 1
	xp[id] = 0
	return true


## Change de classe. Seulement à Dracombra (la carte de la ville).
func can_switch_here() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path.contains("dracombra")


func switch_to(id: StringName) -> bool:
	if not unlocked.has(id) or id == current:
		return false
	current = id
	class_changed.emit(id)
	var player := get_tree().get_first_node_in_group("player") as Player
	if player:
		player.apply_class()
	return true


func gain_xp(amount: int) -> void:
	if not Game.has_flag(&"prologue_done") or amount <= 0:
		return
	xp[current] = int(xp.get(current, 0)) + amount
	while int(xp[current]) >= xp_to_next(level()):
		xp[current] = int(xp[current]) - xp_to_next(level())
		levels[current] = level() + 1
		leveled_up.emit(current, level())
		var player := get_tree().get_first_node_in_group("player") as Player
		if player:
			player.apply_class()
			Emote.show(player, "Niv. %d" % level(), Color(1.0, 0.9, 0.4), 34.0)
	xp_changed.emit(current, level(), int(xp[current]))


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
	return {"name": hero_name, "current": String(current), "unlocked": u, "levels": lv, "xp": x}


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
