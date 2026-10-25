class_name HeroProjectile
extends Hitbox
## Flèche de l'archer, projectile de mana du mage, et les tirs des techniques
## (boule de feu, onde du fendoir...). Se brise contre les murs.

var velocity := Vector2.ZERO
var lifetime := 1.2
## Traverse les ennemis au lieu de se briser au premier touché.
var pierce := false
## Rayon d'explosion à l'impact, en pixels (0 = pas d'explosion).
var explode_radius := 0.0
var explode_color := Color(1.0, 0.55, 0.2)
var _sprite: Sprite2D


## kind : &"arrow", &"bolt", &"fire" (boule de feu) ou &"wave" (onde d'épée).
static func create(kind: StringName, from: Vector2, direction: Vector2, dmg: int, shooter: Node2D) -> HeroProjectile:
	var p := HeroProjectile.new()
	p.collision_layer = 0
	p.collision_mask = 16 | 1
	p.once_per_activation = true
	p.damage = dmg
	p.knockback_tiles = 0.8 if kind == &"arrow" else 1.6
	if kind == &"wave":
		p.collision_mask = 16
	p.source = shooter
	p.position = from
	var t := float(Game.TILE_SIZE)
	var speed := {&"arrow": 14.0, &"bolt": 7.0, &"fire": 8.0, &"wave": 10.0}
	p.velocity = direction.normalized() * t * float(speed.get(kind, 7.0))
	p.lifetime = 0.7 if kind == &"arrow" else 0.6 if kind == &"wave" else 1.1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 3.0 if kind == &"arrow" else 5.0
	shape.shape = circle
	p.add_child(shape)
	p._sprite = Sprite2D.new()
	p._sprite.texture = _texture(kind)
	p._sprite.scale = Vector2(0.5, 0.5)  # dessin HD
	p._sprite.rotation = direction.angle()
	p.add_child(p._sprite)
	if kind != &"arrow":
		var light := PointLight2D.new()
		light.texture = load("res://assets/lights/light_radial.tres")
		light.color = Color(1.0, 0.55, 0.25) if kind == &"fire" else Color(0.7, 0.5, 1.0)
		light.texture_scale = 0.5
		light.energy = 0.9
		p.add_child(light)
	return p


## Dessins HD des projectiles (2 pixels dessinés par pixel du monde), tournés vers la droite.
static func _texture(kind: StringName) -> Texture2D:
	if kind == &"arrow":
		return _arrow()
	if kind == &"wave":
		return _wave()
	if kind == &"fire":
		return _orb([Color8(92, 20, 12), Color8(196, 64, 28), Color8(244, 128, 36), Color8(252, 200, 92), Color8(255, 244, 200)])
	return _orb([Color8(40, 22, 72), Color8(100, 52, 160), Color8(156, 92, 220), Color8(212, 164, 255), Color8(255, 255, 255)])


static func _arrow() -> Texture2D:
	var img := Image.create(22, 7, false, Image.FORMAT_RGBA8)
	var outline := Color8(30, 20, 38)
	var wood := Color8(140, 100, 64)
	var wood_dark := Color8(104, 72, 48)
	var feather := Color8(232, 226, 214)
	var feather_dark := Color8(176, 60, 52)
	var steel := Color8(196, 200, 210)
	var steel_dark := Color8(108, 108, 120)
	# Hampe.
	for x in range(4, 17):
		img.set_pixel(x, 3, wood)
		img.set_pixel(x, 4, wood_dark)
	# Empennage.
	for i in 4:
		img.set_pixel(i, 1 + i / 2, feather)
		img.set_pixel(i + 1, 1 + i / 2, feather_dark if i % 2 == 0 else feather)
		img.set_pixel(i, 6 - i / 2, feather)
		img.set_pixel(i + 1, 6 - i / 2, feather_dark if i % 2 == 1 else feather)
	# Pointe d'acier.
	for y in range(1, 6):
		var w := 3 - absi(y - 3)
		for x in range(17, 17 + w + 2):
			img.set_pixel(x, y, steel if y <= 3 else steel_dark)
	img.set_pixel(21, 3, steel)
	_outline(img, outline)
	return ImageTexture.create_from_image(img)


static func _orb(pal: Array) -> Texture2D:
	var img := Image.create(18, 18, false, Image.FORMAT_RGBA8)
	var c := Vector2(9, 9)
	for y in 18:
		for x in 18:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			# Une petite traîne vers l'arrière (à gauche).
			var tail := x < 9 and absf(y + 0.5 - 9.0) < (9.0 - x) * 0.35 + 1.5 and x > 1
			if d <= 5.5:
				var lit := Vector2(x + 0.5, y + 0.5).distance_to(c + Vector2(1.2, -1.2))
				img.set_pixel(x, y, pal[4] if lit < 1.6 else pal[3] if lit < 3.0 else pal[2] if d < 4.6 else pal[1])
			elif tail:
				img.set_pixel(x, y, Color(pal[2], 0.85) if x > 5 else Color(pal[1], 0.7))
	# Étincelles.
	for p in [Vector2i(15, 4), Vector2i(3, 14), Vector2i(14, 15)]:
		img.set_pixelv(p, pal[3])
	return ImageTexture.create_from_image(img)


static func _wave() -> Texture2D:
	var img := Image.create(14, 30, false, Image.FORMAT_RGBA8)
	for y in 30:
		for x in 14:
			var d := Vector2(x / 13.0, (y - 14.5) / 14.5).length()
			var inner := Vector2((x + 6.0) / 13.0, (y - 14.5) / 14.5).length()
			if d <= 1.0 and inner > 1.0:
				img.set_pixel(x, y, Color8(244, 232, 255) if inner < 1.08 else Color8(196, 150, 255) if inner < 1.2 else Color(Color8(118, 70, 220), 0.85))
	return ImageTexture.create_from_image(img)


## Contour d'un pixel autour du dessin.
static func _outline(img: Image, col: Color) -> void:
	var src := img.duplicate() as Image
	for y in img.get_height():
		for x in img.get_width():
			if src.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + d
				if q.x >= 0 and q.y >= 0 and q.x < img.get_width() and q.y < img.get_height() and src.get_pixelv(q).a > 0.0:
					img.set_pixel(x, y, col)
					break


func _ready() -> void:
	super()
	body_entered.connect(func(_b: Node2D) -> void: _break())
	hit_landed.connect(func(_h: Hurtbox) -> void:
		if not pierce:
			_break())


func _physics_process(delta: float) -> void:
	position += velocity * delta
	lifetime -= delta
	if lifetime <= 0.0:
		_break()
		return
	super(delta)


func _break() -> void:
	if not active:
		return
	active = false
	if explode_radius > 0.0 and is_inside_tree():
		var boom := SkillArea.create(global_position, explode_radius, damage, 1.5, explode_color, source)
		get_parent().add_child.call_deferred(boom)
	velocity = Vector2.ZERO
	set_deferred("monitoring", false)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.1)
	tween.tween_callback(queue_free)
