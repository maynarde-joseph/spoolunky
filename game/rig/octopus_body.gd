class_name OctopusBody
extends CreatureBody

## An octopus: a head with two eyes, a soft bag of a mantle above it, and eight
## arms of four bones each. Its own kind because nothing else is built like it;
## the numbers are in a .tres of it all the same.
##
## Drawn the minimal way, as the spider and the insects are: smooth parts, arms
## that taper to a point bent at round joints, one flat colour, and two small eyes
## that shine a little. Every length is in body radii and every angle in degrees;
## forward is -Z and up is +Y. Its head and mantle are
## centred on the creature's middle, and its arms reach out of that the way an
## insect's legs do. At rest it sits the way it crawls: arms spread round it on
## the floor, their ends curling up.

## The four bones of an arm, root to tip, as a fraction of its length.
const PIECES := [0.3, 0.27, 0.23, 0.2]
## How far below level each bone of an arm runs at rest, in degrees: down from
## the head to the floor, along it, and turning up a little at the end.
const DROOPS := [55.0, 12.0, -2.0, -18.0]


@export_group("Colours")

@export var colour := Color(0.86, 0.42, 0.36)
@export var eye_colour := Color(0.03, 0.03, 0.03)


@export_group("Body")

## The head's radii: across, up and along.
@export var head := Vector3(0.48, 0.4, 0.44)
## The mantle's radii, and how far up and back from the head it sits.
@export var mantle := Vector3(0.52, 0.6, 0.52)
@export var mantle_at := Vector2(0.45, 0.22)
## Each eye's radius.
@export var eye := 0.07


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

## One mesh in two surfaces: everything but the eyes in its one colour, and the
## eyes.
func build_mesh(skeleton: Skeleton3D) -> ArrayMesh:
	var skin := RigKit.begin()
	var shine := RigKit.begin()
	var trunk := skeleton.find_bone("Body")
	var bag := skeleton.find_bone("Mantle")
	var upward := RigKit.along(Vector3.UP, Vector3.RIGHT)

	RigKit.ellipsoid(skin, skeleton, trunk, Vector3.ZERO, head, RigKit.plain(colour), 20, 12)
	RigKit.lathe(skin, skeleton, bag, Transform3D(upward, Vector3.ZERO),
		RigKit.ovoid(Vector3(mantle.x, mantle.z, mantle.y), 0.15, 14, RigKit.solid(colour)), 20)
	for side in [-1.0, 1.0]:
		# Set into the front of the head, a little proud of it.
		var toward := Vector3(side * 0.45, 0.35, -0.82).normalized()
		RigKit.ellipsoid(shine, skeleton, trunk, toward * head - toward * eye * 0.4,
			Vector3.ONE * eye, RigKit.plain(eye_colour), 10, 6)

	var cut := RigKit.Cut.new(8, 2, 3)
	for i in 8:
		var done := 0.0
		for k in 4:
			var length := arm * float(PIECES[k])
			var from := done / arm
			done += length
			RigKit.segment(skin, skeleton, skeleton.find_bone(arm_bone(i, k)), length,
				arm_girth(from), arm_girth(done / arm), RigKit.plain(colour), cut)

	return RigKit.commit([skin, shine], [RigKit.shell_material(0.75, 0.0, 0.3),
		RigKit.eye_material(eye_colour, eye_colour, 0.15)])
