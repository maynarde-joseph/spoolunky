class_name SilkCaster
extends Node3D

## Right mouse: silk.
##
## Cast exactly as it was: press and a ball of silk winds up over the spider's
## back, growing and brightening; the view lifts and widens over the spider's
## shoulder while it does; let go and it is thrown down the cross. A tap throws
## the smallest, a full second's wind-up the biggest.
##
## What is thrown is new: a whole web, flying — see [ThrownWeb]. The size the
## wind-up reached is the size of the web, so a bigger web is a bigger platform
## and a wider net for a fly.
##
## Holding it does not stop anything else. The grapple and the Pullback both go
## while the ball is held, and the ball is still there, winding, when they have.

## How long winding up to the biggest web takes, in seconds.
const CHARGE_TIME := 0.9

## A web's radius at a tap, and at a full wind-up, in metres.
const SMALLEST := 1.0
const BIGGEST := 2.4

## How fast a thrown web flies, and how far before it comes apart.
const SPEED := 22.0
const REACH := 36.0

## The least time between throws.
const COOLDOWN := 0.2

## The held ball's radius, in body heights, from a tap to a full wind-up. The
## ball the old game held, unchanged.
const HELD_BODIES := Vector2(0.12, 0.4)

## How far off the cross a fly can be and still be what the web is thrown at, in
## degrees past its own outline.
const PICK_ANGLE := 3.0

var weaver: Weaver
var view: SpiderCamera

var charging := false

## How far through the wind-up, 0 to 1.
var charge := 0.0

var _cooling := 0.0
var _held: MeshInstance3D
var _held_material: StandardMaterial3D


func setup(owner_weaver: Weaver, camera: SpiderCamera) -> void:
	weaver = owner_weaver
	view = camera
	_build_held()


## The key went down: start winding up.
func begin() -> bool:
	if charging:
		return false
	charging = true
	charge = 0.0
	_held.visible = true
	return true


## Let go: throw what the wind-up reached. False if nothing went.
func release() -> bool:
	if not charging:
		return false
	charging = false
	_held.visible = false
	var wound := charge
	charge = 0.0
	return throw(wound)


## Put the ball away without throwing.
func cancel() -> void:
	charging = false
	charge = 0.0
	if _held != null:
		_held.visible = false


## Throws a web wound up to [param wound], 0 to 1, down the cross. What letting
## go does, and what a check calls to throw without a key.
func throw(wound := 0.0) -> bool:
	if _cooling > 0.0:
		return false
	if weaver.webs_left() <= 0:
		weaver.notify("No silk left — call your webs back (E)")
		weaver.out_of_silk.emit()
		return false
	var from := view.aim_origin()
	var heading := view.aim_forward()
	var radius := web_radius(wound)
	var fly := picked_fly()
	if fly != null:
		# Only steered when the throw as aimed would miss: a web that will pass over
		# the fly anyway goes where the cross is, which may be the wall behind it.
		var meet := intercept(from, SPEED, fly.global_position, fly.velocity)
		var along := (meet - from).dot(heading)
		var miss := (meet - (from + heading * along)).length()
		if along <= 0.0 or miss > radius * 0.7:
			var lead := meet - from
			if lead.length_squared() > 0.0001:
				heading = lead.normalized()
	var web := ThrownWeb.throw(weaver.web_container(), weaver, from, heading, SPEED, radius, REACH)
	weaver.adopt_web(web)
	_cooling = COOLDOWN
	return true


## How wide a web wound up to [param wound] is.
func web_radius(wound: float) -> float:
	return lerpf(SMALLEST, BIGGEST, clampf(wound, 0.0, 1.0))


## The fly a throw now would be aimed at, if any: the one nearest the cross whose
## outline is within [constant PICK_ANGLE] of it, in reach and in plain sight — or,
## while Shift is held, the fly the spider has locked on to.
func picked_fly() -> Fly:
	if view == null or view.camera == null:
		return null
	if weaver.locking and weaver.lock_target != null:
		return weaver.lock_target
	var eye := view.camera.global_position
	var look := -view.camera.global_basis.z.normalized()
	var from := view.aim_origin()
	var best: Fly = null
	var best_slack := INF
	for node in get_tree().get_nodes_in_group(Fly.GROUP):
		var fly := node as Fly
		if fly == null or not fly.is_free():
			continue
		var at := fly.global_position
		if from.distance_to(at) > REACH:
			continue
		var sight := at - eye
		var distance := sight.length()
		if distance < 0.01:
			continue
		var slack := rad_to_deg(look.angle_to(sight)) - rad_to_deg(atan2(Fly.HIT_RADIUS, distance))
		if slack > PICK_ANGLE or slack >= best_slack:
			continue
		var query := PhysicsRayQueryParameters3D.create(from, at, GameLayers.WORLD,
			[weaver.get_rid()])
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			continue
		best_slack = slack
		best = fly
	return best


func _process(delta: float) -> void:
	_cooling = maxf(0.0, _cooling - delta)
	if charging:
		charge = clampf(charge + delta / CHARGE_TIME, 0.0, 1.0)
	# The framing: the view lifts over the spider's back while a throw winds up,
	# and comes back down after, eased either way.
	if view != null:
		view.aim_blend = move_toward(view.aim_blend, 1.0 if charging else 0.0, delta * 4.0)
	_update_held()


## How big the held ball is at [param wound].
func ball_radius(wound: float) -> float:
	return Weaver.HEIGHT * lerpf(HELD_BODIES.x, HELD_BODIES.y, clampf(wound, 0.0, 1.0))


## Where the ball is held, or nowhere.
func held_ball() -> Node3D:
	return _held if _held != null and _held.visible else null


func _update_held() -> void:
	if _held == null or not _held.visible:
		return
	var wide := ball_radius(charge)
	var back := weaver.global_basis.y.normalized()
	_held.global_position = weaver.global_position + back * (Weaver.HEIGHT * 0.9 + wide)
	_held.scale = Vector3.ONE * maxf(wide, 0.005)
	_held_material.emission_energy_multiplier = lerpf(0.5, 2.2, charge)


func _build_held() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	_held_material = WebGeometry.silk_material()
	_held_material.albedo_color = Color(0.12, 0.13, 0.16, 1.0)
	_held = MeshInstance3D.new()
	_held.name = "HeldSilk"
	_held.mesh = mesh
	_held.material_override = _held_material
	_held.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_held.top_level = true
	_held.visible = false
	add_child(_held)


## Where to throw from [param from], at [param pace], to meet something at
## [param at] moving at [param velocity] — if it keeps going the way it is going:
## the point where web and fly arrive at the same moment. Something too fast to
## catch, or not moving, gets thrown at where it is.
static func intercept(from: Vector3, pace: float, at: Vector3, velocity: Vector3) -> Vector3:
	var gap := at - from
	var a := velocity.dot(velocity) - pace * pace
	var b := 2.0 * gap.dot(velocity)
	var c := gap.dot(gap)
	var soonest := -1.0
	if absf(a) < 0.000001:
		if absf(b) > 0.000001:
			soonest = -c / b
	else:
		var room := b * b - 4.0 * a * c
		if room >= 0.0:
			var first := (-b - sqrt(room)) / (2.0 * a)
			var second := (-b + sqrt(room)) / (2.0 * a)
			for t in [minf(first, second), maxf(first, second)]:
				if t > 0.0:
					soonest = t
					break
	if soonest <= 0.0:
		return at
	return at + velocity * soonest
