class_name Lysia
extends Node2D
## Lysia Vernebrume, scribe de la Compagnie des Cartographes d'Elysia, devenue l'intendante
## de la guilde. Personnage important, comme Ysolde.
##
## Son histoire : envoyée par Elysia cartographier les ruines de Dracombra et retrouver les
## registres de l'ancienne guilde des pionniers, elle s'est perdue dans la caverne
## d'obsidienne. La reine araignée l'a enfermée dans un cocon de soie, gardée vivante comme
## réserve. Le héros la libère après avoir vaincu la reine pour la première fois. Elle
## reconnaît en lui le capitaine déserteur recherché par Elysia… mais lui doit la vie et
## garde le secret. Elle tient désormais le registre derrière le comptoir de la guilde.
## (Fil pour plus tard : son frère, cartographe lui aussi, a disparu plus bas dans les Abysses.)
##
## Dessin PROVISOIRE : planche de PNJ générée, teintée lavande.

const BASE := "res://assets/sprites/npc/lysia/lysia"
const TINT := Color(0.85, 0.75, 1.0)

var _sprite: Sprite2D
var _anims: Dictionary
var _t := 0.0
var _talking := false


static func rescued() -> bool:
	return Game.has_flag(&"lysia_rescued")


func _ready() -> void:
	add_to_group("npc")
	var sheet := SheetAnimation.load_sheet(BASE + ".json")
	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	SheetAnimation.apply_to(_sprite, load(BASE + ".png"), sheet)
	_sprite.modulate = TINT
	add_child(_sprite)
	_anims = SheetAnimation.anims_from(sheet)
	var it := Interactable.new()
	it.prompt = "Parler à Lysia"
	it.radius_tiles = 2.2
	it.position = Vector2(0, 14)
	add_child(it)
	it.interacted.connect(talk)


func _process(delta: float) -> void:
	_t += delta
	var a: Array = _anims[&"idle"]
	_sprite.frame = int(a[0]) * _sprite.hframes + int(_t / 0.45) % int(a[1])


func talk() -> void:
	if _talking:
		return
	_talking = true
	await menu()
	_talking = false


## Le comptoir : registre, candidats, groupe d'aventure.
static func menu() -> void:
	if not Game.has_flag(&"lysia_intro_done"):
		Game.set_flag(&"lysia_intro_done")
		await Ysolde.lines("Lysia", ["Ah, %s ! Bienvenue dans votre propre guilde. J'ai rangé le comptoir, comme vous voyez." % Hero.hero_name,
			"Les registres de l'ancienne Dracombra parlaient d'une salle comme celle-ci : les pionniers y inscrivaient chaque nouvel arrivant.",
			"Alors je ferai pareil. Je tiens le registre, j'accueille les candidats, et je prépare vos groupes d'aventure."])
	while true:
		var options := ["Le registre des membres", "Les candidats du jour (%d)" % Roster.candidates.size(),
			"Le groupe d'aventure", "Les commandes (%d en cours)" % GuildOrders.pending_count(), "Bavarder", "Au revoir"]
		var body := "%s\n%s" % [GuildRegistry.beds_text(), GuildRegistry.party_text()]
		var i := await Choice.ask("Lysia, intendante de la guilde", body, options)
		match i:
			0:
				await GuildRegistry.open_members()
			1:
				await GuildRegistry.open_candidates()
			2:
				await GuildRegistry.open_party()
			3:
				await GuildOrders.open()
			4:
				await _chat()
			_:
				return


static func _chat() -> void:
	var talks := [
		["Je dessinais une carte des galeries quand la reine m'a surprise. Après, il n'y a eu que la soie... et le noir.",
			"Sans vous, je serais encore suspendue là-bas. Je ne l'oublierai pas."],
		["Elysia vous cherche, vous savez. Un capitaine déserteur, cheveux d'argent, une cape violette...",
			"Ne faites pas cette tête. Votre secret est bien gardé ici. On ne livre pas celui qui vous a sauvé la vie."],
		["Mon frère Aurèle est descendu plus bas que moi dans les Abysses. Il cherchait la salle des archives des pionniers.",
			"S'il vous arrive de trouver une sacoche de cartographe dans les profondeurs... rapportez-la-moi."],
		["Ysolde et moi, nous ne sommes pas toujours d'accord. Elle soigne les gens, moi je les range dans des colonnes.",
			"Mais elle fait la meilleure tisane de toute la Sylve. Ça, je ne le contesterai jamais."],
	]
	var t: Array = talks[randi() % talks.size()]
	await Ysolde.lines("Lysia", t)


# ------------------------------------------------------------------ le sauvetage

## Le cocon de soie qui apparaît dans le repaire de la reine (tant que Lysia n'est pas libérée).
static func cocoon() -> Node2D:
	var c := Cocoon.new()
	c.name = "Cocon"
	return c


class Cocoon extends Node2D:
	var _it: Interactable
	var _t := 0.0

	func _ready() -> void:
		_it = Interactable.new()
		_it.prompt = "Examiner le cocon"
		_it.radius_tiles = 2.0
		add_child(_it)
		_it.interacted.connect(_free_her)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		# Un cocon de soie suspendu qui remue faiblement.
		var sway := sin(_t * 2.0) * 1.0
		draw_line(Vector2(0, -60), Vector2(sway, -34), Color(0.9, 0.9, 1.0, 0.8), 1.0)
		var pts := PackedVector2Array()
		for i in 16:
			var a := i / 16.0 * TAU
			pts.append(Vector2(cos(a) * 7.0 + sway, sin(a) * 15.0 - 20.0))
		draw_colored_polygon(pts, Color(0.86, 0.86, 0.94))
		for k in 5:
			var y := -32.0 + k * 6.0
			draw_line(Vector2(-6 + sway, y), Vector2(6 + sway, y + 3), Color(0.7, 0.7, 0.82), 1.0)

	func _free_her() -> void:
		_it.enabled = false
		var hero := Hero.hero_name
		await Ysolde.lines(hero, ["Ce cocon bouge... Il y a quelqu'un là-dedans !"])
		PixelBurst.spawn(self, global_position, PixelBurst.DUST, Vector2.ZERO, 4.0)
		Fx.shake(1.5, 0.2)
		await Ysolde.lines("???", ["*tousse* ... De l'air... enfin de l'air...",
			"La reine... elle est morte ? Vous l'avez tuée ? Par toutes les étoiles d'Elysia..."])
		await Ysolde.lines("Lysia", ["Je m'appelle Lysia Vernebrume. Scribe de la Compagnie des Cartographes.",
			"On m'a envoyée dresser la carte de ces ruines et retrouver les registres de l'ancienne guilde des pionniers. La reine m'a trouvée avant.",
			"Attendez... ces cheveux d'argent, cette cape... Vous êtes le capitaine que tout Elysia recherche."])
		await Ysolde.lines(hero, ["Et si c'était le cas ?"])
		await Ysolde.lines("Lysia", ["Alors je dirais que la Compagnie peut bien chercher. Je vous dois la vie.",
			"Vous bâtissez une guilde à Dracombra, c'est ça ? Il vous faut quelqu'un pour tenir les registres. Je sais faire ça mieux que personne.",
			"Je rentre à Dracombra. Cherchez-moi à la guilde : je serai derrière le comptoir."])
		Game.set_flag(&"lysia_rescued")
		var tween := create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.6)
		tween.tween_callback(queue_free)
		Narration.say("Lysia rejoint la guilde de Dracombra.", 3.0)
