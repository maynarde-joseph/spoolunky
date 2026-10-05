class_name FarmBuilder
extends Node3D

## Putting things down on the farm: what the shop sends the spider out with.
##
## Pick something in the shop and the spider is building it: a see-through copy of
## it follows the cross over the ground, snapped to the farm's grid, green where it
## can go and red where it cannot, with the reason under the cross. Left mouse puts
## one down and keeps the next in hand; R turns it; right mouse puts it away.
##
## Fence goes up a run at a time: left mouse on one corner of the grid, then on the
## opposite one, and the outline of the rectangle between them goes up — a pen in
## two clicks. Corners in a row make a straight run. A gate goes on one edge, on its
## own or in place of a length of fence.
##
## X takes down whatever built thing the cross is on, for half what it cost —
## building or not.

signal notice(text: String)

## How far down the cross the ground is looked for, in metres.
const REACH := 80.0

## How many cells out from the cross the grid is drawn, while building.
const GRID_SHOWN := 4

const GOOD := Color(0.45, 1.0, 0.55, 0.45)
const BAD := Color(1.0, 0.35, 0.3, 0.45)

## Whether the spider is building, and what.
var active := false
var kind: StructureKind = null

## How many quarter turns what is in hand is turned.
var quarter := 0

## The first corner of a run of fence, once it is picked.
var run_start := Vector2i.ZERO
var has_start := false

## Where the cross meets the ground, whether it does, whether what is in hand can
## go there — and if not, why not.
var cursor := Vector3.ZERO
var aimed := false
var valid := false
var reason := ""

var _spider: SpiderPlayer
var _view: SpiderCamera
var _ghost: Node3D
var _ghost_key := ""
var _good: StandardMaterial3D
var _bad: StandardMaterial3D
var _grid_mesh: ImmediateMesh
var _grid_paint: StandardMaterial3D
var _grid_view: MeshInstance3D


func setup(spider: SpiderPlayer, view: SpiderCamera) -> void:
	_spider = spider
	_view = view


func _ready() -> void:
	_good = _paint(GOOD)
	_bad = _paint(BAD)
	_grid_paint = _paint(Color(1.0, 1.0, 1.0, 0.25))
	_grid_paint.vertex_color_use_as_albedo = true
	_grid_mesh = ImmediateMesh.new()
	_grid_view = MeshInstance3D.new()
	_grid_view.name = "Grid"
	_grid_view.mesh = _grid_mesh
	_grid_view.material_override = _grid_paint
	_grid_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_grid_view.top_level = true
	add_child(_grid_view)
	_grid_view.global_transform = Transform3D.IDENTITY


func _process(_delta: float) -> void:
	if not active:
		_clear()
		return
	_update()


## Starts building [param what], from the shop.
func begin(what: StructureKind) -> void:
	if what == null:
		return
	active = true
	kind = what
	has_start = false
	_ghost_key = ""
	notice.emit(hint())


## Puts it away. A run of fence half picked is let go of first.
func stop() -> void:
	if has_start:
		has_start = false
		_ghost_key = ""
		return
	active = false
	kind = null
	_clear()


## Turns what is in hand a quarter.
func rotate_piece() -> void:
	quarter = posmod(quarter + 1, 4)
	_ghost_key = ""


## What left mouse does while building: puts one down, or picks a run's corner.
## Returns whether anything went down.
func place() -> bool:
	var farm := Farm.of(self)
	if not active or farm == null:
		return false
	_update()
	if not aimed:
		notice.emit("Point at the farm's ground")
		return false
	match kind.placement:
		StructureKind.Placement.RUN:
			var corner := farm.grid.corner_at(cursor)
			if not has_start:
				run_start = corner
				has_start = true
				_ghost_key = ""
				return false
			var built := farm.build_run(kind, run_start, corner)
			if built > 0:
				has_start = false
				_ghost_key = ""
				notice.emit("%d length%s of fence up — %d coins" % [built, "" if built == 1 else "s",
					built * kind.cost])
			return built > 0
		StructureKind.Placement.EDGE:
			return farm.build_gate(kind, farm.grid.edge_at(cursor)) != null
	return farm.build(kind, _anchor(farm), quarter) != null


## Takes down the built thing under the cross, for half what it cost. Returns
## whether anything came down.
func demolish_aimed() -> bool:
	var farm := Farm.of(self)
	var built := aimed_structure()
	if farm == null or built == null:
		notice.emit("Nothing built under the cross to take down")
		return false
	var what := built.kind.display_name
	var back := farm.demolish(built)
	notice.emit("Took down the %s — %d coins back" % [what.to_lower(), back])
	return true


## The built thing the cross is on, near enough to take down, or null.
func aimed_structure() -> FarmStructure:
	if _view == null or _view.camera == null or _spider == null:
		return null
	var camera := _view.camera
	var from := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from - camera.global_basis.z * REACH,
		GameLayers.WORLD, [_spider.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var node := hit.get("collider") as Node if not hit.is_empty() else null
	while node != null:
		if node is FarmStructure:
			return node as FarmStructure
		node = node.get_parent()
	return null


## What the readout says while building: what is in hand, what it costs, and how
## to put it down — or why it cannot go where the cross is.
func hint() -> String:
	if not active:
		return ""
	var farm := Farm.of(self)
	if kind == null:
		return ""
	match kind.placement:
		StructureKind.Placement.RUN:
			if has_start and farm != null and aimed:
				var corner := farm.grid.corner_at(cursor)
				return "Fence — %d lengths, %d coins · left click the far corner · right click to start again" \
					% [farm.run_lengths(run_start, corner), farm.run_cost(kind, run_start, corner)]
			return "Fence — %d coins a length · left click a corner, then the opposite corner" % kind.cost
		StructureKind.Placement.EDGE:
			return "%s — %d coins · left click a side of a cell, or a fence · right click to stop" \
				% [kind.display_name, kind.cost]
	return "%s — %d coins · left click to build · R to turn · right click to stop" \
		% [kind.display_name, kind.cost]


# --- following the cross ---------------------------------------------------

func _update() -> void:
	if not active:
		return
	var farm := Farm.of(self)
	aimed = _find_ground()
	if farm == null or not aimed:
		valid = false
		reason = "Point at the farm's ground" if farm != null else "No farm here"
		_show_ghost(null)
		_draw_grid(farm)
		return
	if kind.placement == StructureKind.Placement.RUN:
		var corner := farm.grid.corner_at(cursor)
		reason = farm.run_reason(kind, run_start, corner) if has_start else ""
		if not has_start and not farm.grid.on_land(cursor):
			reason = "Not on the farm"
	elif kind.placement == StructureKind.Placement.EDGE:
		reason = farm.gate_reason(kind, farm.grid.edge_at(cursor))
	else:
		reason = farm.build_reason(kind, _anchor(farm), quarter)
	valid = reason.is_empty()
	_show_ghost(farm)
	_draw_grid(farm)


## Where the cross meets the ground: the camera's own ray, so it is exactly what
## the cross is on. Returns whether it met anything.
func _find_ground() -> bool:
	if _view == null or _view.camera == null or _spider == null or not is_inside_tree():
		return false
	var camera := _view.camera
	var from := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from - camera.global_basis.z * REACH,
		GameLayers.WORLD, [_spider.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	cursor = hit["position"]
	return true


## The first cell of what is in hand, so that the cross is in the middle of it.
func _anchor(farm: Farm) -> Vector2i:
	var span := kind.footprint if quarter % 2 == 0 else Vector2i(kind.footprint.y, kind.footprint.x)
	var shift := Vector3(float(span.x - 1), 0.0, float(span.y - 1)) * farm.grid.cell * 0.5
	return farm.grid.cell_at(cursor - shift)


# --- what you can see ----------------------------------------------------

## The see-through copy of what is in hand, where it would go.
func _show_ghost(farm: Farm) -> void:
	if farm == null:
		_drop_ghost()
		return
	var key := _ghost_shape_key(farm)
	if key != _ghost_key:
		_drop_ghost()
		_ghost_key = key
		_ghost = _build_ghost(farm)
		if _ghost != null:
			add_child(_ghost)
			_ghost.top_level = true
	if _ghost == null:
		return
	_ghost.global_transform = _ghost_place(farm)
	_tint(_ghost, _good if valid else _bad)


## What decides the ghost's shape: anything that changes it means building it
## again, and nothing else does.
func _ghost_shape_key(farm: Farm) -> String:
	if kind.placement == StructureKind.Placement.RUN:
		if not has_start:
			return "post"
		var corner := farm.grid.corner_at(cursor)
		return "run %s %s" % [run_start, corner]
	return "%s %d" % [kind.id, quarter]


func _build_ghost(farm: Farm) -> Node3D:
	if kind.placement == StructureKind.Placement.RUN:
		var holder := Node3D.new()
		holder.name = "Ghost"
		if not has_start:
			WorldKit.box(holder, "Post", Vector3(0.18, 1.2, 0.18), WorldKit.at(Vector3(0.0, 0.6, 0.0)),
				"white", false)
			return holder
		var corner := farm.grid.corner_at(cursor)
		for edge in farm.grid.run_edges(run_start, corner):
			if farm.grid.barrier(edge) != null:
				continue
			var piece := FarmStructure.preview(kind)
			piece.transform = Transform3D(farm.grid.edge_basis(edge), farm.grid.edge_middle(edge))
			holder.add_child(piece)
		return holder
	var ghost := FarmStructure.preview(kind)
	ghost.name = "Ghost"
	return ghost


## Where the ghost stands.
func _ghost_place(farm: Farm) -> Transform3D:
	match kind.placement:
		StructureKind.Placement.RUN:
			if not has_start:
				return Transform3D(Basis.IDENTITY, farm.grid.corner_position(farm.grid.corner_at(cursor)))
			return Transform3D.IDENTITY
		StructureKind.Placement.EDGE:
			var edge := farm.grid.edge_at(cursor)
			if not farm.grid.edge_in_bounds(edge):
				return Transform3D(Basis.IDENTITY, cursor)
			return Transform3D(farm.grid.edge_basis(edge), farm.grid.edge_middle(edge))
	var cells := farm.grid.footprint_cells(_anchor(farm), kind.footprint, quarter)
	return Transform3D(Basis(Vector3.UP, -PI * 0.5 * float(quarter)), farm.grid.middle_of(cells))


func _drop_ghost() -> void:
	if _ghost != null and is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null
	_ghost_key = ""


func _clear() -> void:
	_drop_ghost()
	if _grid_mesh != null:
		_grid_mesh.clear_surfaces()


## The grid round the cross, faint, so it is clear where things will snap to.
func _draw_grid(farm: Farm) -> void:
	_grid_mesh.clear_surfaces()
	if farm == null or not aimed:
		return
	var grid := farm.grid
	var middle := grid.corner_at(cursor)
	var low := Vector2i(maxi(middle.x - GRID_SHOWN, 0), maxi(middle.y - GRID_SHOWN, 0))
	var high := Vector2i(mini(middle.x + GRID_SHOWN, grid.size), mini(middle.y + GRID_SHOWN, grid.size))
	var lift := Vector3.UP * 0.03
	var tint := Color(1.0, 1.0, 1.0, 0.5)
	for x in range(low.x, high.x + 1):
		WebGeometry.draw_line_into(_grid_mesh, _grid_paint, grid.corner_position(Vector2i(x, low.y)) + lift,
			grid.corner_position(Vector2i(x, high.y)) + lift, 0.03, tint)
	for z in range(low.y, high.y + 1):
		WebGeometry.draw_line_into(_grid_mesh, _grid_paint, grid.corner_position(Vector2i(low.x, z)) + lift,
			grid.corner_position(Vector2i(high.x, z)) + lift, 0.03, tint)


static func _tint(node: Node, paint: Material) -> void:
	var view := node as MeshInstance3D
	if view != null:
		view.material_override = paint
		view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_tint(child, paint)


static func _paint(colour: Color) -> StandardMaterial3D:
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	paint.albedo_color = colour
	return paint
