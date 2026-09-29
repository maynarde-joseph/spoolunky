class_name SpiderRig
extends RefCounted

## Builds the spider's skeleton, and the one skinned mesh that rides it.
##
## Everything here is in body heights — the body node is scaled to the tier — in
## the frame the spider moves in: forward is -Z, its back is +Y, and the ground
## sits at y = -0.5, the bottom of the collider.
##
## Every bone points along its own +Y, the way imported rigs do. That is so a
## modelled spider can be dropped onto the same bone names later and the gait will
## drive it unchanged; the mesh built here is a stand-in for that model, not the
## thing the animation is written against.
##
## A spider is a rigid exoskeleton in segments, so nothing is blended: every
## vertex belongs to exactly one bone, and each segment turns as a piece at its
## joint the way a real one does.

## One entry per pair of legs, front to back: where the hip sits along the body,
## which way the leg points at rest (degrees, positive is forward), how far out
## its foot sits when standing, and the three lengths the leg is made of.
##
## Legs I and IV are the long ones, as they are on most real spiders — the front
## pair to feel ahead, the back pair to push.
const LEGS := [
	{"z": -0.16, "yaw": 50.0, "reach": 0.64, "femur": 0.36, "tibia": 0.38, "tarsus": 0.27},
	{"z": -0.07, "yaw": 17.0, "reach": 0.68, "femur": 0.33, "tibia": 0.35, "tarsus": 0.24},
	{"z": 0.02, "yaw": -18.0, "reach": 0.66, "femur": 0.31, "tibia": 0.33, "tarsus": 0.23},
	{"z": 0.10, "yaw": -48.0, "reach": 0.66, "femur": 0.37, "tibia": 0.40, "tarsus": 0.28},
]

const SIDES := ["L", "R"]

const COXA := 0.06

## Where the body hangs below the collider's middle. A spider carries itself low
## between its knees, not perched on top of its legs — the knees ride above the
## carapace, which is most of what the silhouette is.
const BODY_DROP := -0.2

## The ground, in body space.
const GROUND := -0.5

## Where the hips sit: this far out from the midline, this far below the body's
## middle.
const HIP_OUT := 0.095
const HIP_DROP := -0.04


## Adds every bone to [param skeleton], with its rest pose.
static func build_bones(skeleton: Skeleton3D) -> void:
	skeleton.clear_bones()
	var root := _add(skeleton, "Root", -1, Transform3D.IDENTITY)
	var thorax := _add(skeleton, "Thorax", root,
		Transform3D(Basis.IDENTITY, Vector3(0.0, BODY_DROP, -0.02)))
	var head := _add(skeleton, "Head", thorax,
		Transform3D(Basis.IDENTITY, Vector3(0.0, BODY_DROP + 0.03, -0.20)))

	for s in 2:
		var side := -1.0 if s == 0 else 1.0
		var tag: String = SIDES[s]
		# Chelicerae hang down and forward from under the eyes, fangs folded in.
		var jaw_at := Vector3(0.034 * side, BODY_DROP - 0.005, -0.25)
		var jaw_dir := Vector3(0.0, -0.75, -0.66).normalized()
		var jaw := _add(skeleton, "Chelicera.%s" % tag, head,
			Transform3D(along(jaw_dir, Vector3.RIGHT), jaw_at))
		var fang_dir := Vector3(-0.55 * side, -0.55, -0.15).normalized()
		_add(skeleton, "Fang.%s" % tag, jaw,
			Transform3D(along(fang_dir, Vector3.RIGHT), jaw_at + jaw_dir * 0.1))
		# Pedipalps: out and forward, then down to the ground ahead of the jaws.
		var palp_at := Vector3(0.06 * side, BODY_DROP - 0.02, -0.235)
		var palp_dir := Vector3(0.35 * side, 0.25, -0.9).normalized()
		var palp := _add(skeleton, "Palp.%s.1" % tag, head,
			Transform3D(along(palp_dir, Vector3.RIGHT), palp_at))
		var tip_dir := Vector3(0.1 * side, -0.7, -0.7).normalized()
		_add(skeleton, "Palp.%s.2" % tag, palp,
			Transform3D(along(tip_dir, Vector3.RIGHT), palp_at + palp_dir * 0.11))

	var belly_dir := Vector3(0.0, 0.18, 1.0).normalized()
	var belly_at := Vector3(0.0, BODY_DROP + 0.02, 0.14)
	var abdomen := _add(skeleton, "Abdomen", thorax,
		Transform3D(along(belly_dir, Vector3.RIGHT), belly_at))
	_add(skeleton, "Spinnerets", abdomen,
		Transform3D(along(belly_dir, Vector3.RIGHT), belly_at + belly_dir * 0.5))

	for pair in LEGS.size():
		var spec: Dictionary = LEGS[pair]
		for s in 2:
			var side := -1.0 if s == 0 else 1.0
			var tag := "Leg.%s%d" % [SIDES[s], pair + 1]
			var out := outward(pair, side)
			var normal := leg_plane_normal(out)
			var hip := hip_of(pair, side)
			var coxa_dir := (out + Vector3.DOWN * 0.15).normalized()
			var coxa := _add(skeleton, "%s.Coxa" % tag, thorax,
				Transform3D(along(coxa_dir, normal), hip))
			# At rest the leg stands the way a spider's does: the femur up and out
			# to a high knee, the tibia out and down, the tarsus to the ground.
			var knee_at := hip + coxa_dir * COXA
			var femur_dir := (out * 0.5 + Vector3.UP * 0.86).normalized()
			var femur := _add(skeleton, "%s.Femur" % tag, coxa,
				Transform3D(along(femur_dir, normal), knee_at))
			var tibia_at := knee_at + femur_dir * float(spec["femur"])
			var tibia_dir := (out * 0.62 + Vector3.DOWN * 0.78).normalized()
			var tibia := _add(skeleton, "%s.Tibia" % tag, femur,
				Transform3D(along(tibia_dir, normal), tibia_at))
			var tarsus_at := tibia_at + tibia_dir * float(spec["tibia"])
			var tarsus_dir := (out * 0.3 + Vector3.DOWN * 0.95).normalized()
			_add(skeleton, "%s.Tarsus" % tag, tibia,
				Transform3D(along(tarsus_dir, normal), tarsus_at))


## Which way leg [param pair] points on [param side] (-1 left, +1 right), flat.
static func outward(pair: int, side: float) -> Vector3:
	var yaw := deg_to_rad(float(LEGS[pair]["yaw"]))
	return Vector3(side * cos(yaw), 0.0, -sin(yaw)).normalized()


## The normal to the plane a leg bends in, which is every leg bone's local X — so
## that turning the leg about its hip and bending its knee never twists a segment.
static func leg_plane_normal(out: Vector3) -> Vector3:
	return out.cross(Vector3.UP).normalized()


## Where leg [param pair] on [param side] meets the body, at rest.
static func hip_of(pair: int, side: float) -> Vector3:
	return Vector3(HIP_OUT * side, BODY_DROP + HIP_DROP, float(LEGS[pair]["z"]))


## Where that leg's foot stands when the spider stands still on flat ground.
static func home_of(pair: int, side: float) -> Vector3:
	var foot := hip_of(pair, side) + outward(pair, side) * float(LEGS[pair]["reach"])
	return Vector3(foot.x, GROUND, foot.z)


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


static func _add(skeleton: Skeleton3D, bone_name: String, parent: int,
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


# --- the mesh ------------------------------------------------------------

## The stand-in body, one skinned mesh on [param skeleton]'s rest pose: a body
## surface coloured per vertex, and a second for the eyes, which want to shine.
static func build_mesh(skeleton: Skeleton3D, palette: Dictionary) -> ArrayMesh:
	var body := _begin()
	var eyes := _begin()
	var shell: Color = palette.get("body", Color(0.09, 0.075, 0.08))
	var legs: Color = palette.get("legs", Color(0.12, 0.1, 0.1))
	var band: Color = palette.get("band", Color(0.42, 0.33, 0.24))
	var mark: Color = palette.get("marking", Color(0.55, 0.43, 0.3))
	var gloss: Color = palette.get("eyes", Color(0.02, 0.02, 0.025))

	var thorax := skeleton.find_bone("Thorax")
	var head := skeleton.find_bone("Head")
	var abdomen := skeleton.find_bone("Abdomen")
	# Carapace, and the paler sternum under it.
	_ellipsoid(body, skeleton, thorax, Vector3(0.0, 0.025, -0.07), Vector3(0.13, 0.075, 0.17),
		func(n: Vector3, _p: Vector3) -> Color:
			return shell.lerp(mark, clampf(n.y, 0.0, 1.0) * clampf(0.35 - absf(n.x) * 1.4, 0.0, 1.0)))
	_ellipsoid(body, skeleton, thorax, Vector3(0.0, -0.025, -0.06), Vector3(0.1, 0.045, 0.13),
		func(_n: Vector3, _p: Vector3) -> Color: return shell.lerp(band, 0.35))
	# The raised eye mound, and eight eyes on it: the big front pair looking ahead.
	_ellipsoid(body, skeleton, head, Vector3(0.0, 0.03, -0.01), Vector3(0.075, 0.05, 0.06),
		func(_n: Vector3, _p: Vector3) -> Color: return shell)
	for side in [-1.0, 1.0]:
		for eye in [
				[Vector3(0.022, 0.05, -0.058), 0.019],
				[Vector3(0.05, 0.045, -0.045), 0.012],
				[Vector3(0.03, 0.078, -0.02), 0.011],
				[Vector3(0.058, 0.066, -0.005), 0.01]]:
			var at: Vector3 = eye[0]
			var size: float = eye[1]
			_ellipsoid(eyes, skeleton, head, Vector3(at.x * side, at.y, at.z),
				Vector3.ONE * size, func(_n: Vector3, _p: Vector3) -> Color: return gloss, 8, 5)

	# The abdomen, with the pale folium down its back that most house spiders wear.
	_ellipsoid(body, skeleton, abdomen, Vector3(0.0, 0.25, -0.01), Vector3(0.2, 0.27, 0.17),
		func(n: Vector3, p: Vector3) -> Color:
			var back := clampf(-n.z * 1.6 - 0.35, 0.0, 1.0)
			var along := p.y / 0.5
			var chevron := absf(fposmod(along * 4.0 + absf(p.x) * 9.0, 1.0) - 0.5) * 2.0
			var lit := back * clampf(1.0 - absf(p.x) * 7.0 + 0.25, 0.0, 1.0)
			return shell.lerp(mark, lit * smoothstep(0.25, 0.75, chevron)), 14, 9)
	_segment(body, skeleton, skeleton.find_bone("Spinnerets"), 0.05, 0.03, 0.012, shell, shell)

	for tag in SIDES:
		_segment(body, skeleton, skeleton.find_bone("Chelicera.%s" % tag), 0.1, 0.03, 0.022,
			shell, shell.lerp(band, 0.3))
		_segment(body, skeleton, skeleton.find_bone("Fang.%s" % tag), 0.055, 0.011, 0.002,
			Color(0.22, 0.08, 0.05), Color(0.1, 0.03, 0.02))
		_segment(body, skeleton, skeleton.find_bone("Palp.%s.1" % tag), 0.11, 0.016, 0.014,
			legs, band)
		_segment(body, skeleton, skeleton.find_bone("Palp.%s.2" % tag), 0.1, 0.014, 0.018,
			legs, band)

	for pair in LEGS.size():
		var spec: Dictionary = LEGS[pair]
		for tag in SIDES:
			var leg := "Leg.%s%d" % [tag, pair + 1]
			_segment(body, skeleton, skeleton.find_bone(leg + ".Coxa"), COXA, 0.026, 0.024,
				legs, legs)
			_segment(body, skeleton, skeleton.find_bone(leg + ".Femur"), spec["femur"],
				0.026, 0.021, legs, band)
			_segment(body, skeleton, skeleton.find_bone(leg + ".Tibia"), spec["tibia"],
				0.021, 0.016, legs, band)
			_segment(body, skeleton, skeleton.find_bone(leg + ".Tarsus"), spec["tarsus"],
				0.015, 0.006, legs, legs.lerp(band, 0.4))

	var mesh := ArrayMesh.new()
	body.commit(mesh)
	eyes.commit(mesh)
	mesh.surface_set_material(0, _shell_material())
	mesh.surface_set_material(1, _eye_material(palette.get("eyeshine", Color(0.9, 0.55, 0.2))))
	return mesh


static func _begin() -> SurfaceTool:
	var tool := SurfaceTool.new()
	# Before begin(), which refuses to change it after.
	tool.set_skin_weight_count(SurfaceTool.SKIN_4_WEIGHTS)
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	return tool


## One vertex, in [param bone]'s rest space, put into the skeleton's rest space
## and tied to that bone alone.
static func _vertex(tool: SurfaceTool, rest: Transform3D, bone: int, at: Vector3,
		normal: Vector3, colour: Color) -> void:
	tool.set_color(colour)
	tool.set_normal((rest.basis * normal).normalized())
	tool.set_bones(PackedInt32Array([bone, 0, 0, 0]))
	tool.set_weights(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
	tool.add_vertex(rest * at)


## An ellipsoid on [param bone], centred at [param centre] in its space.
## [param paint] colours each vertex from its unit normal and its position.
static func _ellipsoid(tool: SurfaceTool, skeleton: Skeleton3D, bone: int, centre: Vector3,
		radii: Vector3, paint: Callable, sides := 12, rings := 8) -> void:
	var rest := skeleton.get_bone_global_rest(bone)
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
			row.append([at, normal, paint.call(normal, at)])
		grid.append(row)
	# Clockwise seen from outside, which is Godot's front face.
	for r in rings:
		for s in sides:
			var a: Array = grid[r][s]
			var b: Array = grid[r + 1][s]
			var c: Array = grid[r + 1][s + 1]
			var d: Array = grid[r][s + 1]
			for corner in [a, c, b, a, d, c]:
				_vertex(tool, rest, bone, corner[0], corner[1], corner[2])


## A limb segment on [param bone]: a tapered tube from its root to [param length]
## along +Y, with a rounded cap at each end so the joints read as joints.
## [param tip] is the colour it shades to at the far joint — spiders' legs are
## banded, and the bands sit at the joints.
static func _segment(tool: SurfaceTool, skeleton: Skeleton3D, bone: int, length: float,
		root_radius: float, tip_radius: float, colour: Color, tip: Color, sides := 8) -> void:
	if bone < 0:
		return
	var rest := skeleton.get_bone_global_rest(bone)
	var rows: Array = []
	var cap := 3
	# Root cap, from the pole round to the equator.
	for r in cap:
		var angle := PI * 0.5 * float(cap - r) / float(cap)
		rows.append([-sin(angle) * root_radius, cos(angle) * root_radius, -sin(angle), 0.0])
	for r in 5:
		var t := float(r) / 4.0
		rows.append([length * t, lerpf(root_radius, tip_radius, t), 0.0, t])
	for r in range(1, cap + 1):
		var angle := PI * 0.5 * float(r) / float(cap)
		rows.append([length + sin(angle) * tip_radius, cos(angle) * tip_radius, sin(angle), 1.0])
	var grid: Array = []
	for row in rows:
		var y: float = row[0]
		var radius: float = row[1]
		var tilt: float = row[2]
		var t: float = row[3]
		var shade := colour.lerp(tip, smoothstep(0.72, 1.0, t))
		var ring: Array = []
		for s in sides + 1:
			var angle := TAU * float(s) / float(sides)
			var around := Vector3(cos(angle), 0.0, sin(angle))
			var normal := (around * sqrt(maxf(1.0 - tilt * tilt, 0.0)) + Vector3.UP * tilt).normalized()
			ring.append([Vector3(around.x * radius, y, around.z * radius), normal, shade])
		grid.append(ring)
	for r in grid.size() - 1:
		for s in sides:
			var a: Array = grid[r][s]
			var b: Array = grid[r + 1][s]
			var c: Array = grid[r + 1][s + 1]
			var d: Array = grid[r][s + 1]
			for corner in [a, c, b, a, d, c]:
				_vertex(tool, rest, bone, corner[0], corner[1], corner[2])


static func _shell_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.5
	material.metallic = 0.08
	# A little rim light for the hairs, so a dark spider against a dark wall still
	# has an outline.
	material.rim_enabled = true
	material.rim = 0.35
	material.rim_tint = 0.6
	return material


static func _eye_material(shine: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.02, 0.02, 0.025)
	material.roughness = 0.05
	material.metallic = 0.3
	# Eyeshine, faint: enough to find the head from across a room.
	material.emission_enabled = true
	material.emission = shine
	material.emission_energy_multiplier = 0.35
	return material
