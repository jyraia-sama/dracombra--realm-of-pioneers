class_name HeroJuice
extends Node
## Petits effets de mouvement du héros, indépendants de sa planche de sprites :
## poussière à chaque pas, nuage et étirement au départ d'une roulade, tassement à l'arrivée.
## Ajouté automatiquement au joueur par l'autoload Fx.

## Temps entre deux pas (s) à vitesse normale : la marche fait 6 images de 0,1 s, 2 pas.
@export var step_time: float = 0.3

var _player: Player
var _last_state := -1
var _step := 0.0


func _ready() -> void:
	_player = get_parent() as Player


func _process(delta: float) -> void:
	if _player == null:
		return
	var state := _player.state
	if state != _last_state:
		_on_state_changed(_last_state, state)
		_last_state = state
	if _player.input_locked and _player.scripted_direction == Vector2.ZERO:
		return
	if state == Player.State.NORMAL and _player.velocity.length() > 1.0:
		_step -= delta * maxf(_player.speed_multiplier, 0.3)
		if _step <= 0.0:
			_step = step_time
			var back := -_player.velocity.normalized()
			PixelBurst.spawn(_player, _player.global_position + back * 2.0, PixelBurst.DUST, back)
	else:
		_step = 0.05


func _on_state_changed(from: int, to: int) -> void:
	var visual := _player.visual
	if to == Player.State.DODGE:
		var back := -_player.velocity.normalized() if _player.velocity != Vector2.ZERO else -_player.facing
		PixelBurst.spawn(_player, _player.global_position, PixelBurst.DUST, back, 2.5)
		_squash(visual, Vector2(1.15, 0.85), 0.18)
	elif from == Player.State.DODGE and to == Player.State.NORMAL:
		PixelBurst.spawn(_player, _player.global_position, PixelBurst.DUST, Vector2.ZERO, 1.5)
		_squash(visual, Vector2(1.12, 0.88), 0.14)


## Déforme brièvement le visuel puis le ramène à sa taille normale.
func _squash(visual: Node2D, amount: Vector2, duration: float) -> void:
	# Pendant une cinématique, l'échelle peut être pilotée par la scène : on n'y touche pas.
	if _player.input_locked or visual.scale != Vector2.ONE:
		return
	visual.scale = amount
	var tween := visual.create_tween()
	tween.tween_property(visual, "scale", Vector2.ONE, duration) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
