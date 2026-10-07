class_name SilkCutter
extends Area3D

## A silk cutter: a grid of violet laser beams in a metal frame, that cuts silk. A web flying through it
## comes apart there — and if the spider was riding it, the ride stops dead and the
## spider drops — and a grapple line will not go through it. It does nothing to
## the spider, which walks through it as if it were not there; and the Pullback's
## webs, which come home through walls, come home through it.
##
## So a level can say where silk may not go — "no ride across here", "no throw
## through this window" — without a wall in the way of anything else. Violet, not
## red: red is for the hazards that do hurt the spider.

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
	_build_lasers()


## Where the segment from [param from] to [param to] first crosses a silk cutter, or
## an empty dictionary if it crosses none.
static func crossing(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, GameLayers.CUTTER)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.hit_from_inside = true
	return space.intersect_ray(query)


## How far apart its beams are, and how thick they and its frame are, in metres.
const SPACING := 0.75
const BEAM := 0.045
const FRAME := 0.14

var _beam_paint: StandardMaterial3D
var _clock := 0.0


## A grid of laser beams strung across a dark metal frame: lines one way and the
## other across the cutter's face, every [constant SPACING], with a faint haze
## between so the plane reads edge-on too.
func _build_lasers() -> void:
	# Its face is the two longest sides; the thin one is its depth.
	var thin := 0
	for axis in 3:
		if size[axis] < size[thin]:
			thin = axis
	var across: Array[int] = []
	for axis in 3:
		if axis != thin:
			across.append(axis)
	var middle := Vector3(0.0, size.y * 0.5, 0.0)
	var half := size * 0.5

	_beam_paint = StandardMaterial3D.new()
	_beam_paint.albedo_color = COLOUR.lightened(0.35)
	_beam_paint.emission_enabled = true
	_beam_paint.emission = COLOUR
	_beam_paint.emission_energy_multiplier = 2.5
	var beams := SurfaceTool.new()
	beams.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 2:
		var along := across[k]
		var step_axis := across[1 - k]
		var count := maxi(int(floor(size[step_axis] / SPACING)), 1)
		var first := -half[step_axis] + (size[step_axis] - SPACING * (count - 1)) * 0.5
		for n in count:
			var at := middle
			at[step_axis] += first + SPACING * n
			var extent := Vector3.ONE * BEAM
			extent[along] = size[along]
			_add_box(beams, at, extent)
	_add_mesh("Beams", beams.commit(), _beam_paint)

	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.16, 0.17, 0.2)
	metal.metallic = 0.7
	metal.roughness = 0.35
	var frame := SurfaceTool.new()
	frame.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 2:
		var along := across[k]
		var side := across[1 - k]
		for sign in [-1.0, 1.0]:
			var at := middle
			at[side] += sign * half[side]
			var extent := Vector3.ONE * FRAME
			extent[along] = size[along] + FRAME
			_add_box(frame, at, extent)
	_add_mesh("Frame", frame.commit(), metal)

	var haze := StandardMaterial3D.new()
	haze.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	haze.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	haze.cull_mode = BaseMaterial3D.CULL_DISABLED
	haze.albedo_color = Color(COLOUR, 0.06)
	var sheet := BoxMesh.new()
	var flat := size
	flat[thin] = 0.01
	sheet.size = flat
	var view := _add_mesh("View", sheet, haze)
	view.position = middle


func _add_box(into: SurfaceTool, at: Vector3, extent: Vector3) -> void:
	var box := BoxMesh.new()
	box.size = extent
	into.append_from(box, 0, Transform3D(Basis.IDENTITY, at))


func _add_mesh(called: String, mesh: Mesh, paint: Material) -> MeshInstance3D:
	var view := MeshInstance3D.new()
	view.name = called
	view.mesh = mesh
	view.material_override = paint
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(view)
	return view


## The beams hum: their glow rises and falls a little.
func _process(delta: float) -> void:
	if _beam_paint == null:
		return
	_clock += delta
	_beam_paint.emission_energy_multiplier = 2.2 + sin(_clock * 9.0) * 0.5 + sin(_clock * 23.0) * 0.2
