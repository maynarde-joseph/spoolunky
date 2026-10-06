class_name Pullback
extends Node3D

## E (or the middle mouse button): every web in reach flies back to you.
##
## Each comes off whatever it was on and flies straight home through anything in
## the way, wrapping every fly it passes and bringing whatever it was stuck to —
## a crate — to put down at your feet. The silk is yours to throw again the
## moment it lets go. The web you are standing on, or riding, is taken back where
## it is: it comes apart under you and you carry on with whatever speed it gave
## you.
##
## It goes while silk is held, and the ball is still there afterwards.

## How far it reaches, in metres.
const REACH := 60.0

## The least time between calls.
const COOLDOWN := 0.35

var weaver: Weaver

var _cooling := 0.0
var _flash := 0.0
var _lines: MeshInstance3D
var _mesh: ImmediateMesh
var _paint: StandardMaterial3D
var _called: Array[Vector3] = []


func setup(owner_weaver: Weaver) -> void:
	weaver = owner_weaver
	_mesh = ImmediateMesh.new()
	_paint = StandardMaterial3D.new()
	_paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	_paint.vertex_color_use_as_albedo = true
	_lines = MeshInstance3D.new()
	_lines.name = "Lines"
	_lines.mesh = _mesh
	_lines.top_level = true
	_lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_lines)


## The webs a call now would bring home.
func callable_webs() -> Array[ThrownWeb]:
	var found: Array[ThrownWeb] = []
	for web in weaver.webs():
		if web.is_standing() and web.global_position.distance_to(weaver.global_position) <= REACH:
			found.append(web)
	return found


## Calls every web in reach home. False if there were none, or it was too soon.
func cast() -> bool:
	if _cooling > 0.0:
		return false
	var webs := callable_webs()
	if webs.is_empty():
		weaver.notify("No web in reach to call back")
		return false
	_called.clear()
	var under := weaver.standing_web()
	for web in webs:
		_called.append(web.global_position)
		if web == under:
			weaver.let_go_of_web()
			web.reclaim()
		else:
			web.call_back(weaver)
	_cooling = COOLDOWN
	_flash = 0.3
	return true


func _process(delta: float) -> void:
	_cooling = maxf(0.0, _cooling - delta)
	_mesh.clear_surfaces()
	_lines.global_transform = Transform3D.IDENTITY
	if _flash <= 0.0:
		return
	_flash -= delta
	var tint := Color(0.75, 0.85, 1.0, clampf(_flash * 3.0, 0.0, 1.0) * 0.6)
	for at in _called:
		WebGeometry.draw_line_into(_mesh, _paint, weaver.global_position, at, 0.03, tint)
