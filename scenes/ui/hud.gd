extends CanvasLayer
## Interface provisoire : points de vie du guerrier et ressources ramassées.
## Elle sera remplacée par de vrais cœurs et une vraie barre d'objets en pixel art.

@onready var health_label: Label = $HealthLabel
@onready var items_box: HBoxContainer = $Items

## Une étiquette par objet affiché, indexée par l'identifiant de l'objet.
var _item_labels: Dictionary[StringName, Label] = {}


func _ready() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		health_label.text = ""
	else:
		player.health.health_changed.connect(_on_health_changed)
		_on_health_changed(player.health.current_health, player.health.max_health)

	Inventory.item_changed.connect(_on_item_changed)
	for item in Inventory.get_items():
		_on_item_changed(item, Inventory.get_count(item.id))


func _on_health_changed(current: int, maximum: int) -> void:
	health_label.text = "PV : %d / %d" % [current, maximum]


func _on_item_changed(item: ItemData, count: int) -> void:
	if not _item_labels.has(item.id):
		var icon := TextureRect.new()
		icon.texture = item.icon
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icon.tooltip_text = item.display_name
		items_box.add_child(icon)
		var label := Label.new()
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 4)
		items_box.add_child(label)
		_item_labels[item.id] = label
	_item_labels[item.id].text = "%d" % count
