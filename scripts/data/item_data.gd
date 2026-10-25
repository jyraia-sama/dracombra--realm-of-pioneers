class_name ItemData
extends Resource
## Description d'un objet : ressource de craft, soin...
## Chaque objet est un fichier .tres dans data/items/.

## Identifiant unique, utilisé par l'inventaire.
@export var id: StringName
## Nom affiché au joueur.
@export var display_name: String
## Icône affichée au sol et dans l'interface.
@export var icon: Texture2D
## Si supérieur à 0, l'objet est consommé au ramassage et soigne de ce montant.
## Il n'entre alors pas dans l'inventaire.
@export var heal_amount: int = 0
## Description affichée dans le sac.
@export_multiline var description: String = ""
## Soin quand on l'utilise depuis le sac (0 = ne se consomme pas).
@export var use_heal: int = 0
## Catégorie, pour trier le sac : resource, food, equipment...
@export var category: StringName = &"resource"
## Équipement : emplacement où il se porte (head, body, hands, feet, main, off ; vide = ne se porte pas).
@export var slot: StringName = &""
## Bonus quand il est porté : {str, dex, int, wis, vit, def, dmg, parry, crit, stamina, mana}.
@export var bonus: Dictionary = {}
## Classes qui peuvent le porter (vide = toutes).
@export var classes: Array[StringName] = []
