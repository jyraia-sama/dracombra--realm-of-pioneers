extends Level
## La salle de la guilde (à partir du palier Village) : on y gère les membres de la ville.
## - le pupitre : le registre (fiches, comportement au combat, renvoyer) ;
## - le tableau : les candidats du jour ;
## - les membres présents flânent dans la salle (on peut leur parler) ;
## - la porte en bas ramène en ville.
## Décor PROVISOIRE, entièrement dessiné par le code (plancher, murs de pierre, tapis).

const W := 22  # cases
const H := 13
const BRAZIER := preload("res://scenes/props/ruins/rune_brazier.tscn")
const CITY := "res://scenes/levels/dracombra/dracombra.tscn"

var _room: Rect2


func _ready() -> void:
	var t := float(Game.TILE_SIZE)
	_room = Rect2(0, 0, W * t, H * t)
	var floor_node := HallFloor.new()
	floor_node.room = _room
	floor_node.z_index = -1
	add_child(floor_node)
	move_child(floor_node, 0)
	_build_walls()
	_build_props()
	var spawn := Marker2D.new()
	spawn.name = "entrance"
	spawn.position = Vector2(_room.size.x / 2.0, _room.size.y - t * 1.5)
	$Spawns.add_child(spawn)
	super()
	_limit_camera_to_room()
	for m in Roster.living():
		if Roster.party.has(int(m["id"])):
			pass  # les compagnons du groupe sont aussi dans la salle (ils ne suivent pas ici)
		var npc := MemberNPC.create(m, Rect2(t * 3, t * 5, _room.size.x - t * 6, _room.size.y - t * 8))
		$Props.add_child(npc)
	Narration.say("Salle de la guilde — %d membre%s, %d place%s libre%s." % [Roster.living().size(),
		"s" if Roster.living().size() > 1 else "", maxi(0, Roster.free_beds()), "s" if Roster.free_beds() > 1 else "",
		"s" if Roster.free_beds() > 1 else ""], 3.0)


func _limit_camera_to_room() -> void:
	if _camera == null:
		return
	# La salle est plus petite que l'écran : on la centre.
	var view := Vector2(480, 270)
	var c := _room.get_center()
	var half := Vector2(maxf(_room.size.x, view.x), maxf(_room.size.y, view.y)) / 2.0
	_camera.limit_left = int(c.x - half.x)
	_camera.limit_right = int(c.x + half.x)
	_camera.limit_top = int(c.y - half.y)
	_camera.limit_bottom = int(c.y + half.y)


func _build_walls() -> void:
	var t := float(Game.TILE_SIZE)
	var body := StaticBody2D.new()
	body.name = "Walls"
	add_child(body)
	# Mur du fond (3 cases de haut), murs latéraux, mur du bas avec la porte au milieu.
	var door := t * 3.0
	var rects := [
		Rect2(0, 0, _room.size.x, t * 3.2),
		Rect2(-t, 0, t * 1.5, _room.size.y),
		Rect2(_room.size.x - t * 0.5, 0, t * 1.5, _room.size.y),
		Rect2(0, _room.size.y - t * 0.5, (_room.size.x - door) / 2.0, t),
		Rect2((_room.size.x + door) / 2.0, _room.size.y - t * 0.5, (_room.size.x - door) / 2.0, t),
	]
	for r in rects:
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = r.size
		cs.shape = shape
		cs.position = r.get_center()
		body.add_child(cs)
	# Sortie : la porte du bas.
	var exit := LevelExit.new()
	exit.name = "ExitToCity"
	exit.target_scene = CITY
	exit.spawn_id = &"from_guild_hall"
	exit.collision_layer = 0
	exit.collision_mask = 2
	exit.monitorable = false
	var ecs := CollisionShape2D.new()
	var es := RectangleShape2D.new()
	es.size = Vector2(door, t * 0.6)
	ecs.shape = es
	exit.add_child(ecs)
	exit.position = Vector2(_room.size.x / 2.0, _room.size.y + t * 0.2)
	add_child(exit)


func _build_props() -> void:
	var t := float(Game.TILE_SIZE)
	# Le comptoir : Lysia derrière (une fois libérée), sinon le registre posé sur un pupitre.
	if Lysia.rescued():
		var counter := HallCounter.new()
		counter.position = Vector2(_room.size.x * 0.3, t * 5.6)
		$Props.add_child(counter)
		var lysia := Lysia.new()
		lysia.name = "Lysia"
		lysia.position = counter.position + Vector2(0, -12)
		lysia.z_index = 0
		$Props.add_child(lysia)
	else:
		var desk := HallDesk.new()
		desk.position = Vector2(_room.size.x * 0.3, t * 5.0)
		$Props.add_child(desk)
	var board := HallBoard.new()
	board.position = Vector2(_room.size.x * 0.68, t * 3.2)
	$Props.add_child(board)
	for x in [t * 2.0, _room.size.x - t * 2.0]:
		var b: Node2D = BRAZIER.instantiate()
		b.position = Vector2(x, t * 3.6)
		$Props.add_child(b)


func is_guild_hall() -> bool:
	return true


func allows_save() -> bool:
	return true


# ------------------------------------------------------------------ décor dessiné

class HallFloor extends Node2D:
	var room: Rect2

	func _draw() -> void:
		var t := float(Game.TILE_SIZE)
		# Plancher.
		draw_rect(room, Color("6b4a32"))
		var y := t * 3.0
		var row := 0
		while y < room.size.y:
			var off := (row % 2) * t
			var x := -off
			while x < room.size.x:
				draw_rect(Rect2(x + 1, y + 1, t * 2.0 - 2, t * 0.5 - 1), Color("7d5839"))
				draw_line(Vector2(x, y), Vector2(x + t * 2.0, y), Color("4f3524"))
				x += t * 2.0
			y += t * 0.5
			row += 1
		# Tapis central.
		var rug := Rect2(room.size.x / 2.0 - t * 2.5, t * 4.0, t * 5.0, room.size.y - t * 4.0)
		draw_rect(rug, Color("5a1f2a"))
		draw_rect(rug.grow(-3), Color("8c2f3c"))
		draw_rect(rug.grow(-3), Color("d9a441"), false, 1.0)
		# Mur du fond : pierre.
		var wall := Rect2(0, 0, room.size.x, t * 3.0)
		draw_rect(wall, Color("54505e"))
		for wy in range(0, int(t * 3.0), 8):
			var shift := 8 if (wy / 8) % 2 == 1 else 0
			for wx in range(-shift, int(room.size.x), 16):
				draw_rect(Rect2(wx + 1, wy + 1, 14, 6), Color("6c6878"))
		draw_rect(Rect2(0, t * 3.0 - 3, room.size.x, 3), Color("2c2833"))
		# Bannière de la guilde au mur.
		var bx := room.size.x / 2.0
		draw_rect(Rect2(bx - 8, 4, 16, 30), Color("8c2f3c"))
		draw_colored_polygon(PackedVector2Array([Vector2(bx - 8, 34), Vector2(bx, 40), Vector2(bx + 8, 34)]), Color("8c2f3c"))
		draw_circle(Vector2(bx, 18), 4.0, Color("d9a441"))
		# Murs latéraux et bas.
		draw_rect(Rect2(-t, 0, t, room.size.y + t), Color("2c2833"))
		draw_rect(Rect2(room.size.x, 0, t, room.size.y + t), Color("2c2833"))
		var door := t * 3.0
		draw_rect(Rect2(0, room.size.y - 4, (room.size.x - door) / 2.0, 4 + t), Color("2c2833"))
		draw_rect(Rect2((room.size.x + door) / 2.0, room.size.y - 4, (room.size.x - door) / 2.0, 4 + t), Color("2c2833"))


class HallDesk extends Node2D:
	func _ready() -> void:
		var body := StaticBody2D.new()
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(30, 8)
		cs.shape = r
		cs.position = Vector2(0, -4)
		body.add_child(cs)
		add_child(body)
		var it := Interactable.new()
		it.prompt = "Registre de la guilde"
		it.radius_tiles = 2.0
		it.position = Vector2(0, 4)
		add_child(it)
		it.interacted.connect(func() -> void: await GuildRegistry.open_members())

	func _draw() -> void:
		draw_rect(Rect2(-17, -18, 34, 18), Color("2a1b12"))
		draw_rect(Rect2(-16, -17, 32, 16), Color("8a5f3c"))
		draw_rect(Rect2(-16, -17, 32, 3), Color("a8774c"))
		# Le registre ouvert et une plume.
		draw_rect(Rect2(-9, -22, 18, 7), Color("1d1622"))
		draw_rect(Rect2(-8, -21, 8, 5), Color("efe6cf"))
		draw_rect(Rect2(0, -21, 8, 5), Color("e2d8bd"))
		draw_line(Vector2(9, -24), Vector2(13, -30), Color("f4f0e8"), 1.0)


class HallCounter extends Node2D:
	func _ready() -> void:
		var body := StaticBody2D.new()
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(56, 8)
		cs.shape = r
		cs.position = Vector2(0, -4)
		body.add_child(cs)
		add_child(body)

	func _draw() -> void:
		draw_rect(Rect2(-29, -16, 58, 16), Color("2a1b12"))
		draw_rect(Rect2(-28, -15, 56, 14), Color("8a5f3c"))
		draw_rect(Rect2(-29, -18, 58, 4), Color("a8774c"))
		for x in [-20, -6, 8, 22]:
			draw_line(Vector2(x, -13), Vector2(x, -2), Color("6b4a2e"))
		# Le registre, un encrier, une pile de papiers.
		draw_rect(Rect2(-22, -23, 16, 6), Color("1d1622"))
		draw_rect(Rect2(-21, -22, 7, 4), Color("efe6cf"))
		draw_rect(Rect2(-14, -22, 7, 4), Color("e2d8bd"))
		draw_rect(Rect2(14, -22, 5, 4), Color("1d1622"))
		draw_rect(Rect2(4, -21, 8, 3), Color("efe6cf"))


class HallBoard extends Node2D:
	func _ready() -> void:
		var it := Interactable.new()
		it.prompt = "Tableau des candidats"
		it.radius_tiles = 2.2
		it.position = Vector2(0, 14)
		add_child(it)
		it.interacted.connect(func() -> void: await GuildRegistry.open_candidates())

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(-22, -30, 44, 28), Color("2a1b12"))
		draw_rect(Rect2(-21, -29, 42, 26), Color("9b7048"))
		# Une affiche par candidat du jour.
		var n := Roster.candidates.size()
		for i in n:
			var x := -16 + i * 18
			draw_rect(Rect2(x, -26, 14, 18), Color("efe6cf"))
			for l in 4:
				draw_line(Vector2(x + 2, -22 + l * 4), Vector2(x + 12, -22 + l * 4), Color("8a7f6a"))
			draw_circle(Vector2(x + 7, -26), 1.5, Color("b23a3a"))
		if n == 0:
			draw_rect(Rect2(-6, -22, 12, 10), Color(0.94, 0.9, 0.81, 0.4))
