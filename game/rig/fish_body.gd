class_name FishBody
extends CreatureBody

## Something that swims with its tail: a body shaped like a teardrop that bends
## where the tail starts, a fin on the end of the tail, one on its back and one
## beneath, two at its sides that paddle, big eyes and a mouth that gulps. A
## goldfish is this and so is a shark; what tells them apart is numbers in a .tres
## of it.
##
## Drawn like the rest, minimal and a little goofy. Every length is in body radii
## and every angle in degrees; forward is -Z and up is +Y. From its nose to the
## root of its tail fin it is centred on the creature's middle, and the fins reach
## out of that the way an insect's legs do.
##
## The body is one profile turned on a lathe and cut in two where the tail bends,
## each half closed off with a round end tucked inside the other: straight, it is
## one smooth teardrop; bent, the crease is where the tail starts, as it is on a
## fish.

const SIDES := ["L", "R"]

## How far past the cut each half of the body reaches, in body radii, tucked
## inside the other so the tail can bend without opening a gap.
const TUCK := 0.3


@export_group("Colours")

## Its back and sides.
@export var colour := Color(0.95, 0.5, 0.12)
## Beneath, from where [member belly_line] says.
@export var belly_colour := Color(0.98, 0.85, 0.6)
## Where the belly's colour starts, from the top of its sides (1) to the bottom
## (-1): a shark is pale further up than a goldfish.
@export_range(-1.0, 1.0) var belly_line := -0.45
@export var fin_colour := Color(0.98, 0.6, 0.2)
@export var fin_rim := Color(0.9, 0.42, 0.1)
@export var lip_colour := Color(0.98, 0.62, 0.4)
## The middle of each eye, and what shows round it.
@export var eye_colour := Color(0.03, 0.03, 0.03)
@export var eye_ring := Color(0.95, 0.94, 0.9)
@export var gill_colour := Color(0.2, 0.22, 0.25)
## How wet it looks.
@export_range(0.0, 1.0) var gloss := 0.45


@export_group("Body")

## Its radii across and up, and half its length from the nose to the root of the
## tail fin.
@export var body := Vector3(0.36, 0.58, 1.0)
## Where along it the body is deepest, from the nose (-1) to the tail (1).
@export_range(-0.8, 0.8) var deepest := -0.15
## How pointed the nose is: 0 round, 1 a point.
@export_range(0.0, 1.0) var nose_point := 0.1
## How thick the tail is where its fin starts, against the body's depth.
@export_range(0.05, 0.6) var wrist := 0.22
## Where the tail bends from the body, from the nose (-1) to the tail (1).
@export_range(-0.5, 0.8) var bend_at := 0.25


@export_group("Face")

## Each eye's radius, and how much of it is white round the middle.
@export var eye := 0.17
@export_range(0.0, 1.0) var eye_white := 0.5
## Lips this thick round the mouth, pouting. Zero for none.
@export var lips := 0.1
## How wide the mouth is, and how far under the middle of the nose it sits.
@export var mouth := Vector2(0.14, 0.0)
## How far back from the tip of the nose the mouth is: none for a goldfish's,
## pouting at the front; a shark's is underneath.
@export var mouth_back := 0.0
## Teeth this long all along the mouth: a shark's grin. Zero for none. A mouth
## with teeth is under the snout with a jaw below it; one without pouts at the
## front.
@export var teeth := 0.0
## How far open the mouth hangs when nothing is happening, in degrees: a grin.
@export var grin := 0.0
## This many gill slits down each side. None for gills that do not show.
@export_range(0, 6) var gills := 0


@export_group("Fins")

## The tail fin: how tall and how long.
@export var tail_fin := Vector2(0.9, 0.7)
## How deeply the tail fin is forked, from a fan (0) to two lobes (1).
@export_range(0.0, 1.0) var fork := 0.35
## How much longer the top lobe is than the bottom one: a shark's is far longer.
@export var lobe := 1.0
## The fin on its back: how tall and how long, how far back it leans in degrees,
## and where it stands along the back, from the nose (-1) to the tail (1).
@export var dorsal := Vector2(0.45, 0.8)
@export var dorsal_sweep := 30.0
@export_range(-0.9, 0.9) var dorsal_at := -0.1
## The fin beneath the tail: how tall and how long. Zero for none.
@export var anal := Vector2(0.2, 0.3)
## The fins at its sides that paddle: how long and how wide, and how far below
## straight out they point, in degrees.
@export var pectoral := Vector2(0.45, 0.25)
@export var pectoral_droop := 25.0


@export_group("Swimming")

## Beats of the tail a second at a cruise, and how far it swings each way, in
## degrees.
@export var beat_rate := 2.0
@export var swing := 22.0


# --- the bones ----------------------------------------------------------------

func make_motion() -> CreatureMotion:
	return FishMotion.new()


func build_bones(skeleton: Skeleton3D) -> void:
	skeleton.clear_bones()
	var root := RigKit.add_bone(skeleton, "Root", -1, Transform3D.IDENTITY)
	var trunk := RigKit.add_bone(skeleton, "Body", root, Transform3D.IDENTITY)
	var jaw := jaw_rest()
	RigKit.add_bone(skeleton, "Jaw", trunk,
		Transform3D(RigKit.along(jaw["direction"], Vector3.RIGHT), jaw["at"]))
	for s in 2:
		var paddle := pectoral_rest(-1.0 if s == 0 else 1.0)
		RigKit.add_bone(skeleton, "Pectoral.%s" % SIDES[s], trunk,
			Transform3D(RigKit.along(paddle["direction"], Vector3.BACK), paddle["at"]))
	var tail := RigKit.add_bone(skeleton, "Tail", trunk,
		Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, bend_at * body.z)))
	RigKit.add_bone(skeleton, "Fin", tail, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, body.z)))


## How far below the middle of the body the floor is when it lies on its side,
## out of the water: half its width.
func reach_down() -> float:
	return body.x * 0.95


## How deep the body is at [param u] along it, from the nose (-1) to the root of
## the tail (1), against its depth at its deepest: an egg toward the nose, round
## or pointed, and narrowing to the wrist of the tail behind.
func girth(u: float) -> float:
	if u < deepest:
		var t := clampf((u - deepest) / (-1.0 - deepest), 0.0, 1.0)
		var round := sqrt(maxf(1.0 - t * t, 0.0))
		return pow(round, 1.0 - nose_point) * pow(1.0 - t, nose_point * 0.8)
	var t := clampf((u - deepest) / (1.0 - deepest), 0.0, 1.0)
	return wrist + (1.0 - wrist) * pow(cos(t * PI * 0.5), 1.3)


## A side fin at rest: where it leaves the body, and which way it points — out,
## down a little and back.
func pectoral_rest(side: float) -> Dictionary:
	var u := -0.4
	var droop := deg_to_rad(pectoral_droop)
	return {
		"at": Vector3(side * body.x * girth(u) * 0.85, -body.y * girth(u) * 0.3, u * body.z),
		"direction": Vector3(side * cos(droop), -sin(droop), 0.45).normalized(),
	}


## The jaw at rest: where it hinges, behind the mouth, which way it runs to the
## front of the mouth, and how long it is. One with teeth runs along under the
## snout, low enough at the front for the teeth above to show.
func jaw_rest() -> Dictionary:
	var front := _front()
	if teeth <= 0.0:
		return {"at": Vector3(0.0, _mouth_y() - body.y * 0.08, front + body.z * 0.3),
			"direction": Vector3.FORWARD, "length": body.z * 0.3}
	var back := front + body.z * 0.36
	var hinge := Vector3(0.0, -body.y * girth(back / body.z) * 0.9, back)
	var tip := Vector3(0.0, -body.y * girth(front / body.z) * 0.9 - teeth, front)
	return {"at": hinge, "direction": (tip - hinge).normalized(), "length": hinge.distance_to(tip)}


## How far forward the front of the mouth is.
func _front() -> float:
	return -body.z + mouth_back


## How far above the middle of the body the mouth is.
func _mouth_y() -> float:
	return mouth.y - body.y * 0.1


# --- the mesh -----------------------------------------------------------------

## One mesh in three surfaces: the body in its colours, the eyes and lips that
## shine, and the fins, drawn from both sides.
func build_mesh(skeleton: Skeleton3D) -> ArrayMesh:
	var skin := RigKit.begin()
	var shine := RigKit.begin()
	var fins := RigKit.begin()
	var trunk := skeleton.find_bone("Body")
	var tail := skeleton.find_bone("Tail")
	var backward := RigKit.along(Vector3.BACK, Vector3.RIGHT)
	var cut := bend_at
	var tuck := TUCK / body.z

	# The body, in two halves, each tucked into the other where the tail bends.
	RigKit.lathe(skin, skeleton, trunk, Transform3D(backward, Vector3.ZERO),
		_profile(-1.0, cut, 0.0, tuck), 18)
	RigKit.lathe(skin, skeleton, tail, Transform3D(backward, Vector3(0.0, 0.0, -cut * body.z)),
		_profile(cut, 1.0, tuck, wrist * body.y * 0.6 / body.z), 18)

	_build_face(skin, shine, skeleton, trunk)

	# The tail fin, standing up at the end of the tail; the fins along the back
	# and beneath, standing in the same plane down the middle.
	var upright := Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT)
	RigKit.panel(fins, skeleton, skeleton.find_bone("Fin"), _tail_outline(),
		Vector2(tail_fin.y * 0.25, 0.0), fin_colour, fin_rim, 0.12, 0.0,
		Transform3D(upright, Vector3.ZERO))
	var back := dorsal_at * body.z
	RigKit.panel(fins, skeleton, trunk, _dorsal_outline(),
		Vector2(dorsal.y * 0.4, dorsal.x * 0.3), fin_colour, fin_rim, 0.12, 0.0,
		Transform3D(upright, Vector3(0.0, body.y * girth(dorsal_at) * 0.92, back - dorsal.y * 0.4)))
	if anal != Vector2.ZERO:
		var under := lerpf(cut, 1.0, 0.45)
		RigKit.panel(fins, skeleton, tail, PackedVector2Array([Vector2(0.0, 0.05),
			Vector2(anal.y * 0.55, -anal.x), Vector2(anal.y, -anal.x * 0.8),
			Vector2(anal.y * 0.9, 0.05)]), Vector2(anal.y * 0.5, -anal.x * 0.3), fin_colour,
			fin_rim, 0.12, 0.0, Transform3D(upright, Vector3(0.0,
				-body.y * girth(under) * 0.85, (under - cut) * body.z - anal.y * 0.5)))
	for s in 2:
		RigKit.panel(fins, skeleton, skeleton.find_bone("Pectoral.%s" % SIDES[s]),
			PackedVector2Array([Vector2(-0.02, 0.0), Vector2(-0.02, pectoral.x * 0.7),
				Vector2(pectoral.y * 0.3, pectoral.x), Vector2(pectoral.y * 0.9, pectoral.x * 0.8),
				Vector2(pectoral.y, pectoral.x * 0.35), Vector2(pectoral.y * 0.5, 0.0)]),
			Vector2(pectoral.y * 0.4, pectoral.x * 0.4), fin_colour, fin_rim, 0.12)

	return RigKit.commit([skin, shine, fins], [RigKit.shell_material(1.0 - gloss, 0.0, 0.35),
		RigKit.gloss_material(), RigKit.membrane_material(false, 0.6)])


## The rows of the body from [param from] to [param to] along it, for
## [method RigKit.lathe] along it, with a round end [param before] long before
## the first and [param after] long after the last, in the same units — tucked
## inside the other half, or closing off the tail.
func _profile(from: float, to: float, before: float, after: float) -> Array:
	var rows: Array = []
	var paint := _skin_paint()
	var count := 18
	# A row on the true profile a hair either side of the cut, between it and the
	# round end: the lathe finds a row's slope from its neighbours, and without
	# this the end curving away would bend the light at the join into a seam.
	var hair := 0.004
	if before > 0.0:
		for i in 4:
			var angle := PI * 0.5 * float(4 - i) / 4.0
			var g := girth(from) * cos(angle)
			rows.append([(from - before * sin(angle)) * body.z, body.x * g, body.y * g, paint])
		rows.append([(from - hair) * body.z, body.x * girth(from - hair),
			body.y * girth(from - hair), paint])
	for i in count + 1:
		var t := float(i) / float(count)
		# Closer together toward the nose, where the curve is.
		var u := lerpf(from, to, t) if from > -1.0 else lerpf(from, to, 1.0 - cos(t * PI * 0.5))
		var g := girth(u)
		rows.append([u * body.z, body.x * g, body.y * g, paint])
	if after > 0.0:
		rows.append([(to + hair) * body.z, body.x * girth(to + hair), body.y * girth(to + hair),
			paint])
		for i in range(1, 5):
			var angle := PI * 0.5 * float(i) / 4.0
			var g := girth(to) * cos(angle)
			rows.append([(to + after * sin(angle)) * body.z, body.x * g, body.y * g, paint])
	return rows


## Paints the body: its colour above, the belly's beneath, fading across a band.
func _skin_paint() -> Callable:
	return func(n: Vector3, _p: Vector3) -> Color:
		return colour.lerp(belly_colour, smoothstep(belly_line + 0.12, belly_line - 0.12, n.y))


## Eyes, a mouth on a jaw that opens — with lips to pout, or teeth to grin — and
## gill slits.
func _build_face(skin: SurfaceTool, shine: SurfaceTool, skeleton: Skeleton3D,
		trunk: int) -> void:
	var chin := skeleton.find_bone("Jaw")
	var u := -0.62
	for side in [-1.0, 1.0]:
		var at := Vector3(side * body.x * girth(u) * 0.78, body.y * girth(u) * 0.3, u * body.z)
		RigKit.eye(shine, skeleton, trunk, at, Vector3(side, 0.15, -0.4).normalized(), eye,
			eye_colour, eye_white, eye_ring)
	if teeth > 0.0:
		_build_grin(skin, skeleton, trunk, chin)
	else:
		_build_lips(skin, shine, skeleton, trunk, chin)
	for k in gills:
		var along := -0.46 + float(k) * 0.06
		var depth := body.y * girth(along)
		for side in [-1.0, 1.0]:
			var at := Vector3(side * body.x * girth(along) * 0.97, -depth * 0.3, along * body.z)
			RigKit.lathe(skin, skeleton, trunk, Transform3D(RigKit.along(Vector3(side * 0.12, 1.0,
				0.08).normalized(), Vector3.BACK), at),
				RigKit.capsule(depth * 0.55, 0.018, gill_colour, 1), 5)


## A mouth that pouts at the front of the nose: lips above and on the jaw below,
## and dark inside for when it opens.
func _build_lips(skin: SurfaceTool, shine: SurfaceTool, skeleton: Skeleton3D, trunk: int,
		chin: int) -> void:
	var front := _front()
	var reach: float = jaw_rest()["length"]
	var mouth_y := _mouth_y()
	RigKit.ellipsoid(skin, skeleton, trunk, Vector3(0.0, mouth_y - body.y * 0.06,
		front + body.z * 0.14), Vector3(mouth.x * 0.85, body.y * 0.1, reach * 0.4),
		RigKit.plain(Color(0.25, 0.06, 0.08)), 10, 6)
	# The lower jaw: a short wedge under the nose, running forward from the hinge.
	RigKit.lathe(skin, skeleton, chin, Transform3D.IDENTITY, [
		[0.0, mouth.x * 1.1, body.y * 0.1, _skin_paint()],
		[reach * 0.6, mouth.x * 1.0, body.y * 0.08, _skin_paint()],
		[reach * 0.98, mouth.x * 0.7, body.y * 0.05, _skin_paint()],
		[reach * 1.02, 0.0, 0.0, _skin_paint()]], 12)
	if lips > 0.0:
		RigKit.ellipsoid(shine, skeleton, trunk, Vector3(0.0, mouth_y + lips * 0.35, front
			+ lips * 0.35), Vector3(mouth.x, lips * 0.6, lips * 0.75), RigKit.plain(lip_colour), 14, 8)
		RigKit.ellipsoid(shine, skeleton, chin, Vector3(0.0, reach * 0.95, lips * 0.05),
			Vector3(mouth.x * 0.9, lips * 0.7, lips * 0.5), RigKit.plain(lip_colour), 14, 8)


## A grin under the snout: a row of teeth hanging from the snout's underside in
## a curve, a jaw below it with a row of its own, and dark in between. The dark
## rides on the jaw and reaches up inside the head, so however far the jaw drops
## there is mouth behind the teeth rather than daylight.
func _build_grin(skin: SurfaceTool, skeleton: Skeleton3D, trunk: int, chin: int) -> void:
	var white := Color(0.98, 0.97, 0.93)
	var front := _front()
	var jaw := jaw_rest()
	var length: float = jaw["length"]
	var wide := body.x * girth(front / body.z)
	# In the jaw's own space, +Y runs forward along it and +Z is up.
	RigKit.lathe(skin, skeleton, chin, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -0.05)), [
		[-0.04, wide * 0.7, 0.05, _skin_paint()], [length * 0.5, wide * 0.8, 0.07, _skin_paint()],
		[length * 0.95, wide * 0.6, 0.06, _skin_paint()], [length * 1.05, 0.0, 0.0, _skin_paint()]], 14)
	RigKit.ellipsoid(skin, skeleton, chin, Vector3(0.0, length * 0.55, 0.06),
		Vector3(wide * 0.7, length * 0.5, 0.16), RigKit.plain(Color(0.22, 0.05, 0.07)), 12, 8)
	var count := 9
	for i in count:
		var angle := lerpf(-1.25, 1.25, float(i) / float(count - 1))
		var z := front + (1.0 - cos(angle)) * wide * 0.7
		var round := body.x * girth(z / body.z)
		var x := sin(angle) * wide * 0.8
		var y := -body.y * girth(z / body.z) * sqrt(maxf(1.0 - pow(x / round, 2.0), 0.0)) * 0.97
		RigKit.lathe(skin, skeleton, trunk, Transform3D(RigKit.along(Vector3.DOWN, Vector3.RIGHT),
			Vector3(x, y + 0.01, z)), [[0.0, teeth * 0.45, teeth * 0.3, white],
				[teeth, 0.0, 0.0, white]], 6)
		RigKit.lathe(skin, skeleton, chin, Transform3D(RigKit.along(Vector3.BACK, Vector3.RIGHT),
			Vector3(sin(angle) * wide * 0.62, length - (1.0 - cos(angle)) * wide * 0.55, 0.0)),
			[[0.0, teeth * 0.4, teeth * 0.28, white], [teeth * 0.8, 0.0, 0.0, white]], 6)


## The edge of the tail fin, in its own plane — back along +X and up +Y from the
## root of the tail: out to the top lobe, into the fork, out to the bottom lobe
## and back.
func _tail_outline() -> PackedVector2Array:
	var high := tail_fin.x * 0.5
	var long := tail_fin.y
	var top := Vector2(long * sqrt(lobe), high * sqrt(lobe))
	var bottom := Vector2(long / sqrt(lobe), -high / sqrt(lobe))
	var notch := Vector2(long * (1.0 - fork * 0.65), 0.0)
	var root := wrist * body.y * 0.8
	var outline := PackedVector2Array([Vector2(-0.05, root)])
	outline.append(Vector2(top.x * 0.45, lerpf(root, top.y, 0.7)))
	outline.append(top)
	outline.append(top.lerp(notch, 0.5) + Vector2(fork * 0.05 + 0.06, 0.0))
	outline.append(notch)
	outline.append(bottom.lerp(notch, 0.5) + Vector2(fork * 0.05 + 0.06, 0.0))
	outline.append(bottom)
	outline.append(Vector2(bottom.x * 0.45, lerpf(-root, bottom.y, 0.7)))
	outline.append(Vector2(-0.05, -root))
	return outline


## The edge of the fin on its back, in its own plane: from its root at the front,
## up and back to its peak, and down again to the back.
func _dorsal_outline() -> PackedVector2Array:
	var lean := tan(deg_to_rad(dorsal_sweep)) * dorsal.x
	return PackedVector2Array([Vector2(0.0, -0.08), Vector2(dorsal.y * 0.12, dorsal.x * 0.55),
		Vector2(dorsal.y * 0.25 + lean * 0.8, dorsal.x), Vector2(dorsal.y * 0.35 + lean,
			dorsal.x * 0.92), Vector2(dorsal.y * 0.75, dorsal.x * 0.3), Vector2(dorsal.y, -0.08)])
