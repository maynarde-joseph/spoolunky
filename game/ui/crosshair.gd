class_name Crosshair
extends Control

## The cross in the middle of the screen, and what it can tell you about the silk.
##
## Everything it draws is read off the answers the grapple and the shot act on, so
## it cannot promise what they will not do:
##
## * A dot in the middle of the view, and a ring round it the size of the pick: a
##   creature whose outline reaches inside the ring is what a shot will be thrown at.
## * Bright when silk has something in reach to land on, faint when it has not, and
##   warm when a creature is picked.
## * A small ring where the grapple will really land, whenever that is not the
##   middle. The camera sits above the spider and sees over things the spider
##   cannot, so silk can stop short on a ledge the cross is looking past.
## * Brackets round a picked creature, and a dot where the shot will meet it —
##   ahead of anything moving, because that is where it will be.
## * An arc round the ring filling while the spell in hand waits to be cast again,
##   and a brighter one while a throw is wound up.

## What the cross is over.
enum Mark {
	NOTHING,   ## nothing in reach: a grapple has nowhere to go
	SURFACE,   ## somewhere silk can land
	CREATURE,  ## a creature a shot would be thrown at
}

const DOT := 2.5
const WIDTH := 2.0
const NOTHING_TINT := Color(1.0, 1.0, 1.0, 0.35)
const SURFACE_TINT := Color(1.0, 1.0, 1.0, 0.85)
const CREATURE_TINT := Color(1.0, 0.72, 0.3, 0.95)
const OFFSET_TINT := Color(1.0, 0.55, 0.45, 0.9)
## Drawn under every line, so the cross still reads against a pale wall.
const SHADOW := Color(0.0, 0.0, 0.0, 0.4)

var spider: SpiderPlayer

## What it was over when it last drew, and the creature it bracketed — so a check
## can ask what the player was shown rather than work it out again.
var mark: Mark = Mark.NOTHING
var target: Prey = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Anchors and offsets both: anchors alone keep whatever rectangle the control
	# already has, which for a new one is none at all, and the middle of nothing is
	# the corner of the screen.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	read()
	queue_redraw()


## Works out what the cross is over, from the builder's own answers. Every frame
## before drawing, and on its own for anything that wants to know without drawing.
func read() -> void:
	var builder := spider.web_builder if spider != null else null
	target = builder.shot_target() if builder != null else null
	if target != null:
		mark = Mark.CREATURE
	elif builder != null and builder.aim_valid:
		mark = Mark.SURFACE
	else:
		mark = Mark.NOTHING


func _draw() -> void:
	var middle := size * 0.5
	var builder := spider.web_builder if spider != null else null
	var camera := spider.view.camera if spider != null and spider.view != null else null
	if builder == null or camera == null:
		_ring(middle, 8.0, NOTHING_TINT)
		return
	if target != null and not is_instance_valid(target):
		read()
	var tint: Color = [NOTHING_TINT, SURFACE_TINT, CREATURE_TINT][mark]
	var ring := pick_radius()

	_ring(middle, ring, tint)
	_dot(middle, DOT, tint)
	if mark == Mark.SURFACE:
		_landing(builder, camera, middle, ring)
	elif mark == Mark.CREATURE:
		_bracket(builder, camera)

	var outer := ring + 5.0
	var spells := spider.spells
	var holding := spells.current() if spells != null else null
	if builder.aiming:
		_arc(middle, outer, builder.charge, Color(CREATURE_TINT, 1.0), WIDTH + 1.0)
	elif holding != null and spells.cooling(holding):
		# The wait of what right mouse would cast.
		_arc(middle, outer, spells.cooldown_progress(holding), Color(tint, tint.a * 0.7), WIDTH)


## The ring's radius on screen: [member WebBuilder.shot_pick_angle] as the camera
## draws it, in the same units as everything else here.
func pick_radius() -> float:
	if spider == null or spider.view == null or spider.view.camera == null:
		return 8.0
	var camera := spider.view.camera
	var angle := maxf(spider.web_builder.shot_pick_angle, 0.0)
	var per := size.y * 0.5 / tan(deg_to_rad(camera.fov) * 0.5)
	return maxf(per * tan(deg_to_rad(angle)), 7.0)


## Where the grapple will really land, when that is not the middle of the view.
func _landing(builder: WebBuilder, camera: Camera3D, middle: Vector2, ring: float) -> void:
	if camera.is_position_behind(builder.aim_point):
		return
	var lands := camera.unproject_position(builder.aim_point)
	if lands.distance_to(middle) <= ring:
		return
	_line(middle, lands, Color(OFFSET_TINT, 0.35), 1.0)
	_ring(lands, 5.0, OFFSET_TINT)


## Brackets round the picked creature, and a dot where the shot will meet it.
func _bracket(builder: WebBuilder, camera: Camera3D) -> void:
	var at := target.global_position
	if camera.is_position_behind(at):
		return
	var centre := camera.unproject_position(at)
	var edge := camera.unproject_position(at + camera.global_basis.x * target.hit_radius())
	var half := maxf(centre.distance_to(edge), 6.0) + 4.0
	var arm := half * 0.45
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var tip: Vector2 = centre + corner * half
		_line(tip, tip - Vector2(corner.x * arm, 0.0), CREATURE_TINT, WIDTH)
		_line(tip, tip - Vector2(0.0, corner.y * arm), CREATURE_TINT, WIDTH)
	var lead := builder.shot_lead(target)
	if camera.is_position_behind(lead):
		return
	var ahead := camera.unproject_position(lead)
	if ahead.distance_to(centre) > half:
		_line(centre, ahead, Color(CREATURE_TINT, 0.35), 1.0)
	_dot(ahead, DOT + 0.5, CREATURE_TINT)


func _ring(at: Vector2, radius: float, tint: Color) -> void:
	draw_arc(at, radius, 0.0, TAU, 40, SHADOW, WIDTH + 2.0, true)
	draw_arc(at, radius, 0.0, TAU, 40, tint, WIDTH, true)


## A part of a ring, from the top round clockwise, [param done] of the way.
func _arc(at: Vector2, radius: float, done: float, tint: Color, width: float) -> void:
	if done <= 0.001:
		return
	var end := -PI * 0.5 + TAU * clampf(done, 0.0, 1.0)
	draw_arc(at, radius, -PI * 0.5, end, 48, SHADOW, width + 2.0, true)
	draw_arc(at, radius, -PI * 0.5, end, 48, tint, width, true)


func _dot(at: Vector2, radius: float, tint: Color) -> void:
	draw_circle(at, radius + 1.0, SHADOW)
	draw_circle(at, radius, tint)


func _line(from: Vector2, to: Vector2, tint: Color, width: float) -> void:
	draw_line(from, to, SHADOW, width + 2.0, true)
	draw_line(from, to, tint, width, true)
