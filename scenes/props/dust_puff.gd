extends CPUParticles2D
## Nuage de poussière qui se joue une fois puis disparaît.


func _ready() -> void:
	emitting = true
	finished.connect(queue_free)
