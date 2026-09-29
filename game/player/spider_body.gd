class_name SpiderBody
extends Node3D

## The spider you see: a skeleton, one skinned mesh riding it, and a gait that
## puts eight feet down on whatever the spider is standing on.
##
## It was a stand-in built from primitives, with legs that swung in two sets and
## never touched anything, which was enough to read the spider's size and which
## way it faced. It is a rig now — see [SpiderRig] for the bones and [SpiderGait]
## for how they move — and this node's job is only to build it and to tell the
## gait, every frame, what the rest of the spider is doing.
##
## Local forward is -Z, matching the body it hangs off, and the node is scaled to
## the tier, so everything under it is in body heights.

@export var body_colour := Color(0.09, 0.075, 0.08)
@export var leg_colour := Color(0.12, 0.1, 0.1)
## The pale bands at the joints and the folium down the abdomen.
@export var band_colour := Color(0.42, 0.33, 0.24)
@export var marking_colour := Color(0.55, 0.43, 0.3)
## Eyeshine: faint, so the head can be found across a dark room.
@export var eye_colour := Color(0.9, 0.55, 0.2)

var skeleton: Skeleton3D
var gait: SpiderGait
var mesh: MeshInstance3D

var _spider: SpiderPlayer
var _height := 0.25
var _was_visible := true


func _ready() -> void:
	_build()


## Hands over the spider, so the body can see what it is doing. Without it the
## body still walks — on the speed it is given and nothing else.
func setup(spider: SpiderPlayer) -> void:
	_spider = spider
	if gait != null:
		gait.exclude = [spider.get_rid()]
	if spider.vitals != null:
		spider.vitals.hurt.connect(func(_amount: float, _left: float) -> void:
			if gait != null:
				gait.flinch())


## Rescales the whole spider. Called whenever the size tier changes.
func set_body_height(height: float) -> void:
	_height = maxf(height, 0.01)
	scale = Vector3.ONE * _height
	# Feet were put down for the old size. Put them down again for this one.
	if gait != null:
		gait.reset_feet()


## Tells the gait what the spider is doing this frame. [param speed] is metres
## per second along the ground, and is only used when there is no spider to ask.
func animate(delta: float, speed: float) -> void:
	if gait == null:
		return
	# Nobody sees it in first person, so nothing is worked out for it — and when
	# it comes back into view its feet go down fresh rather than from wherever
	# they were left.
	if not is_visible_in_tree():
		gait.active = false
		_was_visible = false
		return
	if not _was_visible:
		gait.reset_feet()
		_was_visible = true
	gait.active = true

	var here := global_position
	if _spider == null:
		gait.stance = SpiderGait.Stance.GROUND
		gait.velocity = -global_basis.z.normalized() * speed
		return
	gait.stance = _stance()
	# The body's own velocity from physics, not the change in position between
	# drawn frames: the body only moves on a physics tick, so between ticks it
	# reads as standing still and on the tick as running at several times its
	# speed. Riding sets the position outright, and says its speed in velocity.
	gait.velocity = _spider.velocity if gait.stance == SpiderGait.Stance.RIDING \
		else _spider.get_real_velocity()
	var climb := _spider.climb
	match gait.stance:
		SpiderGait.Stance.HANGING:
			gait.line_a = climb.line_anchor
			gait.line_b = climb.line_anchor
		SpiderGait.Stance.RIDING:
			if is_instance_valid(climb.ride_web):
				gait.line_a = climb.ride_web.point_a
				gait.line_b = climb.ride_web.point_b
	gait.spread = climb.glide
	var builder := _spider.web_builder
	gait.aim = clampf(_spider.view.aim_blend, 0.0, 1.0) if builder != null and builder.aiming \
		else move_toward(gait.aim, 0.0, delta * 4.0)
	var held := builder.get_node_or_null("HeldSilk") as Node3D if builder != null else null
	gait.ball = held.global_position if held != null and held.visible \
		else here + global_basis.y.normalized() * _height
	gait.feeding = _spider.feeding != null
	var tether := _spider.tether
	if tether != null and tether.is_towing() and is_instance_valid(tether.cargo):
		gait.towing = tether.cargo.global_position - here
	else:
		gait.towing = Vector3.ZERO


## What the legs should be doing, read off the climb.
func _stance() -> SpiderGait.Stance:
	var climb := _spider.climb
	if climb == null or not climb.handles_movement():
		return SpiderGait.Stance.AIR
	match climb.mode:
		SpiderClimb.Mode.ATTACHED:
			return SpiderGait.Stance.GROUND
		SpiderClimb.Mode.HANGING:
			return SpiderGait.Stance.HANGING
		SpiderClimb.Mode.RIDING:
			return SpiderGait.Stance.RIDING
		SpiderClimb.Mode.GRAPPLING:
			return SpiderGait.Stance.GRAPPLING
	return SpiderGait.Stance.AIR


## Where each foot was drawn last frame — the tip of every tarsus, in the world,
## in leg order: L1 R1 L2 R2 L3 R3 L4 R4. See [method SpiderGait.drawn_feet] for
## why the gait keeps these rather than the skeleton.
func feet() -> PackedVector3Array:
	return gait.drawn_feet() if gait != null else PackedVector3Array()


func _build() -> void:
	skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton"
	add_child(skeleton)
	SpiderRig.build_bones(skeleton)

	mesh = MeshInstance3D.new()
	mesh.name = "Shell"
	mesh.mesh = SpiderRig.build_mesh(skeleton, {
		"body": body_colour, "legs": leg_colour, "band": band_colour,
		"marking": marking_colour, "eyeshine": eye_colour,
	})
	skeleton.add_child(mesh)
	mesh.skeleton = NodePath("..")
	mesh.skin = skeleton.create_skin_from_rest_transforms()

	gait = SpiderGait.new()
	gait.name = "Gait"
	skeleton.add_child(gait)
	gait.bind(skeleton)
