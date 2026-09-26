extends TestSuite

## Headless check on the greyboxed world.
##
##     godot --headless --script res://tests/world_smoke_test.gd
##
## A prototype's job is to be the right shape, so that is what is checked: the
## zones exist and do not sit inside each other, every interior has a light,
## the way down is open at every step, and each room is a plausible size for
## the body it was built for. None of this looks at how it plays — that is what
## opening it is for.

const WORLD_PATH := "res://game/world/world.tscn"
const TESTBED_PATH := "res://game/world/testbed.tscn"


func run_checks() -> void:
	var world := await open(WORLD_PATH)
	if world == null:
		return

	var spider := root.get_tree().get_first_node_in_group("spider") as SpiderPlayer
	if not check(spider != null, "the world has a spider in it"):
		return

	_test_zones()
	_test_lights(world)
	_test_thresholds()
	await _test_the_spider_lands(spider)
	_test_the_way_down(spider)
	_test_the_other_key(world, spider)

	# Opening the gym drops the world: two full levels in the tree at once is
	# more than a headless run needs to hold.
	await _test_the_testbed()


## The gym. Not the game, so what is checked is that it holds together: it
## loads, the spider lands on its floor, every station is there with a sign on
## it, and the three gates are the three sizes. A testbed that errors on load is
## worse than no testbed, because you find out while looking for something else.
func _test_the_testbed() -> void:
	var bed := await open(TESTBED_PATH)
	if bed == null:
		return

	var spider := root.get_tree().get_first_node_in_group("spider") as SpiderPlayer
	if not check(spider != null, "with a spider in it"):
		return

	var stations := 0
	var signs := 0
	for node in all_under(bed):
		if node is Label3D:
			signs += 1
			if not (node as Label3D).text.is_empty():
				stations += 1
	check(stations >= 10, "every station is signed, and there are %d of them" % stations)
	check(signs == stations, "and no sign without words on it")

	var gates := _thresholds()
	var sizes: Array[float] = []
	for gate in gates:
		sizes.append(gate.opens_at)
	sizes.sort()
	check(gates.size() == 3, "the three gates are all here (%d)" % gates.size())
	if gates.size() == 3:
		check(is_equal_approx(sizes[0], 0.4) and is_equal_approx(sizes[1], 0.7)
			and is_equal_approx(sizes[2], 1.2),
			"at the sizes the tier table says (%.1f, %.1f, %.1f)"
			% [sizes[0], sizes[1], sizes[2]])

	# It has to hold the spider up, and it has to be small.
	await run_frames(180)
	check(spider.global_position.y > -4.0,
		"the spider lands on the floor rather than through it (%.2f)"
		% spider.global_position.y)
	check(absf(spider.global_position.x) < 30.0 and absf(spider.global_position.z) < 24.0,
		"and stays on it (%.0f, %.0f)" % [spider.global_position.x, spider.global_position.z])
	# Something to pick up, in the group the pick actually searches.
	var loose := root.get_tree().get_nodes_in_group("silk_devices").size()
	check(loose >= 3, "with loose items lying about to be picked up (%d)" % loose)
	var near := 0
	for node in root.get_tree().get_nodes_in_group("silk_devices"):
		var item := node as Node3D
		if item != null and item.global_position.distance_to(SpiderTestbed.SPAWN) < 6.0:
			near += 1
	check(near >= 3, "within reach of where you start (%d of them)" % near)

	var across := SpiderTestbed.FLOOR_HI - SpiderTestbed.FLOOR_LO
	check(across.x < 60.0 and across.z < 50.0,
		"the whole gym is %.0f by %.0f, which is the point of it" % [across.x, across.z])


## Five places, none of them inside another. Overlapping bounds would make
## "which zone am I in" a coin toss, and everything a zone is for hangs off it.
func _test_zones() -> void:
	var zones: Array[Zone] = []
	for node in root.get_tree().get_nodes_in_group("zones"):
		var zone := node as Zone
		if zone != null:
			zones.append(zone)
	if not check(zones.size() == 5, "five zones (%d)" % zones.size()):
		return

	var names: Array[String] = []
	for zone in zones:
		names.append(zone.display_name)
	note(", ".join(names))

	for zone in zones:
		check(zone.bounds.get_volume() > 0.0,
			"%s has somewhere to be (%.0f m3)" % [zone.display_name, zone.bounds.get_volume()])

	var overlaps := 0
	for i in zones.size():
		for j in range(i + 1, zones.size()):
			if zones[i].bounds.intersects(zones[j].bounds):
				overlaps += 1
				note("%s overlaps %s" % [zones[i].display_name, zones[j].display_name])
	check(overlaps == 0, "and none of them are inside each other (%d)" % overlaps)

	# Scale is the whole point of the prototype, so it gets asserted rather
	# than eyeballed: a room should be a room, not a county.
	for zone in zones:
		var across := zone.body_lengths_across()
		check(across > 20.0 and across < 400.0,
			"%s is %d body lengths across" % [zone.display_name, roundi(across)])


## Pure white needs a light or it is a silhouette. Every interior gets one.
func _test_lights(world: Node) -> void:
	var lights := _lights_under(world)
	check(lights >= 5, "the world is lit (%d sources)" % lights)
	var shadowed := 0
	for node in all_under(world):
		var light := node as Light3D
		if light != null and light.shadow_enabled:
			shadowed += 1
	check(shadowed == lights, "and every one of them casts (%d of %d)" % [shadowed, lights])

	var sun := 0
	for node in all_under(world):
		if node is DirectionalLight3D:
			sun += 1
	check(sun == 1, "with one sun for the outdoors (%d)" % sun)


## Three ways down, each shut until there is more of the spider. The sizes are
## the tier table: a House Spider, then a Huntsman, then a Gutter Spider.
func _test_thresholds() -> void:
	var gates := _thresholds()
	if not check(gates.size() == 3, "three ways on (%d)" % gates.size()):
		return
	var opens: Array[float] = []
	for gate in gates:
		opens.append(gate.opens_at)
		check(not gate.open, "%s starts shut" % gate.name)
		check(gate.opens_for != "",
			"and has a second key on it — %s opens %s" % [gate.opens_for, gate.name])
	opens.sort()
	check(opens[0] < opens[1] and opens[1] < opens[2],
		"and they want you bigger each time (%.1f, %.1f, %.1f)"
		% [opens[0], opens[1], opens[2]])


## The spider is put in the attic, and the attic has to hold it up.
func _test_the_spider_lands(spider: SpiderPlayer) -> void:
	var start := spider.global_position
	await run_frames(240)
	var here := Zone.at(root.get_tree(), spider.global_position)
	check(here != null and here.display_name == "The Attic",
		"the spider starts in the attic and stays there (%s)"
		% (here.display_name if here != null else "nowhere"))
	check(spider.global_position.y > SpiderWorld.ATTIC_LO.y - 2.0,
		"standing on its floor rather than through it (%.1f, floor at %.1f)"
		% [spider.global_position.y, SpiderWorld.ATTIC_LO.y])
	check(spider.global_position.distance_to(start) < 30.0,
		"and near where it was put (%.1fm)" % spider.global_position.distance_to(start))


## Growing has to actually open the way. Feed the spider through the tiers and
## check each gate gives at the size the design says it should.
func _test_the_way_down(spider: SpiderPlayer) -> void:
	var gates := _thresholds()
	gates.sort_custom(func(a: Threshold, b: Threshold) -> bool: return a.opens_at < b.opens_at)
	for gate in gates:
		var before := spider.stage().body_height
		check(not gate.open,
			"%s is still shut at %.2f" % [gate.name, before])
		while spider.stage().body_height < gate.opens_at:
			if not spider.growth.feed(60.0, "test"):
				break
		gate._physics_process(0.016)
		check(gate.open, "%s gives at %.2f" % [gate.name, spider.stage().body_height])


## Size is one key and not the only one. A gate no spider will ever be big
## enough for still gives, if it went up the tree some other way.
func _test_the_other_key(world: Node, spider: SpiderPlayer) -> void:
	var traits := spider.traits
	if not check(traits != null, "the spider has a tree to go up"):
		return

	# Far from everything, and sized past the end of the ladder, so the only
	# thing that can open it is the trait.
	var gate := Threshold.make(world as Node3D, Vector3(200.0, 200.0, 200.0),
		Vector3(206.0, 200.4, 206.0), 999.0, "TestHatch", "wing_buds")
	gate._physics_process(0.016)
	check(not gate.open, "a gate past the end of the ladder stays shut")
	check(not traits.has("wing_buds"), "with no trait to open it either")

	traits.owned["wing_buds"] = true
	gate._physics_process(0.016)
	check(gate.open, "and gives to the trait instead of to the size")
	traits.owned.erase("wing_buds")


# --- helpers -------------------------------------------------------------

func _thresholds() -> Array[Threshold]:
	var found: Array[Threshold] = []
	for node in all_under(current_scene):
		var gate := node as Threshold
		if gate != null:
			found.append(gate)
	return found


func _lights_under(node: Node) -> int:
	var total := 0
	for child in all_under(node):
		if child is Light3D:
			total += 1
	return total
