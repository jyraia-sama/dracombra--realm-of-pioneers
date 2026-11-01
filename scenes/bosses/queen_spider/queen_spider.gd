class_name QueenSpider
extends ObsidianSpider
## La reine araignée d'obsidienne, mini-boss de la caverne d'obsidienne (étage 3).
## Une araignée d'obsidienne deux fois plus grande (dessin PROVISOIRE : planche de
## l'araignée teintée), qui en plus :
##   - crache des salves de toile qui ralentissent le héros ;
##   - pond des œufs d'où sortent de petites araignées ;
##   - devient plus agressive sous la moitié de ses PV.
## Créée par le donjon : QueenSpider.create() (scène de l'araignée + ce script).

signal spawned(node: Node2D)

const SPIDER_SCENE := preload("res://scenes/enemies/obsidian_spider/obsidian_spider.tscn")
const MAX_BROOD := 4

var max_hp := 40
var _web_timer := 3.0
var _egg_timer := 6.0
var _enraged := false
var _brood: Array[Node2D] = []


static func create(hp: int) -> QueenSpider:
	var q := SPIDER_SCENE.instantiate()
	q.set_script(load("res://scenes/bosses/queen_spider/queen_spider.gd"))
	q.max_hp = hp
	q.name = "QueenSpider"
	return q as QueenSpider


func _ready() -> void:
	super()
	scale = Vector2(2.0, 2.0)
	visual.modulate = Color(1.0, 0.75, 0.9)
	health.max_health = max_hp
	health.current_health = max_hp
	health.invulnerability_duration = 0.1
	move_speed_tiles = 2.2
	detection_radius_tiles = 30.0
	lose_interest_radius_tiles = 40.0
	leap_range_tiles = 4.5
	leap_distance_tiles = 4.0
	leap_damage = 3
	leap_cooldown = 3.0
	windup_time = 0.6
	contact_damage = 1
	contact_hitbox.damage = contact_damage
	hurt_duration = 0.08
	health.health_changed.connect(func(cur: int, mx: int) -> void:
		if not _enraged and cur <= mx / 2:
			_enraged = true
			visual.modulate = Color(1.0, 0.55, 0.65)
			Emote.show(self, "!!", Color(1, 0.4, 0.4), 20.0)
			Fx.shake(3.0, 0.4))


func _physics_process(delta: float) -> void:
	super(delta)
	if state == State.DEAD or not is_instance_valid(_target):
		return
	if state != State.CHASE and state != State.IDLE:
		return
	var speed := 1.6 if _enraged else 1.0
	_web_timer -= delta * speed
	_egg_timer -= delta * speed
	if _web_timer <= 0.0:
		_web_timer = 4.5
		_spit_web()
	elif _egg_timer <= 0.0:
		_egg_timer = 9.0
		_lay_eggs()


## Les coups ne la repoussent presque pas.
func _on_hit_received(hitbox: Hitbox) -> void:
	super(hitbox)
	velocity *= 0.15


## Trois jets de toile en éventail vers le héros.
func _spit_web() -> void:
	var dir := global_position.direction_to(_target.global_position)
	for a in [-0.35, 0.0, 0.35]:
		var web := WebShot.create(global_position + Vector2(0, -12), dir.rotated(a), self)
		get_parent().add_child(web)
	Emote.show(self, "Pfft !", Color(0.95, 0.95, 1.0), 16.0)


## Pond des œufs qui éclosent en petites araignées (4 au maximum en même temps).
func _lay_eggs() -> void:
	_brood = _brood.filter(func(n): return is_instance_valid(n) and not n.get_node("Health").is_dead())
	var count := mini(2 if not _enraged else 3, MAX_BROOD - _brood.size())
	for i in count:
		var at := global_position + Vector2.from_angle(randf() * TAU) * randf_range(20.0, 34.0)
		PixelBurst.spawn(self, at, PixelBurst.SMOKE, Vector2.ZERO, 0.6)
		get_tree().create_timer(0.8).timeout.connect(func() -> void:
			if not is_inside_tree() or state == State.DEAD:
				return
			var s: Node2D = SPIDER_SCENE.instantiate()
			s.name = "Spiderling"
			s.position = at
			s.scale = Vector2(0.7, 0.7)
			var h := s.get_node("Health") as HealthComponent
			h.max_health = 1
			s.set("leap_damage", 1)
			s.set("detection_radius_tiles", 30.0)
			s.set("lose_interest_radius_tiles", 40.0)
			get_parent().add_child(s)
			_brood.append(s)
			spawned.emit(s))


func _on_died() -> void:
	super()
	for s in _brood:
		if is_instance_valid(s):
			var h := s.get_node_or_null("Health") as HealthComponent
			if h and not h.is_dead():
				h.take_damage(999)
