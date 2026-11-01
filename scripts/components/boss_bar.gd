class_name BossBar
extends CanvasLayer
## Barre de vie d'un boss, en haut de l'écran.

var _health: HealthComponent
var _bar: ProgressBar
var _label: Label


static func create(title: String, health: HealthComponent) -> BossBar:
	var b := BossBar.new()
	b.layer = 15
	b._health = health
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	box.offset_left = -130
	box.offset_right = 130
	box.offset_top = 4
	box.add_theme_constant_override("separation", 1)
	b.add_child(box)
	b._label = Label.new()
	b._label.text = title
	b._label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b._label.add_theme_font_size_override("font_size", 10)
	b._label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.85))
	b._label.add_theme_color_override("font_outline_color", Color.BLACK)
	b._label.add_theme_constant_override("outline_size", 4)
	box.add_child(b._label)
	b._bar = ProgressBar.new()
	b._bar.custom_minimum_size = Vector2(260, 7)
	b._bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.06, 0.1, 0.85)
	bg.border_color = Color(0.55, 0.45, 0.7)
	bg.set_border_width_all(1)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.85, 0.2, 0.35)
	b._bar.add_theme_stylebox_override("background", bg)
	b._bar.add_theme_stylebox_override("fill", fill)
	box.add_child(b._bar)
	return b


func _process(_delta: float) -> void:
	if not is_instance_valid(_health):
		queue_free()
		return
	_bar.max_value = _health.max_health
	_bar.value = _health.current_health
