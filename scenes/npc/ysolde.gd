class_name Ysolde
extends Node2D
## Ysolde, l'herboriste exilée qui vit cachée dans les ruines de Dracombra.
## Elle a trouvé le héros effondré devant la grande porte et l'a soigné pendant des jours.
## Elle guide ses premiers pas (quêtes de l'autoload Quests) et deviendra la première
## habitante de la guilde.

const SHEET := preload("res://assets/sprites/npc/ysolde.png")

var _sprite: Sprite2D
var _interact: Interactable
var _time := 0.0
var _talking := false


func _ready() -> void:
	add_to_group("npc")
	_sprite = Sprite2D.new()
	_sprite.texture = SHEET
	_sprite.hframes = 2
	_sprite.centered = false
	_sprite.offset = Vector2(-10, -30)
	add_child(_sprite)
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 6)
	shape.shape = rect
	shape.position = Vector2(0, -3)
	body.add_child(shape)
	add_child(body)
	_interact = Interactable.new()
	_interact.prompt = "Parler à Ysolde"
	_interact.radius_tiles = 1.6
	_interact.position = Vector2(0, -4)
	add_child(_interact)
	_interact.interacted.connect(talk)


func _process(delta: float) -> void:
	_time += delta
	_sprite.frame = int(_time / 0.7) % 2
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		_sprite.flip_h = player.global_position.x < global_position.x
	# Un « ! » quand elle a quelque chose à dire.
	if Quests.ready_to_report and int(_time * 2.0) % 6 == 0 and not _talking and fmod(_time, 3.0) < delta:
		Emote.show(self, "!", Color(1.0, 0.85, 0.3), 32.0)


## Une suite de répliques, au clavier ou à la manette.
static func lines(speaker: String, texts: Array) -> void:
	for t in texts:
		var choice := await Choice.ask(speaker, t, ["Continuer"], true)
		if choice < 0:
			return


func talk() -> void:
	if _talking:
		return
	_talking = true
	await _dialogue()
	_talking = false


func _dialogue() -> void:
	var hero := Hero.hero_name
	if not Quests.active():
		await lines("Ysolde", ["Regarde-toi, %s : un vrai bâtisseur. Dracombra renaît, pierre après pierre." % hero,
			"Je garde un œil sur les blessés. Va, la Sylve t'attend."])
		return
	var s := Quests.current()
	match Quests.step:
		0:
			await lines("Ysolde", ["Tu tiens debout, c'est déjà ça. Commençons par le plus simple.",
				"Il te faut de quoi te soigner. Les buissons et les hautes herbes des ruines cachent des herbes médicinales : frappe-les pour les cueillir."])
			Quests.advance()
		_:
			if Quests.ready_to_report:
				await _report(Quests.step)
			else:
				await lines("Ysolde", [_reminder(Quests.step) if _reminder(Quests.step) != "" else s["hint"]])


func _reminder(step: int) -> String:
	match step:
		1: return "Des herbes, %s. Frappe les buissons et les hautes herbes, il en faut trois." % Hero.hero_name
		2: return "Un peu de bois et de pierre, pour commencer. Frappe un arbre et des décombres : ce sera long sans outil."
		3: return "Au feu de camp, tu peux te fabriquer une hache et une pioche. Trois bois et deux ou trois pierres chacune."
		4: return "Avec tes outils, abats des arbres et brise des décombres : il te faut 18 bois et 6 pierres."
		5: return "Appuie sur B pour choisir un bâtiment, place-le, puis dépose-y les matériaux. Une nuit de sommeil, et ta tente sera debout."
		6: return "Un établi, maintenant. Sans outils, pas d'équipement, pas de baume."
		7: return "À l'établi, trois herbes pilées font un baume. Apporte-m'en un."
		8: return "Parle à la guilde, près du feu : elle te dira ce qu'il manque pour devenir un vrai village."
	return ""


func _report(step: int) -> void:
	match step:
		2:
			await lines("Ysolde", ["Tu t'épuises à frapper ces troncs avec ton épée. Il te faut de vrais outils.",
				"Au feu de camp, fabrique-toi une hache et une pioche : trois morceaux de bois et quelques pierres suffisent.",
				"La hache pour les arbres, la pioche pour la pierre. Tu iras deux fois plus vite, et tu en tireras davantage."])
		3:
			await lines("Ysolde", ["Voilà qui ressemble à un bâtisseur !",
				"Maintenant, réunis de quoi construire : une tente pour dormir au sec, puis un établi."])
		6:
			await lines("Ysolde", ["Un établi ! Avec ça, tu pourras fabriquer cordes, tissus... et des armes pour d'autres combattants que toi.",
				"Tiens, prends ce lin que j'ai récolté près de la rivière. Pile-moi d'abord trois herbes en baume, veux-tu ?"])
			Inventory.add_item(Inventory.item_by_id(&"flax"), 4)
		7:
			Inventory.remove_item(Inventory.item_by_id(&"balm"), 1)
			await lines("Ysolde", ["Parfait. Un baume bien fait, comme je les aime.",
				"Tu sais quoi ? Je crois que je vais rester. Ce camp a besoin d'une soigneuse... et toi aussi.",
				"Dracombra n'a plus de guilde depuis des siècles. Fais grandir ce feu de camp : d'autres viendront, des oubliés comme nous.",
				"Pour un arc, il te faudra du cuir : chasse les sangliers de la Sylve et fais sécher leurs peaux. Le lin pousse au bord de la rivière, les pierres précieuses au pied de la montagne."])
			Inventory.add_item(Inventory.item_by_id(&"meat"), 2)
			Game.set_flag(&"ysolde_joined")
		8:
			await lines("Ysolde", ["Un village, %s ! Je n'aurais jamais cru revoir ça de mon vivant." % Hero.hero_name,
				"De nouveaux quartiers s'ouvrent. La suite de l'histoire t'appartient."])
	Quests.advance()
