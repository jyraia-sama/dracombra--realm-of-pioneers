class_name DungeonApproach
extends Node2D
## L'entrée des Abysses de Dracombra, au bout de la route du nord : une allée de piliers
## mène à l'escalier qui s'enfonce sous la ville (voir DONJON.md).
## Le bâtiment d'entrée n'est pas encore dessiné : escalier dessiné par le code, encadré
## de piliers et de braseros existants (PROVISOIRE).

const PILLAR := preload("res://scenes/props/ruins/pillar.tscn")
const BRAZIER := preload("res://scenes/props/ruins/rune_brazier.tscn")
const DUNGEON := "res://scenes/levels/dungeon/dungeon.tscn"

## Bas de l'escalier d'entrée (px monde), au bout de la route du nord.
const ENTRANCE := Vector2(1600, 176)
## Allée de piliers : écart au centre de la route, premier et dernier pilier, pas.
const ALLEY_HALF_WIDTH := 38.0
const ALLEY_FROM_Y := 236.0
const ALLEY_TO_Y := 560.0
const ALLEY_STEP := 64.0


## Construit l'entrée dans le niveau de la ville (avant Level._ready, pour le point d'arrivée).
static func build(level: Node2D) -> DungeonApproach:
	var a := DungeonApproach.new()
	a.name = "DungeonApproach"
	a.y_sort_enabled = true
	level.add_child(a)
	a._clear_props(level)
	a._build()
	var spawns := level.get_node_or_null("Spawns")
	if spawns:
		var m := Marker2D.new()
		m.name = "from_dungeon"
		m.position = ENTRANCE + Vector2(0, 28)
		spawns.add_child(m)
	return a


## Retire les ruines, arbres et herbes qui encombrent l'allée.
func _clear_props(level: Node2D) -> void:
	var props := level.get_node_or_null("Props")
	if props == null:
		return
	var area := Rect2(ENTRANCE.x - 70, ENTRANCE.y - 40, 140, ALLEY_TO_Y - ENTRANCE.y + 60)
	for p in props.get_children():
		var n := p as Node2D
		if n and area.has_point(n.position):
			n.queue_free()


func _build() -> void:
	var stairs := DungeonStairs.new()
	stairs.name = "Entrance"
	stairs.position = ENTRANCE
	add_child(stairs)
	stairs.setup(true, true)
	stairs.interact.prompt = "Entrer dans les Abysses"
	stairs.used.connect(_enter)
	for side in [-1.0, 1.0]:
		var pillar: Node2D = PILLAR.instantiate()
		pillar.position = ENTRANCE + Vector2(side * 30.0, 2.0)
		add_child(pillar)
		var brazier: Node2D = BRAZIER.instantiate()
		brazier.position = ENTRANCE + Vector2(side * 52.0, 14.0)
		add_child(brazier)
		var y := ALLEY_FROM_Y
		while y <= ALLEY_TO_Y:
			var p: Node2D = PILLAR.instantiate()
			p.position = Vector2(ENTRANCE.x + side * ALLEY_HALF_WIDTH, y)
			add_child(p)
			y += ALLEY_STEP


func _enter() -> void:
	if not Game.has_flag(&"prologue_done"):
		return
	var i := await Choice.ask("Les Abysses de Dracombra",
		"Un escalier s'enfonce sous les ruines. Un air froid en remonte, chargé d'éclats d'obsidienne.",
		["Descendre (étage 1)", "Plus tard"])
	if i == 0:
		Game.dungeon_floor = 1
		Transition.change_scene(DUNGEON)
