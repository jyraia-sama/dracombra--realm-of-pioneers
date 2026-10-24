extends CanvasLayer
## Textes de narration et titres, utilisables partout :
##     await Narration.say("Seul dans le noir...", 3.0)
##     await Narration.title_card("SOLAKOR", "Gardien des Telles-Ombrages")

@onready var box: PanelContainer = $Box
@onready var text_label: Label = $Box/Text
@onready var title: Control = $Title
@onready var title_label: Label = $Title/TitleLabel
@onready var subtitle_label: Label = $Title/SubtitleLabel
@onready var top_bar: ColorRect = $TopBar
@onready var bottom_bar: ColorRect = $BottomBar

## Hauteur des bandes noires de cinématique, en pixels.
const BAR_HEIGHT := 34.0

var _say_id: int = 0


func _ready() -> void:
	box.modulate.a = 0.0
	title.modulate.a = 0.0


## Affiche un texte en bas de l'écran pendant `duration` secondes.
## Un nouveau texte remplace immédiatement le précédent.
func say(text: String, duration: float = 3.0) -> void:
	_say_id += 1
	var my_id := _say_id
	text_label.text = text
	await _fade(box, 1.0, 0.25)
	await get_tree().create_timer(duration).timeout
	if my_id == _say_id:
		await _fade(box, 0.0, 0.3)


## Grand titre au centre de l'écran (nom de boss, lieu...).
func title_card(main_text: String, sub_text: String = "", duration: float = 2.5) -> void:
	title_label.text = main_text
	subtitle_label.text = sub_text
	await _fade(title, 1.0, 0.4)
	await get_tree().create_timer(duration).timeout
	await _fade(title, 0.0, 0.5)


## Bandes noires en haut et en bas : le joueur ne contrôle plus le héros.
func cinematic(on: bool, time: float = 0.5) -> void:
	var height := BAR_HEIGHT if on else 0.0
	var tween := create_tween().set_parallel()
	tween.tween_property(top_bar, "offset_bottom", height, time)
	tween.tween_property(bottom_bar, "offset_top", -height, time)
	await tween.finished


func hide_all() -> void:
	_say_id += 1
	box.modulate.a = 0.0
	title.modulate.a = 0.0
	top_bar.offset_bottom = 0.0
	bottom_bar.offset_top = 0.0


func _fade(node: CanvasItem, alpha: float, time: float) -> void:
	var tween := create_tween()
	tween.tween_property(node, "modulate:a", alpha, time)
	await tween.finished
