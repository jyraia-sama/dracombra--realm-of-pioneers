extends Node
## Constantes, état global de la partie et passage des jours.
## Accessible partout avec Game.TILE_SIZE, Game.day, Game.sleep()...

## Taille d'une tile en pixels. Passera à 32 lors du remaster.
## Toutes les distances, vitesses et portées doivent en dépendre.
const TILE_SIZE: int = 16

## PV maximum du héros pendant le prologue : un capitaine aguerri.
const HERO_PROLOGUE_HEALTH: int = 20
## PV maximum après le prologue : la blessure de Solakor l'a durablement affaibli.
const HERO_BASE_HEALTH: int = 10

signal day_changed(day: int)

## Drapeaux de progression de l'histoire (intro vue, boss vaincu...).
## Conservés pendant toute la partie, même quand une salle est rechargée.
var flags: Dictionary[StringName, bool] = {}
## Jour de jeu (le premier jour est celui du réveil à Dracombra).
var day: int = 1
## Ressources récoltées : { "niveau:chemin du décor" : jour de la récolte }.
var harvested: Dictionary = {}
## Point d'arrivée dans le prochain niveau (nom d'un Marker2D sous « Spawns »).
var next_spawn: StringName = &""
## Position où replacer le héros au chargement d'une sauvegarde.
var pending_position: Variant = null

var _sleeping := false


func has_flag(flag: StringName) -> bool:
	return flags.get(flag, false)


func set_flag(flag: StringName, value: bool = true) -> void:
	flags[flag] = value


func hero_max_health() -> int:
	return HERO_BASE_HEALTH if has_flag(&"prologue_done") else HERO_PROLOGUE_HEALTH


## Nouvelle partie : tout est remis à zéro.
func reset() -> void:
	flags.clear()
	day = 1
	harvested.clear()
	next_spawn = &""
	pending_position = null
	Inventory.clear()
	Town.reset()


# ------------------------------------------------------------------ récoltes

func is_harvested(key: String, regrow_days: int) -> bool:
	if not harvested.has(key):
		return false
	if regrow_days <= 0:
		return true
	if day - int(harvested[key]) >= regrow_days:
		harvested.erase(key)
		return false
	return true


func mark_harvested(key: String) -> void:
	harvested[key] = day


# ------------------------------------------------------------------ le sommeil

## Le héros dort : fondu au noir, un jour passe, les chantiers avancent, il récupère.
func sleep() -> void:
	if _sleeping:
		return
	_sleeping = true
	var player := get_tree().get_first_node_in_group("player") as Player
	if player:
		player.input_locked = true
	await Transition.fade_out(0.8)
	day += 1
	var finished := Town.advance_day()
	if player:
		player.health.heal(player.health.max_health)
	await Transition.story_text("Jour %d" % day, 1.2)
	for text in finished:
		await Transition.story_text(text, 1.6)
	day_changed.emit(day)
	Save.save_game()
	await Transition.fade_in(0.8)
	if player:
		player.input_locked = false
	_sleeping = false


# ------------------------------------------------------------------ sauvegarde

func serialize() -> Dictionary:
	var f := {}
	for k in flags:
		f[String(k)] = flags[k]
	return {"flags": f, "day": day, "harvested": harvested.duplicate()}


func deserialize(data: Dictionary) -> void:
	flags.clear()
	for k in data.get("flags", {}):
		flags[StringName(k)] = bool(data["flags"][k])
	day = int(data.get("day", 1))
	harvested = data.get("harvested", {}).duplicate()
