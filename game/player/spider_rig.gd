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
## drive it unchanged. The meshes built here, one per [enum Look], are stand-ins
## for that model, not the thing the animation is written against — and that all
## of them wear the one skeleton is the proof that a model would too.
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

## The ways the spider can be drawn. Each is one skinned mesh on the same bones,
## so the gait drives them all alike and never knows which it has.
enum Look {
	DETAILED,  ## banded legs, a marked back, jaws, palps and eight eyes
	LOW_POLY,  ## the same parts cut into flat faces, a colour to each face
	MINIMAL,   ## two smooth blobs on eight thin legs, two eyes, one colour
}

## What each look is called on screen, in [enum Look] order.
const LOOK_NAMES := ["detailed", "low poly", "minimal"]

## A leg's four segments, hip to foot.
const LEG_PARTS := ["Coxa", "Femur", "Tibia", "Tarsus"]

## The eyes on one side of the head: where each sits on the head bone, and how
## big it is. The big front pair looks ahead.
const EYES := [
	[Vector3(0.022, 0.05, -0.058), 0.019],
	[Vector3(0.05, 0.045, -0.045), 0.012],
	[Vector3(0.03, 0.078, -0.02), 0.011],
	[Vector3(0.058, 0.066, -0.005), 0.01],
]


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


## Dresses [param skeleton] in [param look]: one mesh skinned to its rest pose,
## with a surface for the body and a second for the eyes, which want a material of
## their own. [param palette] holds the colours, by the names [SpiderBody] uses.
static func build_mesh(skeleton: Skeleton3D, palette: Dictionary,
		look := Look.DETAILED) -> ArrayMesh:
	match look:
		Look.LOW_POLY:
			return _low_poly(skeleton, palette)
		Look.MINIMAL:
			return _minimal(skeleton, palette)
	return _detailed(skeleton, palette)


## Banded legs, a marked carapace and abdomen, jaws, palps and eight eyes, all
## smooth-shaded.
static func _detailed(skeleton: Skeleton3D, palette: Dictionary) -> ArrayMesh:
	var body := _begin()
	var eyes := _begin()
	var shell: Color = palette.get("body", Color(0.09, 0.075, 0.08))
	var legs: Color = palette.get("legs", Color(0.12, 0.1, 0.1))
	var band: Color = palette.get("band", Color(0.42, 0.33, 0.24))
	var mark: Color = palette.get("marking", Color(0.55, 0.43, 0.3))
	var gloss: Color = palette.get("eyes", Color(0.02, 0.02, 0.025))
	var rounded := Cut.new()

	var thorax := skeleton.find_bone("Thorax")
	var head := skeleton.find_bone("Head")
	var abdomen := skeleton.find_bone("Abdomen")
	# Carapace, and the paler sternum under it.
	_ellipsoid(body, skeleton, thorax, Vector3(0.0, 0.025, -0.07), Vector3(0.13, 0.075, 0.17),
		func(n: Vector3, _p: Vector3) -> Color:
			return shell.lerp(mark, clampf(n.y, 0.0, 1.0) * clampf(0.35 - absf(n.x) * 1.4, 0.0, 1.0)))
	_ellipsoid(body, skeleton, thorax, Vector3(0.0, -0.025, -0.06), Vector3(0.1, 0.045, 0.13),
		_plain(shell.lerp(band, 0.35)))
	# The raised eye mound, and eight eyes on it.
	_ellipsoid(body, skeleton, head, Vector3(0.0, 0.03, -0.01), Vector3(0.075, 0.05, 0.06),
		_plain(shell))
	_eight_eyes(eyes, skeleton, head, _plain(gloss), 8, 5, false)

	# The abdomen, with the pale folium down its back that most house spiders wear.
	_ellipsoid(body, skeleton, abdomen, Vector3(0.0, 0.25, -0.01), Vector3(0.2, 0.27, 0.17),
		func(n: Vector3, p: Vector3) -> Color:
			var back := clampf(-n.z * 1.6 - 0.35, 0.0, 1.0)
			var along := p.y / 0.5
			var chevron := absf(fposmod(along * 4.0 + absf(p.x) * 9.0, 1.0) - 0.5) * 2.0
			var lit := back * clampf(1.0 - absf(p.x) * 7.0 + 0.25, 0.0, 1.0)
			return shell.lerp(mark, lit * smoothstep(0.25, 0.75, chevron)), 14, 9)
	_segment(body, skeleton, skeleton.find_bone("Spinnerets"), 0.05, 0.03, 0.012, _plain(shell),
		rounded)
	_mouthparts(body, skeleton, rounded, rounded, shell, legs, band)
	_eight_legs(body, skeleton, rounded, _leg_widths(), _leg_colours(legs, band))
	return _commit(body, eyes, _shell_material(), _eye_material(
		palette.get("eyeshine", Color(0.9, 0.55, 0.2))))


## The same parts as the detailed look, cut into flat faces: four-sided legs that
## come to a point at every joint, blobs of a few dozen faces, and a colour to each
## face. The markings survive as whole faces picked out in the paler colour.
static func _low_poly(skeleton: Skeleton3D, palette: Dictionary) -> ArrayMesh:
	var body := _begin()
	var eyes := _begin()
	var shell: Color = palette.get("body", Color(0.09, 0.075, 0.08))
	var legs: Color = palette.get("legs", Color(0.12, 0.1, 0.1))
	var band: Color = palette.get("band", Color(0.42, 0.33, 0.24))
	var mark: Color = palette.get("marking", Color(0.55, 0.43, 0.3))
	var gloss: Color = palette.get("eyes", Color(0.02, 0.02, 0.025))
	# Square legs with a face on top, and three-sided fangs.
	var facets := Cut.new(4, 1, 1, true, PI * 0.25)
	var blade := Cut.new(3, 1, 1, true)

	var thorax := skeleton.find_bone("Thorax")
	var head := skeleton.find_bone("Head")
	var abdomen := skeleton.find_bone("Abdomen")
	# Carapace with a pale ridge along the top, and the sternum under it.
	_ellipsoid(body, skeleton, thorax, Vector3(0.0, 0.025, -0.07), Vector3(0.13, 0.075, 0.17),
		func(n: Vector3, _p: Vector3) -> Color:
			return shell.lerp(mark, 0.55) if n.y > 0.6 and absf(n.x) < 0.3 else shell, 8, 4, true)
	_ellipsoid(body, skeleton, thorax, Vector3(0.0, -0.025, -0.06), Vector3(0.1, 0.045, 0.13),
		_plain(shell.lerp(band, 0.35)), 6, 3, true)
	_ellipsoid(body, skeleton, head, Vector3(0.0, 0.03, -0.01), Vector3(0.075, 0.05, 0.06),
		_plain(shell), 6, 3, true)
	# Every eye an octahedron.
	_eight_eyes(eyes, skeleton, head, _plain(gloss), 4, 2, true)

	# The folium as a leaf of pale faces down the back: the middle row of faces
	# the length of it, and the rows either side where it is widest.
	_ellipsoid(body, skeleton, abdomen, Vector3(0.0, 0.25, -0.01), Vector3(0.2, 0.27, 0.17),
		func(n: Vector3, p: Vector3) -> Color:
			var across := Vector2(n.x, n.z).length()
			var back := -n.z / maxf(across, 0.0001)
			var lat := asin(clampf((p.y - 0.25) / 0.27, -1.0, 1.0))
			var ring := int(floorf((lat / PI + 0.5) * 6.0))
			var middle := back > 0.95 and ring >= 1 and ring <= 4
			var flank := back > 0.7 and ring >= 2 and ring <= 3
			return shell.lerp(mark, 0.8) if middle or flank else shell, 10, 6, true)
	_segment(body, skeleton, skeleton.find_bone("Spinnerets"), 0.05, 0.03, 0.012, _plain(shell),
		facets)
	_mouthparts(body, skeleton, facets, blade, shell, legs, band)
	_eight_legs(body, skeleton, facets, _leg_widths(), _leg_colours(legs, band))
	return _commit(body, eyes, _shell_material(0.8, 0.0, 0.2), _eye_material(
		palette.get("eyeshine", Color(0.9, 0.55, 0.2))))


## As little as still reads as a spider: two smooth blobs, eight thin legs bent at
## round joints, two pale eyes, and one colour for everything else. No jaws, no
## palps, no markings.
static func _minimal(skeleton: Skeleton3D, palette: Dictionary) -> ArrayMesh:
	var body := _begin()
	var eyes := _begin()
	var shell: Color = palette.get("body", Color(0.09, 0.075, 0.08))
	# The eyes are the one thing not in the body colour: pale, so the face has a front.
	var pale := Color(0.92, 0.9, 0.84)
	# Round all the way along, and a round end at every joint, so each leg reads
	# as one bent rod rather than four pieces.
	var rod := Cut.new(8, 1, 3)

	var thorax := skeleton.find_bone("Thorax")
	var abdomen := skeleton.find_bone("Abdomen")
	var front := Vector3(0.0, 0.03, -0.08)
	var front_size := Vector3(0.12, 0.08, 0.16)
	_ellipsoid(body, skeleton, thorax, front, front_size, _plain(shell), 16, 10)
	_ellipsoid(body, skeleton, abdomen, Vector3(0.0, 0.24, -0.01), Vector3(0.19, 0.25, 0.18),
		_plain(shell), 18, 12)
	var thin := [0.014, 0.014]
	var one := [shell, shell]
	_eight_legs(body, skeleton, rod, [thin, thin, thin, [0.014, 0.011]], [one, one, one, one])
	# Two eyes, set into the front of the carapace. On the thorax rather than the
	# head, because that is the bone the carapace they sit in hangs off.
	for side in [-1.0, 1.0]:
		var toward := Vector3(0.34 * side, 0.52, -0.78).normalized()
		_ellipsoid(eyes, skeleton, thorax, front + toward * front_size, Vector3.ONE * 0.022,
			_plain(pale), 10, 6)
	return _commit(body, eyes, _matte_material(shell), _eye_material(
		palette.get("eyeshine", Color(0.9, 0.55, 0.2)), pale, 0.2))


# --- the parts every look is built from -----------------------------------

## Jaws, fangs and palps, both sides. [param fang_cut] cuts the fangs, which are
## thin enough to want fewer sides than anything else.
static func _mouthparts(tool: SurfaceTool, skeleton: Skeleton3D, cut: Cut, fang_cut: Cut,
		shell: Color, legs: Color, band: Color) -> void:
	for tag in SIDES:
		_segment(tool, skeleton, skeleton.find_bone("Chelicera.%s" % tag), 0.1, 0.03, 0.022,
			_banded(shell, shell.lerp(band, 0.3), 0.1), cut)
		_segment(tool, skeleton, skeleton.find_bone("Fang.%s" % tag), 0.055, 0.011, 0.002,
			_banded(Color(0.22, 0.08, 0.05), Color(0.1, 0.03, 0.02), 0.055), fang_cut)
		_segment(tool, skeleton, skeleton.find_bone("Palp.%s.1" % tag), 0.11, 0.016, 0.014,
			_banded(legs, band, 0.11), cut)
		_segment(tool, skeleton, skeleton.find_bone("Palp.%s.2" % tag), 0.1, 0.014, 0.018,
			_banded(legs, band, 0.1), cut)


## Eight legs of four segments. [param widths] is each segment's radius at its root
## and its tip, and [param colours] its colour and the colour it shades to at the
## far joint, both in [constant LEG_PARTS] order.
static func _eight_legs(tool: SurfaceTool, skeleton: Skeleton3D, cut: Cut, widths: Array,
		colours: Array) -> void:
	for pair in LEGS.size():
		var spec: Dictionary = LEGS[pair]
		var lengths := [COXA, float(spec["femur"]), float(spec["tibia"]), float(spec["tarsus"])]
		for tag in SIDES:
			for part in LEG_PARTS.size():
				var bone := skeleton.find_bone("Leg.%s%d.%s" % [tag, pair + 1, LEG_PARTS[part]])
				var width: Array = widths[part]
				var colour: Array = colours[part]
				var length: float = lengths[part]
				_segment(tool, skeleton, bone, length, width[0], width[1],
					_banded(colour[0], colour[1], length), cut)


## How thick each segment of a leg is, root and tip: thick at the hip, fine at
## the foot. Pairs of floats rather than a Vector2, which would round them.
static func _leg_widths() -> Array:
	return [[0.026, 0.024], [0.026, 0.021], [0.021, 0.016], [0.015, 0.006]]


## Each segment's colour and the band it ends in. The coxa has none, and the
## tarsus only a faint one: the bands sit at the knee and the ankle.
static func _leg_colours(legs: Color, band: Color) -> Array:
	return [[legs, legs], [legs, band], [legs, band], [legs, legs.lerp(band, 0.4)]]


## Eight eyes on [param head], in [constant EYES] and its mirror image.
static func _eight_eyes(tool: SurfaceTool, skeleton: Skeleton3D, head: int, paint: Callable,
		sides: int, rings: int, flat: bool) -> void:
	for side in [-1.0, 1.0]:
		for eye in EYES:
			var at: Vector3 = eye[0]
			var size: float = eye[1]
			_ellipsoid(tool, skeleton, head, Vector3(at.x * side, at.y, at.z),
				Vector3.ONE * size, paint, sides, rings, flat)


## Paints everything [param colour].
static func _plain(colour: Color) -> Callable:
	return func(_n: Vector3, _p: Vector3) -> Color: return colour


## Paints a segment [param length] long [param colour], shading to [param tip]
## over its last quarter — spiders' legs are banded, and the bands sit at the
## joints.
static func _banded(colour: Color, tip: Color, length: float) -> Callable:
	return func(_n: Vector3, p: Vector3) -> Color:
		return colour.lerp(tip, smoothstep(0.72, 1.0, clampf(p.y / length, 0.0, 1.0)))


static func _begin() -> SurfaceTool:
	var tool := SurfaceTool.new()
	# Before begin(), which refuses to change it after.
	tool.set_skin_weight_count(SurfaceTool.SKIN_4_WEIGHTS)
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	return tool


static func _commit(body: SurfaceTool, eyes: SurfaceTool, body_material: Material,
		eye_material: Material) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	body.commit(mesh)
	eyes.commit(mesh)
	mesh.surface_set_material(0, body_material)
	mesh.surface_set_material(1, eye_material)
	return mesh


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
## [param paint] colours it from the unit normal and the position, both in the
## bone's space; with [param flat], once per face rather than once per vertex.
static func _ellipsoid(tool: SurfaceTool, skeleton: Skeleton3D, bone: int, centre: Vector3,
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
	_sew(tool, skeleton.get_bone_global_rest(bone), bone, grid, paint, flat)


## A limb segment on [param bone]: a tapered tube from its root to [param length]
## along +Y, closed at each end the way [param cut] says, so the joints read as
## joints. [param paint] colours it, as for [method _ellipsoid].
static func _segment(tool: SurfaceTool, skeleton: Skeleton3D, bone: int, length: float,
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
	_sew(tool, skeleton.get_bone_global_rest(bone), bone, grid, paint, cut.flat)


## Sews rings of vertices — each one [position, normal, colour], in the bone's
## space — into triangles on [param bone].
##
## With [param flat], every face gets one normal and one colour of its own, which
## is what makes low poly read as low poly rather than as a sphere drawn badly:
## the normal is the face's own, and the colour is [param paint]'s at its middle,
## a shade lighter or darker from face to face the way a faceted model is painted.
static func _sew(tool: SurfaceTool, rest: Transform3D, bone: int, grid: Array,
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
						_vertex(tool, rest, bone, corner[0], corner[1], corner[2])
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
				var shade := 0.94 + 0.12 * _noise(middle)
				colour = Color(colour.r * shade, colour.g * shade, colour.b * shade, colour.a)
				for corner in face:
					_vertex(tool, rest, bone, corner[0], normal, colour)


## A number from 0 to 1 that is the same every time for the same point.
static func _noise(at: Vector3) -> float:
	return fposmod(sin(at.dot(Vector3(12.9898, 78.233, 37.719))) * 43758.5453, 1.0)


static func _shell_material(roughness := 0.5, metallic := 0.08, rim := 0.35) -> StandardMaterial3D:
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
static func _matte_material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.8
	material.rim_enabled = true
	material.rim = 0.3
	material.rim_tint = 0.5
	return material


static func _eye_material(shine: Color, albedo := Color(0.02, 0.02, 0.025),
		glow := 0.35) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.roughness = 0.05
	material.metallic = 0.3
	# Eyeshine, faint: enough to find the head from across a room.
	material.emission_enabled = true
	material.emission = shine
	material.emission_energy_multiplier = glow
	return material
