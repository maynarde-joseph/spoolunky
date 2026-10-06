class_name Fly
extends Node3D

## A fly to catch: it hangs in the air where the level put it, or flies a set
## path round and round, and the first silk that touches it takes it.
##
## Taken, it is wrapped where it was and goes on a line behind the spider — see
## [FlyLine]. There it is a jump in the air, eaten when spent; whatever is still on
## the line at the exit goes in the bag. Nothing else happens to a fly:
## it does not dodge, it does not wander, and a web sitting on a wall does not
## catch one that flies into it. The only ways to take one are a thrown web that
## touches it and a web called back through it.
##
## Drawn with the fly's own body (`fly_body.tres`): the skeleton, the mesh and the
## poses it was first given, scaled up so it reads at the distances this game is
## played at.

signal caught(fly: Fly)

enum State {
	FREE,    ## hovering or on its path
	CAUGHT,  ## wrapped, and on a line behind the spider
	BAGGED,  ## in the bag at the exit
	EATEN,   ## eaten off the line for a jump
}

const GROUP := "flies"

## The fly's body, as it was first built.
const BODY := preload("res://flies/fly/fly_body.tres")

## How big a fly is drawn: its body radius, in metres. The body is drawn in that
## unit. Five times life size against a spider at a Huntsman's 0.7 m, so one can
## be picked out across a room.
const SIZE := 0.13

## How close silk has to pass, from the fly's middle, to take it.
const HIT_RADIUS := 0.32

## Points along the path, in the world. None, or one, and it hovers where it is.
var path := PackedVector3Array()

## How fast it flies its path, in metres a second.
var speed := 2.5

## Whether the path closes into a loop (three points or more) or runs back and
## forth along itself.
var loops := true

var state := State.FREE

## How it is moving, for a shot to lead it.
var velocity := Vector3.ZERO

var view: Node3D
var skeleton: Skeleton3D
var motion: CreatureMotion

var _home := Vector3.ZERO
var _leg := 0
var _forward := true
var _clock := 0.0
var _heading := Quaternion.IDENTITY
var _wrap: MeshInstance3D
var _glow: MeshInstance3D
var _halo: OmniLight3D
var _pick: Area3D


func _ready() -> void:
	add_to_group(GROUP)
	_home = global_position
	_clock = randf() * 10.0
	_build()
	if path.size() >= 2:
		global_position = path[0]
		_leg = 1


## Whether it is still out there to be caught.
func is_free() -> bool:
	return state == State.FREE


## Wrapped and taken: off its path, and the line has it from here.
func catch_it() -> bool:
	if state != State.FREE:
		return false
	state = State.CAUGHT
	velocity = Vector3.ZERO
	if _pick != null:
		_pick.collision_layer = 0
	_wrap.visible = true
	_halo.visible = false
	_glow.visible = false
	caught.emit(self)
	return true


## Eaten off the line, for a jump in the air: a puff of silk where it was, and
## gone.
func eat() -> void:
	state = State.EATEN
	var puff := MeshInstance3D.new()
	puff.name = "Puff"
	var ball := SphereMesh.new()
	ball.radius = 0.3
	ball.height = 0.6
	ball.radial_segments = 12
	ball.rings = 6
	puff.mesh = ball
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	paint.albedo_color = Color(1.0, 0.85, 0.45, 0.8)
	puff.material_override = paint
	puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(puff)
	puff.global_position = global_position
	var grow := puff.create_tween()
	grow.set_parallel(true)
	grow.tween_property(puff, "scale", Vector3.ONE * 3.0, 0.3)
	grow.tween_property(paint, "albedo_color:a", 0.0, 0.3)
	grow.chain().tween_callback(puff.queue_free)
	queue_free()


## Into the bag.
func bag() -> void:
	state = State.BAGGED
	visible = false


func _physics_process(delta: float) -> void:
	_clock += delta
	if state != State.FREE:
		return
	var was := global_position
	if path.size() >= 2:
		_fly_path(delta)
	else:
		# Hovering: a slow drift round where it was put, never far.
		global_position = _home + Vector3(sin(_clock * 1.3) * 0.12,
			sin(_clock * 2.1) * 0.08, cos(_clock * 1.1) * 0.12)
	velocity = (global_position - was) / maxf(delta, 0.0001)


func _fly_path(delta: float) -> void:
	var step := speed * delta
	while step > 0.0:
		var goal := path[_leg]
		var to := goal - global_position
		var gap := to.length()
		if gap > step:
			global_position += to / gap * step
			return
		global_position = goal
		step -= gap
		_next_leg()


func _next_leg() -> void:
	if loops and path.size() >= 3:
		_leg = (_leg + 1) % path.size()
		return
	if _forward:
		if _leg >= path.size() - 1:
			_forward = false
			_leg -= 1
		else:
			_leg += 1
	else:
		if _leg <= 0:
			_forward = true
			_leg += 1
		else:
			_leg -= 1


func _process(delta: float) -> void:
	if motion == null:
		return
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	motion.pose = CreatureMotion.Pose.CURLED if state != State.FREE \
		else CreatureMotion.Pose.FLYING
	motion.speed = flat.length() / SIZE
	motion.climb = velocity.y / SIZE
	if state == State.FREE:
		if flat.length() > 0.05:
			_heading = Quaternion(Vector3.UP, atan2(-flat.x, -flat.z))
		view.quaternion = view.quaternion.slerp(_heading, clampf(delta * 8.0, 0.0, 1.0))
		# The light it carries pulses, so a fly can be found across a room.
		var pulse := 0.5 + 0.5 * sin(_clock * 4.0)
		_halo.light_energy = 0.6 + pulse * 0.6
	else:
		var hang := _heading * Quaternion(Vector3.RIGHT, -PI * 0.5)
		view.quaternion = view.quaternion.slerp(hang, clampf(delta * 8.0, 0.0, 1.0))


func _build() -> void:
	view = Node3D.new()
	view.name = "Body"
	view.scale = Vector3.ONE * SIZE
	add_child(view)
	skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton"
	view.add_child(skeleton)
	BODY.build_bones(skeleton)
	var shell := MeshInstance3D.new()
	shell.name = "Shell"
	skeleton.add_child(shell)
	shell.skeleton = NodePath("..")
	shell.mesh = BODY.mesh_for(skeleton)
	shell.skin = BODY.skin_for(skeleton)
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	motion = BODY.make_motion()
	motion.name = "Motion"
	skeleton.add_child(motion)
	motion.bind(skeleton, BODY)
	motion.clock = randf() * 100.0

	# Silk round it once it is caught: a pale cocoon a little bigger than the body.
	_wrap = MeshInstance3D.new()
	_wrap.name = "Wrap"
	var cocoon := SphereMesh.new()
	cocoon.radius = SIZE * 1.25
	cocoon.height = SIZE * 3.4
	cocoon.radial_segments = 12
	cocoon.rings = 8
	_wrap.mesh = cocoon
	var silk := StandardMaterial3D.new()
	silk.albedo_color = Color(0.93, 0.94, 0.97, 0.82)
	silk.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	silk.roughness = 0.5
	silk.emission_enabled = true
	silk.emission = Color(0.7, 0.75, 0.9)
	silk.emission_energy_multiplier = 0.25
	_wrap.material_override = silk
	_wrap.visible = false
	add_child(_wrap)

	# A soft glow round it while it is free, for finding it.
	_glow = MeshInstance3D.new()
	_glow.name = "Glow"
	var ball := SphereMesh.new()
	ball.radius = HIT_RADIUS
	ball.height = HIT_RADIUS * 2.0
	ball.radial_segments = 16
	ball.rings = 8
	_glow.mesh = ball
	var aura := StandardMaterial3D.new()
	aura.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	aura.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aura.albedo_color = Color(1.0, 0.82, 0.32, 0.12)
	aura.cull_mode = BaseMaterial3D.CULL_FRONT
	_glow.material_override = aura
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_glow)

	_halo = OmniLight3D.new()
	_halo.name = "Halo"
	_halo.light_color = Color(1.0, 0.8, 0.4)
	_halo.omni_range = 2.2
	_halo.light_energy = 0.8
	_halo.shadow_enabled = false
	add_child(_halo)

	# What the crosshair finds: the camera's aim reads areas on the prey layer.
	_pick = Area3D.new()
	_pick.name = "Pick"
	_pick.collision_layer = GameLayers.PREY
	_pick.collision_mask = 0
	_pick.monitoring = false
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = HIT_RADIUS
	shape.shape = sphere
	_pick.add_child(shape)
	add_child(_pick)
