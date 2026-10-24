extends Control
## Fin du prologue : le texte défile sur fond noir, puis on peut recommencer.

const LINES: Array[String] = [
	"Signant sa fuite au prix de son sang, il émergea enfin de l'autre côté de la montagne.",
	"Devant ses yeux s'étendait la Sylve des Dracombres : une vaste plaine sauvage baignée par une brume mystique, bordée de ruines anciennes et de forêts inexplorées.",
	"Il avait atteint sa destination.",
]
const RESTART_SCENE := "res://scenes/levels/prologue/cave_entrance.tscn"

@onready var text_label: Label = $Text
@onready var title_label: Label = $Title
@onready var hint_label: Label = $Hint

var _can_restart := false


func _ready() -> void:
	text_label.modulate.a = 0.0
	title_label.modulate.a = 0.0
	hint_label.modulate.a = 0.0
	_play.call_deferred()


func _play() -> void:
	await get_tree().create_timer(0.8).timeout
	for line in LINES:
		text_label.text = line
		await _fade(text_label, 1.0, 0.8)
		await get_tree().create_timer(2.0 + line.length() * 0.03).timeout
		await _fade(text_label, 0.0, 0.6)
	await _fade(title_label, 1.0, 1.2)
	await get_tree().create_timer(1.0).timeout
	await _fade(hint_label, 1.0, 0.6)
	_can_restart = true


func _unhandled_input(event: InputEvent) -> void:
	if _can_restart and (event.is_action_pressed("attack") or event.is_action_pressed("interact")):
		_can_restart = false
		Game.flags.clear()
		Inventory.clear()
		Transition.change_scene(RESTART_SCENE)


func _fade(node: CanvasItem, alpha: float, time: float) -> void:
	var tween := create_tween()
	tween.tween_property(node, "modulate:a", alpha, time)
	await tween.finished
