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
