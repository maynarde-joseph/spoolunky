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

## How the inside of a closed web is woven.
enum Weave {
	## The web is the shape you drew: the spiral runs all the way out to the
	## anchors, so the silk takes the outline of whatever gap you strung it
	## across, however odd that outline is.
	STRETCHED,
	## The web a real spider would build: an even round capture spiral sitting
	## inside the frame, as big as will fit, with the spokes carrying on past it
	## to the anchors. Nothing is ever stretched out of shape.
	INSCRIBED,
}

## How much of the largest circle that fits inside the frame the capture spiral
## actually uses. Real webs leave a gap between spiral and frame.
const INSCRIBED_FILL := 0.9


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
	var rim: PackedVector3Array      ## ordered boundary at the real anchors, local space
	var centre := Vector3.ZERO       ## local-space hub of the web
	var normal := Vector3.UP         ## plane normal, world-aligned
	var area := 0.0                  ## catching area in square metres
	var radius := 0.0                ## furthest rim point from the hub
	var weave: Weave = Weave.STRETCHED
	var spiral_radius := 0.0         ## INSCRIBED only: radius of the sticky disc
	var plane_u := Vector3.RIGHT     ## in-plane axes, for orienting the catch volume
	var plane_v := Vector3.BACK
	var valid := false


## Builds the silk layout for a closed web from anchors given in world space.
## [param origin] is the node origin the returned points are relative to.
##
## The rim always sits on the real anchors — never on a flattened copy of them —
## so a web strung across a corner stays attached to all three surfaces and
## tents through the fold instead of slicing across it. Only the capture spiral
## cares about the fitted plane, and only in [constant Weave.INSCRIBED].
## [param include_frame] draws the rim as part of the web. Turn it off when the
## frame is already standing in the world as strands the spider walked.
static func layout_net(world_points: PackedVector3Array, pattern: WebPattern,
		origin: Vector3, quality: float, weave: Weave = Weave.STRETCHED,
		include_frame := true) -> NetLayout:
	var layout := NetLayout.new()
	layout.strands = StrandSet.new()
	layout.weave = weave
	if world_points.size() < 3:
		return layout

	var normal := plane_normal(world_points)
	var basis_u := _perpendicular(normal)
	var basis_v := normal.cross(basis_u).normalized()
	var rough_centre := _average(world_points)

	# Flatten onto the plane only to work out what order the anchors go round
	# in. The indices come along so the rim can use the real positions.
	var flat: Array[Vector2] = []
	for p in world_points:
		var offset := p - rough_centre
		flat.append(Vector2(offset.dot(basis_u), offset.dot(basis_v)))
	var order: Array[int] = []
	for i in flat.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		return flat[a].angle() < flat[b].angle())

	var rim_2d: Array[Vector2] = []
	for index in order:
		rim_2d.append(flat[index])
		layout.rim.append(world_points[index] - origin)

	var frame_area := _polygon_area(rim_2d)
	if frame_area < MIN_AREA:
		return layout

	# Where the hub goes, and how far the sticky part reaches.
	var hub_2d := _polygon_centroid(rim_2d)
	if weave == Weave.INSCRIBED:
		var circle := _largest_inscribed_circle(rim_2d)
		hub_2d = circle["centre"]
		layout.spiral_radius = float(circle["radius"]) * INSCRIBED_FILL
		if layout.spiral_radius < 0.005:
			return layout
		layout.area = PI * layout.spiral_radius * layout.spiral_radius
	else:
		layout.area = frame_area

	var hub := rough_centre + basis_u * hub_2d.x + basis_v * hub_2d.y - origin
	layout.centre = hub
	layout.normal = normal
	layout.plane_u = basis_u
	layout.plane_v = basis_v

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i((rough_centre + hub) * 97.0)) ^ hash(pattern.id)
	var thickness: float = pattern.strand_thickness * sqrt(quality)

	# Frame: the heaviest silk, run anchor to anchor exactly where they are.
	for i in layout.rim.size():
		var a := layout.rim[i]
		var b := layout.rim[(i + 1) % layout.rim.size()]
		if include_frame:
			layout.strands.add(a, b, thickness * 1.5)
		layout.radius = maxf(layout.radius, hub.distance_to(a))

	# Spokes, from the hub out to wherever the frame happens to be in that
	# direction. Straight lines, so a folded frame costs them nothing.
	var radials: int = pattern.radial_count
	var spoke_end := PackedVector3Array()
	var spoke_dir: Array[Vector2] = []
	if radials >= 3:
		for i in radials:
			var angle := TAU * float(i) / float(radials)
			angle += rng.randf_range(-1.0, 1.0) * pattern.jitter * TAU / float(radials) * 0.5
			var dir := Vector2(cos(angle), sin(angle))
			var hit := _ray_to_polygon(hub_2d, dir, rim_2d)
			spoke_dir.append(dir)
			if hit.is_empty():
				spoke_end.append(hub)
				continue
			var edge: int = hit["edge"]
			var along: float = hit["edge_t"]
			var end := layout.rim[edge].lerp(layout.rim[(edge + 1) % layout.rim.size()], along)
			spoke_end.append(end)
			layout.strands.add(hub, end, thickness)

	# Capture spiral.
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
			var point_a := _spiral_point(layout, hub, spoke_end, spoke_dir, i, f_a * jitter_a,
				basis_u, basis_v)
			var point_b := _spiral_point(layout, hub, spoke_end, spoke_dir, j, f_b * jitter_b,
				basis_u, basis_v)
			if point_a == hub or point_b == hub:
				continue
			layout.strands.add(point_a, point_b, thickness * 0.75)

	layout.valid = layout.strands.size() > 0
	return layout


## A point on the capture spiral. Stretched webs follow the spokes out to the
## frame; inscribed webs stay on an even circle around the hub.
static func _spiral_point(layout: NetLayout, hub: Vector3, spoke_end: PackedVector3Array,
		spoke_dir: Array[Vector2], index: int, fraction: float,
		basis_u: Vector3, basis_v: Vector3) -> Vector3:
	if layout.weave == Weave.INSCRIBED:
		var dir: Vector2 = spoke_dir[index]
		var reach := layout.spiral_radius * clampf(fraction, 0.0, 1.0)
		return hub + (basis_u * dir.x + basis_v * dir.y) * reach
	var end := spoke_end[index]
	if end == hub:
		return hub
	return hub.lerp(end, clampf(fraction, 0.0, 1.0))


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


## Draws a single silk line straight into an [ImmediateMesh], for lines that
## move every frame — a dragline, a tether — where rebuilding an [ArrayMesh]
## would be wasteful. Same crossed-quad trick as [method build_mesh].
static func draw_line_into(mesh: ImmediateMesh, material: Material, a: Vector3,
		b: Vector3, width: float, color: Color) -> void:
	if a.distance_squared_to(b) < 0.000001:
		return
	var axis := (b - a).normalized()
	var side_a := _perpendicular(axis) * width * 0.5
	var side_b := axis.cross(side_a).normalized() * width * 0.5
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, material)
	_write_quad(mesh, a, b, side_a, color)
	_write_quad(mesh, a, b, side_b, color)
	mesh.surface_end()


static func _write_quad(mesh: ImmediateMesh, a: Vector3, b: Vector3, offset: Vector3,
		color: Color) -> void:
	var p0 := a - offset
	var p1 := a + offset
	var p2 := b + offset
	var p3 := b - offset
	for point in [p0, p1, p2, p0, p2, p3]:
		mesh.surface_set_color(color)
		mesh.surface_add_vertex(point)


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


static func _polygon_centroid(points: Array[Vector2]) -> Vector2:
	var centroid := Vector2.ZERO
	var signed := 0.0
	for i in points.size():
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % points.size()]
		var cross := a.x * b.y - b.x * a.y
		signed += cross
		centroid += (a + b) * cross
	if absf(signed) < 0.000001:
		var mean := Vector2.ZERO
		for p in points:
			mean += p
		return mean / maxf(float(points.size()), 1.0)
	return centroid / (3.0 * signed)


## Where a ray from [param from] along [param dir] leaves the polygon: which
## edge it crossed and how far along that edge, so the caller can look the point
## up on the real three-dimensional rim. Empty if it never crosses.
static func _ray_to_polygon(from: Vector2, dir: Vector2, polygon: Array[Vector2]) -> Dictionary:
	var best := {}
	var best_distance := INF
	for i in polygon.size():
		var a: Vector2 = polygon[i]
		var edge: Vector2 = polygon[(i + 1) % polygon.size()] - a
		var denom := dir.cross(edge)
		if absf(denom) < 0.000001:
			continue
		var offset := a - from
		var along_ray := offset.cross(edge) / denom
		var along_edge := offset.cross(dir) / denom
		if along_ray <= 0.0 or along_edge < 0.0 or along_edge > 1.0:
			continue
		if along_ray < best_distance:
			best_distance = along_ray
			best = {"distance": along_ray, "edge": i, "edge_t": along_edge}
	return best


## Centre and radius of the largest circle that fits inside a polygon, found by
## narrowing a search window rather than solving it exactly — plenty for ten
## anchors, and it copes with awkward concave shapes.
static func _largest_inscribed_circle(polygon: Array[Vector2]) -> Dictionary:
	var lowest := Vector2(INF, INF)
	var highest := Vector2(-INF, -INF)
	for p in polygon:
		lowest = Vector2(minf(lowest.x, p.x), minf(lowest.y, p.y))
		highest = Vector2(maxf(highest.x, p.x), maxf(highest.y, p.y))

	var centre := _polygon_centroid(polygon)
	var best := _clearance(centre, polygon)
	var window: float = maxf(highest.x - lowest.x, highest.y - lowest.y) * 0.5

	for pass_index in 7:
		var step := window * 0.25
		var improved_centre := centre
		for gx in range(-2, 3):
			for gy in range(-2, 3):
				var candidate := centre + Vector2(float(gx), float(gy)) * step
				var clearance := _clearance(candidate, polygon)
				if clearance > best:
					best = clearance
					improved_centre = candidate
		centre = improved_centre
		window *= 0.5

	return {"centre": centre, "radius": maxf(best, 0.0)}


## Distance from a point to the nearest polygon edge, or zero if it is outside.
static func _clearance(point: Vector2, polygon: Array[Vector2]) -> float:
	if not _inside_polygon(point, polygon):
		return 0.0
	var nearest := INF
	for i in polygon.size():
		var a: Vector2 = polygon[i]
		var b: Vector2 = polygon[(i + 1) % polygon.size()]
		nearest = minf(nearest, _distance_to_segment(point, a, b))
	return nearest


static func _distance_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var edge := b - a
	var length_squared := edge.length_squared()
	if length_squared < 0.000001:
		return point.distance_to(a)
	var t := clampf((point - a).dot(edge) / length_squared, 0.0, 1.0)
	return point.distance_to(a + edge * t)


static func _inside_polygon(point: Vector2, polygon: Array[Vector2]) -> bool:
	var inside := false
	var count := polygon.size()
	var j := count - 1
	for i in count:
		var a: Vector2 = polygon[i]
		var b: Vector2 = polygon[j]
		if (a.y > point.y) != (b.y > point.y):
			var crossing := (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x
			if point.x < crossing:
				inside = not inside
		j = i
	return inside
