class_name GameHUD
extends CanvasLayer

## What is on screen while a level is played: the cross, the flies, the clock, the
## silk left, and a line of news.
##
## The cross reads off the answers the verbs act on, so it cannot promise what
## they will not do. Its ring is bright when the grapple has something to hold,
## red over something slick, faint over nothing in reach, and broken while the
## grapple is spent. It turns gold, and brackets the fly, when a thrown web would
## be aimed at one. An arc fills round it while silk winds up.

const FONT_SIZE := 22

var run: LevelRun

var _cross: Control
var _flies: Label
var _clock: Label
var _best: Label
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
	run.weaver.fly_caught.connect(func(_fly: Fly) -> void:
		say("Fly caught — %d / %d" % [run.caught(), run.flies_total]))
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

	_flies = _label(Vector2(28, 20), FONT_SIZE + 6)
	_clock = _label(Vector2.ZERO, FONT_SIZE + 10)
	_place(_clock, 0.5, 0.0, Rect2(-160, 14, 320, 40))
	_best = _label(Vector2.ZERO, FONT_SIZE - 6)
	_place(_best, 0.5, 0.0, Rect2(-160, 56, 320, 30))
	_best.modulate = Color(1, 1, 1, 0.7)
	_news = _label(Vector2.ZERO, FONT_SIZE)
	_place(_news, 0.5, 1.0, Rect2(-500, -150, 1000, 36))
	_help = _label(Vector2.ZERO, FONT_SIZE - 4)
	_place(_help, 0.5, 1.0, Rect2(-700, -44, 1400, 30))
	_help.text = "WASD run · Space jump · LEFT MOUSE grapple · RIGHT MOUSE silk (hold to grow) · E / MIDDLE MOUSE pullback · R restart · Esc pause"

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
	_flies.text = "FLIES  %d / %d" % [run.caught(), run.flies_total]
	if run.flies_needed < run.flies_total:
		_flies.text += "   (need %d)" % run.flies_needed
	_flies.modulate = Color(1.0, 0.85, 0.4) if run.caught() >= run.flies_needed \
		else Color.WHITE
	_clock.text = clock_text(run.time)
	_news_left -= delta
	_news.modulate.a = clampf(_news_left, 0.0, 1.0)
	_help_left -= delta
	_help.modulate.a = clampf(_help_left, 0.0, 1.0) * 0.85
	_silk_flash = maxf(0.0, _silk_flash - delta)
	_cross.queue_redraw()


func _on_finished(seconds: float, best: float) -> void:
	var line := "IN THE BAG\n%s" % clock_text(seconds)
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
	var target := weaver.grapple.aimed()
	var tint := Color(1, 1, 1, 0.35)
	if not target.is_empty():
		tint = Color(1.0, 0.4, 0.35, 0.95) if target.get("slick", false) \
			else Color(1, 1, 1, 0.92)
		if target.get("web") != null:
			tint = Color(0.6, 0.85, 1.0, 0.95)
	var fly := weaver.caster.picked_fly()
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
	if fly != null:
		var camera := weaver.view.camera
		if camera != null and not camera.is_position_behind(fly.global_position):
			var at := camera.unproject_position(fly.global_position)
			var gold := Color(1.0, 0.78, 0.3, 0.95)
			var s := 16.0
			for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var c: Vector2 = at + corner * s
				_cross.draw_line(c, c - Vector2(corner.x * 7.0, 0.0), gold, 2.0)
				_cross.draw_line(c, c - Vector2(0.0, corner.y * 7.0), gold, 2.0)
	_draw_fly_marks(weaver)
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


## A small gold bead over every fly still out, so they can be found across a
## level — smaller the further off, and dimmer behind a wall.
func _draw_fly_marks(weaver: Weaver) -> void:
	var camera := weaver.view.camera
	if camera == null:
		return
	var space := weaver.get_world_3d().direct_space_state
	for node in get_tree().get_nodes_in_group(Fly.GROUP):
		var fly := node as Fly
		if fly == null or not fly.is_free():
			continue
		var at := fly.global_position + Vector3.UP * 0.45
		if camera.is_position_behind(at):
			continue
		var point := camera.unproject_position(at)
		var distance := camera.global_position.distance_to(at)
		var size := clampf(90.0 / maxf(distance, 1.0), 4.0, 10.0)
		var query := PhysicsRayQueryParameters3D.create(camera.global_position, fly.global_position,
			GameLayers.WORLD, [weaver.get_rid()])
		var hidden := not space.intersect_ray(query).is_empty()
		var gold := Color(1.0, 0.8, 0.3, 0.45 if hidden else 0.95)
		_cross.draw_circle(point, size * 0.75, Color(0, 0, 0, 0.35 if hidden else 0.5))
		_cross.draw_circle(point, size * 0.5, gold)
