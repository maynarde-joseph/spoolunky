class_name Grapple
extends Node3D

## The line a held left mouse puts the spider on: from the spider to the web it has
## just thrown, pulling it along to the web's middle and onto it as the web flies.
## The spider rides the web wherever it goes, until it sticks or stops dead. A ride
## is a commitment: no jumping off, no stepping off. Jump while the line is still
## pulling, before you are on, and you drop where you are.
##
## One ride in the air: the grapple is spent the moment the line goes, and comes
## back when the spider lands, on the ground or on a web that has stuck. A hold
## with it spent only throws.
##
## This node keeps hold of the web while the spider is pulled, and draws the line.
## The pulling itself is the spider's — see [method Weaver.start_grapple].

## How fast the spider is pulled, in metres a second — and quicker on a long line,
## so that no pull takes longer than [constant LONGEST].
const SPEED := 18.2
const LONGEST := 1.1

var weaver: Weaver
var view: SpiderCamera

## The web the line is on while it pulls. It pulls to the web's middle.
var web: ThrownWeb = null
var active := false

## The pull's own speed, set when it goes.
var speed := SPEED

var _line: MeshInstance3D
var _mesh: ImmediateMesh
var _paint: StandardMaterial3D


func setup(owner_weaver: Weaver, camera: SpiderCamera) -> void:
	weaver = owner_weaver
	view = camera
	_mesh = ImmediateMesh.new()
	_paint = WebGeometry.silk_material()
	_paint.emission_energy_multiplier = 0.8
	_line = MeshInstance3D.new()
	_line.name = "Line"
	_line.mesh = _mesh
	_line.material_override = _paint
	_line.top_level = true
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_line)


## Puts the line on [param thrown], the web just thrown, to ride it.
func hold_on(thrown: ThrownWeb) -> void:
	web = thrown
	speed = SPEED
	active = true


## Where the line is pulling to now: the web's middle, wherever it has gone.
func target_point() -> Vector3:
	if web != null and is_instance_valid(web):
		return web.global_position
	return weaver.global_position


## Whether the web the line was on has gone: come apart, or called home.
func lost() -> bool:
	return web == null or not is_instance_valid(web) or not web.is_standing()


func end() -> void:
	active = false
	web = null


func _process(_delta: float) -> void:
	if _mesh == null:
		return
	_mesh.clear_surfaces()
	_line.global_transform = Transform3D.IDENTITY
	var from := weaver.global_position + weaver.global_basis.y * 0.1
	if active:
		WebGeometry.draw_line_into(_mesh, _paint, from, target_point(), 0.035,
			Color(0.95, 0.96, 1.0, 0.95))
