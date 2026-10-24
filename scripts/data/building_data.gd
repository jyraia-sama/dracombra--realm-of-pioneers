class_name BuildingData
extends Resource
## Fiche d'un bâtiment constructible à Dracombra (tente, établi...).

@export var id: StringName
@export var display_name: String
@export_multiline var description: String = ""
## Palier de la guilde à atteindre pour pouvoir le construire (0 = camp).
@export var tier_required: int = 0
## Emprise au sol, en cases : c'est elle qui bloque le passage et les autres constructions.
@export var size: Vector2i = Vector2i(2, 1)
## Coût : { identifiant d'objet : quantité }.
@export var cost: Dictionary[StringName, int] = {}
## Jours de chantier une fois les matériaux déposés.
@export var build_days: int = 1
@export var texture: Texture2D
## Habitants que le bâtiment peut loger.
@export var housing: int = 0
## On peut y dormir (et faire passer les jours).
@export var can_sleep: bool = false
