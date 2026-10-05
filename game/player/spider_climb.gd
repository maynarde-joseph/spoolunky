class_name SpiderClimb
extends Node3D

## Sticking to things.
##
## Takes over movement whenever the spider is touching a climbable surface, so
## a floor, a wall and a ceiling are all the same thing: a plane you walk on
## with your back to it. The body's up axis becomes the surface normal, gravity
## is replaced by a pull into the surface, and the camera comes along for the
## ride.
##
## It also carries out the grapple: once [SpiderGrapple] has picked a point, this
## hauls the body over to it and puts it down on the surface there. There is no
## hanging from silk any more — a line is how you get somewhere, not somewhere to
## be.

enum Mode {
	## In the air, normal gravity, looking for something to grab.
	AIRBORNE,
	## Stuck to a surface, whatever angle it is.
	ATTACHED,
	## Hauling itself along a line of silk to where the grapple struck.
	GRAPPLING,
}

signal mode_changed(mode: Mode)
signal surface_changed(normal: Vector3)
signal jumped()
signal grappled(point: Vector3, normal: Vector3)

## How far up a surface has to face to be walked as a floor, and how far down to
## be walked as a ceiling, as the y of its up. Anything between is climbed: see
## [method _climbing_axes].
const FLOOR_UP := 0.98
const CEILING_UP := -0.6

## How far, in degrees, the walk can come apart from the camera's reading of the
## keys before it stops taking the camera's turns, and how close the two have to come
## again before it hands back. See [method _carry_over].
const CARRY_APART := 30.0
const CARRY_TOGETHER := 15.0

## Below this many degrees a change of surface is a curve — the side of a trunk, the
## next facet of a stone — and the body rolls round it over a few frames; at or above
## it the change is an edge, and is taken at once. See [method _adopt_surface].
const CURVE := 40.0

## How much of the way round a curve the body's up goes each physics frame.
const CURVE_FOLLOW := 0.35

## How steep both surfaces have to be — as the y of their ups, either way — for a
## walk carried between them to keep its angle to the way up rather than be carried
## the shortest way round. See [method _uphill_carry].
const STEEP_KEEP := 0.85

## How far from a wall a surface has to be — as the y of its up, either way — for the
## camera's reading of the keys on it to be a steady one the walk can always settle
## back onto: a floor, a ceiling, a gentle slope. See [method _carry_over].
const SETTLE_UP := 0.5


@export_group("Climbing")

## How far the spider's feet reach for a surface, in body heights.
@export var stick_reach := 1.15

## Pull into the surface, in body heights per second. This is what stops a
## spider on a ceiling falling off.
@export var stick_force := 9.0

## How quickly the body rolls over onto a new surface.
@export var orientation_speed := 9.0

## Speed on a vertical or upside-down surface, against speed on the flat.
@export_range(0.1, 1.0, 0.05) var steep_speed_factor := 0.8

@export var acceleration := 14.0

## How much of a grapple's travel along the surface survives the landing: all of
## it, up to the landing's top speed (see [member landing_speed]) — so a glancing
## arrival lands you running and a head-on one stops. Letting go of the keys brakes
## what it kept within a step: the skid that once slid you on past the point with
## nothing held is gone, and so is the dead stop that replaced it.
@export_range(0.0, 1.0, 0.05) var grapple_carry := 1.0

## Seconds a grapple's landing puts a spring in the step for, fading all the way:
## a higher top speed and a harder push toward whatever the keys say, so running on
## from where a grapple lands is one movement rather than a stop and a start.
@export var landing_time := 0.8

## Top speed over a walk at the moment a grapple lands: 0.25 is a quarter as fast
## again. Fades over [member landing_time].
@export var landing_speed := 0.25

## Acceleration over the usual at the moment a grapple lands: 2 is three times as
## hard. Fades over [member landing_time].
@export var landing_push := 2.0

## How fast speed above a walk bleeds off, per second, while the keys go along
## with it.
##
## Deliberately far gentler than [member deceleration], which exists to stop you
## the moment you let go of a key: speed that came from somewhere else — off a
## grapple, out of a fall — is a skid you can use, not something wiped out in four
## frames. Let go, though, and it brakes like anything else.
@export var skid_damping := 1.6
@export var deceleration := 18.0

## Seconds after jumping before the spider may stick to anything again,
## so a jump off a wall actually leaves the wall.
@export var release_grace := 0.22

## Surfaces to climb: the land and everything built on it — a fence, a trough,
## the market's awning.
@export_flags_3d_physics var climbable_layers := GameLayers.WORLD

## Colliders in this group cannot be climbed — glass, grease, a hot pipe.
@export var no_climb_group := "no_climb"

## How far the camera may swing, in degrees, before a walk carried over an edge
## hands back to the camera's own reading of the keys. See [method _carry_over].
@export_range(10.0, 180.0, 5.0) var carry_release_angle := 50.0


@export_group("Grapple")

## How fast the spider hauls itself to where the grapple struck, in body heights
## per second. It is how you get about the farm, so this wants to be brisk.
@export var grapple_speed := 26.0

## Give up on a grapple after this long, so a blocked one cannot hang.
@export var grapple_timeout := 2.5

## Longest a grapple should take, however far it goes. Without this, reaching
## across the farm at a walking pace is a nine-second commute — which is the
## tedium a grapple is there to remove, not add.
@export var grapple_max_travel := 1.1

var mode: Mode = Mode.AIRBORNE
var surface_normal := Vector3.UP

## Where a grapple is heading, and the surface waiting at the other end.
var grapple_target := Vector3.ZERO
var grapple_normal := Vector3.UP

## Speed along the surface, for head bob and footsteps.
var tangent_velocity := Vector3.ZERO

## What speed is multiplied by while dragging something. Written by the tether;
## one means empty-handed.
var haul := 1.0

## How tall the body is, in metres. Everything here that is measured in body
## heights is measured against this; the spider sets it.
var body_height := 0.7

var _spider: CharacterController3D
var _view: SpiderCamera
var _facing := Vector3.FORWARD
var _current_up := Vector3.UP
var _grace := 0.0

## Seconds left of a grapple landing's spring: see [member landing_time].
var _landing := 0.0

var _previous_up := Vector3.ZERO
var _swap_cooldown := 0.0
var _grapple_time := 0.0

## The keys' two directions as last walked, [right, ahead], for as long as a key is
## down: carried round with the surface underfoot as it turns, and steered with the
## camera as it turns. Empty while nothing is held. See [method _carry_over].
var _walked: Array[Vector3] = []

## Whether [member _walked] has stopped taking the camera's turns: the surface has
## brought it apart from the camera's reading of the keys — over an edge, round a
## curve — and it keeps going the way it was going until the two agree again.
var _carrying := false

## Where the camera was looking when the carry began, so swinging it well away
## hands the walk back to the camera.
var _carried_look := Vector3.ZERO

## The camera's yaw and pitch when [member _walked] last took its turn.
var _walked_yaw := 0.0
var _walked_pitch := 0.0

## How far this grapple has to go, measured when it started.
var _grapple_span := 0.0


func setup(spider: CharacterController3D, view: SpiderCamera) -> void:
	_spider = spider
	_view = view
	_facing = -spider.global_basis.z
	_current_up = Vector3.UP
	surface_normal = Vector3.UP


## True while this component is driving the body. Water and free-fly are left
## to the character-controller template.
func handles_movement() -> bool:
	return _spider != null and not _spider.is_fly_mode() and not _in_water()


func is_attached() -> bool:
	return mode == Mode.ATTACHED


func is_grappling() -> bool:
	return mode == Mode.GRAPPLING


## True when the spider is on something it could not stand on upright.
func on_steep_surface() -> bool:
	return mode == Mode.ATTACHED and surface_normal.dot(Vector3.UP) < 0.7


## Direction the body treats as up right now.
func body_up() -> Vector3:
	return _current_up


## Which way the body's back actually faces this frame: [method body_up], as far
## as the body has rolled towards it.
##
## What the camera lifts its pivot along. [method body_up] jumps the instant the
## spider takes a new surface — it is a decision, and movement needs it that way —
## and a pivot hung off it jumped with it: a quarter turn at a spiderling's size
## moved the camera half a metre in one frame, at every corner. The body rolls onto
## the new surface over a few frames instead, so a pivot riding on its back swings
## round with it.
func view_up() -> Vector3:
	if _spider == null:
		return _current_up
	var back := _spider.global_basis.y
	if back.length_squared() < 0.000001:
		return _current_up
	return back.normalized()


## Points the view, and so the body, along a direction.
func face(direction: Vector3) -> void:
	if _view != null:
		_view.face(direction)
	var flat := direction - _current_up * direction.dot(_current_up)
	if flat.length_squared() > 0.000001:
		_facing = flat.normalized()


## Which way "forward" is on a floor or a ceiling: the way the camera is looking,
## flattened onto it. Walls are read another way; see [method _climbing_axes].
##
## Looking straight down at a floor, or straight up at a ceiling, leaves nothing to
## flatten, so it falls back to the camera's own up: the top of the screen.
func _surface_forward(up: Vector3) -> Vector3:
	if _view == null:
		return _facing
	return _surface_forward_for(up, _view.forward(), _view.up())


## [method _surface_forward] for a camera looking along [param look] with the top of
## the screen along [param top].
func _surface_forward_for(up: Vector3, look: Vector3, top: Vector3) -> Vector3:
	var flat := look - up * look.dot(up)
	if flat.length_squared() < 0.02:
		var sideways: float = -signf(look.dot(up))
		if sideways == 0.0:
			sideways = 1.0
		var fallback := top * sideways
		flat = fallback - up * fallback.dot(up)
	if flat.length_squared() < 0.000001:
		return _facing
	return flat.normalized()


## Rolls the body toward the surface it is on. Runs every frame, including the
## frames where the template is driving movement, so mouse look never stalls.
func update_orientation(delta: float) -> void:
	if _spider == null:
		return
	# The body turns to face where W walks it — the walk as it is being carried while
	# a key is down, the camera's reading otherwise — and the camera never follows
	# the body.
	var walking := _flat(_walked[1], _current_up) if _walked.size() == 2 else Vector3.ZERO
	if walking != Vector3.ZERO:
		_facing = walking
	else:
		var axes := _key_axes(_current_up)
		if not axes.is_empty():
			_facing = axes[1]
	if mode == Mode.GRAPPLING:
		# Roll onto the surface on the way in, so arrival is not a snap.
		_blend_up(grapple_normal, delta)
	elif mode == Mode.AIRBORNE:
		_blend_up(Vector3.UP, delta)
	var target := _orientation_basis(_current_up)
	var current := _spider.global_basis.orthonormalized()
	var weight := clampf(orientation_speed * delta, 0.0, 1.0)
	_spider.global_basis = Basis(current.get_rotation_quaternion().slerp(
		target.get_rotation_quaternion(), weight))


## One step of spider movement.
func step(delta: float, input_axis: Vector2, want_jump: bool, want_sprint: bool) -> void:
	if _spider == null:
		return
	_grace = maxf(0.0, _grace - delta)
	_landing = maxf(0.0, _landing - delta)
	_swap_cooldown = maxf(0.0, _swap_cooldown - delta)
	if mode == Mode.GRAPPLING:
		_step_grappling(delta)
	else:
		_step_surface(delta, input_axis, want_jump, want_sprint)


## Stands the body the right way up on the spot, rather than rolling it there.
##
## For being *put* somewhere rather than getting there — a respawn, or a test
## setting a scene. [method release] lets go and leaves the body to roll upright
## on its own, which is right in mid-air and wrong here: put down fresh, it spent
## its first half second turning over from however it was hanging before, and
## anything aimed in that half second was aimed from a spider on its back.
func stand_upright() -> void:
	release()
	_current_up = Vector3.UP
	surface_normal = Vector3.UP
	_previous_up = Vector3.ZERO
	_swap_cooldown = 0.0
	var flat := _facing - Vector3.UP * _facing.dot(Vector3.UP)
	_facing = flat.normalized() if flat.length_squared() > 0.000001 else Vector3.FORWARD
	if _spider != null:
		_spider.global_basis = _orientation_basis(Vector3.UP)


## Drops everything and falls. Used when handing back to the template.
func release() -> void:
	if mode != Mode.AIRBORNE:
		_set_mode(Mode.AIRBORNE)
	_landing = 0.0
	_forget_walk()
	if _spider != null:
		_spider.up_direction = Vector3.UP


# --- surfaces -----------------------------------------------------------

func _step_surface(delta: float, input_axis: Vector2, want_jump: bool,
		want_sprint: bool) -> void:
	var height := _body_height()
	var wish := _walk(input_axis)
	var hit := _find_surface(height, wish)

	if hit.is_empty() or _grace > 0.0:
		_forget_walk()
		_set_mode(Mode.AIRBORNE)
		_move_airborne(delta, input_axis)
		return

	# The frame the keys were read in on the way here. In the air that is the
	# level one the air steers by, whatever the body is still rolling through.
	var before := _current_up if mode == Mode.ATTACHED else Vector3.UP
	_adopt_surface(hit["normal"])
	_carry_over(before, input_axis)
	_set_mode(Mode.ATTACHED)

	if want_jump:
		_leap(input_axis)
		return

	# Walking the surface: all the movement happens in its tangent plane, and
	# the only force is the one holding the spider onto it.
	wish = _walk(input_axis)
	# A grapple's landing springs: quicker and harder off the mark for a moment,
	# fading to nothing over landing_time.
	var spring := _landing / landing_time if landing_time > 0.0 else 0.0
	var speed := _surface_speed(want_sprint) * (1.0 + landing_speed * spring)
	var velocity := _spider.velocity
	var tangent := velocity - _current_up * velocity.dot(_current_up)
	var target := wish * speed
	# Above a walk, speed bleeds instead of being clamped away. Steering against
	# it still brakes hard — that is what deceleration is for — but coasting on
	# what a jump or a line gave you is a skid, and a skid is the only place
	# carried momentum can actually live.
	#
	# Only while the keys go along with it, though. Let go and it brakes: a skid
	# that coasted on with nothing held read as the spider sliding out of your
	# hands. And steering across one turns as sharply as steering at a walk: a
	# landing that would not take a turn for half a second read as the keys going
	# the wrong way. A landing's spring is not a skid either: it fades on its own.
	var with_skid := spring <= 0.0 and wish != Vector3.ZERO \
		and wish.dot(tangent.normalized()) > 0.7
	if tangent.length() > speed and with_skid:
		tangent = tangent.lerp(target, clampf(skid_damping * delta, 0.0, 1.0))
	else:
		var rate: float = acceleration if target.dot(tangent) > 0.0 else deceleration
		if wish != Vector3.ZERO:
			rate *= 1.0 + landing_push * spring
		tangent = tangent.lerp(target, clampf(rate * delta, 0.0, 1.0))

	var into := _current_up * stick_force * height
	_spider.velocity = tangent - into
	_spider.up_direction = _current_up
	_spider.move_and_slide()
	tangent_velocity = tangent


func _move_airborne(delta: float, input_axis: Vector2) -> void:
	var wish := _wish_direction(input_axis, Vector3.UP)
	var velocity := _spider.velocity
	velocity.y -= _spider.gravity * delta
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var target := wish * _spider.speed
	var steering: float = _spider.air_control
	horizontal = horizontal.lerp(target, clampf(acceleration * steering * delta, 0.0, 1.0))
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	_spider.velocity = velocity
	_spider.up_direction = Vector3.UP
	_spider.move_and_slide()
	tangent_velocity = Vector3(velocity.x, 0.0, velocity.z)


func _leap(input_axis: Vector2) -> void:
	var wish := _walk(input_axis)
	_forget_walk()
	# Whatever you were already carrying comes with you. Jumping out of a skid is
	# what turns a grapple's landing into the next hop, rather than a full stop
	# followed by a standing jump — and it is the half of chaining that a launch
	# built from scratch quietly threw away.
	var carried := _spider.velocity
	carried -= _current_up * carried.dot(_current_up)
	_spider.velocity = carried + _current_up * _spider.jump_height \
		+ wish * _spider.speed * 0.5
	_grace = release_grace
	_set_mode(Mode.AIRBORNE)
	jumped.emit()


## Picks what to stick to. The surface already underfoot wins ties, so brushing
## past a wall doesn't throw the spider onto it — you have to walk into it.
func _find_surface(height: float, wish: Vector3) -> Dictionary:
	var space := _spider.get_world_3d().direct_space_state
	var origin := _spider.global_position
	var reach := height * stick_reach
	var up := _current_up
	var forward := _facing
	var right := forward.cross(up)
	if right.length_squared() < 0.000001:
		right = up.cross(Vector3.RIGHT)
	right = right.normalized()

	var directions: Array[Vector3] = [
		-up, forward, -forward, right, -right, up,
		-up + forward, -up - forward, -up + right, -up - right,
	]

	var best := {}
	var best_score := INF
	var same := {}
	var same_score := INF
	var other := {}
	var other_score := INF
	var exclude: Array[RID] = [_spider.get_rid()]

	for direction in directions:
		var dir := direction.normalized()
		var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * reach,
			climbable_layers, exclude)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		var normal: Vector3 = hit.get("normal", Vector3.UP)
		if normal.dot(dir) > -0.1:
			continue
		var collider := hit.get("collider") as Node
		if collider != null and collider.is_in_group(no_climb_group):
			continue
		var distance: float = origin.distance_to(hit["position"])
		if distance < best_score:
			best_score = distance
			best = hit
		if normal.dot(up) > 0.85:
			if distance < same_score:
				same_score = distance
				same = hit
		elif distance < other_score:
			other_score = distance
			other = hit

	if best.is_empty():
		return best
	if mode != Mode.ATTACHED or same.is_empty():
		return best

	# Still on the old surface. Only change allegiance if the player is actively
	# pushing into another, and it is near enough to be the next thing underfoot.
	#
	# The nearest other surface, not the nearest surface: in a crevice — round the
	# side of a log lying on the ground, into the floor under it — the surface you
	# are on stays nearer than the floor you are walking into, and asking only the
	# nearest left the spider pressed into the gap for as long as the key was down.
	if other.is_empty() or other_score > height * 0.75:
		return same
	var candidate: Vector3 = other.get("normal", Vector3.UP)
	# Fresh off another surface and the candidate is the one we just left? Stay
	# put for a moment, or an inside corner ping-pongs between wall and ceiling.
	if _swap_cooldown > 0.0 and candidate.dot(_previous_up) > 0.85:
		return same
	# And only onto a surface standing on this side of the one underfoot: an
	# inside corner, which is the only kind there is to push into. The far face
	# of an edge you have just come over is *behind* the face you are on now, and
	# walking away from the edge points into it just as squarely — counted as a
	# push, it pulled the spider back over the edge it was walking off.
	var rise: float = (other.get("position", origin) - same.get("position", origin)).dot(up)
	if rise > height * 0.05 and wish.length_squared() > 0.01 \
			and wish.normalized().dot(-candidate) > 0.2:
		return other
	return same


## Moves the body's idea of up onto a new surface, carrying the facing
## direction with it.
##
## The normal is normalized on the way in rather than trusted. Physics hands
## back normals that are a shade under unit length — 0.9993 turns up readily —
## and this value becomes the body's up, which is then slerped every frame.
## Vector3.slerp needs both ends exactly unit, so one sloppy normal from the
## world is an error every frame until the spider next touches something else.
func _adopt_surface(raw_normal: Vector3, roll := true) -> void:
	if raw_normal.length_squared() < 0.000001:
		return
	var normal := raw_normal.normalized()
	if normal.dot(_current_up) > 0.999:
		surface_normal = normal
		_current_up = normal
		return
	if roll and normal.dot(_current_up) > cos(deg_to_rad(CURVE)):
		# Round a curve, or onto the next facet of something round: the body rolls
		# round it over a few frames rather than snapping. A trunk built of twelve
		# flat sides turned the body thirty degrees at every side, and rocked it
		# between two of them at each seam.
		surface_normal = normal
		var rolled := _current_up.slerp(normal, CURVE_FOLLOW).normalized()
		var facing := _flat(Quaternion(_current_up, rolled) * _facing, rolled)
		if facing != Vector3.ZERO:
			_facing = facing
		_current_up = rolled
		return
	var along := _facing.dot(normal)
	var new_facing: Vector3
	if absf(along) > 0.95:
		# Walked straight into the surface (face up it) or over an edge onto
		# its far side (face down it).
		new_facing = _current_up * (-1.0 if along > 0.0 else 1.0)
	else:
		new_facing = _facing - normal * along
	new_facing = new_facing - normal * new_facing.dot(normal)
	if new_facing.length_squared() < 0.000001:
		new_facing = normal.cross(Vector3.RIGHT)
		if new_facing.length_squared() < 0.000001:
			new_facing = normal.cross(Vector3.FORWARD)
	_facing = new_facing.normalized()
	_previous_up = _current_up
	_swap_cooldown = 0.3
	_current_up = normal
	surface_normal = normal
	surface_changed.emit(normal)


func _surface_speed(want_sprint: bool) -> float:
	var speed := _spider.speed
	if want_sprint:
		speed *= _spider.sprint_speed_multiplier
	var steepness := clampf(1.0 - maxf(0.0, _current_up.dot(Vector3.UP)), 0.0, 1.0)
	speed *= lerpf(1.0, steep_speed_factor, steepness)
	return speed * haul


# --- grappling ----------------------------------------------------------

## How far the feet are below the middle of the body, in body heights.
const FEET := 0.4


## Where the spider's feet are: under the body, along whatever it calls up.
func feet() -> Vector3:
	return _spider.global_position - _current_up * _body_height() * FEET


## Throws the spider off whatever it is on, at [param push]: a hit hard enough to
## knock it loose. It does not stick to anything again for a moment, the way a jump
## does not, or the first wall it brushed would take it straight back.
func fling(push: Vector3) -> void:
	if _spider == null:
		return
	release()
	_grace = release_grace
	_spider.velocity = push


## Hauls the spider to [param point], landing it on the surface facing
## [param normal]. False if a grapple is already under way.
func grapple_to(point: Vector3, normal: Vector3) -> bool:
	if mode == Mode.GRAPPLING or _spider == null:
		return false
	grapple_target = point
	grapple_normal = normal.normalized() if normal.length_squared() > 0.000001 else Vector3.UP
	_grapple_time = 0.0
	_grapple_span = _spider.global_position.distance_to(point)
	_set_mode(Mode.GRAPPLING)
	return true


func _step_grappling(delta: float) -> void:
	var height := _body_height()
	_grapple_time += delta
	var offset := grapple_target - _spider.global_position
	var distance := offset.length()
	var speed := _grapple_speed(height)
	if distance <= maxf(height * 0.5, 0.02) or _grapple_time > _grapple_limit(speed):
		_arrive()
		return

	_spider.velocity = offset / distance * speed
	_spider.up_direction = Vector3.UP
	var before := _spider.global_position
	_spider.move_and_slide()
	tangent_velocity = _spider.velocity
	# Jammed on geometry short of the target: near enough, stop there.
	if _spider.global_position.distance_to(before) < speed * delta * 0.25:
		_arrive()


## Short hops keep the tier's own speed; long ones are flung fast enough to
## arrive in about the same time, so a long way across is not a long wait.
func _grapple_speed(height: float) -> float:
	var speed := grapple_speed * height
	if _grapple_span > 0.0 and grapple_max_travel > 0.0:
		speed = maxf(speed, _grapple_span / grapple_max_travel)
	return speed


## The bail-out, which has to scale with the trip or a long grapple would give
## up in mid-air and drop the spider wherever it happened to be.
func _grapple_limit(speed: float) -> float:
	return maxf(grapple_timeout, _grapple_span / maxf(speed, 0.001) * 2.0 + 0.5)


func _arrive() -> void:
	var point := grapple_target
	var normal := grapple_normal
	# What was running into the surface goes. Of what was running along it,
	# [member grapple_carry] stays — no faster than the landing's own top speed,
	# since a grapple flies far faster than any walk — and the landing's spring
	# takes it on from there, or the brakes do if nothing is held.
	var travel := _spider.velocity
	var along := travel - normal * travel.dot(normal)
	# Taken outright: the body rolled towards it all the way in, and the grapple
	# knows exactly which surface it is.
	_adopt_surface(normal, false)
	_set_mode(Mode.ATTACHED)
	_landing = landing_time
	_spider.velocity = (along * grapple_carry).limit_length(
		_surface_speed(false) * (1.0 + landing_speed))
	tangent_velocity = _spider.velocity
	grappled.emit(point, normal)


# --- helpers ------------------------------------------------------------

## Where the keys want to go on the surface underfoot: the walk as it has been
## carried and steered while a key has been down — see [method _carry_over] — or the
## camera's reading of the keys for the first step.
func _walk(input_axis: Vector2) -> Vector3:
	if input_axis.length_squared() < 0.01:
		# Let go, and the next press is read fresh.
		_forget_walk()
		return Vector3.ZERO
	if _walked.size() == 2:
		var right := _flat(_walked[0], _current_up)
		var ahead := _flat(_walked[1], _current_up)
		if right != Vector3.ZERO and ahead != Vector3.ZERO:
			return (ahead * input_axis.y + right * input_axis.x).normalized()
	return _wish_direction(input_axis, _current_up)


## Drops the walk, so the next press reads the keys afresh off the camera.
func _forget_walk() -> void:
	_walked.clear()
	_carrying = false


## Keeps the walk going the way it was going while the surface underfoot turns, and
## lets the camera steer it while it does.
##
## The keys are read off the camera, and the reading depends on the surface as well
## as on the camera, so as the surface turns the reading can turn with it. Across an
## edge it jumps: climb a wall to the ceiling still facing the wall and W on the
## ceiling means *back towards the wall* — straight back onto the surface you came
## from, so the spider took the wall again, then the ceiling, then the wall, a swap
## every three tenths of a second and the camera thrown half a metre each time. Round
## a curve it drifts: hold D on the side of a trunk with the camera still, and as the
## trunk turns under the spider the reading turns from along it to down it, and the
## spider slid off the bottom instead of going round.
##
## So for as long as a key is down the walk is kept rather than read again. Each step
## it is turned by exactly the turn the surface made — forward on the floor becomes up
## the wall, up the wall becomes on across the ceiling, along a trunk stays along it
## all the way round — and by whatever the camera's turn did to the camera's own
## reading of the keys, so the mouse steers it as it always did. Where the surface has
## brought the two [constant CARRY_APART] degrees apart, the walk stops taking the
## camera's turns and keeps going the way it was going, until the camera's reading
## comes back within [constant CARRY_TOGETHER] of it, the keys are let go, or the
## camera swings [member carry_release_angle] away — each of which is the player
## asking again. A turn near a half circle, like dropping onto a ceiling from below,
## has no one way to carry anything, so it is read fresh.
func _carry_over(before: Vector3, input_axis: Vector2) -> void:
	if input_axis.length_squared() < 0.01 or before.length_squared() < 0.000001 \
			or _view == null:
		_forget_walk()
		return
	var from := before.normalized()
	if rad_to_deg(from.angle_to(_current_up)) > 150.0:
		_forget_walk()
		return
	var fresh := _key_axes(_current_up)
	if fresh.is_empty():
		return
	if _walked.size() != 2:
		# The first step with a key down starts from the camera's reading, on the
		# surface it was read on.
		var start := _key_axes(from)
		if start.is_empty():
			return
		_walked = [start[0], start[1]]
		_carrying = false
		_note_steer()
	var carried := _uphill_carry(from, _current_up)
	if carried.is_empty():
		var bend := Quaternion(from, _current_up)
		carried = [bend * _walked[0], bend * _walked[1]]
	var right := _flat(carried[0], _current_up)
	var ahead := _flat(carried[1], _current_up)
	if right == Vector3.ZERO or ahead == Vector3.ZERO:
		_walked = [fresh[0], fresh[1]]
		_carrying = false
		_note_steer()
		return
	if not _carrying:
		# The camera's turn since the last step, as it turned its own reading of this
		# surface.
		var was := _key_axes_for(_current_up, _walked_yaw, _walked_pitch)
		if not was.is_empty():
			var steer := _turn_about(was[1], fresh[1], _current_up)
			right = right.rotated(_current_up, steer)
			ahead = ahead.rotated(_current_up, steer)
	_note_steer()
	var apart := rad_to_deg(maxf(right.angle_to(fresh[0]), ahead.angle_to(fresh[1])))
	var steady := absf(_current_up.y) >= SETTLE_UP
	if _carrying:
		var swung := _view.forward().angle_to(_carried_look) > deg_to_rad(carry_release_angle)
		if swung or apart < CARRY_TOGETHER:
			_carrying = false
			# Handed back. Where the camera's reading is a steady one, onto it; on a
			# wall, whose reading turns smoothly between facing it and looking along it,
			# the walk keeps its own way and takes the camera's turns from here — or
			# handing back mid-turn would set the walk a few degrees up the wall, and it
			# would climb that way round a trunk for as long as the key stayed down.
			if swung or steady:
				_walked = [fresh[0], fresh[1]]
				return
	elif apart > CARRY_APART:
		_carrying = true
		_carried_look = _view.forward()
	elif steady:
		# On a floor, a ceiling or a gentle slope the walk is the camera's, exactly:
		# whatever a bump or an edge left it a few degrees off is let go of, not
		# walked on with.
		_walked = [fresh[0], fresh[1]]
		return
	_walked = [right, ahead]


## The walk carried from a steep surface facing [param from] onto another facing
## [param to], keeping its angle to the way up each one: level round a trunk stays
## level all the way round, tapered or not. Carried the shortest way round instead,
## it is a straight line on the surface, and a straight line round a narrowing trunk
## spirals — eighteen degrees a lap on an ordinary one, down to the ground in two.
## Empty unless both surfaces are steep enough to have a way up worth keeping to.
func _uphill_carry(from: Vector3, to: Vector3) -> Array:
	if absf(from.y) > STEEP_KEEP or absf(to.y) > STEEP_KEEP:
		return []
	var was := _slope_frame(from)
	var now := _slope_frame(to)
	if was.is_empty() or now.is_empty():
		return []
	var carried := []
	for direction in _walked:
		carried.append(now[0] * direction.dot(was[0]) + now[1] * direction.dot(was[1]))
	return carried


## The way up a slope facing [param up] and the level way across it, as
## [uphill, along]; empty for a floor or a ceiling, which have neither.
static func _slope_frame(up: Vector3) -> Array:
	var along := Vector3.UP.cross(up)
	var uphill := Vector3.UP - up * up.y
	if along.length_squared() < 0.000001 or uphill.length_squared() < 0.000001:
		return []
	return [uphill.normalized(), along.normalized()]


## Remembers where the camera is pointing, for the next step's turn.
func _note_steer() -> void:
	if _view != null:
		_walked_yaw = _view.yaw
		_walked_pitch = _view.pitch


## The angle from [param from] to [param to] around [param axis], signed the way
## [method Vector3.rotated] turns.
static func _turn_about(from: Vector3, to: Vector3, axis: Vector3) -> float:
	return atan2(axis.dot(from.cross(to)), from.dot(to))


## [param direction] laid flat on a surface facing [param up], or zero if it
## stands straight out of it.
func _flat(direction: Vector3, up: Vector3) -> Vector3:
	var flat := direction - up * direction.dot(up)
	if flat.length_squared() < 0.01:
		return Vector3.ZERO
	return flat.normalized()


## Where the keys want to go: the camera's own axes, fitted to whatever is
## underfoot.
##
## This is where a wall or a ceiling is dealt with, and it belongs here rather
## than in the camera. The rig keeps a level horizon and never rolls, which is
## what makes it pleasant to look through — so on a wall, "screen-right" and
## "along the wall" are two different directions and something has to reconcile
## them. Deriving right from `forward.cross(up)`, as this did, reconciled them
## wrongly: on a wall with its face toward you that gave *down the wall* for D,
## and on a ceiling it came out mirrored, so D walked you left while the world
## was still drawn the right way up. Neither was ever written down. They were
## just how it felt, which is the worst way to have a bug in a control scheme.
func _wish_direction(input_axis: Vector2, up: Vector3) -> Vector3:
	if input_axis.length_squared() < 0.01:
		return Vector3.ZERO
	var axes := _key_axes(up)
	if axes.is_empty():
		return Vector3.ZERO
	return (axes[1] * input_axis.y + axes[0] * input_axis.x).normalized()


## The two directions the keys move you in on a surface facing [param up], as
## [right, ahead], or empty if there is nothing to read them by.
##
## A floor and a ceiling read the keys off where the camera looks: W goes away
## from you, D goes the way the camera calls right — see [method _surface_axes].
## Anything steeper is climbed rather than walked, and reads them off how you face
## it instead — see [method _climbing_axes].
func _key_axes(up: Vector3) -> Array:
	if _view == null:
		var lead := _surface_forward(up)
		if lead.length_squared() < 0.000001:
			return []
		return _surface_axes(up, lead.normalized())
	return _key_axes_for(up, _view.yaw, _view.pitch)


## [method _key_axes] for a camera turned to [param yaw] and tipped to [param pitch]
## — the reading a camera pointed somewhere else would give, which is how the walk
## tells the camera's own turns from the surface's. See [method _carry_over].
func _key_axes_for(up: Vector3, yaw: float, pitch: float) -> Array:
	if up.y < FLOOR_UP and up.y > CEILING_UP:
		var climbing := _climbing_axes_for(up, yaw)
		if not climbing.is_empty():
			return climbing
	var look := Basis.from_euler(Vector3(pitch, yaw, 0.0))
	var lead := _surface_forward_for(up, -look.z, look.y)
	if lead.length_squared() < 0.000001:
		return []
	return _surface_axes_for(up, lead.normalized(), look.x)


## The keys on a wall, a slope or an overhang, as [right, ahead]: read off which
## way the camera faces the surface across the ground, and never off how far the
## camera is tipped up or down.
##
## Reading them off the look flattened onto the surface, as floors do, was wrong
## here twice over. On a wall in front of you the look flattened is all tip: W
## climbed with the camera level or raised and went *down* the moment it dipped
## past eight degrees — and a third-person camera looks a little down at the spider
## most of the time. And on a wall beside you a few degrees of turn swapped the
## keys outright: W from along the wall to up it, D from up it to along it, or to
## back towards the camera.
##
## So a wall has three readings, and the turn between them is smooth. Facing it, W
## climbs and D goes along it the way the camera calls right. Looking along it, W
## goes along it the way you are looking and the key towards the wall climbs it —
## D on a wall to your right, A on one to your left. Looking away from it, W comes
## back down. A gentle slope is not snapped at all: the same frame turned through
## exactly the angle you face it at is "go where you look", which is what a floor
## does, and steepness eases from one to the other.
func _climbing_axes(up: Vector3) -> Array:
	if _view == null:
		return []
	return _climbing_axes_for(up, _view.yaw)


## [method _climbing_axes] for a camera turned to [param yaw].
func _climbing_axes_for(up: Vector3, yaw: float) -> Array:
	var along := Vector3.UP.cross(up)
	var uphill := Vector3.UP - up * Vector3.UP.dot(up)
	var into := Vector3(-up.x, 0.0, -up.z)
	if along.length_squared() < 0.000001 or uphill.length_squared() < 0.000001 \
			or into.length_squared() < 0.000001:
		return []
	along = along.normalized()
	uphill = uphill.normalized()
	into = into.normalized()
	# Which way the camera faces across the ground: its yaw, whatever its pitch.
	var facing := Vector3(-sin(yaw), 0.0, -cos(yaw))
	# 0 facing the surface, a quarter turn with it on your right, a half turn with
	# your back to it; negative with it on your left.
	var turned := atan2(-facing.dot(along), facing.dot(into))
	var steep := smoothstep(0.5, 0.85, 1.0 - absf(up.y))
	var turn := lerpf(turned, _wall_turn(turned), steep)
	var ahead := uphill * cos(turn) - along * sin(turn)
	var right := uphill * sin(turn) + along * cos(turn)
	return [right.normalized(), ahead.normalized()]


## [param turned] eased onto the three readings a wall has — facing it, along it,
## and away from it — and turned smoothly between them rather than at a seam.
static func _wall_turn(turned: float) -> float:
	var off := absf(rad_to_deg(turned))
	var snapped := 0.0
	if off >= 140.0:
		snapped = 180.0
	elif off > 100.0:
		snapped = 90.0 + 90.0 * smoothstep(100.0, 140.0, off)
	elif off >= 80.0:
		snapped = 90.0
	elif off > 40.0:
		snapped = 90.0 * smoothstep(40.0, 80.0, off)
	return deg_to_rad(snapped) * signf(turned)


## The two directions the keys move you in on a floor or a ceiling, as
## [right, ahead]. Anything steeper is [method _climbing_axes]'s.
##
## Right comes first, because a mirrored strafe is the thing you feel: it is the
## camera's own right, flattened onto the surface. Ahead is then squared off
## against it inside the surface, pointed whichever way the camera is looking.
## Upside down that keeps D screen-right, where `lead.cross(up)` mirrored it.
##
## It is also what walls used, and why they could not: the camera's right is
## always horizontal and its look is mostly tilt, so on a wall the sign of ahead
## came down to how far the camera was tipped, and a few degrees of turn beside one
## swapped the keys. Walls are [method _climbing_axes]'s now; this is the fallback
## for one when there is no camera to read them by.
func _surface_axes(up: Vector3, lead: Vector3) -> Array:
	return _surface_axes_for(up, lead, _view.right() if _view != null else lead.cross(up))


## [method _surface_axes] for a camera whose right is [param across].
func _surface_axes_for(up: Vector3, lead: Vector3, across: Vector3) -> Array:
	var right := across - up * across.dot(up)
	if right.length_squared() < 0.02:
		# Looking along a wall's face edge-on: the camera's right points into the
		# wall, and there is honestly no right on that surface to go to. Fall back
		# to the old pair, which is always square and always somewhere. The view
		# is a sliver of wall at that angle and the player is about to turn it.
		return [lead.cross(up).normalized(), lead]
	right = right.normalized()
	var ahead := up.cross(right)
	if ahead.length_squared() < 0.000001:
		return [right, lead]
	ahead = ahead.normalized()
	var agreement := ahead.dot(lead)
	if absf(agreement) < 0.05:
		if ahead.dot(Vector3.UP) < 0.0:
			ahead = -ahead
	elif agreement < 0.0:
		ahead = -ahead
	return [right, ahead]


func _orientation_basis(raw_up: Vector3) -> Basis:
	var up := raw_up.normalized() if raw_up.length_squared() > 0.000001 else Vector3.UP
	var back := -_facing
	var right := up.cross(back)
	if right.length_squared() < 0.000001:
		right = up.cross(Vector3.FORWARD)
		if right.length_squared() < 0.000001:
			right = up.cross(Vector3.RIGHT)
	right = right.normalized()
	back = right.cross(up).normalized()
	return Basis(right, up, back)


func _blend_up(target: Vector3, delta: float) -> void:
	if target.length_squared() < 0.000001 or _current_up.length_squared() < 0.000001:
		return
	# Both ends, every time. slerp builds a rotation about the cross product of
	# its operands and refuses an axis that is not unit length, so a hair off
	# on either side is a hard error rather than a slightly wrong angle.
	var from := _current_up.normalized()
	var to := target.normalized()
	var blended := from.slerp(to, clampf(orientation_speed * delta, 0.0, 1.0))
	if blended.length_squared() > 0.000001:
		_current_up = blended.normalized()


func _set_mode(new_mode: Mode) -> void:
	if mode == new_mode:
		return
	var leaving_surface := mode == Mode.ATTACHED
	mode = new_mode
	if leaving_surface:
		# Drop the pull that was holding us on, or we launch into the floor.
		var into := _spider.velocity.dot(-_current_up)
		if into > 0.0:
			_spider.velocity += _current_up * into
	mode_changed.emit(new_mode)


func _body_height() -> float:
	return maxf(body_height, 0.01)


func _in_water() -> bool:
	var swim := _spider.swim_ability
	if swim == null:
		return false
	var ray := swim.get_node_or_null("RayCast3D") as RayCast3D
	return ray != null and ray.is_colliding()
