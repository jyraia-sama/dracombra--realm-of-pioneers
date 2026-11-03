class_name BuildingData
extends Resource
## Fiche d'un bâtiment constructible à Dracombra (logement, forge...).
##
## Un bâtiment réserve dès sa pose l'emprise de son dernier palier : tous ses paliers ont la même
## taille au sol (le vide des petits paliers est comblé dans le dessin : barrière, caisses...).

## Catégories du menu de construction, dans l'ordre d'affichage.
const CATEGORIES: Array[StringName] = [&"logement", &"production", &"artisanat", &"stockage"]
const CATEGORY_NAMES := {&"logement": "Logement", &"production": "Production", &"artisanat": "Artisanat",
	&"stockage": "Stockage"}

@export var id: StringName
@export var display_name: String
@export_multiline var description: String = ""
## Rubrique du menu de construction (voir CATEGORIES).
@export var category: StringName = &"production"
## Palier de la guilde à atteindre pour pouvoir le construire (0 = camp).
@export var tier_required: int = 0
## Emprise au sol, en cases : c'est elle qui bloque le passage et les autres constructions.
@export var size: Vector2i = Vector2i(3, 2)
## Coût : { identifiant d'objet : quantité }.
@export var cost: Dictionary[StringName, int] = {}
## Jours de chantier une fois les matériaux déposés.
@export var build_days: int = 1
## Dessin de secours (et du premier palier si `art` est vide).
@export var texture: Texture2D
## Préfixe des dessins par palier : res://assets/sprites/buildings/<art>_<palier>.png (palier 0, 1, 2...).
@export var art: String = ""
## Nom de chaque palier (« Tente », « Cabane », « Maison »). Vide = un seul palier.
@export var level_names: Array[String] = []
## Habitants que le bâtiment peut loger (au premier palier ; multiplié par le palier).
@export var housing: int = 0
## On peut y dormir (et faire passer les jours).
@export var can_sleep: bool = false

## Bâtiment de travail : métier des habitants qui y travaillent (vide = aucun).
@export var job: StringName = &""
## Travailleurs au maximum (au premier palier ; +1 par palier).
@export var workers: int = 0
## Production par travailleur et par jour : { objet : quantité }.
@export var produces: Dictionary = {}
## Stock maximum par objet dans le bâtiment (avant l'entrepôt ; multiplié par le palier).
@export var stock_cap: int = 40


func max_level() -> int:
	return maxi(1, level_names.size())


## Nom du bâtiment à un palier donné (1 = premier).
func level_name(level: int) -> String:
	if level_names.is_empty():
		return display_name
	return level_names[clampi(level, 1, level_names.size()) - 1]


## Dessin du bâtiment terminé à un palier donné (1 = premier).
func texture_for(level: int) -> Texture2D:
	if art != "":
		for l in range(clampi(level, 1, max_level()), 0, -1):
			var path := "res://assets/sprites/buildings/%s_%d.png" % [art, l - 1]
			if ResourceLoader.exists(path):
				return load(path)
	return texture


## Coût pour passer au palier `level` (2, 3...) : le coût de base multiplié par le palier.
func upgrade_cost(level: int) -> Dictionary:
	var out := {}
	for item in cost:
		out[item] = int(cost[item]) * level
	return out


func upgrade_days(level: int) -> int:
	return build_days + level - 1


## Palier de la guilde demandé pour atteindre ce palier du bâtiment.
func tier_for_level(level: int) -> int:
	return tier_required + level - 1
