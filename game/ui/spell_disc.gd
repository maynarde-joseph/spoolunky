class_name SpellDisc
extends Control

## The spell disc on screen: the spells in hand in a ring round the cross while right
## mouse is held, the one the pointer is on lit in its own colour, and its name in the
## middle. Everything it shows is read off the spider's [SpiderDisc] every frame, so
## it can only show what letting go will do.
##
## The ring goes round in the hand's order, the grapple at the top, so a spell is
## always in the same place: the disc is learned as a set of flicks, not read.

## The ring's inside and outside, in the HUD's 1920x1080 units, and the gap left
## between two slices along the inside.
const INNER := 110.0
const OUTER := 250.0
const GAP := 7.0

## How long it takes to come up and go away, in real seconds.
const FADE := 0.08

## The panel colour every slice is filled with, and the dimming over the world behind
## the disc while it is up — enough to say the world is held, not enough to hide it.
const FILL := Color(0.06, 0.07, 0.09, 0.8)
const DIM := Color(0.0, 0.0, 0.0, 0.22)
const FAINT := Color(0.72, 0.74, 0.8, 0.85)
const SHADOW := Color(0.0, 0.0, 0.0, 0.5)

var spider: SpiderPlayer

## How far up it is, 0 to 1, eased in real time.
var _shown := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	var disc := _disc()
	var real := delta / Engine.time_scale if Engine.time_scale > 0.0001 else delta
	var up := disc != null and disc.showing
	_shown = move_toward(_shown, 1.0 if up else 0.0, real / FADE)
	visible = _shown > 0.0
	if visible:
		queue_redraw()


func _disc() -> SpiderDisc:
	return spider.disc if spider != null and is_instance_valid(spider) else null


func _draw() -> void:
	var disc := _disc()
	if disc == null or _shown <= 0.0:
		return
	var spells := spider.spells
	var keys := disc.slices()
	var count := keys.size()
	if count == 0 or spells == null:
		return
	var middle := size * 0.5
	var grow := lerpf(0.9, 1.0, _shown)
	var inner := INNER * grow
	var outer := OUTER * grow
	draw_rect(Rect2(Vector2.ZERO, size), Color(DIM, DIM.a * _shown))
	var pointed := disc.pointed_index()
	var holding := spells.current()
	for i in count:
		_slice(middle, inner, outer, i, count, keys[i], i == pointed, keys[i] == holding,
			spells)
	_centre(middle, inner, disc, keys, pointed, holding)


## One slice: filled, lit in the spell's colour when the pointer is on it, with its
## name and how long it has still to wait.
func _slice(middle: Vector2, inner: float, outer: float, index: int, count: int,
		spell: SpiderSpell, lit: bool, in_hand: bool, spells: SpiderSpells) -> void:
	var share := TAU / float(count)
	var mid_turn := -PI * 0.5 + share * float(index)
	# Pushed out a little when lit, so the eye finds it before the colour does.
	var push := SpiderDisc.slice_direction(index, count) * (10.0 if lit else 0.0) * _shown
	var centre := middle + push
	var tint := spell.colour
	var fill := FILL.lerp(Color(tint.r, tint.g, tint.b, 0.85), 0.42 if lit else 0.0)
	var waiting := spells.cooling(spell)
	var outline := Color(tint.r, tint.g, tint.b, 1.0 if lit else 0.55)
	var points := _sector(centre, inner, outer, mid_turn - share * 0.5, mid_turn + share * 0.5)
	draw_colored_polygon(points, Color(fill, fill.a * _shown))
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, Color(outline, outline.a * _shown), 3.0 if lit else 1.5, true)

	var font := get_theme_default_font()
	var label_turn := (inner + outer) * 0.5
	var label_at := centre + Vector2.from_angle(mid_turn) * label_turn
	# As wide as the slice is across where the name sits, short of its edges.
	var room := 2.0 * label_turn * sin(share * 0.5) - 26.0
	var name_tint := tint if not waiting else FAINT
	_text(font, label_at + Vector2(0.0, -4.0), spell.display_name, SpiderHUD.BODY_SIZE,
		Color(name_tint, _shown), room)
	var under := "%.1fs" % spells.cooldown_left(spell) if waiting else ("in hand" if in_hand else "")
	if under != "":
		_text(font, label_at + Vector2(0.0, 20.0), under, SpiderHUD.SMALL_SIZE,
			Color(FAINT, FAINT.a * _shown), room)


## The middle: what letting go now takes in hand, and a mark on the inside of the ring
## where the pointer is heading.
func _centre(middle: Vector2, inner: float, disc: SpiderDisc, keys: Array[SpiderSpell],
		pointed: int, holding: SpiderSpell) -> void:
	var font := get_theme_default_font()
	draw_circle(middle, inner - GAP * 2.0, Color(FILL, 0.88 * _shown))
	if pointed < 0:
		var keep := holding.display_name if holding != null else ""
		_text(font, middle + Vector2(0.0, -6.0), "keep", SpiderHUD.SMALL_SIZE,
			Color(FAINT, FAINT.a * _shown))
		_text(font, middle + Vector2(0.0, 20.0), keep, SpiderHUD.BODY_SIZE,
			Color(FAINT, FAINT.a * _shown))
		return
	var spell := keys[pointed]
	_text(font, middle + Vector2(0.0, 10.0), spell.display_name, SpiderHUD.TITLE_SIZE,
		Color(spell.colour, _shown), (inner - GAP * 2.0) * 1.8)
	var mark := middle + disc.pointer.normalized() * (inner - GAP * 3.5)
	draw_circle(mark, 6.0, Color(SHADOW, SHADOW.a * _shown))
	draw_circle(mark, 4.5, Color(spell.colour, _shown))


## The outline of a slice of the ring between two turns, with a gap down each side
## that is the same width all the way out.
func _sector(centre: Vector2, inner: float, outer: float, from: float, to: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var steps := 18
	var trim_out := GAP * 0.5 / outer
	var trim_in := GAP * 0.5 / inner
	for i in steps + 1:
		var turn := lerpf(from + trim_out, to - trim_out, float(i) / float(steps))
		points.append(centre + Vector2.from_angle(turn) * outer)
	for i in steps + 1:
		var turn := lerpf(to - trim_in, from + trim_in, float(i) / float(steps))
		points.append(centre + Vector2.from_angle(turn) * inner)
	return points


## A line of text centred on [param at], over a shadow so it reads on anything, and
## made smaller until it is no wider than [param room], if there is a room to fit.
func _text(font: Font, at: Vector2, text: String, font_size: int, tint: Color,
		room := -1.0) -> void:
	var wide := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	while room > 0.0 and wide > room and font_size > 13:
		font_size -= 1
		wide = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var start := at - Vector2(wide * 0.5, 0.0)
	draw_string(font, start + Vector2(1.5, 1.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
		Color(SHADOW, SHADOW.a * tint.a))
	draw_string(font, start, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, tint)
