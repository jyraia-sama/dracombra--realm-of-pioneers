extends Node
## Effets de jeu (« juice ») posés automatiquement, sans toucher aux scènes :
##   - ombre ovale sous chaque personnage (héros, PNJ, monstres) ;
##   - flash blanc + tassement quand on touche un monstre ou un décor récoltable ;
##   - étincelles / copeaux / éclats selon ce qui est touché ;
##   - micro-pause (« hit stop ») et tremblement de caméra sur les coups ;
##   - nuage de fumée à la mort d'un monstre ;
##   - poussière de pas et de roulade du héros (HeroJuice).
## Tout est dessiné par le code : les effets restent quand on remplace les sprites.
## Un nœud peut refuser un effet avec la méta « no_fx » (tout) ou « no_shadow ».

const FLASH_SHADER := preload("res://scripts/components/fx/hit_flash.gdshader")

## Réglages généraux (à ajuster au ressenti).
const HIT_STOP_ENEMY := 0.045
const HIT_STOP_KILL := 0.09
const HIT_STOP_PLAYER := 0.08
const HIT_STOP_HARVEST := 0.02

## Ressource récoltée -> gerbe de pixels.
const HARVEST_BURSTS := {
	&"wood": PixelBurst.WOOD, &"stone": PixelBurst.STONE, &"gem": PixelBurst.GEM,
}

var _resume_at_ms := 0


func _ready() -> void:
	# Doit tourner même pendant une micro-pause ou un menu.
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)


func _process(_delta: float) -> void:
	if _resume_at_ms > 0 and Time.get_ticks_msec() >= _resume_at_ms:
		_resume_at_ms = 0
		Engine.time_scale = 1.0


# ------------------------------------------------------------------ outils publics

## Fige presque le jeu pendant `duration` secondes réelles (sensation d'impact).
func hit_stop(duration: float) -> void:
	if duration <= 0.0:
		return
	_resume_at_ms = maxi(_resume_at_ms, Time.get_ticks_msec() + int(duration * 1000.0))
	Engine.time_scale = 0.05


## Tremblement de caméra du niveau courant.
func shake(strength: float, duration: float) -> void:
	var scene := get_tree().current_scene
	if scene is Level:
		(scene as Level).shake_camera(strength, duration)


## Flash blanc sur un sprite (n'importe lequel ; le matériau est posé à la première fois).
func flash(sprite: CanvasItem, duration: float = 0.12) -> void:
	if sprite == null or not is_instance_valid(sprite):
		return
	var mat := sprite.material as ShaderMaterial
	if sprite.material == null:
		mat = ShaderMaterial.new()
		mat.shader = FLASH_SHADER
		sprite.material = mat
	elif mat == null or mat.shader != FLASH_SHADER:
		return  # le sprite a déjà son propre matériau : on n'y touche pas
	mat.set_shader_parameter("flash", 1.0)
	var tween := sprite.create_tween()
	tween.tween_method(func(v: float) -> void: mat.set_shader_parameter("flash", v), 1.0, 0.0, duration)


## Écrase brièvement un visuel (impact), puis le ramène à son échelle de départ.
func squash(visual: Node2D, amount: Vector2 = Vector2(1.2, 0.8), duration: float = 0.15) -> void:
	if visual == null or not is_instance_valid(visual):
		return
	if visual.has_meta("_fx_base_scale"):
		return  # déjà en cours
	var base := visual.scale
	visual.set_meta("_fx_base_scale", base)
	visual.scale = base * amount
	var tween := visual.create_tween()
	tween.tween_property(visual, "scale", base, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: visual.remove_meta("_fx_base_scale"))


## Le sprite principal d'un personnage ou d'un décor.
func find_sprite(node: Node) -> CanvasItem:
	if node == null:
		return null
	for path in ["Visual/Sprite", "Visual/Body", "Visual/Sprite2D", "Sprite2D", "Sprite"]:
		var s := node.get_node_or_null(path) as CanvasItem
		if s != null:
			return s
	return null


# ------------------------------------------------------------------ branchement automatique

func _on_node_added(node: Node) -> void:
	if node is Hurtbox or node is HealthComponent or node is CharacterBody2D \
			or (node is Node2D and node.get_script() != null):
		# Attendre la fin de _ready (groupes, formes de collision, enfants créés par le code).
		_attach.call_deferred(node)


func _attach(node: Node) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree() or _refused(node):
		return
	if node is Hurtbox:
		var hb := node as Hurtbox
		if not hb.hit_received.is_connected(_on_hit):
			hb.hit_received.connect(_on_hit.bind(hb))
	elif node is HealthComponent:
		var body := node.get_parent()
		if body != null and body.is_in_group("enemies"):
			(node as HealthComponent).died.connect(_on_enemy_died.bind(body), CONNECT_ONE_SHOT)
	elif node is CharacterBody2D or node.is_in_group("npc"):
		_add_shadow(node as Node2D)
		if node is Player and node.get_node_or_null("HeroJuice") == null:
			var juice := HeroJuice.new()
			juice.name = "HeroJuice"
			node.add_child(juice)


func _refused(node: Node) -> bool:
	return node.has_meta("no_fx") or (node.get_parent() != null and node.get_parent().has_meta("no_fx"))


func _add_shadow(body: Node2D) -> void:
	if body.has_meta("no_shadow") or body.get_node_or_null("Shadow") != null:
		return
	if body.get_node_or_null("Visual") == null and find_sprite(body) == null:
		return
	var width := float(Game.TILE_SIZE) * 0.8
	for child in body.get_children():
		var cs := child as CollisionShape2D
		if cs == null or cs.shape == null:
			continue
		if cs.shape is RectangleShape2D:
			width = (cs.shape as RectangleShape2D).size.x
		elif cs.shape is CircleShape2D:
			width = (cs.shape as CircleShape2D).radius * 2.0
		elif cs.shape is CapsuleShape2D:
			width = (cs.shape as CapsuleShape2D).radius * 2.0
		break
	# Au moins ~55 % de la largeur d'une case du sprite (le slime déborde de sa collision).
	var sprite := find_sprite(body) as Sprite2D
	if sprite != null and sprite.texture != null:
		var cell_w := sprite.texture.get_width() / float(maxi(1, sprite.hframes))
		width = maxf(width, cell_w * absf(sprite.global_scale.x) * 0.5)
	var shadow := BlobShadow.new()
	shadow.name = "Shadow"
	shadow.width = width * 1.15
	shadow.position = Vector2(0, 0)
	body.add_child(shadow)
	body.move_child(shadow, 0)


# ------------------------------------------------------------------ réactions aux coups

func _on_hit(hitbox: Hitbox, hurtbox: Hurtbox) -> void:
	var owner_node := hurtbox.get_parent()
	if owner_node == null:
		return
	var from_player := is_instance_valid(hitbox.source) and hitbox.source.is_in_group("player")
	if owner_node is Harvestable:
		_on_harvest_hit(owner_node as Harvestable, hitbox)
	elif owner_node.is_in_group("player"):
		_on_player_hit(owner_node as Node2D, hitbox)
	elif owner_node.is_in_group("enemies"):
		_on_enemy_hit(owner_node as Node2D, hitbox, from_player)


func _on_enemy_hit(body: Node2D, hitbox: Hitbox, from_player: bool) -> void:
	BugReport.log_event("%s touché (%d dégâts) par %s" % [body.name, hitbox.damage, _src(hitbox)])
	flash(find_sprite(body))
	squash(body.get_node_or_null("Visual") as Node2D)
	var dir := hitbox.get_knockback_direction(body.global_position)
	PixelBurst.spawn(body, body.global_position + dir * 2.0, PixelBurst.SPARK, dir)
	if from_player:
		hit_stop(HIT_STOP_ENEMY)
		shake(1.0, 0.1)


func _on_player_hit(body: Node2D, hitbox: Hitbox) -> void:
	BugReport.log_event("HÉROS touché (%d dégâts) par %s" % [hitbox.damage, _src(hitbox)])
	flash(find_sprite(body), 0.1)
	var dir := hitbox.get_knockback_direction(body.global_position)
	PixelBurst.spawn(body, body.global_position, PixelBurst.BLOOD, dir)
	if hitbox.heavy:
		hit_stop(HIT_STOP_PLAYER)
		shake(2.5, 0.22)
	else:
		shake(1.2, 0.12)


func _on_harvest_hit(h: Harvestable, hitbox: Hitbox) -> void:
	var decor := h.get_parent()
	flash(find_sprite(decor), 0.08)
	var dir := hitbox.get_knockback_direction(h.global_position)
	PixelBurst.spawn(h, h.global_position + dir * 2.0, HARVEST_BURSTS.get(h.item_id, PixelBurst.PLANT), dir)
	hit_stop(HIT_STOP_HARVEST)


## Appelé par Harvestable quand la ressource est épuisée.
func harvest_depleted(h: Harvestable) -> void:
	var preset: Dictionary = HARVEST_BURSTS.get(h.item_id, PixelBurst.PLANT)
	PixelBurst.spawn(h, h.global_position + Vector2(0, 2), PixelBurst.higher(preset), Vector2.ZERO, 2.5)
	PixelBurst.spawn(h, h.global_position + Vector2(0, 2), PixelBurst.SMOKE, Vector2.ZERO, 0.8)
	shake(1.5, 0.15)


func _on_enemy_died(body: Node) -> void:
	if not is_instance_valid(body):
		return
	BugReport.log_event("%s vaincu" % body.name)
	var b := body as Node2D
	hit_stop(HIT_STOP_KILL)
	shake(2.0, 0.18)
	PixelBurst.spawn(b, b.global_position, PixelBurst.SPARK, Vector2.ZERO, 2.0)
	# La fumée arrive quand le corps commence à s'effacer.
	get_tree().create_timer(0.45).timeout.connect(func() -> void:
		if is_instance_valid(b):
			PixelBurst.spawn(b, b.global_position, PixelBurst.SMOKE)
	)
	var shadow := b.get_node_or_null("Shadow") as CanvasItem
	if shadow:
		shadow.create_tween().tween_property(shadow, "modulate:a", 0.0, 1.2)


func _src(hitbox: Hitbox) -> String:
	return String(hitbox.source.name) if is_instance_valid(hitbox.source) else String(hitbox.name)
