class_name SpiderGrapple
extends Node3D

## Left mouse: a thread of silk to wherever the cross is, and the spider hauled
## over to it.
##
## It is how you get about the farm — across a pen in one go, up onto the market's
## awning, over a fence with something on the end of your line. Nothing about it is
## kept: the thread is drawn while it pulls and gone once you land. You cannot hang
## from it, and there is no wait between one and the next.
##
## Picking the point is all this does. Getting there is the climb's, which hauls
## the body along the thread and puts it down on the surface at the end — see
## [method SpiderClimb.grapple_to].

signal notice(text: String)

## How far the thread reaches, in metres. Far enough for any point on the farm you
## can see from inside it; past that it is open sky, and silk needs something to
## stick to.
@export var reach := 60.0

## Closer than this, in body heights, is a step, not a grapple.
@export var least := 0.3

@export var thread_colour := Color(0.92, 0.94, 1.0, 0.85)

## Where the cross meets something the thread could stick to, the surface's normal
## there, and whether it found anything at all. Kept current by [method aim].
var aim_point := Vector3.ZERO
var aim_normal := Vector3.UP
var aim_valid := false

var _spider: SpiderPlayer
var _view: SpiderCamera
var _climb: SpiderClimb
var _mesh: ImmediateMesh
var _material: StandardMaterial3D
var _thread: MeshInstance3D


func setup(spider: SpiderPlayer, view: SpiderCamera, climb: SpiderClimb) -> void:
	_spider = spider
	_view = view
	_climb = climb


func _ready() -> void:
	_material = WebGeometry.silk_material()
	_mesh = ImmediateMesh.new()
	_thread = MeshInstance3D.new()
	_thread.name = "Thread"
	_thread.mesh = _mesh
	_thread.material_override = _material
	_thread.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_thread.top_level = true
	add_child(_thread)
	_thread.transform = Transform3D.IDENTITY


func _process(_delta: float) -> void:
	_draw()


## Looks down the cross for something to stick the thread to: the land and
## everything built on it. Insects are looked straight through — the cross can be
## on one and the thread still goes to the ground behind it. Returns whether it
## found anything.
func aim() -> bool:
	aim_valid = false
	if _view == null or _spider == null or not _spider.is_inside_tree():
		return false
	var from := _view.aim_origin()
	var query := PhysicsRayQueryParameters3D.create(from, from + _view.aim_forward() * reach,
		GameLayers.WORLD, [_spider.get_rid()])
	var hit := _spider.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	aim_normal = hit.get("normal", Vector3.UP)
	if aim_normal.length_squared() < 0.000001:
		aim_normal = Vector3.UP
	aim_normal = aim_normal.normalized()
	# Off the surface by a hair, so the body lands on it rather than in it.
	aim_point = hit["position"] + aim_normal * 0.02
	aim_valid = true
	return true


## Throws the thread where the cross is and hauls the spider after it. False, and
## says why, if there is nothing in reach to stick it to.
func fire() -> bool:
	if _climb == null or _climb.is_grappling():
		return false
	if not aim():
		notice.emit("Nothing in reach to grapple to")
		return false
	if _spider.global_position.distance_to(aim_point) < _spider.body_height * least:
		return false
	return _climb.grapple_to(aim_point, aim_normal)


## Whether a thread is out, pulling.
func pulling() -> bool:
	return _climb != null and _climb.is_grappling()


## The thread from the spider's back to where it struck, while it pulls.
func _draw() -> void:
	if _mesh == null:
		return
	_mesh.clear_surfaces()
	if not pulling() or _spider == null:
		return
	var height := _spider.body_height
	var from := _spider.global_position + _climb.body_up() * height * 0.3
	WebGeometry.draw_line_into(_mesh, _material, from, _climb.grapple_target,
		maxf(height * 0.035, 0.004), thread_colour)
