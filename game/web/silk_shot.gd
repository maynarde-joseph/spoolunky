class_name SilkShot
extends Node3D

## A ball of silk in flight.
##
## The other way to make a web: instead of the web appearing where the
## crosshair is, a bolt of silk flies there and opens out where it lands. It
## travels, so it can miss, and it takes a moment, so a moving target has to be
## led — which is a different skill from pointing at a spot, and the reason it
## is worth having both.
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

@export var speed := 26.0

## How wide the ball of silk counts as, for catching something alive.
##
## The world is hit with a ray and anything alive with a swept ball of this
## size, which is the split that makes the shot playable. A wall is a wall and
## deserves no forgiveness — a web has to land on the surface it is built
## against. A fly is five centimetres across and wandering, and a hairline ray
## will never touch one, which is why nothing could be caught by shooting at
## it. The web being thrown is bigger than the thing being thrown at, so "did
## the web cover it" is the honest question, not "did a line through the middle
## of it happen to touch".
@export var catch_radius := 0.6

## How far it will travel before giving up, in metres.
@export var range_limit := 90.0

## And how long, in seconds. A shot that finds nothing has to stop being a
## shot: without this, silk fired at open sky is a node quietly flying away
## from the level for ever.
@export var lifetime := 2.0

var _velocity := Vector3.ZERO
var _travelled := 0.0
var _age := 0.0
var _exclude: Array[RID] = []
var _size := 0.05
var _spent := false


static func fire(from: Vector3, direction: Vector3, body_height: float,
		exclude: Array[RID]) -> SilkShot:
	var shot := SilkShot.new()
	shot.name = "SilkShot"
	shot._exclude = exclude
	shot._size = maxf(body_height * 0.25, 0.04)
	shot._velocity = direction.normalized() * shot.speed * maxf(body_height, 0.3)
	# Plain position, not global: nothing has a parent yet, and asking a Node3D
	# for its place in the world before it is in the tree is an error.
	shot.position = from
	return shot


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


## The nearest creature the ball passes within [member catch_radius] of during
## this frame's step, and never past what the world stopped it at.
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
		if (offset - step * along).length() > catch_radius:
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


func _build_visual() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = _size * 0.5
	mesh.height = _size
	mesh.radial_segments = 8
	mesh.rings = 4
	var material := WebGeometry.silk_material()
	# A bead you can follow, and a brighter one than the thread it becomes: in
	# flight it is the only thing on screen that has to be tracked.
	material.albedo_color = Color(0.10, 0.11, 0.14, 1.0)
	material.emission_energy_multiplier = 0.9
	var view := MeshInstance3D.new()
	view.name = "Ball"
	view.mesh = mesh
	view.material_override = material
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(view)
