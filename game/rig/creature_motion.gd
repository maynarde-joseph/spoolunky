class_name CreatureMotion
extends SkeletonModifier3D

## Poses a creature's bones every frame from a few plain facts about what it is
## doing: which [enum Pose] it is in, how fast it is going, how much fight it has
## left. Each kind of body has its own motion, which is where knowing how an
## insect flies lives; this one holds the facts, and the few things every motion
## does with them.
##
## It runs inside the skeleton's own update, after everything else has had its say
## for the frame, so what it poses is what gets drawn. The spider's gait found the
## catch in that: once the frame is drawn, the skeleton hands back its rest pose,
## so a motion that wants to be checked records what it drew itself — see
## [method feet] and [method strokes].

## What the creature is doing, as far as its body is concerned.
enum Pose {
	FLYING,      ## off the ground under its own power: in the air, or in water
	WALKING,     ## on its feet, moving or standing
	STRUGGLING,  ## caught, and fighting it
	SPENT,       ## caught, and fought out
	CURLED,      ## wrapped up, or dead
}

## How quickly it goes from one way of holding itself to the next, per second.
const EASE := 5.0

var pose: Pose = Pose.FLYING

## Speed along the ground or through the air, in body radii a second.
var speed := 0.0

## The fastest it goes, in the same units: what [member speed] is out of. Big
## things go fewer of their own lengths a second than small ones, so how hard one
## is working is how fast it is going against this, not against any fixed pace.
var top_speed := 4.0

## How fast it is rising, or sinking if negative, in body radii a second.
var climb := 0.0

## How much fight it has left, 0 to 1. Only means anything while it struggles.
var effort := 0.0

## Seconds into its life, started somewhere different for every creature so that
## a swarm does not beat its wings in step.
var clock := 0.0

# How much of each way of holding itself is in the pose right now, 0 to 1, eased
# from one to the next by _blend, so that going from flying to caught to wrapped
# is a change of shape rather than a jump.
var _air := 0.0
var _walk := 0.0
var _thrash := 0.0
var _slack := 0.0
var _curl := 0.0

# Every bone's rest, which every turn is made from.
var _rest := {}
var _missing := PackedStringArray()


## Finds the bones this poses. Called once, when the skeleton is built.
func bind(_skeleton: Skeleton3D, _body: CreatureBody) -> void:
	pass


## Where the end of every foot was drawn last frame, in the world: whatever it
## stands on, and what has to reach the floor when it does. Empty for something
## with nothing to stand on.
func feet() -> PackedVector3Array:
	return PackedVector3Array()


## Where the ends of whatever it flies or swims with were drawn last frame, in the
## world: wings, a tail, arms. Empty for something that only walks.
func strokes() -> PackedVector3Array:
	return PackedVector3Array()


## The bones [method bind] looked for and did not find: none, when a body and its
## motion agree about the skeleton. A motion poses what it finds and passes over
## the rest, so a bone a body forgot to build is a limb that never moves — quietly,
## unless something asks.
func missing() -> PackedStringArray:
	return _missing


## Remembers every bone's rest, and forgets what was missing: the start of a bind.
func _keep_rest(skeleton: Skeleton3D) -> void:
	_rest.clear()
	_missing.clear()
	for bone in skeleton.get_bone_count():
		_rest[bone] = skeleton.get_bone_rest(bone)


## The bone called [param bone_name], or -1, which [method missing] reports unless
## it is [param optional] — a part only some bodies of a kind have.
func _find(skeleton: Skeleton3D, bone_name: String, optional := false) -> int:
	var bone := skeleton.find_bone(bone_name)
	if bone < 0 and not optional:
		_missing.append(bone_name)
	return bone


## Eases each way of holding itself toward what [member pose] says, over
## [param delta] seconds. Something caught thrashes as hard as it has fight left,
## and never quite stops until the fight is gone.
func _blend(delta: float) -> void:
	var step := clampf(EASE * delta, 0.0, 1.0)
	_air = move_toward(_air, 1.0 if pose == Pose.FLYING else 0.0, step)
	_walk = move_toward(_walk, 1.0 if pose == Pose.WALKING else 0.0, step)
	var fight := 0.35 + 0.65 * clampf(effort, 0.0, 1.0)
	_thrash = move_toward(_thrash, fight if pose == Pose.STRUGGLING else 0.0, step)
	_slack = move_toward(_slack, 1.0 if pose == Pose.SPENT else 0.0, step)
	_curl = move_toward(_curl, 1.0 if pose == Pose.CURLED else 0.0, step)


## Turns [param bone] by [param turn], given in its parent's space, from rest.
func _turn(skeleton: Skeleton3D, bone: int, turn: Quaternion) -> void:
	if bone < 0:
		return
	var rest: Transform3D = _rest[bone]
	skeleton.set_bone_pose_rotation(bone, turn * rest.basis.get_rotation_quaternion())


## Moves [param bone] by [param offset], in its parent's space, from rest.
func _shift(skeleton: Skeleton3D, bone: int, offset: Vector3) -> void:
	if bone < 0:
		return
	var rest: Transform3D = _rest[bone]
	skeleton.set_bone_pose_position(bone, rest.origin + offset)


## Where the point [param along] out along [param bone] is drawn now, in the world.
func _tip(skeleton: Skeleton3D, bone: int, along: float) -> Vector3:
	return _at(skeleton, bone, Vector3(0.0, along, 0.0))


## Where [param point], in [param bone]'s own space, is drawn now, in the world.
func _at(skeleton: Skeleton3D, bone: int, point: Vector3) -> Vector3:
	return skeleton.global_transform * (skeleton.get_bone_global_pose(bone) * point)
