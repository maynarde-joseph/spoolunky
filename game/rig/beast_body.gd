class_name BeastBody
extends CreatureBody

## Something on four legs: a body, a head with a snout, ears and a jaw that opens,
## four legs, and a tail. A rat, a cat and a dog are all this, and so — with the
## ears and the tail left off and the legs splayed out to the sides — is a frog.
## What tells one from another is numbers in a .tres of it.
##
## Drawn the minimal way, as the spider and the insects are: smooth parts, thin
## legs of one width bent at round joints, a few flat colours, and two small eyes
## that shine a little. Nothing that does not help the silhouette — no whiskers,
## no teeth, no markings. Every length is in body radii and every angle in
## degrees; forward is -Z and up is +Y.
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
	NONE,     ## a frog's, or a lizard's: none to be seen
}


@export_group("Colours")

## The coat: the body, the head and the legs.
@export var colour := Color(0.46, 0.43, 0.41)
@export var ear_colour := Color(0.46, 0.43, 0.41)
@export var tail_colour := Color(0.46, 0.43, 0.41)
## The end of the snout. The coat's own colour for a nose not worth one of its own.
@export var nose_colour := Color(0.46, 0.43, 0.41)
@export var eye_colour := Color(0.04, 0.03, 0.03)


@export_group("Body")

## The body's radii: across, up and along.
@export var body := Vector3(0.5, 0.46, 0.72)
## How much narrower it is at the shoulders than at the hips: 0 an egg, 1 a pear.
@export_range(0.0, 1.0) var body_point := 0.25
## The head's radii: across, up and along.
@export var head := Vector3(0.34, 0.32, 0.34)
## How high the head is carried, above the middle of the body.
@export var head_lift := 0.3
## How far forward of the body's middle the head is set, against the body's
## length: on a neck, or sunk into the shoulders the way a frog's is.
@export_range(0.2, 1.2) var head_set := 0.78
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
@export var eye := 0.06
## How far round the head the eyes sit: 0 looking straight ahead, 1 out to the
## sides.
@export_range(0.0, 1.0) var eye_spread := 0.45
## How high up the head they sit: low on its face as a rat's are, or — at one and a
## half or so — up on top of it the way a frog's are.
@export_range(0.0, 2.0) var eye_lift := 0.35
@export var ears := Ears.ROUND
## Each ear's width and length.
@export var ear := Vector2(0.26, 0.24)
## How far out from upright the ears lean, in degrees.
@export var ear_lean := 25.0
## How long the lower jaw is, against the snout.
@export_range(0.3, 1.2) var jaw := 0.8
## Mouth open whenever it is not caught: a dog's.
@export var pants := false
## A pair of tusks this long and this thick at the root, curving up out of the
## lower jaw, so they come up with it when it opens its mouth: a boar's. Zero for
## none.
@export var tusks := Vector2.ZERO
@export var tusk_colour := Color(0.9, 0.86, 0.74)


@export_group("Legs")

## How thick every part of a leg is, from the shoulder to the floor.
@export var leg_thickness := 0.06
## How much of each leg is the upper part, down to the knee.
@export_range(0.2, 0.8) var leg_split := 0.5
## How far the ankle is off the floor: the last part of each leg.
@export var foot := 0.1
## How far out to the side the legs go from the body before they come down, in
## degrees: a frog's and a lizard's elbows stick out. None for something that
## stands with its legs under it.
@export_range(0.0, 70.0) var sprawl := 0.0


@export_group("Tail")

## How long it is. Zero for none.
@export var tail := 1.6
@export_range(2, 8) var tail_bones := 5
## How thick the tail is at its root, and at its tip.
@export var tail_thickness := Vector2(0.07, 0.025)
## How much of it, back from the tip, is [member tail_tip_colour]: a fox's white
## brush. Zero for none.
@export_range(0.0, 1.0) var tail_tip := 0.0
@export var tail_tip_colour := Color(0.92, 0.9, 0.86)
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
	if ears != Ears.NONE:
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

	if tail > 0.0:
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
	var face := Vector3(0.0, head_lift, -(body.z * head_set + head.z * 0.5))
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
## Either goes out to the side first by [member sprawl], and then down.
func leg_rest(end: int, side: float) -> Dictionary:
	# Legs that splay out leave the body from its sides rather than from under it.
	var wide := lerpf(0.5, 0.85, sprawl / 70.0)
	var at: Vector3 = _layout()["body"] + Vector3(side * body.x * wide, -body.y * 0.25,
		body.z * (-0.55 if end == 0 else 0.55))
	var high := foot
	var drop := maxf(at.y + stance - high, 0.05)
	var directions: Array[Vector3] = [Vector3.DOWN, Vector3.DOWN, Vector3.DOWN]
	var lengths := Vector3(drop * leg_split, drop * (1.0 - leg_split), high)
	var bend := deg_to_rad(HOCK) if end == 1 else 0.0
	var out := deg_to_rad(sprawl)
	directions[0] = Vector3(side * sin(out) * cos(bend), -cos(out) * cos(bend), -sin(bend))
	directions[1] = Vector3(0.0, -cos(bend), sin(bend))
	lengths.x /= cos(out) * cos(bend)
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

## One mesh in two surfaces: everything but the eyes in its few flat colours,
## and the eyes.
func build_mesh(skeleton: Skeleton3D) -> ArrayMesh:
	var coat := RigKit.begin()
	var shine := RigKit.begin()
	var at := _layout()
	var forward := RigKit.along(Vector3.FORWARD, Vector3.RIGHT)
	var trunk := skeleton.find_bone("Body")
	var face := skeleton.find_bone("Head")
	var neck: Vector3 = at["neck"]
	var head_at: Vector3 = at["head"] - neck
	var muzzle: Vector3 = at["snout"] - neck

	RigKit.lathe(coat, skeleton, trunk, Transform3D(forward, Vector3.ZERO),
		RigKit.ovoid(body, body_point, 16, RigKit.solid(colour)), 20)
	RigKit.lathe(coat, skeleton, face, Transform3D(forward, head_at),
		RigKit.ovoid(head, 0.0, 12, RigKit.solid(colour)), 18)
	RigKit.lathe(coat, skeleton, face, Transform3D(forward, muzzle),
		RigKit.ovoid(Vector3(snout.x, snout.y, snout.z * 0.5), snout_point, 10,
			RigKit.solid(colour)), 16)
	RigKit.ellipsoid(coat, skeleton, face, muzzle + Vector3(0.0, snout.y * 0.1, -snout.z * 0.5),
		Vector3(nose * 1.1, nose * 0.9, nose * 0.8), RigKit.plain(nose_colour), 12, 8)
	# The lower jaw: the underside of the snout, on a bone of its own so the mouth
	# can open.
	var length := snout.z * jaw
	RigKit.lathe(coat, skeleton, skeleton.find_bone("Jaw"), Transform3D.IDENTITY,
		RigKit.ovoid(Vector3(snout.x * 0.7, snout.y * 0.35, length * 0.5), snout_point * 0.6, 8,
			RigKit.solid(colour)).map(
			func(row: Array) -> Array: return [row[0] + length * 0.5, row[1], row[2], row[3]]), 12)

	if tusks != Vector2.ZERO:
		_build_tusks(coat, skeleton)

	for s in 2:
		var side := -1.0 if s == 0 else 1.0
		# Set into the head, a little proud of it, out toward the sides as far as
		# [member eye_spread] says.
		var toward := Vector3(side * lerpf(0.35, 0.8, eye_spread), eye_lift,
			-lerpf(0.87, 0.5, eye_spread)).normalized()
		RigKit.ellipsoid(shine, skeleton, face, head_at + toward * head - toward * eye * 0.4,
			Vector3.ONE * eye, RigKit.plain(eye_colour), 10, 6)
		# Upright ears face forward and a little out, the way they cup sound.
		if ears != Ears.NONE:
			RigKit.ear(coat, skeleton, skeleton.find_bone("Ear.%s" % SIDES[s]), ear.x, ear.y,
				ear.x * 0.2, 1.0 if ears == Ears.POINTED else 0.0, ear_colour,
				0.0 if ears == Ears.FLOPPY else -side * 35.0)

	# Every part of a leg one width, a round end at every joint, so each reads as
	# one bent rod rather than three pieces.
	var rod := RigKit.Cut.new(8, 1, 3)
	for end in 2:
		for s in 2:
			var limb := leg_rest(end, -1.0 if s == 0 else 1.0)
			var lengths: Vector3 = limb["lengths"]
			for part in 3:
				RigKit.segment(coat, skeleton, skeleton.find_bone(leg_bone(end, s, part)),
					lengths[part], leg_thickness, leg_thickness, RigKit.plain(colour), rod)

	if tail > 0.0:
		var rest := tail_rest()
		var piece: float = rest["piece"]
		var tipped := float(tail_bones) * (1.0 - tail_tip) - 0.001
		for i in tail_bones:
			var from := lerpf(tail_thickness.x, tail_thickness.y, float(i) / float(tail_bones))
			var to := lerpf(tail_thickness.x, tail_thickness.y, float(i + 1) / float(tail_bones))
			var paint := tail_tip_colour if tail_tip > 0.0 and float(i) >= tipped else tail_colour
			RigKit.segment(coat, skeleton, skeleton.find_bone(tail_bone(i)), piece, from, to,
				RigKit.plain(paint), rod)

	return RigKit.commit([coat, shine], [RigKit.shell_material(0.75, 0.0, 0.3),
		RigKit.eye_material(eye_colour, eye_colour, 0.15)])


## Two tusks on the jaw, from near its front: out, up and forward, and curling
## back toward the face. In the jaw's own space its length runs up +Y and +Z is
## the way the face's top is.
func _build_tusks(coat: SurfaceTool, skeleton: Skeleton3D) -> void:
	var jaw_bone := skeleton.find_bone("Jaw")
	var length: float = _mouth()["length"]
	for side in [-1.0, 1.0]:
		RigKit.horn(coat, skeleton, jaw_bone,
			Vector3(side * snout.x * 0.55, length * 0.72, snout.y * 0.15),
			Vector3(side * 0.4, 0.45, 0.8), Vector3.RIGHT, tusks.x, tusks.y, 60.0, tusk_colour)
