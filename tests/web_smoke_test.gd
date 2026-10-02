extends WebSuite

## Headless smoke test for the web building loop.
##
##     godot --headless --script res://tests/web_smoke_test.gd
##
## Loads the sandbox level and drives the spider through building each kind of
## web, catching prey in one, wrapping and draining it, growing a size tier and
## pulling a web back down. Exits non-zero if anything comes back wrong.


func run_checks() -> void:
	if not await open_sandbox():
		return
	for section: Callable in _sections():
		await reset()
		await section.call()


## Every section, each one handed a fresh arena by [method WebSuite.reset].
##
## The order used to be load-bearing and mostly undocumented: the tree went last
## because buying a trait is permanent, and everything above it had been written
## against a spider the ladder alone had made. Nothing depends on what ran before
## it any more — a section that wants a grown spider or a standing web makes one.
func _sections() -> Array[Callable]:
	var list: Array[Callable] = [
		_test_starting_state,
		_test_input_map,
		_test_aiming,
		_test_building_a_net,
		_test_catching,
		_test_strands,
		_test_growth,
		_test_held_at_one_size,
		_test_tripline_alert,
		_test_pressure_snare,
		_test_trigger_links,
		_test_weave_modes,
		_test_rings_of_silk,
		_test_living_on_the_web,
		_test_tuning_dials,
		_test_saved_designs,
		_test_placing_a_web,
		_test_a_web_fits_the_space,
		_test_spitting_a_web_at_something,
		_test_throwing_a_bolt,
		_test_species,
		_test_creatures_that_live_somewhere,
		_test_tethering,
		_test_a_catch_comes_over_a_wall,
		_test_a_meal_takes_time,
		_test_anything_you_can_hold,
		_test_carrion,
		_test_something_hunts_you,
		_test_a_hunt_runs_out,
		_test_wrapped_things_fall,
		_test_shooting,
		_test_softening_something_big,
		_test_silk_slows_what_it_sticks_to,
		_test_what_venom_is_worth,
		_test_silk_stays_on_what_tore_loose,
		_test_silk_outlasts_the_wait,
		_test_it_takes_more_than_one_shot,
		_test_a_bolt_at_a_creature_leaves_no_web,
		_test_clicking_something_alive_grapples_past_it,
		_test_hitching_something_to_the_ground,
		_test_taking_a_web_home,
		_test_the_click_finds_the_whole_web,
		_test_a_road_is_not_collected,
		_test_the_camera_tells_the_truth,
		_test_taking_aim,
		_test_leading_a_moving_target,
		_test_how_far_silk_goes,
		_test_a_shot_fits_a_corner,
		_test_silk_sits_on_what_it_sticks_to,
		_test_a_sprint_costs_wind,
		_test_a_spiders_jump,
		_test_the_bar,
		_test_the_larder,
		_test_three_lines,
		_test_webs_do_not_pile_up,
		_test_a_web_ends_with_its_catch,
		_test_the_bag,
		_test_sandbox_wiring,
		_test_demolish,
		_test_the_tree,
	]
	# SPOOLUNKY_SHUFFLE=<seed> runs them in a random order. Nothing here depends on
	# what ran before it, and running it shuffled now and again is what keeps that
	# true — the seed is printed so a failure can be run again exactly.
	var seed_text := OS.get_environment("SPOOLUNKY_SHUFFLE")
	if not seed_text.is_empty():
		seed(seed_text.hash())
		list.shuffle()
		note("shuffled, seed %s" % seed_text)
	return list


func _test_starting_state() -> void:
	var stage := spider.stage()
	check(stage.display_name == "Spiderling", "starts as a spiderling")
	var capsule := spider.collision.shape as CapsuleShape3D
	check(is_equal_approx(capsule.height, stage.body_height),
		"collider matches the size tier (%.2f)" % capsule.height)
	check(is_equal_approx(spider.head.position.y, stage.body_height * 0.32),
		"eye height scaled to the body")
	check(builder.patterns.size() >= 6, "loaded %d web patterns" % builder.patterns.size())
	check(builder.unlocked_patterns().size() == 3,
		"frame line, tripline and sheet web to start with (%d)"
		% builder.unlocked_patterns().size())
	# Q spins nets and refuses strands, so a wheel parked on a strand is a
	# place key that silently does nothing. That is exactly how it shipped.
	var starting := builder.current_pattern()
	check(starting != null and starting.shape == WebPattern.Shape.NET,
		"the wheel starts on a web Q can actually spin (%s)"
		% (starting.display_name if starting != null else "nothing"))


func _test_input_map() -> void:
	for action in ["web_build_mode", "web_place", "web_cancel", "web_finish",
			"web_next_pattern", "web_prev_pattern", "web_remove", "interact",
			"device_mode", "web_throw_mode", "web_tether", "web_shoot", "move_sprint",
			"skill_tree", "hotbar_1", "hotbar_9", "hotbar_next", "toggle_help"]:
		check(InputMap.has_action(action), "input action '%s' is set up" % action)

	# A headless display server cannot capture the mouse, so lift that gate.
	spider.require_captured_mouse = false

	var started_with := builder.current_pattern()
	send_action(spider.input_next_pattern)
	await process_frame
	check(builder.current_pattern() != started_with, "the wheel changes pattern")
	send_action(spider.input_prev_pattern)
	await process_frame
	check(builder.current_pattern() == started_with, "and changes back")

	# Grappling is not a mode any more, and Q spins a web where you point
	# rather than putting you in a state.
	check(not builder.building, "there is no build mode to be in")
	send_action(spider.input_build_mode)
	await process_frame
	check(not builder.building, "and Q does not put you in one")
	builder.cancel_place()
	release_action(spider.input_build_mode)


func _test_aiming() -> void:
	builder.start()
	# Look straight down at the floor. Aim lives on the camera rig now.
	spider.view.pitch = -PI / 2.0
	await process_frame
	builder._update_aim()
	check(builder.aim_valid, "aiming at the floor finds an anchor point")
	check(builder.aim_point.distance_to(spider.global_position) < spider.stage().anchor_range,
		"anchor point is inside the tier's reach")

	# Aiming at open sky should not find anything.
	spider.view.pitch = PI / 2.0
	await process_frame
	builder._update_aim()
	check(not builder.aim_valid, "aiming at nothing gives no anchor")
	check(builder.problem == WebBuilder.Problem.NO_SURFACE, "and says why")
	builder.stop()


func _test_building_a_net() -> void:
	select_pattern("sheet_web")
	builder.start()
	var centre := spider.global_position + Vector3(0, 0.4, -1.0)

	var corners := _square(centre, 0.6)
	for point in corners:
		builder.add_anchor(point)
	check(web_count() == 3, "three lines behind four anchors (%d)" % web_count())
	check(builder.enclosed_area() > 0.0,
		"the run encloses %.2f m2" % builder.enclosed_area())

	builder.finish()
	await physics_frame

	var net := newest_web("sheet_web") as WebNet
	if not check(net != null, "a sheet web was woven inside it"):
		return
	check(net.mesh_instance != null and net.mesh_instance.mesh.get_surface_count() > 0,
		"the web has a mesh")
	check(net.catch_area != null, "the web has a catch volume")
	check(net.area > 0.0, "the web encloses %.2f m2" % net.area)
	check(net.global_position.distance_to(centre) < 0.5, "the web sits where it was strung")
	check(net.durability > 0.0 and net.durability == net.max_durability, "it starts intact")
	check(builder.anchors.is_empty(), "the run resets after weaving")
	check(builder.building, "build mode stays on for the next one")

	# The frame outlives the web: roads are not traps.
	var lines_before := _count_pattern("frame_line")
	check(lines_before == 4, "the ring left four lines standing (%d)" % lines_before)
	builder.stop()

	# Too few anchors must not weave anything — with nothing else to lean on.
	#
	# One anchor while a ring of silk is in view is a different move: the builder
	# weaves a sheet into the ring, which is a feature and says so ("Sheet Web
	# woven into the ring"). This check used to pass only because the section
	# before it happened to leave the camera pointing elsewhere, so it never
	# actually tested its own claim. Look away from the ring and it does.
	spider.view.face(Vector3(0, 0, 1))
	spider.view.pitch = 0.0
	builder.start()
	builder.add_anchor(centre + Vector3(0, 1.5, 0))
	var webs_before := web_count()
	builder.finish()
	check(web_count() == webs_before,
		"a lone anchor weaves nothing (%d, started %d)" % [web_count(), webs_before])
	builder.stop()


## Vertices in a web's drawn silk, or 0. A stand-in for "how much thread".
func _mesh_verts(web: WebStructure) -> int:
	if web == null or web.mesh_instance == null or web.mesh_instance.mesh == null:
		return 0
	if web.mesh_instance.mesh.get_surface_count() == 0:
		return 0
	return web.mesh_instance.mesh.surface_get_array_len(0)


func _count_pattern(pattern_id: String) -> int:
	var total := 0
	for child in webs.get_children():
		var web := child as WebStructure
		if web != null and not web.is_queued_for_deletion() and web.pattern.id == pattern_id:
			total += 1
	return total


func _test_catching() -> void:
	var net := first_web() as WebNet
	if net == null:
		return
	clear_prey_near(net.to_global(net.centre_local), net.radius * 3.0, null)
	await physics_frame
	await process_frame
	var fly := spawn_fly(net.to_global(net.centre_local))
	await physics_frame
	await physics_frame

	if not check(fly.is_stuck(), "a fly that flew into the web is stuck"):
		return
	check(net.snared_count() == 1, "the web knows it caught something")

	# Struggling should be wearing the web down.
	var durability_before := net.durability
	for i in 10:
		await physics_frame
	check(net.durability < durability_before, "struggling damages the web")

	spider.jaws.handle(fly)
	check(fly.wrapped, "the spider wrapped it")

	var steady := net.durability
	for i in 10:
		await physics_frame
	check(is_equal_approx(net.durability, steady), "a wrapped fly stops wrecking the web")

	var biomass_before := spider.growth.biomass
	spider.jaws.handle(fly)
	await process_frame
	check(spider.growth.biomass > biomass_before, "draining it feeds the spider")
	check(not is_instance_valid(fly) or fly.eaten, "the fly is gone")
	# And the web goes with it. A web is a larder while it holds something and
	# nothing once it does not — see _test_a_web_ends_with_its_catch.
	check(not is_instance_valid(net), "and the web comes down with the catch")


func _test_strands() -> void:
	select_pattern("trip_line")
	builder.start()
	var base := spider.global_position + Vector3(1.5, 0.3, 0)
	builder.add_anchor(base)
	builder.add_anchor(base + Vector3(0, 0, 1.2))
	await physics_frame

	var trip := find_web("trip_line") as WebStrand
	if not check(trip != null, "a tripline was spun"):
		return
	check(trip.catch_area != null, "the tripline watches for crossings")
	check(trip.get_node_or_null("Walkway") == null,
		"and has nothing to walk on: a line is something to hang from")
	builder.stop()


func _test_growth() -> void:
	var before_height := (spider.collision.shape as CapsuleShape3D).height
	var gained := spider.growth.feed(60.0, "test")
	await physics_frame
	check(gained > 0, "eating enough grows the spider %d tier(s)" % gained)
	var stage := spider.stage()
	var capsule := spider.collision.shape as CapsuleShape3D
	check(capsule.height > before_height, "the body got bigger (%.2f -> %.2f)" % [before_height, capsule.height])
	check(is_equal_approx(capsule.height, stage.body_height), "and matches the new tier")
	check(is_equal_approx(spider.jump_ability.height, stage.jump_velocity), "jump scaled with it")
	check(builder.unlocked_patterns().size() > 2, "bigger spider, more web patterns")

	# A bridge is a tier-2 unlock, so it should build now.
	select_pattern("silk_bridge")
	builder.start()
	var base := spider.global_position + Vector3(-1.5, 0.4, 0)
	builder.add_anchor(base)
	builder.add_anchor(base + Vector3(0, 0, 1.4))
	await physics_frame
	var bridge := find_web("silk_bridge") as WebStrand
	if check(bridge != null, "a silk bridge was spun"):
		check(bridge.get_node_or_null("Walkway") != null, "the bridge is solid enough to walk on")
		check(bridge.catch_area == null, "but it does not catch anything")
	builder.stop()


## A level can hold the spider at one size: eating is still worth its biomass,
## but it grows nothing. That is the world where size comes from what you become
## rather than from what you eat. And it can start the spider bigger than a
## spiderling.
func _test_held_at_one_size() -> void:
	var growth := spider.growth
	growth.grows = false
	growth.start_stage = 2
	growth.apply_initial()
	await physics_frame
	check(growth.stage_index == 2 and spider.stage().display_name == "Huntsman",
		"a level can start the spider as a Huntsman (%s)" % spider.stage().display_name)
	var capsule := spider.collision.shape as CapsuleShape3D
	check(is_equal_approx(capsule.height, spider.stage().body_height),
		"and the body is that size (%.2f)" % capsule.height)
	var before := growth.biomass
	var gained := growth.feed(5000.0, "test")
	await physics_frame
	check(gained == 0 and growth.stage_index == 2,
		"and held there, eating grows it nothing (%d tiers from a feast)" % gained)
	check(growth.biomass > before, "though the meal still counts (%d -> %d)"
		% [roundi(before), roundi(growth.biomass)])
	growth.grows = true
	growth.start_stage = 0


func _test_tripline_alert() -> void:
	# Its own line to walk into. This used to read whatever tripline an earlier
	# section had left up, which made it the only check here with no setup and the
	# first to break when anything above it changed.
	select_pattern("trip_line")
	builder.start()
	var base := spider.global_position + Vector3(0, 0.3, -1.2)
	builder.add_anchor(base + Vector3(-0.7, 0, 0))
	builder.add_anchor(base + Vector3(0.7, 0, 0))
	await physics_frame
	builder.stop()
	var trip := find_web("trip_line") as WebStrand
	if not check(trip != null, "a tripline to walk into"):
		return
	var tripped := [false]
	trip.tripped.connect(func(_web: WebStructure, _who: Node3D) -> void: tripped[0] = true)

	var fly := spawn_fly((trip.point_a + trip.point_b) * 0.5)
	await physics_frame
	await physics_frame
	check(tripped[0], "walking through a tripline reports it")
	check(not fly.is_stuck(), "but a tripline does not hold anything")
	check(trip.snared_count() == 0, "and catches nothing")
	fly.queue_free()
	await physics_frame


func _test_pressure_snare() -> void:
	check(grow_to_spin("pressure_snare"), "grown enough to build snares")
	await physics_frame

	select_pattern("pressure_snare")
	var centre := spider.global_position + Vector3(0, 0.5, 2.0)
	# Clear the patch first. Some of what wanders the level walks on the floor
	# now, and a trap on the floor is exactly what a walker blunders into — so
	# without this the snare is sometimes already sprung before the first check
	# looks at it, which is a test of where the beetles happened to be.
	clear_prey_near(centre, 8.0, null)
	await physics_frame
	await process_frame

	builder.start()
	for point in _square(centre, 0.7):
		builder.add_anchor(point)
	builder.finish()
	builder.stop()
	await physics_frame

	var snare := find_web("pressure_snare") as WebNet
	if not check(snare != null, "a pressure snare was spun"):
		return
	check(snare.armed, "it starts armed")
	check(not snare.needs_rearm(), "and does not want re-arming yet")
	check(snare.snared_count() == 0,
		"with nothing already in it (%d)" % snare.snared_count())

	# A beetle walks, which is the whole reason a trap on the ground exists.
	var quarry := spawn("beetle", snare.to_global(snare.centre_local))
	if not check(quarry != null, "a beetle to spring it on"):
		return
	await physics_frame
	await physics_frame
	check(quarry.is_stuck(), "the snare caught a beetle")
	check(not snare.armed, "the snare has sprung")
	check(snare.needs_rearm(), "and now needs re-arming")

	# While the snare holds it rigid the fly cannot fight back.
	var durability := snare.durability
	for i in 8:
		await physics_frame
	check(is_equal_approx(snare.durability, durability), "held prey cannot damage a sprung snare")

	check(snare.rearm(), "the snare re-arms")
	check(snare.armed and not snare.needs_rearm(), "and is ready again")
	quarry.consume()
	await physics_frame


## The point of the whole feature: a tripline metres away springs a snare, and
## the snare grabs prey that never touched it.
func _test_trigger_links() -> void:
	# A snare is two tiers up, and this is about wiring rather than growing.
	grow_to_spin("pressure_snare")
	var base := spider.global_position + Vector3(0, 0.4, -3.0)

	select_pattern("pressure_snare")
	builder.start()
	for point in _square(base, 0.7):
		builder.add_anchor(point)
	builder.finish()
	builder.stop()
	await physics_frame
	var snare := newest_web("pressure_snare") as WebNet
	if not check(snare != null, "a snare to wire up"):
		return

	# A tripline well clear of the snare — nothing that crosses it is anywhere
	# near the silk.
	var trip_at := base + Vector3(3.5, 0, 0)
	select_pattern("trip_line")
	builder.start()
	builder.add_anchor(trip_at + Vector3(0, -0.4, -0.6))
	builder.add_anchor(trip_at + Vector3(0, -0.4, 0.6))
	builder.stop()
	await physics_frame
	var trip := newest_web("trip_line") as WebStrand
	if not check(trip != null, "a tripline to wire it to"):
		return

	# Wire them together, both ends by hand the way the player does.
	check(builder.link_nodes(trip, snare), "the two webs can be wired together")
	await physics_frame
	check(trip.links.has(snare), "the tripline is wired to the snare")
	check(not builder.is_linking(), "wiring finished")
	check(trip.link_mesh != null and trip.link_mesh.mesh != null,
		"the signal line is drawn so the player can read it")
	# A solid line would be one segment: two crossed quads, twelve vertices.
	# Dashes are what stop it reading as structural silk.
	var wire_verts: int = trip.link_mesh.mesh.surface_get_array_len(0)
	check(wire_verts > 12 * 4, "and drawn dashed, not as another strand of silk (%d verts)"
		% wire_verts)

	# A fly loitering near the snare, but not in it.
	var centre := snare.to_global(snare.centre_local)
	var bystander := spawn_fly(centre + Vector3(0, 0, 1.3))
	await physics_frame
	await physics_frame
	var reach: float = snare.radius * snare.pattern.signal_strike_factor
	check(not bystander.is_stuck(), "a fly beside the snare is not caught by it")
	check(centre.distance_to(bystander.global_position) > snare.radius,
		"and is genuinely outside the web")
	check(centre.distance_to(bystander.global_position) < reach,
		"but inside the snare's strike range (%.1fm)" % reach)

	# The level keeps a dozen flies wandering about, and a sprung snare grabs
	# the nearest thing in reach — so anything else that has drifted into range
	# would win the race and make this a test of where the spawner's flies
	# happened to be. Clear the field first.
	clear_prey_near(centre, reach, bystander)
	await physics_frame
	await process_frame

	# Now set the line off, far away.
	check(snare.armed, "the snare is armed before anything happens")
	var crosser := spawn_fly((trip.point_a + trip.point_b) * 0.5)
	await physics_frame
	await physics_frame

	# Fire the line directly rather than trusting a fly to blunder into a thread
	# two centimetres thick inside two frames. That a fly trips a line is
	# _test_tripline_alert's job; what is being tested here is that the signal
	# reaches a snare across the room, and that should not ride on spawn luck.
	trip.fire()
	await physics_frame
	await physics_frame

	check(not snare.armed, "a signal down the line springs the distant snare")
	check(bystander.is_stuck(),
		"and the snare drags in a fly that never touched it")
	check(snare.snared_count() == 1, "the snare has it")
	check(not crosser.is_stuck(), "while the fly on the tripline walks on")

	# Tensing: a plain web wired to something pulls taut instead of springing.
	select_pattern("orb_web")
	builder.start()
	for point in _square(base + Vector3(-2.5, 0, 0), 0.6):
		builder.add_anchor(point)
	builder.finish()
	builder.stop()
	await physics_frame
	var orb := newest_web("orb_web") as WebNet
	if check(orb != null, "an orb web to tense"):
		var relaxed := orb.hold_strength()
		orb.receive_signal(trip, 1)
		check(orb.is_tensed(), "a signal draws a plain web tight")
		check(orb.hold_strength() > relaxed,
			"which makes it hold better (%.1f -> %.1f)" % [relaxed, orb.hold_strength()])
		check(orb.armed, "and does not spring it — there is nothing to spring")

	# A chain of webs must not be able to ring round forever.
	trip.links.append(orb)
	orb.links.append(trip)
	trip.fire()
	check(true, "a loop of wired webs settles instead of hanging")
	orb.links.erase(trip)
	trip.links.erase(orb)

	# Pulling a web down takes its wiring with it. The bystander is simply
	# removed rather than drained — draining it would take the snare down with
	# it, and the snare is the thing being demolished on purpose here.
	bystander.queue_free()
	var had_links := trip.links.size()
	check(had_links > 0, "the tripline still has wiring to lose")
	snare.demolish()
	await physics_frame
	check(trip.links.size() == had_links - 1, "demolishing a web unwires it")
	check(trip.link_mesh.mesh == null, "and its signal line stops being drawn")


## Keeping a rig and putting it down again somewhere else, wiring and all.
## Every dial has to cost something. A setting that is simply better is not a
## decision, so these checks are really checks on the design.
## Anchors in a room corner do not share a plane. Whichever way a web is woven,
## its frame has to stay on them — a web that floats off the wall it was
## anchored to is the bug this guards.
func _corner_anchors() -> PackedVector3Array:
	return PackedVector3Array([
		Vector3(0.0, 0.2, 0.2), Vector3(0.0, 0.2, 0.9),
		Vector3(0.0, 0.9, 0.55), Vector3(0.7, 0.55, 0.0)])


func _worst_anchor_drift(points: PackedVector3Array, layout) -> float:
	var origin := Vector3.ZERO
	for p in points:
		origin += p
	origin /= float(points.size())
	var worst := 0.0
	for anchor in points:
		var nearest := INF
		for rim_point in layout.rim:
			nearest = minf(nearest, anchor.distance_to(origin + rim_point))
		worst = maxf(worst, nearest)
	return worst


func _test_weave_modes() -> void:
	# An orb web is a tier past a spiderling, and this is about the web.
	grow_to_spin("orb_web")
	select_pattern("orb_web")
	var pattern := builder.current_pattern()
	var corner := _corner_anchors()
	var centre := Vector3.ZERO
	for p in corner:
		centre += p
	centre /= float(corner.size())

	# How far off a single plane those anchors really are.
	var normal := WebGeometry.plane_normal(corner)
	var off_plane := 0.0
	for anchor in corner:
		off_plane = maxf(off_plane, absf((anchor - centre).dot(normal)))
	check(off_plane > 0.1, "the test anchors genuinely do not lie flat (%.2fm)" % off_plane)

	for mode in [WebGeometry.Weave.STRETCHED, WebGeometry.Weave.INSCRIBED]:
		var label := "stretched" if mode == WebGeometry.Weave.STRETCHED else "inscribed"
		var layout = WebGeometry.layout_net(corner, pattern, centre, 1.0, mode)
		check(layout.valid, "%s: the corner web holds together" % label)
		check(layout.rim.size() == corner.size(), "%s: every anchor is on the frame" % label)
		var drift := _worst_anchor_drift(corner, layout)
		check(drift < 0.001, "%s: the frame stays on the anchors (%.4fm drift)" % [label, drift])

	# Stretched fills the whole outline; inscribed keeps a round spiral inside it.
	var stretched = WebGeometry.layout_net(corner, pattern, centre, 1.0,
		WebGeometry.Weave.STRETCHED)
	var inscribed = WebGeometry.layout_net(corner, pattern, centre, 1.0,
		WebGeometry.Weave.INSCRIBED)
	check(inscribed.spiral_radius > 0.0, "inscribed: there is a sticky disc (%.2fm across)"
		% (inscribed.spiral_radius * 2.0))
	check(inscribed.area < stretched.area,
		"inscribed: it catches over less than the whole outline (%.2f vs %.2f m2)"
		% [inscribed.area, stretched.area])
	check(stretched.spiral_radius == 0.0, "stretched: sticky all the way to the frame")

	# The shape of the outline pays: a fat one fits a far bigger spiral than a
	# sliver of the same span.
	var fat := PackedVector3Array([Vector3(0, 0, 0), Vector3(1.2, 0, 0),
		Vector3(1.2, 1.2, 0), Vector3(0, 1.2, 0)])
	var sliver := PackedVector3Array([Vector3(0, 0, 0), Vector3(1.2, 0, 0),
		Vector3(1.2, 0.12, 0), Vector3(0, 0.12, 0)])
	var fat_disc = WebGeometry.layout_net(fat, pattern, Vector3(0.6, 0.6, 0), 1.0,
		WebGeometry.Weave.INSCRIBED)
	var sliver_disc = WebGeometry.layout_net(sliver, pattern, Vector3(0.6, 0.06, 0), 1.0,
		WebGeometry.Weave.INSCRIBED)
	check(fat_disc.spiral_radius > sliver_disc.spiral_radius * 4.0,
		"a fat outline is worth far more web than a sliver (%.2fm vs %.2fm radius)"
		% [fat_disc.spiral_radius, sliver_disc.spiral_radius])

	# The switch reaches the webs that actually get spun.
	var base := spider.global_position + Vector3(6.0, 0.4, 0.0)
	builder.weave = WebGeometry.Weave.INSCRIBED
	builder.start()
	for point in _square(base, 0.7):
		builder.add_anchor(point)
	builder.finish()
	builder.stop()
	await physics_frame
	var spun := newest_web("orb_web") as WebNet
	if check(spun != null, "an inscribed web was spun"):
		check(spun.weave == WebGeometry.Weave.INSCRIBED, "and it remembers how")
		check(spun.spiral_radius > 0.0, "with a sticky disc")
		var collider := spun.catch_area.get_child(0) as CollisionShape3D
		check(collider.shape is CylinderShape3D, "and only that disc catches")
		spun.demolish()
	builder.toggle_weave()
	check(builder.weave == WebGeometry.Weave.STRETCHED, "K switches the weave back")
	await physics_frame


## Three lines slung across a gap, none of them touching another at an end,
## still enclose the triangle where they cross — and that triangle can be woven.
func _test_rings_of_silk() -> void:
	spider.view.pitch = 0.0
	spider.view.face(Vector3.FORWARD)
	await physics_frame
	var origin := spider.view.aim_origin()
	var forward := spider.view.aim_forward()
	var centre := origin + forward * 2.0
	var across := forward.cross(Vector3.UP).normalized()
	var up := across.cross(forward).normalized()

	# A triangle made only by crossings: each line runs well past the others.
	var frame := pattern_named("frame_line")
	var lines: Array[WebStrand] = []
	for pair in [
			[centre - across * 1.0 - up * 0.35, centre + across * 1.0 - up * 0.35],
			[centre - across * 0.5 - up * 0.7, centre + across * 0.5 + up * 0.7],
			[centre + across * 0.5 - up * 0.7, centre - across * 0.5 + up * 0.7]]:
		var line := WebStrand.spin(frame, pair[0], pair[1], 1.0)
		if line != null:
			line.place_in(webs)
			lines.append(line)
	check(lines.size() == 3, "three lines strung across the gap")
	await physics_frame

	var rings := builder.loops()
	if not check(rings.size() > 0, "their crossings enclose something (%d ring%s)"
			% [rings.size(), "" if rings.size() == 1 else "s"]):
		return
	var smallest = rings[rings.size() - 1]
	check(smallest.area > 0.01, "the ring has real area (%.3f m2)" % smallest.area)
	check(smallest.points.size() == 3, "and three corners (%d)" % smallest.points.size())

	# None of those corners is the end of a line: they are all crossings.
	var corners_on_ends := 0
	for corner in smallest.points:
		for line in lines:
			if corner.distance_to(line.point_a) < 0.05 or corner.distance_to(line.point_b) < 0.05:
				corners_on_ends += 1
	check(corners_on_ends == 0, "every corner is a crossing, not a line end")

	select_pattern("sheet_web")
	builder.start()
	var aimed = builder.aimed_loop()
	check(aimed != null, "the ring is found under the crosshair")
	var woven := builder.fill_aimed_loop()
	builder.stop()
	await physics_frame
	check(woven, "and can be woven in one go")

	var net := newest_web("sheet_web") as WebNet
	if check(net != null, "a web is standing in the ring"):
		net.demolish()
	for line in lines:
		if is_instance_valid(line):
			check(true, "the lines are still there afterwards")
			break
	for line in lines:
		if is_instance_valid(line):
			line.demolish()
	await physics_frame

	# And every strand is rideable now, not just the ones meant as roads.
	var opt_in := false
	for entry in pattern_named("trip_line").get_property_list():
		if entry.get("name", "") == "ridable":
			opt_in = true
	check(not opt_in, "there is no opt-in for riding any more — all silk is a zipline")


## A spider lives on its web. It has to hold the spider's weight and still let
## prey fly into it, which is why silk gets its own collision layer.
func _test_living_on_the_web() -> void:

	# A web lying flat on the ground — the case worth checking, because a trap
	# underfoot is the one that sounds like it needs to be a special object.
	var floor_height := spider.global_position.y - spider.stage().body_height * 0.4
	var centre := spider.global_position + Vector3(2.5, 0, 2.5)
	centre.y = floor_height + 0.05
	select_pattern("sheet_web")
	builder.start()
	for offset in [Vector3(-0.7, 0, -0.7), Vector3(0.7, 0, -0.7),
			Vector3(0.7, 0, 0.7), Vector3(-0.7, 0, 0.7)]:
		builder.add_anchor(centre + offset)
	builder.finish()
	builder.stop()
	await physics_frame

	var mat := newest_web("sheet_web") as WebNet
	if not check(mat != null, "a web woven flat on the ground"):
		return
	check(absf(mat.plane_normal.dot(Vector3.UP)) > 0.9, "lying flat, as asked")

	# It must be solid enough to stand on...
	var walkway := mat.get_node_or_null("Walkway") as StaticBody3D
	if not check(walkway != null, "the web is something to stand on"):
		return
	check(walkway.collision_layer & GameLayers.WEB_WALK != 0, "on the silk layer")
	check(spider.collision_mask & GameLayers.WEB_WALK != 0, "which the spider collides with")
	check(builder._climb.climbable_layers & GameLayers.WEB_WALK != 0,
		"and can climb about on")

	# ...without being solid to the things it is meant to catch.
	var fly := spawn_fly(centre + Vector3(0, 1.0, 0))
	await physics_frame
	check(walkway.collision_layer & fly.collision_mask == 0,
		"but prey passes straight through it")
	check(mat.catch_area.collision_mask & fly.collision_layer != 0,
		"into the catch volume underneath")

	# And it really does catch something walking over it.
	fly.global_position = mat.to_global(mat.centre_local)
	await physics_frame
	await physics_frame
	check(fly.is_stuck(), "a fly that wandered onto it is caught")
	# Removed rather than drained: draining takes the mat down with it, and the
	# mat is what the rest of this is standing on.
	fly.queue_free()
	await physics_frame

	# The spider can stand on it: drop it on and see it stick.
	spider.climb.release()
	spider.global_position = mat.to_global(mat.centre_local) + Vector3(0, 0.4, 0)
	spider.velocity = Vector3.ZERO
	for i in 40:
		await physics_frame
	check(spider.climb.is_attached(), "the spider settles onto the web")
	check(spider.global_position.y > floor_height,
		"standing on the silk rather than through it (%.2f vs floor %.2f)"
		% [spider.global_position.y, floor_height])
	mat.demolish()
	await physics_frame


func _test_tuning_dials() -> void:
	# An orb web is a tier past a spiderling, and this is about the web.
	grow_to_spin("orb_web")
	select_pattern("orb_web")
	var pattern := builder.current_pattern()
	var tuning := builder.tuning_for(pattern)
	check(tuning.is_default(), "a pattern starts on standard settings")

	# Tension: holding power against durability.
	tuning.tension = WebTuning.STEPS - 1
	var tight := tuning.apply_to(pattern)
	tuning.tension = 0
	var slack := tuning.apply_to(pattern)
	check(tight.hold_strength > pattern.hold_strength, "spun tight, a web holds harder")
	check(tight.durability < pattern.durability, "and tears sooner")
	check(slack.hold_strength < pattern.hold_strength, "spun slack, it holds less")
	check(slack.durability > pattern.durability, "and lasts longer")
	check(is_equal_approx(tight.spin_time, slack.spin_time),
		"tension is free either way — it is purely a trade")
	tuning.tension = WebTuning.NEUTRAL

	# Weight: everything against how long it takes to spin.
	tuning.weight = WebTuning.STEPS - 1
	var heavy := tuning.apply_to(pattern)
	check(heavy.hold_strength > pattern.hold_strength
		and heavy.durability > pattern.durability, "heavy silk is better in every way")
	check(heavy.spin_time > pattern.spin_time,
		"and that is what you pay for: longer before the next one (%.2fx)"
		% heavy.spin_time)
	check(heavy.strand_thickness > pattern.strand_thickness, "you can see the difference")
	tuning.weight = WebTuning.NEUTRAL

	# Mesh: what you catch against what you spend.
	tuning.mesh = WebTuning.STEPS - 1
	var open_mesh := tuning.apply_to(pattern)
	tuning.mesh = 0
	var close_mesh := tuning.apply_to(pattern)
	check(open_mesh.radial_count < close_mesh.radial_count
		and open_mesh.ring_count < close_mesh.ring_count,
		"an open mesh is fewer threads (%d vs %d spokes)"
		% [open_mesh.radial_count, close_mesh.radial_count])
	check(open_mesh.min_catch_size > close_mesh.min_catch_size,
		"so small prey walks through it")
	tuning.mesh = WebTuning.NEUTRAL

	# Fewer threads really does mean less silk, measured off the real geometry.
	var base := spider.global_position + Vector3(3.0, 0.4, -4.0)
	var costs := {}
	for setting in [0, WebTuning.STEPS - 1]:
		tuning.mesh = setting
		builder.start()
		for point in _square(base, 0.6):
			builder.add_anchor(point)
		builder.finish()
		builder.stop()
		await physics_frame
		var web := newest_web("orb_web")
		# Measured off the drawn geometry: a coarse mesh is literally fewer
		# threads, and vertices are what fewer threads look like from here.
		costs[setting] = float(_mesh_verts(web))
		if web != null:
			check(web.tuning != null and web.tuning.mesh == setting,
				"the web remembers the dials it was spun with")
			web.demolish()
		await physics_frame
	var fine: float = costs[0]
	var coarse: float = costs[WebTuning.STEPS - 1]
	check(coarse < fine, "an open mesh really is fewer threads (%.0f vs %.0f verts)"
		% [coarse, fine])
	tuning.mesh = WebTuning.NEUTRAL

	# And the size gate has teeth: a fly ignores a web meshed for bigger things.
	tuning.mesh = WebTuning.STEPS - 1
	builder.start()
	for point in _square(base, 0.6):
		builder.add_anchor(point)
	builder.finish()
	builder.stop()
	await physics_frame
	var coarse_web := newest_web("orb_web") as WebNet
	if check(coarse_web != null, "a coarse web to test the gate on"):
		check(coarse_web.pattern.min_catch_size > 1, "it is meshed for bigger prey")
		var fly := spawn_fly(coarse_web.to_global(coarse_web.centre_local))
		await physics_frame
		await physics_frame
		check(not fly.is_stuck(), "and a fly goes straight through it")
		fly.queue_free()
		coarse_web.demolish()
	builder.reset_dials()
	check(builder.current_tuning().is_default(), "the dials can be put back to standard")
	await physics_frame


func _test_saved_designs() -> void:
	# A snare is two tiers up, and this is about wiring rather than growing.
	grow_to_spin("pressure_snare")
	var base := spider.global_position + Vector3(-5.0, 0.4, 0.0)

	# A two-piece rig: snare plus a tripline wired to it.
	select_pattern("pressure_snare")
	builder.start()
	for point in _square(base, 0.6):
		builder.add_anchor(point)
	builder.finish()
	builder.stop()
	select_pattern("trip_line")
	builder.start()
	builder.add_anchor(base + Vector3(1.6, -0.4, -0.5))
	builder.add_anchor(base + Vector3(1.6, -0.4, 0.5))
	builder.stop()
	await physics_frame

	var snare := newest_web("pressure_snare") as WebNet
	var trip := newest_web("trip_line") as WebStrand
	if not check(snare != null and trip != null, "a rig to keep"):
		return
	check(snare.anchors.size() == 4, "a spun web remembers its anchors")
	check(builder.link_nodes(trip, snare), "wired the rig together")

	# Keep it.
	var design := DesignLibrary.capture(trip, Vector3.FORWARD, spider.growth.stage_index)
	if not check(design != null, "the rig can be captured as a design"):
		return
	check(design.piece_count() == 2, "both webs came along (%d)" % design.piece_count())
	check(design.link_count() == 1, "and so did the wiring")
	check(design.anchors.size() == 6, "every anchor was recorded (%d)" % design.anchors.size())

	check(DesignLibrary.store(design), "the design saves to disk")
	var reloaded := DesignLibrary.load_all()
	var found: WebDesign = null
	for candidate in reloaded:
		if candidate.id == design.id:
			found = candidate
	check(found != null, "and loads back again")
	if found != null:
		check(found.piece_count() == design.piece_count(), "with its pieces intact")
		check(found.link_count() == design.link_count(), "and its wiring intact")

	# Put it down somewhere else.
	builder.designs = reloaded
	for i in builder.designs.size():
		if builder.designs[i].id == design.id:
			builder.design_index = i
	builder.placing_design = true
	builder.aim_valid = true
	builder.aim_point = spider.global_position + Vector3(0, 0.5, -7.0)
	builder.aim_normal = Vector3.UP

	var before_webs := web_count()
	# Aim is recomputed every frame, so remember where this went.
	var placed_at := builder.aim_point
	check(builder.place_design(), "the design can be spun somewhere new")
	await physics_frame
	check(web_count() == before_webs + 2, "both webs went up")

	# The copies must be wired to each other, not back to the original.
	var copies: Array[WebStructure] = []
	for child in webs.get_children():
		var web := child as WebStructure
		if web != null and not web.is_queued_for_deletion() and web != trip and web != snare \
				and web.global_position.distance_to(placed_at) < 6.0:
			copies.append(web)
	var wired_copies := 0
	for web in copies:
		for target in web.links:
			if copies.has(target):
				wired_copies += 1
	check(wired_copies == 1, "the copy is wired to itself, not the original (%d)" % wired_copies)
	check(trip.links.has(snare), "the original rig is untouched")

	# There is no being too poor for one any more, so what is left to check is
	# that a second copy is a second copy: the same design, somewhere else,
	# going up whole rather than borrowing from the first.
	var before_second := web_count()
	builder.aim_valid = true
	builder.aim_point = spider.global_position + Vector3(0, 0.5, -11.0)
	builder.aim_normal = Vector3.UP
	check(builder.place_design(), "the same design goes up again elsewhere")
	await physics_frame
	check(web_count() == before_second + design.piece_count(),
		"whole, with all %d of its pieces" % design.piece_count())

	builder.placing_design = false
	DesignLibrary.forget(design)


func _test_sandbox_wiring() -> void:
	var spawner := level.get_node_or_null("PreySpawner") as PreySpawner
	if check(spawner != null, "the level has a prey spawner"):
		# Clearing the room between sections takes the spawner's stock with
		# everything else, and it refills one creature per respawn_delay — five
		# seconds, which is not worth waiting out three times over. So it is asked
		# to do now what it would do anyway, and then watched doing it.
		spawner._pending = 0.0
		var stocked := await wait_until(
			func() -> bool: return spawner.alive_count() > 0, 120)
		var alive := spawner.alive_count()
		check(stocked, "it stocked %d creature%s" % [alive, "" if alive == 1 else "s"])

		# And not in the player's lap. The world's spawn volume has the player
		# start inside it, so without this a wasp appears within its own hunt
		# range and attacks on arrival — which reads as the wasp being unfair
		# rather than as the spawner being careless.
		spawner.keep_clear = 12.0
		var nearest := INF
		for i in 12:
			var spot: Vector3 = spawner._clear_point(null)
			nearest = minf(nearest, spot.distance_to(spider.global_position))
		check(nearest > spider.stage().body_height * 4.0,
			"and puts them at arm's length or better (nearest of twelve: %.1fm)"
			% nearest)
		check(spawner.stock.size() > 1,
			"from a mixed stock (%d species)" % spawner.stock.size())
	var hud := level.get_node_or_null("HUD") as SpiderHUD
	if check(hud != null, "the level has a HUD"):
		check(hud.stage_label.text.contains(spider.stage().display_name),
			"the HUD is showing the current stage (%s)" % hud.stage_label.text)
		check(hud.web_bar.max_value == 1.0, "and showing when the next web is ready")


func _test_demolish() -> void:
	# Its own, rather than whatever the suite left standing: webs come down with
	# their catch now, so leftovers are not something to count on.
	var web := await _sheet_at(Vector3(90.0, 3.0, 40.0))
	var count := web_count()
	if not check(web != null, "there is a web to pull down"):
		return
	web.demolish()
	await process_frame
	check(web_count() == count - 1, "the web is gone")


## Webs do not pile up for ever either, but the rule is not the lines' rule.
##
## Lines are capped at three because a line is traversal and three is a number
## you hold in your head. Webs are *sites* — one fills up and a full one catches
## nothing, so running several is the play — and capping them at three would be
## arguing with the thing the game asks for. So the cap is higher, and it only
## ever takes down a web that is **empty**: a web you filled is what you went away
## and came back for, and clearing it to make room loses you the catch rather than
## the silk.
##
## Measured before this existed: ten shots at a wall left ten webs standing, which
## is what a wall papered with silk actually was.
func _test_webs_do_not_pile_up() -> void:
	check(WebBuilder.MAX_WEBS > WebBuilder.MAX_LINES,
		"more webs than lines, because they are not the same kind of thing (%d against %d)"
		% [WebBuilder.MAX_WEBS, WebBuilder.MAX_LINES])
	grow_to_spin("orb_web")
	select_pattern("orb_web")
	ignore_shot_cooldown()
	var slab := add_slab(Vector3(560, 0.0, 560), Vector3(30, 0.5, 30))
	var wall := add_slab(Vector3(560, 3.0, 552), Vector3(30, 6.0, 0.6))
	await physics_frame
	stand_on(Vector3(560, 0.4, 560))
	await run_frames(10)
	clear_prey_near(slab.global_position, 40.0, null)
	clear_webs()
	builder._webs.clear()
	await physics_frame

	# Two more than the cap, all of them empty.
	var wanted := WebBuilder.MAX_WEBS + 2
	for i in wanted:
		builder._cooling = 0.0
		aim_at(Vector3(560.0 - 5.0 + 1.4 * float(i), 1.4, 552.5))
		await physics_frame
		builder.shoot()
		await wait_until(func() -> bool: return not builder.shot_in_flight(), 240)
		await run_frames(4)
	check(builder.web_count() <= WebBuilder.MAX_WEBS,
		"%d shots leave %d webs, not %d" % [wanted, builder.web_count(), wanted])
	check(builder.web_count() == WebBuilder.MAX_WEBS,
		"and it is the cap they stop at (%d)" % builder.web_count())

	# But a web with something in it is never the one that goes. The oldest is
	# the one that would be taken, so that is the one to fill.
	var oldest: WebNet = builder._webs[0] as WebNet
	if not check(oldest != null and is_instance_valid(oldest),
			"there is an oldest web to keep"):
		return
	var fly := spawn_fly(oldest.to_global(oldest.centre_local))
	if not check(fly != null, "a fly in it"):
		return
	fly.move_speed = 0.0
	if not check(await wait_until(func() -> bool: return fly.is_stuck(), 180),
			"caught, so the web is a larder now"):
		return
	check(builder._webs[0] == oldest, "still the oldest of them")

	builder._cooling = 0.0
	aim_at(Vector3(560.0 + 6.0, 1.4, 552.5))
	await physics_frame
	builder.shoot()
	await wait_until(func() -> bool: return not builder.shot_in_flight(), 240)
	await run_frames(4)
	check(is_instance_valid(oldest) and not oldest.is_queued_for_deletion(),
		"and it survives the next web going up, because it is holding something")
	check(oldest.snared_count() > 0, "with the fly still in it")
	if is_instance_valid(fly):
		fly.queue_free()


## Three lines at a time, and the fourth takes the oldest down.
##
## This is what replaced the silk budget on lines: a line costs nothing to
## make and everything to keep, so the question is which three you want rather
## than whether you can afford another.
func _test_three_lines() -> void:
	check(WebBuilder.MAX_LINES == 3, "three at a time (%d)" % WebBuilder.MAX_LINES)

	# Start from a known register — the suite has been grappling for a while.
	for strand in builder.lines():
		strand.demolish()
	builder._lines.clear()
	spider.climb.release()
	await physics_frame
	check(builder.line_count() == 0, "starting with none up (%d)" % builder.line_count())

	var base := Vector3(60.0, 4.0, 60.0)
	select_pattern("frame_line")
	var first := _run_a_line(base, base + Vector3(2, 0, 0))
	var second := _run_a_line(base + Vector3(2, 0, 0), base + Vector3(4, 0, 0))
	var third := _run_a_line(base + Vector3(4, 0, 0), base + Vector3(6, 0, 0))
	await physics_frame
	if not check(first != null and second != null and third != null, "three lines go up"):
		return
	check(builder.line_count() == 3, "and all three are counted (%d)" % builder.line_count())

	var fourth := _run_a_line(base + Vector3(6, 0, 0), base + Vector3(8, 0, 0))
	await physics_frame
	await process_frame
	check(fourth != null, "a fourth can still be run")
	check(builder.line_count() == 3, "but there are still three (%d)" % builder.line_count())
	check(not is_instance_valid(first), "because the oldest came down for it")
	check(is_instance_valid(second) and is_instance_valid(third) and is_instance_valid(fourth),
		"and the other three are standing")

	# The one holding you up is never the one that goes. Dropping the player out
	# of the air is the game taking the controls off them.
	spider.climb.clip_on(second, second.point_a.lerp(second.point_b, 0.5))
	var fifth := _run_a_line(base + Vector3(8, 0, 0), base + Vector3(10, 0, 0))
	await physics_frame
	await process_frame
	check(fifth != null, "a fifth while hanging from the oldest")
	check(is_instance_valid(second), "leaves the line you are hanging from alone")
	check(not is_instance_valid(third), "and takes the next oldest instead")
	spider.climb.release()

	for strand in builder.lines():
		strand.demolish()
	builder._lines.clear()
	await physics_frame
	await process_frame


## A web is a larder while it holds something, and nothing once it does not.
func _test_a_web_ends_with_its_catch() -> void:
	var centre := Vector3(70.0, 3.0, 30.0)
	clear_prey_near(centre, 14.0, null)
	var net := await _sheet_at(centre)
	if not check(net != null, "a web to fill and then empty"):
		return

	var at := net.to_global(net.centre_local)
	var one := spawn_fly(at)
	var two := spawn_fly(at + Vector3(0.12, 0.0, 0.12))
	await run_frames(4)
	if not check(one != null and two != null and one.is_stuck() and two.is_stuck(),
			"two flies in it"):
		return
	check(net.snared_count() == 2, "which it is holding (%d)" % net.snared_count())

	one.wrap()
	one.consume()
	await physics_frame
	check(is_instance_valid(net), "taking one out leaves the web up")
	check(net.snared_count() == 1, "still holding the other (%d)" % net.snared_count())

	two.wrap()
	two.consume()
	await physics_frame
	await process_frame
	check(not is_instance_valid(net), "and the last one takes the web with it")

	# Escaping is not harvesting. Something getting away is the web losing, and
	# taking the web as well would be losing twice for one mistake.
	var again := await _sheet_at(centre)
	if not check(again != null, "another web, to lose one out of"):
		return
	var runner := spawn_fly(again.to_global(again.centre_local))
	await run_frames(4)
	if check(runner != null and runner.is_stuck(), "a fly in this one"):
		again.on_prey_escaped(runner)
		await physics_frame
		check(is_instance_valid(again), "one that gets away leaves the web standing")
		check(again.snared_count() == 0, "and empty (%d)" % again.snared_count())
	if is_instance_valid(again):
		again.demolish()
	if is_instance_valid(runner):
		runner.queue_free()
	await physics_frame


## Spins a sheet web round a point, the scripted way.
func _sheet_at(centre: Vector3) -> WebNet:
	select_pattern("sheet_web")
	builder.start()
	for point in _square(centre, 0.7):
		builder.add_anchor(point)
	builder.finish()
	builder.stop()
	await physics_frame
	return newest_web("sheet_web") as WebNet


## Runs a line the way arriving from a grapple does, without the journey.
func _run_a_line(from: Vector3, to: Vector3) -> WebStrand:
	builder._launched_from = from
	# The whole launch, not half of it. This skips place() to put a line exactly
	# where a check wants one, and a launch records whether the spider had hold of
	# anything as well as where it fired from — leave that out and every line here
	# reads as fired in mid-air, which lays nothing.
	builder._launch_anchored = true
	builder._arrive_at(to)
	var up := builder.lines()
	return up[up.size() - 1] if up.size() > 0 else null


## A shot fits its rim to the room, the way the held placer always did.
##
## The bolt is the visual; the web it opens is the placer's geometry. Aligning
## that web to the surface it hit made corners strictly worse than the old
## system, because a web flat against a wall casts all sixteen rim rays parallel
## to that wall and none of them find anything.
func _test_a_shot_fits_a_corner() -> void:
	# An orb web is a tier past a spiderling, and this is about the web.
	grow_to_spin("orb_web")
	select_pattern("orb_web")
	ignore_shot_cooldown()
	# First person, so the bolt leaves along exactly the line being aimed. In
	# third person the cross and the muzzle are apart, and a bolt meant for the
	# wall ahead can arrive at the one beside it instead.
	var was_third := spider.view.third_person
	if was_third:
		spider.view.toggle_mode()
		spider.view.update(spider.stage().body_height)

	# A flat wall first, for the number a corner has to beat.
	var flat_at := Vector3(-140.0, 0.0, -140.0)
	var flat_floor := add_slab(flat_at, Vector3(10, 0.5, 10))
	add_slab(flat_at + Vector3(4.0, 2.0, 0.0), Vector3(0.4, 4.0, 10.0))
	await physics_frame
	stand_on(flat_floor.global_position + Vector3(-1.0, 0.25, 0.0))
	spider.view.face(Vector3.RIGHT)
	spider.view.pitch = 0.0
	await run_frames(4)
	var flat_anchored := await _shoot_and_read_rim()

	# Then an inside corner: walls close on both sides of the one it hits, near
	# enough that a web of this size can actually reach them. A shot is 1.26m
	# across at this tier, so walls four metres out would make this test pass on
	# nothing at all.
	# The side walls go where this spider's shot can actually reach, measured
	# rather than written down. They used to sit a flat metre out, which was
	# inside the reach of whatever size the spider had eaten its way to by the
	# time this ran and outside a smaller one's — so the check quietly stopped
	# testing anything instead of failing. Faces at four fifths of the reach,
	# plus the wall's own half-thickness.
	var side := builder.shot_radius() * 0.8 + 0.2
	var corner_at := Vector3(-170.0, 0.0, -140.0)
	var corner_floor := add_slab(corner_at, Vector3(10, 0.5, 10))
	add_slab(corner_at + Vector3(4.0, 2.0, 0.0), Vector3(0.4, 4.0, 10.0))
	add_slab(corner_at + Vector3(0.0, 2.0, side), Vector3(10, 4.0, 0.4))
	add_slab(corner_at + Vector3(0.0, 2.0, -side), Vector3(10, 4.0, 0.4))
	await physics_frame
	stand_on(corner_floor.global_position + Vector3(-1.0, 0.25, 0.0))
	spider.view.face(Vector3.RIGHT)
	spider.view.pitch = 0.0
	await run_frames(4)
	var corner_anchored := await _shoot_and_read_rim()

	check(corner_anchored > flat_anchored,
		"a shot into a corner finds more to hold on to than one at a flat wall (%d against %d of %d)"
		% [corner_anchored, flat_anchored, WebBuilder.PLACE_SIDES])
	check(corner_anchored > 0,
		"so the web really is fitted to the gap rather than pasted on stone")
	if was_third and not spider.view.third_person:
		spider.view.toggle_mode()


## Fires one and reports how many of the web's corners found something.
func _shoot_and_read_rim() -> int:
	var built: Array[WebStructure] = []
	var catcher := func(web: WebStructure) -> void: built.append(web)
	# Nothing else in the air: shoot() refuses while a bolt is still flying, and
	# the test before this one ends on a tap whose silk is still out there.
	await wait_until(func() -> bool: return not builder.shot_in_flight(), 240)
	builder.web_built.connect(catcher)
	builder._cooling = 0.0
	if not check(builder.shoot(), "a bolt goes off toward the wall"):
		builder.web_built.disconnect(catcher)
		return -1
	await wait_until(func() -> bool: return not built.is_empty(), 240)
	builder.web_built.disconnect(catcher)
	var anchored := builder.place_anchored
	for web in built:
		if is_instance_valid(web):
			web.demolish()
	await physics_frame
	return anchored


## Silk stuck to a wall should look stuck to it.
func _test_silk_sits_on_what_it_sticks_to() -> void:
	# An orb web is a tier past a spiderling, and this is about the web.
	grow_to_spin("orb_web")
	var slab := add_slab(Vector3(200.0, 0.0, 200.0))
	await physics_frame
	var top := slab.global_position.y + 0.25
	stand_on(slab.global_position + Vector3(0, 0.25, 0))
	await process_frame
	select_pattern("frame_line")
	builder._update_aim()

	# Straight down at the slab: the anchor is on it, not hovering over it.
	var lift := builder.aim_point.y - top
	check(lift >= 0.0,
		"an anchor never sinks into the surface it found (%.4fm)" % lift)
	check(lift < 0.05,
		"and sits on it rather than above it (%.4fm off, was a third of a metre)"
		% lift)
	check(lift > 0.0,
		"clear of it by something, so silk does not z-fight the stone (%.4fm)" % lift)

	# The same for a web's rim: a corner stops a strand short, not a hand's width.
	select_pattern("orb_web")
	if check(builder.begin_place(), "a web to measure against the floor"):
		builder.place_radius = clampf(1.0, builder._min_place_radius(),
			builder._max_place_radius())
		builder._update_placement()
		var off := builder.place_centre.y - top
		check(off >= 0.0 and off < 0.08,
			"and a web sits on the floor it was spun against (%.4fm)" % off)
		builder.cancel_place()
	slab.queue_free()
	await physics_frame


# --- helpers ------------------------------------------------------------

func _square(centre: Vector3, half: float) -> Array[Vector3]:
	return [
		centre + Vector3(-half, -half, 0),
		centre + Vector3(half, -half, 0),
		centre + Vector3(half, half, 0),
		centre + Vector3(-half, half, 0),
	]


# --- the bag ------------------------------------------------------------

## Devices are the one thing that isn't silk, so what's tested here is the ways
## they differ from a web: they run out, they come back up, they do something
## silk can't, and they wire into the same network either way round.
func _test_the_bag() -> void:
	var bag := spider.bag
	var placer := spider.device_placer
	placer.notice.connect(func(text: String) -> void: note(text))

	check(bag.kinds.size() >= 3, "loaded %d kinds of device" % bag.kinds.size())
	var venom := bag.kind_by_id("venom_spur")
	var lure := bag.kind_by_id("scent_lure")
	var bell := bag.kind_by_id("signal_bell")
	if not check(venom != null and lure != null and bell != null,
			"venom spur, scent lure and signal bell all exist"):
		return
	check(bag.count(venom) == 2, "starts carrying two venom spurs")
	check(bag.total() == 4, "and four devices in all (%d)" % bag.total())

	# N is a mode of its own, and it takes the mouse off the web builder.
	spider.require_captured_mouse = false
	builder.start()
	send_action(spider.input_device_mode)
	await process_frame
	check(placer.active, "N opens the bag")
	check(not builder.building, "and puts build mode away — one tool at a time")
	send_action(spider.input_device_mode)
	await process_frame
	check(not placer.active, "N closes it again")

	# The wheel walks what you are carrying, not every kind that exists.
	placer.start()
	var first := placer.current_kind()
	placer.cycle(1)
	check(placer.current_kind() != first, "the wheel changes device")
	placer.cycle(-1)
	check(placer.current_kind() == first, "and changes back")

	# A slab of our own to work on, so what's under the crosshair is known
	# rather than whatever the demo level happens to have at that coordinate.
	var slab := add_slab(Vector3(30, 0.0, 30))
	await physics_frame
	stand_on(slab.global_position + Vector3(0, 0.25, 0))
	await process_frame

	# Placing costs a device out of the bag and no silk at all: the bag is the
	# whole limit on them, which is why they are allowed to be better than silk.
	_select_device("venom_spur")
	var carried_before := bag.count(venom)
	var spur := placer.place()
	await physics_frame
	if not check(spur != null, "put a venom spur down"):
		return
	check(bag.count(venom) == carried_before - 1, "it came out of the bag")
	check(spur.is_inside_tree(), "it is in the level")
	check(spur.global_position.distance_to(placer.aim_point) < 1.0,
		"where the crosshair was")

	# Two in the same spot would be a mess, and no use.
	placer._update_aim()
	check(placer.problem == DevicePlacer.Problem.CROWDED,
		"won't stack a second one on top of it")

	# Taking it back up is the whole reason a device isn't a web.
	stand_on(spur.global_position)
	await process_frame
	check(placer.aimed_device() == spur, "looking at it finds it")
	check(placer.pick_up_aimed(), "picked it back up")
	await physics_frame
	await process_frame
	check(bag.count(venom) == carried_before, "and it is back in the bag")
	check(not is_instance_valid(spur) or spur.is_queued_for_deletion(),
		"and gone from the level")

	# Run out and the wheel moves off it rather than sitting on an empty slot.
	stand_on(slab.global_position + Vector3(0, 0.25, 3.0))
	await process_frame
	_select_device("scent_lure")
	var only_lure := placer.place()
	await physics_frame
	if not check(only_lure != null, "put the one scent lure down"):
		return
	check(bag.count(lure) == 0, "that was the last one")
	check(placer.current_kind() != lure, "the wheel moved off the empty slot")
	only_lure.pick_up()
	await physics_frame
	await process_frame

	await _test_venom_kills_what_silk_only_holds(slab)
	await _test_wiring_a_device(slab)
	placer.stop()
	slab.queue_free()


## The point of the venom spur: a dead fly can be drained whatever its size,
## and silk can only ever hold something until you get there.
func _test_venom_kills_what_silk_only_holds(slab: StaticBody3D) -> void:
	var placer := spider.device_placer
	var bag := spider.bag
	stand_on(slab.global_position + Vector3(4.0, 0.25, 0))
	await process_frame

	_select_device("venom_spur")
	var spur := placer.place()
	await physics_frame
	if not check(spur != null, "a venom spur to fire"):
		return

	var fly := spawn_fly(spur.global_position + Vector3(0, 0.3, 0))
	fly.size_class = spider.stage().bite_power + 3
	await physics_frame
	check(not fly.subdued, "a live fly beside it, too big to bite")

	spur.receive_signal(null, 0)
	await physics_frame
	check(fly.subdued, "a signal into the spur kills it")
	check(fly.wrapped, "a dead fly needs no wrapping")
	check(spur.spent, "and the spur is used up")
	check(not spur.can_receive_signal(), "a spent spur does nothing more")

	# Too big to bite, but dead — so drainable. That is the trade the item buys.
	spider.global_position = fly.global_position + Vector3(0, 0.2, 0)
	await physics_frame
	var got: float = await eat(fly, 900)
	check(got > 0.0,
		"drained something bigger than the spider could ever bite (+%.1f)" % got)

	# A spent device still sweeps up, so the level doesn't fill with litter.
	var spur_kind := spur.kind
	var held := bag.count(spur_kind)
	stand_on(spur.global_position)
	await process_frame
	if check(placer.aimed_device() == spur, "the spent spur is still there to sweep up"):
		check(placer.pick_up_aimed(), "swept it up")
		check(bag.count(spur_kind) == held, "and a spent one does not go back in the bag")


## A device is a node on the same signal graph a web is, which is the whole
## reason it is worth having: the tripline you already built sets it off.
func _test_wiring_a_device(slab: StaticBody3D) -> void:
	var at := slab.global_position + Vector3(-4.0, 0.25, 0)
	stand_on(at)
	await process_frame

	_select_device("signal_bell")
	var bell := placer.place()
	await physics_frame
	if not check(bell != null, "a bell to wire up"):
		return

	select_pattern("trip_line")
	builder.start()
	builder.add_anchor(at + Vector3(-0.6, 0.4, 0))
	builder.add_anchor(at + Vector3(0.6, 0.4, 0))
	builder.stop()
	await physics_frame
	var trip := newest_web("trip_line") as WebStrand
	if not check(trip != null, "a tripline to wire it to"):
		return

	check(builder.link_nodes(trip, bell), "a web can be wired to a device")
	check(trip.links.has(bell), "the tripline sets off the bell")

	# The bell reports, so it can be a source as well as a target — that is what
	# lets a rig across the level reach you.
	check(bell.can_signal(), "a bell has something to report")
	var heard := []
	var handle := func(text: String) -> void: heard.append(text)
	spider.notice.connect(handle)
	trip.fire()
	await physics_frame
	spider.notice.disconnect(handle)
	check(heard.size() > 0, "setting the tripline off rings the bell")

	# Wiring is aimed at whatever is under the crosshair, device or web alike.
	stand_on(bell.global_position)
	await process_frame
	check(builder.aimed_node() == bell, "the wiring cursor picks devices up too")

	# Taking a device away takes its wiring with it, rather than leaving a line
	# hanging off nothing. Count the links rather than looking for the bell
	# among them: it has been freed by now, and a freed instance is never found
	# in a typed array, so that version passed whether or not unlinking worked.
	var wired_before := trip.links.size()
	bell.pick_up()
	await physics_frame
	check(trip.links.size() == wired_before - 1,
		"picking the bell up unwires it (%d → %d)" % [wired_before, trip.links.size()])
	trip.queue_free()


func _select_device(id: String) -> void:
	for i in placer._inventory.kinds.size():
		if placer._inventory.kinds[i].id == id:
			placer.kind_index = i
			return
	check(false, "device '%s' exists" % id)


# --- the larder ---------------------------------------------------------

## A web is meant to be somewhere you leave things and come back to. That only
## works if a catch survives you walking away, and if a web can be full — so
## this is about both: what a web keeps, and how much of it.
func _test_the_larder() -> void:
	# Out in open air, well clear of everything else the suite has built, and
	# with a full spool so this measures catching rather than what is left over.
	var centre := Vector3(30, 3, 20)
	select_pattern("sheet_web")
	builder.start()
	for point in _square(centre, 0.7):
		builder.add_anchor(point)
	builder.finish()
	builder.stop()
	await physics_frame
	var net := newest_web("sheet_web") as WebNet
	if not check(net != null, "a sheet web to fill up"):
		return
	check(net.capacity() == 2, "a sheet web holds two (%d)" % net.capacity())
	check(not net.is_full(), "and starts empty")

	# The tuning spine: a web keeps a catch if it can out-hold the whole thrash.
	# A sheet web is meant to be exactly good enough for a fly.
	var at := net.to_global(net.centre_local)
	var first := spawn_fly(at)
	await physics_frame
	await physics_frame
	if not check(first.is_stuck(), "a fly flew into it"):
		return
	var thrash := first.struggle_power * first.struggle_stamina
	check(thrash < net.hold_strength() * Prey.ESCAPE_MARGIN,
		"a fly's whole thrash (%.1f) is inside a sheet web's hold (%.1f)"
		% [thrash, net.hold_strength() * Prey.ESCAPE_MARGIN])
	check(first.is_fighting(), "it is fighting at first — this is when you can lose it")

	# Fast-forward the fight rather than waiting five real seconds through it.
	first._fight_left = 0.15
	var fought_out: bool = await wait_until(
		func() -> bool: return not first.is_fighting(), 120)
	check(fought_out, "it tires itself out")
	check(first.is_stuck(), "and is STILL in the web — this is the whole point")
	check(first.is_secured(), "the web is holding it for you now")
	check(not first.wrapped, "without you having been there to wrap it")

	# A tired catch still pulls, but nothing like a fighting one: the web is a
	# store that wears out slowly, not a countdown.
	var settled_before := net.durability
	await run_frames(20)
	var settled_drain := settled_before - net.durability

	var second := spawn_fly(at)
	await physics_frame
	await physics_frame
	if not check(second.is_stuck(), "a second fly lands in it"):
		return
	var fighting_before := net.durability
	await run_frames(20)
	var fighting_drain := fighting_before - net.durability
	check(fighting_drain > settled_drain,
		"a fighting catch costs the web far more than a settled one (%.4f vs %.4f)"
		% [fighting_drain, settled_drain])

	# Full means full. This is what makes a second site worth walking to.
	check(net.is_full(), "two catches fill a sheet web")
	check(net.status_line().contains("FULL"), "and it says so: %s" % net.status_line())
	var turned_away := spawn_fly(at)
	await physics_frame
	await physics_frame
	check(not turned_away.is_stuck(), "a full web catches nothing more")
	turned_away.queue_free()

	# A catch that stops existing without telling the web must not leave it
	# retired: being full is what stops it catching, so a dead reference would
	# be a web that never works again.
	second.queue_free()
	await physics_frame
	await process_frame
	await physics_frame
	check(not net.is_full(), "a catch vanishing frees the slot back up")
	check(net.snared_count() == 1, "and the web counts what is actually there")

	# Wrapping is now preservation: it stops the catch costing you the web.
	first.wrap()
	await physics_frame
	var wrapped_at := net.durability
	await run_frames(20)
	check(is_equal_approx(net.durability, wrapped_at),
		"wrapping a catch stops it wearing the web at all")

	await _test_a_web_can_lose_a_fight()
	net.demolish()


## The other half of the deal: a catch is only kept if the web was good enough
## for it. Something that out-fights the silk still gets away, and takes a bite
## of the web with it — which is what stops "leave a web anywhere" being free.
func _test_a_web_can_lose_a_fight() -> void:
	var centre := Vector3(30, 3, 26)
	select_pattern("sheet_web")
	builder.start()
	for point in _square(centre, 0.7):
		builder.add_anchor(point)
	builder.finish()
	builder.stop()
	await physics_frame
	var net := newest_web("sheet_web") as WebNet
	if not check(net != null and not net.is_full(), "a fresh web for a real fight"):
		return

	var brute := spawn_fly(net.to_global(net.centre_local))
	brute.species = "Test Brute"
	brute.struggle_power = 40.0
	await physics_frame
	await physics_frame
	if not check(brute.is_stuck(), "something much stronger hits the web"):
		return
	var thrash := brute.struggle_power * brute.struggle_stamina
	check(thrash > net.hold_strength() * Prey.ESCAPE_MARGIN,
		"it out-fights the silk on paper (%.0f vs %.0f)"
		% [thrash, net.hold_strength() * Prey.ESCAPE_MARGIN])

	var before := net.durability
	var escaped: bool = await wait_until(
		func() -> bool: return not brute.is_stuck(), 240)
	check(escaped, "and gets free in practice, inside its stamina")
	# Either it tore loose and left the web worse, or it wrecked the web on the
	# way out. Both are the web losing, which is the thing being asserted.
	if is_instance_valid(net) and not net.is_queued_for_deletion():
		check(net.durability < before, "and the fight cost the web")
	else:
		check(true, "and took the whole web with it")
	brute.queue_free()


## Anything dead is food. A carcass is drunk where it lies and dragged home like a
## bundle — but something else took it down, so it is never a hard kill.
func _test_carrion() -> void:
	var slab := add_slab(Vector3(-60, 0.0, 140))
	await physics_frame
	stand_on(slab.global_position + Vector3(0, 0.25, 0))
	await process_frame
	clear_prey_near(spider.global_position, 6.0, null)
	var wasp := spawn("wasp", spider.global_position + Vector3(0.3, 0.1, 0.0))
	if not check(wasp != null, "a wasp"):
		return
	wasp.aggression = 0.0
	await physics_frame
	wasp.die()
	await run_frames(20)
	check(wasp.is_dead(), "dead")
	check(spider.tether.can_carry(wasp), "dead, it can be dragged home like a bundle")
	check(builder.shot_target() != wasp, "and silk is not thrown at it")
	Input.action_press("interact")
	spider.jaws.handle(wasp)
	var started: bool = spider.feeding == wasp
	var past: int = spider.jaws._past
	Input.action_release("interact")
	spider.jaws.stop()
	check(started, "it is drunk where it lies, past a spiderling's bite as it is")
	check(past == 0, "but it was taken down by something else: no hard kill (%d)" % past)
	var got: float = await eat(wasp, 900)
	check(got > 0.0, "a meal all the same (+%.1f)" % got)


## Anything you can hold, you can eat. Size used to refuse a meal outright — too
## big, grow first — and now it only decides how you get hold of one: something
## past your bite has to be beaten by the silk before it is yours.
func _test_anything_you_can_hold() -> void:
	# Beside the spider, so what the web catches can be drunk where it hangs.
	var centre := spider.global_position + Vector3(0.0, 1.2, 1.5)
	select_pattern("sheet_web")
	builder.start()
	for point in _square(centre, 0.7):
		builder.add_anchor(point)
	builder.finish()
	builder.stop()
	await physics_frame
	var net := newest_web("sheet_web") as WebNet
	if not check(net != null and not net.is_full(), "a spiderling's sheet web"):
		return
	clear_prey_near(centre, 6.0, null)
	var bite := spider.stage().bite_power

	# Loose, it is out of reach of bare fangs, as it always was.
	var loose := spawn("wasp", spider.global_position + Vector3(0.4, 0.3, 0.0))
	if not check(loose != null, "a wasp on the loose"):
		return
	loose.move_speed = 0.0
	loose.aggression = 0.0
	check(loose.size_class > bite,
		"which is past a spiderling's bite (%d against %d)" % [loose.size_class, bite])
	spider.jaws.handle(loose)
	check(spider.feeding == null and not loose.wrapped, "loose, it is not a meal")
	# Bundled — by silk that could take it — it is, however big.
	loose.bundle()
	await physics_frame
	Input.action_press("interact")
	spider.jaws.handle(loose)
	var started: bool = spider.feeding == loose
	Input.action_release("interact")
	spider.jaws.stop()
	check(started, "bundled, the same wasp is dinner — nothing says grow first")
	loose.queue_free()

	# In a web it has to lose the fight first. One that tires before it can tear
	# the silk is a fight the web wins.
	var wasp := spawn("wasp", net.to_global(net.centre_local))
	if not check(wasp != null, "a wasp for the web"):
		return
	wasp.aggression = 0.0
	wasp.struggle_stamina = 0.4
	await physics_frame
	await physics_frame
	if not check(wasp.is_stuck() and wasp.is_fighting(), "it flies in and fights"):
		return
	spider.jaws.handle(wasp)
	check(not wasp.wrapped and spider.feeding == null,
		"and while it fights it cannot be wrapped")

	var tired: bool = await wait_until(func() -> bool: return wasp.is_secured(), 120)
	if not check(tired, "the web holds it until it has fought itself out"):
		return
	spider.jaws.handle(wasp)
	check(wasp.wrapped, "then a spiderling can wrap a wasp")
	var got: float = await eat(wasp, 900)
	check(got > 0.0 and (not is_instance_valid(wasp) or wasp.eaten),
		"and drink the whole of it (+%.1f)" % got)


## Runs physics until [param test] passes, or gives up. Returns whether it
## passed, so a test can say "this happened" rather than "this took N frames".
# --- spinning a web where you point -------------------------------------

## The main way a web gets made. Aim, hold, let go — no ring to have built
## first, and no area to have enclosed by accident.
func _test_placing_a_web() -> void:
	# An orb web is a tier past a spiderling, and this is about the web.
	grow_to_spin("orb_web")
	var slab := add_slab(Vector3(-30, 0.0, 30))
	await physics_frame
	stand_on(slab.global_position + Vector3(0, 0.25, 0))
	await process_frame

	select_pattern("orb_web")
	var before := web_count()
	check(builder.begin_place(), "Q starts spinning a web")
	check(builder.placing, "and it grows while held")
	check(builder.place_valid, "with somewhere to put it")
	var smallest := builder.place_radius

	# Holding is the only size control there is.
	await run_frames(30)
	check(builder.place_radius > smallest,
		"holding makes it bigger (%.2fm -> %.2fm)" % [smallest, builder.place_radius])
	var held := builder.place_radius

	var rim := builder.place_rim()
	check(rim.size() >= 3, "it has a rim to spin round (%d corners)" % rim.size())
	var facing := builder.place_normal.dot(-spider.view.aim_forward())
	check(facing > 0.9, "and it faces the player (%.2f)" % facing)

	# Catch the web it actually spins rather than searching for one afterwards:
	# an earlier test left orb webs about, and searching found one of those and
	# then cheerfully measured it when this placement had in fact failed.
	var spun: Array[WebStructure] = []
	var catcher := func(built: WebStructure) -> void: spun.append(built)
	builder.web_built.connect(catcher)
	check(builder.commit_place(), "letting go spins it")
	builder.web_built.disconnect(catcher)
	check(not builder.placing, "and stops the growing")
	await physics_frame
	if not check(spun.size() == 1, "exactly one web came out of it (%d)" % spun.size()):
		return
	var web := spun[0] as WebNet
	if not check(web != null and web.pattern.id == "orb_web",
			"and it is the pattern that was selected"):
		return
	check(web.global_position.distance_to(builder.place_centre) < held * 2.0,
		"it sits where the ghost was")
	check(web.radius > 0.0, "with real size to it (%.2fm)" % web.radius)
	check(web.catch_area != null, "and something to catch with")

	# Web size is what growing buys now, so the ceiling moves with the tier
	# rather than being a flat number.
	var ceiling := builder._max_place_radius()
	check(is_equal_approx(ceiling, spider.stage().max_strand_length * 0.5),
		"the biggest web a tier can spin comes from the tier (%.2fm)" % ceiling)
	check(builder._min_place_radius() < ceiling, "and the smallest is smaller")
	check(builder.place_radius <= ceiling + 0.001,
		"and nothing grew past it (%.2fm)" % builder.place_radius)

	# The tier's reach is now the only ceiling, so held long enough it goes all
	# the way there and then stops rather than being refused at the end.
	check(builder.begin_place(), "spinning one and holding it")
	await run_frames(120)
	var full_radius := builder.place_radius
	check(builder.place_capped, "growth stops at the tier's own reach")
	builder.cancel_place()
	check(full_radius > ceiling - 0.05,
		"having grown all the way to it (%.2fm)" % full_radius)

	# Drive it through the input system as well. Calling begin_place() straight
	# is how this shipped broken: the wheel sat on a strand, so the real key
	# refused every single press while the test never went near a key.
	select_pattern("orb_web")
	var count_before := web_count()
	send_action(spider.input_build_mode)
	await process_frame
	check(builder.placing, "the Q key itself starts it")
	await run_frames(20)
	release_action(spider.input_build_mode)
	await process_frame
	await physics_frame
	check(not builder.placing, "and letting the key go finishes it")
	check(web_count() == count_before + 1,
		"leaving a web behind (%d -> %d)" % [count_before, web_count()])

	# A line is grappled across a gap, not spun in mid-air.
	select_pattern("trip_line")
	check(not builder.begin_place(), "a tripline refuses to be spun as a web")
	builder.cancel_place()
	_select_first_spinnable_again()

	web.demolish()
	slab.queue_free()
	await physics_frame
	await process_frame


# --- webs take the shape of the space -----------------------------------

## Holding the key says how far a web is *allowed* to reach; the room decides
## where it actually stops. The same press should give a full circle in open
## air and something that fills the gap when there is a gap to fill.
func _test_a_web_fits_the_space() -> void:
	# An orb web is a tier past a spiderling, and this is about the web.
	grow_to_spin("orb_web")
	select_pattern("orb_web")

	# Open air: a slab to stand on and nothing beside it.
	var open_slab := add_slab(Vector3(-60, 0.0, -60))
	await physics_frame
	stand_on(open_slab.global_position + Vector3(0, 0.25, 0))
	# Straight down at the floor, set rather than inherited. Two things have to be
	# true for "open air" to mean anything: the crosshair needs a surface under it
	# or there is no placement at all, and the web's plane has to end up parallel
	# to the floor or its own rim rays find the floor. Looking down does both. This
	# used to ride on whatever the previous test happened to leave the camera
	# pointing at, which is not something a check should depend on.
	spider.view.face(Vector3(0, 0, -1))
	spider.view.pitch = -PI / 2.0
	await process_frame
	await run_frames(4)
	if not check(builder.begin_place(), "spinning one in the open"):
		return
	# Pin the reach rather than growing to it. Growth accumulates delta in
	# _process, and idle frames do not interleave with physics frames the same
	# way twice, so two timed presses are never bit-for-bit the same size —
	# and this test is about what the room does with a reach, not about growth.
	var reach: float = clampf(2.0, builder._min_place_radius(), builder._max_place_radius())
	builder.place_radius = reach
	builder._update_placement()
	var open_area := builder.place_area
	check(builder.place_anchored == 0,
		"in open air nothing catches the edges (%d of %d)"
		% [builder.place_anchored, WebBuilder.PLACE_SIDES])
	check(open_area > 0.0, "and it covers a plain %.2f m2" % open_area)
	builder.cancel_place()

	# A slot: two walls close either side, looking along it at the end.
	var floor_at := Vector3(-90, 0.0, -60)
	var slot_floor := add_slab(floor_at, Vector3(10, 0.5, 10))
	add_slab(floor_at + Vector3(0, 2.0, -0.9), Vector3(10, 4.0, 0.4))
	add_slab(floor_at + Vector3(0, 2.0, 0.9), Vector3(10, 4.0, 0.4))
	add_slab(floor_at + Vector3(4.0, 2.0, 0), Vector3(0.4, 4.0, 4.0))
	await physics_frame
	stand_on(slot_floor.global_position + Vector3(-2.0, 0.25, 0))
	spider.view.face(Vector3.RIGHT)
	spider.view.pitch = 0.0
	await process_frame
	await run_frames(4)

	if not check(builder.begin_place(), "spinning one down the slot"):
		return
	builder.place_radius = reach
	builder._update_placement()
	check(is_equal_approx(builder.place_radius, reach),
		"the very same reach is allowed here (%.2fm)" % builder.place_radius)
	check(builder.place_anchored > 0,
		"but here the edges find the walls (%d of %d)"
		% [builder.place_anchored, WebBuilder.PLACE_SIDES])
	check(builder.place_area < open_area,
		"so the web covers less than open air would (%.2f vs %.2f m2)"
		% [builder.place_area, open_area])

	var rim := builder.place_rim()
	var nearest := INF
	var furthest := 0.0
	for point in rim:
		var span := builder.place_centre.distance_to(point)
		nearest = minf(nearest, span)
		furthest = maxf(furthest, span)
	check(furthest <= builder.place_radius + 0.01,
		"no corner reaches past what was held (%.2f of %.2f)"
		% [furthest, builder.place_radius])

	# Silk has thickness, so a corner sitting exactly on the wall buries half
	# of itself in it. Every anchored corner should stop just shy.
	var space := spider.get_world_3d().direct_space_state
	var buried := 0
	for point in rim:
		var probe := PhysicsRayQueryParameters3D.create(builder.place_centre, point,
			GameLayers.WORLD)
		if not space.intersect_ray(probe).is_empty():
			buried += 1
	check(buried == 0,
		"and no corner is inside the wall it found (%d of %d)" % [buried, rim.size()])
	check(nearest < furthest * 0.9,
		"and the shape is genuinely the gap, not a disc (%.2f to %.2f)"
		% [nearest, furthest])
	builder.cancel_place()

	open_slab.queue_free()
	await physics_frame
	await process_frame


# --- catching something by spinning a web over it ------------------------

## The other half of what webs are for. A web is somewhere you leave a trap,
## and it is also something you throw over a thing that is right there — and
## the second only works if a new web catches what is already inside it, since
## a catch volume otherwise only ever hears about arrivals.
func _test_spitting_a_web_at_something() -> void:
	# An orb web is a tier past a spiderling, and this is about the web.
	grow_to_spin("orb_web")
	var before := web_count()
	var slab := add_slab(Vector3(-120, 0.0, -60))
	await physics_frame
	stand_on(slab.global_position + Vector3(0, 0.25, 0))
	await process_frame
	clear_prey_near(slab.global_position, 12.0, null)
	await physics_frame
	await process_frame

	# A fly sitting still, between the spider and the floor it is aiming at:
	# halfway down the line of sight. It was put a fixed height over the floor,
	# which is over the spider's own eye at this size — so whether it was in the
	# way came down to which way it drifted in two frames, and that came down to
	# whatever ran before.
	builder._update_placement()
	if not check(builder.place_valid, "somewhere to spin one"):
		return
	var floor_y := builder.aim_point.y
	var sitting := spawn_fly(builder.aim_point.lerp(spider.view.aim_origin(), 0.5))
	await physics_frame
	await physics_frame
	check(not sitting.is_stuck(), "a fly minding its own business")

	# Aiming down at the floor with a fly hanging in the way: the throw should
	# lock onto the fly rather than the floor a foot behind it.
	builder._update_placement()
	check(builder.place_target == sitting,
		"the throw picks out the fly, not the floor behind it")
	check(builder.place_centre.distance_to(sitting.global_position) < 0.01,
		"and centres on it (%.3fm off)"
		% builder.place_centre.distance_to(sitting.global_position))

	select_pattern("orb_web")
	if not check(builder.begin_place(), "spinning one straight onto it"):
		return
	builder.place_radius = clampf(1.6, builder._min_place_radius(),
		builder._max_place_radius())
	builder._update_placement()
	var spun: Array[WebStructure] = []
	var catcher := func(built: WebStructure) -> void: spun.append(built)
	builder.web_built.connect(catcher)
	var made := builder.commit_place()
	builder.web_built.disconnect(catcher)
	if not check(made and spun.size() == 1, "the web goes up"):
		return

	# Taken on the spot, not on the next frame something happens to move.
	var net := spun[0] as WebNet
	check(net.bundled_on_arrival == 1,
		"the web wraps it the moment it exists (%d)" % net.bundled_on_arrival)
	check(sitting.wrapped, "the fly is wrapped in the silk")
	check(sitting.is_bundled(), "and out of the web rather than hanging in it")
	check(not sitting.is_fighting(), "with no fight left to put up")
	check(net.snared_count() == 0,
		"so the web is not holding it (%d)" % net.snared_count())
	check(net.caught_on_arrival == 1,
		"and it reads as a catch (%d)" % net.caught_on_arrival)

	# The silk went round the fly, so there is no web left hanging on the wall.
	await physics_frame
	await process_frame
	check(not is_instance_valid(net) or net.is_queued_for_deletion(),
		"and the web goes with it rather than sitting there empty")
	check(web_count() == before,
		"leaving nothing standing (%d, started %d)" % [web_count(), before])

	# It has to come down, and come down to the floor — a bundle is dead weight
	# whether or not the thing inside it could fly, and it must not come to
	# rest on the silk it was caught with.
	var dropped_from := sitting.global_position.y
	await wait_until(func() -> bool: return sitting.is_on_floor(), 240)
	var rest := sitting.global_position.y
	check(rest < dropped_from - 0.05,
		"the bundle falls (%.2f -> %.2f)" % [dropped_from, rest])
	check(rest < floor_y + 0.25,
		"all the way to the ground (%.2f, floor at %.2f)" % [rest, floor_y])
	check(sitting.is_on_floor(), "and is standing on it")
	# Nothing may take it back: a bundle lands inside the catch volume of
	# whatever wrapped it, and a thing already wrapped is not catch.
	check(not sitting.can_be_snared(), "and no web will take it back")
	check(sitting.is_bundled(), "so it is still a bundle, not stuck again")

	# And is simply there to be drained off the floor. Which takes a few seconds
	# now, like every other meal.
	var fed: float = await eat(sitting, 900)
	check(fed > 0.0, "a bundle on the floor is drainable (+%.1f)" % fed)

	# The silk still has to be up to it: one that out-fights the web is caught
	# the ordinary way and has to be held, exactly as if it had flown in — and
	# a web that only holds rather than wraps is a web that stays up.
	stand_on(slab.global_position + Vector3(2.5, 0.25, 0))
	await process_frame
	if not check(builder.begin_place(), "a second throw, at something tougher"):
		return
	builder.place_radius = clampf(1.6, builder._min_place_radius(),
		builder._max_place_radius())
	builder._update_placement()
	var brute := spawn_fly(builder.place_centre)
	brute.species = "Test Brute"
	brute.struggle_power = 40.0
	brute.flying = false
	await physics_frame
	await physics_frame

	var standing := web_count()
	var tough: Array[WebStructure] = []
	var second := func(built: WebStructure) -> void: tough.append(built)
	builder.web_built.connect(second)
	builder.commit_place()
	builder.web_built.disconnect(second)
	await physics_frame
	if not check(tough.size() == 1, "the second web goes up"):
		return
	var held := tough[0] as WebNet
	check(brute.total_thrash() > held.hold_strength() * Prey.ESCAPE_MARGIN,
		"it out-fights the silk (%.0f vs %.0f)"
		% [brute.total_thrash(), held.hold_strength() * Prey.ESCAPE_MARGIN])
	check(held.bundled_on_arrival == 0, "so it is not wrapped outright")
	check(brute.is_stuck() and not brute.is_bundled(),
		"it hangs in the web and has to be fought for")
	check(web_count() == standing + 1,
		"and that web stays up, because it is still holding something")

	brute.queue_free()
	held.demolish()
	slab.queue_free()
	await physics_frame
	await process_frame


# --- throwing a bolt of silk --------------------------------------------

## The other way of making a web, kept behind a toggle while the two are being
## compared. A bolt leaves the spider, travels, and opens out where it lands —
## so it can miss, it can be led onto something moving, and the web does not
## exist until it gets there. All three of those are what make it different
## from putting the web straight down under the crosshair.
func _test_throwing_a_bolt() -> void:
	# An orb web is a tier past a spiderling, and this is about the web.
	grow_to_spin("orb_web")
	var slab := add_slab(Vector3(90, 0.0, -90))
	await physics_frame
	stand_on(slab.global_position + Vector3(0, 0.25, 0))
	await process_frame
	clear_prey_near(slab.global_position, 16.0, null)
	await physics_frame
	select_pattern("orb_web")

	check(not builder.throwing, "webs go down where you point to start with")
	builder.toggle_throwing()
	check(builder.throwing, "and the toggle switches to throwing them")
	check(builder.throw_name().contains("thrown"),
		"which the readout says out loud (%s)" % builder.throw_name())

	if not check(builder.begin_place(), "winding one up to throw"):
		builder.toggle_throwing()
		return
	builder.place_radius = clampf(1.2, builder._min_place_radius(),
		builder._max_place_radius())
	builder._update_placement()
	var aimed_at := builder.aim_point

	var thrown: Array[WebStructure] = []
	var catcher := func(built: WebStructure) -> void: thrown.append(built)
	builder.web_built.connect(catcher)

	var standing := web_count()
	check(builder.commit_place(), "letting go throws it")
	check(builder.shot_in_flight(), "and puts a bolt in the air")
	check(thrown.is_empty(), "with no web yet — the silk has to get there first")
	check(true,
		"and nothing paid for while it is still flying")
	check(web_count() == standing, "nothing standing yet either")

	var arrived := await wait_until(func() -> bool: return not thrown.is_empty(), 240)
	builder.web_built.disconnect(catcher)
	if not check(arrived and thrown.size() == 1,
			"the bolt opens out into a web (%d)" % thrown.size()):
		builder.toggle_throwing()
		return
	check(not builder.shot_in_flight(), "and the bolt itself is gone")

	var web := thrown[0] as WebNet
	if not check(web != null, "and it is a net, like the pattern asked for"):
		builder.toggle_throwing()
		return
	check(web.global_position.distance_to(aimed_at) < 1.5,
		"near where it was aimed (%.2fm off)"
		% web.global_position.distance_to(aimed_at))
	check(web.radius > 0.0, "with real size to it (%.2fm)" % web.radius)
	check(web_count() == standing + 1, "and it is standing there")
	web.demolish()
	await physics_frame

	# Leading a fly: the bolt takes time to arrive, so the catch happens where
	# the fly is when the silk gets there, not where the crosshair was.
	builder._update_placement()
	# Squarely on the line of sight and clear of both the spider above it and
	# the slab below, so "did the bolt hit it" is about the bolt rather than
	# about where a guessed offset happened to put the fly.
	var muzzle := spider.view.aim_origin()
	var floor_point := builder.aim_point
	var sitting := spawn_fly(floor_point + (muzzle - floor_point).normalized() * 0.3)
	await physics_frame
	await physics_frame
	check(not sitting.is_stuck(), "a fly in the way of the next one")
	builder._update_placement()
	check(builder.place_target == sitting, "and the crosshair is on it")

	if not check(builder.begin_place(), "winding up a throw at it"):
		builder.toggle_throwing()
		return
	builder.place_radius = clampf(1.4, builder._min_place_radius(),
		builder._max_place_radius())
	# Read what the web arrived with inside the signal rather than afterwards. A
	# throw that wraps everything frees the web on the spot, and casting a freed
	# object a frame later is an error that takes the rest of the test with it.
	# Boxed in an array because a lambda captures locals by value, so a plain
	# int assigned in here would never be seen out there.
	var at_fly: Array[WebStructure] = []
	var wrapped_on_arrival: Array[int] = [-1]
	var second := func(built: WebStructure) -> void:
		at_fly.append(built)
		var net := built as WebNet
		wrapped_on_arrival[0] = net.bundled_on_arrival if net != null else -1
	builder.web_built.connect(second)
	var before_fly := web_count()
	check(builder.commit_place(), "and throwing it")
	var hit := await wait_until(func() -> bool: return not at_fly.is_empty(), 240)
	builder.web_built.disconnect(second)
	# Only ever the size of it: the one inside has been freed by now.
	if not check(hit and at_fly.size() == 1,
			"the bolt reaches the fly (%d)" % at_fly.size()):
		builder.toggle_throwing()
		return

	check(wrapped_on_arrival[0] == 1,
		"and wraps it on arrival (%d)" % wrapped_on_arrival[0])
	check(sitting.wrapped and sitting.is_bundled(),
		"the fly is a bundle rather than stuck in a web")
	await physics_frame
	await process_frame
	check(web_count() == before_fly,
		"and the silk goes with it, leaving nothing hanging (%d, started %d)"
		% [web_count(), before_fly])

	# And back to putting them down where you point.
	builder.toggle_throwing()
	check(not builder.throwing, "the toggle goes back the other way")
	check(builder.throw_name().contains("placed"),
		"and says so (%s)" % builder.throw_name())
	stand_on(slab.global_position + Vector3(2.0, 0.25, 0))
	await process_frame
	var placed: Array[WebStructure] = []
	var third := func(built: WebStructure) -> void: placed.append(built)
	builder.web_built.connect(third)
	check(builder.begin_place(), "one more, the old way")
	builder.place_radius = clampf(1.2, builder._min_place_radius(),
		builder._max_place_radius())
	builder.commit_place()
	builder.web_built.disconnect(third)
	check(placed.size() == 1, "which goes up on the spot, with nothing in flight")
	check(not builder.shot_in_flight(), "because nothing was thrown")
	if placed.size() == 1:
		placed[0].demolish()

	sitting.queue_free()
	slab.queue_free()
	await physics_frame
	await process_frame


# --- what there is to catch ---------------------------------------------

## Creatures are resources, and the point of having several is that they are
## not interchangeable. What is checked here is the ladder the escape margin
## claims to define — a sheet web keeps a fly, an orb web keeps a moth, a
## pressure snare keeps a wasp — because if that is not true then every web in
## the game is the same web and none of the choosing matters.
func _test_species() -> void:
	var all := PreyLibrary.load_species()
	check(all.size() >= 5, "the game has creatures in it (%d)" % all.size())
	var ids: Array[String] = []
	for kind in all:
		ids.append(kind.id)
	check(ids.has("midge") and ids.has("fly") and ids.has("moth")
		and ids.has("beetle") and ids.has("wasp"),
		"five of them, smallest first: %s" % ", ".join(ids))

	var midge := PreyLibrary.find("midge")
	var fly := PreyLibrary.find("fly")
	var moth := PreyLibrary.find("moth")
	var beetle := PreyLibrary.find("beetle")
	var wasp := PreyLibrary.find("wasp")
	if not check(midge != null and fly != null and moth != null
			and beetle != null and wasp != null, "all five load"):
		return

	# They have to fight differently, or the hold strengths decide nothing.
	check(midge.total_thrash() < fly.total_thrash()
		and fly.total_thrash() < moth.total_thrash()
		and moth.total_thrash() < beetle.total_thrash()
		and beetle.total_thrash() < wasp.total_thrash(),
		"each fights harder than the last (%.1f, %.1f, %.1f, %.1f, %.1f)"
		% [midge.total_thrash(), fly.total_thrash(), moth.total_thrash(),
			beetle.total_thrash(), wasp.total_thrash()])
	check(beetle.size_class > fly.size_class,
		"and a beetle is bigger than a fly (%d vs %d)"
		% [beetle.size_class, fly.size_class])
	check(not beetle.flying and moth.flying,
		"a beetle walks and a moth flies, so they are caught in different places")
	check(moth.wander_height.x > fly.wander_height.x,
		"and the moth lives higher up (%.1fm vs %.1fm)"
		% [moth.wander_height.x, fly.wander_height.x])
	check(wasp.lure_susceptibility < fly.lure_susceptibility,
		"a wasp will not come to a lure the way a fly will (%.2f vs %.2f)"
		% [wasp.lure_susceptibility, fly.lure_susceptibility])

	# The ladder, measured against real patterns. At a stated silk quality
	# rather than whatever the spider happens to be: growth is *supposed* to
	# move every one of these lines, so reading the live stage would make this
	# a test of how much the earlier tests fed the spider.
	var mid := 1.8
	var sheet := _hold_of("sheet_web", mid)
	var orb := _hold_of("orb_web", mid)
	var snare := _hold_of("pressure_snare", mid)
	check(sheet > 0.0 and orb > sheet and snare > orb,
		"the webs hold in order too (%.1f, %.1f, %.1f)" % [sheet, orb, snare])
	check(fly.total_thrash() <= sheet and moth.total_thrash() > sheet,
		"a sheet web keeps a fly and loses a moth (%.1f, %.1f, holds %.1f)"
		% [fly.total_thrash(), moth.total_thrash(), sheet])
	check(beetle.total_thrash() <= orb and wasp.total_thrash() > orb,
		"an orb web keeps a beetle and loses a wasp (%.1f, %.1f, holds %.1f)"
		% [beetle.total_thrash(), wasp.total_thrash(), orb])
	check(wasp.total_thrash() <= snare,
		"and a pressure snare keeps the wasp (%.1f, holds %.1f)"
		% [wasp.total_thrash(), snare])

	# And growing is supposed to move the lines, not just the numbers: better
	# silk should turn the web that lost a moth into the web that keeps one.
	var grown := _hold_of("sheet_web", mid * 2.0)
	check(moth.total_thrash() <= grown,
		"better silk turns the sheet web into one that keeps a moth (holds %.1f)"
		% grown)

	# Mesh is a dial rather than something baked into a pattern, so what a
	# species says about it is what it is worth catching in a web spun coarse.
	# The midge earns its place by being the cheap common thing that fills a
	# web you left out, not by being hard to catch.
	check(midge.spawn_weight > wasp.spawn_weight,
		"midges are what you mostly get (%.1f against a wasp's %.1f)"
		% [midge.spawn_weight, wasp.spawn_weight])
	check(midge.biomass < fly.biomass and wasp.biomass > moth.biomass,
		"and worth the least, while the hard ones are worth the most (%d, %d, %d)"
		% [midge.biomass, moth.biomass, wasp.biomass])

	# And one of them, in the world, built from nothing but its resource.
	var slab := add_slab(Vector3(-90, 0.0, 90))
	await physics_frame
	clear_prey_near(slab.global_position, 16.0, null)
	await physics_frame
	var one := spawn("wasp", slab.global_position + Vector3(0, 1.2, 0))
	await physics_frame
	if check(one != null, "a wasp can be put in the world"):
		check(one.species == "Wasp", "it knows what it is (%s)" % one.species)
		check(is_equal_approx(one.total_thrash(), wasp.total_thrash()),
			"and fights like the resource says (%.1f)" % one.total_thrash())
		check(one.get_node_or_null("Body") != null,
			"with a body built from the species, not from a scene per creature")
		check(one.get_node_or_null("Hitbox") != null, "and something to hit")
		one.queue_free()

	# A walker gets no wings, which is the visible half of "caught elsewhere".
	var walker := spawn("beetle", slab.global_position + Vector3(1.5, 0.6, 0))
	await physics_frame
	if check(walker != null, "and so can a beetle"):
		check(walker.get_node_or_null("WingLeft") == null,
			"which has no wings, because it does not fly")
		walker.queue_free()

	slab.queue_free()
	await physics_frame
	await process_frame


## The rats, wolves and fish live somewhere, and only turn up there. The insects turn
## up anywhere, so a spawner left to choose — this room's — draws them and nothing
## else, however many other species there are.
##
## And the ones that swim stay in the water: a fish steering at a lure on the bank,
## or at a spider on a boat, follows along underneath.
func _test_creatures_that_live_somewhere() -> void:
	var placed := 0
	var anywhere := PreyLibrary.ordinary_mix()
	for kind in PreyLibrary.load_species():
		if not kind.habitat.is_empty():
			placed += 1
			check(not anywhere.has(kind), "%s lives in the %s and nowhere else"
				% [_one(kind.id), kind.habitat])
	check(placed >= 9, "the creatures that live somewhere say where (%d)" % placed)
	var spawner := level.get_node_or_null("PreySpawner") as PreySpawner
	if check(spawner != null, "this room has a spawner that chose its own stock"):
		var strays: Array[String] = []
		for kind in spawner.stock:
			if not kind.habitat.is_empty():
				strays.append(kind.id)
		check(strays.is_empty() and spawner.stock.size() == anywhere.size(),
			"and it stocked the insects and nothing else (%d species, %s)"
			% [spawner.stock.size(), "none from elsewhere" if strays.is_empty()
				else ", ".join(strays)])
	for id in ["fish", "octopus", "shark"]:
		var kind := PreyLibrary.find(id)
		check(kind != null and kind.flying and kind.swims, "%s swims" % _one(id))

	# A pond, well away from everything, and a fish in it steering at the sky.
	var at := Vector3(-200.0, 0.0, 260.0)
	var bed := add_slab(at + Vector3(0.0, -12.0, 0.0), Vector3(60.0, 1.0, 60.0))
	var pond := WorldKit.water(level, "TestPond", Vector3(60.0, 10.0, 60.0),
		WorldKit.at(at + Vector3(0.0, -6.5, 0.0)), "pond")
	await physics_frame
	await physics_frame
	var top := Prey.water_top_at(pond, at + Vector3(0.0, -5.0, 0.0))
	check(is_equal_approx(top, at.y - 1.5), "the pond's top is where it was built (%.2f)" % top)
	var fish := spawn("fish", at + Vector3(0.0, -6.0, 0.0))
	await physics_frame
	if check(fish != null, "there is a fish to put in it"):
		var highest := -INF
		for i in 180:
			if i % 30 == 0:
				fish._target = at + Vector3(randf_range(-8.0, 8.0), 20.0, randf_range(-8.0, 8.0))
			await physics_frame
			highest = maxf(highest, fish.global_position.y + fish.hit_radius())
		check(highest <= top + 0.01,
			"steering at the sky, it keeps all of itself under the surface (top of it %.2f, water %.2f)"
			% [highest, top])
		fish.queue_free()

	# Something big is put down on its feet, not buried to the shoulders in the floor.
	var boar := PreyLibrary.find("boar")
	var wallow := PreySpawner.new()
	var boars: Array[PreySpecies] = [boar]
	wallow.stock = boars
	wallow.population = 0
	wallow.spawn_extents = Vector3(4.0, 2.0, 4.0)
	level.add_child(wallow)
	wallow.global_position = bed.global_position + Vector3(0.0, 2.0, 0.0)
	await physics_frame
	if check(boar != null, "there is a boar to put down"):
		var lowest := INF
		for i in 8:
			lowest = minf(lowest, wallow._random_point(boar).y)
		var ground := bed.global_position.y + 0.5
		check(lowest - ground >= boar.body_radius * Prey.HITBOX_SCALE - 0.01,
			"a boar is put down standing (%.1f above the floor, %.1f of it)"
			% [lowest - ground, boar.body_radius * Prey.HITBOX_SCALE])
	wallow.queue_free()
	pond.queue_free()
	bed.queue_free()
	await physics_frame


## "A rat", "an octopus".
func _one(id: String) -> String:
	return ("an " if "aeiou".contains(id.left(1)) else "a ") + id


## The most a pattern can hold at a given silk quality, as the escape check
## measures it — pattern strength times quality, times the margin.
func _hold_of(id: String, quality: float) -> float:
	var pattern := pattern_named(id)
	if pattern == null:
		return 0.0
	return pattern.hold_strength * quality * Prey.ESCAPE_MARGIN


# --- dragging things about ----------------------------------------------

## A catch on the line comes over a wall instead of being lost against it.
##
## A rope pulls in a straight line and the world is not straight. Haul something
## home with a wall in between and the pull is *into* the wall: the catch cannot
## follow, you keep walking, and the line parts. Which is a real thing for a rope
## to do and a stupid way to lose a catch you had already won, because there was
## nothing you could have done differently short of not going that way.
##
## So a line that is pulling and getting nowhere lifts as well, and the catch goes
## up and over — which is what a spider hauling something up a wall looks like
## anyway. Two pieces make it work and both were wrong first time:
##
## Progress is measured **along the pull**, not as plain movement. Plain movement
## oscillated, because the lift is its own undoing — the catch rises, rising
## counts as moving, moving cancels the lift, the catch drops back. Measured over
## a 1.2m wall it got 0.44m up and then lost the catch.
##
## And a snagged line **pays out** rather than stretching, so the breaking point
## moves with it. Without that the lift worked and the line parted anyway on
## anything tall: the catch crested a 3m wall at the exact moment the span passed
## the limit.
func _test_a_catch_comes_over_a_wall() -> void:
	var tether := spider.tether
	var slab := add_slab(Vector3(600, 0.0, 600), Vector3(40, 0.5, 40))
	var wall := add_slab(Vector3(600, 0.9, 596), Vector3(40, 1.8, 0.6))
	await physics_frame
	stand_on(Vector3(600, 0.4, 599.5))
	await run_frames(20)
	clear_prey_near(slab.global_position, 50.0, null)
	await physics_frame

	var load := spawn_fly(Vector3(600, 0.4, 599.8))
	if not check(load != null, "a bundle to haul home"):
		return
	load.move_speed = 0.0
	load.bundle()
	await run_frames(10)
	if not check(tether.hook(load), "on the line"):
		return
	var wall_top: float = wall.global_position.y + 0.9
	check(load.global_position.y < wall_top,
		"and starting below the wall between you and home (%.2f under %.2f)"
		% [load.global_position.y, wall_top])

	# Walk away over the wall at a walking pace, which is the case that lost it.
	var step: float = spider.stage().move_speed / 60.0
	var top := 0.0
	var over := false
	for i in 400:
		if not tether.is_towing():
			break
		var at := spider.global_position
		at.z -= step
		at.y = wall_top + 0.15 if at.z < 596.6 and at.z > 595.0 else 0.4
		spider.global_position = at
		await physics_frame
		top = maxf(top, load.global_position.y)
		if load.global_position.z < 595.6:
			over = true
			break

	check(tether.is_towing(), "the line holds rather than parting on the wall")
	check(top > wall_top,
		"because the catch is lifted over it (%.2fm, wall top %.2f)" % [top, wall_top])
	check(over, "so it ends up on your side of it")
	# Lifted, not launched: the climb is a governed rate, so a taller wall takes
	# longer rather than throwing the catch further.
	check(top < wall_top * 2.5,
		"without being flung (%.2fm over a %.2fm wall)" % [top, wall_top])
	tether.cut()
	if is_instance_valid(load):
		load.queue_free()


## A catch used to be something you walked back to. A tether makes it cargo:
## hook it and it comes with you. What matters is that it is a rope and not a
## rod — slack does nothing, so walking towards the thing you are towing is
## free, and only past the length of the line does it pull.
func _test_tethering() -> void:
	var tether := spider.tether
	var slab := add_slab(Vector3(120, 0.0, 120))
	await physics_frame
	stand_on(slab.global_position + Vector3(0, 0.25, 0))
	await process_frame
	clear_prey_near(slab.global_position, 18.0, null)
	await physics_frame

	check(not tether.is_towing(), "you start with nothing on the line")
	check(is_equal_approx(tether.drag_factor(), 1.0), "and nothing slowing you")

	# Something still fighting is not cargo. That is what the wrapping is for.
	var live := spawn("fly", slab.global_position + Vector3(0.5, 0.6, 0))
	if not check(live != null, "a fly to try it on"):
		return
	await physics_frame
	check(not tether.can_carry(live), "a fly going about its business is not cargo")
	check(not tether.hook(live), "so it refuses the line")
	check(not tether.is_towing(), "and nothing is on it")

	# Wrapped, it is finished business and can be dragged.
	check(live.bundle(), "wrapping it makes it a bundle")
	await physics_frame
	check(tether.can_carry(live), "and a bundle is cargo")

	if not check(tether.hook(live), "the line goes on it"):
		return
	check(tether.is_towing(), "and you are towing it")
	check(tether.cargo_name() == "Fly", "which the HUD can name (%s)" % tether.cargo_name())

	# A rope, not a rod: standing still next to it does nothing at all.
	var resting := live.global_position
	await run_frames(30)
	check(tether.slack() > 0.5, "slack line, standing next to it (%.2f)" % tether.slack())
	check(live.global_position.distance_to(resting) < 0.35,
		"which leaves the bundle where it lies (%.2fm)"
		% live.global_position.distance_to(resting))

	# Walk away and it has to come. Not snapped to a fixed distance — hauled.
	var started := live.global_position
	var rope: float = spider.stage().body_height * tether.rope_bodies
	spider.climb.release()
	spider.global_position = slab.global_position + Vector3(rope * 2.0, 0.85, 0)
	await run_frames(90)
	var moved := live.global_position.distance_to(started)
	check(moved > 0.5, "walking off drags it along (%.2fm)" % moved)
	check(live.global_position.distance_to(spider.global_position)
		<= rope * tether.snap_strain,
		"and it stays on the end of the line (%.2fm of %.2fm)"
		% [live.global_position.distance_to(spider.global_position),
			rope * tether.snap_strain])
	check(tether.is_towing(), "still towing after the haul")

	# Weight is the cost. Something three sizes up is a real drag.
	var light := tether.drag_factor()
	tether.cut()
	check(not tether.is_towing(), "cutting the line lets go")
	var heavy_one := spawn("wasp", slab.global_position + Vector3(0, 0.6, 0))
	if check(heavy_one != null, "something heavier to drag"):
		heavy_one.bundle()
		await physics_frame
		if check(tether.hook(heavy_one), "hooked the wasp"):
			check(tether.drag_factor() < light,
				"a wasp is heavier going than a fly (%.2f against %.2f)"
				% [tether.drag_factor(), light])
			spider.climb.haul = tether.drag_factor()
			check(spider.climb._surface_speed(false) < spider.stage().move_speed,
				"which you feel in your own legs")
			tether.cut()
			spider.climb.haul = 1.0
		heavy_one.queue_free()

	# Firing silk at something you have already caught puts a line on it rather
	# than hauling you over to stand next to it — the same click, read the only
	# way that makes sense for a thing already wrapped up and going nowhere.
	# On the slab, not off the edge of it. A bundle dropped past the edge is a
	# bundle falling for ever, which measures gravity rather than aiming.
	live.global_position = slab.global_position + Vector3(0, 0.35, -5.5)
	spider.climb.release()
	spider.global_position = slab.global_position + Vector3(0, 0.85, 0)
	# First person, so the crosshair really is the line the pick uses. In third
	# person the camera sits behind the spider and the two are a parallax
	# apart, which is fine to play with and no way to write an aiming test.
	var was_third := spider.view.third_person
	if was_third:
		spider.view.toggle_mode()
	# Settle first, then aim. The camera rig moves to its new place on the
	# next frame rather than on the call, and the spider is still dropping on
	# to the slab — aiming from a viewpoint that is still moving points the
	# crosshair at where the viewpoint used to be.
	await run_frames(10)
	aim_at(live.global_position)
	await run_frames(2)
	check(tether.aimed_cargo() == live,
		"the crosshair picks the bundle out from five metres")
	var strands := spider.get_tree().get_nodes_in_group("silk_webs").size()
	check(tether.grab_aimed(), "and the grapple puts a line on it")
	check(tether.is_towing(), "so you are towing rather than standing on it")
	var after := spider.get_tree().get_nodes_in_group("silk_webs").size()
	check(after == strands, "with no line strung to go there (%d)" % after)

	# A long shot pays out the whole distance and then winds back in, so it
	# harpoons rather than yanking the thing to your feet.
	var reeled := live.global_position.distance_to(spider.global_position)
	check(reeled > 4.0, "it is still out there to start with (%.2fm)" % reeled)
	await run_frames(150)
	var closer := live.global_position.distance_to(spider.global_position)
	check(closer < reeled - 0.8, "and it reels in (%.2fm from %.2fm)" % [closer, reeled])
	tether.cut()

	# But a click that merely passes a bundle on its way to a wall is a grapple.
	# Same aim, bundle moved off to the side of it.
	live.global_position = slab.global_position + Vector3(2.5, 0.35, -5.5)
	await physics_frame
	check(tether.aimed_cargo() == null,
		"a bundle off to one side is not what the click meant")
	check(not tether.grab_aimed(), "so the grapple stays a grapple")
	if was_third:
		spider.view.toggle_mode()

	# The line does not outlive what is on the end of it — and eating a catch off
	# the line is a success, so it must not be reported as a lost cargo. It was:
	# eating happens on an input frame and frees the creature at the end of it,
	# so the tether's next tick found nothing there and said the line came back
	# empty. Every meal off a tether read as a failure.
	live.global_position = slab.global_position + Vector3(0, 0.4, 0)
	await physics_frame
	if check(tether.hook(live), "one more, to be eaten off the line"):
		var said: Array[String] = []
		var listen := func(text: String) -> void: said.append(text)
		tether.notice.connect(listen)
		live.consume()
		# Freed at the end of the frame the eating happened on, exactly as in
		# play — so the tether has to have been told, not left to look afterwards.
		await process_frame
		await physics_frame
		await physics_frame
		tether.notice.disconnect(listen)
		check(not tether.is_towing(), "draining the cargo drops the line")
		check(not is_instance_valid(live), "and the creature is gone with it")
		check(said.is_empty(),
			"quietly — nothing about an empty line over the top of your meal (%s)"
			% ", ".join(said))

	slab.queue_free()
	await physics_frame
	await process_frame


# --- a meal is a few seconds you are standing still ---------------------

## Eating used to be one keypress and instantly over, and that is what made a web
## pointless: if a meal costs nothing, nowhere is safer than anywhere else and
## there is no reason to drag anything anywhere. A meal you have to stand still
## for is what gives the trip home a point.
func _test_a_meal_takes_time() -> void:
	# A moth is size two and a spiderling bites one, so wrapped or not it is "too
	# big for you". This check is about how long a meal takes, not about reaching
	# one, so it grows first.
	grow_to_bite(2)
	var slab := add_slab(Vector3(60, 0.0, -140))
	await physics_frame
	stand_on(slab.global_position + Vector3(0, 0.25, 0))
	await process_frame
	clear_prey_near(slab.global_position, 20.0, null)
	await physics_frame

	var meal := spawn("moth", spider.global_position + Vector3(0.3, 0.2, 0))
	if not check(meal != null, "a moth to eat"):
		slab.queue_free()
		return
	meal.move_speed = 0.0
	check(meal.bundle(), "wrapped and ready")
	await physics_frame
	var whole := meal.biomass
	check(whole > 0.0, "with something in it (%.0f biomass)" % whole)
	check(is_equal_approx(meal.full_biomass, whole),
		"and nothing taken out of it yet")

	# One press is a mouthful, not a meal.
	#
	# Drinking happens in the spider's _process, so it is process frames that are
	# waited for. Two physics frames used to stand in for them, which holds only
	# while a process frame falls between them — and after a slow frame, building
	# the moth's body the first time it is drawn, the engine runs physics steps back
	# to back to catch up, and the meal had not begun.
	Input.action_press("interact")
	spider.jaws.handle(meal)
	check(spider.feeding == meal,
		"holding the key starts drinking the %s" % meal.species)
	await process_frame
	await process_frame
	await process_frame
	var sip := meal.biomass
	check(sip < whole, "a moment of it takes some (%.1f from %.0f)" % [sip, whole])
	check(sip > whole * 0.25,
		"and nowhere near all of it — a meal is seconds, not a click (%.0f%% left)"
		% (100.0 * sip / whole))

	# Let go part way and the rest is still hanging there.
	Input.action_release("interact")
	await process_frame
	await process_frame
	check(spider.feeding == null, "letting go stops the meal")
	check(is_instance_valid(meal), "the moth is still there")
	if is_instance_valid(meal):
		check(meal.part_eaten(), "half eaten (%.0f%% gone)" % (100.0 * meal.drained()))
		check(meal.biomass > 0.0, "with the rest of it still in it (%.1f)" % meal.biomass)
		# And what you did swallow is yours — banked as it came, not at the end, so
		# an interrupted meal is not a wasted one.
		var part := spider.growth.biomass
		check(part > 0.0, "and what you drank is already banked (%.1f)" % part)

		# Go back to it and finish.
		var rest: float = await eat(meal, 900)
		check(rest > 0.0, "coming back finishes it (+%.1f)" % rest)
		check(not is_instance_valid(meal) or meal.eaten,
			"and the moth is gone this time")

	# On the line, at any length: silk is a straw, which is what makes eating on
	# the move possible at all — take it, tether it, run, drink on the way.
	var carried := spawn("fly", spider.global_position + Vector3(1.2, 0.3, 0))
	if check(carried != null, "a fly to carry"):
		carried.move_speed = 0.0
		carried.bundle()
		await physics_frame
		var tether := spider.tether
		if check(tether.hook(carried), "hooked onto your line"):
			var fangs: float = maxf(spider.stage().reach * 2.5,
				spider.stage().body_height * 4.0)
			spider.global_position += Vector3(0, 0, -(fangs + 2.0))
			await physics_frame
			var span := spider.global_position.distance_to(carried.global_position)
			check(span > fangs,
				"further off than your fangs reach (%.2fm past %.2fm)" % [span, fangs])
			var drunk: float = await eat(carried, 900)
			check(drunk > 0.0,
				"and you can still drink it down the line (+%.1f)" % drunk)
			if tether.is_towing():
				tether.cut()

	slab.queue_free()
	await physics_frame
	await process_frame


## A hunt is a thing that runs out.
##
## Giving up used to be distance-only: `hunt_range * 1.8` away and it loses you.
## But a hunter moves at [constant Prey.CHASE_DASH] times its own speed and a
## creature is only worth hunting while it out-sizes your bite — so the thing
## chasing you is always faster than you, and a distance you cannot open is not an
## escape. The only real outs were silk and growing a tier, and from in front that
## reads as a creature that simply will not stop.
##
## So the sprint is finite. It tires, the last stretch is slower than you are so
## you can *see* it going, and then it breaks off and leaves you alone for a while.
## Silk stays the good answer; running is now an answer at all.
func _test_a_hunt_runs_out() -> void:
	var tick := float(Engine.physics_ticks_per_second)
	var stage := spider.stage()

	# The numbers first, because this is where it goes wrong: a wind-down that is
	# still faster than the spider is a wind-down nobody can tell is happening.
	var sprint: float = 2.6 * Prey.CHASE_DASH
	var spent: float = 2.6 * Prey.CHASE_SPENT
	check(sprint > stage.move_speed,
		"a hunter's sprint beats the spider it is hunting (%.1f against %.1f)"
		% [sprint, stage.move_speed])
	check(spent < stage.move_speed,
		"and what it has left at the end does not (%.1f against %.1f), which is the window"
		% [spent, stage.move_speed])
	var winding: float = Prey.CHASE_STAMINA * (1.0 - Prey.CHASE_SECOND_WIND)
	check(winding > 1.0,
		"and the window is long enough to use (%.1fs of %.1f)"
		% [winding, Prey.CHASE_STAMINA])
	check(Prey.CHASE_COOLDOWN > 1.0,
		"breaking off means something, rather than re-acquiring on the next look (%.1fs)"
		% Prey.CHASE_COOLDOWN)

	var slab := add_slab(Vector3(60, 0.0, 200), Vector3(20, 0.5, 20))
	await physics_frame
	stand_on(slab.global_position + Vector3(0, 0.25, 0))
	await process_frame
	clear_prey_near(slab.global_position, 60.0, null)
	await physics_frame

	# Far enough that it cannot arrive inside its sprint, so what is measured is
	# the chase rather than a wasp sitting on the spider's face biting it.
	var wasp := spawn("wasp", spider.global_position + Vector3(0.0, 0.6, 26.0))
	if not check(wasp != null, "a wasp, well across the room"):
		slab.queue_free()
		return
	if not check(wasp.would_hunt(spider),
			"which out-sizes this spider's bite, so it is the hunting sort (size %d against bite %d)"
			% [wasp.size_class, stage.bite_power]):
		wasp.queue_free()
		slab.queue_free()
		return
	# Its own acquire radius is 6m and it is 26m out; the chase is what is under
	# test, not how far it can see. Past the settling-in grace for the same reason.
	wasp.hunt_range = 40.0
	wasp.aggression = 1.0
	wasp._life = Prey.SETTLE_IN + 1.0
	wasp._hunt_timer = 0.0

	if not check(await wait_until(func() -> bool: return wasp.is_hunting(), 120),
			"it comes for you"):
		wasp.queue_free()
		slab.queue_free()
		return

	# A second at full sprint, against a second at the end of one. Both measured
	# after a lead-in, because steering lerps towards the speed it is given rather
	# than taking it — measured from the moment it changes, the two seconds overlap
	# enough that the difference nearly vanishes and the check becomes a coin flip.
	await run_frames(roundi(tick))
	var from := wasp.global_position
	await run_frames(roundi(tick))
	var dashed := from.distance_to(wasp.global_position)
	check(dashed > stage.move_speed,
		"and covers more ground than you can while it is fresh (%.1fm in a second)" % dashed)

	# Run it down to the wind-down rather than waiting the whole sprint out: what
	# is being checked is that the slow stretch exists and is slow, and six seconds
	# of watching a wasp fly in a straight line proves that no better.
	wasp._chase_left = winding
	await run_frames(roundi(tick * 0.8))
	from = wasp.global_position
	await run_frames(roundi(tick))
	var limped := from.distance_to(wasp.global_position)
	check(wasp.is_hunting(), "it is still coming as it tires")
	check(limped < dashed * 0.7,
		"but slower than it started (%.1fm against %.1fm in the same second)"
		% [limped, dashed])
	check(limped < stage.move_speed,
		"and slower than you, so you can see yourself pulling away (%.1fm against %.1f)"
		% [limped, stage.move_speed])

	# And then it stops, without the spider having done anything at all.
	if not check(await wait_until(func() -> bool: return not wasp.is_hunting(),
			roundi(winding * tick) + 60), "then it breaks off on its own"):
		wasp.queue_free()
		slab.queue_free()
		return

	# The cooldown is the difference between breaking off and blinking. Its quarry
	# never moved and is still well inside the 40m it can see.
	await run_frames(roundi(tick * 2.0))
	check(not wasp.is_hunting(),
		"and stays off you for a while rather than turning straight round")
	wasp.queue_free()
	slab.queue_free()


## Everything you can eat can also eat you at the wrong size — which is the one
## line §8 of the design doc always had and nothing enforced. A creature inside
## your bite is food; one outside it, and aggressive, comes looking.
func _test_something_hunts_you() -> void:
	var slab := add_slab(Vector3(-60, 0.0, 140), Vector3(24, 0.5, 24))
	await physics_frame
	stand_on(slab.global_position + Vector3(0, 0.25, 0))
	await process_frame
	clear_prey_near(slab.global_position, 30.0, null)
	await physics_frame

	spider.health = spider.max_stamina()
	check(spider.max_stamina() > 0.0,
		"the spider has something to lose (%.0f)" % spider.max_stamina())
	check(not spider.is_hurt(), "and starts whole")

	var wasp := spawn("wasp", spider.global_position + Vector3(2.0, 0.4, 0))
	if not check(wasp != null, "a wasp, which is what hunts you"):
		slab.queue_free()
		return
	check(wasp.aggression > 0.0, "and it is the aggressive sort (%.2f)" % wasp.aggression)

	# The rule, both ways round, against a stand-in whose bite we choose. The real
	# spider is a Huntsman by the time this runs and a Huntsman out-bites every
	# creature in the game, which made the honest-looking version of this check a
	# tautology: it passed while proving nothing.
	# Never added to the tree: the rule reads a bite power and nothing else, and
	# this script is a SceneTree, which has no children to add it to.
	var small := PretendSpider.new()
	small.bite = wasp.size_class - 1
	check(wasp.would_hunt(small),
		"a wasp comes for anything whose bite is under its size (%d against %d)"
		% [small.bite, wasp.size_class])
	small.bite = wasp.size_class
	check(not wasp.would_hunt(small),
		"and stops the moment the bite catches up (%d)" % small.bite)
	var midge := spawn("midge", spider.global_position + Vector3(1.0, 0.3, 0))
	if check(midge != null, "a midge, which never hunts anything"):
		small.bite = 1
		check(not midge.would_hunt(small),
			"however small the thing in front of it is, because its aggression is nil")
		midge.queue_free()
	small.free()

	# Being bitten costs you the mouthful. That is the whole reason to eat at home.
	var dinner := spawn("fly", spider.global_position + Vector3(0.3, 0.2, 0))
	if check(dinner != null, "something to be interrupted eating"):
		dinner.move_speed = 0.0
		dinner.bundle()
		await physics_frame
		Input.action_press("interact")
		spider.jaws.handle(dinner)
		await physics_frame
		check(spider.feeding == dinner, "mid-meal")
		var before := spider.health
		spider.take_bite(2.0, wasp)
		check(spider.health < before,
			"a bite takes something off you (%.1f from %.1f)" % [spider.health, before])
		check(spider.feeding == null, "and costs you the mouthful")
		Input.action_release("interact")
		await process_frame
		if is_instance_valid(dinner):
			dinner.queue_free()

	# Run out and you are driven off, not killed: you drop what you were carrying
	# and get thrown clear. A sandbox with no save has no business killing you.
	var hauled := spawn("fly", spider.global_position + Vector3(0.6, 0.2, 0))
	if check(hauled != null, "something on your line to lose"):
		hauled.move_speed = 0.0
		hauled.bundle()
		await physics_frame
		spider.tether.hook(hauled)
		check(spider.tether.is_towing(), "towing it")
		var routed := [false]
		var watch := func() -> void: routed[0] = true
		spider.routed.connect(watch)
		spider.take_bite(spider.max_stamina() * 2.0, wasp)
		spider.routed.disconnect(watch)
		check(routed[0], "running out of stamina drives you off")
		check(not spider.tether.is_towing(), "and you drop what you were carrying")
		check(spider.velocity.length() > 0.0, "thrown clear of it")
		if is_instance_valid(hauled):
			hauled.queue_free()

	# It comes back on its own, so a bad trip costs you time and not a restart.
	#
	# The wasp is parked for this rather than cleared away: a wasp still biting
	# takes the stamina down faster than it mends, which reads as "mending is
	# broken", but the checks below still need it alive to stop hunting.
	var was_aggression := wasp.aggression
	wasp.aggression = 0.0
	wasp.move_speed = 0.0
	await physics_frame
	spider.health = 1.0
	spider.vitals.quiet = 0.0
	var low := spider.health
	await run_frames(120)
	check(spider.health > low, "stamina mends on its own (%.1f from %.1f)"
		% [spider.health, low])
	wasp.aggression = was_aggression

	# And growing is what settles it for good: the thing that was hunting you is
	# food once your bite catches up, which is the whole reward for eating.
	var was_bite := spider.stage().bite_power
	var hurt_first := spider.health
	if grow_to_bite(wasp.size_class):
		check(not wasp.would_hunt(spider),
			"grown past it, the wasp stops hunting you (bite %d against size %d)"
			% [spider.stage().bite_power, wasp.size_class])
	# Only meaningful if it actually grew — by this point in the suite the spider
	# may already out-bite a wasp, and then there is no tier to have mended you.
	if spider.stage().bite_power > was_bite:
		check(is_equal_approx(spider.health, spider.max_stamina()),
			"and growing left you whole (%.0f of %.0f)"
			% [spider.health, spider.max_stamina()])
	else:
		check(spider.health >= hurt_first,
			"already out-biting a wasp, so there was no tier left to mend you")

	# A hunter that comes at you through silk goes into the silk first. Even a web
	# too weak to keep it has bought you the seconds it spends tearing out — which
	# is what makes a web somewhere to stand and eat rather than a fortress.
	var centre := slab.global_position + Vector3(0, 3.0, 0)
	select_pattern("sheet_web")
	builder.start()
	for point in _square(centre, 0.8):
		builder.add_anchor(point)
	builder.finish()
	builder.stop()
	await physics_frame
	var net := newest_web("sheet_web") as WebNet
	if check(net != null, "a sheet web hung between you and it"):
		var comer := spawn("wasp", net.to_global(net.centre_local))
		if check(comer != null, "a wasp that flies into it"):
			comer.move_speed = 0.0
			await physics_frame
			await physics_frame
			check(comer.is_stuck() or comer.wrapped,
				"and it is in the silk rather than on your face")
			check(not comer.would_hunt(spider),
				"so it is hunting nothing while it is in there")
			# Cover, not a wall. Whether the web *keeps* it is the same sum every
			# other catch uses, and a wasp out-thrashes a sheet web — so what you
			# bought is the seconds it spends tearing out, and the silk it costs.
			var thrash := comer.struggle_power * comer.struggle_stamina
			var hold := net.hold_strength() * Prey.ESCAPE_MARGIN
			check(thrash > hold,
				"a sheet web cannot keep a wasp (%.1f thrash against %.1f hold)"
				% [thrash, hold])
			var bought := hold / maxf(comer.struggle_power, 0.01)
			check(bought > 1.0,
				"but it holds it for %.1fs, which is the seconds you were after"
				% bought)
			# A moment of fighting, then look: the wear is the other half of the
			# bargain. A sprung snare holds rigid for a beat first, so this waits.
			await run_frames(30)
			var worn := net.max_durability - net.durability
			check(worn > 0.0,
				"and the fight costs the web as it goes (%.3f of %.1f)"
				% [worn, net.max_durability])
			comer.queue_free()
		net.queue_free()

	if is_instance_valid(wasp):
		wasp.queue_free()
	slab.queue_free()
	await physics_frame
	await process_frame


# --- wrapped silk with nothing holding it -------------------------------

## Anything wrapped is finished business, and finished business obeys gravity.
## Two ways to end up wrapped in mid-air with nothing under you — killed by
## venom where you flew, and left behind when the web holding you comes down —
## and neither of them should leave a cocoon hovering in the air.
func _test_wrapped_things_fall() -> void:
	var slab := add_slab(Vector3(-120, 0.0, -120))
	await physics_frame
	stand_on(slab.global_position + Vector3(0, 0.25, 0))
	await process_frame
	clear_prey_near(slab.global_position, 18.0, null)
	await physics_frame
	var floor_y := slab.global_position.y + 0.25

	# Poisoned in mid-air, having never been in a web at all.
	var high := slab.global_position + Vector3(0, 2.4, 0)
	var flier := spawn("fly", high)
	if not check(flier != null, "a fly in the air to poison"):
		return
	await physics_frame
	check(flier.envenom(), "venom kills it where it flew")
	check(flier.wrapped, "and wraps it")
	await wait_until(func() -> bool: return flier.is_on_floor(), 300)
	check(flier.global_position.y < high.y - 0.5,
		"a dead thing falls (%.2f from %.2f)" % [flier.global_position.y, high.y])
	check(flier.global_position.y < floor_y + 0.3,
		"all the way down (%.2f, floor at %.2f)" % [flier.global_position.y, floor_y])
	# Not off across the level: with nowhere recorded to hang from, the old
	# behaviour dragged it towards the middle of the world instead.
	var drift := Vector2(flier.global_position.x - high.x, flier.global_position.z - high.z)
	check(drift.length() < 2.0,
		"and lands under where it died rather than sailing off (%.2fm)" % drift.length())
	flier.queue_free()
	await physics_frame

	# Wrapped in a web, and then the web comes down around it. Built by hand
	# rather than by spinning one over it and hoping: what is being tested is
	# what happens to a wrapped catch when its web goes, so the catch has to be
	# wrapped and in a web before the test starts, not as a side effect.
	var second := spawn("fly", high)
	if not check(second != null, "another fly, this one for a web"):
		slab.queue_free()
		return
	await physics_frame
	select_pattern("sheet_web")
	builder.start()
	for point in _square(high, 0.8):
		builder.add_anchor(point)
	builder.finish()
	builder.stop()
	await physics_frame
	var holder := newest_web("sheet_web") as WebNet
	if not check(holder != null, "a web to hang it in"):
		second.queue_free()
		slab.queue_free()
		return

	second.on_snared(holder, high, 0.0)
	second.wrap()
	await physics_frame
	check(second.wrapped and second.is_stuck(),
		"the fly is wrapped and hanging in it")
	var hung := second.global_position
	await run_frames(20)
	check(second.global_position.distance_to(hung) < 0.2,
		"and stays put while the web holds it (%.2fm)"
		% second.global_position.distance_to(hung))

	# Now take the web away. Nothing is holding it up any more.
	holder.demolish()
	await physics_frame
	var landed: bool = await wait_until(func() -> bool: return second.is_on_floor(), 300)
	check(landed, "with the web gone, a wrapped fly comes down")
	check(second.global_position.y < floor_y + 0.3,
		"onto the floor (%.2f, floor at %.2f)" % [second.global_position.y, floor_y])
	check(second.wrapped, "still wrapped when it lands — it is still finished business")
	second.queue_free()

	slab.queue_free()
	await physics_frame
	await process_frame


# --- aim and shoot ------------------------------------------------------

## The web verb, and now the only one the player has. Point, press, and a bolt
## leaves the spider: no ghost, no held key, and no asking the room whether
## there is a good enough spot. What it hits decides what happens.
func _test_shooting() -> void:
	# An orb web is a tier past a spiderling, and this is about the web.
	grow_to_spin("orb_web")
	var slab := add_slab(Vector3(150, 0.0, -150))
	await physics_frame
	stand_on(slab.global_position + Vector3(0, 0.25, 0))
	await process_frame
	clear_prey_near(slab.global_position, 18.0, null)
	await physics_frame
	select_pattern("orb_web")

	check(builder.shot_radius() > 0.0,
		"a throw has a size, taken from the body (%.2fm)" % builder.shot_radius())
	check(not builder.cooling(), "and no wait on it to start with")

	# At a surface: a web, wherever it landed, with nothing asked of the room.
	var built: Array[WebStructure] = []
	var catcher := func(web: WebStructure) -> void: built.append(web)
	builder.web_built.connect(catcher)
	var standing := web_count()
	var from := spider.view.aim_origin()
	var along := spider.view.aim_forward().normalized()
	check(builder.shoot(), "right mouse fires one")
	check(builder.shot_in_flight(), "and it is in the air")
	check(builder.cooling(), "with the wait already running (%.1fs)" % builder.cooldown_left())
	check(built.is_empty(), "with nothing built yet — it has to get there")

	# Along the crosshair, not under it. The bolt used to be pulled down, so
	# aiming at a thing and hitting it was only true at close range and the
	# crosshair quietly stopped meaning anything past that.
	var drift := 0.0
	var watched := 0
	for i in 12:
		await physics_frame
		var bolt := builder._shot
		if bolt == null or not is_instance_valid(bolt):
			break
		watched += 1
		var offset := bolt.global_position - from
		drift = maxf(drift, (offset - along * offset.dot(along)).length())
	check(watched > 0, "the bolt can be watched in flight (%d frames)" % watched)
	check(drift < 0.01, "and holds the line it was fired along (%.4fm off it)" % drift)
	var landed: bool = await wait_until(func() -> bool: return not built.is_empty(), 240)
	builder.web_built.disconnect(catcher)
	check(landed and built.size() == 1, "it makes a web where it lands (%d)" % built.size())
	check(web_count() == standing + 1, "which is standing there")
	if built.size() == 1:
		built[0].demolish()
	await physics_frame

	# The wait is the whole cost of a web now, so it has to actually bite. Set
	# by hand rather than measured off the last shot: how long the bolt spent in
	# the air must not decide whether this passes.
	builder._cooling = builder.shot_cooldown
	check(builder.cooling(), "a shot starts a wait (%.1fs)" % builder.cooldown_left())
	check(not builder.shoot(), "and nothing else goes while it runs")
	check(builder.cooldown_progress() < 1.0,
		"with the readout part-way along it (%.2f)" % builder.cooldown_progress())
	builder._cooling = 0.0
	check(not builder.cooling() and builder.cooldown_progress() >= 1.0,
		"and it comes back on its own, costing nothing that was being saved")
	# Tested once. The rest of the suite fires freely rather than sitting out a
	# wait between every check.
	builder.shot_cooldown = 0.0

	# At something alive: the creature is wrapped, and no web is left hanging.
	builder._update_aim()
	var victim := spawn("fly", builder.aim_point + Vector3(0, 0.4, 0))
	if not check(victim != null, "a fly to shoot at"):
		slab.queue_free()
		return
	await physics_frame
	check(not victim.wrapped, "going about its business")
	var after: Array[WebStructure] = []
	var second := func(web: WebStructure) -> void: after.append(web)
	builder.web_built.connect(second)
	var before_shot := web_count()
	check(builder.shoot(), "a second shot, at the fly")
	var hit: bool = await wait_until(func() -> bool: return victim.wrapped, 240)
	builder.web_built.disconnect(second)
	check(hit, "hitting it wraps it where it stood")
	check(victim.is_bundled(), "and drops it as a bundle")
	await physics_frame
	await process_frame
	check(web_count() == before_shot,
		"with no web left hanging (%d, started %d)" % [web_count(), before_shot])
	victim.queue_free()

	# Off the line on purpose. The bolt is a ball of silk, not a hairline: a fly
	# is five centimetres across and wandering, so a ray through the middle of
	# one is a shot nobody can make, which is why nothing could be caught.
	#
	# But the ball is the ball you can see. It used to take anything within two
	# and a half body lengths of its path, which is sixty centimetres either side
	# for a spiderling's tap, so every shot anywhere near a creature caught it and
	# where you aimed stopped mattering.
	builder._update_aim()
	var reach := builder.catch_radius(builder.shot_radius())
	check(is_equal_approx(reach, builder.ball_radius(0.0)),
		"a tap catches with the ball it throws, %.3fm across its middle" % reach)
	check(reach < spider.stage().body_height * 0.5,
		"which is smaller than the spider, not wider than it (%.3fm against %.2fm)"
		% [reach, spider.stage().body_height])
	var start := spider.view.aim_origin()
	var sideways := spider.view.aim_forward().cross(Vector3.UP)
	if sideways.length_squared() < 0.001:
		sideways = Vector3.RIGHT
	sideways = sideways.normalized()
	var beside := start + (builder.aim_point - start) * 0.5 + sideways * reach * 0.6
	clear_prey_near(beside, 6.0, null)
	var grazed := spawn("fly", beside)
	if check(grazed != null, "a fly beside the line, not on it"):
		# Held still: this is about where the ball goes, not about a test keeping
		# a crosshair on something that wanders. And picking held off, or the
		# shot would be thrown at the fly instead of past it — that has a section
		# of its own.
		grazed.move_speed = 0.0
		builder.shot_pick_angle = -1.0
		await physics_frame
		check(builder.shoot(), "a shot past it")
		var near: bool = await wait_until(func() -> bool: return grazed.wrapped, 240)
		check(near, "a graze is enough — the ball touched it, and it is wrapped")
		grazed.queue_free()
		builder.shot_pick_angle = 2.0
		await physics_frame

	# And near is not touching. Clear of the ball by a fly's own width, which the
	# old catch would have taken without a second look. A quarter of the way down
	# rather than halfway, so it is out of reach of the web the bolt opens when it
	# lands on the floor — being caught by that is a web doing its job, which is not
	# what this is measuring.
	var clear_of := reach + 0.1
	var wide := start + (builder.aim_point - start) * 0.25 + sideways * clear_of
	clear_prey_near(wide, 6.0, null)
	var missed := spawn("fly", wide)
	if check(missed != null, "a fly a hand's width off the line"):
		missed.move_speed = 0.0
		await physics_frame
		check(clear_of - missed.hit_radius() > reach,
			"far enough that the ball and the fly do not touch (%.3fm apart)"
			% (clear_of - missed.hit_radius() - reach))
		check(builder.shoot(), "a shot past that one too")
		await wait_until(func() -> bool: return not builder.shot_in_flight(), 240)
		await run_frames(2)
		check(not missed.wrapped and is_zero_approx(missed.bound),
			"is a miss — no wrap, and no silk on it (%d%%)" % roundi(missed.bound * 100.0))
		missed.queue_free()
		await physics_frame

	# At nothing at all: the bolt has to stop being a bolt.
	spider.view.face(Vector3(0, 0, -1))
	spider.view.pitch = 1.2
	await run_frames(4)
	check(builder.shoot(), "a third, fired at the sky")
	check(builder.shot_in_flight(), "which is away")
	var gone: bool = await wait_until(func() -> bool: return not builder.shot_in_flight(), 300)
	check(gone, "and gives up rather than flying off for ever")

	slab.queue_free()
	await physics_frame
	await process_frame


## A creature under the cross is thrown at where it is going to be.
##
## Aimed at where a fly *is*, a tap never catches one that is moving: at the pace
## silk flies, a spiderling's shot takes the best part of a second to cross the
## room, and a fly has gone twenty times its own width by then. Measured on a
## wandering fly with the cross dead on it, that was none in forty, where a shot
## led to where the fly was going caught nine in ten.
##
## So a shot picks the creature under the cross — one whose outline comes within a
## couple of degrees of it — and throws at the point where silk and creature meet.
## The crosshair brackets what it picked and marks that point. It promises
## nothing: the bolt still flies dead straight, and a creature that turns while it
## is in the air has turned away from it.
func _test_leading_a_moving_target() -> void:
	var slab := add_slab(Vector3(-150, 0.0, -150), Vector3(24, 0.5, 24))
	await physics_frame
	place(slab.global_position + Vector3(0, 0.6, 0))
	if not check(await wait_until(
			func() -> bool: return spider.climb.is_attached(), 120),
			"standing on the floor"):
		slab.queue_free()
		return
	clear_prey_near(slab.global_position, 30.0, null)
	await physics_frame
	builder.shot_cooldown = 0.0
	var hair := level.find_child("Crosshair", true, false) as Crosshair
	check(hair != null, "the HUD draws a crosshair")

	# A fly crossing in front, four metres off, going steadily one way. Steered by
	# the test rather than by itself, so this is about the aim and not about luck.
	var start := spider.global_position + Vector3(-1.2, 0.8, -4.0)
	var fly := _crossing_fly(start)
	if not check(fly != null, "a fly flying across"):
		slab.queue_free()
		return
	aim_at(fly.global_position)
	await process_frame
	aim_at(fly.global_position)
	check(builder.shot_target() == fly, "the cross on it picks it")
	if hair != null:
		hair.read()
		check(hair.mark == Crosshair.Mark.CREATURE and hair.target == fly,
			"and the crosshair brackets it")
	var from := spider.view.aim_origin()
	var lead := builder.shot_lead(fly)
	var pace := SilkShot.pace_for(spider.stage().body_height)
	var arrives := from.distance_to(lead) / pace
	var meets := fly.global_position + fly.velocity * arrives
	check((lead - fly.global_position).dot(fly.velocity) > 0.0,
		"leading it: the shot goes ahead of it, the way it is flying")
	check(lead.distance_to(meets) < 0.01,
		"to where it will be when the silk gets there (%.2fm ahead, %.2fs out)"
		% [lead.distance_to(fly.global_position), arrives])
	check(builder.shoot(), "a tap")
	var caught := await _fly_until_over(fly)
	check(caught, "and the silk meets it where it had got to")
	if is_instance_valid(fly):
		fly.queue_free()
	await physics_frame

	# The same shot at where it was, which is all a straight throw can do.
	builder.shot_pick_angle = -1.0
	var other := _crossing_fly(start)
	if check(other != null, "the same fly again, crossing the same way"):
		aim_at(other.global_position)
		await process_frame
		aim_at(other.global_position)
		check(builder.shot_target() == null, "with picking off, nothing is picked")
		check(builder.shoot(), "the same tap, straight down the cross")
		var hit := await _fly_until_over(other)
		check(not hit, "misses — by the time the silk arrives it has flown on")
		if is_instance_valid(other):
			other.queue_free()
	builder.shot_pick_angle = 2.0
	await physics_frame

	# Well off the cross is not under it, however near.
	var aside := spawn("fly", spider.global_position + Vector3(0.0, 0.8, -4.0))
	if check(aside != null, "a fly straight ahead"):
		aside.set_physics_process(false)
		aim_at(aside.global_position + Vector3(0.9, 0.0, 0.0))
		await process_frame
		aim_at(aside.global_position + Vector3(0.9, 0.0, 0.0))
		check(builder.shot_target() == null,
			"with the cross a hand's width beside it, it is not picked")
		# And a wall between the spider and it takes it out of the question: silk
		# thrown at it would land on the wall.
		var wall := add_slab(spider.global_position + Vector3(0.0, 0.5, -2.0),
			Vector3(3.0, 1.6, 0.2))
		await physics_frame
		aim_at(aside.global_position)
		await process_frame
		aim_at(aside.global_position)
		check(builder.shot_target() == null,
			"and behind a wall the silk would hit first, it is not picked either")
		wall.queue_free()
		aside.queue_free()
	slab.queue_free()
	await physics_frame


## A fly at [param at] crossing the room at a fly's pace in a straight line, the
## test's hand on it instead of its own wandering.
func _crossing_fly(at: Vector3) -> Prey:
	var fly := spawn("fly", at)
	if fly == null:
		return null
	fly.set_physics_process(false)
	fly.velocity = Vector3(1.0, 0.0, 0.0) * PreyLibrary.find("fly").move_speed
	return fly


## Keeps [param fly] flying straight until the shot in the air is over, and says
## whether the shot took it.
func _fly_until_over(fly: Prey) -> bool:
	for i in 180:
		await physics_frame
		if not is_instance_valid(fly):
			return true
		if fly.wrapped or fly.bound > 0.0:
			return true
		fly.global_position += fly.velocity / float(Engine.physics_ticks_per_second)
		if not builder.shot_in_flight():
			break
	await physics_frame
	return is_instance_valid(fly) and (fly.wrapped or fly.bound > 0.0)


## The crosshair tells the truth, and the arm stays out of the walls.
##
## Both were the same mistake made twice: reasoning about a third-person camera as
## if it were the spider's eye.
##
## **Aiming.** The silk used to be fired from the spider along the *camera's*
## direction. The camera sits behind and above, so those are two different shots
## and only one of them goes where the cross is — measured against a wasp three
## metres off, the old aim landed 0.45m away from it, on a creature 0.05m across.
## The cross's own ray is cast now, and the spider aims at what it finds.
##
## **The arm.** The pivot lifted along world up, so on a ceiling it sat *inside*
## the ceiling — and a ray that starts inside a solid does not report hitting it,
## so the arm found nothing in the way and put the camera through the roof. It is
## measured off the surface the spider is standing on now, which is open air
## whichever way up that is.
func _test_the_camera_tells_the_truth() -> void:
	var view := spider.view
	var slab := add_slab(Vector3(-200, 0.0, 200), Vector3(16, 0.5, 16))
	await physics_frame
	stand_on(slab.global_position + Vector3(0, 0.25, 0))
	if not check(await wait_until(
			func() -> bool: return spider.climb.is_attached(), 120),
			"standing on the floor"):
		return
	clear_prey_near(slab.global_position, 24.0, null)
	await physics_frame
	check(view.third_person, "and looking at the spider rather than out of it")

	var mark := spawn("wasp", spider.global_position + Vector3(0, 0.35, -3.0))
	if not check(mark != null, "a wasp three metres off"):
		return
	mark.move_speed = 0.0
	mark.aggression = 0.0
	await physics_frame
	aim_at(mark.global_position)
	await physics_frame

	# What the cross is on is what the silk is aimed at.
	var span := view.aim_origin().distance_to(mark.global_position)
	var lands := view.aim_origin() + view.aim_forward() * span
	var miss := lands.distance_to(mark.global_position)

	# The old rule, for something to measure against: from the spider, towards a
	# point far down the camera's own forward.
	var was := (view.camera.global_position + view.forward() * 200.0
		- view.aim_origin()).normalized()
	var old_miss := (view.aim_origin() + was * span).distance_to(mark.global_position)

	check(miss < mark.kind.body_radius * 2.0,
		"the silk goes where the cross is, inside the wasp itself (%.3fm off)" % miss)
	check(miss < old_miss * 0.25,
		"which the camera's own direction did not (%.3fm off, against %.3f)"
		% [miss, old_miss])
	check(view.aim_focus().distance_to(mark.global_position) < 0.2,
		"because the cross is cast at the world and finds the wasp (%.3fm)"
		% view.aim_focus().distance_to(mark.global_position))
	mark.queue_free()

	# Upside down, the arm still has to end up in the room — and on every frame of
	# getting there. The pivot rides the body's back, which starts out pointing
	# into the roof and turns over as the body does, so the whole roll is a pivot
	# pressed against stone: it is carried out from the middle of the body, and has
	# to stop short of the roof every time rather than be set down inside it.
	var roof := add_slab(Vector3(-200, 4.0, 200), Vector3(14, 0.5, 14))
	await physics_frame
	var under: float = roof.global_position.y - 0.25
	spider.global_position = Vector3(-200, 3.55, 200)
	spider.climb.release()
	await physics_frame
	# Watched frame by frame in a plain loop rather than through wait_until: a
	# lambda gets its own copy of a local, so a running maximum kept inside one
	# never leaves it and the check below would pass on nothing.
	var highest := -INF
	var rolled := false
	for i in 180:
		highest = maxf(highest, view.camera.global_position.y)
		if spider.climb.view_up().y < -0.5:
			rolled = true
			break
		await physics_frame
	if not check(rolled, "hanging under a ceiling, the other way up"):
		return
	check(highest < under,
		"and the camera stayed in the room the whole way over (%.2f at most, under %.2f)"
		% [highest, under])
	view.pitch = 0.0
	view.update(spider.stage().body_height, spider.climb.view_up())
	check(view.aim_pivot().y < spider.global_position.y,
		"the pivot goes away from the ceiling, not into it (%.2f under the spider's %.2f)"
		% [view.aim_pivot().y, spider.global_position.y])
	check(view.camera.global_position.y < under,
		"so the camera is in the room and not in the roof (%.2f, under %.2f)"
		% [view.camera.global_position.y, under])
	# And the arm keeps at least the room it always kept — the near plane needs
	# about a centimetre, which is *less* than this, so the old margin was never
	# what was letting the camera through a wall.
	check(view._clearance() >= spider.stage().body_height * 0.35,
		"with the arm's old clearance intact (%.4fm)" % view._clearance())
	roof.queue_free()


## Holding the shoot key: a ball of silk wound up over the spider's back, which
## buys a bigger throw rather than a promised one.
func _test_taking_aim() -> void:
	# Six shots in a row, and this is about where they go rather than how long you
	# wait between them. It used to get that for free from the section before it.
	ignore_shot_cooldown()
	var slab := add_slab(Vector3(150, 0.0, 150))
	await physics_frame
	stand_on(slab.global_position + Vector3(0, 0.25, 0))
	await process_frame
	clear_prey_near(spider.global_position, 30.0, null)
	select_pattern("orb_web")
	await physics_frame

	var quarry := spawn("fly", spider.global_position + Vector3(3.0, 1.0, 0.0))
	if not check(quarry != null, "a fly to take aim at"):
		slab.queue_free()
		return
	# Still, for the winding-up half. What is being checked is the wind-up, not
	# whether a test can hold a crosshair on a wandering insect.
	quarry.move_speed = 0.0
	await physics_frame

	var was_third := spider.view.third_person
	spider.view.aim_blend = 0.0
	check(builder.begin_shot(), "holding right mouse starts winding a throw up")
	check(builder.aiming, "which is a state you are in")
	# It used to drop you into first person. Watching the spider wind the throw
	# up is worth more than the precision that bought, so the camera stays put.
	check(spider.view.third_person == was_third,
		"and leaves the camera alone — you keep watching the spider")
	var ball := builder.get_node_or_null(NodePath("HeldSilk")) as MeshInstance3D
	check(ball != null and ball.visible, "with a ball of silk held over its back")
	check(is_zero_approx(builder.charge), "wound up not at all yet")

	# No frames between here and letting go: a physics frame would see the key
	# is not really held down in a headless run and let go on the spider's
	# behalf, which is the safety net doing its job and ruining the test.
	aim_at(quarry.global_position)
	spider.view.update(spider.stage().body_height)
	builder._update_held()
	var small_ball: float = ball.scale.x if ball != null else 0.0
	var tap_radius := builder.shot_radius()
	var tap_span := builder.catch_radius(tap_radius)

	for i in 30:
		aim_at(quarry.global_position)
		spider.view.update(spider.stage().body_height)
		builder.track(0.05)
		builder._frame_the_aim(0.05)
		builder._update_held()
	check(builder.charge >= 1.0, "holding it winds all the way up (%.2f)" % builder.charge)

	# What the second buys. It used to buy a promise — hold the cross on a fly
	# for a second and the bolt steered itself home, which took the shot away
	# from the player. It buys size instead: the same help, earned the same way,
	# and you still have to aim it.
	var full_radius := builder.shot_radius()
	var full_span := builder.catch_radius(full_radius)
	check(full_radius > tap_radius * 1.5,
		"and throws a far bigger web (%.2fm across, from %.2fm)"
		% [full_radius * 2.0, tap_radius * 2.0])
	# The catch ball has a floor under it, so that a tap is not a shot nobody
	# could make — which is why it grows by less than the web does.
	check(full_span > tap_span,
		"which is that much easier to hit with (%.2fm ball, from %.2fm)"
		% [full_span * 2.0, tap_span * 2.0])
	# The ball is the readout as well: it swells as the wind-up fills, so you
	# can keep looking at the fly rather than down at a bar.
	if ball != null:
		check(ball.scale.x > small_ball,
			"and you can watch it grow in your hands (%.4f from %.4f)"
			% [ball.scale.x, small_ball])
	check(spider.view.aim_blend > 0.5,
		"with the camera settling into the aim (%.2f)" % spider.view.aim_blend)

	# The framing on its own: same look, one blend against the other. Nothing
	# travels — the arm keeps its length and the horizon stays put. The point it
	# orbits lifts, so the spider drops down the screen and the room over its back
	# opens out, which is where the silk is going. We did try bringing the arm in
	# and round the shoulder and it was far too much motion for a framing.
	var wound := spider.view.aim_blend
	spider.view.face(Vector3(1, 0, 0))
	spider.view.pitch = 0.0
	spider.view.aim_blend = 0.0
	spider.view.update(spider.stage().body_height)
	var resting := spider.view.camera.global_position
	var arm_out := resting.distance_to(spider.global_position)
	spider.view.aim_blend = wound
	spider.view.update(spider.stage().body_height)
	var framed := spider.view.camera.global_position
	check(framed.y > resting.y,
		"the view lifts above the spider for a throw (%.2fm up)" % (framed.y - resting.y))
	check(absf(framed.distance_to(spider.global_position) - arm_out) < arm_out * 0.3,
		"without hauling the camera in (%.2fm against %.2fm)"
		% [framed.distance_to(spider.global_position), arm_out])
	check(spider.view.aim_fov_gain > 0.0,
		"and the view opens up by %.0f° with it" % spider.view.aim_fov_gain)

	# A wound-up throw, aimed at the fly, takes it — and it is the aim that does
	# it. The bolt leaves along the crosshair and keeps that heading.
	aim_at(quarry.global_position)
	spider.view.update(spider.stage().body_height)
	var along := spider.view.aim_forward().normalized()
	check(builder.release_shot(), "letting go throws it")
	check(not builder.aiming, "and the wind-up is over")
	check(ball == null or not ball.visible, "and the ball has left its hands")
	var bolt := builder._shot
	if check(bolt != null, "with a ball of silk in the air"):
		check(bolt.heading().normalized().dot(along) > 0.999,
			"flying exactly where it was pointed, nothing steering it")
	var took: bool = await wait_until(func() -> bool: return quarry.wrapped, 360)
	check(took, "and a wide ball thrown at a fly catches it")
	check(not is_instance_valid(quarry) or quarry.is_bundled(),
		"leaving it bundled")

	# Nothing homes any more. Wind one right up, throw it the other way, and the
	# fly across the room is left alone: the help is the size of the ball.
	await wait_until(func() -> bool: return not builder.shot_in_flight(), 240)
	var bystander := spawn("fly", spider.global_position + Vector3(14.0, 1.0, 0.0))
	if check(bystander != null, "another fly, right across the room"):
		bystander.move_speed = 0.0
		await physics_frame
		check(builder.begin_shot(), "winding another one up")
		for i in 30:
			builder.track(0.05)
		spider.view.face(Vector3(-1, 0, 0))
		spider.view.pitch = 0.9
		spider.view.update(spider.stage().body_height)
		check(builder.release_shot(), "thrown the other way entirely")
		var spent: bool = await wait_until(
			func() -> bool: return not builder.shot_in_flight(), 300)
		check(spent, "the throw runs out rather than turning round")
		check(not bystander.wrapped, "and the fly behind you is untouched")
		bystander.queue_free()
		await physics_frame

	# A tap is still a tap: nothing wound up, the smallest ball, straight out.
	await wait_until(func() -> bool: return not builder.shot_in_flight(), 200)
	check(builder.begin_shot(), "a tap starts the same way")
	var tapped := builder.catch_radius(builder.shot_radius())
	check(builder.release_shot(), "and lets go before anything is wound up")
	check(is_zero_approx(builder.charge) and tapped < full_span,
		"throwing the small ball it always did (%.2fm)" % [tapped * 2.0])

	if is_instance_valid(quarry):
		quarry.queue_free()
	slab.queue_free()
	await physics_frame
	await process_frame


## How far silk goes, and what it costs to throw it that far.
##
## Grappling and throwing were both effectively unlimited — anywhere you could
## see — which made the whole game read as too long ranged. That is what happens
## when nothing is out of reach: there is no distance left for growing to close,
## and a room you cannot cross is the only thing that makes crossing it a reward.
func _test_how_far_silk_goes() -> void:
	# An orb web is a tier past a spiderling, and this is about the web.
	grow_to_spin("orb_web")
	var slab := add_slab(Vector3(-150, 0.0, 150), Vector3(20, 0.5, 20))
	await physics_frame
	stand_on(slab.global_position + Vector3(0, 0.25, 0))
	await process_frame
	clear_prey_near(slab.global_position, 24.0, null)
	select_pattern("orb_web")
	await physics_frame

	var stage := spider.stage()
	var reach := builder.silk_reach()
	check(reach < WebBuilder.UNLIMITED_REACH,
		"silk has an end to it now (%.1fm)" % reach)
	check(is_equal_approx(reach, stage.max_strand_length * builder.silk_span),
		"and it is one thread's span, %.1f times over (%.1fm of %.1fm)"
		% [builder.silk_span, reach, stage.max_strand_length])
	# The same number for both verbs. Two ways of putting silk over there, each
	# with its own invisible limit, is the fastest way to make a reach unreadable.
	check(reach > stage.body_height * 8.0,
		"which is a good way further than the spider is long")

	# It grows. That is the whole point of hanging it off the body: the room you
	# could not cross yesterday is what eating bought you.
	var ladder := WebLibrary.default_stages()
	if check(ladder.size() > 1, "there is a ladder of sizes"):
		var opens := true
		for i in ladder.size() - 1:
			if ladder[i + 1].max_strand_length <= ladder[i].max_strand_length:
				opens = false
		check(opens, "and every tier reaches further than the one below it")
		check(ladder[ladder.size() - 1].max_strand_length
			> ladder[0].max_strand_length * 5.0,
			"by %.0f times over the whole ladder"
			% (ladder[ladder.size() - 1].max_strand_length
				/ ladder[0].max_strand_length))

	# Past the end of it there is nothing to grapple to, and the readout says so
	# with the number in it — "no surface in reach" reads as a broken click,
	# where a distance reads as somewhere to come back to when you are bigger.
	var far := add_slab(slab.global_position
		+ Vector3(0, 0.0, -(reach + 12.0)), Vector3(8, 6.0, 0.5))
	await physics_frame
	spider.view.face(Vector3(0, 0, -1))
	spider.view.pitch = 0.0
	await run_frames(4)
	builder._update_aim()
	check(builder.problem == WebBuilder.Problem.NO_SURFACE,
		"a wall past the reach is not something to grapple to")
	check(builder.problem_text().contains("%.0fm" % reach),
		"and the readout names the distance (%s)" % builder.problem_text())
	far.queue_free()
	await physics_frame

	# Inside it, the same wall is fair game.
	var near := add_slab(slab.global_position
		+ Vector3(0, 0.0, -reach * 0.5), Vector3(8, 6.0, 0.5))
	await physics_frame
	builder._update_aim()
	check(builder.problem == WebBuilder.Problem.NONE,
		"the same wall half that far away is (%s)" % builder.problem_text())
	near.queue_free()
	await physics_frame

	# And distance costs something inside the reach as well, which is the part
	# that can be played around: a hard edge says where you may not throw, this
	# says what throwing far is worth. Long shots land — they land thinner.
	var close_up := builder.throw_quality(0.0)
	var far_off := builder.throw_quality(reach)
	check(is_equal_approx(close_up, stage.silk_quality),
		"a web spun at your feet is worth full quality (%.2f)" % close_up)
	check(far_off < close_up,
		"one thrown the whole way is thinner (%.2f against %.2f)"
		% [far_off, close_up])
	check(is_equal_approx(far_off, close_up * builder.far_quality),
		"by exactly the falloff (%.2f)" % builder.far_quality)
	check(far_off > 0.0,
		"and never nothing — a throw that builds no web reads as broken")
	check(builder.throw_quality(reach * 2.0) >= far_off,
		"with no extra penalty past the end, because there is no past the end")

	slab.queue_free()
	await physics_frame
	await process_frame


## Sprinting costs wind, and hauling something costs more of it.
##
## The point of the pool is the second half. Weight already makes a haul *slower*
## ([member SilkTether.haul_drag]); on its own that just makes the slow version
## worse than the fast one, with nothing to weigh. Wind makes running with a catch
## on your line something you spend, so walking it home is a real alternative
## rather than what you do when you have forgotten about Shift.
##
## Wind is deliberately **not** the pool a bite takes. That one is condition, you
## cannot wait it back, and running out of it throws you across the room. Running
## out of wind costs you nothing but a walk.
func _test_a_sprint_costs_wind() -> void:
	var vitals := spider.vitals
	var tether := spider.tether
	var slab := add_slab(Vector3(-140, 0.0, 140), Vector3(20, 0.5, 20))
	await physics_frame
	stand_on(slab.global_position + Vector3(0, 0.25, 0))
	if not check(await wait_until(
			func() -> bool: return spider.climb.is_attached(), 120),
			"standing on something to run along"):
		return
	clear_prey_near(slab.global_position, 26.0, null)
	await physics_frame

	check(vitals.max_wind() > 0.0, "there is a sprint to spend (%.1fs)" % vitals.max_wind())
	check(is_equal_approx(vitals.wind_left(), 1.0), "and it starts full")
	check(spider.can_sprint(), "so the key would do something")
	# A tier does not buy a longer sprint — it buys a faster one, which covers more
	# ground in the same seconds. Scaling both would be paying the ladder twice.
	var small := vitals.max_wind()
	grow_to_tier(2)
	check(is_equal_approx(vitals.max_wind(), small),
		"and growing does not lengthen it (%.1fs against %.1f)"
		% [vitals.max_wind(), small])
	check(spider.stage().move_speed > 0.0, "it just makes the same seconds go further")

	# Carrying nothing: one second of sprint costs one second of wind.
	check(is_equal_approx(vitals.sprint_effort(), 1.0),
		"empty-handed a sprint costs its own length (%.2fx)" % vitals.sprint_effort())
	var bare := vitals.breath
	check(vitals.sprint(0.5, true), "you can run")
	var spent_bare := bare - vitals.breath
	check(is_equal_approx(spent_bare, 0.5),
		"half a second of running is half a second of wind (%.2f)" % spent_bare)

	# With a wasp on the line it costs more, which is the whole mechanic.
	catch_breath()
	var load := spawn("wasp", spider.global_position + Vector3(1.2, 0.3, 0.0))
	if not check(load != null, "a wasp to drag about"):
		return
	load.move_speed = 0.0
	load.aggression = 0.0
	load.bundle()
	await physics_frame
	if not check(tether.hook(load), "on the line"):
		return
	check(tether.cargo_weight() > 1.0,
		"which weighs something (%d size classes)" % roundi(tether.cargo_weight()))
	check(vitals.sprint_effort() > 1.0,
		"so a sprint costs more than its own length (%.2fx)" % vitals.sprint_effort())
	var laden := vitals.breath
	check(vitals.sprint(0.5, true), "you can still run")
	var spent_laden := laden - vitals.breath
	check(spent_laden > spent_bare,
		"and the same half second costs more of it (%.2f against %.2f)"
		% [spent_laden, spent_bare])
	tether.cut()
	load.queue_free()

	# Run it out. Being blown is a bar rather than a number going to zero, so an
	# empty tank does not buy a frame of sprint per frame of recovery.
	catch_breath()
	var frames := 0
	while vitals.sprint(1.0 / 60.0, true) and frames < 2000:
		frames += 1
	check(frames > 0 and frames < 2000,
		"holding it down runs the tank dry (%.1fs of frames)" % (frames / 60.0))
	check(not spider.can_sprint(), "and then the key does nothing")
	await run_frames(6)
	check(not vitals.sprint(1.0 / 60.0, true),
		"still nothing a moment later, rather than a stutter of one frame each")

	# It all comes back on its own, which is what makes it a tax on running and
	# not a wound.
	var gasping := vitals.breath
	await run_frames(150)
	check(vitals.breath > gasping,
		"it comes back while you walk (%.2fs from %.2f)" % [vitals.breath, gasping])
	check(spider.can_sprint(),
		"and you get your legs back without doing anything about it")
	check(not spider.is_hurt(),
		"with condition untouched throughout — a sprint is not a wound")


## A spider's jump, not a person's scaled down.
func _test_a_spiders_jump() -> void:
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	var ladder := WebLibrary.default_stages()
	if not check(ladder.size() > 1, "there is a ladder to jump up"):
		return
	var first := ladder[0]
	var rise: float = first.jump_velocity * first.jump_velocity / (2.0 * gravity)
	check(rise > first.body_height * 5.0,
		"a spiderling clears %.1f of its own body lengths (%.2fm)"
		% [rise / first.body_height, rise])

	var climbing := true
	for i in ladder.size() - 1:
		if ladder[i + 1].jump_velocity <= ladder[i].jump_velocity:
			climbing = false
	check(climbing, "and every tier jumps harder than the one below it")

	# Bigger things jump fewer of their own lengths. That is not a concession,
	# it is what square-cube does to anything that jumps.
	var last := ladder[ladder.size() - 1]
	var last_rise: float = last.jump_velocity * last.jump_velocity / (2.0 * gravity)
	check(last_rise / last.body_height < rise / first.body_height,
		"while the biggest clears fewer of its own (%.1f against %.1f)"
		% [last_rise / last.body_height, rise / first.body_height])


## Nine pockets, and the bar is the whole inventory.
func _test_the_bar() -> void:
	var bag := spider.bag
	check(SpiderInventory.SLOTS == 9, "nine slots (%d)" % SpiderInventory.SLOTS)
	check(bag.slots().size() == 9, "and the bar always has nine of them")
	check(bag.selected == 0, "starting on the first")

	var filled := 0
	for kind in bag.slots():
		if kind != null:
			filled += 1
	check(filled == bag.carried().size(),
		"what you carry is what is on the bar (%d)" % filled)
	check(bag.in_hand() == bag.slots()[0], "and the first pocket is in hand")

	bag.select(3)
	check(bag.selected == 3, "a number key picks a pocket outright")
	bag.select(20)
	check(bag.selected == 3, "and an impossible one is ignored, not wrapped")

	bag.scroll(1)
	check(bag.selected == 4, "the wheel steps along it")
	bag.select(8)
	bag.scroll(1)
	check(bag.selected == 0, "and wraps round the end")
	bag.scroll(-1)
	check(bag.selected == 8, "both ways")
	bag.select(0)


## Puts the wheel back on something spinnable, the way a fresh spider starts.
func _select_first_spinnable_again() -> void:
	builder._select_first_spinnable()


## A spider with a bite power of our choosing.
##
## The hunting rule turns on one comparison — the creature's size against the
## spider's bite — and by the time the hunt test runs, the real spider has eaten
## its way to a Huntsman, which out-bites everything in the game. Checking the
## rule against it could only ever come out one way. This lets the check state
## both halves.
class PretendSpider extends Node3D:
	var bite := 1

	func stage() -> GrowthStage:
		var tier := GrowthStage.new()
		tier.bite_power = bite
		tier.body_height = 0.25
		return tier


## Evolution: traits come from what you eat, by chance, and a trait is a body.
func _test_the_tree() -> void:
	var traits := spider.traits
	if not check(traits != null, "the spider has an evolutionary tree"):
		return
	check(traits.tree.size() == 9, "nine traits in it (%d)" % traits.tree.size())
	for which in SpiderTrait.BRANCH_NAMES.size():
		check(traits.branch(which).size() == 3,
			"%s runs three deep" % SpiderTrait.BRANCH_NAMES[which])

	var wings := traits.by_id("wing_buds")
	var lean := traits.by_id("hollow_frame")
	var bulk := traits.by_id("heavy_frame")
	if not check(wings != null and lean != null and bulk != null,
			"wings, a lean frame and a heavy one"):
		return
	check(wings.effect_line() != "" and bulk.effect_line().contains("size"),
		"each one says what it does, off its own numbers (%s)" % bulk.effect_line())

	# Every trait comes from something in the game, and everything in the game
	# carries something — a creature that could never change you is half a reason
	# to hunt it.
	var strays := PackedStringArray()
	for gift in traits.tree:
		for species_id in gift.carried_by:
			if PreyLibrary.find(species_id) == null:
				strays.append("%s from %s" % [gift.id, species_id])
	check(strays.is_empty(), "every trait comes from a creature that exists %s" % strays)
	var barren := PackedStringArray()
	for kind in PreyLibrary.load_species():
		var carries := false
		for gift in traits.tree:
			carries = carries or gift.carried_by.has(kind.id)
		if not carries:
			barren.append(kind.id)
	check(barren.is_empty(), "and every creature carries at least one %s" % barren)

	var fly := PreyLibrary.find("fly")
	var moth := PreyLibrary.find("moth")
	var ant := PreyLibrary.find("ant")
	var bat := PreyLibrary.find("bat")
	var fish := PreyLibrary.find("fish")
	if not check(fly != null and moth != null and ant != null and bat != null and fish != null,
			"a fly, a moth, an ant, a bat and a fish to reckon with"):
		return

	# The odds, rule by rule.
	check(traits.unlocked(wings), "a root is open from the start")
	check(not traits.unlocked(lean), "and what stands on it is not")
	check(is_equal_approx(traits.odds(wings, fly, 0), wings.chance),
		"a fly passes wings on to a spiderling at the trait's own chance (%d%%)"
		% roundi(wings.chance * 100.0))
	check(traits.odds(wings, ant, 0) == 0.0, "an ant does not carry them at all")
	check(traits.odds(lean, moth, 0) == 0.0,
		"and a moth cannot give a lean frame before the wings it stands on")
	var higher := traits.odds(wings, fly, 4)
	check(is_equal_approx(higher, wings.chance * traits.evolution_scale(4)) and higher > wings.chance,
		"further up the ladder the same fly is likelier to (%d%% at the fifth rung)"
		% roundi(higher * 100.0))
	check(is_equal_approx(traits.odds(wings, moth, 0, 1), wings.chance * traits.stretch),
		"one size past your bite doubles the odds (a moth, %d%%)"
		% roundi(traits.odds(wings, moth, 0, 1) * 100.0))
	check(traits.odds(wings, bat, 0, traits.sure_past) == 1.0,
		"and something %d sizes past it is a sure thing (a bat)" % traits.sure_past)
	traits.misses["wing_buds"] = 3
	check(is_equal_approx(traits.odds(wings, fly, 0), wings.chance * (1.0 + 3.0 * traits.pity)),
		"every miss makes the next meal likelier (%d%% after three)"
		% roundi(traits.odds(wings, fly, 0) * 100.0))
	traits.misses.clear()

	# The dice, on a spare set of traits with no body hanging off it, so thousands
	# of meals resize nothing.
	var spare := SpiderTraits.new()
	spare.tree = traits.tree
	spare.dice.seed = 20260930
	var hits := 0
	for i in 2000:
		spare.owned.clear()
		spare.misses.clear()
		if spare.digest(fly, 0) != null:
			hits += 1
	var rate := float(hits) / 2000.0
	check(absf(rate - wings.chance) < 0.025,
		"the dice keep to the odds: %.1f%% of first flies passed wings on, against %d%%"
		% [rate * 100.0, roundi(wings.chance * 100.0)])

	# Bad luck runs out. However the dice fall, a fly passes wings on by the meal the
	# misses make it certain — and every meal that did not counted toward it.
	spare.owned.clear()
	spare.misses.clear()
	var certain_by := ceili((1.0 / wings.chance - 1.0) / spare.pity) + 1
	var meals := 0
	var counted := true
	while not spare.has("wing_buds") and meals < certain_by:
		var before := spare.missed("wing_buds")
		if spare.digest(fly, 0) == null:
			counted = counted and spare.missed("wing_buds") == before + 1
		meals += 1
	check(spare.has("wing_buds"),
		"bad luck runs out: wings came within %d meals of a fly (took %d)" % [certain_by, meals])
	check(counted, "every meal that missed was counted")
	check(spare.missed("wing_buds") == 0, "and the count is forgotten once it comes")

	# A fish carries only what a spiderling cannot take yet. An ordinary meal of one
	# does nothing — but one far enough past your bite is a sure thing, and pays in
	# something else you could take.
	spare.owned.clear()
	spare.misses.clear()
	check(spare.carried(fish).is_empty(), "a fish carries nothing a spiderling can take")
	check(spare.digest(fish, 0) == null, "so a fish your own size changes nothing")
	var paid := spare.digest(fish, 0, fish.size_class - 1)
	check(paid != null and paid.depth == 0,
		"but one five sizes past your bite still pays (%s)"
		% (paid.display_name if paid != null else "nothing"))

	# A practice target off a post in the gym is drunk like anything else, but it
	# is not in the world, and nothing about it counts toward what you are.
	var post := load("res://game/data/training/dummy_post.tres") as PreySpecies
	if check(post != null, "a practice target to eat"):
		spare.owned.clear()
		check(spare.digest(post, 0, 5) == null,
			"which changes nothing, however far past your bite it is")
		spare.record(post)
		check(spare.eaten(post.id) == 0, "and is not counted in the larder")
	spare.free()

	check(traits.owned.is_empty(), "none of that touched the spider")

	# The rule all of that rests on, through the real path: take down something you
	# had no business taking on, drink it to the end, and it changes you. This is
	# the one section that lets the spider evolve.
	traits.evolving = true
	var heard: Array = []
	var listen := func(gift: SpiderTrait, source: String) -> void:
		heard.append([gift.id, source])
	traits.gained.connect(listen)
	var wasp := spawn("wasp", spider.global_position + Vector3(0.3, 0.2, 0.0))
	if check(wasp != null, "a wasp to take on"):
		wasp.move_speed = 0.0
		wasp.aggression = 0.0
		var past := wasp.size_class - spider.stage().bite_power
		check(past >= traits.sure_past,
			"two sizes past a spiderling's bite (%d)" % past)
		# Bundled, as a web that out-held it would leave it, and put on the line so
		# it can be drunk where it lies.
		wasp.bundle()
		await physics_frame
		spider.tether.hook(wasp)
		var got: float = await eat(wasp, 900)
		check(not is_instance_valid(wasp) or wasp.eaten,
			"drunk to the end (+%.1f biomass)" % got)
		check(traits.eaten("wasp") == 1, "the larder counts it")
		check(heard.size() == 1, "and it changed the spider — one trait (%s)" % str(heard))
		if heard.size() == 1:
			check(heard[0][1] == "Wasp" and traits.has(str(heard[0][0])),
				"and says it came from the wasp (%s)" % str(heard[0]))
		if spider.tether.is_towing():
			spider.tether.cut()
	traits.gained.disconnect(listen)
	traits.evolving = false

	# A trait is a body, not a stat line: taking one resizes the spider the same way
	# growing a tier does, through the same signal.
	traits.owned.clear()
	traits.changed.emit()
	await physics_frame
	check(traits.take(wings), "wings can be taken")
	check(not traits.take(wings), "but not twice")
	check(traits.unlocked(lean), "and what stood on them is open now")

	# Wings are a lighter fall, with no key to hold.
	check(traits.glide() > 0.0, "wings cancel some of a fall (%.2f)" % traits.glide())
	var gliding := _fall_gain(traits.glide())
	var plummeting := _fall_gain(0.0)
	check(gliding < plummeting,
		"so a fall picks up less speed (%.2f against %.2f m/s per tenth)"
		% [gliding, plummeting])
	check(gliding > 0.0, "and it is still a fall — wings flatten it, not stop it")

	var tier := spider.growth.stage_index
	var tall := spider.stage().body_height
	var capsule := spider.collision.shape as CapsuleShape3D
	check(traits.take(lean), "a hollow frame can be taken once the wings are there")
	await physics_frame
	check(spider.stage().body_height < tall,
		"which makes the spider smaller (%.3f -> %.3f)" % [tall, spider.stage().body_height])
	check(is_equal_approx(capsule.height, spider.stage().body_height),
		"and the collider went with it")
	check(spider.growth.stage_index == tier,
		"without moving it down a tier — you grew lean, not younger")
	check(spider.growth.base_stage().body_height > spider.stage().body_height,
		"so it stands under its own tier (%.3f under %.3f)"
		% [spider.stage().body_height, spider.growth.base_stage().body_height])
	check(spider.stage().move_speed > spider.growth.base_stage().move_speed,
		"and is quicker than its tier for it")

	# Bulk is the other end of the same ruler.
	var small := spider.stage().body_height
	check(traits.take(bulk), "a heavy frame can be taken alongside it")
	await physics_frame
	check(spider.stage().body_height > small,
		"and puts the size back on (%.3f -> %.3f)" % [small, spider.stage().body_height])

	await _test_fangs()
	_test_the_tree_on_screen()


## Venom's gift: a kill that needs no web behind it.
func _test_fangs() -> void:
	var fangs := traits.by_id("hunting_fangs")
	if not check(fangs != null, "the tree has fangs at the end of venom"):
		return
	check(not traits.has_fangs(), "a spider without them needs a web")

	# Something inside the bite either way, so this is about the fangs and not
	# about the bite power they also carry.
	#
	# That needs a creature inside the bite but not inside half of it, and with a
	# bite of one there is none: the smallest creature is size one, and one
	# doubled is exactly the bite plus the bonus fangs carry. From a bite of two
	# the moth sits in the gap.
	grow_to_bite(2)
	var bite := spider.stage().bite_power
	var quarry: PreySpecies = null
	for kind in PreyLibrary.load_species():
		if kind.size_class <= bite and kind.size_class * 2 > bite + fangs.bite_bonus:
			quarry = kind
			break
	if not check(quarry != null,
			"there is a creature inside a bite of %d but not by half" % bite):
		return

	var at := spider.global_position + Vector3(0.35, 0.0, 0.0)
	clear_prey_near(at, 3.0, null)
	var caught := spawn(quarry.id, at)
	await physics_frame
	if not check(caught != null, "there is a %s to try it on" % quarry.display_name):
		return
	check(not caught.is_stuck(), "which is not in a web")
	spider.jaws.handle(caught)
	check(is_instance_valid(caught) and not caught.eaten,
		"and cannot be taken bare-fanged, however small it is")

	var line: Array[String] = ["paralytic", "digestive", "hunting_fangs"]
	for step in line:
		var gift := traits.by_id(step)
		check(traits.take(gift), "the venom line goes up in order — %s" % gift.display_name)
	await physics_frame
	check(traits.has_fangs(), "and ends in fangs")

	# Fangs change the verdict, and the verdict is the whole claim: bare-fanged
	# the same press refused and said to use a web (checked above), and with them
	# it starts a meal.
	#
	# Checked at the verdict rather than by draining the beetle dry. It used to
	# drain it in one call; now it is thirty biomass of meal, and this test runs
	# last in a level holding fifty-odd webs and a restocking spawner, where a
	# long meal has plenty to interrupt it — the run that taught me this drank
	# sixteen of the thirty and then stopped. Whether a drain completes is what
	# the feeding tests are for, on a clean slab; what this one is about is fangs.
	Input.action_press("interact")
	spider.jaws.handle(caught)
	var started: bool = spider.feeding == caught
	Input.action_release("interact")
	await process_frame
	await process_frame
	check(started,
		"with which the %s can be taken where it stands, no web needed"
		% quarry.display_name)


## The evolution screen: a map of what eating could make you, not a shop.
func _test_the_tree_on_screen() -> void:
	var hud := level.get_node_or_null("HUD") as SpiderHUD
	if not check(hud != null, "the level has a HUD to hang the tree off"):
		return
	var screen := hud.get_node_or_null(NodePath("TraitTree")) as TraitTree
	if not check(screen != null, "which built a tree screen"):
		return
	check(not screen.open and not screen.visible, "shut until it is asked for")
	check(screen._cards.size() == traits.tree.size(),
		"with a card for every trait (%d)" % screen._cards.size())

	var owned := screen.from_text("wing_buds")
	check(owned.contains("yours"), "an owned trait says so (%s)" % owned)
	var locked := screen.from_text("girder_legs")
	check(locked.begins_with("needs"), "a locked one names what it stands on (%s)" % locked)

	# An open one says what carries it and the odds from each, as the spider is now.
	var gift := traits.by_id("broad_back")
	var open_text := screen.from_text("broad_back")
	if check(gift != null and traits.unlocked(gift) and not traits.has(gift.id),
			"a broad back is open by now"):
		check(open_text.contains("Beetle") and open_text.contains("%"),
			"an open one lists what carries it, with the odds (%s)" % open_text)
		var bite := spider.stage().bite_power
		var sure := false
		for kind in traits.carriers(gift):
			sure = sure or kind.size_class - bite >= traits.sure_past
		if sure:
			check(open_text.contains("sure"),
				"down to the ones a meal of is a sure thing (%s)" % open_text)

	screen.show_tree()
	check(screen.open and screen.visible, "[E] opens it")
	check(screen._larder.text != "", "with the larder across the top (%s)" % screen._larder.text)
	screen.close()
	check(not screen.open and not screen.visible, "and [E] again puts it away")


## Speed one tenth of a second of falling adds, at a given glide. Measured well
## above the level so nothing is underfoot to cut the fall short.
func _fall_gain(glide: float) -> float:
	var climb := spider.climb
	var was_glide := climb.glide
	var was_where := spider.global_position
	climb.glide = glide
	climb.release()
	spider.global_position = Vector3(12.0, 400.0, 0.0)
	spider.velocity = Vector3(0.0, -1.0, 0.0)
	climb._move_airborne(0.1, Vector2.ZERO)
	var gained := -1.0 - spider.velocity.y
	climb.glide = was_glide
	spider.global_position = was_where
	spider.velocity = Vector3.ZERO
	return gained

# --- softening something too big for one shot ----------------------------

## The tandem the whole thing is for: silk you can put on a creature a bit at a
## time, until a web that could never have held it can.
##
## A bolt used to wrap whatever it touched, whatever the size of it, which made a
## spiderling's first shot a guaranteed kill on a wasp and left both of the slower
## ways of catching things with nothing to do.
func _test_softening_something_big() -> void:
	grow_to_spin("orb_web")
	select_pattern("orb_web")
	ignore_shot_cooldown()
	var slab := add_slab(Vector3(90, 0.0, 170), Vector3(16, 0.5, 16))
	await physics_frame
	stand_on(slab.global_position + Vector3(0, 0.25, 0))
	await process_frame
	clear_prey_near(slab.global_position, 22.0, null)
	await physics_frame

	var orb := pattern_named("orb_web")
	if not check(orb != null, "an orb web to throw"):
		return
	var hold: float = orb.hold_strength

	# The two ends of the ladder, against the same silk.
	var fly := spawn_fly(spider.global_position + Vector3(1.2, 0.3, 0.0))
	var wasp := spawn("wasp", spider.global_position + Vector3(2.4, 0.3, 0.0))
	if not check(fly != null and wasp != null, "a fly and a wasp to try it on"):
		return
	fly.move_speed = 0.0
	wasp.move_speed = 0.0
	wasp.aggression = 0.0
	await physics_frame

	check(fly.taken_cleanly_by(hold),
		"an orb web takes a fly outright (%.1f thrash against %.1f)"
		% [fly.total_thrash(), hold * Prey.ESCAPE_MARGIN])
	check(not wasp.taken_cleanly_by(hold),
		"and cannot take a wasp, which is four times the fight (%.1f)"
		% wasp.total_thrash())

	# Binding is worth a measured share of the way, not a guess.
	var share := wasp.bind_share(hold)
	check(share > 0.0 and share < 1.0,
		"one hit of it is worth %d%% of a wasp" % roundi(share * 100.0))
	var needed := ceili((1.0 - share) / share)
	note("so a wasp needs %d softening hit(s) before the same web takes it" % needed)

	# Put that much on it and the same silk now can.
	check(not wasp.bind(share), "one hit does not close it")
	check(not wasp.wrapped, "a wasp with one hit on it is still loose")
	check(wasp.bound > 0.0, "but it is carrying silk (%d%%)" % roundi(wasp.bound * 100.0))
	check(wasp.thrash_power() < wasp.struggle_power,
		"which is fight it no longer has (%.2f of %.2f)"
		% [wasp.thrash_power(), wasp.struggle_power])

	for i in needed:
		wasp.bind(share)
	check(wasp.taken_cleanly_by(hold),
		"wrapped enough, the orb web can take it after all (%d%% on it)"
		% roundi(wasp.bound * 100.0))

	# And it comes off if you walk away, so chipping is a burst and not a siege.
	var loose := spawn("wasp", spider.global_position + Vector3(3.6, 0.3, 0.0))
	if check(loose != null, "another wasp, to leave alone"):
		loose.move_speed = 0.0
		loose.aggression = 0.0
		loose.bind(0.5)
		var was: float = loose.bound
		await run_frames(120)
		check(loose.bound < was,
			"silk works off a creature you leave alone (%d%% from %d%%)"
			% [roundi(loose.bound * 100.0), roundi(was * 100.0)])
		check(loose.bound > 0.0,
			"but not all at once — two seconds is not a reprieve (%d%%)"
			% roundi(loose.bound * 100.0))


## Silk stays on a creature that tears out of a web, because the next attempt on it
## should start from where the last one got to.
func _test_silk_stays_on_what_tore_loose() -> void:
	grow_to_spin("orb_web")
	var slab := add_slab(Vector3(-90, 0.0, 170), Vector3(14, 0.5, 14))
	await physics_frame
	stand_on(slab.global_position + Vector3(0, 0.25, 0))
	await process_frame
	clear_prey_near(slab.global_position, 20.0, null)
	await physics_frame

	var runner := spawn("wasp", spider.global_position + Vector3(1.4, 0.3, 0.0))
	if not check(runner != null, "a wasp to lose"):
		return
	runner.move_speed = 0.0
	runner.aggression = 0.0
	runner.bind(0.4)
	await physics_frame
	var carried: float = runner.bound
	check(carried > 0.0, "with silk on it (%d%%)" % roundi(carried * 100.0))

	var web := await _sheet_at(spider.global_position + Vector3(1.4, 0.4, 0.0))
	if not check(web != null, "and a sheet web that cannot keep it"):
		return
	await physics_frame
	var tore: bool = await wait_until(func() -> bool: return not runner.is_stuck(), 400)
	if check(tore, "it tears out, which is what a sheet web does to a wasp"):
		check(is_equal_approx(runner.bound, carried),
			"and the silk it was fighting in is still on it (%d%%)"
			% roundi(runner.bound * 100.0))


## The one relationship the softening loop stands on, and the one nothing else
## would notice breaking: silk has to go on faster than it comes off.
##
## A shot is shot_cooldown seconds apart and a hit is worth bind_share of the
## creature. If the wait costs most of a hit back, every shot nets nothing and
## there is no softening loop — which is exactly what the first cut did, at four
## points a shot. The two numbers live in different files and neither reads like
## it owns this, so it is checked here against both of them rather than trusted.
func _test_silk_outlasts_the_wait() -> void:
	grow_to_spin("orb_web")
	select_pattern("orb_web")
	var orb := pattern_named("orb_web")
	if not check(orb != null, "an orb web to reckon with"):
		return

	var wait: float = builder.shot_cooldown * maxf(orb.spin_time, 0.1)
	check(wait > 0.0, "a shot costs a wait of %.1fs" % wait)

	var sample := spawn("wasp", spider.global_position + Vector3(6.0, 0.4, 0.0))
	if not check(sample != null, "a wasp to measure against"):
		return
	sample.move_speed = 0.0
	sample.aggression = 0.0
	var share: float = sample.bind_share(orb.hold_strength)
	var lost: float = Prey.BIND_SHRUG * wait
	check(lost < share * 0.5,
		"and the wait costs back %d%% of a hit, not most of it (%.3f of %.3f)"
		% [roundi(100.0 * lost / share), lost, share])

	# Two hits a cooldown apart have to leave it takeable, or nothing is.
	var needed := 1.0 - share
	var after_two := share - lost + share
	check(after_two >= needed,
		"so two hits a wait apart get past what the web needs (%.2f against %.2f)"
		% [after_two, needed])
	sample.queue_free()


## The whole thing end to end, with real bolts rather than arithmetic: the bolt
## actually asks the rule, which is the bug this was written for — a direct hit
## used to wrap whatever it touched and never asked anything.
##
## How many hits a hard catch adds up to is stated against the numbers in
## [method _test_softening_something_big]; grinding it out with real shots would
## cost the suite half a minute of waiting out recatch timers to say the same
## thing. What is here is the part only the real thing can show: which side of the
## rule each pattern falls on.
func _test_it_takes_more_than_one_shot() -> void:
	# Grown once, up front. Both halves then run against the same spider at the
	# same range, so the pattern is the only thing that differs — growing in the
	# middle moves the body and the aim with it, and the second half was quietly
	# shooting somewhere else.
	grow_to_spin("orb_web")
	ignore_shot_cooldown()
	var slab := add_slab(Vector3(-150, 0.0, 90), Vector3(16, 0.5, 16))
	await physics_frame
	# Left looking at the floor, the way stand_on leaves it: the aim ray has to
	# land on something for aim_point to mean anything, and a horizontal look
	# across an empty slab hits nothing and quietly keeps the last one — which is
	# how the first draft of this shot at a wasp 187 metres away and passed.
	stand_on(slab.global_position + Vector3(0, 0.25, 0))
	await run_frames(4)
	clear_prey_near(slab.global_position, 24.0, null)
	await physics_frame

	# The starter web, at point-blank range, against something four times the fight
	# it can hold.
	select_pattern("sheet_web")
	builder._update_aim()
	var sheet_landed := 0.0
	var tough := spawn("wasp", builder.aim_point + Vector3(0, 0.4, 0))
	if not check(tough != null, "a wasp to shoot at"):
		return
	tough.move_speed = 0.0
	tough.aggression = 0.0
	await physics_frame
	builder._cooling = 0.0
	if check(builder.shoot(), "a sheet web thrown straight at it"):
		await wait_until(func() -> bool: return not builder.shot_in_flight(), 240)
		await run_frames(4)
		check(not tough.is_bundled(),
			"does not take a wasp in one — a sheet web is not up to it")
		sheet_landed = tough.bound
		check(tough.bound > 0.0,
			"but it costs the wasp %d%% of its fight" % roundi(tough.bound * 100.0))
		var loose: bool = await wait_until(
			func() -> bool: return not tough.is_stuck(), 400)
		check(loose, "it tears out of the web that came with the shot")
		check(tough.bound > 0.0,
			"still wearing the silk, so the next shot starts from there (%d%%)"
			% roundi(tough.bound * 100.0))
	tough.queue_free()
	clear_webs()
	await physics_frame

	# And the better web is worth more per shot, which is the trade the wheel is
	# for. Not "takes it outright": a bolt at a creature is silk on the creature
	# and nothing else now, so what a heavier pattern buys is fewer shots.
	#
	# Stood up again first: the wait for the first wasp to tear loose is six seconds
	# of the spider settling onto the slab, and it sank far enough that a bolt fired
	# straight down went past the second one rather than through it.
	stand_on(slab.global_position + Vector3(0, 0.25, 0))
	await run_frames(4)
	select_pattern("orb_web")
	builder._update_aim()
	var second := spawn("wasp", builder.aim_point + Vector3(0, 0.4, 0))
	if not check(second != null, "another wasp, and a better web for it"):
		return
	second.move_speed = 0.0
	second.aggression = 0.0
	await physics_frame
	builder._cooling = 0.0
	if check(builder.shoot(), "an orb web thrown the same way"):
		await wait_until(func() -> bool: return not builder.shot_in_flight(), 240)
		await run_frames(4)
		check(second.bound > sheet_landed,
			"puts on far more silk for the same shot (%d%% against a sheet web's %d%%)"
			% [roundi(second.bound * 100.0), roundi(sheet_landed * 100.0)])
		check(second.bound > 0.5,
			"enough that the next one finishes it (%d%%)" % roundi(second.bound * 100.0))
	second.queue_free()


# --- taking the larder home ----------------------------------------------

## A web is a larder, and a larder you have to stand next to in the open is worth
## less than one you can take with you. Click a net and it comes down: what was in
## it arrives at your feet as bundles, and the web is gone.
##
## No new key for it: left mouse has always meant "silk connects me to that", and
## the tether is what it asks first.
##
## This replaced dragging the web home on a rope. The rope was fiddly and it made
## the catch depend on the trip — walk it through a corner and half of it spilled —
## and the thing you actually wanted was the contents, not a web you could no
## longer use anyway.
func _test_taking_a_web_home() -> void:
	var tether := spider.tether
	grow_to_spin("orb_web")
	var slab := add_slab(Vector3(60, 0.0, -60), Vector3(14, 0.5, 14))
	await physics_frame
	stand_on(slab.global_position + Vector3(0, 0.25, 0))
	await run_frames(4)
	clear_prey_near(slab.global_position, 20.0, null)
	await physics_frame

	var centre := spider.global_position + Vector3(0, 0.4, -1.2)
	var web := await _sheet_at(centre)
	if not check(web != null, "a sheet web to take home"):
		return
	check(web.can_be_collected(), "which is a net, so there is something to take")

	var catch_it := spawn_fly(centre)
	if not check(catch_it != null, "with a fly caught in it"):
		return
	catch_it.move_speed = 0.0
	if not check(await wait_until(func() -> bool: return catch_it.is_stuck(), 120),
			"properly stuck in it"):
		return
	check(not catch_it.is_bundled(), "and hanging there rather than bundled")

	aim_at(web.global_position)
	await physics_frame
	check(tether.aimed_web() == web, "the cross is on it")
	var webs_before := web_count()
	if not check(tether.take_aimed(), "and the click takes it"):
		return
	await run_frames(4)

	check(not is_instance_valid(web) or web.is_queued_for_deletion(),
		"the web is gone (%d webs, started %d)" % [web_count(), webs_before])
	if not check(is_instance_valid(catch_it) and not catch_it.eaten,
			"but the fly is not"):
		return
	# The whole point: it keeps its silk. Freed, it would simply fly off, and a
	# larder you have to chase is not a larder.
	check(catch_it.is_bundled(), "it comes back bundled rather than loose")
	check(catch_it.held_by() == null, "and held by nothing, since there is no web")
	check(catch_it.global_position.distance_to(spider.global_position) < 2.0,
		"at your feet rather than where the web was (%.2fm)"
		% catch_it.global_position.distance_to(spider.global_position))

	# And it is a meal like any other bundle, by the ordinary in-reach rule.
	check(spider.jaws.within_reach(catch_it), "close enough to drink")
	var got: float = await eat(catch_it, 900)
	check(got > 0.0, "and drinking it works (+%.1f biomass)" % got)

	# Something still fighting comes too. Taking the web is taking the catch: a
	# catch that squirmed off because it happened to be mid-struggle would be a
	# coin flip rather than a decision.
	var second := await _sheet_at(spider.global_position + Vector3(0, 0.4, -1.4))
	if not check(second != null, "a second web, for something that is still fighting"):
		return
	var fighter := spawn_fly(second.global_position)
	if not check(fighter != null, "with a fly in it"):
		return
	fighter.move_speed = 0.0
	if not check(await wait_until(func() -> bool: return fighter.is_stuck(), 120),
			"stuck, and not yet wrapped"):
		return
	check(not fighter.wrapped, "still fighting it, in fact")
	aim_at(second.global_position)
	await physics_frame
	check(tether.take_aimed(), "the click takes that one too")
	await run_frames(4)
	check(is_instance_valid(fighter) and fighter.is_bundled(),
		"and it is bundled all the same, not shaken loose")
	if is_instance_valid(fighter):
		fighter.queue_free()


## Where the click has to land, and what it must not be distracted by.
##
## Two ways it went wrong in play, both of them the pick rather than the taking.
##
## The web was found by measuring its *origin point* against the line of sight,
## with the tolerance cargo uses — a slice of the screen, half a metre at ten. A
## bundle is small enough to be a point and a web is a surface metres across, so
## only a shot at the dead centre landed: probed across the face of a sheet web it
## came back one time in fifteen, and the other fourteen clicks fell through to the
## grapple. It is cast at the web's own collider now.
##
## And a catch inside a web counted as cargo, so the moment one tired out or got
## wrapped it answered for the web and the click tethered the creature out instead.
## Taking the web takes everything in it, so a catch in one is not the tether's any
## more — but a bundle lying loose in *front* of a web still is, and that is the
## third check here: nearest along the line of sight wins, both ways round.
func _test_the_click_finds_the_whole_web() -> void:
	var tether := spider.tether
	grow_to_spin("orb_web")
	var slab := add_slab(Vector3(140, 0.0, 90), Vector3(16, 0.5, 16))
	await physics_frame
	stand_on(slab.global_position + Vector3(0, 0.25, 0))
	await run_frames(6)
	clear_prey_near(slab.global_position, 24.0, null)
	await physics_frame

	var centre := spider.global_position + Vector3(0, 0.5, -2.0)
	var web := await _sheet_at(centre)
	if not check(web != null, "a sheet web to point at"):
		return

	# Across the face, not just the middle of it.
	var found := 0
	var tried := 0
	for dx in [-0.45, 0.0, 0.45]:
		for dy in [-0.45, 0.0, 0.45]:
			aim_at(centre + Vector3(dx, dy, 0.0))
			await physics_frame
			tried += 1
			if tether.aimed_web() == web:
				found += 1
	check(found == tried,
		"the cross finds it anywhere on its face, not only dead centre (%d of %d)"
		% [found, tried])

	# A catch settled in it does not answer for it.
	var settled := spawn_fly(centre)
	if not check(settled != null, "a fly in it"):
		return
	settled.move_speed = 0.0
	if not check(await wait_until(func() -> bool: return settled.is_stuck(), 120),
			"stuck in it"):
		return
	settled.wrap()
	await physics_frame
	check(settled.is_secured() and settled.held_by() == web,
		"wrapped, and still hanging in the web")
	check(not tether.can_carry(settled),
		"which is not something to put a line on — the web it is in is")
	aim_at(centre)
	await physics_frame
	check(tether.aimed_cargo() == null, "so the cross is not on cargo")
	if not check(tether.take_aimed(), "and the click takes the web"):
		return
	await run_frames(4)
	check(not is_instance_valid(web) or web.is_queued_for_deletion(),
		"the web came down")
	check(is_instance_valid(settled) and settled.is_bundled(),
		"with the fly bundled at your feet, rather than towed out of it")
	if is_instance_valid(settled):
		settled.queue_free()
	await physics_frame

	# The other way round: a bundle on the floor in front of a web is what you
	# pointed at, and the web behind it is not.
	var second := await _sheet_at(spider.global_position + Vector3(0, 0.5, -3.0))
	if not check(second != null, "another web, further off"):
		return
	var loose := spawn_fly(spider.global_position + Vector3(0, 0.3, -1.0))
	if not check(loose != null, "and a bundle lying between you and it"):
		return
	loose.move_speed = 0.0
	loose.bundle()
	await physics_frame
	check(loose.is_bundled() and loose.held_by() == null,
		"loose on the floor, in no web at all")
	aim_at(loose.global_position)
	await physics_frame
	check(tether.aimed_cargo() == loose, "the cross is on it")
	if not check(tether.take_aimed(), "and the click deals with it"):
		return
	check(tether.cargo == loose,
		"by putting a line on the bundle (%s)" % tether.cargo_name())
	check(is_instance_valid(second) and not second.is_queued_for_deletion(),
		"leaving the web behind it standing")
	tether.cut()
	loose.queue_free()


## A road is not a larder. Lines are the floor you walk on, and picking one up
## would be pulling that up — so the click on one stays a grapple, which is how
## you get onto it in the first place.
func _test_a_road_is_not_collected() -> void:
	var tether := spider.tether
	grow_to_spin("orb_web")
	var slab := add_slab(Vector3(-60, 0.0, -60), Vector3(14, 0.5, 14))
	await physics_frame
	stand_on(slab.global_position + Vector3(0, 0.25, 0))
	await run_frames(4)
	clear_prey_near(slab.global_position, 20.0, null)
	await physics_frame

	select_pattern("frame_line")
	var road := await _run_a_line(spider.global_position + Vector3(-0.8, 0.4, -1.0),
		spider.global_position + Vector3(0.8, 0.4, -1.0))
	if not check(road != null, "a frame line, which is a road"):
		return
	check(not road.can_be_collected(), "and not something to take down")
	aim_at(road.global_position)
	await physics_frame
	check(tether.aimed_web() == null, "so the cross finds nothing to take")
	check(not tether.take_aimed(), "and the click falls through to the grapple")
	check(is_instance_valid(road) and not road.is_queued_for_deletion(),
		"leaving the road where it is")


## Silk costs a creature its legs as well as its fight, which is the thing that
## makes softening worth doing before a chase rather than only before a web.
##
## Without it nothing the player does makes a fast creature catchable: a fleeing
## wasp runs at 4.7 and the fastest tier on the ladder is 4.8, so the answer to
## "it is faster than me" was to grow, and nothing else.
func _test_silk_slows_what_it_sticks_to() -> void:
	var quarry := spawn("wasp", spider.global_position + Vector3(4.0, 0.4, 0.0))
	if not check(quarry != null, "a wasp, which outruns most of the ladder"):
		return
	quarry.aggression = 0.0
	var loose := quarry.current_speed()
	check(is_equal_approx(loose, quarry.move_speed),
		"loose, it runs at its own pace (%.2f)" % loose)

	quarry.bind(0.5)
	var slowed := quarry.current_speed()
	check(slowed < loose * 0.6,
		"half wrapped, it is down to %.2f from %.2f" % [slowed, loose])

	# The number that matters is whether the chase is on: fleeing is the fastest
	# a creature ever goes, and a spiderling is the slowest the spider ever is.
	var ladder := WebLibrary.default_stages()
	var spiderling: float = ladder[0].move_speed
	check(loose * 1.8 > spiderling,
		"at full pelt it outruns a spiderling (%.2f against %.2f)"
		% [loose * 1.8, spiderling])
	check(slowed * 1.8 < spiderling,
		"and half wrapped it does not (%.2f against %.2f)"
		% [slowed * 1.8, spiderling])

	# Never quite stopped: something held still where it stands without being
	# wrapped would be a pin, and that is a different mechanic.
	quarry.bound = 0.99
	check(quarry.current_speed() > 0.0,
		"wrapped to the last, it still crawls (%.2f)" % quarry.current_speed())
	quarry.queue_free()


# --- venom, once something else has put it there --------------------------

## What venom is worth, against what a bolt is worth.
##
## Venom used to arrive by hand: click something alive and the spider threw itself
## at it and bit it. That is gone, and with it the only caller of [method Prey.poison]
## — the drip is kept because it is a shape something else will want, not because
## anything produces it today. Which is exactly why the numbers are worth holding:
## un-called tuning is tuning nobody notices has drifted.
##
## Shooting is the efficient way to soften something: it lands a large share at
## once from somewhere safe. Venom trades that away for working while you are
## elsewhere, so it has to stay the slower of the two — otherwise whatever ends up
## delivering it makes shooting pointless.
func _test_what_venom_is_worth() -> void:
	var sample := spawn("wasp", spider.global_position + Vector3(5.0, 0.4, 0.0))
	if not check(sample != null, "a wasp to reckon against"):
		return
	sample.move_speed = 0.0
	sample.aggression = 0.0

	var orb := pattern_named("orb_web")
	if not check(orb != null, "and an orb web to compare with"):
		return
	var bolt_share: float = sample.bind_share(orb.hold_strength)
	var bolt_wait: float = builder.shot_cooldown * maxf(orb.spin_time, 0.1)
	var bolt_rate := bolt_share / bolt_wait
	var venom_rate: float = Prey.VENOM_BIND - Prey.BIND_SHRUG

	check(venom_rate > 0.0,
		"venom goes on faster than it comes off, or it does nothing (%.3f)" % venom_rate)
	check(venom_rate < bolt_rate,
		"and slower than shooting, so silk from across the room stays worth it (%.3f against %.3f a second)"
		% [venom_rate, bolt_rate])

	# Venom twice over is not twice the venom. Without this the answer to
	# everything is another dose, and a drip that stacks outruns the bolt it is
	# meant to sit behind.
	sample.poison(8.0)
	var one := sample.venom
	sample.poison(8.0)
	check(is_equal_approx(sample.venom, one),
		"and a second dose refreshes rather than stacks (%.1fs, not %.1f)"
		% [sample.venom, one * 2.0])
	sample.queue_free()


## A bolt that reaches a creature has found what it was aimed at. It used to also
## open a web where the creature happened to be standing, which plants one on the
## floor every time you shoot something low — a web nobody chose to put there.
##
## What a hit does instead is silk: enough wraps it where it stands, short of
## enough costs it fight and speed and the next bolt starts from there. Then it is
## a bundle to put a line on and drag off.
func _test_a_bolt_at_a_creature_leaves_no_web() -> void:
	grow_to_spin("orb_web")
	select_pattern("orb_web")
	ignore_shot_cooldown()
	var slab := add_slab(Vector3(120, 0.0, -40), Vector3(16, 0.5, 16))
	await physics_frame
	stand_on(slab.global_position + Vector3(0, 0.25, 0))
	await run_frames(4)
	clear_prey_near(slab.global_position, 24.0, null)
	clear_webs()
	await physics_frame

	builder._update_aim()
	var low := spawn("wasp", builder.aim_point + Vector3(0, 0.35, 0))
	if not check(low != null, "a wasp down near the floor"):
		return
	low.move_speed = 0.0
	low.aggression = 0.0
	await physics_frame

	var before := web_count()
	builder._cooling = 0.0
	if not check(builder.shoot(), "a bolt straight at it"):
		return
	await wait_until(func() -> bool: return not builder.shot_in_flight(), 240)
	await run_frames(6)

	check(web_count() == before,
		"leaves no web behind it (%d, started %d)" % [web_count(), before])
	check(low.bound > 0.0,
		"but the silk is on the wasp (%d%%)" % roundi(low.bound * 100.0))
	check(low.current_speed() < low.move_speed or low.move_speed <= 0.0,
		"which is speed it no longer has")
	low.queue_free()


## HITCH: a click on something alive ties it to the ground you are standing on.
##
## It keeps its legs — this is not a pin — but only inside a radius, so what beats
## the creature is where you tied it rather than the line itself. And it comes
## undone: what spends the silk is the creature's own [method Prey.thrash_power],
## which is the number silk already on it has been eating into, so a softened
## catch stays tied far longer than a fresh one and the two mechanics multiply.
func _test_hitching_something_to_the_ground() -> void:
	# Off by default — see `_test_clicking_something_alive_grapples_past_it` — so
	# this section switches it on, and [method WebSuite.rewind_live_line] puts it
	# back before anything else clicks at a creature.
	live.move = LiveLine.Move.HITCH
	var slab := add_slab(Vector3(-180, 0.0, 60), Vector3(20, 0.5, 20))
	await physics_frame
	stand_on(slab.global_position + Vector3(0, 0.25, 0))
	if not check(await wait_until(
			func() -> bool: return spider.climb.is_attached(), 120),
			"standing on something to tie a line to"):
		return
	clear_prey_near(slab.global_position, 30.0, null)
	await physics_frame

	var mark := spawn("wasp", spider.global_position + Vector3(2.2, 0.3, 0.0))
	if not check(mark != null, "a wasp in front of you"):
		return
	mark.aggression = 0.0
	await physics_frame
	aim_at(mark.global_position)
	await physics_frame
	check(live.aimed_creature() == mark, "under the cross and still on its feet")

	var footing := spider.global_position
	send_action(spider.input_place_anchor)
	await run_frames(4)
	var hitch := live.hitch_on(mark)
	if not check(hitch != null, "the click ties it to the floor"):
		return
	check(hitch.length > 0.0 and hitch.length < live.reach(),
		"on a line shorter than silk reaches, so it is a radius and not a leash to nowhere (%.1fm of %.1f)"
		% [hitch.length, live.reach()])
	check(hitch.anchor.distance_to(footing) < 1.0,
		"anchored where you were standing (%.2fm off)"
		% hitch.anchor.distance_to(footing))

	# A second click on the same creature is not a second line.
	live._hitch_cooling = 0.0
	send_action(spider.input_place_anchor)
	await run_frames(4)
	var lines := 0
	for node in spider.get_tree().get_nodes_in_group("silk_hitches"):
		if (node as SilkHitch).cargo == mark:
			lines += 1
	check(lines == 1, "and clicking again does not tie a second one (%d)" % lines)

	# Now put it well outside its radius and let go: the line hauls it back.
	var out := hitch.anchor + Vector3(hitch.length * 1.6, 0.4, 0.0)
	mark.global_position = out
	mark.move_speed = 0.0
	await physics_frame
	check(hitch.is_taut(), "walked out past the end of it, the line goes tight")
	var before := hitch.anchor.distance_to(mark.global_position)
	await run_frames(30)
	check(hitch.anchor.distance_to(mark.global_position) < before,
		"and pulls it back in (%.1fm from %.1f)"
		% [hitch.anchor.distance_to(mark.global_position), before])

	# Fighting it is what spends it, and silk already on the creature is fight it
	# does not have. Two identical hitches, one on a half-wrapped wasp.
	var fresh: float = mark.thrash_power()
	mark.bind(0.5)
	check(mark.thrash_power() < fresh,
		"silk on it costs it what it can pull with (%.1f from %.1f)"
		% [mark.thrash_power(), fresh])

	var left := hitch.strength
	await run_frames(30)
	check(hitch.strength < left,
		"a wasp on the end of a tight line wears it through (%.1f from %.1f)"
		% [hitch.strength, left])

	# And it always gets free in the end, which is the difference between this and
	# a pin. Wound down to nothing rather than waited out: what is being checked is
	# that running out cuts the line, not how long that takes — the wearing itself
	# is the check above.
	hitch.strength = 0.0
	await run_frames(4)
	check(live.hitch_on(mark) == null, "and when it runs out, the line parts")
	check(not is_instance_valid(hitch) or hitch.is_queued_for_deletion(),
		"and takes itself away with it")
	mark.queue_free()


## A click on something alive reads straight through it, as the game ships.
##
## [member LiveLine.move] is `NOTHING` by default and this is what that means: the
## aim cast is `WORLD | WEB_WALK` and prey is on its own layer, so the silk finds
## the *wall behind* the creature and the spider goes past it — the same thing the
## click does when no creature is there at all. That is the whole contract of the
## button, and a click that means two things depending on a couple of pixels costs
## you confidence in the grapple as well as in the other move.
func _test_clicking_something_alive_grapples_past_it() -> void:
	check(live.move == LiveLine.Move.NOTHING,
		"the game ships with a click on something alive doing nothing special")
	var middle := Vector3(-120, 0.0, -40)
	var slab := add_slab(middle, Vector3(22, 0.5, 22))
	await physics_frame
	stand_on(slab.global_position + Vector3(0, 0.25, 0))
	if not check(await wait_until(
			func() -> bool: return spider.climb.is_attached(), 120),
			"standing on something to push off"):
		return
	clear_prey_near(middle, 30.0, null)
	await physics_frame

	# Somewhere to grapple to, inside what silk reaches at this size rather than
	# at a distance picked by hand — the tier decides the reach, so the tier has
	# to decide where the wall goes.
	var span: float = minf(builder.silk_reach() * 0.6, 8.0)
	add_slab(spider.global_position + Vector3(0, 2.5, span + 0.3),
		Vector3(22, 6.0, 0.6))
	await physics_frame
	aim_at(spider.global_position + Vector3(0, 0, span * 3.0))
	await physics_frame
	builder._update_aim()
	if not check(builder.aim_valid, "and a wall in front of you to grapple to"):
		return

	# Right in the line of sight, between the spider and that wall.
	var mark := spawn("wasp", spider.global_position + Vector3(0, 0.1, span * 0.4))
	if not check(mark != null, "a wasp standing in the way"):
		return
	mark.move_speed = 0.0
	mark.aggression = 0.0
	await physics_frame
	aim_at(mark.global_position)
	await physics_frame

	# The premise: the cross really is on the creature. Without this the rest of
	# the section is a grapple at an empty wall passing for a grapple past a wasp.
	var forward := spider.view.aim_forward()
	var offset := mark.global_position - spider.view.aim_origin()
	var gap := (offset - forward * offset.dot(forward)).length()
	check(gap < 0.6, "the cross is on the wasp (%.2fm off the line)" % gap)
	check(not spider.tether.grab_aimed(),
		"and it is not something already caught, so the line does not want it")

	builder._update_aim()
	var to_wasp := spider.global_position.distance_to(mark.global_position)
	var to_aim := spider.global_position.distance_to(builder.aim_point)
	check(builder.aim_valid and to_aim > to_wasp + 0.5,
		"the aim reads through it to the surface behind (%.1fm against %.1fm)"
		% [to_aim, to_wasp])

	send_action(spider.input_place_anchor)
	await physics_frame
	check(spider.climb.is_grappling(), "so the click grapples")
	await wait_until(func() -> bool: return not spider.climb.is_grappling(), 240)
	await run_frames(4)
	check(spider.global_position.distance_to(mark.global_position) > to_wasp,
		"which carries you past the wasp rather than onto it (%.1fm away, was %.1f)"
		% [spider.global_position.distance_to(mark.global_position), to_wasp])
	check(not mark.is_poisoned(), "and nothing was bitten on the way")
	mark.queue_free()
