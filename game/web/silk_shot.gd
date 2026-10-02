class_name SilkShot
extends Node3D

## A ball of silk in flight.
##
## The other way to make a web: instead of the web appearing where the
## crosshair is, a bolt of silk flies there and opens out where it lands. It
## travels, so it can miss, and it takes a moment, so a moving target has to be
## led. Put the cross on a creature and the builder does that sum — see
## [method intercept] — because how long the silk will take is the one thing the
## screen never tells you. The bolt itself flies dead straight either way.
##
## It holds the line it was fired along. It used to be pulled down a little,
## which meant the honest thing — aim at a wall, hit the wall — was only true
## up close, and the crosshair quietly stopped meaning anything past that.
## Leading something that is moving is a skill; compensating for a drop the
## crosshair does not show you is just a wrong crosshair.

## Landed. The point and the surface normal are where it opened out, the prey
## is whatever it hit if that was something alive, and the heading is the way
## the bolt was travelling — which is what decides the web's plane, because a
## web faces the way the silk came from.
signal landed(at: Vector3, normal: Vector3, prey: Node3D, heading: Vector3)

## Gave up without hitting anything worth opening on.
signal fizzled()

## How fast a bolt flies, in body heights a second — of a body counted as at
## least 0.3m tall, so a spiderling's silk is not a crawl. See [method pace_for].
const SPEED := 26.0

## How big the ball of silk is, and so how close it has to pass to catch
## something alive: it takes a creature when the ball touches the creature's
## hitbox, which is this plus [method Prey.hit_radius]. It is also the size the
## bead is drawn, so what you watch fly is what hits.
##
## The world is hit with a ray and anything alive with this swept ball, which is
## the split that makes the shot playable. A wall is a wall and deserves no
## forgiveness — a web has to land on the surface it is built against. A fly is
## five centimetres across and wandering, and a hairline will never touch one.
##
## It used to be far bigger than the ball — bigger than the web being thrown,
## and never less than two and a half body lengths — on the reasoning that "did
## the web cover it" was the honest question. It turned out to answer yes to
## nearly everything: sixty centimetres either side of the line for a
## spiderling's tap and a metre and a half wound up, against a fly five
## centimetres across, so every shot anywhere near a creature was a catch and
## where you aimed stopped mattering.
@export var catch_radius := 0.05

## How far it will travel before giving up, in metres.
@export var range_limit := 90.0

## And how long, in seconds. A shot that finds nothing has to stop being a
## shot: without this, silk fired at open sky is a node quietly flying away
## from the level for ever.
@export var lifetime := 2.0

## What the bead is drawn in, and how brightly it glows. Silk's own by default;
## a bolt of fire is thrown by the same code and only looks different.
@export var colour := Color(0.10, 0.11, 0.14, 1.0)
@export var glow := 0.9

## Whether it glows in its own colour rather than silk's pale one.
@export var glows_own := false

var _velocity := Vector3.ZERO
var _travelled := 0.0
var _age := 0.0
var _exclude: Array[RID] = []
var _spent := false


static func fire(from: Vector3, direction: Vector3, body_height: float,
		exclude: Array[RID]) -> SilkShot:
	var shot := SilkShot.new()
	shot.name = "SilkShot"
	shot._exclude = exclude
	shot._velocity = direction.normalized() * pace_for(body_height)
	# Plain position, not global: nothing has a parent yet, and asking a Node3D
	# for its place in the world before it is in the tree is an error.
	shot.position = from
	return shot


## How fast a bolt thrown by a body [param body_height] tall flies, in metres a
## second.
static func pace_for(body_height: float) -> float:
	return SPEED * maxf(body_height, 0.3)


## Where to throw from [param from], at [param pace], to meet something at
## [param at] moving at [param velocity] — if it keeps going the way it is going.
##
## The straight answer to a moving target: the point where silk and creature
## arrive at the same moment. It is where a good shot would lead to by eye, worked
## out so the player does not have to guess how long the silk will take, which
## the screen never shows them. It promises nothing — anything that turns while
## the silk is in the air has turned away from where it was going to be.
##
## Something too fast to catch at all, or not moving, gets thrown at where it is.
static func intercept(from: Vector3, pace: float, at: Vector3, velocity: Vector3) -> Vector3:
	var gap := at - from
	# |gap + velocity t| = pace t, solved for the soonest t after now.
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


## Holds the throw to a distance, and gives it just enough life to fly it.
##
## A bolt used to be given a flat ninety metres and two seconds, which at any
## size above a house spider is further than the eye can pick a target out — so
## "how far can I throw silk" had no answer you could feel. It is the same reach
## the grapple has now, which is the body's own.
func limit_to(distance: float) -> void:
	range_limit = maxf(distance, 0.1)
	var pace := _velocity.length()
	if pace > 0.001:
		lifetime = range_limit / pace + 0.2


## Which way it is travelling. Read off the bolt rather than remembered from the
## trigger, so a web opens facing the way the silk actually arrived.
func heading() -> Vector3:
	if _velocity.length_squared() < 0.000001:
		return Vector3.FORWARD
	return _velocity.normalized()


func launch_from(container: Node3D, at: Vector3) -> void:
	container.add_child(self)
	global_position = at
	_build_visual()


func _physics_process(delta: float) -> void:
	if _spent:
		return
	_age += delta
	if lifetime > 0.0 and _age >= lifetime:
		_give_up()
		return
	var step := _velocity * delta
	var distance := step.length()
	if distance < 0.0001:
		return

	# The world, exactly. Swept, not teleported: a bolt moving at speed would
	# otherwise pass straight through anything thinner than one frame of travel.
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(global_position,
		global_position + step,
		GameLayers.WORLD | GameLayers.WEB_WALK, _exclude)
	var hit := space.intersect_ray(query)
	var reach := 1.0
	if not hit.is_empty():
		var landing: Vector3 = hit.get("position", global_position)
		reach = clampf((landing - global_position).length() / distance, 0.0, 1.0)

	# And anything alive, generously — but never through the wall in front of it.
	var creature := _creature_along(step, reach)
	if creature != null:
		_land_on(creature)
		return
	if not hit.is_empty():
		_land(hit)
		return

	global_position += step
	_travelled += distance
	if _travelled >= range_limit:
		_give_up()


## The nearest creature the ball touches during this frame's step — passing
## within [member catch_radius] of its hitbox — and never past what the world
## stopped it at.
func _creature_along(step: Vector3, reach: float) -> Prey:
	var span: float = maxf(step.length_squared(), 0.000001)
	var best: Prey = null
	var soonest := 2.0
	for node in get_tree().get_nodes_in_group("prey"):
		var creature := node as Prey
		if creature == null or not is_instance_valid(creature) or creature.eaten:
			continue
		var offset := creature.global_position - global_position
		# Ahead of the bolt, not beside or behind it. Without this the first
		# frame of every shot sweeps up whatever happens to be standing next to
		# the spider, including things it was pointedly not aimed at.
		if offset.dot(step) < 0.0:
			continue
		var along := clampf(offset.dot(step) / span, 0.0, reach)
		if along >= soonest:
			continue
		if (offset - step * along).length() > catch_radius + creature.hit_radius():
			continue
		soonest = along
		best = creature
	return best


func _land_on(creature: Prey) -> void:
	_spent = true
	landed.emit(creature.global_position, Vector3.UP, creature, heading())
	queue_free()


func _give_up() -> void:
	_spent = true
	fizzled.emit()
	queue_free()


func _land(hit: Dictionary) -> void:
	_spent = true
	var at: Vector3 = hit.get("position", global_position)
	var normal: Vector3 = hit.get("normal", Vector3.UP)
	var struck := hit.get("collider") as Node3D
	var prey := struck as Prey
	if prey != null:
		# Open out on the thing rather than on the skin of it.
		at = prey.global_position
	landed.emit(at, normal, prey, heading())
	queue_free()


## Drawn at [member catch_radius] exactly, so the bead in flight is the ball that
## has to touch something.
func _build_visual() -> void:
	var radius := maxf(catch_radius, 0.005)
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	var material := WebGeometry.silk_material()
	# A bead you can follow, and a brighter one than the thread it becomes: in
	# flight it is the only thing on screen that has to be tracked.
	material.albedo_color = colour
	material.emission_energy_multiplier = glow
	if glows_own:
		material.emission = colour
	var view := MeshInstance3D.new()
	view.name = "Ball"
	view.mesh = mesh
	view.material_override = material
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(view)
