class_name Shrine
extends Node3D

## Somewhere to come back to: a lamp of old silk on a stone.
##
## Touch one and it is lit, and from then on it is where you wake when you are
## driven off. Rest at one — the interact key, standing at it — and you are whole
## again, and the place stirs: everything you put down is back where it stood.
## That is the bargain the place makes, and why a shrine is a decision rather than
## a free heal. You cannot rest with something coming for you.
##
## [Checkpoints] keeps the memory of which one you lit last and does the waking;
## a shrine only knows whether it is lit, and where in front of it you get up.

signal kindled(shrine: Shrine)

@export var display_name := "Shrine"
@export var lit := false

## How close counts as standing at it, from its middle.
@export var reach := 2.6

## The flame's colour, lit.
const FLAME := Color(1.0, 0.72, 0.4)
const COLD := Color(0.32, 0.3, 0.3)

var _flame: MeshInstance3D
var _glow: OmniLight3D
var _near := false


## One standing at [param at] in the world — the foot of it — facing [param facing]
## across the floor, which is where you get up when you wake at it.
static func make(parent: Node3D, shrine_name: String, at: Vector3, facing: Vector3,
		lit_at_start := false) -> Shrine:
	var shrine := Shrine.new()
	shrine.name = shrine_name.replace(" ", "")
	shrine.display_name = shrine_name
	shrine.lit = lit_at_start
	var flat := Vector3(facing.x, 0.0, facing.z)
	if flat.length_squared() < 0.0001:
		flat = Vector3.BACK
	parent.add_child(shrine)
	# Facing along its own +Z: the side you wake on.
	shrine.global_transform = Transform3D(Basis.looking_at(-flat, Vector3.UP), at)
	shrine._build()
	return shrine


func _build() -> void:
	var stone := WorldKit.body(self, "Stone")
	WorldKit.box(stone, "Plinth", Vector3(1.3, 1.1, 1.3), WorldKit.at(Vector3(0.0, 0.55, 0.0)),
		"ruin_dark")
	WorldKit.box(stone, "Step", Vector3(2.2, 0.2, 2.2), WorldKit.at(Vector3(0.0, 0.1, 0.0)),
		"ruin")
	WorldKit.cylinder(stone, "Bowl", 0.5, 0.2, WorldKit.at(Vector3(0.0, 1.2, 0.0)), "ruin", true,
		0.62, 16)
	var ball := SphereMesh.new()
	ball.radius = 0.24
	ball.height = 0.48
	ball.radial_segments = 12
	ball.rings = 6
	_flame = MeshInstance3D.new()
	_flame.name = "Flame"
	_flame.mesh = ball
	_flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flame.position = Vector3(0.0, 1.5, 0.0)
	add_child(_flame)
	_glow = OmniLight3D.new()
	_glow.name = "Glow"
	_glow.position = Vector3(0.0, 2.2, 0.0)
	_glow.omni_range = 10.0
	_glow.light_color = FLAME
	add_child(_glow)
	_show()


func _ready() -> void:
	add_to_group("shrines")
	# Built this run, the pieces are already in hand; loaded from a baked scene,
	# they are children with nothing pointing at them.
	if _flame == null:
		_flame = get_node_or_null("Flame") as MeshInstance3D
		_glow = get_node_or_null("Glow") as OmniLight3D
	_show()


func _physics_process(_delta: float) -> void:
	var spider := _spider()
	_near = spider != null and spider.global_position.distance_to(_middle()) <= reach
	if not _near:
		return
	if not lit:
		kindle()
	if Input.is_action_just_pressed("interact"):
		var keeper := Checkpoints.of(self)
		if keeper != null:
			keeper.rest_at(self)


## Lights it: from now on it is somewhere to wake.
func kindle() -> void:
	if lit:
		return
	lit = true
	_show()
	kindled.emit(self)
	var spider := _spider()
	if spider != null:
		spider.notice.emit("%s lit — you will wake here" % display_name)


## Whether the spider is standing at it.
func is_near() -> bool:
	return _near


## Where you get up when you wake here: in front of it, facing away from it.
func wake_transform() -> Transform3D:
	var out := global_basis.z
	out.y = 0.0
	out = out.normalized() if out.length_squared() > 0.0001 else Vector3.BACK
	return Transform3D(Basis.looking_at(out, Vector3.UP),
		global_position + out * 1.8 + Vector3.UP * 0.7)


func _middle() -> Vector3:
	return global_position + Vector3.UP * 0.6


func _show() -> void:
	if _flame != null:
		var paint := StandardMaterial3D.new()
		paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		paint.albedo_color = FLAME if lit else COLD
		_flame.material_override = paint
		_flame.scale = Vector3.ONE * (1.0 if lit else 0.6)
	if _glow != null:
		_glow.light_energy = 1.8 if lit else 0.0
		_glow.visible = lit


func _spider() -> SpiderPlayer:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group("spider") as SpiderPlayer
