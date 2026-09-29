class_name SpiderRig
extends RefCounted

## Builds the spider's skeleton, and the skinned meshes that ride it, out of the
## parts in [RigKit].
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
	var root := RigKit.add_bone(skeleton, "Root", -1, Transform3D.IDENTITY)
	var thorax := RigKit.add_bone(skeleton, "Thorax", root,
		Transform3D(Basis.IDENTITY, Vector3(0.0, BODY_DROP, -0.02)))
	var head := RigKit.add_bone(skeleton, "Head", thorax,
		Transform3D(Basis.IDENTITY, Vector3(0.0, BODY_DROP + 0.03, -0.20)))

	for s in 2:
		var side := -1.0 if s == 0 else 1.0
		var tag: String = SIDES[s]
		# Chelicerae hang down and forward from under the eyes, fangs folded in.
		var jaw_at := Vector3(0.034 * side, BODY_DROP - 0.005, -0.25)
		var jaw_dir := Vector3(0.0, -0.75, -0.66).normalized()
		var jaw := RigKit.add_bone(skeleton, "Chelicera.%s" % tag, head,
			Transform3D(RigKit.along(jaw_dir, Vector3.RIGHT), jaw_at))
		var fang_dir := Vector3(-0.55 * side, -0.55, -0.15).normalized()
		RigKit.add_bone(skeleton, "Fang.%s" % tag, jaw,
			Transform3D(RigKit.along(fang_dir, Vector3.RIGHT), jaw_at + jaw_dir * 0.1))
		# Pedipalps: out and forward, then down to the ground ahead of the jaws.
		var palp_at := Vector3(0.06 * side, BODY_DROP - 0.02, -0.235)
		var palp_dir := Vector3(0.35 * side, 0.25, -0.9).normalized()
		var palp := RigKit.add_bone(skeleton, "Palp.%s.1" % tag, head,
			Transform3D(RigKit.along(palp_dir, Vector3.RIGHT), palp_at))
		var tip_dir := Vector3(0.1 * side, -0.7, -0.7).normalized()
		RigKit.add_bone(skeleton, "Palp.%s.2" % tag, palp,
			Transform3D(RigKit.along(tip_dir, Vector3.RIGHT), palp_at + palp_dir * 0.11))

	var belly_dir := Vector3(0.0, 0.18, 1.0).normalized()
	var belly_at := Vector3(0.0, BODY_DROP + 0.02, 0.14)
	var abdomen := RigKit.add_bone(skeleton, "Abdomen", thorax,
		Transform3D(RigKit.along(belly_dir, Vector3.RIGHT), belly_at))
	RigKit.add_bone(skeleton, "Spinnerets", abdomen,
		Transform3D(RigKit.along(belly_dir, Vector3.RIGHT), belly_at + belly_dir * 0.5))

	for pair in LEGS.size():
		var spec: Dictionary = LEGS[pair]
		for s in 2:
			var side := -1.0 if s == 0 else 1.0
			var tag := "Leg.%s%d" % [SIDES[s], pair + 1]
			var out := outward(pair, side)
			var normal := leg_plane_normal(out)
			var hip := hip_of(pair, side)
			var coxa_dir := (out + Vector3.DOWN * 0.15).normalized()
			var coxa := RigKit.add_bone(skeleton, "%s.Coxa" % tag, thorax,
				Transform3D(RigKit.along(coxa_dir, normal), hip))
			# At rest the leg stands the way a spider's does: the femur up and out
			# to a high knee, the tibia out and down, the tarsus to the ground.
			var knee_at := hip + coxa_dir * COXA
			var femur_dir := (out * 0.5 + Vector3.UP * 0.86).normalized()
			var femur := RigKit.add_bone(skeleton, "%s.Femur" % tag, coxa,
				Transform3D(RigKit.along(femur_dir, normal), knee_at))
			var tibia_at := knee_at + femur_dir * float(spec["femur"])
			var tibia_dir := (out * 0.62 + Vector3.DOWN * 0.78).normalized()
			var tibia := RigKit.add_bone(skeleton, "%s.Tibia" % tag, femur,
				Transform3D(RigKit.along(tibia_dir, normal), tibia_at))
			var tarsus_at := tibia_at + tibia_dir * float(spec["tibia"])
			var tarsus_dir := (out * 0.3 + Vector3.DOWN * 0.95).normalized()
			RigKit.add_bone(skeleton, "%s.Tarsus" % tag, tibia,
				Transform3D(RigKit.along(tarsus_dir, normal), tarsus_at))


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


# --- the mesh ------------------------------------------------------------

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
	var body := RigKit.begin()
	var eyes := RigKit.begin()
	var shell: Color = palette.get("body", Color(0.09, 0.075, 0.08))
	var legs: Color = palette.get("legs", Color(0.12, 0.1, 0.1))
	var band: Color = palette.get("band", Color(0.42, 0.33, 0.24))
	var mark: Color = palette.get("marking", Color(0.55, 0.43, 0.3))
	var gloss: Color = palette.get("eyes", Color(0.02, 0.02, 0.025))
	var rounded := RigKit.Cut.new()

	var thorax := skeleton.find_bone("Thorax")
	var head := skeleton.find_bone("Head")
	var abdomen := skeleton.find_bone("Abdomen")
	# Carapace, and the paler sternum under it.
	RigKit.ellipsoid(body, skeleton, thorax, Vector3(0.0, 0.025, -0.07),
		Vector3(0.13, 0.075, 0.17), func(n: Vector3, _p: Vector3) -> Color:
			return shell.lerp(mark, clampf(n.y, 0.0, 1.0) * clampf(0.35 - absf(n.x) * 1.4, 0.0, 1.0)))
	RigKit.ellipsoid(body, skeleton, thorax, Vector3(0.0, -0.025, -0.06),
		Vector3(0.1, 0.045, 0.13), RigKit.plain(shell.lerp(band, 0.35)))
	# The raised eye mound, and eight eyes on it.
	RigKit.ellipsoid(body, skeleton, head, Vector3(0.0, 0.03, -0.01),
		Vector3(0.075, 0.05, 0.06), RigKit.plain(shell))
	_eight_eyes(eyes, skeleton, head, RigKit.plain(gloss), 8, 5, false)

	# The abdomen, with the pale folium down its back that most house spiders wear.
	RigKit.ellipsoid(body, skeleton, abdomen, Vector3(0.0, 0.25, -0.01),
		Vector3(0.2, 0.27, 0.17), func(n: Vector3, p: Vector3) -> Color:
			var back := clampf(-n.z * 1.6 - 0.35, 0.0, 1.0)
			var along := p.y / 0.5
			var chevron := absf(fposmod(along * 4.0 + absf(p.x) * 9.0, 1.0) - 0.5) * 2.0
			var lit := back * clampf(1.0 - absf(p.x) * 7.0 + 0.25, 0.0, 1.0)
			return shell.lerp(mark, lit * smoothstep(0.25, 0.75, chevron)), 14, 9)
	RigKit.segment(body, skeleton, skeleton.find_bone("Spinnerets"), 0.05, 0.03, 0.012,
		RigKit.plain(shell), rounded)
	_mouthparts(body, skeleton, rounded, rounded, shell, legs, band)
	_eight_legs(body, skeleton, rounded, _leg_widths(), _leg_colours(legs, band))
	return RigKit.commit([body, eyes], [RigKit.shell_material(),
		RigKit.eye_material(palette.get("eyeshine", Color(0.9, 0.55, 0.2)))])


## The same parts as the detailed look, cut into flat faces: four-sided legs that
## come to a point at every joint, blobs of a few dozen faces, and a colour to each
## face. The markings survive as whole faces picked out in the paler colour.
static func _low_poly(skeleton: Skeleton3D, palette: Dictionary) -> ArrayMesh:
	var body := RigKit.begin()
	var eyes := RigKit.begin()
	var shell: Color = palette.get("body", Color(0.09, 0.075, 0.08))
	var legs: Color = palette.get("legs", Color(0.12, 0.1, 0.1))
	var band: Color = palette.get("band", Color(0.42, 0.33, 0.24))
	var mark: Color = palette.get("marking", Color(0.55, 0.43, 0.3))
	var gloss: Color = palette.get("eyes", Color(0.02, 0.02, 0.025))
	# Square legs with a face on top, and three-sided fangs.
	var facets := RigKit.Cut.new(4, 1, 1, true, PI * 0.25)
	var blade := RigKit.Cut.new(3, 1, 1, true)

	var thorax := skeleton.find_bone("Thorax")
	var head := skeleton.find_bone("Head")
	var abdomen := skeleton.find_bone("Abdomen")
	# Carapace with a pale ridge along the top, and the sternum under it.
	RigKit.ellipsoid(body, skeleton, thorax, Vector3(0.0, 0.025, -0.07),
		Vector3(0.13, 0.075, 0.17), func(n: Vector3, _p: Vector3) -> Color:
			return shell.lerp(mark, 0.55) if n.y > 0.6 and absf(n.x) < 0.3 else shell, 8, 4, true)
	RigKit.ellipsoid(body, skeleton, thorax, Vector3(0.0, -0.025, -0.06),
		Vector3(0.1, 0.045, 0.13), RigKit.plain(shell.lerp(band, 0.35)), 6, 3, true)
	RigKit.ellipsoid(body, skeleton, head, Vector3(0.0, 0.03, -0.01),
		Vector3(0.075, 0.05, 0.06), RigKit.plain(shell), 6, 3, true)
	# Every eye an octahedron.
	_eight_eyes(eyes, skeleton, head, RigKit.plain(gloss), 4, 2, true)

	# The folium as a leaf of pale faces down the back: the middle row of faces
	# the length of it, and the rows either side where it is widest.
	RigKit.ellipsoid(body, skeleton, abdomen, Vector3(0.0, 0.25, -0.01),
		Vector3(0.2, 0.27, 0.17), func(n: Vector3, p: Vector3) -> Color:
			var across := Vector2(n.x, n.z).length()
			var back := -n.z / maxf(across, 0.0001)
			var lat := asin(clampf((p.y - 0.25) / 0.27, -1.0, 1.0))
			var ring := int(floorf((lat / PI + 0.5) * 6.0))
			var middle := back > 0.95 and ring >= 1 and ring <= 4
			var flank := back > 0.7 and ring >= 2 and ring <= 3
			return shell.lerp(mark, 0.8) if middle or flank else shell, 10, 6, true)
	RigKit.segment(body, skeleton, skeleton.find_bone("Spinnerets"), 0.05, 0.03, 0.012,
		RigKit.plain(shell), facets)
	_mouthparts(body, skeleton, facets, blade, shell, legs, band)
	_eight_legs(body, skeleton, facets, _leg_widths(), _leg_colours(legs, band))
	return RigKit.commit([body, eyes], [RigKit.shell_material(0.8, 0.0, 0.2),
		RigKit.eye_material(palette.get("eyeshine", Color(0.9, 0.55, 0.2)))])


## As little as still reads as a spider: two smooth blobs, eight thin legs bent at
## round joints, two pale eyes, and one colour for everything else. No jaws, no
## palps, no markings.
static func _minimal(skeleton: Skeleton3D, palette: Dictionary) -> ArrayMesh:
	var body := RigKit.begin()
	var eyes := RigKit.begin()
	var shell: Color = palette.get("body", Color(0.09, 0.075, 0.08))
	# The eyes are the one thing not in the body colour: pale, so the face has a front.
	var pale := Color(0.92, 0.9, 0.84)
	# Round all the way along, and a round end at every joint, so each leg reads
	# as one bent rod rather than four pieces.
	var rod := RigKit.Cut.new(8, 1, 3)

	var thorax := skeleton.find_bone("Thorax")
	var abdomen := skeleton.find_bone("Abdomen")
	var front := Vector3(0.0, 0.03, -0.08)
	var front_size := Vector3(0.12, 0.08, 0.16)
	RigKit.ellipsoid(body, skeleton, thorax, front, front_size, RigKit.plain(shell), 16, 10)
	RigKit.ellipsoid(body, skeleton, abdomen, Vector3(0.0, 0.24, -0.01),
		Vector3(0.19, 0.25, 0.18), RigKit.plain(shell), 18, 12)
	var thin := [0.014, 0.014]
	var one := [shell, shell]
	_eight_legs(body, skeleton, rod, [thin, thin, thin, [0.014, 0.011]], [one, one, one, one])
	# Two eyes, set into the front of the carapace. On the thorax rather than the
	# head, because that is the bone the carapace they sit in hangs off.
	for side in [-1.0, 1.0]:
		var toward := Vector3(0.34 * side, 0.52, -0.78).normalized()
		RigKit.ellipsoid(eyes, skeleton, thorax, front + toward * front_size,
			Vector3.ONE * 0.022, RigKit.plain(pale), 10, 6)
	return RigKit.commit([body, eyes], [RigKit.matte_material(shell),
		RigKit.eye_material(palette.get("eyeshine", Color(0.9, 0.55, 0.2)), pale, 0.2)])


# --- the parts every look is built from -----------------------------------

## Jaws, fangs and palps, both sides. [param fang_cut] cuts the fangs, which are
## thin enough to want fewer sides than anything else.
static func _mouthparts(tool: SurfaceTool, skeleton: Skeleton3D, cut: RigKit.Cut,
		fang_cut: RigKit.Cut, shell: Color, legs: Color, band: Color) -> void:
	for tag in SIDES:
		RigKit.segment(tool, skeleton, skeleton.find_bone("Chelicera.%s" % tag), 0.1, 0.03,
			0.022, RigKit.banded(shell, shell.lerp(band, 0.3), 0.1), cut)
		RigKit.segment(tool, skeleton, skeleton.find_bone("Fang.%s" % tag), 0.055, 0.011,
			0.002, RigKit.banded(Color(0.22, 0.08, 0.05), Color(0.1, 0.03, 0.02), 0.055), fang_cut)
		RigKit.segment(tool, skeleton, skeleton.find_bone("Palp.%s.1" % tag), 0.11, 0.016,
			0.014, RigKit.banded(legs, band, 0.11), cut)
		RigKit.segment(tool, skeleton, skeleton.find_bone("Palp.%s.2" % tag), 0.1, 0.014,
			0.018, RigKit.banded(legs, band, 0.1), cut)


## Eight legs of four segments. [param widths] is each segment's radius at its root
## and its tip, and [param colours] its colour and the colour it shades to at the
## far joint, both in [constant LEG_PARTS] order.
static func _eight_legs(tool: SurfaceTool, skeleton: Skeleton3D, cut: RigKit.Cut,
		widths: Array, colours: Array) -> void:
	for pair in LEGS.size():
		var spec: Dictionary = LEGS[pair]
		var lengths := [COXA, float(spec["femur"]), float(spec["tibia"]), float(spec["tarsus"])]
		for tag in SIDES:
			for part in LEG_PARTS.size():
				var bone := skeleton.find_bone("Leg.%s%d.%s" % [tag, pair + 1, LEG_PARTS[part]])
				var width: Array = widths[part]
				var colour: Array = colours[part]
				var length: float = lengths[part]
				RigKit.segment(tool, skeleton, bone, length, width[0], width[1],
					RigKit.banded(colour[0], colour[1], length), cut)


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
			RigKit.ellipsoid(tool, skeleton, head, Vector3(at.x * side, at.y, at.z),
				Vector3.ONE * size, paint, sides, rings, flat)

