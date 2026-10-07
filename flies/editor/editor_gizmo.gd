class_name EditorGizmo
extends Node3D

## The handles on the thing selected in the level editor, to drag with the mouse:
##
## - a coloured square on each face of anything with a size, to stretch it from
##   that face (red across, green up, blue along, turned as the thing is turned),
##   the opposite face staying put;
## - three arrows out of its middle, red for x, green for y (up) and blue for z,
##   to move it along just that axis, in the level's own axes;
## - a yellow ball at each stop on a moving platform's path, an aqua one where a
##   door opens to and an orange one at the far end of a rail block's rail.
##
## It only knows where the handles are and which one the mouse is over; the editor
## does the dragging, with [method resized] and the line and plane helpers here.

enum Kind { SIZE, MOVE, POINT, END }

## How big a handle looks, as a share of how far away it is: so it stays the same
## size on screen however close the camera is.
const ON_SCREEN := 0.022
## How near, in pixels, the mouse has to be to a handle to take it.
const REACH := 14.0
## How long a move arrow is, as a share of how far away it is.
const ARROW := 0.2
const AXIS_TINTS := [Color(0.95, 0.3, 0.3), Color(0.35, 0.9, 0.4), Color(0.35, 0.55, 1.0)]
const POINT_TINT := Color(1.0, 0.9, 0.35)
const OPEN_TINT := Color(0.4, 0.85, 0.95)
const RAIL_TINT := Color(0.95, 0.66, 0.22)
const HOT := Color(1.0, 1.0, 1.0)

## Every handle: [code]{kind, at, way, axis, sign, index, key, tint, origin}[/code].
## [code]at[/code] is where it is in the world; [code]way[/code] the direction it
## drags in, for a size or move handle; [code]axis[/code] and [code]sign[/code]
## which face it is on, or which axis it moves along; [code]origin[/code] where a
## move arrow starts from (its tip, [code]at[/code], is kept a set size on screen);
## [code]index[/code] the path stop; [code]key[/code] the setting an end handle sets.
var handles: Array[Dictionary] = []
## The handle the mouse is over, or -1.
var hot := -1

var _views: Array[MeshInstance3D] = []
var _box_mesh: BoxMesh
var _ball_mesh: SphereMesh
var _arrow_mesh: CylinderMesh


func _ready() -> void:
	_box_mesh = BoxMesh.new()
	_box_mesh.size = Vector3(1.0, 1.0, 0.25)
	_ball_mesh = SphereMesh.new()
	_ball_mesh.radius = 0.6
	_ball_mesh.height = 1.2
	_arrow_mesh = CylinderMesh.new()
	_arrow_mesh.top_radius = 0.0
	_arrow_mesh.bottom_radius = 0.6
	_arrow_mesh.height = 1.4


## Puts handles on [param thing], from its data; none for an empty dictionary.
func show_for(thing: Dictionary) -> void:
	handles.clear()
	hot = -1
	if not thing.is_empty():
		_find_handles(thing)
	_make_views()


func _find_handles(thing: Dictionary) -> void:
	var where := LevelData.transform_of(thing)
	var middle := where * Vector3(0.0, 0.5, 0.0)
	if thing.has("size"):
		var size := LevelData.vec(thing["size"])
		middle = where * Vector3(0.0, size.y * 0.5, 0.0)
		for axis in 3:
			for sign in [-1, 1]:
				var local := Vector3(0.0, size.y * 0.5, 0.0)
				local[axis] += size[axis] * 0.5 * sign
				var way: Vector3 = where.basis[axis].normalized() * sign
				handles.append({"kind": Kind.SIZE, "at": where * local, "way": way, "axis": axis,
					"sign": sign, "tint": AXIS_TINTS[axis]})
	for axis in 3:
		var way := Vector3.ZERO
		way[axis] = 1.0
		handles.append({"kind": Kind.MOVE, "at": middle + way, "origin": middle, "way": way,
			"axis": axis, "tint": AXIS_TINTS[axis]})
	var pos := LevelData.vec(thing.get("pos"))
	if thing.has("path"):
		var points := LevelData.path_of(thing)
		for i in points.size():
			if i == 0 and points[0].is_equal_approx(pos):
				continue
			handles.append({"kind": Kind.POINT, "at": points[i], "index": i, "tint": POINT_TINT})
	if thing.has("open"):
		handles.append({"kind": Kind.END, "at": pos + LevelData.vec(thing["open"]), "key": "open",
			"tint": OPEN_TINT})
	if thing.has("travel"):
		handles.append({"kind": Kind.END, "at": pos + LevelData.vec(thing["travel"]),
			"key": "travel", "tint": RAIL_TINT})


func _make_views() -> void:
	for view in _views:
		view.queue_free()
	_views.clear()
	for handle in handles:
		var view := MeshInstance3D.new()
		match handle["kind"]:
			Kind.SIZE:
				view.mesh = _box_mesh
			Kind.MOVE:
				view.mesh = _arrow_mesh
			_:
				view.mesh = _ball_mesh
		var paint := StandardMaterial3D.new()
		paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		paint.no_depth_test = true
		paint.render_priority = 10
		paint.albedo_color = handle["tint"]
		view.material_override = paint
		view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(view)
		_views.append(view)


## Keeps the handles the same size on screen from [param camera], facing their
## way, and lights up the one the mouse is over.
func update_view(camera: Camera3D) -> void:
	for i in handles.size():
		var handle := handles[i]
		var view := _views[i]
		if handle["kind"] == Kind.MOVE:
			var origin: Vector3 = handle["origin"]
			var away := maxf(camera.global_position.distance_to(origin), 0.5)
			handle["at"] = origin + (handle["way"] as Vector3) * away * ARROW
		var at: Vector3 = handle["at"]
		var scale_by := maxf(camera.global_position.distance_to(at), 0.5) * ON_SCREEN
		var basis := Basis.IDENTITY
		if handle["kind"] == Kind.SIZE:
			var way: Vector3 = handle["way"]
			var up := Vector3.UP if absf(way.y) < 0.99 else Vector3.FORWARD
			basis = Basis.looking_at(way, up)
		elif handle["kind"] == Kind.MOVE:
			# The cone points up its own y: turn y onto the axis.
			match int(handle["axis"]):
				0:
					basis = Basis(Vector3.BACK, -PI * 0.5)
				2:
					basis = Basis(Vector3.RIGHT, PI * 0.5)
		if handle["kind"] == Kind.MOVE:
			scale_by *= 1.4
		view.global_transform = Transform3D(basis.scaled(Vector3.ONE * scale_by), at)
		var paint := view.material_override as StandardMaterial3D
		paint.albedo_color = HOT if i == hot else handle["tint"]


## The handle under [param mouse], seen from [param camera], or -1.
func pick(camera: Camera3D, mouse: Vector2) -> int:
	var best := -1
	var nearest := REACH
	for i in handles.size():
		var at: Vector3 = handles[i]["at"]
		if camera.is_position_behind(at):
			continue
		var gap := camera.unproject_position(at).distance_to(mouse)
		if gap < nearest:
			nearest = gap
			best = i
	return best


# --- the dragging -------------------------------------------------------------------

## Stretches [param thing] by [param by] metres from its face on [param axis], on
## the [param sign] side, so the face opposite stays where it is. Never thinner
## than [param least].
static func resized(thing: Dictionary, axis: int, sign: int, by: float, least := 0.1) -> void:
	var size := LevelData.vec(thing["size"])
	var grown := maxf(size[axis] + by, least)
	var change := grown - size[axis]
	size[axis] = grown
	thing["size"] = LevelData.vec_out(size)
	var where := LevelData.transform_of(thing)
	var way: Vector3 = where.basis[axis].normalized() * sign
	# The pivot is the middle of the bottom: across and along it moves half the
	# change; up, only the bottom face moves it.
	var shift := Vector3.ZERO
	if axis == 1:
		if sign < 0:
			shift = way * change
	else:
		shift = way * change * 0.5
	thing["pos"] = LevelData.vec_out(where.origin + shift)


## How far along the line through [param origin] going [param way] the ray under
## [param mouse] comes closest to it; NAN when the ray runs along the line.
static func along_line(camera: Camera3D, mouse: Vector2, origin: Vector3, way: Vector3) -> float:
	var from := camera.project_ray_origin(mouse)
	var ray := camera.project_ray_normal(mouse)
	var d := way.normalized()
	var b := d.dot(ray)
	var denom := 1.0 - b * b
	if denom < 0.0001:
		return NAN
	var w := origin - from
	return (b * ray.dot(w) - d.dot(w)) / denom


## Where the ray under [param mouse] crosses the level plane at [param height], or
## [constant Vector3.INF].
static func on_plane(camera: Camera3D, mouse: Vector2, height: float) -> Vector3:
	var crossed: Variant = Plane(Vector3.UP, height).intersects_ray(
		camera.project_ray_origin(mouse), camera.project_ray_normal(mouse))
	return crossed if crossed != null else Vector3.INF
