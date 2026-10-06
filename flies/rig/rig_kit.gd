class_name RigKit
extends RefCounted

## What every creature's body is built from: bones added by where they sit, and
## meshes skinned to them one bone to a vertex.
##
## Everything here works in the space the caller builds in. A body scales its own
## node to the creature's size, so a rig can be written in whatever unit suits the
## animal — body heights for the spider, body radii for an insect.
##
## Nothing is blended. Every vertex belongs to exactly one bone, because the
## creatures this has to draw are made of rigid pieces that turn at their joints:
## exoskeletons, and limbs thin enough that a bend would never be seen.


# --- bones --------------------------------------------------------------------

## A basis whose +Y runs along [param direction], with +X as near [param hint]
## as it can be. Every bone and every pose in the rig is built with this, which is
## what keeps a segment from spinning about its own length as the leg moves.
static func along(direction: Vector3, hint: Vector3) -> Basis:
	var y := direction.normalized()
	var x := hint - y * hint.dot(y)
	if x.length_squared() < 0.000001:
		x = Vector3.RIGHT - y * y.x
		if x.length_squared() < 0.000001:
			x = Vector3.BACK - y * y.z
	x = x.normalized()
	return Basis(x, y, x.cross(y))


## Adds a bone called [param bone_name] under [param parent] (-1 for a root),
## given where it sits in the skeleton rather than relative to its parent, and
## returns its index. It starts posed at rest.
static func add_bone(skeleton: Skeleton3D, bone_name: String, parent: int,
		global_rest: Transform3D) -> int:
	skeleton.add_bone(bone_name)
	var index := skeleton.get_bone_count() - 1
	var rest := global_rest
	if parent >= 0:
		skeleton.set_bone_parent(index, parent)
		rest = skeleton.get_bone_global_rest(parent).affine_inverse() * global_rest
	skeleton.set_bone_rest(index, rest)
	skeleton.set_bone_pose(index, rest)
	return index


# --- meshes -------------------------------------------------------------------

## How finely a look cuts a limb: [member sides] round it, [member rows] down it
## between its two ends, and [member cap] rings in each end — none leaves the tube
## open, one brings it to a point, more round it off. [member twist] turns the
## cross-section about the limb, and [member flat] shades each face as the flat
## thing it is.
class Cut:
	var sides := 8
	var rows := 4
	var cap := 3
	var twist := 0.0
	var flat := false

	func _init(sides_round := 8, rows_down := 4, cap_rings := 3, faceted := false,
			turn := 0.0) -> void:
		sides = sides_round
		rows = rows_down
		cap = cap_rings
		flat = faceted
		twist = turn


## A surface to build into, ready for a bone and a weight on every vertex.
static func begin() -> SurfaceTool:
	var tool := SurfaceTool.new()
	# Before begin(), which refuses to change it after.
	tool.set_skin_weight_count(SurfaceTool.SKIN_4_WEIGHTS)
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	return tool


## One mesh made of [param surfaces], each given the material at the same place
## in [param materials]. A surface nothing was built into — the wings of a thing
## without any — is left out rather than committed empty.
static func commit(surfaces: Array, materials: Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for i in surfaces.size():
		var before := mesh.get_surface_count()
		(surfaces[i] as SurfaceTool).commit(mesh)
		if mesh.get_surface_count() > before:
			mesh.surface_set_material(before, materials[i])
	return mesh


## One vertex, in [param bone]'s rest space, put into the skeleton's rest space
## and tied to that bone alone.
static func vertex(tool: SurfaceTool, rest: Transform3D, bone: int, at: Vector3,
		normal: Vector3, colour: Color) -> void:
	tool.set_color(colour)
	tool.set_normal((rest.basis * normal).normalized())
	tool.set_bones(PackedInt32Array([bone, 0, 0, 0]))
	tool.set_weights(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
	tool.add_vertex(rest * at)


## An ellipsoid on [param bone], centred at [param centre] in its space.
## [param paint] colours it from the unit normal and the position, both in the
## bone's space; with [param flat], once per face rather than once per vertex.
static func ellipsoid(tool: SurfaceTool, skeleton: Skeleton3D, bone: int, centre: Vector3,
		radii: Vector3, paint: Callable, sides := 12, rings := 8, flat := false) -> void:
	var grid: Array = []
	for r in rings + 1:
		var row: Array = []
		var lat := PI * float(r) / float(rings) - PI * 0.5
		for s in sides + 1:
			var lon := TAU * float(s) / float(sides)
			var unit := Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon))
			var at := centre + unit * radii
			# The true normal of a squashed sphere, not the sphere's.
			var normal := Vector3(unit.x / radii.x, unit.y / radii.y, unit.z / radii.z).normalized()
			row.append([at, normal, Color.BLACK if flat else paint.call(normal, at)])
		grid.append(row)
	sew(tool, skeleton.get_bone_global_rest(bone), bone, grid, paint, flat)


## A limb segment on [param bone]: a tapered tube from its root to [param length]
## along +Y, closed at each end the way [param cut] says, so the joints read as
## joints. [param paint] colours it, as for [method ellipsoid].
static func segment(tool: SurfaceTool, skeleton: Skeleton3D, bone: int, length: float,
		root_radius: float, tip_radius: float, paint: Callable, cut: Cut) -> void:
	if bone < 0:
		return
	var rows: Array = []
	# Root cap, from the pole round to the equator.
	for r in cut.cap:
		var angle := PI * 0.5 * float(cut.cap - r) / float(cut.cap)
		rows.append([-sin(angle) * root_radius, cos(angle) * root_radius, -sin(angle)])
	for r in cut.rows + 1:
		var t := float(r) / float(cut.rows)
		rows.append([length * t, lerpf(root_radius, tip_radius, t), 0.0])
	for r in range(1, cut.cap + 1):
		var angle := PI * 0.5 * float(r) / float(cut.cap)
		rows.append([length + sin(angle) * tip_radius, cos(angle) * tip_radius, sin(angle)])
	var grid: Array = []
	for row in rows:
		var y: float = row[0]
		var radius: float = row[1]
		var tilt: float = row[2]
		var ring: Array = []
		for s in cut.sides + 1:
			var angle := TAU * float(s) / float(cut.sides) + cut.twist
			var around := Vector3(cos(angle), 0.0, sin(angle))
			var normal := (around * sqrt(maxf(1.0 - tilt * tilt, 0.0)) + Vector3.UP * tilt).normalized()
			var at := Vector3(around.x * radius, y, around.z * radius)
			ring.append([at, normal, Color.BLACK if cut.flat else paint.call(normal, at)])
		grid.append(ring)
	sew(tool, skeleton.get_bone_global_rest(bone), bone, grid, paint, cut.flat)


## A body part turned on a lathe: rings round an axis, each one a row of
## [param rows] — [y, radius across, radius up, colour] — in order along it.
## [param frame] carries the lathe's own space, where the axis is +Y, into the
## bone's; that is how an egg is laid along a body that runs front to back.
##
## Two rows at the same place give a hard edge between their colours, which is
## how a band round an abdomen starts where it starts rather than fading in over
## a row. A row with no radius is a pole.
static func lathe(tool: SurfaceTool, skeleton: Skeleton3D, bone: int, frame: Transform3D,
		rows: Array, sides := 12) -> void:
	if bone < 0 or rows.size() < 2:
		return
	var grid: Array = []
	for i in rows.size():
		var row: Array = rows[i]
		var y: float = row[0]
		var across: float = row[1]
		var up: float = row[2]
		# The slope of the profile here, from the nearest rows either side that sit
		# somewhere else along it: the rows of a hard edge share a place.
		var before := i
		while before > 0 and is_equal_approx(float(rows[before][0]), y):
			before -= 1
		var after := i
		while after < rows.size() - 1 and is_equal_approx(float(rows[after][0]), y):
			after += 1
		var run: float = float(rows[after][0]) - float(rows[before][0])
		var widen := 0.0
		var rise := 0.0
		if absf(run) > 0.000001:
			widen = (float(rows[after][1]) - float(rows[before][1])) / run
			rise = (float(rows[after][2]) - float(rows[before][2])) / run
		var ring: Array = []
		for s in sides + 1:
			var angle := TAU * float(s) / float(sides)
			var c := cos(angle)
			var n := sin(angle)
			var normal := Vector3(up * c, -(up * widen * c * c + across * rise * n * n), across * n)
			if normal.length_squared() < 0.000000001:
				normal = Vector3.DOWN if i == 0 else Vector3.UP
			ring.append([frame * Vector3(across * c, y, up * n),
				(frame.basis * normal).normalized(), row[3]])
		grid.append(ring)
	sew(tool, skeleton.get_bone_global_rest(bone), bone, grid, plain(Color.WHITE), false)


## A horn on [param bone]: a smooth rod from [param root] out along
## [param direction], [param thickness] round at the root and coming to a point
## [param length] away, bending [param curl] degrees over its length about
## [param axis] — a tusk curving up, a horn sweeping back, the beam of an antler.
## Drawn in [param pieces] lengths with a ball at every bend, so it reads as one
## curve. Returns where it went — the [code]points[/code] down it, the
## [code]ways[/code] it ran from each and its [code]radii[/code] there — for
## antlers to branch from.
static func horn(tool: SurfaceTool, skeleton: Skeleton3D, bone: int, root: Vector3,
		direction: Vector3, axis: Vector3, length: float, thickness: float, curl: float,
		colour: Color, pieces := 5) -> Dictionary:
	var points: Array[Vector3] = [root]
	var ways: Array[Vector3] = []
	var radii: Array[float] = []
	var turn := deg_to_rad(curl) / float(pieces)
	var piece := length / float(pieces)
	var spin := axis.normalized()
	for i in pieces + 1:
		var t := float(i) / float(pieces)
		radii.append(thickness * (1.0 - t * 0.82) if i < pieces else 0.0)
	for i in pieces:
		var way := direction.normalized().rotated(spin, turn * (float(i) + 0.5))
		ways.append(way)
		points.append(points[i] + way * piece)
	if bone < 0:
		return {"points": points, "ways": ways, "radii": radii}
	var paint := plain(colour)
	ellipsoid(tool, skeleton, bone, root, Vector3.ONE * radii[0], paint, 10, 6)
	for i in pieces:
		var frame := Transform3D(along(ways[i], spin), points[i])
		lathe(tool, skeleton, bone, frame, [
			[0.0, radii[i], radii[i], colour],
			[piece * (1.0 if i == pieces - 1 else 1.02), radii[i + 1], radii[i + 1], colour]], 10)
		if i > 0:
			ellipsoid(tool, skeleton, bone, points[i], Vector3.ONE * radii[i], paint, 10, 6)
	return {"points": points, "ways": ways, "radii": radii}


## The rows of an egg for [method lathe]: [param radii] across, up and half its
## length, centred on the lathe's origin, narrowing toward its +Y end by
## [param point] — 0 is an egg's round end, 1 comes to a point. [param paint]
## colours it by where along it a row is; [param cuts] are places along it where
## the colour changes all at once.
static func ovoid(radii: Vector3, point: float, count: int, paint: Callable,
		cuts := PackedFloat32Array()) -> Array:
	var places: Array[float] = []
	for i in count:
		# Closer together at the ends, where the curve is.
		places.append(-radii.z * cos(PI * float(i) / float(count - 1)))
	for cut in cuts:
		if cut > -radii.z and cut < radii.z:
			places.append(cut)
	places.sort()
	var rows: Array = []
	for y in places:
		var u := clampf(y / radii.z, -1.0, 1.0)
		var girth := sqrt(maxf(1.0 - u * u, 0.0)) * (1.0 - point * pow(maxf(u, 0.0), 1.5))
		var at_cut := false
		for cut in cuts:
			if is_equal_approx(cut, y):
				at_cut = true
		if at_cut:
			# Both colours, at the same place.
			rows.append([y, radii.x * girth, radii.y * girth, paint.call(y - 0.0001)])
		rows.append([y, radii.x * girth, radii.y * girth, paint.call(y + 0.0001)])
	return rows


## The rows of a rod for [method lathe], [param length] long and [param radius]
## round, from the origin along +Y, with a round end each side.
static func capsule(length: float, radius: float, colour: Color, ends := 3) -> Array:
	var rows: Array = []
	for i in ends + 1:
		var angle := PI * 0.5 * float(ends - i) / float(ends)
		rows.append([-sin(angle) * radius, cos(angle) * radius, cos(angle) * radius, colour])
	rows.append([length, radius, radius, colour])
	for i in range(1, ends + 1):
		var angle := PI * 0.5 * float(i) / float(ends)
		rows.append([length + sin(angle) * radius, cos(angle) * radius, cos(angle) * radius, colour])
	return rows


## An ear on [param bone], out along its +Y: [param width] across at its widest,
## [param length] long and [param depth] thick, in [param colour]. [param point]
## shapes it, from a rounded disc (0) to a triangle standing on its base (1), and
## [param turn] turns it about its own length, in degrees.
static func ear(tool: SurfaceTool, skeleton: Skeleton3D, bone: int, width: float,
		length: float, depth: float, point: float, colour: Color, turn := 0.0) -> void:
	if bone < 0:
		return
	var rows: Array = []
	for i in 13:
		var t := float(i) / 12.0
		var girth := _ear_girth(t, point)
		rows.append([t * length, girth * width, depth * clampf(girth * 1.5, 0.25, 1.0), colour])
	lathe(tool, skeleton, bone, Transform3D(Basis(Vector3.UP, deg_to_rad(turn)), Vector3.ZERO),
		rows, 14)


## How wide an ear is [param t] of the way out, against its widest.
static func _ear_girth(t: float, point: float) -> float:
	var round := sqrt(maxf(sin(PI * t), 0.0))
	var pointed := smoothstep(0.0, 0.18, t) * (1.0 - t) / 0.82
	return lerpf(round, pointed, point)


## Something flat — a wing — on [param bone]: out along its +Y for
## [param length], [param width] across where it is broadest, which is
## [param broadest] of the way out. It lies in the bone's X-Y plane with most of
## its width behind the leading edge, toward +X, the way a wing's stiff front
## edge runs nearly straight. [param colour] is the membrane and [param rim] a
## band round its edge.
##
## Both faces are built, each with its own normal, so it is lit the same whichever
## side you see it from. A material drawn from both sides instead lights the back
## as if it faced away, and a coloured wing seen from below goes muddy.
static func membrane(tool: SurfaceTool, skeleton: Skeleton3D, bone: int, length: float,
		width: float, broadest: float, colour: Color, rim: Color, points := 14) -> void:
	if bone < 0:
		return
	var rest := skeleton.get_bone_global_rest(bone)
	# How wide the blade is at each fraction of the way out: nothing at the root
	# and the tip, rounded at both, broadest where it was asked to be.
	var bulge := log(0.5) / log(clampf(broadest, 0.05, 0.95))
	var outline: Array[Vector3] = []
	for i in points + 1:
		var s := float(i) / float(points)
		var chord := sqrt(maxf(sin(PI * pow(s, bulge)), 0.0)) * width
		outline.append(Vector3(-0.3 * chord, s * length, 0.0))
	for i in range(points - 1, 0, -1):
		var s := float(i) / float(points)
		var chord := sqrt(maxf(sin(PI * pow(s, bulge)), 0.0)) * width
		outline.append(Vector3(0.7 * chord, s * length, 0.0))
	var middle := Vector3(0.2 * width, 0.5 * length, 0.0)
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		var a_in := middle.lerp(a, 0.86)
		var b_in := middle.lerp(b, 0.86)
		_two_faced(tool, rest, bone, [middle, b_in, a_in], colour)
		_two_faced(tool, rest, bone, [a_in, b_in, b], rim)
		_two_faced(tool, rest, bone, [a_in, b, a], rim)


## Something flat of any outline on [param bone] — a bat's wing between its
## fingers, a fan of feathers, a fin — lying in the X-Y plane of [param frame],
## which carries it into the bone's space, [param lift] along its Z.
## [param outline] goes round its edge and every point of it has to be in sight
## of [param middle], which it is filled from. Both faces are built, as for
## [method membrane], and a band [param rim_width] of the way in from the edge is
## [param rim].
static func panel(tool: SurfaceTool, skeleton: Skeleton3D, bone: int,
		outline: PackedVector2Array, middle: Vector2, colour: Color, rim: Color,
		rim_width := 0.1, lift := 0.0, frame := Transform3D.IDENTITY) -> void:
	if bone < 0 or outline.size() < 3:
		return
	var rest := skeleton.get_bone_global_rest(bone)
	var centre := frame * Vector3(middle.x, middle.y, lift)
	for i in outline.size():
		var a := frame * Vector3(outline[i].x, outline[i].y, lift)
		var b := frame * Vector3(outline[(i + 1) % outline.size()].x,
			outline[(i + 1) % outline.size()].y, lift)
		var a_in := centre.lerp(a, 1.0 - rim_width)
		var b_in := centre.lerp(b, 1.0 - rim_width)
		_two_faced(tool, rest, bone, [centre, b_in, a_in], colour)
		_two_faced(tool, rest, bone, [a_in, b_in, b], rim)
		_two_faced(tool, rest, bone, [a_in, b, a], rim)


## One flat triangle as two, back to back: the corners in one order facing one
## way and in the other order facing the other, each with the normal of the side
## it shows.
static func _two_faced(tool: SurfaceTool, rest: Transform3D, bone: int, corners: Array,
		colour: Color) -> void:
	var p0: Vector3 = corners[0]
	var p1: Vector3 = corners[1]
	var p2: Vector3 = corners[2]
	var across := (p1 - p0).cross(p2 - p0)
	if across.length_squared() < 1e-14:
		return
	# Godot's front faces go round clockwise, so the side a triangle shows is the
	# opposite of the one its corners wind round anticlockwise toward.
	var shown := -across.normalized()
	for corner in [p0, p1, p2]:
		vertex(tool, rest, bone, corner, shown, colour)
	for corner in [p0, p2, p1]:
		vertex(tool, rest, bone, corner, -shown, colour)


## Sews rings of vertices — each one [position, normal, colour], in the bone's
## space — into triangles on [param bone].
##
## With [param flat], every face gets one normal and one colour of its own, which
## is what makes low poly read as low poly rather than as a sphere drawn badly:
## the normal is the face's own, and the colour is [param paint]'s at its middle,
## a shade lighter or darker from face to face the way a faceted model is painted.
static func sew(tool: SurfaceTool, rest: Transform3D, bone: int, grid: Array,
		paint: Callable, flat: bool) -> void:
	for r in grid.size() - 1:
		for s in (grid[r] as Array).size() - 1:
			var a: Array = grid[r][s]
			var b: Array = grid[r + 1][s]
			var c: Array = grid[r + 1][s + 1]
			var d: Array = grid[r][s + 1]
			# Clockwise seen from outside, which is Godot's front face.
			for face in [[a, c, b], [a, d, c]]:
				if not flat:
					for corner in face:
						vertex(tool, rest, bone, corner[0], corner[1], corner[2])
					continue
				var p0: Vector3 = face[0][0]
				var p1: Vector3 = face[1][0]
				var p2: Vector3 = face[2][0]
				var normal := (p1 - p0).cross(p2 - p0)
				# Two corners on one pole: a face with no area, and no way it faces.
				if normal.length_squared() < 1e-14:
					continue
				normal = normal.normalized()
				var outward: Vector3 = face[0][1] + face[1][1] + face[2][1]
				if normal.dot(outward) < 0.0:
					normal = -normal
				var middle := (p0 + p1 + p2) / 3.0
				var colour: Color = paint.call(normal, middle)
				var shade := 0.94 + 0.12 * noise(middle)
				colour = Color(colour.r * shade, colour.g * shade, colour.b * shade, colour.a)
				for corner in face:
					vertex(tool, rest, bone, corner[0], normal, colour)


## A number from 0 to 1 that is the same every time for the same point.
static func noise(at: Vector3) -> float:
	return fposmod(sin(at.dot(Vector3(12.9898, 78.233, 37.719))) * 43758.5453, 1.0)


## Paints everything [param colour].
static func plain(colour: Color) -> Callable:
	return func(_n: Vector3, _p: Vector3) -> Color: return colour


## Paints every row of a lathe [param colour]: [method plain] for the ones
## coloured by where along them a row is.
static func solid(colour: Color) -> Callable:
	return func(_y: float) -> Color: return colour


## Paints a segment [param length] long [param colour], shading to [param tip]
## over its last quarter — where the band on a leg sits, at the joint.
static func banded(colour: Color, tip: Color, length: float) -> Callable:
	return func(_n: Vector3, p: Vector3) -> Color:
		return colour.lerp(tip, smoothstep(0.72, 1.0, clampf(p.y / length, 0.0, 1.0)))


# --- materials ----------------------------------------------------------------

## Coloured by the mesh's own vertex colours, so one material serves a body
## painted in several.
static func shell_material(roughness := 0.5, metallic := 0.08, rim := 0.35) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = roughness
	material.metallic = metallic
	# A little rim light for the hairs, so a dark spider against a dark wall still
	# has an outline.
	material.rim_enabled = true
	material.rim = rim
	material.rim_tint = 0.6
	return material


## One flat colour, soft and matte, with the same rim to keep an outline.
static func matte_material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.8
	material.rim_enabled = true
	material.rim = 0.3
	material.rim_tint = 0.5
	return material


## For a [method membrane]: coloured by the mesh, and see-through where its
## colours are when [param see_through]. It has two faces of its own, so nothing
## here has to draw a back. An insect's wing shines; skin and feathers want a
## [param roughness] nearer one.
static func membrane_material(see_through: bool, roughness := 0.35) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = roughness
	if see_through:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


## Gives off its own [param colour], [param energy] strong: a firefly's lantern.
static func glow_material(colour: Color, energy := 3.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.6
	material.emission_enabled = true
	material.emission = colour
	material.emission_energy_multiplier = energy
	return material


## Glossy, with a faint glow of [param shine] so a head can be found across a
## dark room.
static func eye_material(shine: Color, albedo := Color(0.02, 0.02, 0.025),
		glow := 0.35) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.roughness = 0.05
	material.metallic = 0.3
	material.emission_enabled = true
	material.emission = shine
	material.emission_energy_multiplier = glow
	return material
