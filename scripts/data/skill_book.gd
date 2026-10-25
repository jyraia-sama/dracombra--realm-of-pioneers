class_name SkillBook
extends RefCounted
## Les techniques (guerrier, archer) et les sorts (mage, clerc) de chaque classe.
## Chaque classe en apprend six, aux niveaux de UNLOCK_LEVELS ; trois peuvent être placées
## dans la barre (touches R, F, C).
##
## Champs communs : name, level, cost (endurance ou mana), cooldown (s), desc, type,
## color (couleur de l'effet). Les autres champs dépendent du type :
##   strike      coup de l'arme renforcé            mult, knock
##   dash        ruée qui blesse sur le passage      mult, dist (cases)
##   nova        onde autour du héros               mult, radius (cases), knock
##   area        zone devant le héros               mult, radius, dist, delay, ticks, interval, follow
##   projectile  tir(s)                              kind, mult, count, spread (°), interval, pierce, scale, explode
##   buff        effet temporaire                    buff {stat: valeur}, duration, heal (part des PV)
##   heal        soin                                heal (part des PV max)
##   blink       saut instantané                     dist (cases, négatif = en arrière), then (technique lancée après)
## Toutes les valeurs sont des premiers réglages, à équilibrer en jouant.

const UNLOCK_LEVELS: Array[int] = [1, 5, 12, 25, 45, 75]

const SKILLS: Dictionary = {
	# ------------------------------------------------------------ Guerrier
	&"power_strike": {"class": &"warrior", "name": "Frappe puissante", "level": 1, "cost": 4, "cooldown": 3.0,
		"type": "strike", "mult": 2.0, "knock": 3.0, "color": Color(1.0, 0.85, 0.5),
		"desc": "Un coup d'épée appuyé : double dégâts, repousse loin."},
	&"charge": {"class": &"warrior", "name": "Charge", "level": 5, "cost": 5, "cooldown": 5.0,
		"type": "dash", "mult": 1.5, "dist": 4.0, "color": Color(1.0, 0.7, 0.4),
		"desc": "Fonce sur 4 cases et blesse tout sur le passage."},
	&"whirlwind": {"class": &"warrior", "name": "Tourbillon", "level": 12, "cost": 7, "cooldown": 7.0,
		"type": "nova", "mult": 1.5, "radius": 1.8, "knock": 2.0, "color": Color(0.9, 0.9, 1.0),
		"desc": "Tournoie, l'épée tendue : frappe tous les ennemis autour."},
	&"war_cry": {"class": &"warrior", "name": "Cri de guerre", "level": 25, "cost": 8, "cooldown": 20.0,
		"type": "buff", "buff": {"damage": 1.5}, "duration": 8.0, "color": Color(1.0, 0.4, 0.3),
		"desc": "+50 % de dégâts pendant 8 secondes."},
	&"iron_skin": {"class": &"warrior", "name": "Peau de fer", "level": 45, "cost": 10, "cooldown": 25.0,
		"type": "buff", "buff": {"guard": 0.5}, "duration": 6.0, "color": Color(0.7, 0.75, 0.85),
		"desc": "Les dégâts reçus sont divisés par deux pendant 6 secondes."},
	&"dragon_cleave": {"class": &"warrior", "name": "Fendoir du dragon", "level": 75, "cost": 15, "cooldown": 15.0,
		"type": "projectile", "kind": &"wave", "mult": 4.0, "count": 1, "pierce": true, "scale": 2.0,
		"color": Color(0.75, 0.5, 1.0), "desc": "L'épée libère une onde qui traverse les rangs ennemis (×4 dégâts)."},
	# ------------------------------------------------------------ Archer
	&"piercing_shot": {"class": &"archer", "name": "Tir perçant", "level": 1, "cost": 4, "cooldown": 3.0,
		"type": "projectile", "kind": &"arrow", "mult": 2.0, "count": 1, "pierce": true, "scale": 1.0,
		"color": Color(0.9, 1.0, 0.7), "desc": "Une flèche qui traverse les ennemis (×2 dégâts)."},
	&"volley": {"class": &"archer", "name": "Salve", "level": 5, "cost": 5, "cooldown": 4.0,
		"type": "projectile", "kind": &"arrow", "mult": 1.0, "count": 3, "spread": 15.0,
		"color": Color(0.9, 1.0, 0.7), "desc": "Trois flèches en éventail."},
	&"evasive_shot": {"class": &"archer", "name": "Tir de repli", "level": 12, "cost": 5, "cooldown": 5.0,
		"type": "blink", "dist": -3.0, "then": &"piercing_shot", "color": Color(0.6, 0.9, 0.6),
		"desc": "Bondit de 3 cases en arrière et décoche un tir perçant."},
	&"hawk_eye": {"class": &"archer", "name": "Œil de faucon", "level": 25, "cost": 8, "cooldown": 20.0,
		"type": "buff", "buff": {"crit": 30.0}, "duration": 10.0, "color": Color(1.0, 0.95, 0.5),
		"desc": "+30 % de chances de coup critique pendant 10 secondes."},
	&"arrow_rain": {"class": &"archer", "name": "Pluie de flèches", "level": 45, "cost": 10, "cooldown": 12.0,
		"type": "area", "mult": 1.0, "radius": 2.0, "dist": 4.0, "delay": 0.3, "ticks": 5, "interval": 0.35,
		"color": Color(0.8, 0.9, 0.6), "desc": "Une pluie de flèches s'abat 4 cases devant : 5 vagues de dégâts."},
	&"dragon_arrow": {"class": &"archer", "name": "Flèche du dragon", "level": 75, "cost": 15, "cooldown": 15.0,
		"type": "projectile", "kind": &"arrow", "mult": 5.0, "count": 1, "pierce": true, "scale": 2.5,
		"color": Color(1.0, 0.6, 0.3), "desc": "Une flèche géante qui perce tout sur sa route (×5 dégâts)."},
	# ------------------------------------------------------------ Mage
	&"fireball": {"class": &"mage", "name": "Boule de feu", "level": 1, "cost": 5, "cooldown": 3.0,
		"type": "projectile", "kind": &"fire", "mult": 2.5, "count": 1, "scale": 1.4, "explode": 1.2,
		"color": Color(1.0, 0.55, 0.2), "desc": "Explose à l'impact et brûle les ennemis proches (×2,5 dégâts)."},
	&"frost_nova": {"class": &"mage", "name": "Nova de givre", "level": 5, "cost": 6, "cooldown": 6.0,
		"type": "nova", "mult": 1.2, "radius": 2.2, "knock": 2.5, "color": Color(0.6, 0.85, 1.0),
		"desc": "Une onde glacée repousse tous les ennemis autour."},
	&"blink": {"class": &"mage", "name": "Clignement", "level": 12, "cost": 5, "cooldown": 4.0,
		"type": "blink", "dist": 4.0, "color": Color(0.7, 0.5, 1.0),
		"desc": "Se téléporte 4 cases plus loin."},
	&"arcane_missiles": {"class": &"mage", "name": "Missiles arcaniques", "level": 25, "cost": 9, "cooldown": 8.0,
		"type": "projectile", "kind": &"bolt", "mult": 1.0, "count": 5, "interval": 0.12, "spread": 8.0,
		"color": Color(0.75, 0.5, 1.0), "desc": "Cinq projectiles de mana tirés en rafale."},
	&"mana_shield": {"class": &"mage", "name": "Bouclier de mana", "level": 45, "cost": 12, "cooldown": 30.0,
		"type": "buff", "buff": {"guard": 0.0}, "duration": 4.0, "color": Color(0.5, 0.7, 1.0),
		"desc": "Aucun dégât reçu pendant 4 secondes."},
	&"meteor": {"class": &"mage", "name": "Météore", "level": 75, "cost": 18, "cooldown": 18.0,
		"type": "area", "mult": 5.0, "radius": 2.2, "dist": 4.0, "delay": 0.7, "ticks": 1, "interval": 0.0,
		"color": Color(1.0, 0.4, 0.15), "desc": "Un météore s'écrase 4 cases devant (×5 dégâts)."},
	# ------------------------------------------------------------ Clerc
	&"heal": {"class": &"cleric", "name": "Soin", "level": 1, "cost": 6, "cooldown": 6.0,
		"type": "heal", "heal": 0.3, "color": Color(0.6, 1.0, 0.6),
		"desc": "Rend 30 % des PV max."},
	&"holy_smite": {"class": &"cleric", "name": "Marteau sacré", "level": 5, "cost": 5, "cooldown": 4.0,
		"type": "area", "mult": 2.0, "radius": 1.3, "dist": 1.3, "delay": 0.1, "ticks": 1, "interval": 0.0,
		"color": Color(1.0, 0.95, 0.6), "desc": "La masse s'abat dans un éclat de lumière (×2 dégâts, en zone)."},
	&"blessing": {"class": &"cleric", "name": "Bénédiction", "level": 12, "cost": 8, "cooldown": 20.0,
		"type": "buff", "buff": {"damage": 1.4, "regen": 1.0}, "duration": 10.0, "color": Color(1.0, 0.9, 0.5),
		"desc": "+40 % de dégâts et 1 PV rendu par seconde pendant 10 secondes."},
	&"consecration": {"class": &"cleric", "name": "Consécration", "level": 25, "cost": 10, "cooldown": 14.0,
		"type": "area", "mult": 1.0, "radius": 2.0, "dist": 0.0, "delay": 0.0, "ticks": 5, "interval": 0.8,
		"follow": true, "color": Color(1.0, 0.85, 0.4), "desc": "Le sol se sanctifie autour du héros : 5 vagues de dégâts."},
	&"divine_bulwark": {"class": &"cleric", "name": "Rempart divin", "level": 45, "cost": 12, "cooldown": 30.0,
		"type": "buff", "buff": {"guard": 0.5}, "duration": 10.0, "heal": 0.2, "color": Color(0.9, 0.9, 0.6),
		"desc": "Rend 20 % des PV et divise les dégâts reçus par deux pendant 10 secondes."},
	&"judgement": {"class": &"cleric", "name": "Jugement", "level": 75, "cost": 18, "cooldown": 20.0,
		"type": "nova", "mult": 4.0, "radius": 4.0, "knock": 3.0, "color": Color(1.0, 1.0, 0.75),
		"desc": "Une colonne de lumière foudroie tout ce qui entoure le héros (×4 dégâts)."},
}


## Les techniques d'une classe, dans l'ordre d'apprentissage.
static func of_class(cls: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for id in SKILLS:
		if SKILLS[id]["class"] == cls:
			out.append(id)
	out.sort_custom(func(a, b): return int(SKILLS[a]["level"]) < int(SKILLS[b]["level"]))
	return out


static func get_skill(id: StringName) -> Dictionary:
	return SKILLS.get(id, {})
