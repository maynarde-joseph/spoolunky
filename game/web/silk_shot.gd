class_name SilkShot
extends Node3D

## A ball of silk in flight.
##
## The other way to make a web: instead of the web appearing where the
## crosshair is, a bolt of silk flies there and opens out where it lands. It
## travels, so it can miss, and it takes a moment, so a moving target has to be
## led — which is a different skill from pointing at a spot, and the reason it
## is worth having both.

## Landed. The point and the surface normal are where it opened out, and the
## prey is whatever it hit, if it hit something alive rather than a wall.
signal landed(at: Vector3, normal: Vector3, prey: Node3D)

## Gave up without hitting anything worth opening on.
signal fizzled()

@export var speed := 26.0
@export var gravity_pull := 2.4

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
	_velocity += Vector3.DOWN * gravity_pull * delta
	var step := _velocity * delta
	var distance := step.length()
	if distance < 0.0001:
		return

	# Swept, not teleported: a bolt moving at speed would otherwise pass
	# straight through anything thinner than one frame of travel.
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(global_position,
		global_position + step,
		GameLayers.WORLD | GameLayers.PREY | GameLayers.WEB_WALK, _exclude)
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		_land(hit)
		return

	global_position += step
	_travelled += distance
	if _travelled >= range_limit:
		_give_up()


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
	landed.emit(at, normal, prey)
	queue_free()


func _build_visual() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = _size * 0.5
	mesh.height = _size
	mesh.radial_segments = 8
	mesh.rings = 4
	var material := WebGeometry.silk_material()
	material.albedo_color = Color(0.95, 0.96, 1.0, 0.9)
	var view := MeshInstance3D.new()
	view.name = "Ball"
	view.mesh = mesh
	view.material_override = material
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(view)
