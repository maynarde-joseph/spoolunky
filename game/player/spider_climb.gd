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
## It also owns the dragline: drop off a ceiling on a thread, pay it out, reel
## it back in, or let go.

enum Mode {
	## In the air, normal gravity, looking for something to grab.
	AIRBORNE,
	## Stuck to a surface, whatever angle it is.
	ATTACHED,
	## Swinging from a line of silk.
	HANGING,
	## Clipped onto a strand and sliding along it.
	RIDING,
	## Hauling itself to a point it is about to anchor silk to.
	GRAPPLING,
}

signal mode_changed(mode: Mode)
signal surface_changed(normal: Vector3)
signal jumped()
signal grappled(point: Vector3, normal: Vector3)
signal line_dropped(anchor: Vector3)
signal line_cut()
signal notice(text: String)


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
@export var deceleration := 18.0

## Seconds after jumping before the spider may stick to anything again,
## so a jump off a wall actually leaves the wall.
@export var release_grace := 0.22

## Surfaces to climb: the world, and silk. Standing on your own web is the
## whole point of having one.
@export_flags_3d_physics var climbable_layers := GameLayers.WORLD | GameLayers.WEB_WALK

## Colliders in this group cannot be climbed — glass, grease, a hot pipe.
@export var no_climb_group := "no_climb"


@export_group("Dragline")

## Longest line the spider can pay out, in body heights.
@export var max_line_bodies := 40.0

## Pay-out and reel-in speed, in body heights per second.
@export var line_speed_bodies := 8.0

## Silk per metre of line, before the size tier's silk quality.
@export var line_silk_per_metre := 0.8

## Fraction of the silk cost recovered by reeling the line back in.
@export_range(0.0, 1.0, 0.05) var line_reel_refund := 0.5

## Sideways push while hanging, for swinging yourself somewhere useful.
@export var swing_force := 4.0

## Air drag on a swinging spider, so a pendulum eventually settles.
@export var swing_damping := 0.6

@export var line_color := Color(0.95, 0.96, 1, 0.92)


@export_group("Ziplining")

## How far the spider will reach to grab a line, in body heights.
@export var grab_reach := 9.0

## Push along the line from the movement keys, in body heights per second.
@export var ride_push := 9.0

## Fastest a ride can get, in body heights per second. Gravity does the rest.
@export var ride_top_speed := 26.0

## Drag on a moving rider, so a level line eventually coasts to a stop.
@export var ride_drag := 0.35

## Upward kick when letting go, so launching off a line clears the edge.
@export var launch_lift := 2.5

## How fast the spider hauls itself to an anchor point, in body heights per
## second. Building a web is walking the frame, so this wants to be brisk.
@export var grapple_speed := 26.0

## Give up on a grapple after this long, so a blocked one cannot hang.
@export var grapple_timeout := 2.5

## Longest a grapple should take, however far it goes. Without this, reaching
## across a courtyard at a spiderling's 6 m/s is a nine-second commute — which
## is the tedium unlimited range was supposed to remove, not add.
@export var grapple_max_travel := 1.1

## How much quicker silk is underfoot than anything else. A line you spun is a
## road, and a road you built should beat walking round.
@export var silk_speed_bonus := 1.5

## How much further the spider's feet reach for silk it is already on, in
## multiples of the ordinary reach. A spider does not fall off its own thread:
## once you are on silk it holds you, and you leave it by jumping.
@export var silk_stick_reach := 2.5

## How firmly a single thread pulls the body back over it, in metres per second
## per metre of drift. A web is a floor and wants none of this; one strand is a
## tightrope, and a spider that has to balance on a tightrope is a spider
## falling off it. Only the drift across the line is corrected — moving along
## it is left entirely alone.
@export var thread_grip := 5.0


var mode: Mode = Mode.AIRBORNE
var surface_normal := Vector3.UP
var line_anchor := Vector3.ZERO
var line_length := 0.0

## The strand being ridden, how far along it, and how fast.
var ride_web: WebStrand = null
var ride_distance := 0.0
var ride_speed := 0.0

## Where a grapple is heading, and the surface waiting at the other end.
var grapple_target := Vector3.ZERO
var grapple_normal := Vector3.UP

## Speed along the surface, for head bob and footsteps.
var tangent_velocity := Vector3.ZERO

## Standing on silk rather than on the world, which is quicker underfoot.
var on_silk := false

## What speed is multiplied by while dragging something. Written by the tether;
## one means empty-handed.
var haul := 1.0

## How much of a fall wings cancel, 0 for none. Written by the spider from its
## traits. There is no glide key: a spider with wings glides, the same way a
## spider with legs walks, which is one fewer thing to hold down.
var glide := 0.0

var _spider: CharacterController3D
var _silk: SilkPool
var _growth: SpiderGrowth
var _view: SpiderCamera
var _facing := Vector3.FORWARD
var _current_up := Vector3.UP
var _grace := 0.0
var _previous_up := Vector3.ZERO
var _swap_cooldown := 0.0
var _grapple_time := 0.0

## How far this grapple has to go, measured when it started.
var _grapple_span := 0.0
var _silk_warning := 0.0
var _line_mesh: ImmediateMesh
var _line_instance: MeshInstance3D
var _line_material: StandardMaterial3D


func setup(spider: CharacterController3D, silk: SilkPool, growth: SpiderGrowth,
		view: SpiderCamera) -> void:
	_spider = spider
	_silk = silk
	_growth = growth
	_view = view
	_facing = -spider.global_basis.z
	_current_up = Vector3.UP
	surface_normal = Vector3.UP
	_build_line_visual()


## True while this component is driving the body. Water and free-fly are left
## to the character-controller template.
func handles_movement() -> bool:
	return _spider != null and not _spider.is_fly_mode() and not _in_water()


func is_attached() -> bool:
	return mode == Mode.ATTACHED


func is_hanging() -> bool:
	return mode == Mode.HANGING


func is_riding() -> bool:
	return mode == Mode.RIDING


func is_grappling() -> bool:
	return mode == Mode.GRAPPLING


## Ground speed along the line, for the HUD and the speed rush on the camera.
func ride_velocity() -> float:
	return absf(ride_speed)


## True when the spider is on something it could not stand on upright.
func on_steep_surface() -> bool:
	return mode == Mode.ATTACHED and surface_normal.dot(Vector3.UP) < 0.7


## Direction the body treats as up right now.
func body_up() -> Vector3:
	return _current_up


## Points the view, and so the body, along a direction.
func face(direction: Vector3) -> void:
	if _view != null:
		_view.face(direction)
	var flat := direction - _current_up * direction.dot(_current_up)
	if flat.length_squared() > 0.000001:
		_facing = flat.normalized()


## Which way "forward" is on the surface underfoot: the way the camera is
## looking, flattened onto it.
##
## Looking straight into a wall leaves nothing to flatten, so it falls back to
## the camera's own up — which means walking at a wall climbs it rather than
## jamming, and looking out from a wall walks you back down it.
func _surface_forward(up: Vector3) -> Vector3:
	if _view == null:
		return _facing
	var look := _view.forward()
	var flat := look - up * look.dot(up)
	if flat.length_squared() < 0.02:
		var sideways: float = -signf(look.dot(up))
		if sideways == 0.0:
			sideways = 1.0
		var fallback := _view.up() * sideways
		flat = fallback - up * fallback.dot(up)
	if flat.length_squared() < 0.000001:
		return _facing
	return flat.normalized()


## Rolls the body toward the surface it is on. Runs every frame, including the
## frames where the template is driving movement, so mouse look never stalls.
func update_orientation(delta: float) -> void:
	if _spider == null:
		return
	# The body turns to follow the camera; the camera never follows the body.
	_facing = _surface_forward(_current_up)
	if mode == Mode.GRAPPLING:
		# Roll onto the surface on the way in, so arrival is not a snap.
		_blend_up(grapple_normal, delta)
	elif mode == Mode.AIRBORNE or mode == Mode.RIDING:
		_blend_up(Vector3.UP, delta)
	elif mode == Mode.HANGING:
		var to_anchor := line_anchor - _spider.global_position
		_blend_up(to_anchor.normalized() if to_anchor.length() > 0.001 else Vector3.UP, delta)
	var target := _orientation_basis(_current_up)
	var current := _spider.global_basis.orthonormalized()
	var weight := clampf(orientation_speed * delta, 0.0, 1.0)
	_spider.global_basis = Basis(current.get_rotation_quaternion().slerp(
		target.get_rotation_quaternion(), weight))
	_draw_line()


## One step of spider movement.
func step(delta: float, input_axis: Vector2, want_jump: bool, want_sprint: bool,
		want_line_out: bool, want_line_in: bool, want_release: bool) -> void:
	if _spider == null:
		return
	_grace = maxf(0.0, _grace - delta)
	_swap_cooldown = maxf(0.0, _swap_cooldown - delta)
	_silk_warning = maxf(0.0, _silk_warning - delta)
	if mode == Mode.GRAPPLING:
		_step_grappling(delta)
	elif mode == Mode.RIDING:
		_step_riding(delta, input_axis, want_jump, want_release)
	elif mode == Mode.HANGING:
		_step_hanging(delta, input_axis, want_line_out, want_line_in, want_release)
	else:
		_step_surface(delta, input_axis, want_jump, want_sprint, want_line_out)


## Drops everything and falls. Used when handing back to the template.
func release() -> void:
	if mode != Mode.AIRBORNE:
		_set_mode(Mode.AIRBORNE)
	ride_web = null
	ride_speed = 0.0
	line_length = 0.0
	if _spider != null:
		_spider.up_direction = Vector3.UP
	_draw_line()


# --- surfaces -----------------------------------------------------------

func _step_surface(delta: float, input_axis: Vector2, want_jump: bool,
		want_sprint: bool, want_line_out: bool) -> void:
	var height := _body_height()
	var wish := _wish_direction(input_axis, _current_up)
	var hit := _find_surface(height, wish)

	if hit.is_empty() or _grace > 0.0:
		on_silk = false
		_set_mode(Mode.AIRBORNE)
		_move_airborne(delta, input_axis)
		return

	_adopt_surface(hit["normal"])
	_note_surface(hit.get("collider"))
	_set_mode(Mode.ATTACHED)

	if want_line_out:
		if _can_hang_from(hit):
			_drop_line(hit)
		else:
			_warn("Nothing overhead to hang from")
		return
	if want_jump:
		_leap(input_axis)
		return

	# Walking the surface: all the movement happens in its tangent plane, and
	# the only force is the one holding the spider onto it.
	wish = _wish_direction(input_axis, _current_up)
	var thread := _strand_under(hit.get("collider")) if on_silk else null
	if thread != null:
		wish = _along_thread(thread, wish)
	var speed := _surface_speed(want_sprint)
	var velocity := _spider.velocity
	var tangent := velocity - _current_up * velocity.dot(_current_up)
	var target := wish * speed
	var rate: float = acceleration if target.dot(tangent) > 0.0 else deceleration
	tangent = tangent.lerp(target, clampf(rate * delta, 0.0, 1.0))
	tangent = _hold_to_thread(thread, tangent)

	_spider.velocity = tangent - _current_up * stick_force * height
	_spider.up_direction = _current_up
	_spider.move_and_slide()
	tangent_velocity = tangent


func _move_airborne(delta: float, input_axis: Vector2) -> void:
	var wish := _wish_direction(input_axis, Vector3.UP)
	var velocity := _spider.velocity
	var spread := clampf(glide, 0.0, 0.9)
	# Wings only work against a fall. On the way up they are neither help nor
	# hindrance, so a jump is the same height with them as without — the trait
	# changes how you come down, which is the part worth having.
	var lift: float = spread if velocity.y < 0.0 else 0.0
	velocity.y -= _spider.gravity * (1.0 - lift) * delta
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var target := wish * _spider.speed * (1.0 + spread)
	var steering: float = _spider.air_control * (1.0 + spread * 3.0)
	horizontal = horizontal.lerp(target, clampf(acceleration * steering * delta, 0.0, 1.0))
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	_spider.velocity = velocity
	_spider.up_direction = Vector3.UP
	_spider.move_and_slide()
	tangent_velocity = Vector3(velocity.x, 0.0, velocity.z)


func _leap(input_axis: Vector2) -> void:
	var wish := _wish_direction(input_axis, _current_up)
	_spider.velocity = _current_up * _spider.jump_height + wish * _spider.speed * 0.5
	_grace = release_grace
	_set_mode(Mode.AIRBORNE)
	jumped.emit()


## Picks what to stick to. The surface already underfoot wins ties, so brushing
## past a wall doesn't throw the spider onto it — you have to walk into it.
func _find_surface(height: float, wish: Vector3) -> Dictionary:
	var space := _spider.get_world_3d().direct_space_state
	var origin := _spider.global_position
	# Silk already underfoot is worth looking harder for. A thread is a couple
	# of centimetres across, so an ordinary reach loses it the moment the body
	# drifts, and losing it means falling off something you were stuck to.
	var reach := height * stick_reach * (silk_stick_reach if on_silk else 1.0)
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
		if normal.dot(up) > 0.85 and distance < same_score:
			same_score = distance
			same = hit

	if best.is_empty():
		return best
	if mode != Mode.ATTACHED or same.is_empty():
		return best

	# Fresh off another surface and the candidate is the one we just left? Stay
	# put for a moment, or an inside corner ping-pongs between wall and ceiling.
	var candidate_normal: Vector3 = best.get("normal", Vector3.UP)
	if _swap_cooldown > 0.0 and candidate_normal.dot(_previous_up) > 0.85:
		return same

	# Still on the old surface. Only change allegiance if the player is
	# actively pushing into the new one.
	var candidate: Vector3 = best.get("normal", Vector3.UP)
	if candidate.dot(up) > 0.85:
		return same
	if wish.length_squared() > 0.01 and wish.normalized().dot(-candidate) > 0.2:
		return best
	return same


## Moves the body's idea of up onto a new surface, carrying the facing
## direction with it.
##
## The normal is normalized on the way in rather than trusted. Physics hands
## back normals that are a shade under unit length — 0.9993 turns up readily —
## and this value becomes the body's up, which is then slerped every frame.
## Vector3.slerp needs both ends exactly unit, so one sloppy normal from the
## world is an error every frame until the spider next touches something else.
func _adopt_surface(raw_normal: Vector3) -> void:
	if raw_normal.length_squared() < 0.000001:
		return
	var normal := raw_normal.normalized()
	if normal.dot(_current_up) > 0.999:
		surface_normal = normal
		_current_up = normal
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


## The single line a walkway belongs to, if it is one. A web's walk surface
## belongs to a net, which is a floor rather than a rope, so that stays null.
func _strand_under(collider: Variant) -> WebStrand:
	var node := collider as Node
	while node != null:
		var strand := node as WebStrand
		if strand != null:
			return strand
		node = node.get_parent()
	return null


## A thread runs one way, so that is the way you can walk on it.
##
## Pushing across a line does nothing rather than walking you off the side of
## it, which is what makes a thread somewhere a spider can live instead of
## something it keeps falling off. You still set your own pace along it, under
## your own power, facing either way — none of which riding lets you do.
## Leaving is the jump.
##
## A web gets none of this. A web is a floor, and a floor you can only cross
## in one direction is not a floor.
func _along_thread(strand: WebStrand, wish: Vector3) -> Vector3:
	var axis := _thread_axis(strand)
	if axis == Vector3.ZERO or wish.length_squared() < 0.000001:
		return Vector3.ZERO
	return axis * wish.dot(axis)


## Keeps the body over the thread it is walking on. Only the drift across the
## line is pulled back; moving along it is untouched, and so is the force
## holding the spider on. With input already confined to the line this is
## mopping up the last few centimetres, not steering.
func _hold_to_thread(strand: WebStrand, tangent: Vector3) -> Vector3:
	var axis := _thread_axis(strand)
	if axis == Vector3.ZERO:
		return tangent
	var nearest := Geometry3D.get_closest_point_to_segment(_spider.global_position,
		strand.point_a, strand.point_b)
	var offset := nearest - _spider.global_position
	offset -= axis * offset.dot(axis)
	offset -= _current_up * offset.dot(_current_up)
	return tangent + offset * thread_grip


## Which way a thread runs, or zero if it is not one.
func _thread_axis(strand: WebStrand) -> Vector3:
	if strand == null or not is_instance_valid(strand):
		return Vector3.ZERO
	var axis := strand.point_b - strand.point_a
	if axis.length_squared() < 0.000001:
		return Vector3.ZERO
	return axis.normalized()


## Whether what is underfoot is silk rather than world. Read off the collider
## the surface probe found, so it costs nothing to know.
func _note_surface(collider: Variant) -> void:
	var body := collider as CollisionObject3D
	on_silk = body != null and (body.collision_layer & GameLayers.WEB_WALK) != 0


func _surface_speed(want_sprint: bool) -> float:
	var speed := _spider.speed
	if want_sprint:
		speed *= _spider.sprint_speed_multiplier
	var steepness := clampf(1.0 - maxf(0.0, _current_up.dot(Vector3.UP)), 0.0, 1.0)
	speed *= lerpf(1.0, steep_speed_factor, steepness)
	if on_silk:
		speed *= silk_speed_bonus
	return speed * haul


# --- dragline -----------------------------------------------------------

## True if the surface is steep or overhead — you cannot dangle from the floor
## you are standing on.
func _can_hang_from(surface_hit: Dictionary) -> bool:
	var normal: Vector3 = surface_hit.get("normal", Vector3.UP)
	return normal.dot(Vector3.UP) < 0.7


func _drop_line(surface_hit: Dictionary) -> void:
	var height := _body_height()
	var start_length := height * 0.9
	var cost := start_length * line_silk_per_metre * _growth.current_stage().silk_quality
	if not _silk.spend(cost):
		_warn("Not enough silk for a line")
		return
	line_anchor = surface_hit.get("position", _spider.global_position + _current_up * height * 0.5)
	line_length = start_length
	_spider.velocity = Vector3.ZERO
	_set_mode(Mode.HANGING)
	line_dropped.emit(line_anchor)


func _cut_line() -> void:
	if mode != Mode.HANGING:
		return
	_grace = release_grace
	_set_mode(Mode.AIRBORNE)
	line_cut.emit()


func _step_hanging(delta: float, input_axis: Vector2, want_out: bool, want_in: bool,
		want_release: bool) -> void:
	if want_release:
		_cut_line()
		return

	var height := _body_height()
	var quality := _growth.current_stage().silk_quality
	var travel := height * line_speed_bodies * delta

	if want_out:
		var room: float = height * max_line_bodies - line_length
		var amount := minf(travel, maxf(room, 0.0))
		var cost := amount * line_silk_per_metre * quality
		if amount <= 0.0:
			_warn("The line is fully paid out")
		elif _silk.spend(cost):
			line_length += amount
		else:
			_warn("Out of silk for the line")
	elif want_in:
		var amount := minf(travel, line_length - height * 0.9)
		if amount > 0.0:
			line_length -= amount
			_silk.refill(amount * line_silk_per_metre * quality * line_reel_refund)
		else:
			# Back at the top — grab whatever the line is anchored to.
			var wish_up := _wish_direction(input_axis, Vector3.UP)
			var hit := _find_surface(height, wish_up)
			if not hit.is_empty():
				_adopt_surface(hit["normal"])
				_set_mode(Mode.ATTACHED)
				return

	var velocity := _spider.velocity
	velocity.y -= _spider.gravity * delta

	# Swing: push sideways relative to where you are looking.
	var wish := _wish_direction(input_axis, Vector3.UP)
	velocity += wish * swing_force * height * delta * 10.0
	velocity = velocity.lerp(Vector3.ZERO, clampf(swing_damping * delta, 0.0, 1.0))

	# Rope constraint: nothing beyond the length of silk paid out.
	var to_anchor := line_anchor - _spider.global_position
	var distance := to_anchor.length()
	if distance > line_length and distance > 0.001:
		var rope := to_anchor / distance
		var outward := velocity.dot(-rope)
		if outward > 0.0:
			velocity += rope * outward
		velocity += rope * (distance - line_length) / maxf(delta, 0.0001) * 0.5

	_spider.velocity = velocity
	_spider.up_direction = Vector3.UP
	_spider.move_and_slide()
	tangent_velocity = Vector3.ZERO

	# Swung into something climbable while pushing towards it? Grab it.
	if wish.length_squared() > 0.01:
		var reach_hit := _find_surface(height, wish)
		if not reach_hit.is_empty():
			var normal: Vector3 = reach_hit.get("normal", Vector3.UP)
			if wish.normalized().dot(-normal) > 0.2:
				_adopt_surface(normal)
				_set_mode(Mode.ATTACHED)
				line_cut.emit()


func _warn(text: String) -> void:
	if _silk_warning > 0.0:
		return
	_silk_warning = 2.0
	notice.emit(text)


# --- grappling ----------------------------------------------------------

## Hauls the spider to a point it is going to anchor silk to. Building a web is
## a journey around its frame rather than a thing done at arm's length, so every
## anchor is somewhere the spider actually went.
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
## arrive in about the same time, so distance costs you silk rather than
## patience.
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
	_spider.velocity = Vector3.ZERO
	_adopt_surface(normal)
	_set_mode(Mode.ATTACHED)
	grappled.emit(point, normal)


# --- ziplines -----------------------------------------------------------

## Clips onto the nearest ridable strand, or lets go of the one being ridden.
## Returns true if anything happened.
##
## This is the only way into a ride, and it is a key press. Nothing puts the
## spider on one for landing near silk, or for grappling somewhere a line
## happened to be: silk holds you where you are, and riding it is a decision.
func toggle_ride() -> bool:
	if mode == Mode.RIDING:
		_launch_off_line()
		return true
	var strand := _find_ridable()
	if strand == null:
		notice.emit("No line in reach to ride")
		return false
	_grab_line(strand)
	return true


## The best strand to clip onto: near enough to reach, and roughly the way the
## player is looking so grabbing is aimed rather than accidental.
func _find_ridable() -> WebStrand:
	var height := _body_height()
	var reach := height * grab_reach
	var origin := _spider.global_position
	var look := _view.aim_forward() if _view != null else _facing

	var best: WebStrand = null
	var best_score := -INF
	for node in _spider.get_tree().get_nodes_in_group("silk_webs"):
		var strand := node as WebStrand
		# Any silk you can reach is silk you can ride.
		if strand == null or strand.pattern == null:
			continue
		var point := Geometry3D.get_closest_point_to_segment(origin,
			strand.point_a, strand.point_b)
		var distance := origin.distance_to(point)
		if distance > reach:
			continue
		var towards := point - origin
		var aim := 1.0 if towards.length() < 0.001 else towards.normalized().dot(look)
		var score := aim - distance / reach
		if score > best_score:
			best_score = score
			best = strand
	return best


func _grab_line(strand: WebStrand) -> void:
	ride_web = strand
	var point := Geometry3D.get_closest_point_to_segment(_spider.global_position,
		strand.point_a, strand.point_b)
	ride_distance = strand.point_a.distance_to(point)

	# Carry whatever speed you arrived with into the ride, so dropping onto a
	# line from a height throws you along it instead of stopping you dead.
	var axis := _ride_axis()
	ride_speed = _spider.velocity.dot(axis)
	_spider.velocity = Vector3.ZERO
	_set_mode(Mode.RIDING)
	notice.emit("On the line")


func _step_riding(delta: float, input_axis: Vector2, want_jump: bool, want_release: bool) -> void:
	if not is_instance_valid(ride_web):
		_launch_off_line()
		return
	if want_jump or want_release:
		_launch_off_line()
		return

	var height := _body_height()
	var axis := _ride_axis()
	var length := ride_web.point_a.distance_to(ride_web.point_b)

	# Gravity pulls you down the slope; the keys push you along it.
	ride_speed += -_spider.gravity * axis.y * delta
	if absf(input_axis.y) > 0.1:
		var facing_along: float = signf(_facing.dot(axis))
		if facing_along == 0.0:
			facing_along = 1.0
		ride_speed += input_axis.y * facing_along * ride_push * height * delta
	ride_speed -= ride_speed * ride_drag * delta
	ride_speed = clampf(ride_speed, -ride_top_speed * height, ride_top_speed * height)

	ride_distance += ride_speed * delta
	if ride_distance <= 0.0 or ride_distance >= length:
		ride_distance = clampf(ride_distance, 0.0, length)
		_launch_off_line()
		return

	# Hang under the line like something on a pulley.
	var point := ride_web.point_a + axis * ride_distance
	_spider.global_position = point - Vector3.UP * height * 0.45
	_spider.velocity = axis * ride_speed
	tangent_velocity = _spider.velocity


func _launch_off_line() -> void:
	var axis := _ride_axis()
	var thrown := axis * ride_speed
	ride_web = null
	ride_speed = 0.0
	ride_distance = 0.0
	_grace = release_grace
	_set_mode(Mode.AIRBORNE)
	_spider.velocity = thrown + Vector3.UP * launch_lift * _body_height()


func _ride_axis() -> Vector3:
	if not is_instance_valid(ride_web):
		return Vector3.FORWARD
	var axis := ride_web.point_b - ride_web.point_a
	if axis.length_squared() < 0.000001:
		return Vector3.FORWARD
	return axis.normalized()


# --- helpers ------------------------------------------------------------

func _wish_direction(input_axis: Vector2, up: Vector3) -> Vector3:
	if input_axis.length_squared() < 0.01:
		return Vector3.ZERO
	var forward := _surface_forward(up)
	if forward.length_squared() < 0.000001:
		return Vector3.ZERO
	forward = forward.normalized()
	# right = forward x up is the +X of the basis the body is rolled onto, and
	# the template's own mover adds it for a positive x input. Subtracting it
	# here mirrored every strafe the moment the climb component took over,
	# which is nearly always — see the strafe checks in the climb suite.
	var right := forward.cross(up).normalized()
	return (forward * input_axis.y + right * input_axis.x).normalized()


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
	if new_mode != Mode.HANGING:
		line_length = 0.0
	if new_mode != Mode.RIDING:
		ride_web = null
	mode_changed.emit(new_mode)


func _body_height() -> float:
	if _growth == null:
		return 0.25
	return _growth.current_stage().body_height


func _in_water() -> bool:
	var swim := _spider.swim_ability
	if swim == null:
		return false
	var ray := swim.get_node_or_null("RayCast3D") as RayCast3D
	return ray != null and ray.is_colliding()


func _build_line_visual() -> void:
	_line_material = StandardMaterial3D.new()
	_line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line_material.vertex_color_use_as_albedo = true
	_line_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_line_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_line_mesh = ImmediateMesh.new()
	_line_instance = MeshInstance3D.new()
	_line_instance.name = "Dragline"
	_line_instance.mesh = _line_mesh
	_line_instance.material_override = _line_material
	_line_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_line_instance.top_level = true
	add_child(_line_instance)
	_line_instance.transform = Transform3D.IDENTITY


func _draw_line() -> void:
	if _line_mesh == null:
		return
	_line_mesh.clear_surfaces()
	if mode != Mode.HANGING:
		return
	var height := _body_height()
	var attach := _spider.global_position + _current_up * height * 0.45
	WebGeometry.draw_line_into(_line_mesh, _line_material, line_anchor, attach,
		maxf(height * 0.05, 0.004), line_color)
