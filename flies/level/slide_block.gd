class_name SlideBlock
extends AnimatableBody3D

## A block on a rail. Silk sticks to it, and goes with it; and call a web on it home
## and the block slides to the other end of its rail, and stops there. Call one home
## again and it slides back. Where you stand has nothing to do with it.
##
## The rail runs from where the block starts, by [member travel], in any direction
## — along the floor, straight up, slantwise — and the block never leaves it. Nothing
## but the Pullback moves it: it does not fall.
##
## It wears orange trim, so it reads as something that moves, and both ends of its
## rail are drawn as orange outlines of the block — where it is, and where it will
## go — joined by a bar, so you can see the whole way it can slide from anywhere.

const TRIM := Color(0.95, 0.62, 0.2)

## Where the rail goes, from where the block starts, in the level's own axes.
var travel := Vector3(0.0, 0.0, -6.0)

## How fast it slides, in metres a second.
var speed := 6.0

var _start := Vector3.ZERO
## Where it is going along the rail: 0 its start, 1 the far end.
var _goal := 0.0


func _ready() -> void:
	collision_layer = GameLayers.WORLD
	collision_mask = 0
	sync_to_physics = true
	_start = position
	# Its look and shape are put on after it is in the tree; dress the rail then.
	_show_rail.call_deferred()


## How far along its rail it is, 0 at its start and 1 at the far end.
func along() -> float:
	if travel.length_squared() < 0.0001:
		return 0.0
	return clampf((position - _start).dot(travel) / travel.length_squared(), 0.0, 1.0)


## A web on it called home: it sets off for the other end of its rail — or, caught
## on its way, turns round and goes back.
func pull() -> void:
	_goal = 0.0 if _goal >= 0.5 else 1.0


func _physics_process(delta: float) -> void:
	if travel.length_squared() < 0.0001:
		return
	var now := along()
	if absf(now - _goal) < 0.0001:
		return
	var next := move_toward(now, _goal, speed * delta / travel.length())
	position = _start + travel * next


# --- how it looks -----------------------------------------------------------------

func _show_rail() -> void:
	var view := get_node_or_null("View") as GeometryInstance3D
	if view != null:
		view.material_override = Surfaces.paint("rail_block")
	if travel.length_squared() < 0.0001:
		return
	var box := _box()
	var parent := get_parent() as Node3D
	var to_world := parent.global_transform if parent != null else Transform3D.IDENTITY
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.albedo_color = TRIM
	var rail := Node3D.new()
	rail.name = "Rail"
	rail.top_level = true
	add_child(rail)
	rail.global_transform = Transform3D.IDENTITY
	var turn := Basis(transform.basis.get_rotation_quaternion())
	for end in [Vector3.ZERO, travel]:
		var at := Transform3D(turn, _start + end)
		_outline(rail, to_world * at, box, paint)
	var middle := box.get_center()
	var from: Vector3 = to_world * (Transform3D(turn, _start) * middle)
	var to: Vector3 = to_world * (Transform3D(turn, _start + travel) * middle)
	_bar(rail, from, to, 0.18, paint)


## The block's own box, in its own space: from its collision shape.
func _box() -> AABB:
	var solid := get_node_or_null("Solid") as CollisionShape3D
	if solid != null and solid.shape is BoxShape3D:
		var size: Vector3 = (solid.shape as BoxShape3D).size
		return AABB(solid.position - size * 0.5, size)
	return AABB(Vector3(-0.5, 0.0, -0.5), Vector3.ONE)


## The twelve edges of [param box], placed by [param where], as thin orange bars.
func _outline(under: Node3D, where: Transform3D, box: AABB, paint: Material) -> void:
	var corners: Array[Vector3] = []
	for i in 8:
		corners.append(where * (box.position + Vector3(
			box.size.x if i & 1 else 0.0, box.size.y if i & 2 else 0.0, box.size.z if i & 4 else 0.0)))
	for edge in [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7],
			[0, 4], [1, 5], [2, 6], [3, 7]]:
		_bar(under, corners[edge[0]], corners[edge[1]], 0.07, paint)


func _bar(under: Node3D, from: Vector3, to: Vector3, thick: float, paint: Material) -> void:
	var length := from.distance_to(to)
	if length < 0.01:
		return
	var bar := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(thick, thick, length + thick)
	bar.mesh = mesh
	bar.material_override = paint
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	under.add_child(bar)
	var way := (to - from).normalized()
	var up := Vector3.UP if absf(way.y) < 0.99 else Vector3.RIGHT
	bar.global_transform = Transform3D(Basis.looking_at(way, up), (from + to) * 0.5)
