class_name Crate
extends RigidBody3D

## A crate. Silk sticks to it like anything else, and a web on it brings it along
## when it is called home — that is the only way to move one. It weighs enough to
## hold a pressure plate down, which a spider does not.

const GROUP := "crate"
const SIZE := 1.0


func _init() -> void:
	collision_layer = GameLayers.WORLD
	collision_mask = GameLayers.WORLD
	mass = 4.0
	can_sleep = true
	continuous_cd = true


func _ready() -> void:
	add_to_group(GROUP)
	var view := MeshInstance3D.new()
	view.name = "View"
	var look := Kit.look_of("box")
	if look.is_empty():
		var box := BoxMesh.new()
		box.size = Vector3.ONE * SIZE
		view.mesh = box
	else:
		var native: Vector3 = look["size"]
		var stretch := Vector3.ONE * SIZE / maxf(native.x, 0.001)
		view.mesh = look["mesh"]
		view.transform = Transform3D(Basis.from_scale(stretch), Vector3(0.0, -SIZE * 0.5, 0.0)) \
			* (look["where"] as Transform3D)
	view.material_override = Surfaces.paint("crate")
	add_child(view)
	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE * SIZE
	var solid := CollisionShape3D.new()
	solid.name = "Solid"
	solid.shape = shape
	add_child(solid)
