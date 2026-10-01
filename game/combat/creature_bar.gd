class_name CreatureBar
extends Node3D

## What a hostile has left, over its head: its health, and under it how much of it
## is wrapped.
##
## The two numbers a catch turns on, where you are looking when you need them.
## Health is what fire and harm take; the lower it is the easier the catch (see
## [method Prey.vigour]), so the bar is the odds. The silk under it is how far the
## catch has got. Shown while it is coming for you, or while it is hurt or carrying
## silk; gone once it is wrapped, and from far off.

## Furthest from the camera it is drawn, in metres.
const SEEN_FROM := 30.0

const HEALTHY := Color(0.35, 0.9, 0.4)
const HURT := Color(0.98, 0.8, 0.2)
const SPENT := Color(0.95, 0.25, 0.2)
const SILK := Color(0.95, 0.95, 1.0)

var creature: Prey = null

var _width := 0.8
var _health: MeshInstance3D
var _health_paint: StandardMaterial3D
var _wrap: MeshInstance3D


## Puts a bar over [param prey], or finds the one already there.
static func attach(prey: Prey) -> CreatureBar:
	var existing := prey.get_node_or_null("Bar") as CreatureBar
	if existing != null:
		existing.creature = prey
		return existing
	var bar := CreatureBar.new()
	bar.name = "Bar"
	bar.creature = prey
	prey.add_child(bar)
	return bar


func _ready() -> void:
	top_level = true
	_width = maxf(creature.hit_radius() * 2.2, 0.7) if creature != null else 0.8
	_part(Vector2(_width + 0.06, 0.15), Vector3(0.0, -0.02, -0.002), Color(0.05, 0.05, 0.06, 0.8))
	_health_paint = _paint(HEALTHY)
	_health = _part(Vector2(_width, 0.09), Vector3.ZERO, HEALTHY, _health_paint)
	_wrap = _part(Vector2(_width, 0.035), Vector3(0.0, -0.075, 0.0), SILK)
	visible = false


func _process(_delta: float) -> void:
	if creature == null or not is_instance_valid(creature):
		visible = false
		return
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	var showing := camera != null and _worth_showing()
	if showing:
		var at := creature.global_position + Vector3.UP * (creature.hit_radius() * 1.6 + 0.35)
		showing = camera.global_position.distance_to(at) <= SEEN_FROM
		if showing:
			global_transform = Transform3D(camera.global_basis, at)
			_fill(_health, creature.health())
			_health_paint.albedo_color = colour_for(creature.health())
			_fill(_wrap, clampf(creature.bound, 0.0, 1.0))
	visible = showing


## Whether there is anything to say: it is coming for you, or it is hurt, or it is
## carrying silk — and it is still loose.
func _worth_showing() -> bool:
	if creature.eaten or creature.wrapped or creature.is_bundled() or creature.is_dead():
		return false
	return creature.is_hunting() or creature.health() < 0.999 or creature.bound > 0.01


## Green when whole, through amber, to red with nothing left.
static func colour_for(health: float) -> Color:
	var left := clampf(health, 0.0, 1.0)
	if left > 0.5:
		return HURT.lerp(HEALTHY, (left - 0.5) * 2.0)
	return SPENT.lerp(HURT, left * 2.0)


## Shows [param share] of a bar, from its left end.
func _fill(part: MeshInstance3D, share: float) -> void:
	var left := clampf(share, 0.0, 1.0)
	part.visible = left > 0.001
	part.scale = Vector3(maxf(left, 0.001), 1.0, 1.0)
	part.position.x = -_width * (1.0 - left) * 0.5


func _part(size: Vector2, at: Vector3, colour: Color,
		paint: StandardMaterial3D = null) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = size
	var part := MeshInstance3D.new()
	part.mesh = quad
	part.position = at
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	part.material_override = paint if paint != null else _paint(colour)
	add_child(part)
	return part


func _paint(colour: Color) -> StandardMaterial3D:
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	paint.no_depth_test = true
	paint.render_priority = 10
	paint.albedo_color = colour
	return paint
