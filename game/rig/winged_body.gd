class_name WingedBody
extends CreatureBody

## Something with fur or feathers that flies on two wings: a body, a head, two
## wings of two bones each — an arm out to the wrist and a hand beyond it — two
## legs, and a tail if it has one. A bat is this with skin stretched between its
## fingers and ears it could hear through a wall with; a parrot is this with
## feathers and a beak. What tells them apart is numbers in a .tres of it.
##
## Drawn like the rest, minimal and a little goofy. Every length is in body radii
## and every angle in degrees; forward is -Z and up is +Y. From the front of its
## face to the back of its body it is centred on the creature's middle, and the
## wings reach out of that the way an insect's do.

const SIDES := ["L", "R"]
## A wing's two bones: shoulder to wrist, and wrist to tip.
const WING_PARTS := ["Arm", "Hand"]
const LEG_PARTS := ["Leg", "Foot"]


@export_group("Colours")

## Fur or feathers: the body and the head.
@export var colour := Color(0.36, 0.27, 0.22)
@export var belly_colour := Color(0.46, 0.36, 0.3)
## Round the eyes, when [member face] asks for a patch there: a parrot's bare face.
@export var face_colour := Color(0.95, 0.93, 0.9)
## A wing's skin, or its flight feathers, and a band round the edge of either.
@export var wing_colour := Color(0.24, 0.19, 0.2)
@export var wing_rim := Color(0.18, 0.14, 0.15)
## The small feathers along a wing's front edge, when [member coverts] asks for any.
@export var covert_colour := Color(0.95, 0.8, 0.1)
## The finger bones in a wing of skin, and the forearm along its front.
@export var bone_colour := Color(0.2, 0.15, 0.15)
@export var nose_colour := Color(0.55, 0.36, 0.36)
## The upper beak, and the lower jaw — of beak, or of fur.
@export var beak_colour := Color(0.92, 0.88, 0.8)
@export var jaw_colour := Color(0.2, 0.2, 0.22)
@export var ear_colour := Color(0.36, 0.27, 0.22)
@export var ear_inside := Color(0.65, 0.45, 0.45)
@export var leg_colour := Color(0.25, 0.2, 0.2)
@export var tail_colour := Color(0.8, 0.1, 0.1)
@export var tail_tip_colour := Color(0.15, 0.35, 0.8)
## The middle of each eye, and what shows round it: white, or an iris.
@export var eye_colour := Color(0.03, 0.02, 0.02)
@export var eye_ring := Color(0.95, 0.94, 0.9)
## How glossy the fur or feathers are.
@export_range(0.0, 1.0) var gloss := 0.15


@export_group("Body")

## The body's radii: across, up and along.
@export var body := Vector3(0.42, 0.42, 0.55)
## How much narrower it is at the front than the back: 0 an egg, 1 a pear.
@export_range(0.0, 1.0) var body_point := 0.2
## The head's radii, and how high it is carried above the middle of the body.
@export var head := Vector3(0.36, 0.34, 0.32)
@export var head_lift := 0.25
## Each eye's radius, how much of it shows [member eye_ring] round the middle,
## and how far round the head the eyes sit and look.
@export var eye := 0.09
@export_range(0.0, 1.0) var eye_white := 0.4
@export_range(0.0, 1.0) var eye_spread := 0.35
## A patch this big round each eye, in [member face_colour]. Zero for none.
@export var face := 0.0
## A short snout: radii across, up and along. Zero for none.
@export var snout := Vector3(0.12, 0.1, 0.14)
## The nose on the end of the snout: flat and wide, like a pig's.
@export var nose := 0.07
## Fangs this long, down from the top jaw. Zero for none.
@export var fangs := 0.0
## A hooked beak this long and this deep at its root. Zero for none.
@export var beak := Vector2.ZERO
## Ears this wide and this long. Zero for none.
@export var ears := Vector2.ZERO
## How far out from upright the ears lean, in degrees.
@export var ear_lean := 20.0


@export_group("Wings")

## Feathers, or skin stretched between the fingers.
@export var feathered := false
## The arm, shoulder to wrist: its length, and how wide the wing is along it.
@export var arm := Vector2(0.9, 0.9)
## The hand, wrist to tip: its length.
@export var hand := 1.3
## A wing of skin has this many fingers; a feathered one this many long feathers
## fanned at its end.
@export_range(2, 7) var fingers := 4
## How far back the covert feathers along the front edge reach, against the
## wing's width. Zero for none.
@export_range(0.0, 1.0) var coverts := 0.0
## How far back the spread wings sweep, for every body radius they reach out.
@export var wing_sweep := 0.15
## How far the hand folds back along the arm when the wings are shut, in degrees.
@export var hand_fold := 150.0
## How wide a shut wing is against an open one: skin pleats up against the bones,
## feathers only slide over one another.
@export_range(0.1, 1.0) var fold_width := 0.3
## Beats a second, how far each swings, and the angle above flat it swings about,
## in degrees.
@export var flap_rate := 5.0
@export var flap_swing := 50.0
@export var flap_centre := 10.0


@export_group("Legs")

## How far below the middle of the body its feet are when it stands.
@export var stance := 0.6
@export var leg_thickness := 0.05
## Each toe's length. A parrot's point two forward and two back; anything else's
## three forward, as claws.
@export var toes := 0.1
## How far it tips its body back, nose up, to stand, in degrees: a parrot stands
## upright on its perch.
@export var perch := 0.0


@export_group("Tail")

## A tail of feathers this long and this wide. Zero for none.
@export var tail := 0.0
@export var tail_width := 0.18
## Which way it leaves the body, in degrees below straight back.
@export var tail_droop := 10.0


# --- the bones ----------------------------------------------------------------

func make_motion() -> CreatureMotion:
	return WingedMotion.new()


func build_bones(skeleton: Skeleton3D) -> void:
	skeleton.clear_bones()
	var at := _layout()
	var root := RigKit.add_bone(skeleton, "Root", -1, Transform3D.IDENTITY)
	var trunk := RigKit.add_bone(skeleton, "Body", root, Transform3D(Basis.IDENTITY, at["body"]))
	var neck: Vector3 = at["neck"]
	var face := RigKit.add_bone(skeleton, "Head", trunk, Transform3D(Basis.IDENTITY, neck))
	# What hangs off the head is laid out from the head, which sits unturned at the
	# neck: where it is in the skeleton is the neck plus that.
	var mouth := _mouth()
	RigKit.add_bone(skeleton, "Jaw", face,
		Transform3D(RigKit.along(mouth["direction"], Vector3.RIGHT), neck + mouth["hinge"]))
	for s in 2:
		var side := -1.0 if s == 0 else 1.0
		if ears != Vector2.ZERO:
			var flap := _ear(side)
			RigKit.add_bone(skeleton, "Ear.%s" % SIDES[s], face,
				Transform3D(RigKit.along(flap["direction"], Vector3.RIGHT), neck + flap["at"]))
		var blade := wing_rest(side)
		var shoulder := RigKit.add_bone(skeleton, wing_bone(s, 0), trunk,
			Transform3D(RigKit.along(blade["out"], Vector3.BACK), blade["at"]))
		RigKit.add_bone(skeleton, wing_bone(s, 1), shoulder,
			Transform3D(RigKit.along(blade["beyond"], Vector3.BACK), blade["wrist"]))
		var limb := leg_rest(side)
		var hip := RigKit.add_bone(skeleton, leg_bone(s, 0), trunk,
			Transform3D(RigKit.along(Vector3.DOWN, Vector3.RIGHT), limb["at"]))
		RigKit.add_bone(skeleton, leg_bone(s, 1), hip,
			Transform3D(RigKit.along(limb["foot"], Vector3.RIGHT), limb["ankle"]))
	if tail > 0.0:
		var rest := tail_rest()
		var parent := trunk
		for i in 2:
			parent = RigKit.add_bone(skeleton, "Tail.%d" % (i + 1), parent,
				Transform3D(RigKit.along(rest["direction"], Vector3.RIGHT), rest["joints"][i]))


## The name of a wing's bone: side 0 left or 1 right, part 0 the arm, 1 the hand.
static func wing_bone(side: int, part: int) -> String:
	return "Wing.%s.%s" % [SIDES[side], WING_PARTS[part]]


## The name of a leg's bone: side 0 left or 1 right, part 0 the leg, 1 the foot.
static func leg_bone(side: int, part: int) -> String:
	return "%s.%s" % [LEG_PARTS[part], SIDES[side]]


func reach_down() -> float:
	return stance


## Where the parts sit, in the body's space.
func _layout() -> Dictionary:
	var face_at := Vector3(0.0, head_lift, -(body.z * 0.8 + head.z * 0.45))
	var front := face_at.z - head.z
	if snout != Vector3.ZERO:
		front = minf(front, face_at.z - head.z * 0.7 - snout.z * 1.1)
	if beak != Vector2.ZERO:
		front = minf(front, face_at.z - head.z * 0.8 - beak.x * 0.6)
	var shift := Vector3(0.0, 0.0, -(front + body.z) * 0.5)
	return {
		"body": shift, "neck": Vector3(0.0, body.y * 0.3, -body.z * 0.7) + shift,
		"head": face_at + shift, "tail": Vector3(0.0, body.y * 0.1, body.z * 0.8) + shift,
	}


## A wing at rest, spread for flight: its shoulder, its wrist, and which way the
## arm and the hand run — out, and swept back a little, the hand more than the arm.
func wing_rest(side: float) -> Dictionary:
	# On the surface of the body, so a wing folded down its side hangs outside it.
	var at: Vector3 = _layout()["body"] + Vector3(side * body.x * 0.88, body.y * 0.42,
		-body.z * 0.3)
	var out := Vector3(side, 0.05, wing_sweep).normalized()
	return {
		"at": at, "out": out, "wrist": at + out * arm.x,
		"beyond": Vector3(side, 0.0, wing_sweep * 1.8).normalized(),
	}


## A leg at rest: its hip, its ankle, and which way the foot runs from there — so
## that standing, with the body tipped back on [member perch], the toes reach the
## floor [member stance] down.
func leg_rest(side: float) -> Dictionary:
	var shift: Vector3 = _layout()["body"]
	var hip := Vector3(side * body.x * 0.4, -body.y * 0.6, body.z * 0.2)
	var tip := deg_to_rad(perch)
	var tipped := hip.y * cos(tip) - hip.z * sin(tip)
	var length := maxf(stance + tipped - leg_thickness, 0.05)
	return {
		"at": hip + shift, "ankle": hip + shift + Vector3.DOWN * length, "length": length,
		"foot": Vector3(0.0, -leg_thickness, -toes).normalized(),
		"reach": Vector2(toes, leg_thickness).length(),
	}


## The tail at rest: where its two bones start, and which way it runs.
func tail_rest() -> Dictionary:
	var droop := deg_to_rad(tail_droop)
	var direction := Vector3(0.0, -sin(droop), cos(droop))
	var root: Vector3 = _layout()["tail"]
	return {"joints": [root, direction * tail * 0.5], "direction": direction}


## The jaw's hinge, under the face, in the head's space, and which way it runs: a
## bat's lower jaw, or a parrot's lower beak.
func _mouth() -> Dictionary:
	var at := _layout()
	var face_at: Vector3 = at["head"] - at["neck"]
	if beak != Vector2.ZERO:
		return {"hinge": face_at + Vector3(0.0, -head.y * 0.35, -head.z * 0.7),
			"direction": Vector3(0.0, -0.5, -1.0).normalized(), "length": beak.x * 0.5}
	var muzzle := _muzzle()
	return {"hinge": muzzle + Vector3(0.0, -snout.y * 0.6, snout.z * 0.5),
		"direction": Vector3(0.0, -0.15, -1.0).normalized(), "length": snout.z * 1.2}


## Where the snout sits, in the head bone's space.
func _muzzle() -> Vector3:
	var at := _layout()
	var face_at: Vector3 = at["head"] - at["neck"]
	return face_at + Vector3(0.0, -head.y * 0.3, -(head.z * 0.72 + snout.z * 0.5))


func _ear(side: float) -> Dictionary:
	var at := _layout()
	var face_at: Vector3 = at["head"] - at["neck"]
	var lean := deg_to_rad(ear_lean)
	return {
		"at": face_at + Vector3(side * head.x * 0.5, head.y * 0.62, head.z * 0.05),
		"direction": Vector3(side * sin(lean), cos(lean), 0.12).normalized(),
	}


# --- the mesh -----------------------------------------------------------------

## One mesh in three surfaces: the body in its flat colours, the parts that shine,
## and the wings, drawn from both sides.
func build_mesh(skeleton: Skeleton3D) -> ArrayMesh:
	var fur := RigKit.begin()
	var shine := RigKit.begin()
	var blades := RigKit.begin()
	var at := _layout()
	var forward := RigKit.along(Vector3.FORWARD, Vector3.RIGHT)
	var trunk := skeleton.find_bone("Body")
	var face := skeleton.find_bone("Head")
	var face_at: Vector3 = at["head"] - at["neck"]

	RigKit.lathe(fur, skeleton, trunk, Transform3D(forward, Vector3.ZERO),
		RigKit.ovoid(body, body_point, 16, func(_y: float) -> Callable: return _coat()), 20)
	var eyes: Array[Vector3] = []
	for side in [-1.0, 1.0]:
		eyes.append(face_at + Vector3(side * head.x * lerpf(0.42, 0.62, eye_spread),
			head.y * 0.22, -head.z * lerpf(0.66, 0.5, eye_spread)))
	RigKit.lathe(fur, skeleton, face, Transform3D(forward, face_at),
		RigKit.ovoid(head, 0.0, 12, func(_y: float) -> Callable: return _face_paint(eyes)), 18)
	for s in 2:
		var side := -1.0 if s == 0 else 1.0
		var look := Vector3(side * eye_spread, 0.1, -1.0 + eye_spread * 0.4).normalized()
		RigKit.eye(shine, skeleton, face, eyes[s], look, eye, eye_colour, eye_white, eye_ring)
		if ears != Vector2.ZERO:
			RigKit.ear(fur, skeleton, skeleton.find_bone("Ear.%s" % SIDES[s]), ears.x, ears.y,
				ears.x * 0.1, 0.7, ear_colour, ear_inside)
	if beak != Vector2.ZERO:
		_build_beak(fur, shine, skeleton, face_at)
	if snout != Vector3.ZERO:
		_build_snout(fur, shine, skeleton)

	for s in 2:
		_build_wing(blades, fur, skeleton, s)
		var limb := leg_rest(-1.0 if s == 0 else 1.0)
		RigKit.segment(fur, skeleton, skeleton.find_bone(leg_bone(s, 0)), limb["length"],
			leg_thickness, leg_thickness * 0.85, RigKit.plain(leg_colour), RigKit.Cut.new(8, 1, 3))
		_build_toes(fur, skeleton, skeleton.find_bone(leg_bone(s, 1)))

	if tail > 0.0:
		for i in 2:
			var from := tail_width * (0.55 if i == 0 else 1.0)
			var to := tail_width * (1.0 if i == 0 else 0.75)
			var rows: Array = []
			for k in 7:
				var t := float(k) / 6.0
				var across := lerpf(from, to, t)
				if i == 1:
					# Rounded off at the end.
					across *= sqrt(maxf(1.0 - pow(t, 4.0), 0.0))
				rows.append([t * tail * 0.5 * 1.04, across, tail_width * 0.12,
					tail_colour if i == 0 else tail_tip_colour])
			RigKit.lathe(fur, skeleton, skeleton.find_bone("Tail.%d" % (i + 1)),
				Transform3D.IDENTITY, rows, 10)

	return RigKit.commit([fur, shine, blades], [RigKit.shell_material(1.0 - gloss, 0.0, 0.4),
		RigKit.gloss_material(), RigKit.membrane_material(false, 0.85)])


## A wing on side [param s]: for a wing of skin, the skin between the body and
## the wrist on the arm and between the fingers on the hand, with the bones along
## it; for feathers, the flight feathers on both and the coverts over their front
## edge, on both faces.
func _build_wing(blades: SurfaceTool, fur: SurfaceTool, skeleton: Skeleton3D, s: int) -> void:
	var shoulder := skeleton.find_bone(wing_bone(s, 0))
	var palm := skeleton.find_bone(wing_bone(s, 1))
	var chord := arm.y
	var reach := arm.x
	if not feathered:
		RigKit.panel(blades, skeleton, shoulder, PackedVector2Array([
			Vector2(-0.04, 0.0), Vector2(-0.04, reach), Vector2(chord * 0.35, reach),
			Vector2(chord * 0.75, reach * 0.55), Vector2(chord, 0.12)]),
			Vector2(chord * 0.35, reach * 0.45), wing_colour, wing_rim, 0.06)
		RigKit.panel(blades, skeleton, palm, _finger_outline(chord),
			Vector2(hand * 0.12, hand * 0.22), wing_colour, wing_rim, 0.06)
		RigKit.lathe(fur, skeleton, shoulder, Transform3D.IDENTITY,
			RigKit.capsule(reach, 0.035, bone_colour, 2), 6)
		for tip in _finger_tips():
			var run: Vector2 = tip
			RigKit.lathe(fur, skeleton, palm, Transform3D(RigKit.along(Vector3(run.x, run.y, 0.0),
				Vector3.BACK), Vector3.ZERO), [
					[0.0, 0.025, 0.025, bone_colour], [run.length() * 0.85, 0.016, 0.016, bone_colour],
					[run.length(), 0.0, 0.0, bone_colour]], 5)
		return
	var ends := PackedVector2Array([Vector2(-0.04, 0.0), Vector2(-0.04, reach),
		Vector2(chord * 0.9, reach)])
	for k in range(1, 5):
		var y := reach * (1.0 - float(k) / 5.0)
		ends.append(Vector2(chord * 0.86, y + reach * 0.1))
		ends.append(Vector2(chord, y))
	ends.append(Vector2(chord * 0.85, 0.0))
	RigKit.panel(blades, skeleton, shoulder, ends, Vector2(chord * 0.4, reach * 0.5), wing_colour,
		wing_rim, 0.14)
	RigKit.panel(blades, skeleton, palm, _feather_outline(chord), Vector2(chord * 0.3, hand * 0.3),
		wing_colour, wing_rim, 0.14)
	if coverts > 0.0:
		var side := -1.0 if s == 0 else 1.0
		for lift in [0.015, -0.015]:
			RigKit.panel(blades, skeleton, shoulder, PackedVector2Array([Vector2(-0.05, 0.0),
				Vector2(-0.05, reach), Vector2(chord * coverts, reach * 0.96),
				Vector2(chord * coverts * 1.05, 0.0)]), Vector2(chord * coverts * 0.5, reach * 0.5),
				covert_colour, covert_colour.darkened(0.15), 0.1, side * lift)
			RigKit.panel(blades, skeleton, palm, PackedVector2Array([Vector2(-0.05, 0.0),
				Vector2(-0.05, hand * 0.42), Vector2(chord * coverts * 0.85, hand * 0.28),
				Vector2(chord * coverts, 0.0)]), Vector2(chord * coverts * 0.4, hand * 0.18),
				covert_colour, covert_colour.darkened(0.15), 0.1, side * lift)


## Where each finger of a wing of skin ends, from the wrist: the first out along
## the hand, the last pointing back to meet the arm's skin.
func _finger_tips() -> Array[Vector2]:
	var tips: Array[Vector2] = []
	for k in fingers:
		var t := float(k) / float(maxi(fingers - 1, 1))
		var angle := deg_to_rad(lerpf(2.0, 100.0, t))
		tips.append(Vector2(sin(angle), cos(angle)) * hand * lerpf(1.0, 0.55, t))
	return tips


## The edge of the skin between the fingers: out along the first, then a scallop
## in between each and the next, and back to the arm's skin at the wrist.
func _finger_outline(chord: float) -> PackedVector2Array:
	var tips := _finger_tips()
	var outline := PackedVector2Array([Vector2(-0.03, 0.0)])
	for k in tips.size():
		outline.append(tips[k])
		if k + 1 < tips.size():
			outline.append((tips[k] + tips[k + 1]) * 0.5 * 0.72)
	outline.append(Vector2(chord * 0.33, 0.0))
	return outline


## The edge of a hand of feathers: along the front, round the fan of long ones at
## its end, and back to the arm's feathers at the wrist.
func _feather_outline(chord: float) -> PackedVector2Array:
	var outline := PackedVector2Array([Vector2(-0.04, 0.0), Vector2(-0.04, hand * 0.55)])
	for k in fingers:
		var t := float(k) / float(maxi(fingers - 1, 1))
		var angle := deg_to_rad(lerpf(4.0, 50.0, t))
		var tip := Vector2(sin(angle), cos(angle)) * hand * lerpf(1.0, 0.72, t)
		outline.append(tip)
		if k + 1 < fingers:
			var next := deg_to_rad(lerpf(4.0, 50.0, float(k + 1) / float(maxi(fingers - 1, 1))))
			var middle := (angle + next) * 0.5
			outline.append(Vector2(sin(middle), cos(middle)) * hand * lerpf(1.0, 0.72, t) * 0.9)
	outline.append(Vector2(chord * 0.9, hand * 0.1))
	outline.append(Vector2(chord * 0.85, 0.0))
	return outline


## A hooked beak: the top half from the face out and then down to a point, the
## bottom half on the jaw so it opens.
func _build_beak(fur: SurfaceTool, shine: SurfaceTool, skeleton: Skeleton3D,
		face_at: Vector3) -> void:
	var face := skeleton.find_bone("Head")
	var root := face_at + Vector3(0.0, -head.y * 0.05, -head.z * 0.78)
	var out := Vector3(0.0, -0.2, -1.0).normalized()
	var reach := beak.x * 0.5
	var girth := beak.y * 0.5
	RigKit.lathe(shine, skeleton, face, Transform3D(RigKit.along(out, Vector3.RIGHT), root), [
		[-girth * 0.3, girth * 0.95, girth * 0.95, beak_colour],
		[0.0, girth, girth, beak_colour],
		[reach * 0.6, girth * 0.8, girth * 0.82, beak_colour],
		[reach, girth * 0.58, girth * 0.62, beak_colour]], 14)
	var bend := root + out * reach
	RigKit.ellipsoid(shine, skeleton, face, bend, Vector3(girth * 0.58, girth * 0.62, girth * 0.62),
		RigKit.plain(beak_colour), 12, 8)
	var hook := Vector3(0.0, -1.0, 0.45).normalized()
	RigKit.lathe(shine, skeleton, face, Transform3D(RigKit.along(hook, Vector3.RIGHT), bend), [
		[0.0, girth * 0.58, girth * 0.62, beak_colour],
		[beak.x * 0.34, girth * 0.36, girth * 0.4, beak_colour],
		[beak.x * 0.56, 0.0, 0.0, beak_colour]], 12)
	var chin := skeleton.find_bone("Jaw")
	var mouth := _mouth()
	var length: float = mouth["length"]
	RigKit.lathe(shine, skeleton, chin, Transform3D.IDENTITY, [
		[-girth * 0.2, girth * 0.7, girth * 0.4, jaw_colour],
		[length * 0.5, girth * 0.6, girth * 0.38, jaw_colour],
		[length, 0.0, 0.0, jaw_colour]], 12)
	# Dark in the throat, for when it opens.
	RigKit.ellipsoid(fur, skeleton, face, root + Vector3(0.0, -girth * 0.6, 0.0),
		Vector3(girth * 0.6, girth * 0.35, girth * 0.7), RigKit.plain(Color(0.25, 0.08, 0.1)), 10, 6)


## A short snout with a flat nose on the end, like a pig's, a jaw under it, and
## fangs when it has any.
func _build_snout(fur: SurfaceTool, shine: SurfaceTool, skeleton: Skeleton3D) -> void:
	var face := skeleton.find_bone("Head")
	var muzzle := _muzzle()
	RigKit.lathe(fur, skeleton, face, Transform3D(RigKit.along(Vector3.FORWARD, Vector3.RIGHT),
		muzzle), RigKit.ovoid(Vector3(snout.x, snout.y, snout.z * 0.5), 0.2, 8,
			RigKit.solid(colour)), 14)
	var front := muzzle + Vector3(0.0, snout.y * 0.15, -snout.z * 0.5)
	RigKit.ellipsoid(shine, skeleton, face, front, Vector3(nose * 1.25, nose * 0.95, nose * 0.45),
		RigKit.plain(nose_colour), 14, 8)
	for side in [-1.0, 1.0]:
		RigKit.ellipsoid(shine, skeleton, face, front + Vector3(side * nose * 0.42, 0.0,
			-nose * 0.36), Vector3(nose * 0.22, nose * 0.3, nose * 0.14),
			RigKit.plain(Color(0.08, 0.04, 0.04)), 8, 5)
	var chin := skeleton.find_bone("Jaw")
	var mouth := _mouth()
	var length: float = mouth["length"]
	RigKit.lathe(fur, skeleton, chin, Transform3D.IDENTITY, RigKit.ovoid(Vector3(snout.x * 0.8,
		snout.y * 0.45, length * 0.5), 0.3, 8, RigKit.solid(jaw_colour)).map(
			func(row: Array) -> Array: return [row[0] + length * 0.5, row[1], row[2], row[3]]), 12)
	var hinge: Vector3 = mouth["hinge"]
	RigKit.ellipsoid(fur, skeleton, face, hinge + Vector3(0.0, snout.y * 0.25, -length * 0.45),
		Vector3(snout.x * 0.7, snout.y * 0.3, length * 0.45), RigKit.plain(Color(0.3, 0.06, 0.08)),
		10, 6)
	if fangs > 0.0:
		for side in [-1.0, 1.0]:
			var root := muzzle + Vector3(side * snout.x * 0.42, -snout.y * 0.55, -snout.z * 0.28)
			RigKit.lathe(fur, skeleton, face, Transform3D(RigKit.along(Vector3.DOWN,
				Vector3.RIGHT), root), [[0.0, 0.026, 0.026, Color(0.98, 0.96, 0.9)],
					[fangs * 0.6, 0.02, 0.02, Color(0.98, 0.96, 0.9)],
					[fangs, 0.0, 0.0, Color(0.98, 0.96, 0.9)]], 6)


## The toes on a foot: two forward and two back for something feathered, three
## forward as claws for anything else.
func _build_toes(fur: SurfaceTool, skeleton: Skeleton3D, foot: int) -> void:
	var spread := [-0.35, 0.35, PI - 0.3, PI + 0.3] if feathered else [-0.4, 0.0, 0.4]
	for angle in spread:
		var run := Vector3(sin(angle) * 0.9, cos(angle), 0.0).normalized()
		RigKit.lathe(fur, skeleton, foot, Transform3D(RigKit.along(run, Vector3.BACK), Vector3.ZERO),
			RigKit.capsule(toes, leg_thickness * 0.55, leg_colour, 2), 6)


## Paints the body: its own colour above, the belly's below.
func _coat() -> Callable:
	return func(n: Vector3, _p: Vector3) -> Color:
		return belly_colour if n.y < -0.3 else colour


## Paints the head: its own colour, with a patch round each of [param eyes] when
## it has a face.
func _face_paint(eyes: Array[Vector3]) -> Callable:
	return func(_n: Vector3, p: Vector3) -> Color:
		var bare := 0.0
		if face > 0.0:
			for centre in eyes:
				bare = maxf(bare, smoothstep(face, face * 0.75, p.distance_to(centre)))
		return colour.lerp(face_colour, bare)
