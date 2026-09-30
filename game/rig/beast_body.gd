class_name BeastBody
extends CreatureBody

## Something furry on four legs: a body, a head with a snout, ears and a jaw that
## opens, four legs on paws, and a tail. A rat, a cat and a dog are all this, and
## what tells one from another is numbers in a .tres of it.
##
## Drawn the way the insects are, minimal: smooth parts, a few flat colours, and a
## face that is mostly eyes and nose. Every length is in body radii and every angle
## in degrees; forward is -Z and up is +Y.
##
## From the tip of its nose to the back of its rump it is centred on the
## creature's middle, which is the middle of its hitbox. The tail, like an
## insect's legs, is what reaches out of it.

const SIDES := ["L", "R"]
## The legs' ends of the body, front and hind.
const ENDS := ["Front", "Hind"]
const LEG_PARTS := ["Upper", "Lower", "Paw"]

## How far forward a hind leg's knee sits from under the hip, in degrees, the
## bend that makes a back leg read as one.
const HOCK := 22.0

## What its ears are like.
enum Ears {
	ROUND,    ## a rat's: wide discs, standing up
	POINTED,  ## a cat's: upright triangles
	FLOPPY,   ## a dog's: long, and hanging down the sides of the head
}


@export_group("Colours")

## The coat.
@export var colour := Color(0.46, 0.43, 0.41)
## Underneath: the belly and the chin.
@export var belly_colour := Color(0.7, 0.66, 0.62)
## The chest that colour too, down the front: a cat's or a dog's white bib.
@export var bib := false
## The snout, and the lower jaw.
@export var muzzle_colour := Color(0.5, 0.47, 0.45)
@export var nose_colour := Color(0.92, 0.56, 0.6)
@export var paw_colour := Color(0.9, 0.62, 0.62)
## The backs of the ears, and their insides.
@export var ear_colour := Color(0.46, 0.43, 0.41)
@export var ear_inside := Color(0.92, 0.62, 0.64)
@export var tail_colour := Color(0.9, 0.65, 0.66)
## The last [member tail_tip] of the tail's length is this colour. None for a tail
## the one colour.
@export var tail_tip_colour := Color(1.0, 1.0, 1.0)
@export_range(0.0, 1.0) var tail_tip := 0.0
## The middle of each eye, and what shows round it as far as [member eye_white]
## says: white, or a cat's green.
@export var eye_colour := Color(0.04, 0.03, 0.03)
@export var eye_ring := Color(0.95, 0.94, 0.9)
## Bands over the back and round the tail, when [member stripes] asks for any.
@export var stripe_colour := Color(0.3, 0.2, 0.1)
@export var stripes := 0
## A patch this big round the left eye, a dog's. Zero for none.
@export var patch := 0.0
@export var patch_colour := Color(0.42, 0.26, 0.13)
## Whiskers, when [member whiskers] asks for any.
@export var whisker_colour := Color(0.15, 0.14, 0.14)
## How glossy the coat is, from dull to sleek.
@export_range(0.0, 1.0) var gloss := 0.15


@export_group("Body")

## The body's radii: across, up and along.
@export var body := Vector3(0.5, 0.46, 0.72)
## How much narrower it is at the shoulders than at the hips: 0 an egg, 1 a pear.
@export_range(0.0, 1.0) var body_point := 0.25
## The head's radii: across, up and along.
@export var head := Vector3(0.34, 0.32, 0.34)
## How high the head is carried, above the middle of the body.
@export var head_lift := 0.3
## The snout's radii across and up, and its whole length.
@export var snout := Vector3(0.17, 0.15, 0.36)
## How much the snout narrows toward its end: 0 blunt, 1 a point.
@export_range(0.0, 1.0) var snout_point := 0.5
## How far down from the middle of the head the snout sits, against the head's
## height: a dog's hangs lower than a rat's.
@export var snout_drop := 0.3
## The nose's radius.
@export var nose := 0.07
## How far below the middle of the body its feet are when it stands, which is how
## tall it stands. The legs are as long as that takes.
@export var stance := 0.85


@export_group("Face")

## Each eye's radius.
@export var eye := 0.1
## How much of each eye is white round the dark middle: none is a bead, and more
## is a stare.
@export_range(0.0, 1.0) var eye_white := 0.0
## How far round the head the eyes sit and look: 0 straight ahead, 1 out to the
## sides.
@export_range(0.0, 1.0) var eye_spread := 0.45
@export var ears := Ears.ROUND
## Each ear's width and length.
@export var ear := Vector2(0.26, 0.24)
## How far out from upright the ears lean, in degrees.
@export var ear_lean := 25.0
## Whiskers this long, three a side. Zero for none.
@export var whiskers := 0.0
## Front teeth this long, showing under the nose: a rat's. Zero for none.
@export var buck_teeth := 0.0
## How long the lower jaw is, against the snout.
@export_range(0.3, 1.2) var jaw := 0.8
## A tongue this long, out past the lower jaw. Zero for none.
@export var tongue := 0.0
## Mouth open and tongue out whenever it is not caught: a dog's.
@export var pants := false


@export_group("Legs")

@export var leg_thickness := 0.1
## How much of each leg is the upper part, down to the knee.
@export_range(0.2, 0.8) var leg_split := 0.5
## Each paw's radii: across, up and along.
@export var paw := Vector3(0.09, 0.05, 0.12)


@export_group("Tail")

@export var tail := 1.6
@export_range(2, 8) var tail_bones := 5
## How thick the tail is at its root, and at its tip.
@export var tail_thickness := Vector2(0.07, 0.025)
## How much thicker than that it is in the middle: a bushy tail's fluff.
@export var tail_fluff := 0.0
## Which way it leaves the body, in degrees above straight back.
@export var tail_lift := -15.0
## How much further up it bends at each bone, in degrees: a cat's hooked tail.
@export var tail_curl := 4.0


@export_group("Moving")

## How far the body goes, in body radii, in one stride of all four legs.
@export var stride := 1.2
## How the tail goes as it walks: 0 a slow swing, 1 a dog's wag.
@export_range(0.0, 1.0) var wag := 0.0


# --- the bones ----------------------------------------------------------------

func make_motion() -> CreatureMotion:
	return BeastMotion.new()


func build_bones(skeleton: Skeleton3D) -> void:
	skeleton.clear_bones()
	var at := _layout()
	var root := RigKit.add_bone(skeleton, "Root", -1, Transform3D.IDENTITY)
	var trunk := RigKit.add_bone(skeleton, "Body", root, Transform3D(Basis.IDENTITY, at["body"]))
	var neck: Vector3 = at["neck"]
	var face := RigKit.add_bone(skeleton, "Head", trunk, Transform3D(Basis.IDENTITY, neck))
	# What hangs off the head is laid out from the head, and the head bone sits
	# unturned at the neck: where it is in the skeleton is the neck plus that.
	var mouth := _mouth()
	RigKit.add_bone(skeleton, "Jaw", face,
		Transform3D(RigKit.along(mouth["direction"], Vector3.RIGHT), neck + mouth["hinge"]))
	for s in 2:
		var side := -1.0 if s == 0 else 1.0
		var flap := _ear(side)
		RigKit.add_bone(skeleton, "Ear.%s" % SIDES[s], face,
			Transform3D(RigKit.along(flap["direction"], flap["hint"]), neck + flap["at"]))

	for end in 2:
		for s in 2:
			var limb := leg_rest(end, -1.0 if s == 0 else 1.0)
			var parent := trunk
			for part in 3:
				parent = RigKit.add_bone(skeleton, leg_bone(end, s, part), parent,
					Transform3D(RigKit.along(limb["directions"][part], Vector3.RIGHT),
						limb["joints"][part]))

	var rest := tail_rest()
	var parent := trunk
	for i in tail_bones:
		parent = RigKit.add_bone(skeleton, tail_bone(i), parent,
			Transform3D(RigKit.along(rest["directions"][i], Vector3.RIGHT), rest["joints"][i]))


## The name of a leg's bone: end 0 front or 1 hind, side 0 left or 1 right, part
## 0 upper, 1 lower, 2 paw.
static func leg_bone(end: int, side: int, part: int) -> String:
	return "Leg.%s%s.%s" % [SIDES[side], ENDS[end].left(1), LEG_PARTS[part]]


## The name of the tail's bone [param index], counting from the root.
static func tail_bone(index: int) -> String:
	return "Tail.%d" % (index + 1)


func reach_down() -> float:
	return stance


## Where the parts sit, in the body's space: its own middle is where the body is
## put so that nose to rump is centred on the creature's.
func _layout() -> Dictionary:
	var face := Vector3(0.0, head_lift, -(body.z * 0.78 + head.z * 0.5))
	var muzzle := face + Vector3(0.0, -head.y * snout_drop, -(head.z * 0.6 + snout.z * 0.5))
	var tip := muzzle.z - snout.z * 0.5 - nose * 0.5
	var shift := Vector3(0.0, 0.0, -(tip + body.z) * 0.5)
	return {
		"body": shift, "neck": Vector3(0.0, body.y * 0.35, -body.z * 0.7) + shift,
		"head": face + shift, "snout": muzzle + shift,
		"tail": Vector3(0.0, body.y * 0.1, body.z * 0.9) + shift,
	}


## A leg at rest, in the body's space: where each joint is, which way each part
## runs, and how long each is, standing on the floor [member stance] down. A front
## leg comes straight down; a hind one puts its knee forward and its hock back.
func leg_rest(end: int, side: float) -> Dictionary:
	var at: Vector3 = _layout()["body"] + Vector3(side * body.x * 0.5, -body.y * 0.25,
		body.z * (-0.55 if end == 0 else 0.55))
	var high := paw.y * 2.0
	var drop := maxf(at.y + stance - high, 0.05)
	var directions: Array[Vector3] = [Vector3.DOWN, Vector3.DOWN, Vector3.DOWN]
	var lengths := Vector3(drop * leg_split, drop * (1.0 - leg_split), high)
	if end == 1:
		var bend := deg_to_rad(HOCK)
		directions[0] = Vector3(0.0, -cos(bend), -sin(bend))
		directions[1] = Vector3(0.0, -cos(bend), sin(bend))
		lengths.x /= cos(bend)
		lengths.y /= cos(bend)
	var joints: Array[Vector3] = [at]
	for part in 2:
		joints.append(joints[part] + directions[part] * lengths[part])
	return {"joints": joints, "directions": directions, "lengths": lengths}


## The tail at rest: where each bone starts and which way it runs.
func tail_rest() -> Dictionary:
	var joints: Array[Vector3] = [_layout()["tail"]]
	var directions: Array[Vector3] = []
	var piece := tail / float(tail_bones)
	for i in tail_bones:
		var pitch := deg_to_rad(tail_lift + tail_curl * float(i))
		directions.append(Vector3(0.0, sin(pitch), cos(pitch)))
		joints.append(joints[i] + directions[i] * piece)
	return {"joints": joints, "directions": directions, "piece": piece}


## The jaw's hinge, under the back of the snout, in the head's space, and which
## way it runs.
func _mouth() -> Dictionary:
	var at := _layout()
	var muzzle: Vector3 = at["snout"] - at["neck"]
	var hinge := muzzle + Vector3(0.0, -snout.y * 0.55, snout.z * 0.45)
	return {"hinge": hinge, "direction": Vector3(0.0, -0.12, -1.0).normalized(),
		"length": snout.z * jaw}


## An ear: where it leaves the head, in the head's space, and which way it points.
## A dog's hang down its sides, their broad faces outward; the others stand up and
## face forward.
func _ear(side: float) -> Dictionary:
	var at := _layout()
	var face: Vector3 = at["head"] - at["neck"]
	var lean := deg_to_rad(ear_lean)
	if ears == Ears.FLOPPY:
		return {
			"at": face + Vector3(side * head.x * 0.62, head.y * 0.55, head.z * 0.1),
			"direction": Vector3(side * sin(lean), -cos(lean), 0.15).normalized(),
			"hint": Vector3.FORWARD,
		}
	return {
		"at": face + Vector3(side * head.x * 0.5, head.y * 0.72, head.z * 0.05),
		"direction": Vector3(side * sin(lean), cos(lean), 0.1).normalized(),
		"hint": Vector3.RIGHT,
	}


# --- the mesh -----------------------------------------------------------------

## One mesh in two surfaces: the body in its flat colours, and the parts that shine
## — eyes and nose.
func build_mesh(skeleton: Skeleton3D) -> ArrayMesh:
	var fur := RigKit.begin()
	var shine := RigKit.begin()
	var at := _layout()
	var forward := RigKit.along(Vector3.FORWARD, Vector3.RIGHT)
	var trunk := skeleton.find_bone("Body")
	var face := skeleton.find_bone("Head")
	var neck: Vector3 = at["neck"]
	var head_at: Vector3 = at["head"] - neck
	var muzzle: Vector3 = at["snout"] - neck

	# The body, narrower at the shoulders, pale underneath.
	RigKit.lathe(fur, skeleton, trunk, Transform3D(forward, Vector3.ZERO),
		RigKit.ovoid(body, body_point, 16, func(_y: float) -> Callable: return _coat()), 20)
	# The head, and a snout on the front of it.
	RigKit.lathe(fur, skeleton, face, Transform3D(forward, head_at),
		RigKit.ovoid(head, 0.0, 12, func(_y: float) -> Callable: return _face_paint(head_at)), 18)
	RigKit.lathe(fur, skeleton, face, Transform3D(forward, muzzle),
		RigKit.ovoid(Vector3(snout.x, snout.y, snout.z * 0.5), snout_point, 10,
			RigKit.solid(muzzle_colour)), 16)
	var tip := muzzle + Vector3(0.0, snout.y * 0.1, -snout.z * 0.5)
	RigKit.ellipsoid(shine, skeleton, face, tip, Vector3(nose * 1.2, nose, nose),
		RigKit.plain(nose_colour), 12, 8)
	_build_mouth(fur, skeleton, muzzle)
	if whiskers > 0.0:
		_build_whiskers(fur, skeleton, face, muzzle)

	for s in 2:
		var side := -1.0 if s == 0 else 1.0
		var look := Vector3(side * eye_spread, 0.12, -1.0 + eye_spread * 0.4).normalized()
		var eye_at := head_at + Vector3(side * head.x * lerpf(0.42, 0.62, eye_spread),
			head.y * 0.3, -head.z * lerpf(0.66, 0.5, eye_spread))
		RigKit.eye(shine, skeleton, face, eye_at, look, eye, eye_colour, eye_white, eye_ring)
		var flap := _ear(side)
		RigKit.ear(fur, skeleton, skeleton.find_bone("Ear.%s" % SIDES[s]), ear.x, ear.y,
			ear.x * 0.12, 0.0 if ears != Ears.POINTED else 1.0, ear_colour,
			ear_colour if ears == Ears.FLOPPY else ear_inside)

	var rod := RigKit.Cut.new(10, 2, 3)
	for end in 2:
		for s in 2:
			var limb := leg_rest(end, -1.0 if s == 0 else 1.0)
			var lengths: Vector3 = limb["lengths"]
			var thick := leg_thickness * (1.1 if end == 1 else 1.0)
			RigKit.segment(fur, skeleton, skeleton.find_bone(leg_bone(end, s, 0)), lengths.x,
				thick * 1.25, thick, RigKit.plain(colour), rod)
			RigKit.segment(fur, skeleton, skeleton.find_bone(leg_bone(end, s, 1)), lengths.y,
				thick, thick * 0.85, RigKit.plain(colour), rod)
			# The paw, a flat oval with its sole on the floor and its toes forward.
			RigKit.ellipsoid(fur, skeleton, skeleton.find_bone(leg_bone(end, s, 2)),
				Vector3(0.0, paw.y, paw.z * 0.35), paw, RigKit.plain(paw_colour), 12, 8)

	var rest := tail_rest()
	var piece: float = rest["piece"]
	for i in tail_bones:
		var from := float(i) / float(tail_bones)
		var to := float(i + 1) / float(tail_bones)
		RigKit.segment(fur, skeleton, skeleton.find_bone(tail_bone(i)), piece,
			_tail_girth(from), _tail_girth(to), _tail_paint(i, piece), RigKit.Cut.new(12, 3, 3))

	return RigKit.commit([fur, shine], [RigKit.shell_material(1.0 - gloss, 0.0, 0.4),
		RigKit.gloss_material()])


## The mouth: a lower jaw under the snout that opens, and dark inside it, with
## front teeth and a tongue when there are any.
func _build_mouth(fur: SurfaceTool, skeleton: Skeleton3D, muzzle: Vector3) -> void:
	var face := skeleton.find_bone("Head")
	var chin := skeleton.find_bone("Jaw")
	var mouth := _mouth()
	var length: float = mouth["length"]
	var hinge: Vector3 = mouth["hinge"]
	var along := Transform3D(Basis.IDENTITY, Vector3.ZERO)
	RigKit.lathe(fur, skeleton, chin, along, RigKit.ovoid(Vector3(snout.x * 0.78,
		snout.y * 0.4, length * 0.5), snout_point * 0.6, 8, RigKit.solid(muzzle_colour)).map(
			func(row: Array) -> Array: return [row[0] + length * 0.5, row[1], row[2], row[3]]), 12)
	# Dark inside, filling the gap an open jaw leaves under the snout.
	RigKit.ellipsoid(fur, skeleton, face, hinge + Vector3(0.0, snout.y * 0.2, -length * 0.45),
		Vector3(snout.x * 0.7, snout.y * 0.3, length * 0.45), RigKit.plain(Color(0.3, 0.06, 0.08)),
		10, 6)
	if tongue > 0.0:
		RigKit.ellipsoid(fur, skeleton, chin, Vector3(0.0, length * 0.55 + tongue * 0.5,
			snout.y * 0.3), Vector3(snout.x * 0.5, tongue * 0.55, snout.y * 0.12),
			RigKit.plain(Color(0.92, 0.42, 0.5)), 10, 6)
	if buck_teeth > 0.0:
		for side in [-1.0, 1.0]:
			RigKit.ellipsoid(fur, skeleton, face, muzzle + Vector3(side * nose * 0.36,
				-snout.y * 0.62, -snout.z * 0.4), Vector3(nose * 0.36, buck_teeth * 0.5,
				nose * 0.24), RigKit.plain(Color(0.97, 0.94, 0.82)), 8, 6)


## Three whiskers a side, fanned out from either side of the snout.
func _build_whiskers(fur: SurfaceTool, skeleton: Skeleton3D, face: int,
		muzzle: Vector3) -> void:
	for side in [-1.0, 1.0]:
		for k in [-1.0, 0.0, 1.0]:
			var root := muzzle + Vector3(side * snout.x * 0.55, -snout.y * 0.1, -snout.z * 0.2)
			var out := Vector3(side, 0.12 * k - 0.05, 0.3 * k - 0.1).normalized()
			RigKit.lathe(fur, skeleton, face, Transform3D(RigKit.along(out, Vector3.UP), root),
				RigKit.capsule(whiskers, 0.008, whisker_colour, 1), 5)


## How thick the tail is [param along] of the way from its root to its tip.
func _tail_girth(along: float) -> float:
	return lerpf(tail_thickness.x, tail_thickness.y, along) + tail_fluff * sin(PI * along)


## Colours tail bone [param index], [param piece] long: its own colour, the tip's
## toward the end, and bands round it when the coat is striped.
func _tail_paint(index: int, piece: float) -> Callable:
	return func(_n: Vector3, p: Vector3) -> Color:
		var along := (float(index) + clampf(p.y / piece, 0.0, 1.0)) / float(tail_bones)
		if tail_tip > 0.0 and along > 1.0 - tail_tip:
			return tail_tip_colour
		if stripes > 0 and int(along * float(stripes) * 2.0) % 2 == 1:
			return stripe_colour
		return tail_colour


## Paints the body: the coat above, pale beneath and on the chest, and bands over
## the back when it is striped.
func _coat() -> Callable:
	return func(n: Vector3, p: Vector3) -> Color:
		if n.y < -0.35 or (bib and n.z < -0.55 and p.y < body.y * 0.2):
			return belly_colour
		if stripes > 0 and n.y > -0.1:
			var band := (p.z / body.z + 1.0) * 0.5 * float(stripes) * 2.0
			if int(band) % 2 == 1 and absf(p.z) < body.z * 0.75:
				return stripe_colour
		return colour


## Paints the head, centred at [param middle]: the coat, pale under the chin, and
## a patch round the left eye when it has one.
func _face_paint(middle: Vector3) -> Callable:
	var patch_at := middle + Vector3(-head.x * 0.5, head.y * 0.3, -head.z * 0.6)
	return func(n: Vector3, p: Vector3) -> Color:
		if patch > 0.0 and p.distance_to(patch_at) < patch:
			return patch_colour
		if n.y < -0.5:
			return belly_colour
		return colour
