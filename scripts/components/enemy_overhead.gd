class_name EnemyOverhead
extends Node2D
## Au-dessus d'un ennemi touché : une petite barre de vie (qui disparaît s'il n'est plus
## touché) et les dégâts reçus, en chiffres qui sautent.

const WIDTH := 18.0
const SHOW_TIME := 3.0

var health: HealthComponent
var height := 24.0
var _timer := 0.0
var _ghost := 1.0


## Appelé par HealthComponent quand un ennemi perd des PV.
static func on_damaged(enemy: Node2D, health: HealthComponent, amount: int) -> void:
	var o := enemy.get_node_or_null("Overhead") as EnemyOverhead
	if o == null:
		o = EnemyOverhead.new()
		o.name = "Overhead"
		o.health = health
		o.height = float(enemy.get("overhead_height")) if enemy.get("overhead_height") != null else 24.0
		o.z_index = 9
		enemy.add_child(o)
	o._timer = SHOW_TIME
	o._number(amount)


func _process(delta: float) -> void:
	_timer -= delta
	var ratio := _ratio()
	_ghost = maxf(ratio, _ghost - delta * 0.8)
	visible = _timer > 0.0 and health != null and not health.is_dead()
	queue_redraw()


func _ratio() -> float:
	if health == null or health.max_health <= 0:
		return 0.0
	return clampf(float(health.current_health) / health.max_health, 0.0, 1.0)


func _draw() -> void:
	var at := Vector2(-WIDTH / 2.0, -height - 4.0)
	var r := Rect2(at, Vector2(WIDTH, 2))
	draw_rect(r.grow(1), Color8(28, 20, 30))
	draw_rect(r, Color8(60, 40, 50))
	draw_rect(Rect2(at, Vector2(round(WIDTH * _ghost), 2)), Color8(250, 226, 170))
	draw_rect(Rect2(at, Vector2(round(WIDTH * _ratio()), 2)), Color8(220, 60, 52))


func _number(amount: int) -> void:
	var label := Label.new()
	label.text = str(amount)
	label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	label.add_theme_color_override("font_outline_color", Color8(40, 16, 20))
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_font_size_override("font_size", 10)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(24, 14)
	label.position = Vector2(-12 + randf_range(-5, 5), -height - 18)
	label.z_index = 10
	# Posé dans le niveau : le chiffre reste en place même si l'ennemi meurt et disparaît.
	var offset := label.position
	get_parent().get_parent().add_child(label)
	label.global_position = get_parent().global_position + offset
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", label.position.y - 8.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.35)
	tween.tween_property(label, "modulate:a", 0.0, 0.25)
	tween.tween_callback(label.queue_free)
