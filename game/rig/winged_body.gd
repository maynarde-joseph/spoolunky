class_name WingedBody
extends CreatureBody

## Something that flies on two wings: a body, a head, two wings of two bones each —
## an arm out to the wrist and a hand beyond it — two legs, and a tail if it has
## one. A bat is this with skin stretched between its fingers and ears as tall as
## its head; a parrot is this with feathers and a hooked beak; a wyvern is a bat's
## wings on something with horns and a long whip of a tail. What tells them apart
## is numbers in a .tres of it.
##
## Drawn the minimal way, as the spider and the insects are: smooth parts, thin
## legs of one width, flat wings with a rim round them, a few flat colours, and
## two small eyes that shine a little. Nothing that does not help the silhouette.
## Every length is in body radii and every angle in degrees; forward is -Z and up
## is +Y. From the front of its face to the back of its body it is centred on the
## creature's middle, and the wings reach out of that the way an insect's do.

const SIDES := ["L", "R"]
## A wing's two bones: shoulder to wrist, and wrist to tip.
const WING_PARTS := ["Arm", "Hand"]
const LEG_PARTS := ["Leg", "Foot"]


@export_group("Colours")

## Fur or feathers: the body and the head.
@export var colour := Color(0.36, 0.27, 0.22)
## A wing's skin, or its flight feathers, and a band round the edge of either. The
## finger bones in a wing of skin are the band's colour.
@export var wing_colour := Color(0.24, 0.19, 0.2)
@export var wing_rim := Color(0.18, 0.14, 0.15)
## The small feathers along a wing's front edge, when [member coverts] asks for any.
@export var covert_colour := Color(0.95, 0.8, 0.1)
## The beak, both halves.
@export var beak_colour := Color(0.92, 0.88, 0.8)
@export var ear_colour := Color(0.36, 0.27, 0.22)
@export var leg_colour := Color(0.25, 0.2, 0.2)
@export var tail_colour := Color(0.8, 0.1, 0.1)
@export var eye_colour := Color(0.03, 0.02, 0.02)


@export_group("Body")

## The body's radii: across, up and along.
@export var body := Vector3(0.42, 0.42, 0.55)
## How much narrower it is at the front than the back: 0 an egg, 1 a pear.
@export_range(0.0, 1.0) var body_point := 0.2
## The head's radii, and how high it is carried above the middle of the body.
@export var head := Vector3(0.36, 0.34, 0.32)
@export var head_lift := 0.25
## Each eye's radius, and how far round the head the eyes sit: 0 looking straight
## ahead, 1 out to the sides.
@export var eye := 0.05
@export_range(0.0, 1.0) var eye_spread := 0.35
## A short snout: radii across, up and along. Zero for none.
@export var snout := Vector3(0.12, 0.1, 0.14)
## A hooked beak this long and this deep at its root. Zero for none.
@export var beak := Vector2.ZERO
## Ears this wide and this long. Zero for none.
@export var ears := Vector2.ZERO
## How far out from upright the ears lean, in degrees.
@export var ear_lean := 20.0
## A pair of horns this long and this thick at the root, sweeping back off the top
## of the head and curling down: a wyvern's. Zero for none.
@export var horns := Vector2.ZERO
@export var horn_colour := Color(0.82, 0.76, 0.62)


@export_group("Wings")

## Feathers, or skin stretched between the fingers.
@export var feathered := false
## The arm, shoulder to wrist: its length, and how wide the wing is along it.
@export var arm := Vector2(0.9, 0.9)
## The hand, wrist to tip: its length.
@export var hand := 1.3
## A wing of skin has this many fingers; a feathered one this many long feathers
## rounding off its end.
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
## How thick every part of a leg is, from the hip to the floor.
@export var leg_thickness := 0.05
## How far forward the foot reaches from the ankle, along the floor.
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
## A long whip of a tail instead of a fan of feathers: this long, in
## [member whip_bones] bones, tapering from the first of [member whip_thickness] at
## the root to the second at the tip. Zero for none.
@export var whip := 0.0
@export_range(2, 10) var whip_bones := 6
@export var whip_thickness := Vector2(0.16, 0.02)


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
	if whip > 0.0:
		var lash := whip_rest()
		var parent := trunk
		for i in whip_bones:
			parent = RigKit.add_bone(skeleton, "Tail.%d" % (i + 1), parent,
				Transform3D(RigKit.along(lash["directions"][i], Vector3.RIGHT), lash["joints"][i]))
	elif tail > 0.0:
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
	return {"joints": [root, root + direction * tail * 0.5], "direction": direction}


## A whip of a tail at rest: where each bone starts and which way it runs — back
## and a little down from the body, lifting a little toward the tip.
func whip_rest() -> Dictionary:
	var joints: Array[Vector3] = [_layout()["tail"]]
	var directions: Array[Vector3] = []
	var piece := whip / float(whip_bones)
	for i in whip_bones:
		var pitch := deg_to_rad(-tail_droop + 3.0 * float(i))
		directions.append(Vector3(0.0, sin(pitch), cos(pitch)))
		joints.append(joints[i] + directions[i] * piece)
	return {"joints": joints, "directions": directions, "piece": piece}


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

## One mesh in three surfaces: everything but the eyes and the wings in its few
## flat colours, the eyes, and the wings, drawn from both sides.
func build_mesh(skeleton: Skeleton3D) -> ArrayMesh:
	var coat := RigKit.begin()
	var shine := RigKit.begin()
	var blades := RigKit.begin()
	var at := _layout()
	var forward := RigKit.along(Vector3.FORWARD, Vector3.RIGHT)
	var trunk := skeleton.find_bone("Body")
	var face := skeleton.find_bone("Head")
	var face_at: Vector3 = at["head"] - at["neck"]

	RigKit.lathe(coat, skeleton, trunk, Transform3D(forward, Vector3.ZERO),
		RigKit.ovoid(body, body_point, 16, RigKit.solid(colour)), 20)
	RigKit.lathe(coat, skeleton, face, Transform3D(forward, face_at),
		RigKit.ovoid(head, 0.0, 12, RigKit.solid(colour)), 18)
	for s in 2:
		var side := -1.0 if s == 0 else 1.0
		# Set into the head, a little proud of it.
		var toward := Vector3(side * lerpf(0.35, 0.8, eye_spread), 0.3,
			-lerpf(0.87, 0.5, eye_spread)).normalized()
		RigKit.ellipsoid(shine, skeleton, face, face_at + toward * head - toward * eye * 0.4,
			Vector3.ONE * eye, RigKit.plain(eye_colour), 10, 6)
		if ears != Vector2.ZERO:
			RigKit.ear(coat, skeleton, skeleton.find_bone("Ear.%s" % SIDES[s]), ears.x, ears.y,
				ears.x * 0.16, 0.7, ear_colour, -side * 25.0)
	if beak != Vector2.ZERO:
		_build_beak(coat, skeleton, face_at)
	if snout != Vector3.ZERO:
		_build_snout(coat, skeleton)
	if horns != Vector2.ZERO:
		for side in [-1.0, 1.0]:
			RigKit.horn(coat, skeleton, face,
				face_at + Vector3(side * head.x * 0.45, head.y * 0.7, head.z * 0.15),
				Vector3(side * 0.3, 0.55, 0.78), Vector3.RIGHT, horns.x, horns.y, 45.0, horn_colour)

	# Legs of one width, a round end at the ankle, and the foot the same rod on
	# along the floor.
	var rod := RigKit.Cut.new(8, 1, 3)
	for s in 2:
		_build_wing(blades, coat, skeleton, s)
		var limb := leg_rest(-1.0 if s == 0 else 1.0)
		RigKit.segment(coat, skeleton, skeleton.find_bone(leg_bone(s, 0)), limb["length"],
			leg_thickness, leg_thickness, RigKit.plain(leg_colour), rod)
		RigKit.segment(coat, skeleton, skeleton.find_bone(leg_bone(s, 1)), limb["reach"],
			leg_thickness, leg_thickness, RigKit.plain(leg_colour), rod)

	if whip > 0.0:
		var lash := whip_rest()
		var piece: float = lash["piece"]
		for i in whip_bones:
			var from := lerpf(whip_thickness.x, whip_thickness.y, float(i) / float(whip_bones))
			var to := lerpf(whip_thickness.x, whip_thickness.y, float(i + 1) / float(whip_bones))
			RigKit.segment(coat, skeleton, skeleton.find_bone("Tail.%d" % (i + 1)), piece, from, to,
				RigKit.plain(tail_colour), rod)
	elif tail > 0.0:
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
				rows.append([t * tail * 0.5 * 1.04, across, tail_width * 0.12, tail_colour])
			RigKit.lathe(coat, skeleton, skeleton.find_bone("Tail.%d" % (i + 1)),
				Transform3D.IDENTITY, rows, 10)

	return RigKit.commit([coat, shine, blades], [RigKit.shell_material(0.75, 0.0, 0.3),
		RigKit.eye_material(eye_colour, eye_colour, 0.15), RigKit.membrane_material(false, 0.75)])


## A wing on side [param s]: for a wing of skin, the skin between the body and
## the wrist on the arm and between the fingers on the hand, with a thin rod along
## each bone; for feathers, the flight feathers on both and a band of coverts over
## their front edge, on both faces.
func _build_wing(blades: SurfaceTool, coat: SurfaceTool, skeleton: Skeleton3D, s: int) -> void:
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
		var rod := RigKit.Cut.new(6, 1, 2)
		RigKit.segment(coat, skeleton, shoulder, reach, 0.022, 0.022, RigKit.plain(wing_rim), rod)
		for tip in _finger_tips():
			var run: Vector2 = tip
			RigKit.lathe(coat, skeleton, palm, Transform3D(RigKit.along(Vector3(run.x, run.y, 0.0),
				Vector3.BACK), Vector3.ZERO), RigKit.capsule(run.length(), 0.022, wing_rim, 2), 6)
		return
	# Feathers: a smooth edge, the trailing one a little rounded out.
	var edge := PackedVector2Array([Vector2(-0.04, 0.0), Vector2(-0.04, reach),
		Vector2(chord * 0.9, reach)])
	for k in range(1, 5):
		edge.append(Vector2(chord * (0.9 + 0.1 * sin(PI * float(k) / 5.0)),
			reach * (1.0 - float(k) / 5.0)))
	edge.append(Vector2(chord * 0.85, 0.0))
	RigKit.panel(blades, skeleton, shoulder, edge, Vector2(chord * 0.4, reach * 0.5), wing_colour,
		wing_rim, 0.1)
	RigKit.panel(blades, skeleton, palm, _feather_outline(chord), Vector2(chord * 0.3, hand * 0.3),
		wing_colour, wing_rim, 0.1)
	if coverts > 0.0:
		var side := -1.0 if s == 0 else 1.0
		for lift in [0.015, -0.015]:
			RigKit.panel(blades, skeleton, shoulder, PackedVector2Array([Vector2(-0.05, 0.0),
				Vector2(-0.05, reach), Vector2(chord * coverts, reach * 0.96),
				Vector2(chord * coverts * 1.05, 0.0)]), Vector2(chord * coverts * 0.5, reach * 0.5),
				covert_colour, covert_colour, 0.1, side * lift)
			RigKit.panel(blades, skeleton, palm, PackedVector2Array([Vector2(-0.05, 0.0),
				Vector2(-0.05, hand * 0.42), Vector2(chord * coverts * 0.85, hand * 0.28),
				Vector2(chord * coverts, 0.0)]), Vector2(chord * coverts * 0.4, hand * 0.18),
				covert_colour, covert_colour, 0.1, side * lift)


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


## The edge of a hand of feathers: along the front, round the end in one smooth
## curve where the long feathers are, and back to the arm's feathers at the wrist.
func _feather_outline(chord: float) -> PackedVector2Array:
	var outline := PackedVector2Array([Vector2(-0.04, 0.0), Vector2(-0.04, hand * 0.55)])
	var count := fingers * 2
	for k in count:
		var t := float(k) / float(count - 1)
		var angle := deg_to_rad(lerpf(4.0, 50.0, t))
		outline.append(Vector2(sin(angle), cos(angle)) * hand * lerpf(1.0, 0.72, t))
	outline.append(Vector2(chord * 0.9, hand * 0.1))
	outline.append(Vector2(chord * 0.85, 0.0))
	return outline


## A hooked beak, in one colour: the top half from the face out and then down to a
## point, the bottom half on the jaw so it opens.
func _build_beak(coat: SurfaceTool, skeleton: Skeleton3D, face_at: Vector3) -> void:
	var face := skeleton.find_bone("Head")
	var root := face_at + Vector3(0.0, -head.y * 0.05, -head.z * 0.78)
	var out := Vector3(0.0, -0.2, -1.0).normalized()
	var reach := beak.x * 0.5
	var girth := beak.y * 0.5
	RigKit.lathe(coat, skeleton, face, Transform3D(RigKit.along(out, Vector3.RIGHT), root), [
		[-girth * 0.3, girth * 0.95, girth * 0.95, beak_colour],
		[0.0, girth, girth, beak_colour],
		[reach * 0.6, girth * 0.8, girth * 0.82, beak_colour],
		[reach, girth * 0.58, girth * 0.62, beak_colour]], 14)
	var bend := root + out * reach
	RigKit.ellipsoid(coat, skeleton, face, bend, Vector3(girth * 0.58, girth * 0.62, girth * 0.62),
		RigKit.plain(beak_colour), 12, 8)
	var hook := Vector3(0.0, -1.0, 0.45).normalized()
	RigKit.lathe(coat, skeleton, face, Transform3D(RigKit.along(hook, Vector3.RIGHT), bend), [
		[0.0, girth * 0.58, girth * 0.62, beak_colour],
		[beak.x * 0.34, girth * 0.36, girth * 0.4, beak_colour],
		[beak.x * 0.56, 0.0, 0.0, beak_colour]], 12)
	var length: float = _mouth()["length"]
	RigKit.lathe(coat, skeleton, skeleton.find_bone("Jaw"), Transform3D.IDENTITY, [
		[-girth * 0.2, girth * 0.7, girth * 0.4, beak_colour],
		[length * 0.5, girth * 0.6, girth * 0.38, beak_colour],
		[length, 0.0, 0.0, beak_colour]], 12)


## A short snout, and a lower jaw under it so the mouth can open, both in the
## body's colour.
func _build_snout(coat: SurfaceTool, skeleton: Skeleton3D) -> void:
	var face := skeleton.find_bone("Head")
	RigKit.lathe(coat, skeleton, face, Transform3D(RigKit.along(Vector3.FORWARD, Vector3.RIGHT),
		_muzzle()), RigKit.ovoid(Vector3(snout.x, snout.y, snout.z * 0.5), 0.2, 8,
			RigKit.solid(colour)), 14)
	var length: float = _mouth()["length"]
	RigKit.lathe(coat, skeleton, skeleton.find_bone("Jaw"), Transform3D.IDENTITY,
		RigKit.ovoid(Vector3(snout.x * 0.8, snout.y * 0.45, length * 0.5), 0.3, 8,
			RigKit.solid(colour)).map(
			func(row: Array) -> Array: return [row[0] + length * 0.5, row[1], row[2], row[3]]), 12)
