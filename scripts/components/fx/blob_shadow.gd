class_name BlobShadow
extends Node2D
## Ombre ovale sous les pieds d'un personnage, dessinée en « gros pixels ».
## Elle reste au sol quand le sprite saute (araignée, roulade...) : ça donne du relief.
## Ajoutée automatiquement par l'autoload Fx sous chaque personnage (voir fx.gd).

## Largeur de l'ombre en px monde (la hauteur vaut ~40 % de la largeur).
@export var width: float = 12.0
@export var color: Color = Color(0.05, 0.03, 0.08, 0.28)


func _ready() -> void:
	# Dessinée avant (donc sous) le reste du personnage.
	show_behind_parent = false
	z_index = 0


func _draw() -> void:
	var w := maxf(4.0, roundf(width))
	var h := maxf(2.0, roundf(w * 0.4))
	# Ellipse découpée en bandes horizontales d'un pixel : bords nets, pas d'anti-aliasing.
	var rows := int(h)
	for i in rows:
		var y := (float(i) + 0.5) / h * 2.0 - 1.0
		var half := roundf(w * 0.5 * sqrt(maxf(0.0, 1.0 - y * y)))
		if half <= 0.0:
			continue
		draw_rect(Rect2(-half, float(i) - roundf(h / 2.0), half * 2.0, 1.0), color)


func set_width(value: float) -> void:
	width = value
	queue_redraw()
