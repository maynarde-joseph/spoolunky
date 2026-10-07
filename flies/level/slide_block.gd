class_name SlideBlock
extends AnimatableBody3D

## A block on a rail. Silk sticks to it, and goes with it; and call a web on it home
## and the block is dragged along its rail toward you — to where, on its rail, its
## top is nearest your feet when you called — and stops there. Pulled into a gap it
## is a stepping stone; pulled up beside the ledge you stand on, a step level with
## it. Stand somewhere else and call again, and it goes back.
##
## The rail runs from where the block starts, by [member travel], in any direction
## — along the floor, straight up, slantwise — and the block never leaves it. Nothing
## but the Pullback moves it: it does not fall.

## Where the rail goes, from where the block starts, in the level's own axes.
var travel := Vector3(0.0, 0.0, -6.0)

## How fast it slides, in metres a second.
var speed := 6.0

## How tall it is, from its base (where it is placed) to its top.
var height := 1.0

var _start := Vector3.ZERO
## How far along the rail it is, and where it is going: 0 at its start, 1 at the end.
var _goal := 0.0


func _ready() -> void:
	collision_layer = GameLayers.WORLD
	collision_mask = 0
	sync_to_physics = true
	_start = position
	_build_rail()


## How far along its rail it is, 0 at its start and 1 at the far end.
func along() -> float:
	if travel.length_squared() < 0.0001:
		return 0.0
	return clampf((position - _start).dot(travel) / travel.length_squared(), 0.0, 1.0)


## Dragged toward the spider at [param spider]: it slides to the place on its rail
## where its top is nearest the spider's feet. Along a floor that is simply the
## nearest place; up or down a rail, it is where its top is level with them.
func drag_toward(spider: Vector3) -> void:
	if travel.length_squared() < 0.0001:
		return
	var parent := get_parent() as Node3D
	var from := parent.to_global(_start) if parent != null else _start
	var rail := (parent.global_basis * travel) if parent != null else travel
	var base_wanted := spider - Vector3.UP * (Weaver.RADIUS + height)
	_goal = clampf((base_wanted - from).dot(rail) / rail.length_squared(), 0.0, 1.0)


func _physics_process(delta: float) -> void:
	if travel.length_squared() < 0.0001:
		return
	var now := along()
	if absf(now - _goal) < 0.0001:
		return
	var next := move_toward(now, _goal, speed * delta / travel.length())
	position = _start + travel * next


## A dark bar under the block's path, so the way it can go reads at a glance.
func _build_rail() -> void:
	if travel.length_squared() < 0.0001:
		return
	var bar := MeshInstance3D.new()
	bar.name = "Rail"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.35, 0.12, travel.length())
	bar.mesh = mesh
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.95, 0.66, 0.22)
	paint.emission_enabled = true
	paint.emission = Color(0.95, 0.6, 0.2)
	paint.emission_energy_multiplier = 0.8
	bar.material_override = paint
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bar.top_level = true
	add_child(bar)
	var middle := _start + travel * 0.5
	var parent := get_parent() as Node3D
	var at := parent.to_global(middle) if parent != null else middle
	var along_rail := (parent.global_basis * travel) if parent != null else travel
	bar.global_transform = Transform3D(Basis.looking_at(along_rail.normalized(),
		Vector3.UP if absf(along_rail.normalized().y) < 0.99 else Vector3.RIGHT), at + Vector3.UP * 0.03)
