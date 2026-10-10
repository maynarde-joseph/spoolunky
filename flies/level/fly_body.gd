class_name FlyBody
extends Node3D

## A fly's body: low poly and plain, the way the rest of the game is drawn — a
## faceted dark grey head, thorax and tapering abdomen, six thin black legs bent at
## the knee, and two long pale wings that lie back over the abdomen in a V at
## rest.
##
## It is a skinned mesh on a skeleton of its own, built with [RigKit], so its legs
## and wings move at their joints: wings buzzing up and down and spread while it
## flies, legs hanging and twitching under it, and everything folded still once a
## web has it.
##
## Built in body units, about two from the front of the head to the tip of the
## abdomen, facing -Z with its back to +Y; the node is scaled to the fly's size.

## How long the fly is in body units, from the head to the tail.
const LENGTH := 2.1

const SHELL := Color(0.06, 0.06, 0.07)
const SHELL_LIT := Color(0.17, 0.17, 0.19)
const LEGS := Color(0.07, 0.07, 0.08)
const WING := Color(0.74, 0.81, 0.83, 0.78)
const WING_RIM := Color(0.6, 0.67, 0.7, 0.88)

## How fast the wings beat, in beats a second, and how far up and down they go
## and how far out they spread while flying, in degrees.
const BEAT := 24.0

## How long a leg's two parts are, in body units: short, tucked under the body.
const FEMUR := 0.36
const TIBIA := 0.5
const STROKE := 38.0
const SPREAD := 34.0

var skeleton: Skeleton3D
var flying := true

var _wings: Array[int] = []
## Every leg's two bones, femur then tibia, and which side it is on.
var _legs: Array[Dictionary] = []
var _clock := 0.0


func _ready() -> void:
	skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton"
	add_child(skeleton)
	var thorax := RigKit.add_bone(skeleton, "thorax", -1, Transform3D.IDENTITY)
	var head := RigKit.add_bone(skeleton, "head", thorax,
		Transform3D(Basis.IDENTITY, Vector3(0.0, 0.04, -0.46)))
	var abdomen := RigKit.add_bone(skeleton, "abdomen", thorax,
		Transform3D(Basis.IDENTITY, Vector3(0.0, -0.02, 0.32)))
	for side in [-1.0, 1.0]:
		var root := Vector3(side * 0.16, 0.34, -0.04)
		var back := Vector3(side * 0.42, 0.1, 1.0).normalized()
		_wings.append(RigKit.add_bone(skeleton, "wing" + _side(side), thorax,
			Transform3D(RigKit.along(back, Vector3(side, 0.0, 0.0)), root)))
	# Three pairs of legs from under the thorax: the front ones reaching forward, the
	# back ones back, each up and out to the knee and down to the foot.
	var pairs := [[-0.2, -0.65], [0.0, 0.0], [0.18, 0.7]]
	for i in pairs.size():
		var z: float = pairs[i][0]
		var reach: float = pairs[i][1]
		for side in [-1.0, 1.0]:
			var hip := Vector3(side * 0.16, -0.24, z)
			var thigh := Vector3(side, 0.05, reach * 0.8).normalized()
			var femur := RigKit.add_bone(skeleton, "femur%d%s" % [i, _side(side)], thorax,
				Transform3D(RigKit.along(thigh, Vector3.UP), hip))
			var knee := hip + thigh * FEMUR
			var shin := Vector3(side * 0.3, -1.0, reach * 0.6).normalized()
			var tibia := RigKit.add_bone(skeleton, "tibia%d%s" % [i, _side(side)], femur,
				Transform3D(RigKit.along(shin, Vector3.UP), knee))
			_legs.append({"femur": femur, "tibia": tibia, "side": side, "pair": i})

	var body := RigKit.begin()
	var limbs := RigKit.begin()
	var wings := RigKit.begin()
	var facets := func(normal: Vector3, _at: Vector3) -> Color:
		return SHELL.lerp(SHELL_LIT, clampf(normal.y * 0.8 + normal.z * -0.15, 0.0, 1.0))
	RigKit.ellipsoid(body, skeleton, thorax, Vector3.ZERO, Vector3(0.36, 0.34, 0.42), facets,
		8, 6, true)
	RigKit.ellipsoid(body, skeleton, head, Vector3(0.0, 0.0, -0.08), Vector3(0.34, 0.26, 0.2),
		facets, 8, 5, true)
	var tail := RigKit.ovoid(Vector3(0.3, 0.26, 0.62), 0.75, 9, RigKit.solid(SHELL))
	RigKit.lathe(body, skeleton, abdomen, Transform3D(Basis(Vector3.RIGHT, PI * 0.5),
		Vector3(0.0, 0.0, 0.5)), tail, 8, facets)
	var cut := RigKit.Cut.new(5, 2, 1, true)
	for leg in _legs:
		var paint := RigKit.plain(LEGS)
		RigKit.segment(limbs, skeleton, leg["femur"], FEMUR, 0.045, 0.035, paint, cut)
		RigKit.segment(limbs, skeleton, leg["tibia"], TIBIA, 0.035, 0.02, paint, cut)
	for wing in _wings:
		RigKit.membrane(wings, skeleton, wing, 1.45, 0.5, 0.62, WING, WING_RIM, 10)
	var shell := RigKit.shell_material(0.6, 0.0, 0.12)
	var legs := RigKit.matte_material(LEGS)
	legs.vertex_color_use_as_albedo = true
	var mesh := MeshInstance3D.new()
	mesh.name = "Look"
	mesh.mesh = RigKit.commit([body, limbs, wings], [shell, legs,
		RigKit.membrane_material(true, 0.3)])
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	skeleton.add_child(mesh)
	mesh.skeleton = NodePath("..")
	mesh.skin = skeleton.create_skin_from_rest_transforms()
	_pose(0.0)


## Folds it up still: wings back over the abdomen, legs drawn in. A web has it.
func fold() -> void:
	flying = false
	_pose(0.0)


func _process(delta: float) -> void:
	if not flying:
		return
	_clock += delta
	_pose(_clock)


## Every joint at [param time]: wings beating and spread, legs hanging and
## twitching, while it flies; folded otherwise.
func _pose(time: float) -> void:
	if skeleton == null:
		return
	for i in _wings.size():
		var bone := _wings[i]
		var side := -1.0 if i == 0 else 1.0
		var rest := skeleton.get_bone_rest(bone).basis
		var turn := Quaternion.IDENTITY
		if flying:
			# Out from the body, and up and down about the body's own length.
			var out := Quaternion(rest.inverse() * Vector3.UP, deg_to_rad(-side * SPREAD))
			var beat := sin(time * TAU * BEAT) * deg_to_rad(STROKE)
			var stroke := Quaternion(rest.inverse() * Vector3.BACK, side * beat)
			turn = out * stroke
		skeleton.set_bone_pose_rotation(bone, (Quaternion(rest) * turn).normalized())
	for leg in _legs:
		var side: float = leg["side"]
		var femur: int = leg["femur"]
		var tibia: int = leg["tibia"]
		var femur_rest := skeleton.get_bone_rest(femur).basis
		var tibia_rest := skeleton.get_bone_rest(tibia).basis
		var femur_axes := skeleton.get_bone_global_rest(femur).basis
		var tibia_axes := skeleton.get_bone_global_rest(tibia).basis
		var lift := 0.0
		var bend := 0.0
		if flying:
			# Hanging down a little, each leg twitching on its own beat.
			var beat := sin(time * 7.0 + float(leg["pair"]) * 1.7 + side) * 0.08
			lift = -0.25 + beat
			bend = 0.15 - beat
		else:
			# Drawn in under the body.
			lift = 0.35
			bend = -0.6
		var hinge := Vector3.BACK * side
		skeleton.set_bone_pose_rotation(femur, (Quaternion(femur_rest)
			* Quaternion((femur_axes.inverse() * hinge).normalized(), lift)).normalized())
		skeleton.set_bone_pose_rotation(tibia, (Quaternion(tibia_rest)
			* Quaternion((tibia_axes.inverse() * hinge).normalized(), bend)).normalized())


static func _side(side: float) -> String:
	return ".L" if side < 0.0 else ".R"
