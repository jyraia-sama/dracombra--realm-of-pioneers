class_name Harvestable
extends Node2D
## Rend un décor récoltable à coups d'épée : un arbre donne du bois, un rocher de la pierre.
## À placer comme enfant du décor. Une fois épuisé, le décor disparaît (et sa collision
## avec) ; il repousse après quelques jours, sauf si `regrow_days` vaut 0.

const PICKUP_SCENE := preload("res://scenes/items/pickup.tscn")
const DUST_SCENE := preload("res://scenes/props/dust_puff.tscn")

## Identifiant de l'objet récolté (wood, stone...).
@export var item_id: StringName = &"wood"
@export var min_amount: int = 2
@export var max_amount: int = 3
## Coups nécessaires.
@export var hits: int = 3
## Jours avant de réapparaître (0 = jamais : décombres déblayés pour de bon).
@export var regrow_days: int = 3
## Taille de la zone qu'on peut frapper, en pixels, posée au pied du décor.
@export var hit_size: Vector2 = Vector2(14, 14)

## Outil qui rend la récolte deux fois plus rapide (et plus généreuse), selon la ressource.
const TOOLS := {&"wood": &"axe", &"stone": &"pickaxe", &"gem": &"pickaxe"}

var health: HealthComponent
var _sprite: CanvasItem
var _hits_taken := 0


func _ready() -> void:
	add_to_group("harvestable")
	_sprite = get_parent().get_node_or_null("Sprite2D") as CanvasItem
	if Game.is_harvested(_key(), regrow_days):
		_set_present(false)
		return
	health = HealthComponent.new()
	health.name = "Health"
	# Les coups sont comptés ici (sans outil, il en faut deux fois plus).
	health.max_health = 9999
	health.invulnerability_duration = 0.15
	add_child(health)
	var hurtbox := Hurtbox.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = 16
	hurtbox.collision_mask = 0
	hurtbox.health = health
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = hit_size
	shape.shape = rect
	shape.position = Vector2(0, -hit_size.y / 2.0)
	hurtbox.add_child(shape)
	add_child(hurtbox)
	hurtbox.hit_received.connect(_on_hit)


func _key() -> String:
	var scene := get_tree().current_scene
	var level := scene.scene_file_path.get_file().get_basename() if scene else "?"
	return "%s:%s" % [level, scene.get_path_to(get_parent()) if scene else get_parent().name]


func has_tool() -> bool:
	return not TOOLS.has(item_id) or Inventory.get_count(TOOLS[item_id]) > 0


func hits_needed() -> int:
	return hits if has_tool() else hits * 2


func _on_hit(_hitbox: Hitbox) -> void:
	_hits_taken += 1
	if _hits_taken >= hits_needed():
		_on_depleted.call_deferred()
	# Le décor tremble sous le coup.
	if _sprite is Node2D:
		var node := _sprite as Node2D
		var tween := create_tween()
		tween.tween_property(node, "position:x", 1.5, 0.04)
		tween.tween_property(node, "position:x", -1.5, 0.06)
		tween.tween_property(node, "position:x", 0.0, 0.04)
	var dust: Node2D = DUST_SCENE.instantiate()
	dust.position = global_position + Vector2(randf_range(-4, 4), -4)
	get_tree().current_scene.add_child(dust)


func _on_depleted() -> void:
	if Game.is_harvested(_key(), regrow_days):
		return
	Game.mark_harvested(_key())
	for child in get_children():
		if child is Hurtbox:
			child.set_deferred("monitorable", false)
	var item := Inventory.item_by_id(item_id)
	var bonus := 1 if TOOLS.has(item_id) and has_tool() else 0
	if item != null:
		for i in randi_range(min_amount, max_amount) + bonus:
			var pickup: Pickup = PICKUP_SCENE.instantiate()
			pickup.item = item
			var at := global_position + Vector2(0, -2)
			pickup.position = at + Vector2.from_angle(randf() * TAU) * randf_range(4.0, 12.0)
			get_tree().current_scene.add_child.call_deferred(pickup)
			pickup.ready.connect(pickup.pop_from.bind(at), CONNECT_ONE_SHOT)
	var tween := create_tween()
	tween.tween_property(get_parent(), "modulate:a", 0.0, 0.35)
	tween.tween_callback(_set_present.bind(false))


## Montre ou cache le décor, avec sa collision.
func _set_present(on: bool) -> void:
	var parent := get_parent() as CanvasItem
	parent.visible = on
	parent.modulate.a = 1.0
	var body := get_parent().get_node_or_null("Body") as StaticBody2D
	if body:
		body.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
		for child in body.get_children():
			if child is CollisionShape2D:
				child.set_deferred("disabled", not on)
	for child in get_children():
		if child is Hurtbox:
			child.set_deferred("monitorable", on)
