class_name PressurePlate
extends StaticBody3D

## A plate in the floor. A crate on it presses it and powers its channel — the
## doors and platforms listening on that channel go. A spider is too light to.

const RADIUS := 1.5
const HEIGHT := 0.14
const SOLID := 0.06

var channel := "a"

var _pad: MeshInstance3D
var _paint: StandardMaterial3D
var _sense: Area3D
var _pressed := false


func _ready() -> void:
	collision_layer = GameLayers.WORLD
	collision_mask = 0
	var rim := MeshInstance3D.new()
	rim.name = "Rim"
	var ring := CylinderMesh.new()
	ring.top_radius = RADIUS + 0.12
	ring.bottom_radius = RADIUS + 0.18
	ring.height = HEIGHT * 0.6
	rim.mesh = ring
	rim.position.y = HEIGHT * 0.3
	rim.material_override = Surfaces.paint(Surfaces.STONE)
	add_child(rim)
	_pad = MeshInstance3D.new()
	_pad.name = "Pad"
	var disc := CylinderMesh.new()
	disc.top_radius = RADIUS
	disc.bottom_radius = RADIUS
	disc.height = HEIGHT
	_pad.mesh = disc
	_pad.position.y = HEIGHT * 0.5
	_paint = Surfaces.paint("plate").duplicate()
	_paint.emission_enabled = true
	_paint.emission = Color(1.0, 0.35, 0.25)
	_paint.emission_energy_multiplier = 0.1
	_pad.material_override = _paint
	add_child(_pad)
	# Solid only a little way up: a spider is a ball, and an edge as high as the
	# pad is drawn would stop it walking on, like a wall.
	var shape := CylinderShape3D.new()
	shape.radius = RADIUS + 0.18
	shape.height = SOLID
	var solid := CollisionShape3D.new()
	solid.shape = shape
	solid.position.y = SOLID * 0.5
	add_child(solid)

	_sense = Area3D.new()
	_sense.name = "Sense"
	_sense.collision_layer = 0
	_sense.collision_mask = GameLayers.WORLD
	var zone := CylinderShape3D.new()
	zone.radius = RADIUS
	zone.height = 0.6
	var volume := CollisionShape3D.new()
	volume.shape = zone
	volume.position.y = HEIGHT + 0.3
	_sense.add_child(volume)
	add_child(_sense)


func is_pressed() -> bool:
	return _pressed


func _physics_process(_delta: float) -> void:
	var now := false
	for found in _sense.get_overlapping_bodies():
		if found.is_in_group(Crate.GROUP) and not (found as RigidBody3D).freeze:
			now = true
			break
	if now == _pressed:
		return
	_pressed = now
	_pad.position.y = HEIGHT * (0.15 if _pressed else 0.5)
	_paint.emission_energy_multiplier = 1.6 if _pressed else 0.1
	var run := LevelRun.current(self)
	if run != null:
		run.power(channel, _pressed)
