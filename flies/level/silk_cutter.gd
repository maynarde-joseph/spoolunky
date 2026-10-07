class_name SilkCutter
extends Area3D

## A silk cutter: a sheet of violet light that cuts silk. A web flying through it
## comes apart there — and if the spider was riding it, the ride stops dead and the
## spider drops — and a grapple line will not go through it. It does nothing to
## the spider, which walks through it as if it were not there; and the Pullback's
## webs, which come home through walls, come home through it.
##
## So a level can say where silk may not go — "no ride across here", "no throw
## through this window" — without a wall in the way of anything else.

const GROUP := "silk_cutter"
const COLOUR := Color(0.72, 0.32, 1.0)

var size := Vector3(4.0, 4.0, 0.2)


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = GameLayers.CUTTER
	collision_mask = 0
	monitoring = false
	monitorable = true
	var shape := BoxShape3D.new()
	shape.size = size
	var volume := CollisionShape3D.new()
	volume.shape = shape
	volume.position.y = size.y * 0.5
	add_child(volume)
	var sheet := MeshInstance3D.new()
	sheet.name = "View"
	var box := BoxMesh.new()
	box.size = size
	sheet.mesh = box
	sheet.position.y = size.y * 0.5
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.cull_mode = BaseMaterial3D.CULL_DISABLED
	glow.albedo_color = Color(COLOUR, 0.28)
	sheet.material_override = glow
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sheet)
	_frame()


## Where the segment from [param from] to [param to] first crosses a silk cutter, or
## an empty dictionary if it crosses none.
static func crossing(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, GameLayers.CUTTER)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.hit_from_inside = true
	return space.intersect_ray(query)


## Bright bars round its edges, so it reads from any side.
func _frame() -> void:
	var edge := StandardMaterial3D.new()
	edge.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	edge.albedo_color = COLOUR
	var half := size * 0.5
	var middle := Vector3(0.0, half.y, 0.0)
	var thick := 0.08
	for axis in 3:
		var others := [0, 1, 2]
		others.erase(axis)
		for a in [-1.0, 1.0]:
			for b in [-1.0, 1.0]:
				var at := middle
				at[others[0]] += a * half[others[0]]
				at[others[1]] += b * half[others[1]]
				var bar := MeshInstance3D.new()
				var mesh := BoxMesh.new()
				var extent := Vector3.ONE * thick
				extent[axis] = size[axis] + thick
				mesh.size = extent
				bar.mesh = mesh
				bar.material_override = edge
				bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				bar.position = at
				add_child(bar)
