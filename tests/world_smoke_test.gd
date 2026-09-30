extends TestSuite

## Headless check on the world, and on the gym.
##
##     godot --headless --script res://tests/world_smoke_test.gd
##
## A level's job is to be the right shape, so that is what is checked: the places
## are all there, in order, none inside another and each a plausible size for the
## body it was built for; every one indoors has a light; the gates between them
## are shut until there is enough of the spider and give when there is; each
## place is stocked with what lives there; and every prop it is furnished with
## is something to stand on. None of this looks at how it plays — that is what
## opening it is for.

const WORLD_PATH := "res://game/world/world.tscn"
const TESTBED_PATH := "res://game/world/testbed.tscn"

## The places, in the order the spider goes through them: what each is called, the
## stretch of the tier table it is built for, and what lives there — empty for a
## place stocked only with the insects that turn up anywhere.
const PLACES := [
	["The Shed", 0.25, 0.7, ""],
	["The Sewers", 0.7, 2.0, "sewers"],
	["The Park", 2.0, 3.4, "park"],
	["The Lake", 3.4, 9.0, "lake"],
]

## The places that are indoors, and have to bring their own light.
const INDOORS := ["The Shed", "The Sewers"]

## The gates, smallest first: what each is called, the size it gives to, and the
## trait that opens it as well.
const GATES := [
	["DrainLid", 0.7, "hollow_frame"],
	["StormGrate", 2.0, "storm_rider"],
]


func run_checks() -> void:
	var world := await open(WORLD_PATH)
	if world == null:
		return

	var spider := root.get_tree().get_first_node_in_group("spider") as SpiderPlayer
	if not check(spider != null, "the world has a spider in it"):
		return

	_test_places()
	_test_lights(world)
	_test_gates()
	_test_the_stock(world)
	_test_props()
	await _test_the_spider_lands(spider)
	_test_the_way_down(spider)
	await _test_the_shafts_are_clear(world as Node3D)
	_test_the_other_key(world, spider)
	await _test_the_water(spider)
	await _test_the_swimmers()
	await _test_the_boats(world as Node3D, spider)

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

	await _test_the_dummies(bed)

	var across := SpiderTestbed.FLOOR_HI - SpiderTestbed.FLOOR_LO
	check(across.x < 60.0 and across.z < 50.0,
		"the whole gym is %.0f by %.0f, which is the point of it" % [across.x, across.z])


## The places, in order, none of them inside another. Overlapping bounds would make
## "which place am I in" a coin toss, and everything a place is for hangs off it.
func _test_places() -> void:
	var zones := _zones()
	var names: Array[String] = []
	for zone in zones:
		names.append(zone.display_name)
	note(", ".join(names))
	if not check(zones.size() == PLACES.size(),
			"the places are all here, and nothing else (%d of %d)" % [zones.size(), PLACES.size()]):
		return

	for i in PLACES.size():
		var place: Array = PLACES[i]
		var zone := _zone_named(place[0])
		if not check(zone != null, "%s is there" % place[0]):
			continue
		check(zone.bounds.get_volume() > 0.0,
			"%s has somewhere to be (%.0f m3)" % [zone.display_name, zone.bounds.get_volume()])
		check(is_equal_approx(zone.built_for.x, place[1]) and is_equal_approx(zone.built_for.y,
			place[2]), "and is built for %.2f to %.2f" % [zone.built_for.x, zone.built_for.y])
		# Scale is the whole point, so it gets asserted rather than eyeballed: a room
		# should be a room, not a county.
		var across := zone.body_lengths_across()
		check(across > 20.0 and across < 400.0,
			"%s is %d body lengths across" % [zone.display_name, roundi(across)])
		# One place picks up where the last left off, so there is always somewhere
		# built for the size you are.
		if i > 0:
			check(is_equal_approx(PLACES[i - 1][2], place[1]),
				"and it starts where %s leaves off" % PLACES[i - 1][0])

	var overlaps := 0
	for i in zones.size():
		for j in range(i + 1, zones.size()):
			if zones[i].bounds.intersects(zones[j].bounds):
				overlaps += 1
				note("%s overlaps %s" % [zones[i].display_name, zones[j].display_name])
	check(overlaps == 0, "and none of them are inside each other (%d)" % overlaps)


## Indoors is lit by its own lamps, and outdoors by the one sun. Every light casts,
## because a shape reads by its shadow.
func _test_lights(world: Node) -> void:
	var lights := 0
	var shadowed := 0
	var suns := 0
	for node in all_under(world):
		var light := node as Light3D
		if light == null:
			continue
		lights += 1
		if light.shadow_enabled:
			shadowed += 1
		if light is DirectionalLight3D:
			suns += 1
	check(shadowed == lights, "every light casts (%d of %d)" % [shadowed, lights])
	check(suns == 1, "with one sun for the outdoors (%d)" % suns)
	for name in INDOORS:
		var zone := _zone_named(name)
		if zone == null:
			continue
		var inside := 0
		for node in all_under(world):
			var lamp := node as OmniLight3D
			if lamp != null and zone.bounds.grow(1.0).has_point(lamp.global_position):
				inside += 1
		check(inside > 0, "%s has a lamp of its own (%d)" % [name, inside])


## The gates, each shut until there is more of the spider, each with a second key,
## and each wanting more than the last. The sizes are the tier table's.
func _test_gates() -> void:
	var gates := _thresholds()
	if not check(gates.size() == GATES.size(),
			"the gates are all here (%d of %d)" % [gates.size(), GATES.size()]):
		return
	gates.sort_custom(func(a: Threshold, b: Threshold) -> bool: return a.opens_at < b.opens_at)
	for i in GATES.size():
		var gate := gates[i]
		var want: Array = GATES[i]
		check(String(gate.name) == want[0] and is_equal_approx(gate.opens_at, want[1]),
			"%s gives at %.1f (%s at %.1f)" % [want[0], want[1], gate.name, gate.opens_at])
		check(not gate.open, "and starts shut")
		check(gate.opens_for == want[2],
			"and %s opens it too (%s)" % [want[2], gate.opens_for])


## Each place is stocked with what lives there and the insects that turn up
## anywhere — and everything that lives there is stocked somewhere in it.
func _test_the_stock(world: Node) -> void:
	for place in PLACES:
		var zone := _zone_named(place[0])
		if zone == null:
			continue
		var habitat: String = place[3]
		var stocked := {}
		var strays: Array[String] = []
		var spawners := 0
		for node in all_under(zone):
			var spawner := node as PreySpawner
			if spawner == null:
				continue
			spawners += 1
			for kind in spawner.stock:
				stocked[kind.id] = true
				if kind.habitat != "" and kind.habitat != habitat:
					strays.append(kind.id)
		check(spawners > 0, "%s has creatures in it (%d spawners, %s)"
			% [place[0], spawners, ", ".join(stocked.keys())])
		check(strays.is_empty(), "and none of them live somewhere else (%s)"
			% (", ".join(strays) if not strays.is_empty() else "none"))
		if habitat.is_empty():
			continue
		var missing: Array[String] = []
		for kind in PreyLibrary.living_in(habitat):
			if not stocked.has(kind.id):
				missing.append(kind.id)
		check(missing.is_empty(), "and everything that lives in the %s is there (%s missing)"
			% [habitat, ", ".join(missing) if not missing.is_empty() else "none"])
	var all_spawners := 0
	for node in all_under(world):
		if node is PreySpawner:
			all_spawners += 1
	check(all_spawners > 0, "the world is stocked (%d spawners)" % all_spawners)


## Every prop has its scene, and every one is something to stand on: a body on the
## world layer with a shape to it.
func _test_props() -> void:
	var baked := 0
	var solid := 0
	var bad: Array[String] = []
	for id in Props.ALL:
		var scene := load(Props.path_of(id)) as PackedScene
		if scene == null:
			bad.append(id)
			continue
		baked += 1
		var made := scene.instantiate()
		var body := made as CollisionObject3D
		var shapes := 0
		for node in all_under(made):
			if node is CollisionShape3D:
				shapes += 1
		if body != null and body.collision_layer & GameLayers.WORLD != 0 and shapes > 0:
			solid += 1
		else:
			bad.append(id)
		made.free()
	check(baked == Props.ALL.size(), "every prop has a scene (%d of %d)" % [baked, Props.ALL.size()])
	check(solid == Props.ALL.size(), "and every one is something to stand on (%s)"
		% (", ".join(bad) if not bad.is_empty() else "all of them"))


## The spider is put in the shed, and the shed has to hold it up.
func _test_the_spider_lands(spider: SpiderPlayer) -> void:
	var start := spider.global_position
	check(start.distance_to(SpiderWorld.SPAWN) < 0.5,
		"the spider is put where a new one starts (%.1fm off)" % start.distance_to(SpiderWorld.SPAWN))
	await run_frames(240)
	var here := Zone.at(root.get_tree(), spider.global_position)
	check(here != null and here.display_name == "The Shed",
		"it starts in the shed and stays there (%s)"
		% (here.display_name if here != null else "nowhere"))
	check(spider.global_position.y > SpiderWorld.SHED_LO.y - 0.5,
		"standing on its floor rather than through it (%.2f, floor at %.1f)"
		% [spider.global_position.y, SpiderWorld.SHED_LO.y])
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
		# A tier at a time, each fed exactly what it takes: the gates are not all one
		# tier apart, and a meal that falls short of the next one proves nothing.
		while spider.stage().body_height < gate.opens_at and spider.growth.next_stage() != null:
			spider.growth.feed(spider.growth.biomass_to_next() + 1.0, "test")
		gate._physics_process(0.016)
		check(gate.open, "%s gives at %.2f" % [gate.name, spider.stage().body_height])


## With the gates given, the way through is clear: nothing across the drain between
## the shed floor and the chamber under it, and nothing across the storm drain
## between the grate and the floor of the chamber it comes up out of. A gate that
## opens onto a slab of forgotten ground is not a way through.
func _test_the_shafts_are_clear(world: Node3D) -> void:
	await physics_frame
	var space := world.get_world_3d().direct_space_state
	var shafts := [
		["the drain", SpiderWorld.DRAIN_LO, SpiderWorld.DRAIN_HI, SpiderWorld.SHED_LO.y],
		["the storm drain", SpiderWorld.STORM_LO, SpiderWorld.STORM_HI, 0.0],
	]
	for shaft in shafts:
		var lo: Vector2 = shaft[1]
		var hi: Vector2 = shaft[2]
		# Down the middle of the half away from the rungs.
		var from := Vector3(lo.x + (hi.x - lo.x) * 0.4, float(shaft[3]) + 2.0,
			lo.y + (hi.y - lo.y) * 0.4)
		var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 40.0,
			GameLayers.WORLD)
		var hit := space.intersect_ray(query)
		var landed: float = hit["position"].y if not hit.is_empty() else INF
		check(landed < SpiderWorld.WALK + 0.5,
			"%s is open all the way down to the walkway (first thing in the way at %.1f)"
			% [shaft[0], landed])


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


## The sewers run with water, and it is water to a spider: put in the channel, it
## is swimming rather than walking along the bottom.
func _test_the_water(spider: SpiderPlayer) -> void:
	var sewers := _zone_named("The Sewers")
	if not check(sewers != null, "there are sewers to have water in"):
		return
	var stretches := 0
	for node in root.get_tree().get_nodes_in_group("water"):
		var pool := node as Area3D
		if pool != null and pool.collision_layer & GameLayers.WATER != 0 \
				and sewers.bounds.has_point(pool.global_position):
			stretches += 1
	check(stretches > 0, "the sewers run with water (%d stretches of it)" % stretches)
	var at := Vector3(-110.0, SpiderWorld.WATER_TOP - 0.6, SpiderWorld.SEWER_Z)
	var top := Prey.water_top_at(spider, at)
	check(is_equal_approx(top, SpiderWorld.WATER_TOP),
		"the channel is full to %.1f (%.1f)" % [SpiderWorld.WATER_TOP, top])
	var was := spider.global_position
	spider.global_position = at
	spider.velocity = Vector3.ZERO
	await run_frames(6)
	check(not spider.climb.handles_movement(),
		"and a spider put in it is swimming, not walking the bottom")
	spider.global_position = was
	spider.velocity = Vector3.ZERO
	await run_frames(2)


## Whatever swims in the lake keeps all of itself under the top of it.
func _test_the_swimmers() -> void:
	var lake := _zone_named("The Lake")
	if not check(lake != null, "there is a lake to swim in"):
		return
	await run_frames(60)
	var swimmers := 0
	var highest := -INF
	for node in root.get_tree().get_nodes_in_group("prey"):
		var prey := node as Prey
		if prey == null or not prey.swims or not lake.bounds.has_point(prey.global_position):
			continue
		swimmers += 1
		highest = maxf(highest, prey.global_position.y + prey.hit_radius())
	check(swimmers >= 4, "there are things in the lake (%d)" % swimmers)
	check(highest <= SpiderWorld.LAKE_TOP + 0.05,
		"and none of them breaks the surface (the highest comes to %.2f, the water %.2f)"
		% [highest, SpiderWorld.LAKE_TOP])


## The boats go round the island, a spider standing in one goes round with it,
## silk spun in one goes with it, and silk tied from one to the jetty snaps.
func _test_the_boats(world: Node3D, spider: SpiderPlayer) -> void:
	var ring: BoatRing = null
	for node in all_under(world):
		if node is BoatRing:
			ring = node
	if not check(ring != null, "there are boats on the lake"):
		return
	var boats := ring.boats()
	check(boats.size() == 6, "six of them (%d)" % boats.size())
	if boats.is_empty():
		return

	# Round, at the speed they are set to, and on the water.
	var middle := ring.global_position
	var before: Array[float] = []
	for boat in boats:
		before.append(_bearing(boat.global_position - middle))
	var seconds := 2.0
	await run_frames(roundi(seconds * 60.0))
	var turned := 0.0
	var off_ring := 0.0
	var off_water := 0.0
	for i in boats.size():
		var from_middle := boats[i].global_position - middle
		turned += absf(angle_difference(before[i], _bearing(from_middle)))
		off_ring = maxf(off_ring, absf(Vector2(from_middle.x, from_middle.z).length() - ring.radius))
		off_water = maxf(off_water, absf(boats[i].global_position.y - middle.y))
	var expected := ring.speed / ring.radius * seconds
	check(turned / float(boats.size()) > expected * 0.8,
		"they go round the island (%.2f of a turn in %.0fs, %.2f expected)"
		% [turned / float(boats.size()) / TAU, seconds, expected / TAU])
	check(off_ring < 0.5 and off_water < ring.bob + 0.1,
		"on their ring and on the water (%.2f off the ring, %.2f up or down)" % [off_ring, off_water])

	# A spider put down in a boat is carried round in it.
	var boat := boats[0]
	spider.global_position = boat.global_transform * Vector3(0.0, 2.0, 2.0)
	spider.velocity = Vector3.ZERO
	await run_frames(40)
	var aboard := boat.global_transform.affine_inverse() * spider.global_position
	var was := spider.global_position
	await run_frames(120)
	var still := boat.global_transform.affine_inverse() * spider.global_position
	check(was.distance_to(spider.global_position) > 5.0,
		"a spider standing in a boat goes round with it (%.1fm in two seconds)"
		% was.distance_to(spider.global_position))
	check(still.distance_to(aboard) < 2.0 and absf(still.x) < 6.5,
		"and is still in it (%.1fm from where it stood, in the boat's own frame)"
		% still.distance_to(aboard))

	# Silk spun in a boat goes with it; silk from a boat to the jetty snaps.
	var line := load("res://game/data/patterns/frame_line.tres") as WebPattern
	var webs := world.get_node_or_null("Webs") as Node3D
	if not check(line != null and webs != null, "there is silk to spin and somewhere to put it"):
		return
	var ours := boats[1]
	var inside := WebStrand.spin(line, ours.global_transform * Vector3(-5.0, 4.1, -2.0),
		ours.global_transform * Vector3(5.0, 4.1, 7.0), 2.0)
	inside.place_in(webs)
	var jetty_end := Vector3(SpiderWorld.LAKE_MIDDLE.x - SpiderWorld.JETTY_END - 1.0, 1.2, 0.0)
	var across := WebStrand.spin(line, ours.global_transform * Vector3(0.0, 5.8, 10.0), jetty_end, 2.0)
	across.place_in(webs)
	var tied := ours.global_transform.affine_inverse() * inside.anchors[0]
	await run_frames(90)
	check(is_instance_valid(inside) and not inside.is_queued_for_deletion(),
		"a line spun across a boat holds")
	if is_instance_valid(inside):
		var now := ours.global_transform.affine_inverse() * inside.anchors[0]
		check(now.distance_to(tied) < 0.3,
			"and goes round with it (%.2fm off where it was tied, in the boat's frame)"
			% now.distance_to(tied))
		inside.demolish()
	check(not is_instance_valid(across) or across.is_queued_for_deletion(),
		"and a line from a boat to the jetty snaps as the boat pulls away")


func _bearing(offset: Vector3) -> float:
	return atan2(offset.z, offset.x)


# --- helpers -------------------------------------------------------------

func _zones() -> Array[Zone]:
	var zones: Array[Zone] = []
	for node in root.get_tree().get_nodes_in_group("zones"):
		var zone := node as Zone
		if zone != null:
			zones.append(zone)
	return zones


func _zone_named(zone_name: String) -> Zone:
	for zone in _zones():
		if zone.display_name == zone_name:
			return zone
	return null


func _thresholds() -> Array[Threshold]:
	var found: Array[Threshold] = []
	for node in all_under(current_scene):
		var gate := node as Threshold
		if gate != null:
			found.append(gate)
	return found


## The dummies station: three creatures on posts with their numbers over their
## heads, for trying a fight against something that holds still and says what it
## is doing.
##
## They are creatures rather than special cases, so silk, venom, webs, hauling and
## eating all work on them the way they work on anything — which is the point, and
## also the thing that would quietly stop being true if they were ever turned into
## a bespoke target.
func _test_the_dummies(bed: Node) -> void:
	var posts: Array[TrainingDummy] = []
	for node in all_under(bed):
		var post := node as TrainingDummy
		if post != null:
			posts.append(post)
	if not check(posts.size() == 3, "three dummies to practise on (%d)" % posts.size()):
		return

	await run_frames(20)
	var kinds: Array[String] = []
	for post in posts:
		var standing: Prey = post._standing
		if not check(is_instance_valid(standing),
				"%s has something standing on it" % post.species_id):
			return
		kinds.append(standing.species)
	check(kinds.size() == 3 and kinds[0] != kinds[1] and kinds[1] != kinds[2],
		"and they are three different things (%s)" % ", ".join(kinds))

	# One stands still, one runs, one comes for you. Those are the three questions
	# a fight asks and there is a target for each.
	var still := 0
	var runners := 0
	var hunters := 0
	for post in posts:
		var standing: Prey = post._standing
		if standing.aggression > 0.0:
			hunters += 1
		elif standing.move_speed <= 0.0:
			still += 1
		else:
			runners += 1
	check(still == 1 and runners == 1 and hunters == 1,
		"one that stands, one that runs, one that bites (%d/%d/%d)"
		% [still, runners, hunters])

	# And the one that bites can never see further than the post will let it walk.
	# The biter shipped with a 14m acquire radius against a 9m leash, so it picked
	# fights with anyone who spawned across the gym and then spent the whole thing
	# being snapped back to its plinth — which from in front read as one creature
	# that would not let go. The post clamps it now, so a `.tres` edited by hand
	# cannot put it back.
	for post in posts:
		var hunter: Prey = post._standing
		if hunter.aggression <= 0.0:
			continue
		check(hunter.hunt_range < post.leash,
			"%s cannot see past its own leash (%.1fm against %.1f)"
			% [post.species_id, hunter.hunt_range, post.leash])
		# Losing the spider on distance is `hunt_range * 1.8`, so that has to fit
		# inside the leash too, or it never gives up that way either.
		check(hunter.hunt_range * 1.8 <= post.leash,
			"and gives up on distance inside it (%.1fm against %.1f)"
			% [hunter.hunt_range * 1.8, post.leash])

	# The readout is the whole reason the station exists.
	var target: Prey = posts[0]._standing
	target.bind(0.4)
	target.poison(6.0)
	await run_frames(4)
	var lines: String = posts[0]._readout.text
	check(lines.contains("bound") and lines.contains("40%"),
		"the readout says how much silk is on it")
	check(lines.contains("venom"), "and how long the venom has left")
	check(lines.contains("a web needs"),
		"and what a web would have to hold to take it")

	# Something a web could actually take, once softened. A practice target no web
	# in the game can hold is a target you cannot practise the web on.
	var snare := WebLibrary.load_patterns()
	var strongest := 0.0
	for spun in snare:
		strongest = maxf(strongest, spun.hold_strength)
	check(target.total_thrash() / Prey.ESCAPE_MARGIN <= strongest,
		"and at 40%% wrapped a real web could take it (%.1f needed, %.1f is the best there is)"
		% [target.total_thrash() / Prey.ESCAPE_MARGIN, strongest])

	# Finish one and the post stands another up, or it is a one-shot station.
	var was: Prey = posts[0]._standing
	was.eaten = true
	posts[0]._waiting = 0.05
	await run_frames(20)
	check(posts[0]._standing != was and is_instance_valid(posts[0]._standing),
		"and finishing one puts a fresh one up")

	# The clamp above is what makes the leash rule true, not the `.tres` happening
	# to agree with it today — and with the clamp in place the two checks up there
	# cannot fail, so this is the one that has anything to prove. Put the shipped
	# 14m back on the species and stand a fresh one up.
	var biter: TrainingDummy = null
	for post in posts:
		if is_instance_valid(post._standing) and post._standing.aggression > 0.0:
			biter = post
	if check(biter != null, "the gym has a hunter to try that on"):
		var kind: PreySpecies = biter._kind
		var was_range := kind.hunt_range
		kind.hunt_range = 14.0
		biter._standing.eaten = true
		biter._waiting = 0.05
		await run_frames(20)
		check(is_instance_valid(biter._standing)
				and biter._standing.hunt_range <= biter.leash * 0.6,
			"and a 14m species on a %.0fm leash still stands up seeing %.1fm"
			% [biter.leash, biter._standing.hunt_range])
		kind.hunt_range = was_range

	# Practice targets stay out of the game: the spawner, the larder and the
	# catalogue all read the species folder, and none of them want these.
	var shipped: Array[String] = []
	for kind in PreyLibrary.load_species():
		shipped.append(kind.id)
	check(not shipped.has("dummy_post"),
		"and none of them are in the game's own species (%d)" % shipped.size())
