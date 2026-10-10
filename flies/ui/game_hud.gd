class_name GameHUD
extends CanvasLayer

## What is on screen while a level is played: the cross, the clock, the silk left,
## the flies still out, and a line of news.
##
## The cross reads off the answers the verbs act on, so it cannot promise what
## they will not do. It is blue where a web thrown now would stick and hold you,
## faint anywhere else; its ring is whole while a hold would ride, and broken while
## the grapple is spent. An arc fills round it as left mouse is held, and a hold
## goes when it closes.

const FONT_SIZE := 22

var run: LevelRun

var _cross: Control
var _clock: Label
var _best: Label
var _flies: Label
var _news: Label
var _help: Label
var _result: PanelContainer
var _result_text: Label
var _news_left := 0.0
var _help_left := 7.0
var _silk_flash := 0.0


func setup(level_run: LevelRun) -> void:
	run = level_run
	run.weaver.notice.connect(say)
	run.weaver.out_of_silk.connect(func() -> void: _silk_flash = 0.6)
	run.finished.connect(_on_finished)
	var best := run.best_time()
	if best >= 0.0:
		_best.text = "best %s" % clock_text(best)
	elif run.level.has("par"):
		_best.text = "par %s" % clock_text(float(run.level["par"]))


func _ready() -> void:
	layer = 5
	_cross = Control.new()
	_cross.name = "Cross"
	_cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cross.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cross.draw.connect(_draw_cross)
	add_child(_cross)

	_clock = _label(Vector2.ZERO, FONT_SIZE + 10)
	_place(_clock, 0.5, 0.0, Rect2(-160, 14, 320, 40))
	_best = _label(Vector2.ZERO, FONT_SIZE - 6)
	_place(_best, 0.5, 0.0, Rect2(-160, 56, 320, 30))
	_best.modulate = Color(1, 1, 1, 0.7)
	_flies = _label(Vector2.ZERO, FONT_SIZE)
	_place(_flies, 0.5, 0.0, Rect2(-160, 84, 320, 32))
	_news = _label(Vector2.ZERO, FONT_SIZE)
	_place(_news, 0.5, 1.0, Rect2(-500, -150, 1000, 36))
	_help = _label(Vector2.ZERO, FONT_SIZE - 4)
	_place(_help, 0.5, 1.0, Rect2(-700, -44, 1400, 30))
	_help.text = "WASD walk · Space jump · LEFT MOUSE tap: throw a web · hold: throw and ride it · RIGHT MOUSE call your oldest web home · R restart · Esc pause"

	_result = PanelContainer.new()
	_result.name = "Result"
	_place(_result, 0.5, 0.5, Rect2(-300, -110, 600, 220))
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.08, 0.09, 0.12, 0.88)
	box.border_color = Color(1.0, 0.78, 0.3)
	box.set_border_width_all(3)
	box.set_corner_radius_all(10)
	box.set_content_margin_all(24)
	_result.add_theme_stylebox_override("panel", box)
	_result_text = Label.new()
	_result_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_result_text.add_theme_font_size_override("font_size", FONT_SIZE + 4)
	_result.add_child(_result_text)
	_result.visible = false
	add_child(_result)


## Pins [param control] to the point [param x], [param y] of the screen (0 to 1
## across and down), at [param rect] from it.
func _place(control: Control, x: float, y: float, rect: Rect2) -> void:
	control.anchor_left = x
	control.anchor_right = x
	control.anchor_top = y
	control.anchor_bottom = y
	control.offset_left = rect.position.x
	control.offset_top = rect.position.y
	control.offset_right = rect.position.x + rect.size.x
	control.offset_bottom = rect.position.y + rect.size.y
	if control is Label:
		(control as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _label(at: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


## Puts [param text] up for a few seconds.
func say(text: String) -> void:
	_news.text = text
	_news_left = 2.6
	_news.modulate.a = 1.0


static func clock_text(seconds: float) -> String:
	var whole := int(seconds)
	return "%02d:%02d.%02d" % [whole / 60, whole % 60, int(fmod(seconds, 1.0) * 100.0)]


func _process(delta: float) -> void:
	if run == null or run.weaver == null:
		return
	_clock.text = clock_text(run.time)
	_flies.visible = run.flies_total > 0
	if run.flies_left() > 0:
		_flies.text = "flies %d / %d" % [run.flies_taken, run.flies_total]
		_flies.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	else:
		_flies.text = "every fly taken — to the bag"
		_flies.add_theme_color_override("font_color", Color(1.0, 0.78, 0.3))
	_news_left -= delta
	_news.modulate.a = clampf(_news_left, 0.0, 1.0)
	_help_left -= delta
	_help.modulate.a = clampf(_help_left, 0.0, 1.0) * 0.85
	_silk_flash = maxf(0.0, _silk_flash - delta)
	_cross.queue_redraw()


func _on_finished(seconds: float, best: float) -> void:
	var line := "OUT\n%s" % clock_text(seconds)
	if best < 0.0 or seconds < best:
		line += "   new best!"
	else:
		line += "   best %s" % clock_text(best)
	line += "\n\nEnter — next level    R — again    Esc — menu"
	_result_text.text = line
	_result.visible = true


func _draw_cross() -> void:
	var weaver := run.weaver if run != null else null
	if weaver == null:
		return
	var middle := _cross.size * 0.5
	var shadow := Color(0, 0, 0, 0.45)
	var target := weaver.caster.aimed()
	# Blue where a web would stick and hold the spider; faint where it would slide
	# off, be cut, not hold you, or reach nothing.
	var tint := Color(1, 1, 1, 0.4)
	if target.get("holds", false):
		tint = Color(0.6, 0.85, 1.0, 0.95)
	var ring := 11.0
	_cross.draw_circle(middle, 3.0, shadow)
	_cross.draw_circle(middle, 2.2, tint)
	if weaver.grapple_ready:
		_cross.draw_arc(middle, ring, 0.0, TAU, 40, shadow, 4.0, true)
		_cross.draw_arc(middle, ring, 0.0, TAU, 40, tint, 2.0, true)
	else:
		for k in 4:
			var from := TAU * float(k) / 4.0 + 0.3
			_cross.draw_arc(middle, ring, from, from + 0.9, 8, tint * Color(1, 1, 1, 0.6), 2.0, true)
	if weaver.caster.charging:
		var wound := weaver.caster.charge
		_cross.draw_arc(middle, ring + 7.0, -PI * 0.5, -PI * 0.5 + TAU * wound, 48,
			Color(0.9, 0.95, 1.0, 0.95), 3.0, true)
	# Silk left: a bead for each web, filled while it is the spider's to throw.
	var count := weaver.max_webs
	var left := weaver.webs_left()
	var spacing := 26.0
	var base := Vector2(middle.x - spacing * float(count - 1) * 0.5, _cross.size.y - 90.0)
	for i in count:
		var at := base + Vector2(spacing * float(i), 0.0)
		var flash := _silk_flash > 0.0 and int(_silk_flash * 10.0) % 2 == 0
		_cross.draw_circle(at, 10.5, Color(0.1, 0.1, 0.14, 0.75))
		if i < left:
			_cross.draw_circle(at, 7.5, Color(0.95, 0.96, 1.0, 0.95))
		else:
			_cross.draw_arc(at, 8.0, 0.0, TAU, 24,
				Color(1.0, 0.4, 0.35, 0.9) if flash else Color(1, 1, 1, 0.4), 2.0, true)
