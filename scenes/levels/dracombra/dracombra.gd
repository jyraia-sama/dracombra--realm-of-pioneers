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
	var hero := Hero.hero_name
	await Ysolde.lines("Ysolde", ["Ah... tu ouvres enfin les yeux. Quatre jours que tu dors, étranger."])
	await Ysolde.lines(hero, ["Où... suis-je ?"])
	await Ysolde.lines("Ysolde", ["Je t'ai trouvé devant la grande porte, à moitié vidé de ton sang. Une griffe de dragon, hein ? Tu as de la chance d'être en vie.",
		"Mes herbes ont refermé la plaie. Mais la brûlure restera : tu n'auras plus la force d'autrefois.",
		"Je m'appelle Ysolde. Herboriste... et exilée, comme toi je suppose. Je vis cachée dans ces ruines depuis des années."])
	await wound.play(&"rise")
	wound.release_pose()
	wound.queue_free()
	player.face(Vector2.UP)
	await Ysolde.lines(hero, ["Je m'appelle %s. Ces ruines... ces dragons sculptés dans la pierre..." % hero])
	await Ysolde.lines("Ysolde", ["Dracombra. L'ancienne capitale des hommes et des dragons. Il n'en reste que des pierres... et nous."])
	await Narration.title_card("DRACOMBRA", "Chapitre 1 — Les Pionniers", 3.0)
	await Ysolde.lines(hero, ["Alors c'est ici que je bâtirai. Un camp, puis un village, puis une cité. Une guilde pour tous les oubliés d'Aethelgard."])
	await Ysolde.lines("Ysolde", ["Ha ! Ambitieux, pour un homme qui tenait à peine debout hier. Bien. Je vais t'apprendre à vivre ici."])
	phase = Phase.FREE
	player.input_locked = false
	Quests.reset()
	Save.save_game()
	Narration.say("E : interagir · B : construire · Échap : menu (sac, personnage, carte). Parlez à Ysolde.", 5.0)
