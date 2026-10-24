extends PointLight2D
## Lumière qui vacille doucement (braises, torches...).

## Amplitude du vacillement, en part de l'énergie de départ.
@export var amount: float = 0.25
## Vitesse du vacillement.
@export var speed: float = 6.0

var _base_energy: float = 1.0
var _time: float = 0.0


func _ready() -> void:
	_base_energy = energy
	_time = randf() * 100.0


func _process(delta: float) -> void:
	_time += delta * speed
	var noise := sin(_time) * 0.5 + sin(_time * 2.3 + 1.7) * 0.3 + sin(_time * 5.1) * 0.2
	energy = _base_energy * (1.0 + noise * amount)
