extends Sprite2D
## Fait défiler en boucle les images d'un décor animé (flammes d'un feu de camp...).

## Images par seconde.
@export var fps: float = 7.0

var _time: float = 0.0


func _ready() -> void:
	_time = randf() * 10.0


func _process(delta: float) -> void:
	_time += delta
	frame = int(_time * fps) % maxi(1, hframes)
