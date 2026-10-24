class_name TownLayer
extends Node2D
## Affiche les bâtiments de Town.sites dans la carte de Dracombra, et les tient à jour.
## Doit être y-trié avec le reste du niveau (y_sort_enabled).

var _nodes: Dictionary = {}  # uid de l'enregistrement -> Building


func _ready() -> void:
	y_sort_enabled = true
	Town.changed.connect(_sync)
	_sync()


func _sync() -> void:
	# Retire les bâtiments disparus.
	var alive := {}
	for record in Town.sites:
		alive[int(record["uid"])] = true
	for key in _nodes.keys():
		if not alive.has(key):
			_nodes[key].queue_free()
			_nodes.erase(key)
	for record in Town.sites:
		var data := Town.building(StringName(record["id"]))
		if data == null:
			continue
		var uid := int(record["uid"])
		if _nodes.has(uid):
			(_nodes[uid] as Building).record = record
			(_nodes[uid] as Building).refresh()
		else:
			var b := Building.new()
			b.name = "%s_%d_%d" % [record["id"], int(record["cell"][0]), int(record["cell"][1])]
			add_child(b)
			b.setup(data, record)
			_nodes[uid] = b
