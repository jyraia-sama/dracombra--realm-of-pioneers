extends Level
## Entrée de la caverne (prologue).
## Introduction : poursuivi par les gardes d'Elysia, le héros fait s'effondrer
## l'entrée derrière lui et se retrouve piégé dans l'obscurité.

const FALLING_ROCK := preload("res://scenes/props/falling_rock.tscn")

## Le calque qui contient les éboulis de l'entrée.
@export var decor_layer: TileMapLayer
## Les cases d'éboulis qui tombent pendant l'introduction.
@export var rubble_cells: Array[Vector2i] = []
## Position du guerrier quand l'introduction a déjà été vue (après une mort).
@export var respawn_position: Vector2 = Vector2.ZERO

var _rubble_tiles: Dictionary[Vector2i, Vector2i] = {}


func _ready() -> void:
	super()
	# Sol et parois dessinés (bords naturels, falaises).
	GroundPainter.apply(self, $Ground, &"cave", $Walls)
	if Game.has_flag(&"prologue_intro_done"):
		get_player().global_position = respawn_position
		return
	# L'éboulement n'a pas encore eu lieu : on retire les éboulis de la carte.
	for cell in rubble_cells:
		_rubble_tiles[cell] = decor_layer.get_cell_atlas_coords(cell)
		decor_layer.erase_cell(cell)
	_play_intro.call_deferred()


func _play_intro() -> void:
	var player := get_player()
	player.input_locked = true

	# Le héros s'engouffre dans la grotte, les gardes sur ses talons.
	Narration.say("« Il est entré dans la grotte ! Ne le laissez pas s'échapper ! »", 2.4)
	player.scripted_direction = Vector2.RIGHT
	await get_tree().create_timer(0.9).timeout
	player.scripted_direction = Vector2.ZERO

	# Il se retourne et frappe les étais de l'entrée.
	await get_tree().create_timer(0.4).timeout
	player.face(Vector2.LEFT)
	await get_tree().create_timer(0.3).timeout
	player.perform_attack()
	shake_camera(1.5, 0.8)
	await get_tree().create_timer(0.6).timeout

	# La chute des roches.
	shake_camera(3.0, 2.2)
	var cells := rubble_cells.duplicate()
	cells.shuffle()
	for cell in cells:
		_drop_rubble(cell)
		await get_tree().create_timer(0.07).timeout
	await get_tree().create_timer(1.1).timeout
	shake_camera(5.0, 0.6)

	await Narration.say("Pour couper court à la traque, il avait provoqué l'effondrement de l'entrée.", 3.2)
	await Narration.say("Les gardes étaient repoussés... mais il était piégé dans l'obscurité, isolé du monde.", 3.4)
	player.input_locked = false
	Game.set_flag(&"prologue_intro_done")
	Narration.say("Au loin, une faible lueur magique semblait l'appeler.", 3.5)


func _drop_rubble(cell: Vector2i) -> void:
	var rock: FallingRock = FALLING_ROCK.instantiate()
	rock.stays = true
	rock.damage = 0
	rock.shake_strength = 2.0
	rock.fall_time = randf_range(0.5, 0.9)
	rock.position = cell_to_world(decor_layer, cell) + Vector2(0.0, Game.TILE_SIZE / 2.0)
	add_child(rock)
	rock.landed.connect(_on_rubble_landed.bind(rock, cell), CONNECT_ONE_SHOT)


func _on_rubble_landed(rock: FallingRock, cell: Vector2i) -> void:
	# Le rocher tombé devient un éboulis de la carte, avec sa collision.
	decor_layer.set_cell(cell, 0, _rubble_tiles[cell])
	rock.queue_free()
