extends Level
## Dracombra : les ruines de l'ancienne capitale, où le héros bâtit sa ville.
## La guilde est au centre ; chaque palier débloque un anneau de ruines à déblayer.
##
## Fin du prologue : le héros se réveille au camp, près du feu, quelques jours après
## s'être effondré devant la porte. L'histoire principale commence.

enum Phase { WAKE, FREE }

## Case de la guilde (le centre de la ville).
@export var center_cell: Vector2i = Vector2i.ZERO

var phase: Phase = Phase.FREE

@onready var guild: Guild = $Guild


func _ready() -> void:
	Town.center = center_cell
	super()
	if Game.has_flag(&"wake_in_dracombra") and not Game.has_flag(&"prologue_done"):
		_wake_up.call_deferred()
	elif Game.has_flag(&"prologue_done"):
		Narration.say("Dracombra — %s. Jour %d." % [Town.tier_name(), Game.day], 2.2)


func _wake_up() -> void:
	phase = Phase.WAKE
	var player := get_player()
	player.input_locked = true
	# Le combat contre Solakor l'a marqué pour toujours : il ne retrouvera pas sa force d'antan.
	Game.set_flag(&"prologue_done")
	Game.set_flag(&"wake_in_dracombra", false)
	var wound := WoundedEffect.new()
	wound.name = "Wound"
	add_child(wound)
	wound.player = player
	wound.play(&"sit", true)
	player.apply_class(true)
	# Il est assis près du feu, à sa gauche, face aux flammes.
	player.global_position = guild.global_position + Vector2(-16, 1)
	player.face(Vector2.RIGHT)
	await get_tree().process_frame
	await Transition.fade_in(1.6)
	await Narration.say("Ses blessures s'étaient refermées. Il était vivant.", 2.8)
	await Narration.say("Mais la griffe de Solakor avait laissé une marque brûlante : il n'avait plus la force d'autrefois.", 3.6)
	await wound.play(&"rise")
	wound.release_pose()
	wound.queue_free()
	player.face(Vector2.UP)
	await Narration.say("Autour de lui, des avenues pavées, des dragons sculptés dans la pierre... Ce ne pouvait être que Dracombra.", 4.0)
	await Narration.title_card("DRACOMBRA", "Chapitre 1 — Les Pionniers", 3.0)
	await Narration.say("Ici, il bâtirait un camp. Puis un village. Puis une cité, et une guilde pour les oubliés d'Aethelgard.", 4.0)
	phase = Phase.FREE
	player.input_locked = false
	Save.save_game()
	Narration.say("B : construire · E : interagir · Échap : menu (sac, personnage, carte)", 5.0)
