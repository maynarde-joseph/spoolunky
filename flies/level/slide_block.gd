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
## It wears orange trim, so it reads as something that moves, and orange arrows on
## its sides point the way it will slide when a web on it is next called home.

const TRIM := Color(0.95, 0.62, 0.2)

## Where the rail goes, from where the block starts, in the level's own axes.
var travel := Vector3(0.0, 0.0, -6.0)

## How fast it slides, in metres a second.
var speed := 6.0

var _start := Vector3.ZERO
## Where it is going along the rail: 0 its start, 1 the far end.
var _goal := 0.0
## The arrows on its sides, and which way along the rail they point: 1 toward the
## far end, -1 back toward the start.
var _arrows: Array[MeshInstance3D] = []
var _pointing := 0.0


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


## Which way along its rail it will go next: 1 toward the far end, -1 back. While
## it moves, the way it is going; at rest, the way a call would send it.
func heading() -> float:
	var now := along()
	if absf(now - _goal) >= 0.0001:
		return signf(_goal - now)
	return 1.0 if _goal < 0.5 else -1.0


func _physics_process(delta: float) -> void:
	if travel.length_squared() < 0.0001:
		return
	var now := along()
	if absf(now - _goal) >= 0.0001:
		var next := move_toward(now, _goal, speed * delta / travel.length())
		position = _start + travel * next
	_point(heading())


# --- how it looks -----------------------------------------------------------------

func _show_rail() -> void:
	var view := get_node_or_null("View") as GeometryInstance3D
	if view != null:
		view.material_override = Surfaces.paint("rail_block")
	if travel.length_squared() < 0.0001:
		return
	var box := _box()
	var way := (transform.basis.inverse() * travel).normalized()
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	paint.albedo_color = TRIM
	var shape := _arrow_mesh()
	for face in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK,
			Vector3.FORWARD]:
		if absf(face.dot(way)) > 0.1:
			continue
		# How big the face is along the rail, and across it.
		var across: Vector3 = face.cross(way).abs()
		var long := absf(box.size.dot(way.abs()))
		var wide := absf(box.size.dot(across))
		var size := minf(long * 0.7, wide * 1.2)
		if size < 0.3:
			continue
		var arrow := MeshInstance3D.new()
		arrow.name = "Arrow"
		arrow.mesh = shape
		arrow.material_override = paint
		arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		arrow.set_meta("face", face)
		arrow.set_meta("way", way)
		arrow.set_meta("size", size)
		var centre: Vector3 = box.get_center() + face * (absf(box.size.dot(face.abs())) * 0.5 + 0.02)
		arrow.set_meta("centre", centre)
		add_child(arrow)
		_arrows.append(arrow)
	_pointing = 0.0
	_point(heading())


## Turns the arrows to point [param sign] along the rail.
func _point(sign: float) -> void:
	if sign == _pointing or _arrows.is_empty():
		return
	_pointing = sign
	for arrow in _arrows:
		var face: Vector3 = arrow.get_meta("face")
		var x: Vector3 = (arrow.get_meta("way") as Vector3) * sign
		var size: float = arrow.get_meta("size")
		var y := face.cross(x)
		arrow.transform = Transform3D(Basis(x, y, face) * Basis.from_scale(Vector3.ONE * size),
			arrow.get_meta("centre"))


## A flat arrow a metre long, pointing along +x, lying in the xy plane.
static func _arrow_mesh() -> ArrayMesh:
	var outline := PackedVector2Array([
		Vector2(-0.5, -0.12), Vector2(0.08, -0.12), Vector2(0.08, -0.3), Vector2(0.5, 0.0),
		Vector2(0.08, 0.3), Vector2(0.08, 0.12), Vector2(-0.5, 0.12)])
	var corners := PackedVector3Array()
	for point in outline:
		corners.append(Vector3(point.x, point.y, 0.0))
	var triangles := Geometry2D.triangulate_polygon(outline)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = corners
	arrays[Mesh.ARRAY_INDEX] = triangles
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## The block's own box, in its own space: from its collision shape.
func _box() -> AABB:
	var solid := get_node_or_null("Solid") as CollisionShape3D
	if solid != null and solid.shape is BoxShape3D:
		var size: Vector3 = (solid.shape as BoxShape3D).size
		return AABB(solid.position - size * 0.5, size)
	return AABB(Vector3(-0.5, 0.0, -0.5), Vector3.ONE)
