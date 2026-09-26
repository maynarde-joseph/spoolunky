class_name SpiderCamera
extends Node3D

## The camera rig, and the only thing that decides where the player is looking.
##
## Yaw and pitch are kept **in the frame of the surface the spider is on**, not
## in the world. The frame's up is the surface's up, eased, and rolled by
## parallel transport so that walking onto a wall turns the view with you rather
## than spinning it: you keep looking at what you were looking at.
##
## This is the third answer to the same question and the first right one. Taking
## the view from the body outright remapped the mouse mid-stride, every time the
## body rolled. Pinning it to the world instead — which is what it did until now
## — fixed that and broke something worse: movement is worked out in the surface
## plane, so on a wall the mouse's *pitch* axis was the one that turned you along
## the wall and yaw only squashed against it, and on a ceiling, with the world
## still drawn the right way up, pressing right walked you left. A frame that
## rolls with the surface has neither problem, because the mouse and the walking
## are finally in the same space.
##
## Movement asks this rig which way is forward, so walking is camera-relative
## the same way it is in any third-person game, and the body turns to follow.

signal mode_changed(third_person: bool)

## Start behind the spider rather than inside its head.
@export var third_person := true

## How far back the camera sits, in body heights.
@export var distance := 4.5

## How far above the spider the third-person pivot sits, in body heights.
@export var pivot_height := 1.4

## How far up and down you can look, in degrees.
@export var pitch_limit := 88.0

@export var sensitivity := 2.0

## How fast the view rolls onto a new surface, per second.
##
## The movement frame snaps the moment a new surface is adopted, because walking
## wants no lag. The view is what a person sees, so it rolls — a wall arriving
## instantly is a smear, and this is the difference between crawling onto one and
## being teleported onto it.
@export var roll_speed := 7.0

## How fast the arm catches up to where it should be, per second. Zero pins it.
##
## Physics runs at a fixed tick and rendering does not, so a camera placed
## straight from the body's position holds still for a few frames and then jumps
## — every tick, the whole time you are moving. That reads as the movement being
## rough when the movement is fine. Easing the arm instead spreads each step
## across the frames that come after it.
@export var follow_speed := 22.0

## How far the arm may be from where it belongs before it stops easing and simply
## goes there, in body heights.
##
## A spider that was moved rather than having walked — respawned, dropped into a
## level, put somewhere by a test — leaves an easing arm to sweep the whole way
## across the world, which is a smear rather than a camera move. Travel under its
## own power never covers this much in one frame, so nothing real trips it.
@export var snap_distance := 9.0

## How far in the arm comes while winding up a throw, as a fraction of its
## usual length — and how far round the shoulder it swings.
##
## Aiming used to drop to first person, which cost the sight of the spider. The
## camera moves *toward* it instead: closer, off to one side, so the throw is
## framed rather than hidden.
@export var aim_distance_scale := 0.58
@export var aim_shoulder := 0.6
@export var aim_rise := 0.2

## How far into the aim the rig is, 0 to 1. Written by the web builder.
var aim_blend := 0.0

## What the arm refuses to pass through.
@export_flags_3d_physics var collide_with := 1

var yaw := 0.0
var pitch := 0.0

var camera: Camera3D
var _anchor: Node3D
var _body: Node3D
## The surface frame yaw and pitch are measured in. Y is the surface's up.
var _frame := Basis.IDENTITY
## The up the frame is rolling toward, so a teleport can go straight to it.
var _wanted_up := Vector3.UP
## Where the body was when the arm was last placed, for telling travel from a
## teleport.
var _last_body := Vector3.ZERO
## Cleared once the arm has been placed, so the first frame does not ease in
## from wherever the node happened to start.
var _placed := false


func setup(body: Node3D, first_person_anchor: Node3D) -> void:
	_body = body
	_anchor = first_person_anchor
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.top_level = true
	add_child(camera)
	camera.make_current()
	yaw = body.global_rotation.y


## Rolls the frame the mouse works in onto a new surface.
##
## Parallel transport: the frame's back is carried across and flattened against
## the new up rather than rebuilt from scratch. Rebuilding it would spin the view
## about the surface normal by however much the two frames happened to differ,
## which is the lurch that made taking the view from the body unusable.
func roll_onto(up: Vector3, delta: float) -> void:
	if up.length_squared() < 0.000001:
		return
	_wanted_up = up.normalized()
	var y := _frame.y
	if y.length_squared() < 0.000001:
		y = Vector3.UP
	else:
		y = y.normalized()
	if y.dot(_wanted_up) < 0.99999:
		y = y.slerp(_wanted_up, clampf(roll_speed * delta, 0.0, 1.0)).normalized()
	else:
		y = _wanted_up
	_carry_frame(y)


## Rebuilds the frame around a new up, carrying the old forward across.
func _carry_frame(up: Vector3) -> void:
	var y := up
	if y.length_squared() < 0.000001:
		return
	y = y.normalized()
	var z := _frame.z - y * _frame.z.dot(y)
	if z.length_squared() < 0.000001:
		# The roll passed through a right angle, so the old back is the new up.
		# The old right still lies in the new plane, so take the view round that
		# way instead of picking a direction out of the air.
		z = _frame.x - y * _frame.x.dot(y)
	if z.length_squared() < 0.000001:
		z = Vector3.FORWARD - y * Vector3.FORWARD.dot(y)
	if z.length_squared() < 0.000001:
		z = Vector3.RIGHT - y * Vector3.RIGHT.dot(y)
	if z.length_squared() < 0.000001:
		return
	z = z.normalized()
	_frame = Basis(y.cross(z), y, z)


## Which way is up as far as the mouse is concerned.
func frame_up() -> Vector3:
	return _frame.y


## Mouse look, in the frame of whatever the spider is standing on.
func look(mouse_axis: Vector2) -> void:
	var scale := sensitivity / 1000.0
	yaw = wrapf(yaw - mouse_axis.x * scale, -PI, PI)
	var limit := deg_to_rad(pitch_limit)
	pitch = clampf(pitch - mouse_axis.y * scale, -limit, limit)


## Points the camera along a direction, keeping the pitch it already had.
##
## Solved in the frame rather than in the world, so "face that way" means the
## same thing on a wall as on the floor.
func face(direction: Vector3) -> void:
	var local := _frame.transposed() * direction
	var flat := Vector3(local.x, 0.0, local.z)
	if flat.length_squared() < 0.000001:
		return
	flat = flat.normalized()
	yaw = atan2(-flat.x, -flat.z)


func toggle_mode() -> void:
	third_person = not third_person
	mode_changed.emit(third_person)


## Places the camera for this frame. [param body_height] scales the rig so a
## coin-sized spider and a car-sized one both sit sensibly in frame.
##
## [param delta] eases the arm into place. Left out, it snaps — which is what a
## caller wants when it needs the rig to be exactly right this instant rather
## than shortly.
func update(body_height: float, delta := 0.0) -> void:
	if camera == null or _body == null:
		return
	# Travel rolls the view; being *moved* does not. A spider that was respawned,
	# dropped into a level or put somewhere by a test would otherwise spend the
	# next fifth of a second rolling the view onto its new surface — and anything
	# read off the crosshair in that time, a thrown web's plane among it, comes
	# out tilted.
	var jumped := _placed \
		and _last_body.distance_to(_body.global_position) > snap_distance * maxf(body_height, 0.01)
	if jumped or not _placed:
		_carry_frame(_wanted_up)
	_last_body = _body.global_position

	var look_basis := _look_basis()
	var look := -look_basis.z

	var place := _body.global_position
	if third_person:
		var aim := clampf(aim_blend, 0.0, 1.0)
		var lift: float = pivot_height + aim_rise * aim
		# Up the *surface*, which is the frame's up — not the world's, and not the
		# look basis's. The world's up runs along a wall, so lifting the pivot
		# that way slid the camera up the face instead of standing it off, and on
		# a ceiling put the arm through the ceiling. The look basis's up tilts
		# with the pitch, which would slide the pivot forward and back every time
		# the player glanced up or down.
		var standing := _frame.y
		var pivot := _body.global_position + standing * lift * body_height
		# Over the shoulder while aiming: across the look direction, so it swings
		# with the camera rather than with the body.
		var sideways := look.cross(standing)
		if sideways.length_squared() > 0.000001:
			pivot += sideways.normalized() * aim_shoulder * aim * body_height
		var reach: float = distance * lerpf(1.0, aim_distance_scale, aim)
		var wanted := pivot - look * reach * body_height
		place = _unobstructed(pivot, wanted, body_height)
	elif _anchor != null:
		place = _anchor.global_position

	var slip := camera.global_position.distance_to(place)
	if not _placed or jumped or delta <= 0.0 or follow_speed <= 0.0 \
			or slip > snap_distance * maxf(body_height, 0.01):
		camera.global_position = place
		_placed = true
	else:
		# Exponential, so the catch-up rate is the same at any frame rate rather
		# than being however much a lerp weight happens to mean this frame.
		camera.global_position = camera.global_position.lerp(
			place, 1.0 - exp(-follow_speed * delta))

	# Never eased. The arm may lag a step behind the body; where you are looking
	# may not lag behind the mouse.
	camera.global_basis = look_basis
	camera.near = clampf(body_height * 0.02, 0.005, 0.05)


## Yaw and pitch, inside the frame of whatever is underfoot.
func _look_basis() -> Basis:
	return _frame * Basis.from_euler(Vector3(pitch, yaw, 0.0))


## Pulls the camera in if there is something between it and the spider, so it
## never ends up looking through a wall.
func _unobstructed(pivot: Vector3, wanted: Vector3, body_height: float) -> Vector3:
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = []
	var collider := _body as CollisionObject3D
	if collider != null:
		exclude.append(collider.get_rid())
	var query := PhysicsRayQueryParameters3D.create(pivot, wanted, collide_with, exclude)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return wanted
	var margin: float = maxf(body_height * 0.35, 0.05)
	var point: Vector3 = hit["position"]
	var back := (pivot - point)
	if back.length() <= margin:
		return pivot
	return point + back.normalized() * margin


func forward() -> Vector3:
	return -_look_basis().z


func right() -> Vector3:
	return _look_basis().x


func up() -> Vector3:
	return _look_basis().y


## Where aiming starts. In third person that is the spider, not the camera,
## so you cannot anchor silk to something the spider could not reach.
func aim_origin() -> Vector3:
	if not third_person and camera != null:
		return camera.global_position
	if _anchor != null:
		return _anchor.global_position
	return _body.global_position if _body != null else global_position


## Where aiming points: through the crosshair, from the spider.
func aim_forward() -> Vector3:
	if camera == null:
		return forward()
	if not third_person:
		return forward()
	var target := camera.global_position + forward() * 200.0
	var offset := target - aim_origin()
	if offset.length_squared() < 0.000001:
		return forward()
	return offset.normalized()
