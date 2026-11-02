class_name Combat
extends RefCounted
## Le tableau des calculs de combat (voir COMBAT.md) : PV, dégâts, défense, critiques,
## niveaux des monstres et XP. Le héros et les membres de la guilde utilisent les mêmes formules.
##
## Échelle « ×10 » : un slime a 30 PV, un coup d'épée fait une dizaine de dégâts.

## Défense : réduction = DÉF / (DÉF + ARMOR_K). Jamais 100 %.
const ARMOR_K := 50.0
## Multiplicateur d'un coup critique.
const CRIT_MULT := 1.75
const CRIT_BASE := 5.0
const CRIT_MAX := 50.0
const PARRY_MAX := 25.0
## Chaque point de la caractéristique principale ajoute 2 % aux dégâts de l'arme.
const MAIN_STAT_BONUS := 0.02

## Les classes ne sont pas équilibrées : le guerrier encaisse (plus de PV, armure lourde),
## le mage frappe fort mais sort en tissu (moins de PV, pas d'armure de base).
## weapon : dégâts de base de l'arme de la classe ; hp + hp_vit × VIT ; armor : défense de base.
const CLASS_COMBAT := {
	&"warrior": {"weapon": 10, "hp": 120, "hp_vit": 6, "armor": 10, "poise": 15},
	&"archer": {"weapon": 9, "hp": 100, "hp_vit": 5, "armor": 4, "poise": 0},
	&"mage": {"weapon": 22, "hp": 80, "hp_vit": 4, "armor": 0, "poise": 0},
	&"cleric": {"weapon": 9, "hp": 100, "hp_vit": 5, "armor": 5, "poise": 5},
}

## Les monstres au niveau 1. Les dégâts de base sont réglés dans leur script ;
## ici : PV, XP de base et résistance aux coups (poise).
const MONSTERS := {
	&"Slime": {"hp": 30, "xp": 4},
	&"ObsidianSpider": {"hp": 25, "xp": 5},
	&"RockGoblin": {"hp": 35, "xp": 6},
	&"Boar": {"hp": 45, "xp": 6},
	&"QueenSpider": {"hp": 600, "xp": 150, "poise": 25},
}


# ------------------------------------------------------------------ joueurs (héros et membres)

static func class_info(cls: StringName) -> Dictionary:
	return CLASS_COMBAT.get(cls, CLASS_COMBAT[&"warrior"])


static func max_hp(cls: StringName, vit: int) -> int:
	var c := class_info(cls)
	return int(c["hp"]) + int(c["hp_vit"]) * vit


## Dégâts d'un coup : (arme de la classe + bonus de l'équipement) × (1 + 2 % par point de la stat principale).
static func damage(cls: StringName, main_stat: int, gear_dmg: int) -> int:
	var weapon := float(int(class_info(cls)["weapon"]) + gear_dmg)
	return maxi(int(round(weapon * (1.0 + MAIN_STAT_BONUS * main_stat))), 1)


## Défense : armure de la classe + 2 par tranche de 5 VIT + armures portées.
static func defense(cls: StringName, vit: int, gear_def: int) -> int:
	return int(class_info(cls)["armor"]) + (2 * vit) / 5 + gear_def


## Part des dégâts retirée par la défense (0 à 1, jamais 1).
static func reduction(def: int) -> float:
	if def <= 0:
		return 0.0
	return float(def) / (float(def) + ARMOR_K)


## Dégâts encaissés après la défense (au moins 1).
static func after_defense(amount: float, def: int) -> int:
	return maxi(int(round(amount * (1.0 - reduction(def)))), 1)


static func crit_chance(dex: int, bonus: float) -> float:
	return minf(CRIT_MAX, CRIT_BASE + dex * 0.4 + bonus)


static func parry_chance(dex: int, vit: int, bonus: float) -> float:
	return minf(PARRY_MAX, dex * 0.25 + vit * 0.1 + bonus)


## XP pour passer au niveau suivant.
static func xp_to_next(lvl: int) -> int:
	return int(round(20.0 * pow(float(lvl), 1.5)))


# ------------------------------------------------------------------ monstres

static func hp_mult(lvl: int) -> float:
	return 1.0 + 0.15 * (lvl - 1)


static func dmg_mult(lvl: int) -> float:
	return 1.0 + 0.10 * (lvl - 1)


static func monster_key(enemy: Node) -> StringName:
	if enemy == null or enemy.get_script() == null:
		return &""
	return StringName(enemy.get_script().get_global_name())


static func monster_level(enemy: Node) -> int:
	return int(enemy.get_meta(&"level", 1)) if is_instance_valid(enemy) else 1


## Donne un niveau à un monstre (avant ou après son entrée dans la scène) :
## PV × (1 + 15 % par niveau), dégâts × (1 + 10 % par niveau).
static func set_level(enemy: Node, lvl: int) -> void:
	lvl = maxi(lvl, 1)
	enemy.set_meta(&"level", lvl)
	enemy.set_meta(&"dmg_mult", dmg_mult(lvl))
	var health := enemy.get_node_or_null("Health") as HealthComponent
	if health:
		var base := int(MONSTERS.get(monster_key(enemy), {}).get("hp", health.max_health))
		var hp := int(ceil(base * hp_mult(lvl)))
		health.max_health = hp
		health.current_health = hp


## Dégâts réels d'une hitbox : ceux du coup × le multiplicateur du niveau de son porteur.
static func hit_amount(hitbox: Hitbox) -> int:
	var amount := float(hitbox.damage)
	var src := hitbox.source
	if is_instance_valid(src) and src.has_meta(&"dmg_mult"):
		amount *= float(src.get_meta(&"dmg_mult"))
	return int(round(amount))


static func kill_xp(enemy: Node) -> int:
	var base := int(MONSTERS.get(monster_key(enemy), {}).get("xp", 2))
	return base * monster_level(enemy)


static func poise(enemy: Node) -> int:
	return int(MONSTERS.get(monster_key(enemy), {}).get("poise", 0))


# ------------------------------------------------------------------ cibles des monstres

## La cible d'un monstre : le héros ou un compagnon debout, le plus proche. Le monstre garde
## sa cible actuelle tant qu'une autre n'est pas nettement plus proche (30 %).
static func pick_target(enemy: Node2D, current: Node2D = null) -> Node2D:
	var tree := enemy.get_tree()
	var candidates: Array[Node2D] = []
	var player := tree.get_first_node_in_group("player") as Node2D
	if player:
		candidates.append(player)
	for c in tree.get_nodes_in_group("companions"):
		if c is Companion and (c as Companion).can_be_targeted():
			candidates.append(c)
	if candidates.is_empty():
		return null
	var best: Node2D = null
	var best_d := INF
	for c in candidates:
		var d := enemy.global_position.distance_to(c.global_position)
		if c == player:
			d *= 0.9  # le héros attire un peu plus
		if d < best_d:
			best_d = d
			best = c
	if is_instance_valid(current) and candidates.has(current) and current != best:
		var cur_d := enemy.global_position.distance_to(current.global_position)
		if cur_d <= best_d * 1.3:
			return current
	return best
