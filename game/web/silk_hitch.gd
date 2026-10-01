class_name SilkHitch
extends Node3D

## A line with one end tied to the world and the other on something still alive.
##
## Every other thing silk connects to has an answer to "who moves" before the
## line lands: a wall is fixed so the spider moves, a wrapped catch is finished
## so the catch moves, a web off its anchors comes along with whatever is in it.
## A creature still on its feet is the one case where both ends can pull, and the
## hitch settles it by taking one end out of the argument. The line is tied to
## the ground you were standing on. The creature can go anywhere it likes inside
## that radius and nowhere outside it.
##
## Which makes the level the weapon, and that is the point of it: a wasp hitched
## beside a doorway cannot follow you through it, and one hitched inside the
## reach of a web you already built is one you can keep shooting at while it
## works the line loose. It is not a pin — it never stops moving, and it always
## gets free in the end. What it buys is *where*.

## Fired when the line parts, whether it was worn through, over-stretched, or
## the thing on the end of it stopped being something to hold.
signal snapped(cargo: Node3D)

## How many points the drawn line is made of. Enough to sag, no more.
const SPAN_POINTS := 10

## How far below the straight line the middle of a fully slack line hangs, as a
## share of its length.
const SAG := 0.22

## The fixed end, in world space. Set before it enters the tree.
var anchor := Vector3.ZERO

## The live end.
var cargo: Prey = null

## How far the creature gets from the anchor before the line starts pulling.
var length := 3.0

## How hard it is hauled back per second once it is past that.
var haul_force := 8.0

## What is left of the silk.
##
## Spent by the creature's own [method Prey.thrash_power] while the line is taut
## and only while it is taut, so something that settles down inside its radius
## costs the hitch nothing. That is deliberate: silk already on the creature has
## taken fight out of it, so a softened catch stays hitched far longer than a
## fresh one, and the two mechanics multiply instead of sitting side by side.
var strength := 30.0

## Past this many times its length the line parts at once, however fresh it is.
## A creature that gets flung this far has been thrown by something bigger than
## a hitch is meant to argue with.
var snap_strain := 2.5

var _mesh: ImmediateMesh
var _material: StandardMaterial3D
var _view: MeshInstance3D
var _colour := Color(0.92, 0.94, 1.0, 0.85)


## Ties one, ready to be dropped into the level.
static func tie(to: Prey, at: Vector3, span: float, hold: float) -> SilkHitch:
	if to == null or not is_instance_valid(to):
		return null
	var hitch := SilkHitch.new()
	hitch.name = "SilkHitch"
	hitch.cargo = to
	hitch.anchor = at
	hitch.length = maxf(span, 0.1)
	hitch.strength = maxf(hold, 0.1)
	return hitch


func _ready() -> void:
	add_to_group("silk_hitches")
	_build_view()


func _physics_process(delta: float) -> void:
	if not _still_worth_holding() or strength <= 0.0:
		_part()
		return

	var offset := cargo.global_position - anchor
	var span := offset.length()
	if span > length * snap_strain:
		_part()
		return

	if span > length and span > 0.0001:
		var along := offset / span
		# Pulled back towards the anchor rather than placed at the end of the
		# line, so it swings and keeps swinging — the same rope-not-rod rule the
		# tether runs on, and for the same reason.
		cargo.tow(-along * (span - length) * haul_force * delta)
		# Only while it is pulling. Spent up here rather than inside the branch
		# that spends it, so a line with nothing left parts on the frame it runs
		# out and not on the next frame the creature happens to strain against it.
		strength -= cargo.thrash_power() * delta

	_draw(span)


## Whether there is still anything worth holding on the end of it.
##
## A creature a web has taken is not this line's business any more: it is held by
## something better, and leaving the hitch on it means two things hauling one
## body in different directions. Same for a bundle, which is cargo for the tether.
func _still_worth_holding() -> bool:
	if cargo == null or not is_instance_valid(cargo) or cargo.is_queued_for_deletion():
		return false
	return not cargo.eaten and not cargo.is_stuck() and not cargo.is_bundled() \
		and not cargo.is_dead()


## How much line is out, as a share of its length. Nothing to do with whether it
## holds — it is what the drawing needs to know how far to let the middle hang.
func slack() -> float:
	if cargo == null or not is_instance_valid(cargo) or length <= 0.0:
		return 1.0
	return clampf(1.0 - anchor.distance_to(cargo.global_position) / length, 0.0, 1.0)


## Whether the line is pulling right now.
func is_taut() -> bool:
	if cargo == null or not is_instance_valid(cargo):
		return false
	return anchor.distance_to(cargo.global_position) > length


func _part() -> void:
	var was := cargo
	cargo = null
	snapped.emit(was)
	queue_free()


func _build_view() -> void:
	_material = WebGeometry.silk_material()
	_mesh = ImmediateMesh.new()
	_view = MeshInstance3D.new()
	_view.name = "HitchLine"
	_view.mesh = _mesh
	_view.material_override = _material
	_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_view.top_level = true
	add_child(_view)
	_view.transform = Transform3D.IDENTITY


## Drawn every frame, because both ends move: the creature obviously, and the
## anchor whenever the level it is tied to does.
func _draw(span: float) -> void:
	if _mesh == null:
		return
	_mesh.clear_surfaces()
	var tail := cargo.global_position
	var droop := Vector3.DOWN * span * SAG * slack()
	var width := maxf(length * 0.008, 0.004)
	var previous := anchor
	for i in range(1, SPAN_POINTS + 1):
		var t := float(i) / float(SPAN_POINTS)
		# A parabola through both ends, deepest in the middle. Good enough for a
		# line that is taut most of the time it is on screen, and it costs no
		# simulation state to be right at both ends.
		var point := anchor.lerp(tail, t) + droop * (4.0 * t * (1.0 - t))
		WebGeometry.draw_line_into(_mesh, _material, previous, point, width, _colour)
		previous = point
