class_name Loot
extends RefCounted
## Le butin d'équipement (voir DONJON.md §3) : raretés, familles, bonus tirés au hasard.
##
##     var item := Loot.piece(1, 2)      # une pièce du palier 1, jusqu'à « rare »
##
## Un objet « normal » est l'objet de base (il s'empile dans le sac). Au-dessus, l'objet est
## unique : mêmes stats que le normal + des bonus en plus, toujours cohérents avec sa famille.

const RARITIES := ["Normal", "Peu commun", "Rare", "Épique", "Légendaire", "Mythique", "Draconique", "Divin"]
const COLORS := [Color(0.92, 0.92, 0.92), Color(0.45, 0.95, 0.45), Color(0.4, 0.65, 1.0), Color(0.75, 0.45, 1.0),
	Color(1.0, 0.6, 0.2), Color(1.0, 0.3, 0.3), Color(0.35, 0.95, 0.85), Color(1.0, 0.95, 0.6)]
## Nombre de bonus en plus selon la rareté.
const EXTRA_BONUSES := [0, 1, 2, 3, 4, 4, 5, 5]

## Familles d'équipement : classes qui les portent et bonus possibles [stat, min, max] au palier 1.
const FAMILIES := {
	&"lourd": {"classes": [&"warrior"], "stats": [[&"str", 1, 2], [&"vit", 1, 3], [&"def", 2, 4], [&"parry", 2, 4]]},
	&"cuir": {"classes": [&"archer"], "stats": [[&"dex", 1, 2], [&"crit", 2, 4], [&"stamina", 4, 8]]},
	&"tissu": {"classes": [&"mage", &"cleric"], "stats": [[&"int", 1, 2], [&"wis", 1, 2], [&"mana", 4, 8]]},
}

## Équipement de chaque palier (objets de base).
const TIER_GEAR := {
	1: [&"iron_helmet", &"iron_armor", &"iron_gauntlets", &"iron_boots", &"iron_sword", &"iron_shield",
		&"chitin_hood", &"chitin_armor", &"chitin_bracers", &"chitin_boots", &"chitin_bow", &"silk_quiver",
		&"silk_hood", &"silk_robe", &"silk_gloves", &"silk_shoes", &"crystal_staff", &"sacred_book"],
}


static func rarity_name(item: ItemData) -> String:
	return RARITIES[clampi(item.rarity, 0, RARITIES.size() - 1)]


static func color(item: ItemData) -> Color:
	return COLORS[clampi(item.rarity, 0, COLORS.size() - 1)]


## Nom affiché avec la rareté : « Casque de fer · Rare ».
static func label(item: ItemData) -> String:
	return item.display_name if item.rarity <= 0 else "%s · %s" % [item.display_name, rarity_name(item)]


static func family_of(item: ItemData) -> StringName:
	for f in FAMILIES:
		for c in item.classes:
			if FAMILIES[f]["classes"].has(c):
				return f
	return &""


## Tire une rareté. weights : poids de chaque rareté à partir de « normal ».
static func roll_rarity(weights: Array, rng: RandomNumberGenerator = null) -> int:
	var total := 0.0
	for w in weights:
		total += float(w)
	var r := (rng.randf() if rng else randf()) * total
	for i in weights.size():
		r -= float(weights[i])
		if r < 0.0:
			return i
	return 0


## Une pièce d'équipement du palier `tier`. weights : poids des raretés (défaut : zone 1,
## jusqu'à « rare »). Renvoie l'objet (de base si normal, unique sinon).
static func piece(tier: int = 1, weights: Array = [50, 35, 15], rng: RandomNumberGenerator = null) -> ItemData:
	var list: Array = TIER_GEAR.get(tier, TIER_GEAR[1])
	var base_id: StringName = list[(rng.randi() if rng else randi()) % list.size()]
	var rarity := roll_rarity(weights, rng)
	if rarity <= 0:
		return Inventory.item_by_id(base_id)
	return make(base_id, rarity, rng)


## Crée l'objet unique : bonus tirés dans la famille de l'objet (sans doublon de stat
## tant que c'est possible).
static func make(base_id: StringName, rarity: int, rng: RandomNumberGenerator = null) -> ItemData:
	var base := Inventory.item_by_id(base_id)
	var fam := family_of(base)
	var pool: Array = FAMILIES[fam]["stats"].duplicate() if fam != &"" else [[&"vit", 1, 2]]
	var extra := {}
	var n: int = EXTRA_BONUSES[clampi(rarity, 0, EXTRA_BONUSES.size() - 1)]
	for i in n:
		if pool.is_empty():
			pool = FAMILIES[fam]["stats"].duplicate() if fam != &"" else [[&"vit", 1, 2]]
		var k := (rng.randi() if rng else randi()) % pool.size()
		var s: Array = pool[k]
		pool.remove_at(k)
		var v := (rng.randi_range(s[1], s[2]) if rng else randi_range(s[1], s[2])) + (rarity - 1) / 2
		extra[s[0]] = int(extra.get(s[0], 0)) + v
	return Inventory.register_unique(base_id, rarity, extra)


## Comparaison avec ce qui est porté au même emplacement : « +2 Force, −1 Défense ».
static func compare_text(item: ItemData) -> String:
	if item.slot == &"":
		return ""
	var worn := Hero.worn(item.slot)
	if worn == null:
		return "Rien de porté à cet emplacement."
	if worn.id == item.id:
		return "C'est l'objet porté."
	var keys := {}
	for k in item.bonus:
		keys[k] = true
	for k in worn.bonus:
		keys[k] = true
	var parts: Array[String] = []
	for k in keys:
		var d := int(item.bonus.get(k, 0)) - int(worn.bonus.get(k, 0))
		if d != 0:
			parts.append("%s%d %s" % ["+" if d > 0 else "−", absi(d), Hero.BONUS_NAMES.get(k, String(k))])
	if parts.is_empty():
		return "Comparé à %s : identique." % label(worn)
	return "Comparé à %s : %s." % [label(worn), ", ".join(parts)]


## Poids d'un point de chaque bonus, pour juger « mieux / moins bien ».
const WEIGHTS := {&"dmg": 1.0, &"def": 1.5, &"str": 1.0, &"dex": 1.0, &"int": 1.0, &"wis": 1.0, &"vit": 1.0,
	&"crit": 0.5, &"parry": 0.5, &"stamina": 0.25, &"mana": 0.25}


## Différences avec l'objet porté au même emplacement : {stat: écart}.
static func diff(item: ItemData) -> Dictionary:
	var worn := Hero.worn(item.slot)
	var out := {}
	var keys := {}
	for k in item.bonus:
		keys[k] = true
	if worn:
		for k in worn.bonus:
			keys[k] = true
	for k in keys:
		var d := int(item.bonus.get(k, 0)) - (int(worn.bonus.get(k, 0)) if worn else 0)
		if d != 0:
			out[k] = d
	return out


## Verdict : 1 = mieux, -1 = moins bien, 0 = équivalent / différent.
static func verdict(item: ItemData) -> int:
	var worn := Hero.worn(item.slot)
	if worn and worn.id == item.id:
		return 0
	var score := 0.0
	var d := diff(item)
	for k in d:
		score += float(d[k]) * float(WEIGHTS.get(k, 1.0))
	if score > 0.25:
		return 1
	if score < -0.25:
		return -1
	return 0


## « ▲ mieux (+1 DÉF, +2 % parade) » en abrégé, pour les listes.
static func compare_short(item: ItemData) -> String:
	var worn := Hero.worn(item.slot)
	if worn and worn.id == item.id:
		return "porté"
	var d := diff(item)
	var parts: Array[String] = []
	for k in d:
		parts.append("%s%d %s" % ["+" if d[k] > 0 else "−", absi(d[k]), Hero.BONUS_SHORT.get(k, String(k))])
	var v := verdict(item)
	var head := "▲ mieux" if v > 0 else ("▼ moins bien" if v < 0 else "≈ équivalent")
	if worn == null:
		head = "▲ rien de porté"
	return "%s%s" % [head, " (%s)" % ", ".join(parts) if not parts.is_empty() else ""]


static func verdict_color(item: ItemData) -> Color:
	if Hero.worn(item.slot) == null:
		return Color(0.55, 1.0, 0.55)
	var v := verdict(item)
	return Color(0.55, 1.0, 0.55) if v > 0 else (Color(1.0, 0.5, 0.45) if v < 0 else Color(0.85, 0.85, 0.85))
