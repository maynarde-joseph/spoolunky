extends TestSuite

## Headless check on the hunting ground, and on the gym.
##
##     godot --headless --script res://tests/world_smoke_test.gd
##
## A level's job is to be the right shape and to be alive, so that is what is
## checked: the places are all there, none inside another, each a plausible size
## for the bodies it was built for and every size with somewhere built for it;
## there is a sun, a day going round and an ecosystem keeping it; every species
## lives somewhere in it, every place but the camp grows food and has dens, and
## the things that roam have haunts to roam between; the ground is under every
## place and the Mere is water; the spider starts in the camp and the HUD says
## so; and every prop it is furnished with is something to stand on. None of this
## looks at how it plays — that is what opening it is for.

const GROUND_PATH := "res://game/world/hunting_ground.tscn"
const TESTBED_PATH := "res://game/world/testbed.tscn"

## The places: what each is called, and the stretch of the tier table it is built
## for, in body heights.
const PLACES := [
	["The Camp", 0.25, 0.4],
	["The Fern Floor", 0.25, 0.7],
	["The Rootways", 0.7, 2.0],
	["The Bloom Glade", 1.2, 3.4],
	["The Old Ruins", 2.0, 5.6],
	["The Mere", 3.4, 9.0],
	["Wyrm's Crag", 9.0, 9.0],
]


func run_checks() -> void:
	var ground := await open(GROUND_PATH)
	if ground == null:
		return

	var spider := root.get_tree().get_first_node_in_group("spider") as SpiderPlayer
	if not check(spider != null, "the hunting ground has a spider in it"):
		return

	_test_places()
	_test_every_size_has_a_place()
	_test_the_sky_and_the_clock(ground)
	_test_life(ground)
	_test_props()
	await _test_the_ground(ground as Node3D)
	await _test_the_spider_starts_in_camp(spider)
	_test_the_other_key(ground, spider)
	await _test_the_water(spider)
	await _test_the_swimmers()

	# Opening the gym drops the hunting ground: two full levels in the tree at once
	# is more than a headless run needs to hold.
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


## The places, none of them inside another. Overlapping bounds would make "which
## place am I in" a coin toss, and the HUD's naming of them hangs off it.
func _test_places() -> void:
	var zones := _zones()
	var names: Array[String] = []
	for zone in zones:
		names.append(zone.display_name)
	note(", ".join(names))
	if not check(zones.size() == PLACES.size(),
			"the places are all here, and nothing else (%d of %d)" % [zones.size(), PLACES.size()]):
		return
	for place in PLACES:
		var zone := _zone_named(place[0])
		if not check(zone != null, "%s is there" % place[0]):
			continue
		check(zone.bounds.get_volume() > 0.0,
			"%s has somewhere to be (%.0f m3)" % [zone.display_name, zone.bounds.get_volume()])
		check(is_equal_approx(zone.built_for.x, place[1]) and is_equal_approx(zone.built_for.y,
			place[2]), "and is built for %.2f to %.2f" % [zone.built_for.x, zone.built_for.y])
		# A forest to a spiderling is the point of the place, but a county is not.
		var across := zone.body_lengths_across()
		check(across > 20.0 and across < 1500.0,
			"%s is %d body lengths across" % [zone.display_name, roundi(across)])
	var overlaps := 0
	for i in zones.size():
		for j in range(i + 1, zones.size()):
			if zones[i].bounds.intersects(zones[j].bounds):
				overlaps += 1
				note("%s overlaps %s" % [zones[i].display_name, zones[j].display_name])
	check(overlaps == 0, "and none of them are inside each other (%d)" % overlaps)


## Whatever size the spider is, somewhere is built for it.
func _test_every_size_has_a_place() -> void:
	var homeless: Array[String] = []
	for stage in WebLibrary.default_stages():
		var found := false
		for zone in _zones():
			if stage.body_height >= zone.built_for.x - 0.001 \
					and stage.body_height <= zone.built_for.y + 0.001:
				found = true
		if not found:
			homeless.append(stage.display_name)
	check(homeless.is_empty(), "every size has a place built for it (%s without)"
		% (", ".join(homeless) if not homeless.is_empty() else "none"))


## One sun, a sky, a day going round and an ecosystem keeping it.
func _test_the_sky_and_the_clock(ground: Node) -> void:
	var suns := 0
	var skies := 0
	for node in all_under(ground):
		if node is DirectionalLight3D:
			suns += 1
		if node is WorldEnvironment:
			skies += 1
	check(suns == 1 and skies == 1, "one sun and one sky (%d, %d)" % [suns, skies])
	var clock := Ecosystem.of(ground)
	check(clock != null and clock.running, "an ecosystem, keeping the day going round")
	var day := ground.find_child("DayNight", true, false) as DayNight
	check(day != null and day.moon != null and day.sun != null,
		"and a day and night driving the sun, with a moon for after dark")


## Every species lives somewhere here: a den of it in some place. Every place but
## the camp grows something to eat and has something living in it, and nothing
## lives in the camp. The things that roam have somewhere to roam to.
func _test_life(ground: Node) -> void:
	var dens: Array[Den] = []
	var patches: Array[Forage] = []
	var haunts: Array[Haunt] = []
	for node in all_under(ground):
		if node is Den:
			dens.append(node)
		elif node is Forage:
			patches.append(node)
		elif node is Haunt:
			haunts.append(node)
	var housed := {}
	for den in dens:
		housed[den.species_id] = true
	var homeless: Array[String] = []
	for kind in PreyLibrary.load_species():
		if not housed.has(kind.id):
			homeless.append(kind.id)
	check(homeless.is_empty(), "every species has a den here (%d dens; %s without)"
		% [dens.size(), ", ".join(homeless) if not homeless.is_empty() else "none"])
	for place in PLACES:
		var zone := _zone_named(place[0])
		if zone == null:
			continue
		var living := 0
		for den in dens:
			if zone.contains(den.global_position):
				living += 1
		var growing := 0
		for patch in patches:
			if zone.contains(patch.global_position):
				growing += 1
		if place[0] == "The Camp":
			check(living == 0, "nothing lives in the camp (%d dens)" % living)
			continue
		check(living > 0 and growing > 0, "%s has %d dens and %d patches of forage"
			% [place[0], living, growing])
	var roamers: Array[String] = []
	for kind in PreyLibrary.load_species():
		if not kind.roams:
			continue
		var places := 0
		for haunt in haunts:
			if haunt.welcomes(kind):
				places += 1
		if places < 2:
			roamers.append("%s (%d)" % [kind.id, places])
	check(roamers.is_empty(), "everything that roams has haunts to roam between (%s short)"
		% (", ".join(roamers) if not roamers.is_empty() else "none"))
	_note_life(dens)


## How much there is: said, not checked.
func _note_life(dens: Array[Den]) -> void:
	var out := 0
	for den in dens:
		out += den.count()
	note("%d dens, %d creatures out" % [dens.size(), out])


## The ground is under every place: straight down from above the middle of each,
## the first thing hit is the ground, at a height that place could have.
func _test_the_ground(ground: Node3D) -> void:
	await physics_frame
	var space := ground.get_world_3d().direct_space_state
	var missing: Array[String] = []
	for place in PLACES:
		var zone := _zone_named(place[0])
		if zone == null:
			continue
		var middle := zone.bounds.get_center()
		var query := PhysicsRayQueryParameters3D.create(Vector3(middle.x, 400.0, middle.z),
			Vector3(middle.x, -100.0, middle.z), GameLayers.WORLD)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			missing.append(place[0])
	check(missing.is_empty(), "there is ground under every place (%s without)"
		% (", ".join(missing) if not missing.is_empty() else "none"))
	# And the hills rise round the edge, so the valley is a valley.
	var rim := space.intersect_ray(PhysicsRayQueryParameters3D.create(
		Vector3(0.0, 400.0, -360.0), Vector3(0.0, -100.0, -360.0), GameLayers.WORLD))
	var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
		Vector3(HuntingGround.GLADE.x, 400.0, HuntingGround.GLADE.y),
		Vector3(HuntingGround.GLADE.x, -100.0, HuntingGround.GLADE.y), GameLayers.WORLD))
	if check(not rim.is_empty() and not floor_hit.is_empty(), "the ground is there at the edge too"):
		check(rim["position"].y > floor_hit["position"].y + 30.0,
			"and the hills round it stand well over the valley floor (%.0f against %.0f)"
			% [rim["position"].y, floor_hit["position"].y])


## The spider is put in the camp, stays there on its floor, and the HUD says where
## it is.
func _test_the_spider_starts_in_camp(spider: SpiderPlayer) -> void:
	await run_frames(240)
	var here := Zone.at(root.get_tree(), spider.global_position)
	check(here != null and here.display_name == "The Camp",
		"it starts in the camp and stays there (%s)"
		% (here.display_name if here != null else "nowhere"))
	var under := HuntingGround.new()
	var floor_y := under.ground_at(spider.global_position.x, spider.global_position.z)
	under.free()
	check(spider.global_position.y > floor_y - 1.0,
		"standing on its floor rather than through it (%.2f, the ground at %.1f)"
		% [spider.global_position.y, floor_y])
	var hud := current_scene.get_node_or_null("HUD")
	var named: Label = hud.get("_area_label") if hud != null else null
	check(named != null and named.text == "The Camp", "and the HUD names the place (%s)"
		% (named.text if named != null else "no label"))


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


## The Mere is water, to a spider as much as anything: put in it, it swims.
func _test_the_water(spider: SpiderPlayer) -> void:
	var mere := _zone_named("The Mere")
	if not check(mere != null, "there is a mere to have water in"):
		return
	var pools := 0
	for node in root.get_tree().get_nodes_in_group("water"):
		var pool := node as Area3D
		if pool != null and pool.collision_layer & GameLayers.WATER != 0 \
				and mere.bounds.has_point(pool.global_position):
			pools += 1
	check(pools > 0, "the Mere is full of water (%d bodies of it)" % pools)
	var at := Vector3(HuntingGround.MERE.x - 30.0, HuntingGround.WATER_TOP - 2.0,
		HuntingGround.MERE.y)
	var top := Prey.water_top_at(spider, at)
	check(is_equal_approx(top, HuntingGround.WATER_TOP),
		"to the top, at %.1f (%.1f)" % [HuntingGround.WATER_TOP, top])
	var was := spider.global_position
	spider.global_position = at
	spider.velocity = Vector3.ZERO
	await run_frames(6)
	check(not spider.climb.handles_movement(),
		"and a spider put in it is swimming, not walking the bottom")
	spider.global_position = was
	spider.velocity = Vector3.ZERO
	await run_frames(2)


## Whatever swims in the Mere keeps all of itself under the top of it.
func _test_the_swimmers() -> void:
	var mere := _zone_named("The Mere")
	if mere == null:
		return
	await run_frames(60)
	var swimmers := 0
	var highest := -INF
	for node in root.get_tree().get_nodes_in_group("prey"):
		var prey := node as Prey
		if prey == null or not prey.swims or not mere.bounds.has_point(prey.global_position):
			continue
		swimmers += 1
		highest = maxf(highest, prey.global_position.y + prey.hit_radius())
	check(swimmers >= 4, "there are things in the Mere (%d)" % swimmers)
	check(highest <= HuntingGround.WATER_TOP + 0.05,
		"and none of them breaks the surface (the highest comes to %.2f, the water %.2f)"
		% [highest, HuntingGround.WATER_TOP])


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
