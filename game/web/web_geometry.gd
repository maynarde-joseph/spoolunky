class_name WebGeometry
extends RefCounted

## Turns a handful of anchor points into actual silk.
##
## Nets are built by fitting a plane through the anchors, ordering them into a
## rim, then drawing spokes from the middle out to that rim and a spiral
## between the spokes. Because the rim follows the anchors, a web always takes
## the shape of the gap the player strung it across instead of being a stamped
## quad.
##
## Everything here works in local space around the web's own origin, so the
## resulting mesh can be parented anywhere.

const MIN_AREA := 0.0001


## A bundle of silk lines waiting to be turned into a mesh.
class StrandSet extends RefCounted:
	var starts := PackedVector3Array()
	var ends := PackedVector3Array()
	var widths := PackedFloat32Array()
	var length := 0.0

	func add(a: Vector3, b: Vector3, width: float) -> void:
		var span := a.distance_to(b)
		if span <= 0.0005:
			return
		starts.append(a)
		ends.append(b)
		widths.append(width)
		length += span

	func size() -> int:
		return starts.size()


## Result of laying out a net: mesh-ready strands plus the numbers the rest of
## the game needs (cost, collision hull, where the middle is).
class NetLayout extends RefCounted:
	var strands: StrandSet
	var rim: PackedVector3Array      ## ordered boundary, local space
	var centre := Vector3.ZERO       ## local-space middle of the web
	var normal := Vector3.UP         ## plane normal, world-aligned
	var area := 0.0                  ## enclosed area in square metres
	var radius := 0.0                ## furthest rim point from the centre
	var valid := false


## Builds the silk layout for a closed web from anchors given in world space.
## [param origin] is the node origin the returned points are relative to.
static func layout_net(world_points: PackedVector3Array, pattern: WebPattern,
		origin: Vector3, quality: float) -> NetLayout:
	var layout := NetLayout.new()
	layout.strands = StrandSet.new()
	if world_points.size() < 3:
		return layout

	var normal := plane_normal(world_points)
	var basis_u := _perpendicular(normal)
	var basis_v := normal.cross(basis_u).normalized()

	var rough_centre := _average(world_points)

	# Flatten onto the plane and order the anchors around the middle so the rim
	# never crosses itself, whatever order the player placed them in.
	var flat: Array[Vector2] = []
	for p in world_points:
		var d := p - rough_centre
		flat.append(Vector2(d.dot(basis_u), d.dot(basis_v)))
	flat.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		return a.angle() < b.angle())

	layout.area = _polygon_area(flat)
	if layout.area < MIN_AREA:
		return layout

	var centre_2d := _polygon_centroid(flat, layout.area)
	var centre_world := rough_centre + basis_u * centre_2d.x + basis_v * centre_2d.y

	# Re-centre everything on the true polygon centroid.
	var rim_2d: Array[Vector2] = []
	for f in flat:
		rim_2d.append(f - centre_2d)

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(centre_world * 97.0)) ^ hash(pattern.id)

	var thickness: float = pattern.strand_thickness * sqrt(quality)
	var to_local := func(p: Vector2) -> Vector3:
		return centre_world + basis_u * p.x + basis_v * p.y - origin

	# Rim: the frame the whole web hangs from, the thickest silk in it.
	for i in rim_2d.size():
		var a: Vector2 = rim_2d[i]
		var b: Vector2 = rim_2d[(i + 1) % rim_2d.size()]
		layout.strands.add(to_local.call(a), to_local.call(b), thickness * 1.5)
		layout.rim.append(to_local.call(a))
		layout.radius = maxf(layout.radius, a.length())

	layout.centre = to_local.call(Vector2.ZERO)
	layout.normal = normal

	# Spokes out to wherever the rim happens to be in that direction.
	var radials: int = pattern.radial_count
	var spoke_reach := PackedFloat32Array()
	var spoke_dir: Array[Vector2] = []
	if radials >= 3:
		for i in radials:
			var angle := TAU * float(i) / float(radials)
			angle += rng.randf_range(-1.0, 1.0) * pattern.jitter * TAU / float(radials) * 0.5
			var dir := Vector2(cos(angle), sin(angle))
			var reach := _ray_to_polygon(dir, rim_2d)
			spoke_dir.append(dir)
			spoke_reach.append(reach)
			if reach > 0.0:
				layout.strands.add(layout.centre, to_local.call(dir * reach), thickness)

	# Capture spiral, wound from the middle outward between the spokes.
	if radials >= 3 and pattern.ring_count > 0:
		var steps: int = pattern.ring_count * radials
		var rings_plus := float(pattern.ring_count + 1)
		for k in steps:
			var i: int = k % radials
			var j: int = (k + 1) % radials
			var f_a := (floorf(float(k) / float(radials)) + 1.0 + float(i) / float(radials)) / rings_plus
			var f_b := (floorf(float(k + 1) / float(radials)) + 1.0 + float(j) / float(radials)) / rings_plus
			if f_a >= 1.0 or f_b >= 1.0:
				continue
			var jitter_a := 1.0 + rng.randf_range(-1.0, 1.0) * pattern.jitter * 0.25
			var jitter_b := 1.0 + rng.randf_range(-1.0, 1.0) * pattern.jitter * 0.25
			var ra: float = spoke_reach[i] * f_a * jitter_a
			var rb: float = spoke_reach[j] * f_b * jitter_b
			if ra <= 0.0 or rb <= 0.0:
				continue
			layout.strands.add(to_local.call(spoke_dir[i] * ra),
				to_local.call(spoke_dir[j] * rb), thickness * 0.75)

	layout.valid = layout.strands.size() > 0
	return layout


## Silk lines for a simple two-point strand, in local space around [param origin].
static func layout_strand(a: Vector3, b: Vector3, pattern: WebPattern,
		origin: Vector3, quality: float) -> StrandSet:
	var strands := StrandSet.new()
	var thickness: float = pattern.strand_thickness * sqrt(quality)
	var local_a := a - origin
	var local_b := b - origin
	if pattern.walkable:
		# A bridge reads as a couple of parallel draglines with cross-ties.
		var axis := (local_b - local_a).normalized()
		var side := _perpendicular(axis) * pattern.walk_width * 0.5
		strands.add(local_a + side, local_b + side, thickness)
		strands.add(local_a - side, local_b - side, thickness)
		var rungs := maxi(2, int(local_a.distance_to(local_b) / maxf(pattern.walk_width, 0.05)))
		for i in range(1, rungs):
			var t := float(i) / float(rungs)
			var p := local_a.lerp(local_b, t)
			strands.add(p + side, p - side, thickness * 0.6)
	else:
		strands.add(local_a, local_b, thickness)
	return strands


## Builds the drawable mesh. Each silk line becomes two crossed quads so it
## stays visible from any angle without needing a billboard shader.
static func build_mesh(strands: StrandSet, color: Color) -> ArrayMesh:
	if strands.size() == 0:
		return null
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in strands.size():
		var a := strands.starts[i]
		var b := strands.ends[i]
		var half: float = strands.widths[i] * 0.5
		var axis := (b - a).normalized()
		var side_a := _perpendicular(axis)
		var side_b := axis.cross(side_a).normalized()
		_add_quad(tool, a, b, side_a * half, color)
		_add_quad(tool, a, b, side_b * half, color)
	tool.generate_tangents()
	return tool.commit()


## The one material every web shares. Unshaded so silk stays bright in a dark
## corner, double sided so it reads from behind, vertex coloured so each
## pattern can tint itself without a material per web.
static func silk_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(1, 1, 1, 1)
	material.disable_receive_shadows = true
	material.no_depth_test = false
	return material


## Best-fit plane normal for a ring of points (Newell's method).
static func plane_normal(points: PackedVector3Array) -> Vector3:
	var normal := Vector3.ZERO
	var count := points.size()
	for i in count:
		var current := points[i]
		var next := points[(i + 1) % count]
		normal.x += (current.y - next.y) * (current.z + next.z)
		normal.y += (current.z - next.z) * (current.x + next.x)
		normal.z += (current.x - next.x) * (current.y + next.y)
	if normal.length_squared() < 0.000001:
		if count >= 3:
			normal = (points[1] - points[0]).cross(points[2] - points[0])
		if normal.length_squared() < 0.000001:
			return Vector3.UP
	return normal.normalized()


## Convex hull points for a net's catch volume: the rim, pushed out to either
## side of the plane so prey passing through is actually overlapped.
static func catch_hull(rim: PackedVector3Array, normal: Vector3, depth: float) -> PackedVector3Array:
	var hull := PackedVector3Array()
	var offset := normal * maxf(depth, 0.01) * 0.5
	for p in rim:
		hull.append(p + offset)
		hull.append(p - offset)
	return hull


static func _add_quad(tool: SurfaceTool, a: Vector3, b: Vector3, offset: Vector3, color: Color) -> void:
	var normal := (b - a).cross(offset).normalized()
	var p0 := a - offset
	var p1 := a + offset
	var p2 := b + offset
	var p3 := b - offset
	tool.set_color(color)
	tool.set_normal(normal)
	tool.set_uv(Vector2(0, 0))
	tool.add_vertex(p0)
	tool.set_uv(Vector2(0, 1))
	tool.add_vertex(p1)
	tool.set_uv(Vector2(1, 1))
	tool.add_vertex(p2)
	tool.set_uv(Vector2(0, 0))
	tool.add_vertex(p0)
	tool.set_uv(Vector2(1, 1))
	tool.add_vertex(p2)
	tool.set_uv(Vector2(1, 0))
	tool.add_vertex(p3)


static func _average(points: PackedVector3Array) -> Vector3:
	var total := Vector3.ZERO
	for p in points:
		total += p
	return total / float(points.size())


static func _perpendicular(axis: Vector3) -> Vector3:
	var reference := Vector3.UP
	if absf(axis.dot(reference)) > 0.95:
		reference = Vector3.RIGHT
	return axis.cross(reference).normalized()


static func _polygon_area(points: Array[Vector2]) -> float:
	var total := 0.0
	for i in points.size():
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % points.size()]
		total += a.x * b.y - b.x * a.y
	return absf(total) * 0.5


static func _polygon_centroid(points: Array[Vector2], area: float) -> Vector2:
	if area < MIN_AREA:
		return Vector2.ZERO
	var centroid := Vector2.ZERO
	var signed := 0.0
	for i in points.size():
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % points.size()]
		var cross := a.x * b.y - b.x * a.y
		signed += cross
		centroid += (a + b) * cross
	if absf(signed) < 0.000001:
		return Vector2.ZERO
	return centroid / (3.0 * signed)


## Distance from the origin out to the polygon rim along [param dir].
static func _ray_to_polygon(dir: Vector2, polygon: Array[Vector2]) -> float:
	var best := -1.0
	for i in polygon.size():
		var a: Vector2 = polygon[i]
		var edge: Vector2 = polygon[(i + 1) % polygon.size()] - a
		var denom := dir.cross(edge)
		if absf(denom) < 0.000001:
			continue
		var along_ray := a.cross(edge) / denom
		var along_edge := a.cross(dir) / denom
		if along_ray <= 0.0 or along_edge < 0.0 or along_edge > 1.0:
			continue
		if best < 0.0 or along_ray < best:
			best = along_ray
	return best
