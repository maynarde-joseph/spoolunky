class_name CreatureView
extends Node3D

## A creature's body in the world: the skeleton, the mesh its [CreatureBody] skins
## to it, and the [CreatureMotion] that poses it. It sits under a [Prey] as the
## node called Body and watches it to know what to do, so the prey never has to
## know it is there.
##
## It is scaled to the creature's body radius, so everything under it is in the
## body's own unit. It turns to face where the creature is going, which the prey
## itself never does: its collider is a ball, and a ball has no front.

## How quickly it swings round to a new heading, per second.
const TURN_RATE := 10.0

var body: CreatureBody
var skeleton: Skeleton3D
var shell: MeshInstance3D
var motion: CreatureMotion

## Holds the body in one [enum CreatureMotion.Pose] whatever the creature is
## doing, or -1 to follow it. For pictures and checks.
var held := -1

var _prey: Prey
var _heading := Quaternion.IDENTITY


func _ready() -> void:
	_prey = get_parent() as Prey
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
	motion = body.make_motion()
	motion.name = "Motion"
	skeleton.add_child(motion)
	motion.bind(skeleton, body)
	motion.clock = randf() * 100.0
	_heading = quaternion
	# Something that walks stands on its feet: the body drops, or rises, until
	# they reach the bottom of the creature's collider, which is where the floor
	# is. Something that flies keeps its middle where the collider's middle is.
	if _prey != null and not _prey.flying:
		position.y = -(Prey.HITBOX_SCALE - body.reach_down()) * scale.x


func _process(delta: float) -> void:
	if motion == null:
		return
	var velocity := _prey.velocity if _prey != null else Vector3.ZERO
	var unit := maxf(scale.x, 0.00001)
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	motion.pose = (held as CreatureMotion.Pose) if held >= 0 else _pose()
	motion.speed = flat.length() / unit
	if _prey != null:
		motion.top_speed = maxf(_prey.move_speed / unit, 0.5)
	motion.climb = velocity.y / unit
	motion.effort = _prey.fight_left() if _prey != null else 0.0
	_turn(delta, flat, velocity)


## What the creature is doing, read off the prey.
func _pose() -> CreatureMotion.Pose:
	if _prey == null:
		return CreatureMotion.Pose.FLYING
	if _prey.wrapped or _prey.is_bundled():
		return CreatureMotion.Pose.CURLED
	# Out of it — stunned, or dead — limp, the way something that has fought
	# itself out hangs.
	if _prey.is_stunned() or _prey.is_dead():
		return CreatureMotion.Pose.SPENT
	if _prey.is_fighting():
		return CreatureMotion.Pose.STRUGGLING
	if _prey.is_stuck():
		return CreatureMotion.Pose.SPENT
	return CreatureMotion.Pose.FLYING if _prey.flying else CreatureMotion.Pose.WALKING


## Faces the way it is going, nose up a little when climbing. Caught, it keeps
## whatever heading it was caught on. Wrapped, it hangs head down, which is the
## shape the bundle round it is.
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
		target = _heading * Quaternion(Vector3.RIGHT, -PI * 0.5)
	elif _prey != null and _prey.is_dead():
		# Dead, it lies on its side.
		target = _heading * Quaternion(Vector3.BACK, PI * 0.5)
	quaternion = quaternion.slerp(target, clampf(TURN_RATE * delta, 0.0, 1.0))
