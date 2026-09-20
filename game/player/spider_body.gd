class_name SpiderBody
extends Node3D

## A stand-in spider, built out of primitives.
##
## Deliberately crude: it exists so the size of the thing is readable on screen
## and so third person has something to look at. Legs swing in two alternating
## sets when it moves, which is enough to tell walking from standing. Replace
## the whole node with a real rig when there is one.

## Local forward is -Z, matching the body it hangs off.
@export var body_colour := Color(0.1, 0.09, 0.12)
@export var joint_colour := Color(0.16, 0.13, 0.17)
@export var eye_colour := Color(0.85, 0.75, 0.3)

## How far the legs swing, in radians, and how fast they cycle per metre moved.
@export var leg_swing := 0.45
@export var leg_cycle := 2.4

var _legs: Array[Node3D] = []
var _phase := 0.0
var _height := 0.25


func _ready() -> void:
	_build()


## Rescales the whole spider. Called whenever the size tier changes.
func set_body_height(height: float) -> void:
	_height = maxf(height, 0.01)
	scale = Vector3.ONE * _height


## Swings the legs. [param speed] is metres per second along the ground.
func animate(delta: float, speed: float) -> void:
	if _legs.is_empty():
		return
	_phase += delta * (speed / maxf(_height, 0.01)) * leg_cycle
	var moving: float = clampf(speed / maxf(_height * 4.0, 0.01), 0.0, 1.0)
	for i in _legs.size():
		var leg := _legs[i]
		# Alternate sets, the way a real one does: four down, four swinging.
		var offset: float = PI if (i % 4) < 2 else 0.0
		var swing := sin(_phase + offset) * leg_swing * moving
		leg.rotation = Vector3(swing * 0.6, leg.get_meta("yaw", 0.0), swing)


func _build() -> void:
	# Sizes are in units of body height; the node is scaled to match.
	_blob(Vector3(0, 0.02, 0.28), Vector3(0.42, 0.34, 0.5), body_colour)   # abdomen
	_blob(Vector3(0, 0, -0.06), Vector3(0.3, 0.24, 0.34), joint_colour)     # thorax
	_blob(Vector3(-0.06, 0.05, -0.2), Vector3(0.07, 0.07, 0.07), eye_colour)
	_blob(Vector3(0.06, 0.05, -0.2), Vector3(0.07, 0.07, 0.07), eye_colour)

	var placements := [-0.22, -0.07, 0.08, 0.23]
	for side in [-1.0, 1.0]:
		for along in placements:
			_leg(side, along)


func _blob(at: Vector3, size: Vector3, colour: Color) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 10
	mesh.rings = 6
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.55
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = material
	view.position = at
	view.scale = size
	add_child(view)


func _leg(side: float, along: float) -> void:
	var hip := Node3D.new()
	hip.position = Vector3(0.11 * side, 0.0, along)
	var yaw := side * (0.5 + along * 1.4)
	hip.set_meta("yaw", yaw)
	hip.rotation = Vector3(0, yaw, 0)
	add_child(hip)
	_legs.append(hip)

	var material := StandardMaterial3D.new()
	material.albedo_color = body_colour
	material.roughness = 0.45

	# Out and up, then down to the ground: a knee, roughly.
	var knee := Vector3(0.34 * side, 0.30, 0.0)
	hip.add_child(_limb(Vector3.ZERO, knee, material))
	hip.add_child(_limb(knee, Vector3(0.66 * side, -0.48, 0.0), material))


## A box stretched between two points in the parent's space.
func _limb(from: Vector3, to: Vector3, material: Material) -> MeshInstance3D:
	var along := to - from
	var length := along.length()
	var view := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	view.mesh = mesh
	view.material_override = material
	view.position = (from + to) * 0.5
	if length > 0.0001:
		var direction := along / length
		var reference := Vector3.UP
		if absf(direction.dot(reference)) > 0.95:
			reference = Vector3.FORWARD
		# Built by hand rather than with look_at, which needs to be in the tree.
		view.basis = Basis.looking_at(direction, reference)
	view.scale = Vector3(0.05, 0.05, maxf(length, 0.0001))
	return view
