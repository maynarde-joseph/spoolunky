extends TestSuite

## Headless check on the farm: the land and what its fences make of it, what it
## costs to build and where things can go, where flies come from — a starter pen,
## and wild flies drawn in — and the flies themselves: kept in their pen, going to
## the trough when they are hungry and the pond when they are thirsty, growing and
## climbing the grades when they are kept well, and breeding in a compost heap. And
## the crops: ripening, picked, and tipped into a trough.
##
##     godot --headless --path . --script res://tests/farm_smoke_test.gd


func run_checks() -> void:
	_check_grid()
	await _check_building()
	await _check_starter()
	await _check_wild()
	await _check_keeping()
	await _check_suffering()
	await _check_gate()
	await _check_breeding()
	await _check_crops()


# --- the land, as data --------------------------------------------------------

## Plain grid logic: what fences make into pens, and what a gate does to one.
func _check_grid() -> void:
	var grid := FarmGrid.new(10, 2.0)
	check(grid.region_count() == 1 and not grid.is_pen(0), "bare land is one stretch of open ground")
	var run := grid.run_edges(Vector2i(2, 2), Vector2i(5, 5))
	check(run.size() == 12, "a run corner to corner is the outline of the square between (%d lengths)"
		% run.size())
	check(grid.run_edges(Vector2i(1, 1), Vector2i(4, 1)).size() == 3,
		"and corners in a row make a straight run")
	var fence := Barrier.new()
	for edge in run:
		grid.set_barrier(edge, fence)
	grid.recompute()
	var inside := grid.region_id(Vector2i(3, 3))
	check(grid.is_pen(inside) and grid.cells_of(inside).size() == 9,
		"fenced all round, the inside is a pen of 9 cells")
	check(not grid.is_pen(grid.region_id(Vector2i(0, 0))), "and the outside is still open ground")
	check(is_equal_approx(grid.area_of(inside), 36.0), "a pen knows its area (%.0f m²)"
		% grid.area_of(inside))
	var gate := Barrier.new()
	grid.set_barrier(run[0], gate)
	grid.recompute()
	check(grid.is_pen(grid.region_id(Vector2i(3, 3))), "a shut gate keeps it a pen")
	gate.open = true
	grid.recompute()
	check(not grid.is_pen(grid.region_id(Vector2i(3, 3)))
		and grid.region_id(Vector2i(3, 3)) == grid.region_id(Vector2i(0, 0)),
		"an open gate joins the pen to the open ground")
	var corner := FarmGrid.new(10, 2.0)
	for edge in corner.run_edges(Vector2i(0, 0), Vector2i(3, 3)):
		corner.set_barrier(edge, fence)
	corner.recompute()
	check(corner.is_pen(corner.region_id(Vector2i(1, 1))), "a pen built against the land's own edge is closed")
	var middle := grid.centre_of(Vector2i(4, 6))
	check(grid.cell_at(middle) == Vector2i(4, 6), "a cell's middle is in that cell")
	var west := grid.edge_at(middle + Vector3(-0.9, 0.0, 0.1))
	check(west == Vector3i(FarmGrid.ACROSS_X, 4, 6), "the edge nearest a point near a cell's west side is that side")
	check(grid.footprint_cells(Vector2i(1, 1), Vector2i(2, 1), 1).has(Vector2i(1, 2)),
		"a turned footprint swaps its sides")


class Barrier:
	var open := false

	func lets_through() -> bool:
		return open


# --- building ---------------------------------------------------------------

func _check_building() -> void:
	var room := FarmRoom.make(false)
	await stage(room)
	var farm := FarmRoom.farm_of(room)
	var trough := Catalogue.structure("trough")
	var start := farm.coins
	var built := farm.build(trough, Vector2i(1, 1))
	check(built is Trough and farm.coins == start - trough.cost,
		"a trough goes up and is paid for (%d → %d)" % [start, farm.coins])
	check(farm.build_reason(trough, Vector2i(1, 1)) == "Something is already there",
		"nothing else goes on its cell")
	check(not farm.build_reason(trough, Vector2i(50, 50)).is_empty(), "nor off the farm")
	var pond := Catalogue.structure("pond")
	check(farm.build_reason(pond, Vector2i(11, 4)) == "Not on the farm",
		"a pond two cells wide will not hang off the edge")
	var fence := Catalogue.structure("fence")
	var before := farm.coins
	var lengths := farm.build_run(fence, Vector2i(4, 4), Vector2i(7, 7))
	check(lengths == 12 and farm.coins == before - 12 * fence.cost,
		"a run of fence is paid for by the length (%d lengths)" % lengths)
	check(farm.run_reason(fence, Vector2i(4, 4), Vector2i(7, 7)) == "That fence is already up",
		"and the same run again has nothing to build")
	check(farm.grid.is_pen(farm.grid.region_id(Vector2i(5, 5))), "a run all round is a pen")
	var gate_kind := Catalogue.structure("gate")
	var edge := Vector3i(FarmGrid.ACROSS_Z, 5, 7)
	var gate := farm.build_gate(gate_kind, edge)
	check(gate != null and gate.is_gate and farm.structure_on(edge) == gate,
		"a gate takes the place of the fence it is put on")
	check(farm.grid.is_pen(farm.grid.region_id(Vector2i(5, 5))), "and a shut one keeps the pen a pen")
	check(farm.gate_reason(gate_kind, edge) == "There is a gate there already", "one gate to an edge")
	var poor := farm.coins
	farm.coins = 3
	check(farm.build(trough, Vector2i(2, 2)) == null and farm.coins == 3, "nothing is built on credit")
	farm.coins = poor
	var back := farm.demolish(built)
	await run_frames(2)
	check(back == trough.cost / 2 and farm.structure_at(Vector2i(1, 1)) == null,
		"taken down, a trough gives half back and frees its cell (%d)" % back)
	close()


# --- where flies come from -------------------------------------------------

## A new farm is given a pen with flies in it, and charges nothing for it.
func _check_starter() -> void:
	var room := FarmRoom.make(false, Vector3.ZERO, 250)
	var farm := FarmRoom.farm_of(room)
	farm.starter = true
	farm.cells = 24
	await stage(room)
	await run_frames(3)
	var pen := farm.grid.region_id(Farm.STARTER_FROM + Vector2i(1, 1))
	check(farm.grid.is_pen(pen), "a new farm starts with a pen")
	check(farm.has_in(pen, "trough") and farm.has_in(pen, "pond"), "with a trough and a pond in it")
	var flies := farm.insects_in(pen)
	check(flies.size() == Farm.STARTER_FLIES.size() and not flies[0].wild,
		"and %d flies of its own in it" % flies.size())
	check(farm.coins == 250, "for nothing (%d coins left)" % farm.coins)
	var table := false
	for built in farm.structures():
		table = table or built is PrepTable
	check(table, "and a prep table by the gate")
	var back := 0
	for built in farm.structures():
		back += farm.demolish(built)
	check(back == 0, "what was given is not sold back")
	close()


## Troughs, compost heaps and melon patches draw wild flies; a wild fly hangs about
## near what drew it, and is the farm's once it is in a pen.
func _check_wild() -> void:
	var room := FarmRoom.make(false)
	await stage(room)
	var farm := FarmRoom.farm_of(room)
	check(farm.call_wild() == null, "with nothing built, nothing draws a fly in")
	farm.build(Catalogue.structure("trough"), Vector2i(5, 5))
	var drawn: Array[Insect] = []
	for i in 4:
		var fly := farm.call_wild()
		if fly != null:
			drawn.append(fly)
	check(drawn.size() == Farm.WILD_PER_LURE, "a trough draws wild flies in, %d at most (%d)"
		% [Farm.WILD_PER_LURE, drawn.size()])
	await run_frames(2)
	if drawn.is_empty():
		close()
		return
	var fly := drawn[0]
	check(fly.wild and not fly.in_pen() and fly.describe().begins_with("Wild"),
		"a wild fly is on open ground, and nobody's: %s" % fly.describe())
	var lure := farm.structure_at(Vector2i(5, 5)).global_position
	await run_frames(400)
	var near := Vector2(fly.global_position.x - lure.x, fly.global_position.z - lure.z).length()
	check(near < Insect.LOOSE_RANGE + 2.0, "it hangs about near what drew it (%.1fm off)" % near)
	farm.build_run(Catalogue.structure("fence"), Vector2i(8, 8), Vector2i(11, 11))
	fly.global_position = farm.grid.centre_of(Vector2i(9, 9)) + Vector3.UP * 0.8
	await run_frames(3)
	check(not fly.wild and fly.in_pen(), "put in a pen, it is the farm's")
	close()


# --- keeping --------------------------------------------------------------

## A fly kept fed, watered and with room: it stays in, eats, drinks, grows and
## keeps.
func _check_keeping() -> void:
	var room := FarmRoom.make(false)
	await stage(room)
	var farm := FarmRoom.farm_of(room)
	var pen := FarmRoom.pen(farm, Vector2i(2, 2), Vector2i(7, 7))
	var quick := _quick_fly()
	var flies: Array[Insect] = []
	for i in 3:
		flies.append(farm.add_insect(quick, farm.grid.centre_of(Vector2i(4 + i % 2, 4 + i / 2))))
	var trough := farm.structure_at(Vector2i(2, 2)) as Trough
	flies[0].hunger = 0.7
	flies[1].thirst = 0.7
	var strays := 0
	var fed := false
	var watered := false
	for i in 900:
		await physics_frame
		for fly in flies:
			if fly.region() != pen:
				strays += 1
		fed = fed or flies[0].hunger < 0.2
		watered = watered or flies[1].thirst < 0.2
	check(strays == 0, "flies keep to their pen, fliers or not (%d frames out)" % strays)
	check(fed and trough.portions < Trough.BUILT_WITH, "a hungry fly goes to the trough and eats (%d meals left)"
		% trough.portions)
	check(watered, "a thirsty one goes to the pond and drinks")
	check(flies[2].is_grown(), "kept well, a fly grows to market weight (%.0f%%)" % (flies[2].growth * 100.0))
	check(flies[2].quality > 0.0 and flies[2].content,
		"and its grade climbs (%s, %.2f)" % [Dish.grade_name(flies[2].grade()), flies[2].quality])
	check(flies[2].radius() > quick.adult_radius * 0.95, "and it fills out as it grows")
	close()


## With nothing to eat and no pen, a fly neither grows nor keeps.
func _check_suffering() -> void:
	var room := FarmRoom.make(false)
	await stage(room)
	var farm := FarmRoom.farm_of(room)
	var quick := _quick_fly()
	var loose := farm.add_insect(quick, farm.grid.centre_of(Vector2i(1, 1)))
	farm.build_run(Catalogue.structure("fence"), Vector2i(6, 6), Vector2i(10, 10))
	var hungry := farm.add_insect(quick, farm.grid.centre_of(Vector2i(8, 8)))
	hungry.quality = 0.5
	hungry.hunger = 1.0
	await run_frames(300)
	check(loose.growth == 0.0 and not loose.content, "a fly loose on open ground does not grow")
	check(hungry.quality < 0.5 and hungry.growth == 0.0,
		"a starving fly does not grow, and its grade slips back (%.2f)" % hungry.quality)
	check(farm.pen_summary(hungry.region()).contains("no food"), "and its pen says what it is short of")
	for i in 30:
		farm.add_insect(quick, farm.grid.centre_of(Vector2i(8, 8)))
	await run_frames(2)
	check(farm.room_in(hungry.region()) < 1.0, "too many flies in a pen and it is crowded (room %.2f)"
		% farm.room_in(hungry.region()))
	close()


## A gate left open lets the pen's flies out onto the open ground.
func _check_gate() -> void:
	var room := FarmRoom.make(false)
	await stage(room)
	var farm := FarmRoom.farm_of(room)
	FarmRoom.pen(farm, Vector2i(2, 2), Vector2i(7, 7))
	var gate := farm.build_gate(Catalogue.structure("gate"), Vector3i(FarmGrid.ACROSS_Z, 4, 7))
	var fly := farm.add_insect(_quick_fly(), farm.grid.centre_of(Vector2i(4, 4)))
	await run_frames(5)
	check(fly.in_pen(), "a fly in a pen with its gate shut is penned")
	gate.set_open(true)
	await run_frames(2)
	check(not fly.in_pen() and gate.lets_through(), "open the gate and it is on open ground")
	gate.set_open(false)
	await run_frames(2)
	check(fly.in_pen() or fly.region() >= 0, "shut it again and the ground splits back")
	close()


## Two grown flies in a pen with water and room, and a compost heap: it breeds.
func _check_breeding() -> void:
	var room := FarmRoom.make(false)
	await stage(room)
	var farm := FarmRoom.farm_of(room)
	FarmRoom.pen(farm, Vector2i(2, 2), Vector2i(8, 8))
	var heap := farm.build(Catalogue.structure("compost_heap"), Vector2i(4, 4)) as CompostHeap
	var quick := _quick_fly()
	farm.add_insect(quick, farm.grid.centre_of(Vector2i(6, 3)), 1.0)
	await run_frames(3)
	check(heap.breed() == null, "one grown fly is not enough to breed")
	farm.add_insect(quick, farm.grid.centre_of(Vector2i(3, 6)), 1.0)
	await run_frames(3)
	var before := farm.insects().size()
	var hatchling := heap.breed()
	await run_frames(2)
	check(hatchling != null and farm.insects().size() == before + 1 and hatchling.growth < 0.05,
		"two grown flies and a compost heap make a hatchling")
	close()


## A fly that grows and keeps in seconds rather than minutes, for checks.
func _quick_fly() -> InsectSpecies:
	var quick := Catalogue.insect("fly").duplicate() as InsectSpecies
	quick.grow_time = 4.0
	quick.grade_time = 6.0
	quick.hunger_time = 30.0
	quick.thirst_time = 30.0
	return quick


# --- crops ----------------------------------------------------------------

## A crop ripens on its own, is picked into the bag, and fruit fills a trough —
## which does not fill itself.
func _check_crops() -> void:
	var room := FarmRoom.make(true, Vector3(0.0, 0.6, 9.0))
	await stage(room)
	var farm := FarmRoom.farm_of(room)
	var spider := FarmRoom.spider_of(room)
	await run_frames(10)
	var trough := farm.build(Catalogue.structure("trough"), Vector2i(5, 9)) as Trough
	var full := trough.portions
	await run_frames(120)
	check(trough.portions == full and full == Trough.BUILT_WITH, "a trough is built with %d meals and does not fill itself"
		% full)
	var patch := farm.build(Catalogue.structure("melon_patch"), Vector2i(6, 9)) as CropPlot
	check(patch != null and patch.draws_flies(), "a melon patch goes in, and draws wild flies")
	check(not patch.is_ripe() and patch.pick() == null, "it starts unripe, and nothing can be picked")
	await run_frames(60)
	check(patch.growth > 0.0, "it ripens on its own (%.0f%%)" % (patch.growth * 100.0))
	patch.growth = 1.0
	FarmRoom.aim(spider, patch.global_position + Vector3(0.0, 0.3, 0.0))
	spider.global_position = patch.global_position + Vector3(0.0, 0.6, 2.0)
	await run_frames(3)
	FarmRoom.aim(spider, patch.global_position + Vector3(0.0, 0.3, 0.0))
	check(spider.interact_hint().begins_with("F — pick"), "ripe, F picks it: %s" % spider.interact_hint())
	check(spider.interact() and spider.bag.count_produce("feed") == 1 and not patch.is_ripe(),
		"into the bag, and it starts again")
	trough.portions = 0
	spider.global_position = trough.global_position + Vector3(0.0, 0.6, 2.0)
	await run_frames(3)
	FarmRoom.aim(spider, trough.global_position + Vector3(0.0, 0.3, 0.0))
	check(spider.interact() and trough.portions == 6 and spider.bag.count_produce("feed") == 0,
		"F at the trough tips the melon in: six meals")
	var herbs := farm.build(Catalogue.structure("herb_bed"), Vector2i(8, 9)) as CropPlot
	herbs.growth = 1.0
	check(herbs.pick().use == "herb", "a herb bed grows herbs, for the kitchen")
	close()

