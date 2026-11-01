class_name MemberNPC
extends CharacterBody2D
## Un membre de la guilde qui flâne (en ville ou dans la salle de la guilde).
## Dessin PROVISOIRE (silhouette bleue + couleur de classe, ou artisan en jaune).
## Parler avec lui ouvre sa fiche (registre).

var member_id := 0
## Zone de promenade, en coordonnées du monde.
var area := Rect2()

var _sprite: Sprite2D
var _anims: Dictionary
var _dirs: Array = ["bas", "haut", "droite"]
var _target := Vector2.ZERO
var _wait := 0.0
var _t := 0.0
var _facing := Vector2.DOWN


static func create(m: Dictionary, wander: Rect2) -> MemberNPC:
	var n := MemberNPC.new()
	n.member_id = int(m["id"])
	n.area = wander
	n.name = "Membre_%d" % n.member_id
	var base := Roster.sprite_path(m)
	var sheet := SheetAnimation.load_sheet(base + ".json")
	n._sprite = Sprite2D.new()
	n._sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	SheetAnimation.apply_to(n._sprite, load(base + ".png"), sheet)
	n._anims = SheetAnimation.anims_from(sheet)
	n._dirs = sheet.get("dirs", n._dirs)
	return n


func _ready() -> void:
	add_to_group("npc")
	collision_layer = 0
	collision_mask = 1
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(10, 6)
	cs.shape = r
	cs.position = Vector2(0, -3)
	add_child(cs)
	var visual := Node2D.new()
	visual.name = "Visual"
	add_child(visual)
	visual.add_child(_sprite)
	_sprite.name = "Sprite"
	var it := Interactable.new()
	it.prompt = "Parler à %s" % Roster.by_id(member_id).get("name", "?")
	it.radius_tiles = 1.4
	add_child(it)
	it.interacted.connect(_talk)
	_wait = randf_range(0.5, 3.0)
	global_position = _random_point() if area.has_area() else global_position


func _random_point() -> Vector2:
	return Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y))


func _physics_process(delta: float) -> void:
	_t += delta
	if _wait > 0.0:
		_wait -= delta
		velocity = Vector2.ZERO
		if _wait <= 0.0:
			_target = _random_point()
	else:
		var to := _target - global_position
		if to.length() < 3.0 or get_slide_collision_count() > 0 and randf() < 0.05:
			_wait = randf_range(1.5, 5.0)
			velocity = Vector2.ZERO
		else:
			velocity = to.normalized() * Game.TILE_SIZE * 1.6
			_facing = to.normalized()
	move_and_slide()
	_animate()


func _animate() -> void:
	var moving := velocity.length() > 1.0
	var anim := &"walk" if moving and _anims.has(&"walk") else &"idle"
	var dir := "droite" if absf(_facing.x) > absf(_facing.y) else ("haut" if _facing.y < 0.0 else "bas")
	var d := maxi(0, _dirs.find(dir))
	_sprite.flip_h = dir == "droite" and _facing.x < 0.0
	var data: Array = _anims[anim]
	var ft: float = data[2] if float(data[2]) > 0.0 else 0.15
	var idx := int(_t / ft) % int(data[1])
	_sprite.frame = (int(data[0]) + d) * _sprite.hframes + idx


func _talk() -> void:
	var m := Roster.by_id(member_id)
	if m.is_empty():
		return
	# Il se tourne vers le héros.
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		_facing = global_position.direction_to(player.global_position)
		_wait = 3.0
	await GuildRegistry.member_sheet(member_id)
