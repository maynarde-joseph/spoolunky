class_name WorldKit
extends RefCounted

## What the world is built from: solids that are something to see and something
## to stand on, each painted one flat colour from the [Palette].
##
## The greybox's idea with the colour put back. A solid is a mesh and, unless it
## is asked not to be, a collider of the same shape on the same body — so a
## toadstool's cap is somewhere to walk and somewhere silk sticks, with no second
## job of fitting colliders to it afterwards. The shapes are the ones the physics
## engine collides exactly: boxes, cylinders, balls and capsules, and the hull of
## the points for anything else that is convex. The few that are not — the inside
## of a hollow log — are one mesh, collided as its own triangles; and the ground
## is one height map.
##
## A solid goes on a body and is placed by a transform in that body's own space,
## so a prop is written once, standing on the origin and facing -Z, and turned and
## moved as a whole. Lengths are in metres, like everything else.
##
## Identical solids share one mesh and one shape. That is what keeps a baked scene
## small: forty stones of one size are one stone written forty times.

## How finely a round thing is drawn round its middle, by default.
const SIDES := 20

## Two faces whose normals are closer than this, in degrees, meet in a smooth
## curve; further apart, at a crisp edge. What lets one swept line be both a
## smooth round and a square corner.
const SMOOTH_UNDER := 35.0

static var _meshes := {}
static var _shapes := {}


# --- bodies --------------------------------------------------------------

## Something to put solids on: a body on the world layer, so silk sticks to it and
## the spider walks on it. It collides with nothing itself — it is what other
## things collide with.
static func body(parent: Node, part_name: String, where := Transform3D.IDENTITY) -> StaticBody3D:
	var holder := StaticBody3D.new()
	holder.name = part_name
	holder.collision_layer = GameLayers.WORLD
	holder.collision_mask = 0
	holder.transform = where
	if parent != null:
		parent.add_child(holder, true)
	return holder


## A plain node to gather parts under.
static func group(parent: Node, part_name: String, where := Transform3D.IDENTITY) -> Node3D:
	var holder := Node3D.new()
	holder.name = part_name
	holder.transform = where
	if parent != null:
		parent.add_child(holder, true)
	return holder


# --- solids --------------------------------------------------------------

## A box [param size] across, centred on [param where].
static func box(on: Node3D, part_name: String, size: Vector3, where: Transform3D,
		paint: String, solid := true) -> MeshInstance3D:
	var key := "box " + _key(size)
	var mesh := _mesh(key, func() -> Mesh:
		var made := BoxMesh.new()
		made.size = size
		return made)
	var shape: Shape3D = null
	if solid:
		shape = _shape(key, func() -> Shape3D:
			var made := BoxShape3D.new()
			made.size = size
			return made)
	return _place(on, part_name, mesh, shape, where, paint)


## A cylinder standing up [param where]'s own up axis, centred on it. [param top]
## tapers it — a trunk, a stalk, a cone — and a tapered one collides as the
## hull of its points rather than as a cylinder.
static func cylinder(on: Node3D, part_name: String, radius: float, height: float,
		where: Transform3D, paint: String, solid := true, top := -1.0,
		sides := SIDES) -> MeshInstance3D:
	var top_radius := radius if top < 0.0 else top
	var key := "cylinder %s %d" % [_key(Vector3(radius, height, top_radius)), sides]
	var mesh := _mesh(key, func() -> Mesh:
		var made := CylinderMesh.new()
		made.bottom_radius = radius
		made.top_radius = top_radius
		made.height = height
		made.radial_segments = sides
		made.rings = 1
		return made)
	var shape: Shape3D = null
	if solid:
		shape = _shape(key, func() -> Shape3D:
			if is_equal_approx(top_radius, radius):
				var round := CylinderShape3D.new()
				round.radius = radius
				round.height = height
				return round
			var points := _circle(radius, -height * 0.5, 12)
			if top_radius > 0.001:
				points.append_array(_circle(top_radius, height * 0.5, 12))
			else:
				points.append(Vector3(0.0, height * 0.5, 0.0))
			return _hull(points))
	return _place(on, part_name, mesh, shape, where, paint)


## A cylinder from one point to another: a stalk, a twig, a root, a branch.
static func rod(on: Node3D, part_name: String, from: Vector3, to: Vector3, radius: float,
		paint: String, solid := true, top := -1.0, sides := 12) -> MeshInstance3D:
	var along := to - from
	if along.length() < 0.0001:
		return null
	return cylinder(on, part_name, radius, along.length(),
		Transform3D(upright(along), (from + to) * 0.5), paint, solid, top, sides)


## A ball of [param radii] across, up and along — equal for a ball, unequal for an
## egg, a bun or a bush. An egg is the ball stretched, and collides as the hull of
## the same stretch.
static func ball(on: Node3D, part_name: String, radii: Vector3, where: Transform3D,
		paint: String, solid := true) -> MeshInstance3D:
	if is_equal_approx(radii.x, radii.y) and is_equal_approx(radii.y, radii.z):
		var key := "ball " + _key(radii)
		var mesh := _mesh(key, func() -> Mesh:
			var made := SphereMesh.new()
			made.radius = radii.x
			made.height = radii.x * 2.0
			made.radial_segments = 24
			made.rings = 12
			return made)
		var shape: Shape3D = null
		if solid:
			shape = _shape(key, func() -> Shape3D:
				var made := SphereShape3D.new()
				made.radius = radii.x
				return made)
		return _place(on, part_name, mesh, shape, where, paint)
	var unit := _mesh("ball unit", func() -> Mesh:
		var made := SphereMesh.new()
		made.radius = 1.0
		made.height = 2.0
		made.radial_segments = 24
		made.rings = 12
		return made)
	var stretched: Shape3D = null
	if solid:
		stretched = _shape("egg " + _key(radii), func() -> Shape3D:
			var points := PackedVector3Array()
			for ring in range(1, 6):
				var down := PI * float(ring) / 6.0
				for i in 10:
					var around := TAU * float(i) / 10.0
					points.append(Vector3(sin(down) * cos(around), cos(down),
						sin(down) * sin(around)) * radii)
			points.append(Vector3(0.0, radii.y, 0.0))
			points.append(Vector3(0.0, -radii.y, 0.0))
			return _hull(points))
	return _place(on, part_name, unit, stretched, where, paint,
		Transform3D(Basis.from_scale(radii), Vector3.ZERO))


## A capsule standing up [param where]'s up axis: a rod with round ends, the whole
## of it [param height] long. A seed head, the brown head of a bulrush.
static func capsule(on: Node3D, part_name: String, radius: float, height: float,
		where: Transform3D, paint: String, solid := true) -> MeshInstance3D:
	var key := "capsule " + _key(Vector3(radius, height, 0.0))
	var mesh := _mesh(key, func() -> Mesh:
		var made := CapsuleMesh.new()
		made.radius = radius
		made.height = maxf(height, radius * 2.0)
		made.radial_segments = 16
		made.rings = 6
		return made)
	var shape: Shape3D = null
	if solid:
		shape = _shape(key, func() -> Shape3D:
			var made := CapsuleShape3D.new()
			made.radius = radius
			made.height = maxf(height, radius * 2.0)
			return made)
	return _place(on, part_name, mesh, shape, where, paint)


## A ring lying flat on [param where]: the skirt on a toadstool's stem, the cut rim
## of a stump, the end of a hollow log. [param radius] is to the middle of the
## band and [param thickness] is the band's. Solid, it collides as the flat round
## it fills, hole and all.
static func ring(on: Node3D, part_name: String, radius: float, thickness: float,
		where: Transform3D, paint: String, solid := false) -> MeshInstance3D:
	var key := "ring " + _key(Vector3(radius, thickness, 0.0))
	var mesh := _mesh(key, func() -> Mesh:
		var made := TorusMesh.new()
		made.inner_radius = radius - thickness * 0.5
		made.outer_radius = radius + thickness * 0.5
		made.rings = 28
		made.ring_segments = 10
		return made)
	var shape: Shape3D = null
	if solid:
		shape = _shape(key, func() -> Shape3D:
			var made := CylinderShape3D.new()
			made.radius = radius + thickness * 0.5
			made.height = thickness
			return made)
	return _place(on, part_name, mesh, shape, where, paint)


## A flat plate cut to [param outline] — a convex outline of points in one plane,
## given in order round it — and [param thickness] thick across that plane: the
## blade of a fallen leaf. Collides as the hull of its corners.
static func plate(on: Node3D, part_name: String, outline: PackedVector3Array,
		thickness: float, paint: String, solid := true) -> MeshInstance3D:
	var face := Vector3.ZERO
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		face += Vector3((a.y - b.y) * (a.z + b.z), (a.z - b.z) * (a.x + b.x),
			(a.x - b.x) * (a.y + b.y))
	face = face.normalized()
	var half := face * thickness * 0.5
	var top := PackedVector3Array()
	var under := PackedVector3Array()
	for point in outline:
		top.append(point + half)
		under.append(point - half)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	var white := Color.WHITE
	var tints: Array[Color] = [white, white, white, white]
	for i in range(1, outline.size() - 1):
		var up: Array[Vector3] = [top[0], top[i], top[i + 1], top[i + 1]]
		_quad(tool, faces, up, [face, face, face, face], tints)
		var down: Array[Vector3] = [under[0], under[i], under[i + 1], under[i + 1]]
		_quad(tool, faces, down, [-face, -face, -face, -face], tints)
	var middle := Vector3.ZERO
	for point in outline:
		middle += point
	middle /= float(outline.size())
	for i in outline.size():
		var j := (i + 1) % outline.size()
		var out := (outline[j] - outline[i]).cross(face).normalized()
		if out.dot((outline[i] + outline[j]) * 0.5 - middle) < 0.0:
			out = -out
		var edge: Array[Vector3] = [top[i], top[j], under[j], under[i]]
		_quad(tool, faces, edge, [out, out, out, out], tints)
	var view := MeshInstance3D.new()
	view.name = part_name
	view.mesh = tool.commit()
	view.material_override = Palette.paint(paint)
	on.add_child(view, true)
	if solid:
		var corners := top.duplicate()
		corners.append_array(under)
		var hull := CollisionShape3D.new()
		hull.name = part_name + "Shape"
		hull.shape = _hull(corners)
		on.add_child(hull, true)
	return view


# --- shapes built a point at a time ---------------------------------------

## A line of (across, up) points swept [param length] along [param where]'s Z axis,
## centred on it, with a colour for each point. The surface faces to the left of
## the way the line runs, seen looking down -Z: run it left to right along a floor
## and it faces up, so a line run anticlockwise round the inside of a hollow log
## faces into the log.
static func extrude(on: Node3D, part_name: String, profile: PackedVector2Array,
		colours: PackedColorArray, length: float, where: Transform3D,
		solid := true) -> MeshInstance3D:
	var normals := _profile_normals(profile)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	var near := length * 0.5
	for k in profile.size() - 1:
		if profile[k].distance_to(profile[k + 1]) < 0.0001:
			continue
		var p0 := profile[k]
		var p1 := profile[k + 1]
		var n0: Vector2 = normals[k][1]
		var n1: Vector2 = normals[k][2]
		var corners: Array[Vector3] = [
			Vector3(p0.x, p0.y, near), Vector3(p0.x, p0.y, -near),
			Vector3(p1.x, p1.y, -near), Vector3(p1.x, p1.y, near)]
		var turns: Array[Vector3] = [
			Vector3(n0.x, n0.y, 0.0), Vector3(n0.x, n0.y, 0.0),
			Vector3(n1.x, n1.y, 0.0), Vector3(n1.x, n1.y, 0.0)]
		var tints: Array[Color] = [colours[k], colours[k], colours[k + 1], colours[k + 1]]
		_quad(tool, faces, corners, turns, tints)
	return _built(on, part_name, tool, faces, where, solid)


# --- ground --------------------------------------------------------------

## Ground over the square [param cells] × [param cell] across, centred on
## [param centre] in (x, z), shaped by [param height] — called with x and z, it
## says how high the ground is there — and painted by [param paint], called with
## the point and the way the ground faces there, which says its colour.
##
## Drawn in [param chunks] × [param chunks] pieces so that what is behind the
## camera is not drawn, smooth from one sample to the next; and collided as one
## height map, sample for sample the same, so what is walked on is what is seen.
## [param cells] should be a power of two: a height map that is not square and a
## power of two cells across is collided as triangles, which is far slower.
static func terrain(on: Node3D, part_name: String, centre: Vector2, cells: int, cell: float,
		height: Callable, paint: Callable, chunks := 8) -> void:
	var n := cells + 1
	var origin := centre - Vector2.ONE * float(cells) * cell * 0.5
	var heights := PackedFloat32Array()
	heights.resize(n * n)
	for j in n:
		for i in n:
			heights[j * n + i] = float(height.call(origin.x + float(i) * cell,
				origin.y + float(j) * cell))
	var per := cells / chunks
	for cj in chunks:
		for ci in chunks:
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			for j in range(cj * per, (cj + 1) * per + 1):
				for i in range(ci * per, (ci + 1) * per + 1):
					var at := Vector3(origin.x + float(i) * cell, heights[j * n + i],
						origin.y + float(j) * cell)
					var left := heights[j * n + maxi(i - 1, 0)]
					var right := heights[j * n + mini(i + 1, cells)]
					var near := heights[maxi(j - 1, 0) * n + i]
					var far := heights[mini(j + 1, cells) * n + i]
					var normal := Vector3(left - right, 2.0 * cell, near - far).normalized()
					tool.set_normal(normal)
					tool.set_color(paint.call(at, normal))
					tool.add_vertex(at)
			var row := per + 1
			for j in per:
				for i in per:
					var a := j * row + i
					tool.add_index(a)
					tool.add_index(a + 1)
					tool.add_index(a + row)
					tool.add_index(a + 1)
					tool.add_index(a + row + 1)
					tool.add_index(a + row)
			var view := MeshInstance3D.new()
			view.name = "%s%d" % [part_name, cj * chunks + ci]
			view.mesh = tool.commit()
			view.material_override = Palette.paint("painted")
			on.add_child(view, true)
	var shape := HeightMapShape3D.new()
	shape.map_width = n
	shape.map_depth = n
	var scaled := PackedFloat32Array()
	scaled.resize(n * n)
	for k in n * n:
		scaled[k] = heights[k] / cell
	shape.map_data = scaled
	var solid := CollisionShape3D.new()
	solid.name = part_name + "Shape"
	solid.shape = shape
	# Scaled the same every way, which is the only way a shape may be: one sample a
	# cell apart, and the heights given in cells to match.
	solid.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * cell),
		Vector3(centre.x, 0.0, centre.y))
	on.add_child(solid, true)


# --- water ---------------------------------------------------------------

## A body of water [param size] across, centred on [param where]: an area on the
## water layer, which is what the spider's swimming feels for, and its surface drawn
## across the top in [param paint]. The surface is only something to see — the
## water is the area — so things sink into it rather than standing on it.
static func water(parent: Node, part_name: String, size: Vector3, where: Transform3D,
		paint: String) -> Area3D:
	var shape := BoxShape3D.new()
	shape.size = size
	var pool := _water_area(parent, part_name, shape, where)
	var sheet := PlaneMesh.new()
	sheet.size = Vector2(size.x, size.z)
	_surface(pool, sheet, Vector3(0.0, size.y * 0.5, 0.0), paint)
	return pool


## A round body of water: a pond [param radius] across and [param depth] deep,
## standing on [param where] with its surface at the top.
static func round_water(parent: Node, part_name: String, radius: float, depth: float,
		where: Transform3D, paint: String) -> Area3D:
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = depth
	var pool := _water_area(parent, part_name, shape, where * Transform3D(Basis.IDENTITY,
		Vector3(0.0, depth * 0.5, 0.0)))
	var sheet := CylinderMesh.new()
	sheet.top_radius = radius
	sheet.bottom_radius = radius
	sheet.height = 0.02
	sheet.radial_segments = 64
	sheet.rings = 1
	_surface(pool, sheet, Vector3(0.0, depth * 0.5 - 0.01, 0.0), paint)
	return pool


static func _water_area(parent: Node, part_name: String, shape: Shape3D,
		where: Transform3D) -> Area3D:
	var pool := Area3D.new()
	pool.name = part_name
	pool.collision_layer = GameLayers.WATER
	pool.collision_mask = 0
	pool.monitoring = false
	pool.transform = where
	pool.add_to_group("water", true)
	var volume := CollisionShape3D.new()
	volume.name = "Volume"
	volume.shape = shape
	pool.add_child(volume)
	parent.add_child(pool, true)
	return pool


static func _surface(pool: Area3D, mesh: Mesh, at: Vector3, paint: String) -> void:
	var view := MeshInstance3D.new()
	view.name = "Surface"
	view.mesh = mesh
	view.material_override = Palette.paint(paint)
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.position = at
	pool.add_child(view)


# --- helpers -------------------------------------------------------------

## A basis whose up axis runs along [param direction], and whose other two are
## level when they can be.
static func upright(direction: Vector3) -> Basis:
	var up := direction.normalized()
	var helper := Vector3.UP if absf(up.dot(Vector3.UP)) < 0.99 else Vector3.BACK
	var across := helper.cross(up).normalized()
	var along := across.cross(up).normalized()
	return Basis(across, up, along)


## A transform standing at [param at], turned [param degrees] about the up axis.
static func at(position: Vector3, degrees := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(degrees)), position)


static func _place(on: Node3D, part_name: String, mesh: Mesh, shape: Shape3D,
		where: Transform3D, paint: String, look := Transform3D.IDENTITY) -> MeshInstance3D:
	var view := MeshInstance3D.new()
	view.name = part_name
	view.mesh = mesh
	view.material_override = Palette.paint(paint)
	view.transform = where * look
	on.add_child(view, true)
	if shape != null:
		var solid := CollisionShape3D.new()
		solid.name = part_name + "Shape"
		solid.shape = shape
		solid.transform = where
		on.add_child(solid, true)
	return view


static func _built(on: Node3D, part_name: String, tool: SurfaceTool,
		faces: PackedVector3Array, where: Transform3D, solid: bool) -> MeshInstance3D:
	# Neighbouring quads of a smooth surface share their corners exactly, so indexed
	# they share them in the mesh too: a quarter of the points to store.
	tool.index()
	var view := MeshInstance3D.new()
	view.name = part_name
	view.mesh = tool.commit()
	view.material_override = Palette.paint("painted")
	view.transform = where
	on.add_child(view, true)
	if solid and not faces.is_empty():
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces)
		# Either side: a hollow log is walked inside as well as out, and which way
		# round the points went is not something a spider on a wall should have to
		# care about.
		shape.backface_collision = true
		var solid_shape := CollisionShape3D.new()
		solid_shape.name = part_name + "Shape"
		solid_shape.shape = shape
		solid_shape.transform = where
		on.add_child(solid_shape, true)
	return view


## Two triangles from four corners given round the quad, each facing the way its
## normals say. Godot draws a triangle's front where its corners run clockwise, so
## every triangle is checked against its normal and turned over if it runs the
## other way — which is what lets the callers give their corners either way round.
static func _quad(tool: SurfaceTool, faces: PackedVector3Array, corners: Array[Vector3],
		turns: Array[Vector3], tints: Array[Color]) -> void:
	for tri in [[0, 1, 2], [0, 2, 3]]:
		var a: Vector3 = corners[tri[0]]
		var b: Vector3 = corners[tri[1]]
		var c: Vector3 = corners[tri[2]]
		var face := (c - a).cross(b - a)
		if face.length_squared() < 1e-12:
			continue
		var order: Array = tri
		var wanted: Vector3 = turns[tri[0]] + turns[tri[1]] + turns[tri[2]]
		if face.dot(wanted) < 0.0:
			order = [tri[0], tri[2], tri[1]]
		for index in order:
			tool.set_color(tints[index])
			tool.set_normal(turns[index])
			tool.add_vertex(corners[index])
			faces.append(corners[index])


## For each segment of a profile: its own normal, and the normals its two ends
## are drawn with — the average with the next segment's where the two meet in a
## smooth curve, its own where they meet at an edge.
static func _profile_normals(profile: PackedVector2Array) -> Array:
	var own: Array[Vector2] = []
	for k in profile.size() - 1:
		var along := profile[k + 1] - profile[k]
		own.append(Vector2(-along.y, along.x).normalized() if along.length() > 0.0001
			else Vector2.ZERO)
	var result := []
	var limit := cos(deg_to_rad(SMOOTH_UNDER))
	for k in own.size():
		var start := own[k]
		var end := own[k]
		var before := _neighbour(own, k, -1)
		var after := _neighbour(own, k, 1)
		if before != Vector2.ZERO and before.dot(own[k]) > limit:
			start = (before + own[k]).normalized()
		if after != Vector2.ZERO and after.dot(own[k]) > limit:
			end = (after + own[k]).normalized()
		result.append([own[k], start, end])
	return result


## The nearest segment's normal in [param step]'s direction that has any length:
## a point given twice to change colour is a segment of none, and smoothing should
## look past it.
static func _neighbour(own: Array[Vector2], k: int, step: int) -> Vector2:
	var i := k + step
	while i >= 0 and i < own.size():
		if own[i] != Vector2.ZERO:
			return own[i]
		i += step
	return Vector2.ZERO


static func _circle(radius: float, height: float, count: int) -> PackedVector3Array:
	var points := PackedVector3Array()
	for i in count:
		var angle := TAU * float(i) / float(count)
		points.append(Vector3(cos(angle) * radius, height, sin(angle) * radius))
	return points


static func _hull(points: PackedVector3Array) -> ConvexPolygonShape3D:
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	return shape


static func _mesh(key: String, make: Callable) -> Mesh:
	if not _meshes.has(key):
		_meshes[key] = make.call()
	return _meshes[key]


static func _shape(key: String, make: Callable) -> Shape3D:
	if not _shapes.has(key):
		_shapes[key] = make.call()
	return _shapes[key]


static func _key(value: Vector3) -> String:
	return "%.3f,%.3f,%.3f" % [value.x, value.y, value.z]
