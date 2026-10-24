class_name Emote
extends RefCounted
## Petite bulle au-dessus d'un personnage (« ! » de peur, « ? »...), qui monte puis s'efface.


static func show(owner: Node2D, text: String, color: Color = Color(1.0, 0.85, 0.3), height: float = 30.0) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 14)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(24, 18)
	label.position = Vector2(-12, -height - 18)
	label.z_index = 10
	owner.add_child(label)
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", label.position.y - 6.0, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.3)
	tween.tween_callback(label.queue_free)
