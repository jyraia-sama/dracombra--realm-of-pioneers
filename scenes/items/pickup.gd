class_name Pickup
extends Area2D
## Objet posé au sol, ramassé quand le guerrier marche dessus.

## L'objet représenté.
@export var item: ItemData
## Quantité ramassée.
@export var amount: int = 1
## Délai avant de pouvoir être ramassé, pour voir l'objet jaillir.
@export var pickup_delay: float = 0.35

var _time: float = 0.0
var _collected := false

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	if item != null:
		sprite.texture = item.icon
	_time = randf() * TAU


func _process(delta: float) -> void:
	# L'objet flotte doucement au-dessus du sol.
	_time += delta
	sprite.position.y = -6.0 + sin(_time * 4.0) * 1.5


func _physics_process(delta: float) -> void:
	if _collected:
		return
	pickup_delay -= delta
	if pickup_delay > 0.0:
		return
	for body in get_overlapping_bodies():
		var player := body as Player
		if player != null and _try_collect(player):
			return


## Fait jaillir l'objet depuis `from` jusqu'à sa position actuelle.
func pop_from(from: Vector2) -> void:
	var target := global_position
	global_position = from
	var tween := create_tween()
	tween.tween_property(self, "global_position", target, 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _try_collect(player: Player) -> bool:
	if item.heal_amount > 0:
		# Un cœur reste au sol si le guerrier a déjà tous ses PV.
		if player.health.current_health >= player.health.max_health:
			return false
		player.health.heal(item.heal_amount * amount)
	else:
		Inventory.add_item(item, amount)
	_collected = true
	var tween := create_tween().set_parallel()
	tween.tween_property(sprite, "position:y", sprite.position.y - 10.0, 0.2)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(queue_free)
	return true
