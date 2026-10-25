class_name StatBars
extends Control
## Le cadre du héros, en haut à gauche : médaillon de la classe (avec le niveau), barres de
## vie, d'endurance et de mana (classes de magie seulement), et la fine barre d'XP.
## Quand une barre baisse, un reste clair s'efface doucement derrière : on voit ce
## qu'on vient de perdre.

const BAR_W := 104.0
const BAR_H := 7.0
const GAP := 3.0
const MEDAL := 30.0
const FONT_SIZE := 8

const HP_COLORS := [Color8(122, 22, 34), Color8(206, 48, 52), Color8(255, 120, 104)]
const STAMINA_COLORS := [Color8(36, 96, 40), Color8(84, 176, 70), Color8(170, 236, 120)]
const MANA_COLORS := [Color8(28, 46, 120), Color8(60, 108, 220), Color8(140, 196, 255)]
const XP_COLOR := Color8(240, 196, 80)
const FRAME := Color8(28, 20, 30)
const FRAME_LIGHT := Color8(150, 118, 84)
const BACK := Color8(52, 40, 52)

## Valeurs affichées : [actuelle, maximum, reste qui s'efface].
var hp := [0.0, 1.0, 0.0]
var stamina := [0.0, 1.0, 0.0]
var mana := [0.0, 1.0, 0.0]
var show_mana := false
var show_resources := false
var xp_ratio := 0.0
var level := 1
var icon: Texture2D
## Clignotement rouge quand les PV sont bas.
var _pulse := 0.0
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	custom_minimum_size = Vector2(MEDAL + 6 + BAR_W + 4, MEDAL + 8)


func set_values(hp_now: float, hp_max: float, st_now: float, st_max: float, mp_now: float, mp_max: float) -> void:
	_update(hp, hp_now, hp_max)
	_update(stamina, st_now, st_max)
	_update(mana, mp_now, mp_max)


static func _update(bar: Array, now: float, top: float) -> void:
	if now > bar[0] or top != bar[1]:
		bar[2] = maxf(bar[2], now)
	bar[0] = now
	bar[1] = maxf(top, 1.0)


func _process(delta: float) -> void:
	for bar in [hp, stamina, mana]:
		# Le reste attend un peu puis glisse vers la valeur actuelle.
		if bar[2] > bar[0]:
			bar[2] = maxf(bar[0], bar[2] - bar[1] * delta * 0.6)
		else:
			bar[2] = bar[0]
	_pulse += delta
	queue_redraw()


func _draw() -> void:
	# Médaillon : l'arme de la classe et le niveau.
	var m := Rect2(Vector2(0, 0), Vector2(MEDAL, MEDAL))
	draw_rect(m.grow(1), FRAME)
	draw_rect(m, FRAME_LIGHT)
	draw_rect(m.grow(-1), Color8(44, 32, 46))
	draw_rect(Rect2(m.position + Vector2(1, 1), Vector2(MEDAL - 2, 1)), Color8(90, 70, 90))
	if icon:
		draw_texture_rect(icon, Rect2(m.position + Vector2(3, 3), Vector2(MEDAL - 6, MEDAL - 6)), false)
	if show_resources:
		var lv := str(level)
		var w := _font.get_string_size(lv, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		var badge := Rect2(Vector2(MEDAL - w - 5, MEDAL - 8), Vector2(w + 6, 10))
		draw_rect(badge.grow(1), FRAME)
		draw_rect(badge, Color8(120, 84, 40))
		_text(lv, badge.position + Vector2(3, 8), Color.WHITE)

	var x := MEDAL + 5
	var y := 1.0
	var low: bool = hp[0] / hp[1] <= 0.3 and hp[0] > 0
	var hp_cols: Array = HP_COLORS.duplicate()
	if low:
		var k := 0.5 + 0.5 * sin(_pulse * 8.0)
		hp_cols[1] = HP_COLORS[1].lerp(Color8(255, 170, 150), k * 0.5)
	_bar(Vector2(x, y), hp, hp_cols, "%d / %d" % [int(ceil(hp[0])), int(hp[1])])
	y += BAR_H + GAP
	if show_resources:
		_bar(Vector2(x, y), stamina, STAMINA_COLORS, "%d" % int(stamina[0]), BAR_W - 14.0, 5.0)
		y += 5.0 + GAP
		if show_mana:
			_bar(Vector2(x, y), mana, MANA_COLORS, "%d" % int(mana[0]), BAR_W - 6.0, 5.0)
			y += 5.0 + GAP
		# XP : une ligne fine sous les barres.
		var r := Rect2(Vector2(x, y), Vector2(BAR_W - 20.0, 2))
		draw_rect(r.grow(1), FRAME)
		draw_rect(r, BACK)
		draw_rect(Rect2(r.position, Vector2(r.size.x * xp_ratio, 2)), XP_COLOR)


func _bar(at: Vector2, bar: Array, cols: Array, label: String, width: float = BAR_W, height: float = BAR_H) -> void:
	var r := Rect2(at, Vector2(width, height))
	draw_rect(r.grow(1), FRAME)
	draw_rect(r, BACK)
	var ratio := clampf(bar[0] / bar[1], 0.0, 1.0)
	var ghost := clampf(bar[2] / bar[1], 0.0, 1.0)
	if ghost > ratio:
		draw_rect(Rect2(at, Vector2(round(width * ghost), height)), Color8(250, 226, 170))
	var w: float = round(width * ratio)
	if w > 0:
		draw_rect(Rect2(at, Vector2(w, height)), cols[1])
		draw_rect(Rect2(at, Vector2(w, 1)), cols[2])
		draw_rect(Rect2(at + Vector2(0, height - 1), Vector2(w, 1)), cols[0])
	# Graduations tous les 10 points, pour lire la barre d'un coup d'œil.
	var step := 10.0
	if bar[1] / step > 12.0:
		step = 50.0
	var v := step
	while v < bar[1]:
		var gx: float = at.x + round(width * v / bar[1])
		draw_rect(Rect2(Vector2(gx, at.y + 1), Vector2(1, height - 2)), Color(0, 0, 0, 0.25))
		v += step
	if height >= BAR_H:
		_text(label, at + Vector2(width + 4, height - 0.5), Color8(255, 236, 220))
	else:
		_text(label, at + Vector2(width + 4, height + 1), cols[2])


func _text(t: String, at: Vector2, col: Color) -> void:
	draw_string_outline(_font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 3, FRAME)
	draw_string(_font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, col)
