class_name DungeonStairs
extends Node2D
## Escalier du donjon, dessiné par le code (PROVISOIRE) : un trou sombre avec des marches.
## going_down = true : descend à l'étage suivant ; false : remonte vers la ville.

signal used

var going_down := true
var interact: Interactable
var _active := true
var _light: PointLight2D

const LIGHT_TEX := preload("res://assets/lights/light_radial.tres")


func setup(down: bool, active: bool) -> void:
	going_down = down
	interact = Interactable.new()
	interact.name = "Interact"
	interact.prompt = "Descendre" if down else "Remonter en ville"
	interact.radius_tiles = 2.2
	interact.position = Vector2(0, -8)
	add_child(interact)
	interact.interacted.connect(func() -> void: used.emit())
	_light = PointLight2D.new()
	_light.texture = LIGHT_TEX
	_light.texture_scale = 1.4
	_light.color = Color(0.75, 0.55, 1.0) if down else Color(1.0, 0.85, 0.6)
	_light.energy = 0.9
	_light.position = Vector2(0, -10)
	add_child(_light)
	# On ne marche pas sur l'escalier : on s'en approche par le bas pour l'utiliser.
	var body := StaticBody2D.new()
	body.name = "Body"
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(42, 24)
	shape.shape = rect
	shape.position = Vector2(0, -14)
	body.add_child(shape)
	add_child(body)
	set_active(active)


## Un escalier inactif est recouvert d'éclats (il s'ouvre quand la salle est nettoyée).
func set_active(on: bool) -> void:
	_active = on
	if interact:
		interact.enabled = on
	if _light:
		_light.enabled = on
	queue_redraw()


func reveal() -> void:
	set_active(true)
	PixelBurst.spawn(self, global_position, PixelBurst.STONE, Vector2.ZERO, 2.5)
	PixelBurst.spawn(self, global_position, PixelBurst.SMOKE, Vector2.ZERO, 1.0)
	Fx.shake(2.0, 0.25)


func _draw() -> void:
	# Origine au bas de l'escalier. Dalle de pierre autour, trou sombre, marches.
	var w := 36.0
	var h := 26.0
	var top := -h
	draw_rect(Rect2(-w / 2 - 4, top - 4, w + 8, h + 6), Color("1c1622"))
	draw_rect(Rect2(-w / 2 - 3, top - 3, w + 6, h + 4), Color("6e6478"))
	draw_rect(Rect2(-w / 2 - 3, top - 3, w + 6, 2), Color("8f86a0"))
	if not _active:
		draw_rect(Rect2(-w / 2, top, w, h), Color("2a2233"))
		for i in 6:
			var x := -w / 2 + 3 + i * 6
			draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + 3, top + 6 + (i % 3) * 3), Vector2(x + 6, 0)]), Color("3b3048"))
		return
	draw_rect(Rect2(-w / 2, top, w, h), Color("0b0810"))
	var steps := 5
	for i in steps:
		# Les marches rétrécissent et s'assombrissent en s'enfonçant.
		var t := float(i) / steps
		var sw := w * (1.0 - t * 0.45)
		var y := (top + h - 5) - i * 4.5 if going_down else top + 2 + i * 4.5
		var c := Color("8a7f96").darkened(t * 0.75) if going_down else Color("8a7f96").darkened((1.0 - t) * 0.6)
		draw_rect(Rect2(-sw / 2, y, sw, 3), c)
		draw_rect(Rect2(-sw / 2, y + 3, sw, 1), c.darkened(0.4))
