extends CanvasLayer
## Fondus au noir et changements de niveau, utilisables partout :
##     Transition.change_scene("res://scenes/levels/prologue/solakor_lair.tscn")

signal scene_changed

@onready var curtain: ColorRect = $Curtain

var is_busy := false


func _ready() -> void:
	curtain.color.a = 0.0


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
