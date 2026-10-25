extends Sprite2D
## Choisit une variante de dessin d'après la position du décor (toujours la même au même
## endroit) : deux cristaux du même modèle ne se ressemblent pas forcément.

@export var variants: Array[Texture2D] = []


func _ready() -> void:
	if variants.is_empty():
		return
	var p := global_position.round()
	var i := absi(int(p.x) * 73856093 ^ int(p.y) * 19349663) % (variants.size() + 1)
	if i == 0:
		return
	texture = variants[i - 1]
	var size := texture.get_size()
	offset = Vector2(-floorf(size.x / 2.0), -size.y)
