extends Node
## Constantes et réglages globaux du jeu.
## Accessible partout avec Game.TILE_SIZE, par exemple.

## Taille d'une tile en pixels. Passera à 32 lors du remaster.
## Toutes les distances, vitesses et portées doivent en dépendre.
const TILE_SIZE: int = 16

## Drapeaux de progression de l'histoire (intro vue, boss vaincu...).
## Conservés pendant toute la partie, même quand une salle est rechargée.
var flags: Dictionary[StringName, bool] = {}


func has_flag(flag: StringName) -> bool:
	return flags.get(flag, false)


func set_flag(flag: StringName, value: bool = true) -> void:
	flags[flag] = value


## PV maximum du héros pendant le prologue : un capitaine aguerri.
const HERO_PROLOGUE_HEALTH: int = 20
## PV maximum après le prologue : la blessure de Solakor l'a durablement affaibli.
const HERO_BASE_HEALTH: int = 10


func hero_max_health() -> int:
	return HERO_BASE_HEALTH if has_flag(&"prologue_done") else HERO_PROLOGUE_HEALTH
