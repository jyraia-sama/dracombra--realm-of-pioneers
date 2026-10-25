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


static func _texture(kind: StringName) -> Texture2D:
	var img: Image
	if kind == &"arrow":
		img = Image.create(9, 3, false, Image.FORMAT_RGBA8)
		for x in 7:
			img.set_pixel(x, 1, Color(0.6, 0.42, 0.25))
		img.set_pixel(0, 0, Color(0.9, 0.9, 0.9)); img.set_pixel(0, 2, Color(0.9, 0.9, 0.9))
		img.set_pixel(7, 1, Color(0.8, 0.8, 0.85)); img.set_pixel(8, 1, Color(0.95, 0.95, 1.0))
		img.set_pixel(7, 0, Color(0.7, 0.7, 0.75)); img.set_pixel(7, 2, Color(0.7, 0.7, 0.75))
	elif kind == &"wave":
		# Un croissant d'énergie violette, tourné vers l'avant.
		img = Image.create(7, 15, false, Image.FORMAT_RGBA8)
		for y in 15:
			for x in 7:
				var d := Vector2((x - 0.0) / 6.0, (y - 7.0) / 7.0).length()
				var inner := Vector2((x + 3.0) / 6.0, (y - 7.0) / 7.0).length()
				if d <= 1.0 and inner > 1.0:
					img.set_pixel(x, y, Color(0.95, 0.85, 1.0) if inner < 1.15 else Color(0.6, 0.35, 1.0, 0.85))
	elif kind == &"fire":
		img = Image.create(7, 7, false, Image.FORMAT_RGBA8)
		for y in 7:
			for x in 7:
				var d := Vector2(x - 3, y - 3).length()
				if d <= 3.2:
					img.set_pixel(x, y, Color(1.0, 0.95, 0.6) if d < 1.2 else Color(1.0, 0.6, 0.15) if d < 2.3 else Color(0.75, 0.2, 0.05))
	else:
		img = Image.create(7, 7, false, Image.FORMAT_RGBA8)
		for y in 7:
			for x in 7:
				var d := Vector2(x - 3, y - 3).length()
				if d <= 3.2:
					img.set_pixel(x, y, Color(0.95, 0.85, 1.0) if d < 1.2 else Color(0.65, 0.4, 1.0) if d < 2.3 else Color(0.4, 0.2, 0.75))
	return ImageTexture.create_from_image(img)


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
