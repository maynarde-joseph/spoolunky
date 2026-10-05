class_name CreatureView
extends Node3D

## A creature's body in the world: the skeleton, the mesh its [CreatureBody] skins
## to it, and the [CreatureMotion] that poses it. It sits under an [Insect] as the
## node called Body and watches it to know what to do, so the insect never has to
## know it is there.
##
## It is scaled to the creature's body radius, so everything under it is in the
## body's own unit — and as an insect grows, the insect scales it up. It turns to
## face where the creature is going, which the insect itself never does: its
## collider is a ball, and a ball has no front.

## How quickly it swings round to a new heading, per second.
const TURN_RATE := 10.0

## How quickly it settles onto its feet when it lands, or lifts off them when it
## takes to the air, per second.
const SETTLE_RATE := 6.0

var body: CreatureBody
var skeleton: Skeleton3D
var shell: MeshInstance3D
var motion: CreatureMotion

## Holds the body in one [enum CreatureMotion.Pose] whatever the creature is
## doing, or -1 to follow it. For pictures and checks.
var held := -1

var _insect: Insect
var _heading := Quaternion.IDENTITY

## How far it is standing on its feet rather than holding itself up in the air,
## 0 to 1. See [method _stand].
var _standing := -1.0


func _ready() -> void:
	_insect = get_parent() as Insect
	skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton"
	add_child(skeleton)
	body.build_bones(skeleton)
	shell = MeshInstance3D.new()
	shell.name = "Shell"
	skeleton.add_child(shell)
	shell.skeleton = NodePath("..")
	shell.mesh = body.mesh_for(skeleton)
	shell.skin = body.skin_for(skeleton)
	shell.visibility_range_end = 90.0
	shell.visibility_range_end_margin = 9.0
	shell.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	motion = body.make_motion()
	motion.name = "Motion"
	skeleton.add_child(motion)
	motion.bind(skeleton, body)
	motion.clock = randf() * 100.0
	_heading = quaternion


## Scales the body to [param radius] metres, keeping its feet where they were.
func resize(radius: float) -> void:
	scale = Vector3.ONE * maxf(radius, 0.001)
	_stand(0.0)


func _process(delta: float) -> void:
	if motion == null:
		return
	var velocity := _insect.velocity if _insect != null else Vector3.ZERO
	var unit := maxf(scale.x, 0.00001)
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	motion.pose = (held as CreatureMotion.Pose) if held >= 0 else _pose()
	motion.speed = flat.length() / unit
	if _insect != null:
		motion.top_speed = maxf(_insect.pace() / unit, 0.5)
	motion.climb = velocity.y / unit
	motion.effort = 0.8 if _insect != null and _insect.is_held() else 0.0
	_turn(delta, flat, velocity)
	_stand(delta)


## What the creature is doing, read off the insect.
func _pose() -> CreatureMotion.Pose:
	if _insect == null:
		return CreatureMotion.Pose.FLYING
	if _insect.is_bundle():
		return CreatureMotion.Pose.CURLED
	if _insect.is_stunned():
		return CreatureMotion.Pose.SPENT
	if _insect.is_held():
		return CreatureMotion.Pose.STRUGGLING
	if _insect.on_its_feet():
		return CreatureMotion.Pose.WALKING
	return CreatureMotion.Pose.FLYING


## Faces the way it is going, nose up a little when climbing. Wrapped, it keeps
## whatever heading it was wrapped on, level, lying in its bundle.
func _turn(delta: float, flat: Vector3, velocity: Vector3) -> void:
	var pose := motion.pose
	var moving := pose == CreatureMotion.Pose.FLYING or pose == CreatureMotion.Pose.WALKING
	if moving and flat.length() > 0.05:
		var yaw := atan2(-flat.x, -flat.z)
		var pitch := 0.0
		if pose == CreatureMotion.Pose.FLYING:
			pitch = clampf(atan2(velocity.y, flat.length()), -0.6, 0.6) * 0.5
		_heading = Quaternion(Vector3.UP, yaw) * Quaternion(Vector3.RIGHT, pitch)
	var target := _heading
	if pose == CreatureMotion.Pose.CURLED:
		target = Quaternion(Vector3.UP, _heading.get_euler().y)
	quaternion = quaternion.slerp(target, clampf(TURN_RATE * delta, 0.0, 1.0))


## Something on its feet stands on them: the body drops, or rises, until they reach
## the bottom of the creature's collider, which is where the floor is. Something in
## the air — or wrapped up — keeps its middle where the collider's middle is. Eased
## between the two, so a fly landing at a trough settles rather than drops.
func _stand(delta: float) -> void:
	if body == null:
		return
	var on_feet := 1.0 if motion != null and motion.pose == CreatureMotion.Pose.WALKING else 0.0
	if _standing < 0.0 or delta <= 0.0:
		_standing = on_feet if _standing < 0.0 else _standing
	else:
		_standing = move_toward(_standing, on_feet, SETTLE_RATE * delta)
	position.y = -(Insect.HITBOX_SCALE - body.reach_down()) * scale.x * _standing
