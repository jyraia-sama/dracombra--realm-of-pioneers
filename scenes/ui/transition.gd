extends CanvasLayer
## Fondus au noir et changements de niveau, utilisables partout :
##     Transition.change_scene("res://scenes/levels/prologue/solakor_lair.tscn")

signal scene_changed

@onready var curtain: ColorRect = $Curtain

var is_busy := false

var _story: Label


func _ready() -> void:
	curtain.color.a = 0.0
	# Texte affiché sur l'écran noir (« Quelques jours plus tard... »).
	_story = Label.new()
	_story.name = "Story"
	_story.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_story.offset_left = 60
	_story.offset_right = -60
	_story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_story.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_story.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_story.add_theme_color_override("font_color", Color(0.92, 0.88, 0.8))
	_story.modulate.a = 0.0
	add_child(_story)


## Un texte qui apparaît puis s'efface sur l'écran noir (après un fade_out).
func story_text(text: String, duration: float = 3.0) -> void:
	_story.text = text
	var tween := create_tween()
	tween.tween_property(_story, "modulate:a", 1.0, 0.8)
	tween.tween_interval(duration)
	tween.tween_property(_story, "modulate:a", 0.0, 0.7)
	await tween.finished


func fade_out(time: float = 0.5) -> void:
	var tween := create_tween()
	tween.tween_property(curtain, "color:a", 1.0, time)
	await tween.finished


func fade_in(time: float = 0.5) -> void:
	var tween := create_tween()
	tween.tween_property(curtain, "color:a", 0.0, time)
	await tween.finished


## Fondu au noir, chargement du niveau, puis retour de l'image.
func change_scene(path: String, time: float = 0.6) -> void:
	if is_busy:
		return
	is_busy = true
	Narration.hide_all()
	await fade_out(time)
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	scene_changed.emit()
	is_busy = false
	await fade_in(time)
