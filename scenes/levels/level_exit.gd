class_name LevelExit
extends Area2D
## Zone de sortie : quand le guerrier y entre, on passe au niveau suivant.

## Le niveau à charger.
@export_file("*.tscn") var target_scene: String
## Où apparaître dans le niveau suivant (nom d'un Marker2D sous « Spawns »).
@export var spawn_id: StringName = &""
## Une sortie désactivée ne fait rien (par exemple tant qu'un passage est bloqué).
@export var enabled: bool = true


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if enabled and body is Player and target_scene != "" and not Transition.is_busy:
		Game.next_spawn = spawn_id
		Transition.change_scene(target_scene)
