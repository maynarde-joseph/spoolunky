class_name WeaverBody
extends Node3D

## The spider you see: the old game's skeleton, its minimal mesh (two smooth blobs
## on eight thin legs, two eyes, one colour) and its eight-legged gait, told every
## frame what the [Weaver] is doing. The legs find their own footholds, so on a web
## on a wall they stand on the web.

@export var body_colour := Color(0.09, 0.075, 0.08)
@export var leg_colour := Color(0.12, 0.1, 0.1)
@export var band_colour := Color(0.42, 0.33, 0.24)
@export var marking_colour := Color(0.55, 0.43, 0.3)
@export var eye_colour := Color(0.9, 0.55, 0.2)

var skeleton: Skeleton3D
var gait: SpiderGait
var mesh: MeshInstance3D

var _weaver: Weaver


func _ready() -> void:
	skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton"
	add_child(skeleton)
	SpiderRig.build_bones(skeleton)
	mesh = MeshInstance3D.new()
	mesh.name = "Shell"
	skeleton.add_child(mesh)
	mesh.skeleton = NodePath("..")
	mesh.skin = skeleton.create_skin_from_rest_transforms()
	mesh.mesh = SpiderRig.build_mesh(skeleton, {
		"body": body_colour, "legs": leg_colour, "band": band_colour,
		"marking": marking_colour, "eyeshine": eye_colour,
	}, SpiderRig.Look.MINIMAL)
	gait = SpiderGait.new()
	gait.name = "Gait"
	skeleton.add_child(gait)
	gait.bind(skeleton)


func setup(weaver: Weaver) -> void:
	_weaver = weaver
	scale = Vector3.ONE * Weaver.HEIGHT
	# The body hangs off the middle of a ball; its feet want to be a little lower.
	position = Vector3(0.0, -Weaver.HEIGHT * 0.06, 0.0)
	gait.exclude = [weaver.get_rid()]
	gait.mask = GameLayers.WORLD | GameLayers.WEB_WALK
	gait.reset_feet()


func animate(delta: float) -> void:
	if gait == null or _weaver == null:
		return
	if not is_visible_in_tree():
		gait.active = false
		return
	gait.active = true
	match _weaver.mode:
		Weaver.Mode.GROUND, Weaver.Mode.WEB:
			gait.stance = SpiderGait.Stance.GROUND
		Weaver.Mode.GRAPPLE:
			gait.stance = SpiderGait.Stance.GRAPPLING
		_:
			gait.stance = SpiderGait.Stance.AIR
	gait.velocity = _weaver.moving_velocity()
	var held := _weaver.caster.held_ball()
	gait.aim = clampf(_weaver.view.aim_blend, 0.0, 1.0) if held != null \
		else move_toward(gait.aim, 0.0, delta * 4.0)
	gait.ball = held.global_position if held != null \
		else global_position + global_basis.y.normalized() * Weaver.HEIGHT
	gait.towing = _weaver.fly_line.pull()
