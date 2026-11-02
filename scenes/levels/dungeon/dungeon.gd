extends Level
## Un étage des Abysses de Dracombra, tiré au sort à chaque entrée (voir DONJON.md).
## Zone 1 : la caverne d'obsidienne, étages 1 à 3. Zone 2 : les cryptes des pionniers,
## étages 4 à 7 (salles construites, squelettes, feux follets, salle secrète).
##
## Déroulé : salle de départ (escalier vers la ville) → salles de combat (les passages se
## ferment, il faut vaincre tous les monstres) et salles calmes → salle de l'escalier,
## gardée ; une fois nettoyée, l'escalier s'ouvre : descendre ou rentrer en ville.

const SLIME := preload("res://scenes/enemies/slime/slime.tscn")
const SPIDER := preload("res://scenes/enemies/obsidian_spider/obsidian_spider.tscn")
const GOBLIN := preload("res://scenes/enemies/rock_goblin/rock_goblin.tscn")
const LIGHT_TEX := preload("res://assets/lights/light_radial.tres")
const CITY := "res://scenes/levels/dracombra/dracombra.tscn"
const SELF := "res://scenes/levels/dungeon/dungeon.tscn"

## Décors de la caverne : [scène, poids, contre un mur ?].
const DECOR := [
	["res://scenes/props/cave/crystal_purple.tscn", 3, true],
	["res://scenes/props/cave/crystal_purple_small.tscn", 3, false],
	["res://scenes/props/cave/crystal_purple_large.tscn", 1, true],
	["res://scenes/props/cave/crystal_blue_small.tscn", 2, false],
	["res://scenes/props/cave/stalagmite.tscn", 3, true],
	["res://scenes/props/cave/stalagmite_small.tscn", 3, false],
	["res://scenes/props/cave/stalagmite_large.tscn", 1, true],
	["res://scenes/props/cave/rocks.tscn", 2, true],
	["res://scenes/props/cave/rocks_small.tscn", 3, false],
	["res://scenes/props/cave/rock_fragments.tscn", 3, false],
	["res://scenes/props/cave/mushrooms.tscn", 2, true],
	["res://scenes/props/cave/skull_bones.tscn", 1, false],
	["res://scenes/props/cave/roots_a.tscn", 1, true],
]

## Décors des cryptes : [scène, poids, contre un mur ?].
const DECOR_CRYPT := [
	["res://scenes/props/crypt/sarcophagus.tscn", 2, true],
	["res://scenes/props/crypt/sarcophagus_open.tscn", 1, true],
	["res://scenes/props/crypt/candles.tscn", 3, false],
	["res://scenes/props/crypt/candelabra.tscn", 2, true],
	["res://scenes/props/crypt/cobweb.tscn", 2, true],
	["res://scenes/props/crypt/bone_pile.tscn", 2, false],
	["res://scenes/props/crypt/pillar_broken.tscn", 2, true],
	["res://scenes/props/crypt/urn.tscn", 2, true],
	["res://scenes/props/cave/skull_bones.tscn", 1, false],
	["res://scenes/props/cave/rock_fragments.tscn", 1, false],
]

## Zones du donjon (les zones s'allongent en descendant). tier : palier de l'équipement ;
## look : sol et murs (GroundPainter) ; flag : posé quand le boss de la zone est vaincu.
const ZONES := [
	{"name": "Caverne d'obsidienne", "floors": 3, "look": &"cave", "tier": 1, "built": false,
		"darkness": Color(0.3, 0.27, 0.4), "boss": "La reine araignée d'obsidienne", "flag": &"abyss_zone1_queen"},
	{"name": "Cryptes des pionniers", "floors": 4, "look": &"crypt", "tier": 2, "built": true,
		"darkness": Color(0.24, 0.25, 0.34), "boss": "Le Gardien des cryptes", "flag": &"abyss_zone2_guardian"},
]

var gen := DungeonGen.new()
var rng := RandomNumberGenerator.new()
var floor_number := 1

## Salle où se trouve le héros (position sur la grille).
var _room := Vector2i(-1, -1)
var _cleared: Dictionary = {}       # salle -> true
var _gates: Dictionary = {}         # salle -> Array[DungeonGate]
var _alive: Array[Node2D] = []      # monstres du combat en cours
var _fight_room := Vector2i(-1, -1)
var _stairs_down: DungeonStairs
var _spawning := false
var _boss_bar: CanvasLayer
## Salles déjà visitées (les autres restent cachées sur les cartes).
var _visited: Dictionary = {}
## Cases occupées par un décor ou un filon.
var _taken: Dictionary = {}

@onready var ground: TileMapLayer = $Ground
@onready var walls: TileMapLayer = $Walls
@onready var props: Node2D = $Props


func _ready() -> void:
	floor_number = maxi(1, Game.dungeon_floor)
	Game.dungeon_floor = floor_number
	# Début d'un passage : on retient le contenu du sac (règle des 25 % à la mort).
	if Game.dungeon_run.is_empty():
		Game.dungeon_run = {"start": Inventory.serialize()}
	rng.randomize()
	gen.built = bool(zone()["built"])
	gen.secret_room = zone_index() >= 1
	gen.generate(rng, 5 + floor_number + rng.randi_range(0, 1))
	$Darkness.color = zone()["darkness"]
	_paint_tiles()
	_place_start_and_stairs()
	_decorate()
	_furnish()
	super()
	GroundPainter.apply(self, ground, zone()["look"], walls)
	_place_secret_wall()
	var player := get_player()
	_add_hero_light(player)
	player.health.died.connect(_on_hero_died)
	if _camera:
		_camera.limit_smoothed = true
	_update_room(true)
	if floor_number == first_floor() and zone_index() > 0:
		Narration.title_card(zone_name(), "Les Abysses de Dracombra — étage %d" % floor_number, 2.5)
	else:
		Narration.say("%s — étage %d" % [zone_name(), floor_number], 2.5)


## Pas de sauvegarde dans le donjon : il change à chaque entrée (voir Save.save_game).
func allows_save() -> bool:
	return false


## Brouillard des cartes (LevelMap) : les salles pas encore visitées.
func map_hidden_rects() -> Array:
	var out: Array = []
	for pos in gen.rooms:
		if not _visited.has(pos):
			out.append(DungeonGen.slot_rect(pos))
	return out


## Indice de la zone de l'étage (0 = caverne, 1 = cryptes...).
static func zone_of(floor_n: int) -> int:
	var last := 0
	for i in ZONES.size():
		last += int(ZONES[i]["floors"])
		if floor_n <= last:
			return i
	return ZONES.size() - 1


## Premier étage d'une zone.
static func zone_first_floor(z: int) -> int:
	var f := 1
	for i in z:
		f += int(ZONES[i]["floors"])
	return f


func zone_index() -> int:
	return zone_of(floor_number)


func zone() -> Dictionary:
	return ZONES[zone_index()]


func zone_name() -> String:
	return zone()["name"]


func first_floor() -> int:
	return zone_first_floor(zone_index())


## Dernier étage de la zone actuelle (celui du boss).
func last_floor() -> int:
	return first_floor() + int(zone()["floors"]) - 1


## Dernier étage creusé des Abysses.
static func deepest_floor() -> int:
	return zone_first_floor(ZONES.size() - 1) + int(ZONES[ZONES.size() - 1]["floors"]) - 1


# ------------------------------------------------------------------ construction

func _paint_tiles() -> void:
	for cell in gen.floor_cells:
		ground.set_cell(cell, 0, Vector2i(rng.randi_range(0, 5), 2))
	# Murs : toute case non-sol des salles utilisées, plus une bordure.
	for pos in gen.rooms:
		var r := DungeonGen.slot_rect(pos).grow(1)
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var c := Vector2i(x, y)
				if not gen.floor_cells.has(c) and walls.get_cell_source_id(c) == -1:
					walls.set_cell(c, 0, Vector2i(0, 0))


func _cell_pos(cell: Vector2i) -> Vector2:
	return ground.to_global(ground.map_to_local(cell))


func _place_start_and_stairs() -> void:
	var up := DungeonStairs.new()
	up.name = "StairsUp"
	up.position = _cell_pos(DungeonGen.slot_center(gen.start)) + Vector2(0, -24)
	props.add_child(up)
	up.setup(false, true)
	up.used.connect(_on_stairs_up)
	# Le héros arrive juste sous l'escalier de la ville.
	var spawn := Marker2D.new()
	spawn.name = "arrive"
	spawn.position = up.position + Vector2(0, 26)
	$Spawns.add_child(spawn)
	Game.next_spawn = &"arrive"
	_stairs_down = DungeonStairs.new()
	_stairs_down.name = "StairsDown"
	_stairs_down.position = _cell_pos(DungeonGen.slot_center(gen.stairs)) + Vector2(0, 8)
	props.add_child(_stairs_down)
	_stairs_down.setup(true, false)
	_stairs_down.used.connect(_on_stairs_down)


func _decorate() -> void:
	var decor: Array = DECOR_CRYPT if zone()["look"] == &"crypt" else DECOR
	var total := 0
	for d in decor:
		total += int(d[1])
	var taken := _taken
	for pos in gen.rooms:
		var center := DungeonGen.slot_center(pos)
		var count := rng.randi_range(5, 10)
		var tries := 0
		while count > 0 and tries < 200:
			tries += 1
			var r := DungeonGen.inner_rect(pos)
			var cell := Vector2i(rng.randi_range(r.position.x, r.end.x - 1), rng.randi_range(r.position.y, r.end.y - 1))
			if not _free_for_decor(cell, center, taken):
				continue
			var pick := rng.randi() % total
			var spec: Array = decor[0]
			for d in decor:
				pick -= int(d[1])
				if pick < 0:
					spec = d
					break
			if spec[2] and _wall_distance(cell) > 2:
				continue
			var node: Node2D = load(spec[0]).instantiate()
			node.position = _cell_pos(cell) + Vector2(rng.randf_range(-4, 4), rng.randf_range(-3, 3)).round()
			if rng.randf() < 0.5 and node is Node2D:
				var s := node.get_node_or_null("Sprite2D") as Sprite2D
				if s:
					s.flip_h = true
			# Décor du donjon sans collision : les salles sont des arènes, un rocher près
			# d'un mur pouvait coincer le héros.
			var body := node.get_node_or_null("Body")
			if body:
				body.queue_free()
			props.add_child(node)
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					taken[cell + Vector2i(dx, dy)] = true
			count -= 1


## Pas de décor sur les axes entre le centre et les portes, ni au centre.
func _free_for_decor(cell: Vector2i, center: Vector2i, taken: Dictionary) -> bool:
	if not gen.floor_cells.has(cell) or gen.lane_cells.has(cell) or taken.has(cell):
		return false
	if absi(cell.x - center.x) <= 2 or absi(cell.y - center.y) <= 2:
		return false
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if not gen.floor_cells.has(cell + Vector2i(dx, dy)):
				return false
	return true


func _wall_distance(cell: Vector2i) -> int:
	for d in range(1, 4):
		for dir in DungeonGen.DIRS:
			if not gen.floor_cells.has(cell + dir * d):
				return d
	return 99


## Salles spéciales (repos, trésor) et filons de ressources éparpillés.
func _furnish() -> void:
	for pos in gen.rooms:
		var kind: int = gen.rooms[pos]["kind"]
		var c := _cell_pos(DungeonGen.slot_center(pos))
		match kind:
			DungeonGen.Kind.REST:
				var fire := DungeonRoomProps.campfire()
				fire.position = c + Vector2(8, 0)
				props.add_child(fire)
				var m := DungeonRoomProps.merchant()
				m.position = c + Vector2(-28, -6)
				props.add_child(m)
			DungeonGen.Kind.TREASURE:
				var chest := DungeonRoomProps.chest(floor_number, int(zone()["tier"]))
				chest.position = c
				props.add_child(chest)
			DungeonGen.Kind.SECRET:
				var rich := DungeonRoomProps.chest(floor_number, int(zone()["tier"]), true)
				rich.position = c + Vector2(40, 0)
				props.add_child(rich)
				# Quête du Paladin : l'autel du bouclier sacré (étages 5 à 7).
				if zone_index() == 1 and floor_number >= 5 and ClassQuests.active(&"paladin") \
						and not Game.has_flag(ClassQuests.flag(&"paladin", "ready")):
					var shrine := ClassQuests.shrine()
					shrine.position = c + Vector2(-20, 0)
					props.add_child(shrine)
		if kind == DungeonGen.Kind.START:
			continue
		var count := rng.randi_range(1, 3)
		var tries := 0
		while count > 0 and tries < 100:
			tries += 1
			var r := DungeonGen.inner_rect(pos)
			var cell := Vector2i(rng.randi_range(r.position.x, r.end.x - 1), rng.randi_range(r.position.y, r.end.y - 1))
			if not _free_for_decor(cell, DungeonGen.slot_center(pos), _taken) or _wall_distance(cell) > 2:
				continue
			var ore := DungeonRoomProps.ore(rng, int(zone()["tier"]))
			ore.position = _cell_pos(cell)
			props.add_child(ore)
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					_taken[cell + Vector2i(dx, dy)] = true
			count -= 1


## Le mur fissuré qui cache la salle secrète (cryptes).
func _place_secret_wall() -> void:
	if gen.secret == Vector2i(-1, -1):
		return
	var dir := gen.secret - gen.secret_from
	var wall := CrackedWall.new()
	wall.name = "MurFissure"
	wall.setup(DungeonGen.door_cells(gen.secret_from, dir), _cell_pos)
	props.add_child(wall)
	_secret_wall = wall
	_nav_dirty = true
	wall.broken.connect(func() -> void:
		_secret_wall = null
		_nav_dirty = true
		Narration.say("Le mur s'écroule : une salle oubliée des pionniers !", 3.0)
		BugReport.log_event("Salle secrète ouverte"))


var _secret_wall: CrackedWall


func _add_hero_light(player: Player) -> void:
	if player == null or player.get_node_or_null("HeroLight"):
		return
	var light := PointLight2D.new()
	light.name = "HeroLight"
	light.position = Vector2(0, -16)
	light.color = Color(1, 0.86, 0.7)
	light.texture = LIGHT_TEX
	light.texture_scale = 2.2
	player.add_child(light)


# ------------------------------------------------------------------ salles et combats

func _process(delta: float) -> void:
	super(delta)
	_update_room(false)
	if _fight_room != Vector2i(-1, -1):
		_check_fight()


func _update_room(force: bool) -> void:
	var player := get_player()
	if player == null:
		return
	var cell := ground.local_to_map(ground.to_local(player.global_position))
	var room := DungeonGen.slot_of(cell)
	if not gen.rooms.has(room):
		return
	if room != _room or force:
		_room = room
		_visited[room] = true
		_limit_to_room(room)
	# Le combat se déclenche quand le héros est bien entré (pas encore dans le passage).
	var kind: int = gen.rooms[room]["kind"]
	if (kind == DungeonGen.Kind.COMBAT or kind == DungeonGen.Kind.STAIRS) and not _cleared.has(room) \
			and _fight_room == Vector2i(-1, -1) and DungeonGen.inner_rect(room).grow(-2).has_point(cell):
		_start_fight(room)


func _limit_to_room(room: Vector2i) -> void:
	if _camera == null:
		return
	var r := DungeonGen.slot_rect(room)
	var t := Game.TILE_SIZE
	_camera.limit_left = r.position.x * t
	_camera.limit_top = r.position.y * t
	_camera.limit_right = r.end.x * t
	_camera.limit_bottom = r.end.y * t


func _start_fight(room: Vector2i) -> void:
	_fight_room = room
	_spawning = true
	var gates: Array = []
	for dir in gen.rooms[room]["doors"]:
		var gate := DungeonGate.new()
		gate.setup(DungeonGen.door_cells(room, dir), dir)
		props.add_child(gate)
		gate.close()
		gates.append(gate)
	_gates[room] = gates
	_gather_companions(room)
	_nav_dirty = true
	Fx.shake(1.5, 0.2)
	if is_boss_room(room):
		_start_boss(room)
		return
	# Les monstres surgissent après un court instant, annoncés par un nuage de poussière.
	var spots := _spawn_spots(room, _enemy_count(room))
	for spot in spots:
		PixelBurst.spawn(self, spot, PixelBurst.DUST, Vector2.ZERO, 4.0)
	await get_tree().create_timer(0.7).timeout
	if not is_inside_tree():
		return
	for spot in spots:
		var enemy := _make_enemy()
		enemy.position = spot
		add_child(enemy)
		_alive.append(enemy)
		PixelBurst.spawn(self, spot, PixelBurst.SMOKE, Vector2.ZERO, 0.8)
	_spawning = false


## Les compagnons restés dans le couloir rejoignent le héros avant que les grilles ne bloquent.
func _gather_companions(room: Vector2i) -> void:
	var player := get_player()
	if player == null:
		return
	var inner := DungeonGen.inner_rect(room).grow(-1)
	for c in get_tree().get_nodes_in_group("companions"):
		var comp := c as Companion
		var cell := ground.local_to_map(ground.to_local(comp.global_position))
		if not inner.has_point(cell):
			comp.teleport_near(player.global_position)


# ------------------------------------------------------------------ chemins (compagnons)

var _astar: AStarGrid2D
var _nav_dirty := true


## Chemin entre deux points en évitant les murs et les grilles fermées (pour les compagnons).
## Renvoie une liste de points (vide si pas de chemin).
func nav_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	if _astar == null or _nav_dirty:
		_build_nav()
	var a := ground.local_to_map(ground.to_local(from))
	var b := ground.local_to_map(ground.to_local(to))
	if not _astar.is_in_boundsv(a) or not _astar.is_in_boundsv(b) or _astar.is_point_solid(b):
		return PackedVector2Array()
	if _astar.is_point_solid(a):
		return PackedVector2Array([to])
	var cells := _astar.get_id_path(a, b, true)
	var out := PackedVector2Array()
	for i in range(1, cells.size()):
		out.append(_cell_pos(cells[i]))
	return out


func _build_nav() -> void:
	_nav_dirty = false
	var used := Rect2i()
	var first := true
	for cell in gen.floor_cells:
		if first:
			used = Rect2i(cell, Vector2i.ONE)
			first = false
		else:
			used = used.expand(cell)
	used = used.grow(1)
	_astar = AStarGrid2D.new()
	_astar.region = used
	_astar.cell_size = Vector2.ONE
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.update()
	_astar.fill_solid_region(used, true)
	for cell in gen.floor_cells:
		_astar.set_point_solid(cell, false)
	for cell in walls.get_used_cells():
		if _astar.is_in_boundsv(cell):
			_astar.set_point_solid(cell, true)
	if is_instance_valid(_secret_wall):
		for cell in _secret_wall.cells:
			if _astar.is_in_boundsv(cell):
				_astar.set_point_solid(cell, true)
	for room in _gates:
		for gate in _gates[room]:
			if is_instance_valid(gate) and gate.closed:
				for cell in gate.cells:
					if _astar.is_in_boundsv(cell):
						_astar.set_point_solid(cell, true)


## Au dernier étage de la zone, la salle de l'escalier est le repaire de la reine.
func is_boss_room(room: Vector2i) -> bool:
	return floor_number >= last_floor() and room == gen.stairs


func _start_boss(room: Vector2i) -> void:
	await Narration.title_card(zone()["boss"], zone_name(), 2.0)
	if not is_inside_tree():
		return
	if zone_index() == 1:
		_start_guardian(room)
		return
	var queen := QueenSpider.create(floor_number + Game.abyss_clears)
	queen.position = _cell_pos(DungeonGen.slot_center(room) + Vector2i(-7, -3))
	add_child(queen)
	_alive.append(queen)
	queen.spawned.connect(func(n: Node2D) -> void: _alive.append(n))
	queen.health.died.connect(_on_queen_died.bind(queen), CONNECT_ONE_SHOT)
	_boss_bar = BossBar.create("Reine araignée d'obsidienne", queen.health)
	add_child(_boss_bar)
	PixelBurst.spawn(self, queen.position, PixelBurst.SMOKE, Vector2.ZERO, 2.0)
	Fx.shake(4.0, 0.5)
	_spawning = false


func _start_guardian(room: Vector2i) -> void:
	var lvl := floor_number + int(Game.zone_clears.get(1, 0))
	var boss := CryptGuardian.new()
	Combat.set_level(boss, lvl)
	boss.position = _cell_pos(DungeonGen.slot_center(room) + Vector2i(0, -4))
	add_child(boss)
	_alive.append(boss)
	boss.spawned.connect(func(n: Node2D) -> void: _alive.append(n))
	boss.health.died.connect(_on_guardian_died.bind(boss), CONNECT_ONE_SHOT)
	_boss_bar = BossBar.create("Gardien des cryptes", boss.health)
	add_child(_boss_bar)
	PixelBurst.spawn(self, boss.position, PixelBurst.SMOKE, Vector2.ZERO, 2.5)
	Fx.shake(4.0, 0.5)
	Narration.say("Son bouclier arrête les coups de face : frappez-le de dos, ou quand il manque son coup.", 4.0)
	_spawning = false


## Butin du Gardien : une pièce du palier 2 garantie (souvent rare ou mieux) et des ressources.
func _on_guardian_died(boss: Node2D) -> void:
	var at := boss.global_position
	DungeonRoomProps.drop(self, Loot.piece(2, [0, 60, 32, 8]), 1, at)
	for entry in [[&"gold", 70, 110], [&"silver_ore", 3, 6], [&"ancient_bone", 3, 5], [&"spectral_essence", 2, 4], [&"linen_wraps", 2, 4]]:
		DungeonRoomProps.drop(self, Inventory.item_by_id(entry[0]), rng.randi_range(entry[1], entry[2]), at)
	Fx.shake(5.0, 0.6)
	Fx.hit_stop(0.2)
	var first := not Game.has_flag(&"abyss_zone2_guardian")
	Game.set_flag(&"abyss_zone2_guardian")
	Game.zone_clears[1] = int(Game.zone_clears.get(1, 0)) + 1
	if first:
		Narration.say("Le Gardien des cryptes tombe en poussière. Le passage vers les profondeurs est à vous.", 4.5)
	if _boss_bar:
		_boss_bar.queue_free()


## Butin de la reine : une pièce du palier 1 garantie (≈ 25 % rare) et beaucoup de ressources.
func _on_queen_died(queen: Node2D) -> void:
	var at := queen.global_position
	DungeonRoomProps.drop(self, Loot.piece(1, [0, 75, 25]), 1, at)
	for entry in [[&"gold", 40, 60], [&"chitin", 3, 5], [&"silk", 3, 5], [&"mana_crystal", 1, 2], [&"obsidian_shard", 3, 6]]:
		DungeonRoomProps.drop(self, Inventory.item_by_id(entry[0]), rng.randi_range(entry[1], entry[2]), at)
	Fx.shake(5.0, 0.6)
	Fx.hit_stop(0.2)
	# Lysia, prisonnière de la reine, attend dans un cocon (tant qu'on ne l'a pas libérée).
	if not Lysia.rescued():
		var c := Lysia.cocoon()
		c.position = _cell_pos(DungeonGen.slot_center(gen.stairs) + Vector2i(7, -3))
		props.add_child(c)
	var first := not Game.has_flag(&"abyss_zone1_queen")
	Game.set_flag(&"abyss_zone1_queen")
	Game.abyss_clears += 1
	if first:
		Narration.say("La reine est vaincue ! Un raccourci vers les profondeurs s'est ouvert à l'entrée des Abysses.", 4.5)
	if _boss_bar:
		_boss_bar.queue_free()


func _enemy_count(room: Vector2i) -> int:
	# Un monstre de plus par compagnon.
	var base := 2 + floor_number + Roster.party_members().size()
	if gen.rooms[room]["kind"] == DungeonGen.Kind.STAIRS:
		base += 2
	return base + rng.randi_range(0, 1)


func _spawn_spots(room: Vector2i, count: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var player := get_player()
	var r := DungeonGen.inner_rect(room).grow(-1)
	var tries := 0
	while out.size() < count and tries < 400:
		tries += 1
		var cell := Vector2i(rng.randi_range(r.position.x, r.end.x - 1), rng.randi_range(r.position.y, r.end.y - 1))
		if not gen.floor_cells.has(cell) or gen.lane_cells.has(cell):
			continue
		var p := _cell_pos(cell)
		if player and p.distance_to(player.global_position) < 6.0 * Game.TILE_SIZE:
			continue
		var close := false
		for o in out:
			if o.distance_to(p) < 2.0 * Game.TILE_SIZE:
				close = true
		if not close:
			out.append(p)
	return out


## Un monstre adapté à l'étage : son niveau est celui de l'étage.
func _make_enemy() -> Node2D:
	var roll := rng.randf()
	var scene: PackedScene = SLIME
	var enemy: Node2D
	if zone_index() >= 1:
		enemy = _make_crypt_enemy(roll)
	else:
		match floor_number:
			1:
				scene = SPIDER if roll < 0.45 else SLIME
			2:
				scene = GOBLIN if roll < 0.3 else (SPIDER if roll < 0.7 else SLIME)
			_:
				scene = GOBLIN if roll < 0.4 else (SPIDER if roll < 0.85 else SLIME)
		enemy = scene.instantiate()
	var health := enemy.get_node_or_null("Health") as HealthComponent
	# Niveau du monstre = étage (voir Combat) : plus de PV, de dégâts et d'XP.
	Combat.set_level(enemy, floor_number)
	# Avec des compagnons, les monstres sont plus solides (+30 % de PV par compagnon).
	var party := Roster.party_members().size()
	if health and party > 0:
		health.max_health = int(ceil(health.max_health * (1.0 + 0.3 * party)))
		health.current_health = health.max_health
	# Les monstres du donjon chassent dans toute la salle.
	for prop in ["detection_radius_tiles", "lose_interest_radius_tiles"]:
		if prop in enemy:
			enemy.set(prop, maxf(enemy.get(prop), 14.0))
	# De l'or en plus du butin habituel, un peu plus en descendant.
	if health:
		health.died.connect(func() -> void:
			if not is_instance_valid(enemy):
				return
			if randf() < 0.7:
				DungeonRoomProps.drop(self, Inventory.item_by_id(&"gold"), rng.randi_range(1, 2 + floor_number), enemy.global_position)
			# Parfois une potion d'endurance ou de mana (selon la classe du héros).
			if randf() < 0.08:
				DungeonRoomProps.drop(self, Inventory.item_by_id(Hotbar.energy_potion()), 1, enemy.global_position)
			# Rarement, une pièce d'équipement du palier de la zone.
			if randf() < 0.03 + 0.01 * (floor_number - first_floor() + 1):
				DungeonRoomProps.drop(self, Loot.piece(int(zone()["tier"]), [60, 30, 10]), 1, enemy.global_position)
			# Ressources des monstres des cryptes (palier 2).
			for entry in _crypt_drops(enemy):
				if randf() < float(entry[1]):
					DungeonRoomProps.drop(self, Inventory.item_by_id(entry[0]), rng.randi_range(1, int(entry[2])), enemy.global_position)
			# Les araignées laissent de la chitine et de la soie (palier 1).
			if scene == SPIDER:
				if randf() < 0.55:
					DungeonRoomProps.drop(self, Inventory.item_by_id(&"chitin"), 1, enemy.global_position)
				if randf() < 0.45:
					DungeonRoomProps.drop(self, Inventory.item_by_id(&"silk"), rng.randi_range(1, 2), enemy.global_position), CONNECT_ONE_SHOT)
	return enemy


## Monstres des cryptes, selon l'étage (4 : squelettes et rats ; ensuite archers et feux follets).
func _make_crypt_enemy(roll: float) -> Node2D:
	var deep := floor_number - first_floor()
	if deep == 0:
		if roll < 0.45:
			return Skeleton.new()
		return CryptRat.new() if roll < 0.8 else SkeletonArcher.new()
	if roll < 0.35:
		return Skeleton.new()
	if roll < 0.6:
		return SkeletonArcher.new()
	return Wisp.new() if roll < 0.8 else CryptRat.new()


## [objet, chance, maximum] laissés par un monstre des cryptes.
static func _crypt_drops(enemy: Node) -> Array:
	if enemy is SkeletonArcher:
		return [[&"ancient_bone", 0.6, 2]]
	if enemy is Skeleton:
		return [[&"ancient_bone", 0.6, 2], [&"linen_wraps", 0.3, 1]]
	if enemy is Wisp:
		return [[&"spectral_essence", 0.7, 1]]
	if enemy is CryptRat:
		return [[&"crypt_leather", 0.55, 1]]
	return []


func _check_fight() -> void:
	for i in range(_alive.size() - 1, -1, -1):
		var e := _alive[i]
		var h := e.get_node_or_null("Health") as HealthComponent if is_instance_valid(e) else null
		if not is_instance_valid(e) or h == null or h.is_dead():
			_alive.remove_at(i)
	if not _alive.is_empty():
		return
	if _spawning:
		return
	var room := _fight_room
	_cleared[room] = true
	_fight_room = Vector2i(-1, -1)
	for gate in _gates.get(room, []):
		gate.open()
	_nav_dirty = true
	if room == gen.stairs:
		_stairs_down.reveal()
		Narration.say("Le passage vers les profondeurs s'ouvre.", 2.5)
	else:
		Narration.say("Salle nettoyée.", 1.5)


# ------------------------------------------------------------------ escaliers

func _on_stairs_up() -> void:
	if props.get_node_or_null("Cocon") != null and not Lysia.rescued():
		await Ysolde.lines(Hero.hero_name, ["Je ne peux pas laisser cette personne prisonnière de la soie."])
		return
	var i := await Choice.ask("Remonter", "Rentrer à Dracombra ?", ["Remonter en ville", "Rester"])
	if i == 0:
		_leave_to_city()


func _on_stairs_down() -> void:
	# Tant que Lysia est prisonnière de son cocon, on ne descend pas.
	if props.get_node_or_null("Cocon") != null and not Lysia.rescued():
		await Ysolde.lines(Hero.hero_name, ["Ce cocon remue encore... Il y a quelqu'un là-dedans. Je ne peux pas partir sans l'avoir libéré."])
		return
	if floor_number >= deepest_floor():
		var j := await Choice.ask("Fond des %s" % zone_name(),
			"Plus bas, la galerie est effondrée : la zone suivante des Abysses n'est pas encore creusée.\n(Elle arrivera avec une prochaine étape.)",
			["Remonter en ville", "Rester"])
		if j == 0:
			_leave_to_city()
		return
	var next_zone := zone_of(floor_number + 1)
	var body := "Descendre plus profond, ou rentrer en ville avec votre butin ?"
	if next_zone != zone_index():
		body = "Un escalier taillé dans la pierre descend vers les %s.\nDescendre, ou rentrer en ville avec votre butin ?" % String(ZONES[next_zone]["name"]).to_lower()
	var i := await Choice.ask("Étage %d terminé" % floor_number, body,
		["Descendre à l'étage %d" % (floor_number + 1), "Remonter en ville", "Rester"])
	if i == 0:
		Game.dungeon_floor = floor_number + 1
		Transition.change_scene(SELF)
	elif i == 1:
		_leave_to_city()


## Mort dans le donjon : on ne garde que 25 % des ressources ramassées pendant le passage.
## L'équipement (porté ou trouvé) est conservé.
func _on_hero_died() -> void:
	var start: Dictionary = Game.dungeon_run.get("start", {})
	var lost: Array[String] = []
	for item in Inventory.get_items():
		if item.category != &"resource" and item.category != &"currency":
			continue
		var gained := Inventory.get_count(item.id) - int(start.get(String(item.id), start.get(item.id, 0)))
		if gained <= 0:
			continue
		var lose := gained - int(floor(gained * 0.25))
		if lose > 0:
			Inventory.remove_item(item, lose)
			lost.append("%d %s" % [lose, item.display_name.to_lower()])
	Game.dungeon_run = {}
	Game.dungeon_floor = 0
	if lost.is_empty():
		Game.pending_message = "Vous vous réveillez au camp, sonné."
	else:
		Game.pending_message = "Vous vous réveillez au camp. Perdu dans les Abysses (75 %% du butin) : %s." % ", ".join(lost)
	BugReport.log_event("Mort au donjon, pertes : %s" % ", ".join(lost))


func _leave_to_city() -> void:
	Game.dungeon_run = {}
	Game.dungeon_floor = 0
	Game.next_spawn = &"from_dungeon"
	Transition.change_scene(CITY)
