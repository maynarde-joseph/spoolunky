class_name OctopusBody
extends CreatureBody

## An octopus: a head with big eyes and a little tube of a mouth, a soft bag of a
## mantle above it, and eight arms of four bones each, all of it one colour with
## pale suckers under the arms. Its own kind because nothing else is built like
## it; the numbers are in a .tres of it all the same.
##
## Drawn like the rest, minimal and a little goofy. Every length is in body radii
## and every angle in degrees; forward is -Z and up is +Y. Its head and mantle are
## centred on the creature's middle, and its arms reach out of that the way an
## insect's legs do. At rest it sits the way it crawls: arms spread round it on
## the floor, their ends curling up.

## The four bones of an arm, root to tip, as a fraction of its length.
const PIECES := [0.3, 0.27, 0.23, 0.2]
## How far below level each bone of an arm runs at rest, in degrees: down from
## the head to the floor, along it, and turning up a little at the end.
const DROOPS := [55.0, 12.0, -2.0, -18.0]


@export_group("Colours")

@export var colour := Color(0.95, 0.46, 0.42)
## The underside of the arms, and the suckers on it.
@export var sucker_colour := Color(1.0, 0.82, 0.76)
## Spots on the mantle, when [member spots] asks for any.
@export var spot_colour := Color(0.85, 0.32, 0.3)
@export var spots := 5
## The middle of each eye, and what shows round it.
@export var eye_colour := Color(0.03, 0.03, 0.03)
@export var eye_ring := Color(0.96, 0.95, 0.9)
## How wet it looks.
@export_range(0.0, 1.0) var gloss := 0.45


@export_group("Body")

## The head's radii: across, up and along.
@export var head := Vector3(0.48, 0.4, 0.44)
## The mantle's radii, and how far up and back from the head it sits.
@export var mantle := Vector3(0.52, 0.6, 0.52)
@export var mantle_at := Vector2(0.45, 0.22)
## Each eye's radius, and how much of it is white round the middle.
@export var eye := 0.17
@export_range(0.0, 1.0) var eye_white := 0.5
## A little tube of a mouth this long on the front of the head. Zero for none.
@export var siphon := 0.12


@export_group("Arms")

## Each arm's length, and how thick it is at its root and at its tip.
@export var arm := 1.5
@export var arm_thickness := Vector2(0.13, 0.035)
## How wide the ring the arms leave the head from is.
@export var arm_ring := 0.28


@export_group("Moving")

## Pulses a second, swimming, and ripples a second down the arms, crawling.
@export var pulse_rate := 1.4
@export var ripple_rate := 1.8


# --- the bones ----------------------------------------------------------------

func make_motion() -> CreatureMotion:
	return OctopusMotion.new()


func build_bones(skeleton: Skeleton3D) -> void:
	skeleton.clear_bones()
	var root := RigKit.add_bone(skeleton, "Root", -1, Transform3D.IDENTITY)
	var trunk := RigKit.add_bone(skeleton, "Body", root, Transform3D.IDENTITY)
	RigKit.add_bone(skeleton, "Mantle", trunk,
		Transform3D(Basis.IDENTITY, Vector3(0.0, mantle_at.x, mantle_at.y)))
	for i in 8:
		var limb := arm_rest(i)
		var parent := trunk
		for k in 4:
			parent = RigKit.add_bone(skeleton, arm_bone(i, k), parent,
				Transform3D(RigKit.along(limb["directions"][k], limb["across"]), limb["joints"][k]))


## The name of bone [param piece] of arm [param index], counting round from the
## front and out from the head.
static func arm_bone(index: int, piece: int) -> String:
	return "Arm.%d.%d" % [index + 1, piece + 1]


## Where the arms touch the floor when it sits, below the middle of it: the
## lowest of its joints, and the thickness of the arm there.
func reach_down() -> float:
	var limb := arm_rest(0)
	var lowest := 0.0
	for joint in limb["joints"]:
		lowest = minf(lowest, (joint as Vector3).y)
	return -lowest + arm_thickness.x * 0.6


## Arm [param index] at rest: where each of its joints is, which way each bone
## runs, and the axis across it — level, and square to the way it reaches — that
## it curls about.
func arm_rest(index: int) -> Dictionary:
	var angle := (float(index) + 0.5) * TAU / 8.0
	var out := Vector3(sin(angle), 0.0, -cos(angle))
	var joints: Array[Vector3] = [out * arm_ring + Vector3.DOWN * head.y * 0.72]
	var directions: Array[Vector3] = []
	for k in 4:
		var droop := deg_to_rad(DROOPS[k])
		directions.append((out * cos(droop) + Vector3.DOWN * sin(droop)).normalized())
		joints.append(joints[k] + directions[k] * arm * float(PIECES[k]))
	return {
		"joints": joints, "directions": directions, "out": out,
		"across": Vector3.UP.cross(out).normalized(),
	}


## How thick an arm is [param along] of the way from its root to its tip.
func arm_girth(along: float) -> float:
	return lerpf(arm_thickness.x, arm_thickness.y, pow(along, 0.8))


# --- the mesh -----------------------------------------------------------------

## One mesh in two surfaces: the body, and the eyes that shine.
func build_mesh(skeleton: Skeleton3D) -> ArrayMesh:
	var skin := RigKit.begin()
	var shine := RigKit.begin()
	var trunk := skeleton.find_bone("Body")
	var bag := skeleton.find_bone("Mantle")
	var upward := RigKit.along(Vector3.UP, Vector3.RIGHT)

	RigKit.ellipsoid(skin, skeleton, trunk, Vector3.ZERO, head, RigKit.plain(colour), 20, 12)
	RigKit.lathe(skin, skeleton, bag, Transform3D(upward, Vector3.ZERO),
		RigKit.ovoid(Vector3(mantle.x, mantle.z, mantle.y), 0.15, 14,
			func(_y: float) -> Callable: return _spot_paint()), 20)
	for side in [-1.0, 1.0]:
		var at := Vector3(side * head.x * 0.5, head.y * 0.32, -head.z * 0.68)
		RigKit.eye(shine, skeleton, trunk, at, Vector3(side * 0.35, 0.1, -1.0).normalized(), eye,
			eye_colour, eye_white, eye_ring)
	if siphon > 0.0:
		var root := Vector3(head.x * 0.3, -head.y * 0.2, -head.z * 0.85)
		var out := Vector3(0.35, -0.2, -1.0).normalized()
		RigKit.lathe(skin, skeleton, trunk, Transform3D(RigKit.along(out, Vector3.UP), root), [
			[0.0, siphon * 0.45, siphon * 0.45, colour], [siphon, siphon * 0.4, siphon * 0.4, colour],
			[siphon * 1.08, siphon * 0.3, siphon * 0.3, colour.darkened(0.2)],
			[siphon * 1.1, 0.0, 0.0, Color(0.25, 0.06, 0.08)]], 12)

	var cut := RigKit.Cut.new(10, 3, 3)
	for i in 8:
		var done := 0.0
		for k in 4:
			var bone := skeleton.find_bone(arm_bone(i, k))
			var length := arm * float(PIECES[k])
			var from := done / arm
			done += length
			RigKit.segment(skin, skeleton, bone, length, arm_girth(from), arm_girth(done / arm),
				_arm_paint(), cut)
			# Two suckers on the underside of each bone: in the arm's own space, with X
			# across it and Y along it, that is +Z.
			for s in 2:
				var t := (float(s) + 0.5) / 2.0
				var girth := arm_girth(lerpf(from, done / arm, t))
				RigKit.ellipsoid(skin, skeleton, bone, Vector3(0.0, length * t, girth * 0.82),
					Vector3(girth * 0.5, girth * 0.5, girth * 0.28), RigKit.plain(sucker_colour), 8, 5)

	return RigKit.commit([skin, shine], [RigKit.shell_material(1.0 - gloss, 0.0, 0.35),
		RigKit.gloss_material()])


## Paints an arm: its colour on top, paler on the underside.
func _arm_paint() -> Callable:
	return func(n: Vector3, _p: Vector3) -> Color:
		return colour.lerp(sucker_colour, smoothstep(0.2, 0.7, n.z))


## Paints the mantle: its colour, with a few darker spots scattered over the top.
func _spot_paint() -> Callable:
	return func(n: Vector3, _p: Vector3) -> Color:
		var spotted := 0.0
		for k in spots:
			var angle := float(k) * 2.39996
			var lift := 0.35 + 0.5 * fposmod(float(k) * 0.618, 1.0)
			var spot := Vector3(cos(angle) * sqrt(1.0 - lift * lift), lift, sin(angle)
				* sqrt(1.0 - lift * lift))
			spotted = maxf(spotted, smoothstep(0.93, 0.97, n.dot(spot)))
		return colour.lerp(spot_colour, spotted)
