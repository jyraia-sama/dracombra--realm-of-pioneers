class_name LevelExit
extends Area2D
## Zone de sortie : quand le guerrier y entre, on passe au niveau suivant.

## Le niveau à charger.
@export_file("*.tscn") var target_scene: String
## Une sortie désactivée ne fait rien (par exemple tant qu'un passage est bloqué).
@export var enabled: bool = true


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if enabled and body is Player and target_scene != "":
		Transition.change_scene(target_scene)
