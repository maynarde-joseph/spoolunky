class_name InsectBody
extends CreatureBody

## An insect: a head, a thorax and an abdomen, six legs, two feelers, and no wings,
## two or four. Everything that makes one species of it look like itself is a
## number here, so a new insect is a .tres of this and nothing more.
##
## It is drawn the minimal way: smooth parts, thin legs of one width with round
## joints, and a few flat colours. Every length is in body radii, the creature's
## own size, and every angle in degrees. Forward is -Z and up is +Y.
##
## The body is laid out so that from the front of the head to the tip of the
## abdomen it is centred on the creature's middle, which is the middle of its
## hitbox — what you can see is what you can hit.

const SIDES := ["L", "R"]
const LEG_PARTS := ["Femur", "Tibia", "Tarsus"]


@export_group("Colours")

## The head, the thorax, and the feelers and mouthparts on them.
@export var colour := Color(0.18, 0.17, 0.2)
@export var abdomen_colour := Color(0.2, 0.19, 0.22)
## The bands round the abdomen, and its tip, when [member stripes] asks for any.
@export var stripe_colour := Color(0.06, 0.05, 0.05)
@export var leg_colour := Color(0.12, 0.11, 0.13)
@export var eye_colour := Color(0.5, 0.1, 0.07)
## A wing's membrane, and the rim round its edge. Clear wings are mostly alpha.
@export var wing_colour := Color(0.82, 0.86, 0.92, 0.28)
@export var wing_rim := Color(0.3, 0.3, 0.34, 0.6)


@export_group("Body")

## Each part's radii: across, up, and along the body.
@export var head := Vector3(0.36, 0.34, 0.3)
@export var thorax := Vector3(0.42, 0.4, 0.46)
@export var abdomen := Vector3(0.44, 0.34, 0.6)
## How far the abdomen hangs below straight back, in degrees.
@export var abdomen_droop := 8.0
## How much the abdomen narrows toward its tip: 0 an egg, 1 a point.
@export_range(0.0, 1.0) var abdomen_point := 0.25
## How many dark bands go round the abdomen. None for most things.
@export var stripes := 0
## A thin stalk this long between the thorax and the abdomen, the way an ant or a
## wasp is built. Zero for none.
@export var waist := 0.0
@export var waist_thickness := 0.08
## A sting this long at the tip of the abdomen. Zero for none.
@export var sting := 0.0
## Each compound eye's radii: across, up and along.
@export var eyes := Vector3(0.2, 0.24, 0.2)


@export_group("Legs")

## Femur, tibia and tarsus of the middle pair.
@export var leg := Vector3(0.5, 0.55, 0.35)
## How long the front, middle and hind pairs are, against the middle pair.
@export var leg_pairs := Vector3(0.9, 1.0, 1.1)
@export var leg_thickness := 0.045
## Which way each pair points, front to back: degrees forward of straight out.
@export var leg_splay := Vector3(40.0, 0.0, -35.0)


@export_group("Head")

## How long each feeler is, and how sharply it bends at its elbow — an ant's are
## at right angles.
@export var antenna := 0.3
@export var antenna_elbow := 25.0
## A knob this big on the end of each feeler. Zero for none.
@export var antenna_club := 0.0
@export var antenna_thickness := 0.03
## A mouth tube this long. Zero for none.
@export var proboscis := 0.28
@export var proboscis_thickness := 0.035
## How far below straight ahead it points, in degrees.
@export var proboscis_angle := 80.0
## A pad this big on the end of it, which is what a fly mops up with. Zero for none.
@export var proboscis_pad := 0.08
## A pair of jaws, each this long. Zero for none.
@export var mandibles := 0.0


@export_group("Wings")

## How many pairs: none, one or two.
@export_range(0, 2) var wing_pairs := 1
## Length and widest width of a forewing, and of a hindwing.
@export var wing := Vector2(1.3, 0.55)
@export var hind_wing := Vector2(0.9, 0.4)
## Where along its length a wing is widest, from the root (0) to the tip (1): a
## forewing, and a hindwing.
@export_range(0.05, 0.95) var wing_broadest := 0.45
@export_range(0.05, 0.95) var hind_wing_broadest := 0.45
## How far back each pair is swept when spread, fore and hind: how much it leans
## toward the tail for every body radius it reaches out. Negative sweeps forward.
@export var wing_sweep := Vector2(0.22, 0.45)
## Held up together over the back at rest, the way a butterfly holds them, rather
## than folded flat along it.
@export var wings_up := false
## Beats a second, as drawn — a real fly's are a blur, and so are these — how far
## each beat swings, and the angle above flat it swings about, in degrees.
@export var flap_rate := 15.0
@export var flap_swing := 55.0
@export var flap_centre := 10.0


@export_group("Walking")

## How far the body goes, in body radii, while each set of three legs takes a step.
@export var stride := 1.2


# --- the bones ----------------------------------------------------------------

func make_motion() -> CreatureMotion:
	return InsectMotion.new()


func build_bones(skeleton: Skeleton3D) -> void:
	skeleton.clear_bones()
	var at := _layout()
	var root := RigKit.add_bone(skeleton, "Root", -1, Transform3D.IDENTITY)
	var middle := RigKit.add_bone(skeleton, "Thorax", root,
		Transform3D(Basis.IDENTITY, at["thorax"]))
	var face := RigKit.add_bone(skeleton, "Head", middle, Transform3D(Basis.IDENTITY, at["neck"]))
	var behind := middle
	if waist > 0.0:
		behind = RigKit.add_bone(skeleton, "Waist", middle,
			Transform3D(Basis.IDENTITY, at["waist"]))
	RigKit.add_bone(skeleton, "Abdomen", behind,
		Transform3D(Basis(Vector3.RIGHT, deg_to_rad(abdomen_droop)), at["joint"]))

	for s in 2:
		var side := -1.0 if s == 0 else 1.0
		var tag: String = SIDES[s]
		var feeler := _feeler(side)
		var base := RigKit.add_bone(skeleton, "Antenna.%s.1" % tag, face,
			Transform3D(RigKit.along(feeler["first"], Vector3.RIGHT), feeler["at"]))
		RigKit.add_bone(skeleton, "Antenna.%s.2" % tag, base,
			Transform3D(RigKit.along(feeler["second"], Vector3.RIGHT), feeler["elbow"]))
		if mandibles > 0.0:
			var jaw := _jaw(side)
			RigKit.add_bone(skeleton, "Mandible.%s" % tag, face,
				Transform3D(RigKit.along(jaw["direction"], Vector3.UP), jaw["at"]))
	if proboscis > 0.0:
		var mouth := _mouth()
		RigKit.add_bone(skeleton, "Proboscis", face,
			Transform3D(RigKit.along(mouth["direction"], Vector3.RIGHT), mouth["at"]))

	for pair in 3:
		for s in 2:
			var side := -1.0 if s == 0 else 1.0
			var limb := leg_rest(pair, side)
			var parent := middle
			for part in 3:
				parent = RigKit.add_bone(skeleton, leg_bone(pair, s, part), parent,
					Transform3D(RigKit.along(limb["directions"][part], limb["normal"]),
						limb["joints"][part]))

	for hind in wing_pairs:
		for s in 2:
			var side := -1.0 if s == 0 else 1.0
			var blade := _wing(hind == 1, side)
			RigKit.add_bone(skeleton, wing_bone(hind == 1, s), middle,
				Transform3D(RigKit.along(blade["spread"], Vector3.BACK), blade["at"]))


## The name of a leg's bone: pair 0 to 2 from the front, side 0 left or 1 right,
## part 0 femur, 1 tibia, 2 tarsus.
static func leg_bone(pair: int, side: int, part: int) -> String:
	return "Leg.%s%d.%s" % [SIDES[side], pair + 1, LEG_PARTS[part]]


## The name of a wing's bone: the forewing, or the one behind it.
static func wing_bone(hind: bool, side: int) -> String:
	return "Wing.%s%d" % [SIDES[side], 2 if hind else 1]


func reach_down() -> float:
	var lowest := 0.0
	for pair in 3:
		for side in [-1.0, 1.0]:
			var limb := leg_rest(pair, side)
			lowest = minf(lowest, (limb["foot"] as Vector3).y)
	return -lowest


## Where the parts sit, worked out from their sizes, in the body's space. The
## thorax goes where it has to for the whole length, head to tip, to be centred.
func _layout() -> Dictionary:
	var droop := deg_to_rad(abdomen_droop)
	var tail := Vector3(0.0, -sin(droop), cos(droop))
	var neck := Vector3(0.0, thorax.y * 0.15, -thorax.z * 0.85)
	var face := neck + Vector3(0.0, 0.0, -head.z * 0.8)
	# Without a waist the abdomen is joined on broadly, well into the thorax; with
	# one it hangs off the end of it.
	var back := Vector3(0.0, -thorax.y * 0.1, thorax.z * (0.8 if waist > 0.0 else 0.55))
	var joint := back + Vector3(0.0, 0.0, waist)
	var tip := joint + tail * (abdomen.z * 1.95 + sting)
	var shift := Vector3(0.0, 0.0, -(face.z - head.z + tip.z) * 0.5)
	return {
		"thorax": shift, "neck": neck + shift, "head": face + shift, "waist": back + shift,
		"joint": joint + shift, "tail": tail,
	}


## Leg [param pair] on [param side] at rest, in the body's space: where each joint
## is, which way each segment runs, and where the foot is. Up and out to a raised knee, down to the
## ground, and the tarsus out along it — an insect stands inside its legs.
func leg_rest(pair: int, side: float) -> Dictionary:
	var at: Vector3 = _layout()["thorax"] + Vector3(side * thorax.x * 0.55,
		-thorax.y * 0.55, thorax.z * (float(pair) - 1.0) * 0.5)
	var yaw := deg_to_rad(leg_splay[pair])
	var out := Vector3(side * cos(yaw), 0.0, -sin(yaw))
	var lengths := leg * leg_pairs[pair]
	var directions: Array[Vector3] = [
		(out * 0.77 + Vector3.UP * 0.64).normalized(),
		(out * 0.45 + Vector3.DOWN * 0.89).normalized(),
		(out * 0.8 + Vector3.DOWN * 0.6).normalized(),
	]
	var joints: Array[Vector3] = [at]
	for part in 2:
		joints.append(joints[part] + directions[part] * lengths[part])
	return {
		"joints": joints, "directions": directions, "lengths": lengths,
		"foot": joints[2] + directions[2] * lengths[2], "out": out,
		"normal": out.cross(Vector3.UP).normalized(),
	}


## A feeler: where it leaves the head, which way its two segments run, and where
## the elbow between them is.
func _feeler(side: float) -> Dictionary:
	var at: Vector3 = _layout()["head"] + Vector3(side * head.x * 0.35, head.y * 0.7,
		-head.z * 0.65)
	var first := Vector3(side * 0.35, 0.6, -0.72).normalized()
	var second := first.rotated(Vector3.RIGHT, -deg_to_rad(antenna_elbow)).normalized()
	var base_length := antenna * (0.42 if antenna_elbow > 45.0 else 0.3)
	return {
		"at": at, "first": first, "second": second, "elbow": at + first * base_length,
		"lengths": Vector2(base_length, antenna - base_length),
	}


func _mouth() -> Dictionary:
	var angle := deg_to_rad(proboscis_angle)
	return {
		"at": _layout()["head"] + Vector3(0.0, -head.y * 0.55, -head.z * 0.6),
		"direction": Vector3(0.0, -sin(angle), -cos(angle)),
	}


func _jaw(side: float) -> Dictionary:
	return {
		"at": _layout()["head"] + Vector3(side * head.x * 0.3, -head.y * 0.45, -head.z * 0.85),
		"direction": Vector3(-side * 0.35, -0.2, -0.9).normalized(),
	}


## A wing: where it hinges on the thorax, and which way it points spread for
## flight — out, a little up, and swept back, the hindwing more than the fore.
func _wing(hind: bool, side: float) -> Dictionary:
	return {
		"at": _layout()["thorax"] + Vector3(side * thorax.x * 0.45, thorax.y * 0.72,
			thorax.z * (0.2 if hind else -0.2)),
		"spread": Vector3(side, 0.08, wing_sweep.y if hind else wing_sweep.x).normalized(),
		"size": hind_wing if hind else wing,
	}


# --- the mesh -----------------------------------------------------------------

## One mesh in three surfaces: the body in its flat colours, the eyes glossy, and
## the wings drawn from both sides and, unless they are coloured, see-through.
func build_mesh(skeleton: Skeleton3D) -> ArrayMesh:
	var body := RigKit.begin()
	var shine := RigKit.begin()
	var blades := RigKit.begin()
	var at := _layout()
	var rod := RigKit.Cut.new(8, 1, 3)
	var backward := Transform3D(RigKit.along(Vector3.BACK, Vector3.RIGHT), Vector3.ZERO)
	var forward := RigKit.along(Vector3.FORWARD, Vector3.RIGHT)

	var middle := skeleton.find_bone("Thorax")
	var face := skeleton.find_bone("Head")
	var hind := skeleton.find_bone("Abdomen")
	RigKit.lathe(body, skeleton, middle, backward,
		RigKit.ovoid(thorax, 0.0, 12, RigKit.solid(colour)), 16)
	RigKit.lathe(body, skeleton, face, Transform3D(forward, at["head"] - at["neck"]),
		RigKit.ovoid(head, 0.0, 10, RigKit.solid(colour)), 16)
	var waist_bone := skeleton.find_bone("Waist")
	if waist_bone >= 0:
		RigKit.lathe(body, skeleton, waist_bone, backward,
			RigKit.capsule(waist, waist_thickness, colour), 10)

	# The abdomen, and its bands: rows doubled at every edge so that each band
	# starts where it starts, instead of fading in over a row.
	var length := abdomen.z
	var tail := Transform3D(backward.basis, Vector3(0.0, 0.0, length * 0.95))
	var edges := _band_edges()
	RigKit.lathe(body, skeleton, hind, tail,
		RigKit.ovoid(abdomen, abdomen_point, 18, _band_paint(edges), edges), 18)
	if sting > 0.0:
		# From just inside the tip, where its root is hidden, out to a point.
		RigKit.lathe(body, skeleton, hind, tail, [
			[length * 0.88, 0.06, 0.06, stripe_colour],
			[length + sting * 0.35, 0.035, 0.035, stripe_colour],
			[length + sting, 0.0, 0.0, stripe_colour]], 8)

	for pair in 3:
		for s in 2:
			var limb := leg_rest(pair, -1.0 if s == 0 else 1.0)
			for part in 3:
				RigKit.segment(body, skeleton, skeleton.find_bone(leg_bone(pair, s, part)),
					limb["lengths"][part], leg_thickness * [1.0, 0.9, 0.75][part],
					leg_thickness * [0.9, 0.75, 0.6][part], RigKit.plain(leg_colour), rod)

	for s in 2:
		var tag: String = SIDES[s]
		var feeler := _feeler(-1.0 if s == 0 else 1.0)
		var lengths: Vector2 = feeler["lengths"]
		RigKit.segment(body, skeleton, skeleton.find_bone("Antenna.%s.1" % tag), lengths.x,
			antenna_thickness, antenna_thickness, RigKit.plain(colour), rod)
		var tip := skeleton.find_bone("Antenna.%s.2" % tag)
		RigKit.segment(body, skeleton, tip, lengths.y, antenna_thickness,
			antenna_thickness * 0.8, RigKit.plain(colour), rod)
		if antenna_club > 0.0:
			RigKit.ellipsoid(body, skeleton, tip, Vector3(0.0, lengths.y, 0.0),
				Vector3(antenna_club, antenna_club * 1.7, antenna_club), RigKit.plain(colour), 8, 6)
		if mandibles > 0.0:
			RigKit.segment(body, skeleton, skeleton.find_bone("Mandible.%s" % tag), mandibles,
				0.06, 0.015, RigKit.plain(colour.darkened(0.35)), rod)
		# Compound eyes, bulging from either side of the head.
		var eye_at: Vector3 = at["head"] - at["neck"] + Vector3((-1.0 if s == 0 else 1.0)
			* head.x * 0.62, head.y * 0.15, -head.z * 0.15)
		RigKit.ellipsoid(shine, skeleton, face, eye_at, eyes, RigKit.plain(eye_colour), 14, 9)

	var mouth := skeleton.find_bone("Proboscis")
	if mouth >= 0:
		RigKit.segment(body, skeleton, mouth, proboscis, proboscis_thickness,
			proboscis_thickness * 0.6, RigKit.plain(colour), rod)
		if proboscis_pad > 0.0:
			RigKit.ellipsoid(body, skeleton, mouth, Vector3(0.0, proboscis, 0.0),
				Vector3(proboscis_pad * 1.2, proboscis_pad * 0.6, proboscis_pad),
				RigKit.plain(colour), 10, 6)

	for back in wing_pairs:
		for s in 2:
			var size: Vector2 = hind_wing if back == 1 else wing
			RigKit.membrane(blades, skeleton, skeleton.find_bone(wing_bone(back == 1, s)),
				size.x, size.y, hind_wing_broadest if back == 1 else wing_broadest, wing_colour,
				wing_rim)

	return RigKit.commit([body, shine, blades], [RigKit.shell_material(0.75, 0.0, 0.3),
		RigKit.eye_material(eye_colour, eye_colour, 0.15),
		RigKit.membrane_material(wing_colour.a < 0.99 or wing_rim.a < 0.99)])


## Where the bands on the abdomen start and stop, along it: from a third of the
## way back to near the tip, a stripe and a gap in turn.
func _band_edges() -> PackedFloat32Array:
	var edges := PackedFloat32Array()
	if stripes <= 0:
		return edges
	var first := -abdomen.z * 0.3
	var last := abdomen.z * 0.9
	for i in stripes * 2 + 1:
		edges.append(lerpf(first, last, float(i) / float(stripes * 2)))
	return edges


## Colours the abdomen along its length: its own colour at the front, bands in
## turn over [param edges], and the stripe colour on from the last of them.
func _band_paint(edges: PackedFloat32Array) -> Callable:
	return func(y: float) -> Color:
		if edges.is_empty() or y < edges[0]:
			return abdomen_colour
		for i in edges.size() - 1:
			if y < edges[i + 1]:
				return stripe_colour if i % 2 == 1 else abdomen_colour
		return stripe_colour
