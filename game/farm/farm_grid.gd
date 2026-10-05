class_name FarmGrid
extends RefCounted

## The land as squares, and what the fences on it make of it.
##
## The farm is a square of [member size] by [member size] cells, each [member cell]
## metres across, centred on the origin. Things that take up ground — a trough, a
## pond, a table — stand on cells. Fences and gates stand on the *edges* between
## cells, which is what lets four of them close off a square of ground without
## taking any of it.
##
## What the fences close off is worked out, not drawn: every cell is flooded out to
## its neighbours across any edge that lets things through, and each patch of
## ground the flood reaches is a region. A region the flood could leave the land
## from is open ground; one it could not is a pen, and a pen is what keeps an
## insect in. A gate lets things through while it stands open, so opening one
## joins its pen to whatever is on the other side — usually the open ground — and
## shutting it again splits them back apart. See [method recompute].
##
## Plain data: nothing here is a node, so the rules can be checked without a farm.

## Which way an edge runs, the first part of its key. An edge across x runs
## north–south between two cells side by side; one across z runs east–west between
## two cells one behind the other.
const ACROSS_X := 0
const ACROSS_Z := 1

## The four ways out of a cell: the step to the neighbour, and the edge crossed to
## get there, as [axis, dx, dz] off the cell's own corner.
const STEPS := [
	[Vector2i(1, 0), Vector3i(ACROSS_X, 1, 0)],
	[Vector2i(-1, 0), Vector3i(ACROSS_X, 0, 0)],
	[Vector2i(0, 1), Vector3i(ACROSS_Z, 0, 1)],
	[Vector2i(0, -1), Vector3i(ACROSS_Z, 0, 0)],
]

## How many cells a side, and how wide each is in metres.
var size := 24
var cell := 2.0

## What stands on each edge, by edge: anything with a [code]lets_through()[/code]
## that says whether it is open — a fence never is, a gate is when it stands open.
var barriers := {}

## What stands on each cell, by cell.
var occupied := {}

## Which region each cell is in, row by row. See [method region_id].
var _region := PackedInt32Array()

## Each region's cells, and whether the land can be left from it.
var _cells: Array = []
var _open: Array[bool] = []


func _init(cells_a_side := 24, cell_size := 2.0) -> void:
	size = maxi(cells_a_side, 1)
	cell = maxf(cell_size, 0.01)
	recompute()


# --- where things are ----------------------------------------------------

## Half the width of the land, in metres: the land runs from minus this to this,
## both ways.
func half() -> float:
	return float(size) * cell * 0.5


func in_bounds(at: Vector2i) -> bool:
	return at.x >= 0 and at.y >= 0 and at.x < size and at.y < size


## The cell [param world] is over. Off the land, a cell out of bounds.
func cell_at(world: Vector3) -> Vector2i:
	return Vector2i(floori((world.x + half()) / cell), floori((world.z + half()) / cell))


## The middle of [param at], on the ground.
func centre_of(at: Vector2i) -> Vector3:
	return Vector3((float(at.x) + 0.5) * cell - half(), 0.0, (float(at.y) + 0.5) * cell - half())


## Whether [param world] is on the land at all.
func on_land(world: Vector3) -> bool:
	return in_bounds(cell_at(world))


## The grid point nearest [param world]: where four cells meet, which is where a
## run of fence starts and ends. Clamped to the land.
func corner_at(world: Vector3) -> Vector2i:
	return Vector2i(clampi(roundi((world.x + half()) / cell), 0, size),
		clampi(roundi((world.z + half()) / cell), 0, size))


func corner_position(corner: Vector2i) -> Vector3:
	return Vector3(float(corner.x) * cell - half(), 0.0, float(corner.y) * cell - half())


## Whether [param edge] is one of the land's: an edge across x runs from x 0 to
## [member size] and down z for a cell; one across z the other way round.
func edge_in_bounds(edge: Vector3i) -> bool:
	if edge.x == ACROSS_X:
		return edge.y >= 0 and edge.y <= size and edge.z >= 0 and edge.z < size
	return edge.y >= 0 and edge.y < size and edge.z >= 0 and edge.z <= size


## The middle of [param edge], on the ground.
func edge_middle(edge: Vector3i) -> Vector3:
	if edge.x == ACROSS_X:
		return Vector3(float(edge.y) * cell - half(), 0.0, (float(edge.z) + 0.5) * cell - half())
	return Vector3((float(edge.y) + 0.5) * cell - half(), 0.0, float(edge.z) * cell - half())


## Which way [param edge] runs along the ground.
func edge_along(edge: Vector3i) -> Vector3:
	return Vector3.BACK if edge.x == ACROSS_X else Vector3.RIGHT


## A turn that lays something built along x onto [param edge].
func edge_basis(edge: Vector3i) -> Basis:
	return Basis(Vector3.UP, -PI * 0.5) if edge.x == ACROSS_X else Basis.IDENTITY


## The edge nearest [param world]: the side of the cell it is over that it is
## closest to. Null-ish — (-1, -1, -1) — off the land.
func edge_at(world: Vector3) -> Vector3i:
	var at := cell_at(world)
	if not in_bounds(at):
		return Vector3i(-1, -1, -1)
	var local := Vector2((world.x + half()) / cell - float(at.x), (world.z + half()) / cell - float(at.y))
	var best := Vector3i(-1, -1, -1)
	var nearest := INF
	for candidate: Array in [[local.x, Vector3i(ACROSS_X, at.x, at.y)],
			[1.0 - local.x, Vector3i(ACROSS_X, at.x + 1, at.y)],
			[local.y, Vector3i(ACROSS_Z, at.x, at.y)],
			[1.0 - local.y, Vector3i(ACROSS_Z, at.x, at.y + 1)]]:
		if float(candidate[0]) < nearest:
			nearest = float(candidate[0])
			best = candidate[1]
	return best


## The two cells either side of [param edge]; one of them is off the land on the
## land's own edge.
func cells_beside(edge: Vector3i) -> Array[Vector2i]:
	if edge.x == ACROSS_X:
		return [Vector2i(edge.y - 1, edge.z), Vector2i(edge.y, edge.z)]
	return [Vector2i(edge.y, edge.z - 1), Vector2i(edge.y, edge.z)]


## The edges a run of fence from corner [param from] to corner [param to] stands
## on: the outline of the rectangle with those two corners — or, if they share a
## row or a column, the straight line between them.
func run_edges(from: Vector2i, to: Vector2i) -> Array[Vector3i]:
	var edges: Array[Vector3i] = []
	var low := Vector2i(mini(from.x, to.x), mini(from.y, to.y))
	var high := Vector2i(maxi(from.x, to.x), maxi(from.y, to.y))
	if low == high:
		return edges
	# Along the top and the bottom.
	for x in range(low.x, high.x):
		edges.append(Vector3i(ACROSS_Z, x, low.y))
		if high.y != low.y:
			edges.append(Vector3i(ACROSS_Z, x, high.y))
	# Down the two sides.
	for z in range(low.y, high.y):
		edges.append(Vector3i(ACROSS_X, low.x, z))
		if high.x != low.x:
			edges.append(Vector3i(ACROSS_X, high.x, z))
	var kept: Array[Vector3i] = []
	for edge in edges:
		if edge_in_bounds(edge):
			kept.append(edge)
	return kept


## The cells something [param footprint] big covers with its first corner on
## [param at], turned [param quarter] quarter turns: a turn swaps its two sides.
func footprint_cells(at: Vector2i, footprint: Vector2i, quarter := 0) -> Array[Vector2i]:
	var span := footprint if quarter % 2 == 0 else Vector2i(footprint.y, footprint.x)
	var found: Array[Vector2i] = []
	for x in span.x:
		for z in span.y:
			found.append(at + Vector2i(x, z))
	return found


## Where the middle of [param cells] is, on the ground.
func middle_of(cells: Array[Vector2i]) -> Vector3:
	if cells.is_empty():
		return Vector3.ZERO
	var total := Vector3.ZERO
	for at in cells:
		total += centre_of(at)
	return total / float(cells.size())


## Whether every one of [param cells] is on the land and free.
func can_occupy(cells: Array[Vector2i]) -> bool:
	for at in cells:
		if not in_bounds(at) or occupied.has(at):
			return false
	return not cells.is_empty()


# --- what is built ------------------------------------------------------

func set_barrier(edge: Vector3i, what: Object) -> void:
	barriers[edge] = what


func clear_barrier(edge: Vector3i) -> void:
	barriers.erase(edge)


func barrier(edge: Vector3i) -> Object:
	return barriers.get(edge) as Object


func occupy(cells: Array[Vector2i], what: Object) -> void:
	for at in cells:
		occupied[at] = what


func vacate(cells: Array[Vector2i]) -> void:
	for at in cells:
		occupied.erase(at)


## Whether something can get across [param edge]: nothing stands on it, or what
## does is open.
func passable(edge: Vector3i) -> bool:
	var what := barrier(edge)
	if what == null:
		return true
	return what.has_method("lets_through") and bool(what.call("lets_through"))


# --- what the fences make of it ------------------------------------------

## Floods the land again: which cells are in which region, and which regions are
## pens. Cheap — a few hundred cells — so it is simply done again whenever a fence
## goes up or comes down, or a gate opens or shuts.
func recompute() -> void:
	_region = PackedInt32Array()
	_region.resize(size * size)
	_region.fill(-1)
	_cells.clear()
	_open.clear()
	for z in size:
		for x in size:
			if _region[z * size + x] < 0:
				_flood(Vector2i(x, z))


func _flood(start: Vector2i) -> void:
	var id := _cells.size()
	var found: Array[Vector2i] = [start]
	var open := false
	_region[start.y * size + start.x] = id
	var next := 0
	while next < found.size():
		var at := found[next]
		next += 1
		for way: Array in STEPS:
			var edge: Vector3i = way[1]
			edge = Vector3i(edge.x, at.x + edge.y, at.y + edge.z)
			if not passable(edge):
				continue
			var beyond: Vector2i = at + (way[0] as Vector2i)
			if not in_bounds(beyond):
				# Out across the land's own edge, with nothing in the way.
				open = true
				continue
			var slot := beyond.y * size + beyond.x
			if _region[slot] >= 0:
				continue
			_region[slot] = id
			found.append(beyond)
	_cells.append(found)
	_open.append(open)


## Which region [param at] is in, or -1 off the land.
func region_id(at: Vector2i) -> int:
	if not in_bounds(at) or _region.size() != size * size:
		return -1
	return _region[at.y * size + at.x]


func region_count() -> int:
	return _cells.size()


## Whether [param id] is a pen: ground the fences close off.
func is_pen(id: int) -> bool:
	return id >= 0 and id < _open.size() and not _open[id]


## Every pen, by region.
func pens() -> Array[int]:
	var found: Array[int] = []
	for id in _open.size():
		if not _open[id]:
			found.append(id)
	return found


func cells_of(id: int) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	if id >= 0 and id < _cells.size():
		found.assign(_cells[id])
	return found


## How much ground [param id] has, in square metres.
func area_of(id: int) -> float:
	if id < 0 or id >= _cells.size():
		return 0.0
	return float((_cells[id] as Array).size()) * cell * cell


## Somewhere inside [param id], kept [param margin] metres in from the edges of the
## cell it is in so it is not up against a fence.
func point_in(id: int, rng: RandomNumberGenerator, margin := 0.3) -> Vector3:
	var cells := cells_of(id)
	if cells.is_empty():
		return Vector3.ZERO
	var at := cells[rng.randi_range(0, cells.size() - 1)]
	var room := maxf(cell * 0.5 - margin, 0.0)
	return centre_of(at) + Vector3(rng.randf_range(-room, room), 0.0, rng.randf_range(-room, room))
