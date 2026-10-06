class_name SpiderCamera
extends Node3D

## The camera rig, and the only thing that decides where the player is looking.
##
## Look direction is kept in **world** yaw and pitch, deliberately not in the
## body's frame. When the spider is on a wall its body rolls onto that wall, but
## the mouse keeps meaning the same thing: left is left, up is up, and the
## horizon stays level. Deriving the view from the body instead — which is what
## this used to do — quietly remaps the mouse axes the moment you leave the
## floor, and that is what made looking around on a wall feel wrong.
##
## We tried the third option too: a frame that rolls onto the surface, so that
## yaw and pitch were measured against the wall rather than the world. It made
## the axes consistent and it was awful to look at — the whole world turning over
## underneath you as you crawl about is far more movement than anybody wants from
## a camera. This rig stays still, and what a wall does to the *controls* is
## fixed where the controls are: see [method SpiderClimb._wish_direction], which
## builds the walk out of this rig's own screen axes flattened onto whatever is
## underfoot. The camera and the walking agree without the camera moving.
##
## Movement asks this rig which way is forward, so walking is camera-relative
## the same way it is in any third-person game, and the body turns to follow.

signal mode_changed(third_person: bool)

## How far down the crosshair the rig looks for something to aim at. Past any
## reach silk has, so what it finds is a real answer and not a clipped one.
const FOCUS_REACH := 512.0

## Start behind the spider rather than inside its head.
@export var third_person := true

## How far back the camera sits, in body heights.
@export var distance := 3.6

## How far off the spider the third-person pivot sits, in body heights.
##
## Measured along the surface the spider is standing on rather than along world
## up, which is the whole of the ceiling bug. On a ceiling a world-up lift puts
## the pivot *inside* the ceiling, and a ray that starts inside a solid does not
## report hitting it — so the arm found nothing in the way and placed the camera
## on the far side of the roof. Off the surface it is always in open air, whatever
## the spider is standing on.
@export var pivot_height := 1.4

## How far up and down you can look, in degrees.
@export var pitch_limit := 88.0

@export var sensitivity := 2.0

## How far the pivot lifts while winding a throw up, in body heights.
##
## Aiming used to drop to first person, which cost the sight of the spider.
## Nothing needs to move to frame a throw: the camera orbits a point *above* the
## spider instead of the spider itself, which drops it down the screen and opens
## up the room over its back — which is where the throw is going. The arm does
## not come in and it does not swing round the shoulder; those were a lot of
## motion for a framing a raised pivot gives for nothing.
@export var aim_rise := 0.9

## How much wider the view goes at a full wind-up, in degrees.
##
## Read by the spider, which owns the field of view because the speed rush writes
## it too and two things lerping one number is two things fighting.
@export var aim_fov_gain := 9.0

## How far into the aim the rig is, 0 to 1. Written by the web builder.
var aim_blend := 0.0

## What the arm refuses to pass through.
@export_flags_3d_physics var collide_with := 1

## Extra room the arm keeps past the corners of the near plane, as a share of
## them. Nothing clips at 1.0 in theory; a little over covers the frame where the
## spider has moved since the arm was placed.
@export_range(1.0, 2.0, 0.05) var clearance := 1.25

## How fast the arm pays back out once whatever pulled it in is out of the way,
## in body heights per second.
##
## It comes *in* at once, always — in is the direction that stops you looking
## through a wall, and nothing else about the rig is eased either: it is placed
## where it belongs every frame. Out has no such hurry, and taken at once it was
## the jerk at every edge: the camera leaping most of a metre back in one frame as
## a ledge slid off the arm, and flicking in and out along a wall the arm kept
## grazing. Six gets a spiderling's whole arm back in about half a second.
@export var arm_let_out := 6.0

## What the crosshair can come to rest on.
##
## Wider than [member collide_with], and the two are not the same question. That
## one is what the camera refuses to pass through; this is what counts as "the
## thing you are pointing at". A creature does not stop a camera and is very much
## something you aim at — leave prey out of this and the cross reads straight
## through a wasp to the floor behind it, and the silk goes where the floor is.
@export_flags_3d_physics var aim_at_layers := 53

var yaw := 0.0
var pitch := 0.0

var camera: Camera3D
var _anchor: Node3D
var _body: Node3D
var _up := Vector3.UP
var _pivot := Vector3.ZERO
var _body_height := 0.25
## Built once. The arm sweeps a ball down its own length rather than casting a
## line: a line finds the middle of the screen clear while a corner of the near
## plane is already inside the wall, which is what looking into a corner did.
var _ball: SphereShape3D
var _sweep: PhysicsShapeQueryParameters3D

## The body's own collider, which the swept ball has to fit inside. See
## [method _boom_radius].
var _collider: CollisionShape3D

## How long the arm is allowed to be right now, in metres — shortened at once by
## anything in the way and let back out at [member arm_let_out]. Negative until
## the arm has first been placed.
var _arm := -1.0

## How far the pivot is allowed to lift right now, in metres, and whether
## something over the spider is holding it down — or was, and it is still coming
## back up. See [method _headroom].
var _lift := -1.0
var _lift_held := false

## The frame the rig last paid anything out on. It is placed twice a frame, from
## physics and from process, and paying out twice would be paying out double.
var _paid_frame := -1


func setup(body: Node3D, first_person_anchor: Node3D) -> void:
	_body = body
	_anchor = first_person_anchor
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.top_level = true
	add_child(camera)
	camera.make_current()
	yaw = body.global_rotation.y
	_ball = SphereShape3D.new()
	_sweep = PhysicsShapeQueryParameters3D.new()
	_sweep.shape = _ball
	_sweep.collision_mask = collide_with
	var collider := _body as CollisionObject3D
	if collider != null:
		_sweep.exclude = [collider.get_rid()]
	_collider = _body.get_node_or_null("Collision") as CollisionShape3D


## Mouse look, in world terms.
func look(mouse_axis: Vector2) -> void:
	var scale := sensitivity / 1000.0
	yaw = wrapf(yaw - mouse_axis.x * scale, -PI, PI)
	var limit := deg_to_rad(pitch_limit)
	pitch = clampf(pitch - mouse_axis.y * scale, -limit, limit)


## Points the camera along a direction, keeping it level.
func face(direction: Vector3) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length_squared() < 0.000001:
		return
	flat = flat.normalized()
	yaw = atan2(-flat.x, -flat.z)


func toggle_mode() -> void:
	third_person = not third_person
	mode_changed.emit(third_person)


## Forgets whatever was holding the rig in, so the next placing puts it straight
## where it belongs.
##
## For when the spider is *put* somewhere — a respawn, a test setting a scene —
## rather than getting there. The ledge it was under a moment ago is not over it
## now, and easing back out from under something that is not there is the camera
## drifting for no reason.
func settle() -> void:
	_arm = -1.0
	_lift = -1.0
	_lift_held = false


## Places the camera for this frame. [param body_height] scales the rig so a
## coin-sized spider and a car-sized one both sit sensibly in frame.
##
## [param body_up] is the way the spider's back is facing, which is what the
## pivot is measured against — see [member pivot_height]. The spider hands over
## [method SpiderClimb.view_up], the body as far as it has rolled, rather than the
## surface it has just decided on, so the pivot swings round a corner instead of
## jumping to the other side of it.
func update(body_height: float, body_up := Vector3.UP) -> void:
	if camera == null or _body == null:
		return
	_up = body_up.normalized() if body_up.length_squared() > 0.000001 else Vector3.UP
	_body_height = maxf(body_height, 0.001)
	camera.near = clampf(body_height * 0.02, 0.005, 0.05)
	var look_basis := Basis.from_euler(Vector3(pitch, yaw, 0.0))
	var look := -look_basis.z

	var frame := Engine.get_process_frames()
	var paying := frame != _paid_frame
	_paid_frame = frame

	# Winding a throw up raises the point the arm orbits, so the spider sits
	# lower in frame and you see over its back. The arm's length is untouched.
	var lift: float = (pivot_height + aim_rise * clampf(aim_blend, 0.0, 1.0)) * body_height
	# Swept out from the middle of the body rather than set down beside it, so it
	# is never inside anything either — see [method _unobstructed].
	var root := _body.global_position
	var room := root.distance_to(_unobstructed(root, root + _up * lift))
	_pivot = root + _up * _headroom(room, lift, paying)

	if third_person:
		var full := distance * body_height
		var reach := _pivot.distance_to(_unobstructed(_pivot, _pivot - look * full))
		_arm = _pay_out(_arm, reach, paying)
		camera.global_position = _pivot - look * _arm
	elif _anchor != null:
		camera.global_position = _anchor.global_position
	else:
		camera.global_position = _body.global_position

	camera.global_basis = look_basis


## How much room the arm keeps between the camera and anything solid.
##
## Two lower bounds, and the bigger of them wins.
##
## The near plane is what strictly clips: a rectangle a few centimetres in front
## of the lens, and the moment one of its four corners is inside a wall you are
## looking through that wall. Measured, that corner is about a centimetre for a
## spiderling — far *less* than the share of body height this used to keep, which
## is worth knowing, because it says the old margin was never the reason anything
## clipped. What clipped was the pivot ending up inside a ceiling; see
## [member pivot_height].
##
## So the body-height share stays as the floor. It is not about clipping, it is
## about being able to see past the spider at all, and dropping to the near
## plane's corner would have quietly pulled the camera much tighter into walls
## than it used to sit.
##
## What the sweep actually uses is capped a shade under the body's own radius —
## see [method _boom_radius] for why it has to fit inside the body.
func _clearance() -> float:
	var half_height: float = camera.near * tan(deg_to_rad(camera.fov) * 0.5)
	var half_width := half_height * _aspect()
	var corner := Vector3(half_width, half_height, camera.near).length() * clearance
	return maxf(corner, _body_height * 0.35)


func _aspect() -> float:
	var view := camera.get_viewport()
	if view == null:
		return 1.78
	var size := view.get_visible_rect().size
	if size.y <= 0.0 or size.x <= 0.0:
		return 1.78
	return size.x / size.y


## The size of the ball the rig is swept with: as much room as [method _clearance]
## asks for, but never more than fits inside the spider's own body.
##
## Because the sweep starts in the middle of the body, and it has to start *clear*
## rather than nearly clear. Jolt ignores whatever a cast begins inside — measured:
## a ball starting a millimetre into a wall passes straight through it, in every
## direction — while one that merely touches is stopped dead. The body is the one
## place the physics already keeps out of every wall, so a ball that fits inside it
## starts clear by construction. A ball as big as the body did not: pressed into a
## corner it began a hair inside one wall or a hair outside it, and the camera went
## through the wall or collapsed onto the spider depending on which.
func _boom_radius() -> float:
	var shape := _collider.shape if _collider != null else null
	var body := _body_height * 0.35
	if shape is CapsuleShape3D:
		body = (shape as CapsuleShape3D).radius
	elif shape is SphereShape3D:
		body = (shape as SphereShape3D).radius
	return minf(_clearance(), body * 0.9)


## Carries the rig from [param from] towards [param wanted] until it would touch
## something, so it never ends up looking through a wall. Used twice: out from the
## body to the pivot, then from the pivot down the arm.
##
## A ball swept rather than a line cast. A line reports the middle of the screen
## and nothing else, so a corner or a doorframe could be inside the frustum with the
## centre ray still clear — which is exactly what looking into a corner looked like.
##
## The pivot used to be set down off the body directly and the arm swept from
## there. Near a wall that start was *in* the wall often enough to matter, and a
## cast that starts inside something ignores it; starting from the body and carrying
## the start along with each leg is what makes every leg start clear.
func _unobstructed(from: Vector3, wanted: Vector3) -> Vector3:
	if _sweep == null or _ball == null:
		return wanted
	var travel := wanted - from
	if travel.length_squared() < 0.000001:
		return wanted
	_ball.radius = _boom_radius()
	_sweep.transform = Transform3D(Basis.IDENTITY, from)
	_sweep.motion = travel
	_sweep.collision_mask = collide_with
	var space := get_world_3d().direct_space_state
	var reached := space.cast_motion(_sweep)
	# Empty means the query could not run at all.
	if reached.size() < 1:
		return wanted
	return from + travel * reached[0]


## [param current] brought to [param reach]: at once if that is shorter, and paid
## out towards it at [member arm_let_out] if it is longer — once a frame, however
## many times the rig is placed in it.
func _pay_out(current: float, reach: float, paying: bool) -> float:
	if current < 0.0 or reach <= current:
		return reach
	if not paying:
		return current
	return minf(reach, current + arm_let_out * _body_height * get_process_delta_time())


## How far the pivot lifts this frame: all the way while nothing is over the
## spider, only as far as there is [param room] the moment something is, and back
## up at [member arm_let_out] once it has gone.
##
## The arm's rule, and for the arm's reason. Walking in under a ledge lower than
## the pivot has to bring the pivot down at once, or it is inside the ledge — which
## is the ceiling bug over again, a crosshair cast from inside a solid reading
## straight through it. Walking back out has no such hurry, and taken at once the
## view sprang up a body length in a frame. Straight up to [param wanted] whenever
## nothing has been in the way, though, so winding a throw up still lifts the view
## the frame it is asked to.
func _headroom(room: float, wanted: float, paying: bool) -> float:
	if room < wanted - 0.0001:
		_lift_held = true
	if not _lift_held:
		_lift = wanted
		return wanted
	_lift = _pay_out(_lift, room, paying)
	if _lift >= wanted - 0.0001:
		_lift_held = false
	return _lift


func forward() -> Vector3:
	return -Basis.from_euler(Vector3(pitch, yaw, 0.0)).z


func right() -> Vector3:
	return Basis.from_euler(Vector3(pitch, yaw, 0.0)).x


func up() -> Vector3:
	return Basis.from_euler(Vector3(pitch, yaw, 0.0)).y


## Where aiming starts. In third person that is the spider, not the camera,
## so you cannot anchor silk to something the spider could not reach.
func aim_origin() -> Vector3:
	if not third_person and camera != null:
		return camera.global_position
	if _anchor != null:
		return _anchor.global_position
	return _body.global_position if _body != null else global_position


## The point the crosshair's own ray goes through.
##
## The camera sits at `pivot - look * distance` and looks along `look`, so the
## line out of the middle of the screen passes exactly through the pivot. That
## makes this the one place the crosshair can be reasoned about without knowing
## how long the arm currently is — which matters, because the arm changes length
## every time the camera is pulled in off a wall.
func aim_pivot() -> Vector3:
	if not third_person or _body == null:
		return aim_origin()
	return _pivot


## What the crosshair is actually on, in the world.
##
## Cast down the crosshair's own ray, so the answer is the thing you can see
## under it. Aiming then runs *from the spider to that point*, which is what makes
## a third-person crosshair tell the truth: the camera is behind and above the
## spider, so a shot fired along the camera's direction and a shot fired at what
## the camera is looking at are two different shots, and only the second one goes
## where the crosshair says.
func aim_focus() -> Vector3:
	var origin := aim_pivot()
	var ahead := forward()
	var far := origin + ahead * FOCUS_REACH
	if camera == null or not third_person:
		return far
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = []
	var collider := _body as CollisionObject3D
	if collider != null:
		exclude.append(collider.get_rid())
	var query := PhysicsRayQueryParameters3D.create(origin, far, aim_at_layers, exclude)
	# A web's sticky face is an Area3D, and it is the part of a web you point at.
	query.collide_with_areas = true
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return far
	var point: Vector3 = hit["position"]
	# Something under the crosshair but level with the spider or behind it would
	# turn the aim round and fire backwards. The far point is the honest answer to
	# a crosshair pressed up against a wall.
	var from := aim_origin()
	if (point - from).dot(ahead) <= 0.0:
		return far
	return point


## Where aiming points: from the spider, at whatever the crosshair is on.
func aim_forward() -> Vector3:
	if camera == null or not third_person:
		return forward()
	var offset := aim_focus() - aim_origin()
	if offset.length_squared() < 0.000001:
		return forward()
	return offset.normalized()
