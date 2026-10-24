class_name LootEntry
extends Resource
## Une ligne d'une table de butin : quel objet, avec quelle chance, en quelle quantité.

@export var item: ItemData
## Chance d'obtenir l'objet, de 0 (jamais) à 1 (toujours).
@export_range(0.0, 1.0, 0.05) var chance: float = 1.0
@export var min_amount: int = 1
@export var max_amount: int = 1
