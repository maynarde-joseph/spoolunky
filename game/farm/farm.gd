class_name Farm
extends Node3D

## The farm: its money, its land, what is built on it and what lives on it.
##
## The land is a [FarmGrid]. Everything built on it is a [FarmStructure] under
## Structures, and every insect raised on it is an [Insect] under Insects. This is
## where the rules for putting things down live — what it costs, whether there is
## room, the starter pen a new farm is given, the wild flies the farm draws in —
## and where an insect asks what its pen has for it: food, water, room, comfort.
##
## There is one farm in a scene, and anything that wants it asks with
## [method of].

## The money changed: something was bought, or sold.
signal coins_changed(coins: int)

## Something went up or came down, or a gate opened or shut: the pens may not be
## what they were.
signal layout_changed()

## Something worth putting on screen happened.
signal notice(text: String)

const GROUP := "farm"

## What a structure taken down gives back, as a share of what it cost.
const REFUND := 0.5

## How often a wild fly may turn up, in seconds; how many each lure draws at most,
## and how many there can be about the farm at once.
const WILD_EVERY := 14.0
const WILD_PER_LURE := 2
const WILD_MOST := 10

## How far from what drew it a wild fly turns up, in metres.
const WILD_FROM := Vector2(9.0, 15.0)

## The starter pen a new farm is given: its corners, its gate, and what is in it.
const STARTER_FROM := Vector2i(8, 15)
const STARTER_TO := Vector2i(12, 19)
const STARTER_FLIES := [0.25, 0.5, 0.8, 1.0]

## How many cells a side the land is, and how wide each is, in metres.
@export var cells := 24
@export var cell_size := 2.0

## What the farm has to spend.
@export var coins := 250:
	set(value):
		coins = value
		coins_changed.emit(coins)

## Whether a new, empty farm is given a starter pen with flies in it.
@export var starter := true

## Whether wild flies are drawn in by troughs, compost heaps and melon patches.
@export var wild_flies := true

var grid: FarmGrid

var _structures: Array[FarmStructure] = []

## The structures on each region's ground, by region, and the room each region's
## insects have — rebuilt when the layout changes, and once a physics frame.
var _by_region := {}
var _room := {}
var _room_frame := -1
var _rng := RandomNumberGenerator.new()
var _wild_left := WILD_EVERY * 0.5


## The farm [param node] is on, or null if its scene has none.
static func of(node: Node) -> Farm:
	if node == null or not node.is_inside_tree():
		return null
	return node.get_tree().get_first_node_in_group(GROUP) as Farm


## Joined up before anything under it is ready, so an insect already standing in a
## saved farm finds it from its own _ready.
func _enter_tree() -> void:
	add_to_group(GROUP)
	if grid == null:
		grid = FarmGrid.new(cells, cell_size)
	_rng.randomize()
	_holder("Structures")
	_holder("Insects")


func _ready() -> void:
	# Anything already standing — a farm loaded with its fences up — is put back on
	# the grid it stands on.
	for node in _holder("Structures").get_children():
		var built := node as FarmStructure
		if built != null and not _structures.has(built):
			_take_on(built)
	_relayout()
	if starter and _structures.is_empty() and insects().is_empty():
		_build_starter()


func _physics_process(delta: float) -> void:
	if not wild_flies:
		return
	_wild_left -= delta
	if _wild_left <= 0.0:
		_wild_left = WILD_EVERY
		call_wild()


## The pen a new farm starts with, for nothing: fenced, with a gate on the south
## side, a trough and a pond in it, a few flies, and a prep table outside the gate.
func _build_starter() -> void:
	var kept := coins
	coins = 1000000
	build_run(Catalogue.structure("fence"), STARTER_FROM, STARTER_TO)
	build_gate(Catalogue.structure("gate"), Vector3i(FarmGrid.ACROSS_Z, STARTER_FROM.x + 2, STARTER_TO.y))
	build(Catalogue.structure("trough"), STARTER_FROM)
	build(Catalogue.structure("pond"), STARTER_TO - Vector2i(2, 2))
	build(Catalogue.structure("prep_table"), Vector2i(STARTER_TO.x + 1, STARTER_TO.y - 1))
	for built in _structures:
		built.paid = 0
	coins = kept
	var fly := Catalogue.insect("fly")
	var middle := grid.middle_of(grid.footprint_cells(STARTER_FROM + Vector2i(1, 1), Vector2i(2, 2)))
	for grown: float in STARTER_FLIES:
		add_insect(fly, _spot_near(middle, grid.region_id(grid.cell_at(middle))), grown)


## Draws a wild fly in to one of the farm's lures, if there is room for another.
## Returns it, or null.
func call_wild() -> Insect:
	var lures: Array[FarmStructure] = []
	for built in _structures:
		if built.draws_flies():
			lures.append(built)
	if lures.is_empty():
		return null
	var about := 0
	for insect in insects():
		about += 1 if insect.wild else 0
	if about >= mini(WILD_MOST, lures.size() * WILD_PER_LURE):
		return null
	var lure := lures[_rng.randi_range(0, lures.size() - 1)]
	var at := lure.global_position
	var spot := at
	for attempt in 10:
		var angle := _rng.randf() * TAU
		spot = at + Vector3(cos(angle), 0.0, sin(angle)) * _rng.randf_range(WILD_FROM.x, WILD_FROM.y)
		var cell := grid.cell_at(spot)
		if not grid.in_bounds(cell) or not grid.is_pen(grid.region_id(cell)):
			break
	var fly := add_insect(Catalogue.insect("fly"), spot, _rng.randf_range(0.3, 1.0))
	fly.quality = _rng.randf_range(0.0, 0.25)
	fly.draw_to(at)
	notice.emit("A wild fly has come for the %s" % lure.kind.display_name.to_lower())
	return fly


func _holder(holder_name: String) -> Node3D:
	var found := get_node_or_null(holder_name) as Node3D
	if found == null:
		found = Node3D.new()
		found.name = holder_name
		add_child(found)
	return found


# --- money ---------------------------------------------------------------

func can_afford(amount: int) -> bool:
	return coins >= amount


## Pays [param amount] out. False, and nothing paid, if there is not that much.
func spend(amount: int) -> bool:
	if amount > coins:
		return false
	coins -= amount
	return true


func earn(amount: int) -> void:
	if amount > 0:
		coins += amount


# --- building ------------------------------------------------------------

func structures() -> Array[FarmStructure]:
	return _structures.duplicate()


## Why [param kind] cannot go down with its first cell on [param at], turned
## [param quarter] quarter turns — or nothing if it can. For something on a patch of
## cells; a fence or a gate is asked with [method run_reason] or [method gate_reason].
func build_reason(kind: StructureKind, at: Vector2i, quarter := 0) -> String:
	if kind == null:
		return "Nothing to build"
	var covered := grid.footprint_cells(at, kind.footprint, quarter)
	for cell in covered:
		if not grid.in_bounds(cell):
			return "Not on the farm"
	if not grid.can_occupy(covered):
		return "Something is already there"
	if not can_afford(kind.cost):
		return "Not enough coins — %d" % kind.cost
	return ""


## Builds [param kind] with its first cell on [param at], turned [param quarter]
## quarter turns, and pays for it. Null, with a notice saying why, if it cannot go
## there.
func build(kind: StructureKind, at: Vector2i, quarter := 0) -> FarmStructure:
	var reason := build_reason(kind, at, quarter)
	if not reason.is_empty():
		notice.emit(reason)
		return null
	spend(kind.cost)
	var made := FarmStructure.make(kind)
	made.cells = grid.footprint_cells(at, kind.footprint, quarter)
	made.quarter = posmod(quarter, 4)
	made.paid = kind.cost
	made.position = grid.middle_of(made.cells)
	made.rotation.y = -PI * 0.5 * float(made.quarter)
	_holder("Structures").add_child(made, true)
	_take_on(made)
	_relayout()
	return made


## How much a run of fence from corner [param from] to corner [param to] costs:
## only the lengths not already standing.
func run_cost(kind: StructureKind, from: Vector2i, to: Vector2i) -> int:
	return run_lengths(from, to) * (kind.cost if kind != null else 0)


## How many lengths of fence a run from [param from] to [param to] would put up.
func run_lengths(from: Vector2i, to: Vector2i) -> int:
	var count := 0
	for edge in grid.run_edges(from, to):
		if grid.barrier(edge) == null:
			count += 1
	return count


## Why a run of fence from [param from] to [param to] cannot go up, or nothing.
func run_reason(kind: StructureKind, from: Vector2i, to: Vector2i) -> String:
	if from == to:
		return "Pick the other corner"
	var lengths := run_lengths(from, to)
	if lengths == 0:
		return "That fence is already up"
	if not can_afford(lengths * kind.cost):
		return "Not enough coins — %d for %d lengths" % [lengths * kind.cost, lengths]
	return ""


## Puts a run of fence up from corner [param from] to corner [param to], and pays
## for it. Returns how many lengths went up.
func build_run(kind: StructureKind, from: Vector2i, to: Vector2i) -> int:
	var reason := run_reason(kind, from, to)
	if not reason.is_empty():
		notice.emit(reason)
		return 0
	var count := 0
	for edge in grid.run_edges(from, to):
		if grid.barrier(edge) != null:
			continue
		spend(kind.cost)
		_put_on_edge(kind, edge, kind.cost)
		count += 1
	_relayout()
	return count


## Why a gate cannot go on [param edge], or nothing. A gate can go up on its own,
## or in place of a length of fence already there.
func gate_reason(kind: StructureKind, edge: Vector3i) -> String:
	if not grid.edge_in_bounds(edge):
		return "Not on the farm"
	var there := grid.barrier(edge) as Fence
	if there != null and there.is_gate:
		return "There is a gate there already"
	if not can_afford(kind.cost):
		return "Not enough coins — %d" % kind.cost
	return ""


## Puts a gate up on [param edge] — in place of the fence there, if there is one —
## and pays for it. Null, with a notice saying why, if it cannot.
func build_gate(kind: StructureKind, edge: Vector3i) -> Fence:
	var reason := gate_reason(kind, edge)
	if not reason.is_empty():
		notice.emit(reason)
		return null
	var there := grid.barrier(edge) as FarmStructure
	if there != null:
		_take_off(there)
	spend(kind.cost)
	var gate := _put_on_edge(kind, edge, kind.cost)
	_relayout()
	return gate


func _put_on_edge(kind: StructureKind, edge: Vector3i, cost: int) -> Fence:
	var made := FarmStructure.make(kind) as Fence
	made.edge = edge
	made.paid = cost
	made.position = grid.edge_middle(edge)
	made.basis = grid.edge_basis(edge)
	_holder("Structures").add_child(made, true)
	_take_on(made)
	return made


## Takes [param built] down, and gives back [constant REFUND] of what it cost.
## Returns what came back.
func demolish(built: FarmStructure) -> int:
	if built == null or not _structures.has(built):
		return 0
	var back := floori(float(built.paid) * REFUND)
	_take_off(built)
	earn(back)
	_relayout()
	return back


## Puts [param built] on the grid: the farm knows it, and its cells or its edge are
## taken.
func _take_on(built: FarmStructure) -> void:
	built.farm = self
	if not _structures.has(built):
		_structures.append(built)
	if built.is_on_edge():
		grid.set_barrier(built.edge, built)
	else:
		grid.occupy(built.cells, built)


func _take_off(built: FarmStructure) -> void:
	_structures.erase(built)
	if built.is_on_edge():
		if grid.barrier(built.edge) == built:
			grid.clear_barrier(built.edge)
	else:
		grid.vacate(built.cells)
	built.taken_down()
	built.queue_free()


## What stands on [param cell], or null.
func structure_at(cell: Vector2i) -> FarmStructure:
	return grid.occupied.get(cell) as FarmStructure


## What stands on [param edge], or null.
func structure_on(edge: Vector3i) -> FarmStructure:
	return grid.barrier(edge) as FarmStructure


## The pens may have changed: flood the land again, and sort the structures by the
## ground they stand on.
func _relayout() -> void:
	grid.recompute()
	_by_region.clear()
	for built in _structures:
		if built.is_on_edge():
			continue
		var id := built.region()
		if not _by_region.has(id):
			_by_region[id] = []
		(_by_region[id] as Array).append(built)
	_room_frame = -1
	layout_changed.emit()


## Called by a gate when it opens or shuts.
func gate_moved() -> void:
	_relayout()


# --- stock ----------------------------------------------------------------

## Somewhere near [param where] on the same ground, for a hatchling to land.
func _spot_near(where: Vector3, region_id: int) -> Vector3:
	for attempt in 8:
		var angle := _rng.randf() * TAU
		var spot := where + Vector3(cos(angle), 0.0, sin(angle)) * _rng.randf_range(0.2, 0.9)
		if grid.region_id(grid.cell_at(spot)) == region_id:
			return Vector3(spot.x, where.y, spot.z)
	return where


## Puts one [param species] down at [param where], [param grown] of the way to
## market weight: a hatchling from a compost heap, a starter fly, a wild one.
func add_insect(species: InsectSpecies, where: Vector3, grown := 0.0) -> Insect:
	var insect := Insect.of(species, grown)
	var lift := 0.0
	if species != null:
		lift = species.adult_radius * lerpf(Insect.HATCHLING, 1.0, grown) * Insect.HITBOX_SCALE
		if species.flying:
			lift = species.hover.x
	insect.position = Vector3(where.x, maxf(where.y, 0.0) + lift + 0.02, where.z)
	_holder("Insects").add_child(insect, true)
	return insect


## Every insect on the farm, alive or wrapped.
func insects() -> Array[Insect]:
	var found: Array[Insect] = []
	for node in get_tree().get_nodes_in_group(Insect.GROUP):
		var insect := node as Insect
		if insect != null and not insect.is_queued_for_deletion():
			found.append(insect)
	return found


## The insects alive in region [param region_id]: not the ones wrapped up.
func insects_in(region_id: int) -> Array[Insect]:
	var found: Array[Insect] = []
	for insect in insects():
		if not insect.is_bundle() and insect.region() == region_id:
			found.append(insect)
	return found


# --- what a pen has --------------------------------------------------------

## Every structure standing on region [param region_id]'s ground, or only those
## that are [param id].
func in_region(region_id: int, id := "") -> Array[FarmStructure]:
	var found: Array[FarmStructure] = []
	for built: FarmStructure in _by_region.get(region_id, []):
		if is_instance_valid(built) and (id.is_empty() or built.kind.id == id):
			found.append(built)
	return found


func has_in(region_id: int, id: String) -> bool:
	return not in_region(region_id, id).is_empty()


## The nearest thing in [param insect]'s pen with food for it, or null.
func food_for(insect: Insect) -> FarmStructure:
	return _nearest(insect, func(built: FarmStructure) -> bool: return built.has_food_for(insect))


## The nearest water in [param insect]'s pen, or null.
func water_for(insect: Insect) -> FarmStructure:
	return _nearest(insect, func(built: FarmStructure) -> bool: return built.has_water())


func _nearest(insect: Insect, wanted: Callable) -> FarmStructure:
	var best: FarmStructure = null
	var nearest := INF
	for built in in_region(insect.region()):
		if not wanted.call(built):
			continue
		var gap := built.global_position.distance_to(insect.global_position)
		if gap < nearest:
			nearest = gap
			best = built
	return best


## How much room region [param region_id]'s insects have, 0 to 1: one while the
## ground is enough for everything on it, less the more it is overcrowded.
func room_in(region_id: int) -> float:
	var frame := Engine.get_physics_frames()
	if frame != _room_frame:
		_room_frame = frame
		_room.clear()
		var wanted := {}
		for insect in insects():
			if insect.is_bundle() or insect.kind == null:
				continue
			var id := insect.region()
			wanted[id] = float(wanted.get(id, 0.0)) + insect.kind.space
		for id: int in wanted:
			_room[id] = clampf(grid.area_of(id) / maxf(float(wanted[id]), 0.001), 0.0, 1.0)
	return float(_room.get(region_id, 1.0))


## A line about the pen region [param region_id] is, for the readout: how many it
## holds and what it is short of.
func pen_summary(region_id: int) -> String:
	if not grid.is_pen(region_id):
		return "Open ground"
	var living := insects_in(region_id)
	var said := PackedStringArray(["Pen · %d m² · %d insect%s" % [roundi(grid.area_of(region_id)),
		living.size(), "" if living.size() == 1 else "s"]])
	if not living.is_empty():
		if not has_in(region_id, "trough"):
			said.append("no food")
		if not has_in(region_id, "pond"):
			said.append("no water")
		if room_in(region_id) < 0.999:
			said.append("crowded")
	return " · ".join(said)

