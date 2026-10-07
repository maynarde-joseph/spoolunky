class_name SilkCutter
extends Area3D

## A silk cutter: a field of violet laser beams in a metal frame, that cuts silk. A
## web flying through it comes apart there — and if the spider was riding it, the
## ride stops dead and the spider drops — and a grapple line will not go through
## it. It does nothing to the spider, which walks through it as if it were not
## there; and the Pullback's webs, which come home through walls, come home
## through it.
##
## So a level can say where silk may not go — "no ride across here", "no throw
## through this window" — without a wall in the way of anything else. Violet, not
## red: red is for the hazards that do hurt the spider.
##
## A cutter is laid out like a tile map: its face is a grid of [constant CELL]-metre
## cells, and its [member mask] says which hold lasers. The beams run on one lattice
## across every filled cell, so they join up; the frame runs only where a filled
## cell meets an empty one or the edge, so a hole in the field is framed like a
## window and two filled cells side by side are one field, not two.

const GROUP := "silk_cutter"
const COLOUR := Color(0.72, 0.32, 1.0)

## The size of a cell, how far apart the beams are, and how thick they and the
## frame are, in metres.
const CELL := 1.5
const SPACING := 0.75
const BEAM := 0.045
const FRAME := 0.14

## Its extent: across its face, and its depth (the thinnest of the three).
var size := Vector3(4.5, 4.5, 0.2)

## Which cells hold lasers: rows top to bottom, a character a cell left to right,
## "#" for lasers and anything else for open. Missing rows and cells are lasers;
## no mask at all is a field filled edge to edge.
var mask := PackedStringArray()

var _beam_paint: StandardMaterial3D
var _clock := 0.0
## The axes of its face: [code]_u[/code] across, [code]_v[/code] up (or along, for one
## lying flat), and [code]_w[/code] its depth.
var _u := 0
var _v := 1
var _w := 2
var _cols := 1
var _rows := 1


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = GameLayers.CUTTER
	collision_mask = 0
	monitoring = false
	monitorable = true
	_find_axes()
	_build_solids()
	_build_lasers()


## Where the segment from [param from] to [param to] first crosses a silk cutter, or
## an empty dictionary if it crosses none.
static func crossing(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, GameLayers.CUTTER)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.hit_from_inside = true
	return space.intersect_ray(query)


## Whether the cell [param col] across, [param row] up from the bottom, holds lasers.
func filled(col: int, row: int) -> bool:
	if col < 0 or row < 0 or col >= _cols or row >= _rows:
		return false
	var line := _rows - 1 - row
	if line >= mask.size():
		return true
	var text := mask[line]
	return col >= text.length() or text[col] == "#"


# --- the grid ----------------------------------------------------------------------

## The axes of a field of [param extent]: across, up (or along, for one lying
## flat) and its depth, the thinnest of the three.
static func axes_of(extent: Vector3) -> Vector3i:
	var w := 0
	for axis in 3:
		if extent[axis] < extent[w]:
			w = axis
	if w == 1:
		return Vector3i(0, 2, 1)
	return Vector3i(2 if w == 0 else 0, 1, w)


## How many cells across and up a field of [param extent] has.
static func cells_of(extent: Vector3) -> Vector2i:
	var axes := axes_of(extent)
	return Vector2i(maxi(int(ceil(extent[axes.x] / CELL - 0.01)), 1),
		maxi(int(ceil(extent[axes.y] / CELL - 0.01)), 1))


func _find_axes() -> void:
	var axes := axes_of(size)
	_u = axes.x
	_v = axes.y
	_w = axes.z
	var cells := cells_of(size)
	_cols = cells.x
	_rows = cells.y


## The local position of a point on the face, [param a] metres across from the left
## edge and [param b] up from the bottom, at depth 0.
func _at(a: float, b: float) -> Vector3:
	var p := Vector3(0.0, size.y * 0.5, 0.0)
	p[_u] += a - size[_u] * 0.5
	p[_v] += b - size[_v] * 0.5
	p[_w] = 0.0
	return p


## A cell's span across and up, clipped to the field's edge.
func _span(col: int, row: int) -> Rect2:
	var a0 := col * CELL
	var b0 := row * CELL
	return Rect2(a0, b0, minf(CELL, size[_u] - a0), minf(CELL, size[_v] - b0))


## One box per run of filled cells along a row.
func _build_solids() -> void:
	for row in _rows:
		var col := 0
		while col < _cols:
			if not filled(col, row):
				col += 1
				continue
			var start := col
			while col < _cols and filled(col, row):
				col += 1
			var first := _span(start, row)
			var last := _span(col - 1, row)
			var a0 := first.position.x
			var a1 := last.end.x
			var extent := Vector3.ZERO
			extent[_u] = a1 - a0
			extent[_v] = first.size.y
			extent[_w] = size[_w]
			var shape := BoxShape3D.new()
			shape.size = extent
			var volume := CollisionShape3D.new()
			volume.shape = shape
			volume.position = _at((a0 + a1) * 0.5, first.position.y + first.size.y * 0.5)
			add_child(volume)


# --- how it looks -----------------------------------------------------------------

## The beams across every filled cell, on one lattice; the frame where filled meets
## empty; and a faint haze over the filled cells, so the field reads edge-on too.
func _build_lasers() -> void:
	_beam_paint = StandardMaterial3D.new()
	_beam_paint.albedo_color = COLOUR.lightened(0.35)
	_beam_paint.emission_enabled = true
	_beam_paint.emission = COLOUR
	_beam_paint.emission_energy_multiplier = 2.5
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.16, 0.17, 0.2)
	metal.metallic = 0.7
	metal.roughness = 0.35
	var haze := StandardMaterial3D.new()
	haze.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	haze.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	haze.cull_mode = BaseMaterial3D.CULL_DISABLED
	haze.albedo_color = Color(COLOUR, 0.06)

	var beams := SurfaceTool.new()
	beams.begin(Mesh.PRIMITIVE_TRIANGLES)
	var frame := SurfaceTool.new()
	frame.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sheet := SurfaceTool.new()
	sheet.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in _rows:
		for col in _cols:
			if not filled(col, row):
				continue
			var cell := _span(col, row)
			# Beams across the cell and up it, at the lattice's lines inside it.
			for k in 2:
				var along_u := k == 0
				var lo: float = cell.position.y if along_u else cell.position.x
				var hi: float = cell.end.y if along_u else cell.end.x
				var line: float = ceil((lo + SPACING * 0.5 - 0.001) / SPACING - 0.5) * SPACING + SPACING * 0.5
				while line < hi - 0.001:
					if along_u:
						_bar(beams, _at(cell.position.x, line), _at(cell.end.x, line), BEAM)
					else:
						_bar(beams, _at(line, cell.position.y), _at(line, cell.end.y), BEAM)
					line += SPACING
			# Frame along any edge with nothing filled on the other side.
			var a0 := cell.position.x
			var a1 := cell.end.x
			var b0 := cell.position.y
			var b1 := cell.end.y
			if not filled(col - 1, row):
				_bar(frame, _at(a0, b0), _at(a0, b1), FRAME, true)
			if not filled(col + 1, row):
				_bar(frame, _at(a1, b0), _at(a1, b1), FRAME, true)
			if not filled(col, row - 1):
				_bar(frame, _at(a0, b0), _at(a1, b0), FRAME, true)
			if not filled(col, row + 1):
				_bar(frame, _at(a0, b1), _at(a1, b1), FRAME, true)
			_quad(sheet, _at(a0, b0), _at(a1, b0), _at(a1, b1), _at(a0, b1))
	_add_mesh("Beams", beams.commit(), _beam_paint)
	_add_mesh("Frame", frame.commit(), metal)
	_add_mesh("View", sheet.commit(), haze)


## A square bar from [param from] to [param to]; with [param capped], reaching past
## both ends by half its thickness, so frame bars meet cleanly at corners.
func _bar(into: SurfaceTool, from: Vector3, to: Vector3, thick: float, capped := false) -> void:
	var length := from.distance_to(to)
	if length < 0.001:
		return
	var box := BoxMesh.new()
	box.size = Vector3(thick, thick, length + (thick if capped else 0.0))
	var way := (to - from) / length
	var up := Vector3.UP if absf(way.y) < 0.99 else Vector3.RIGHT
	into.append_from(box, 0, Transform3D(Basis.looking_at(way, up), (from + to) * 0.5))


func _quad(into: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for corner in [a, b, c, a, c, d]:
		into.add_vertex(corner)


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
