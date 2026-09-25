extends SceneTree

## Headless smoke test for the web building loop.
##
##     godot --headless --script res://tests/web_smoke_test.gd
##
## Loads the sandbox level and drives the spider through building each kind of
## web, catching prey in one, wrapping and draining it, growing a size tier and
## pulling a web back down. Exits non-zero if anything comes back wrong.

const LEVEL_PATH := "res://addons/character-controller/example/main/level.tscn"

var _checks := 0
var _failures := 0
var _level: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var level: Node = load(LEVEL_PATH).instantiate()
	root.add_child(level)
	current_scene = level
	_level = level
	await physics_frame
	await physics_frame

	var spider := root.get_tree().get_first_node_in_group("spider") as SpiderPlayer
	if not _check(spider != null, "spider is in the level"):
		_finish()
		return

	var webs := level.get_node("Webs") as Node3D
	var builder := spider.web_builder
	builder.notice.connect(func(text: String) -> void: print("        (%s)" % text))

	# Somewhere flat and open to work in.
	spider.global_position = Vector3(12, 0.5, 0)
	await physics_frame

	_test_starting_state(spider, builder)
	await _test_input_map(spider, builder)
	await _test_aiming(spider, builder)
	await _test_building_a_net(spider, builder, webs)
	await _test_catching(spider, level, webs)
	await _test_strands(spider, builder, webs)
	await _test_growth(spider, builder)
	await _test_tripline_alert(spider, builder, webs, level)
	await _test_pressure_snare(spider, builder, webs, level)
	await _test_trigger_links(spider, builder, webs, level)
	await _test_weave_modes(spider, builder, webs)
	await _test_rings_of_silk(spider, builder, webs)
	await _test_living_on_the_web(spider, builder, webs, level)
	await _test_tuning_dials(spider, builder, webs, level)
	await _test_saved_designs(spider, builder, webs)
	await _test_placing_a_web(spider, builder, webs)
	await _test_a_web_fits_the_space(spider, builder)
	await _test_spitting_a_web_at_something(spider, builder, level, webs)
	await _test_throwing_a_bolt(spider, builder, level, webs)
	await _test_species(spider, builder, level)
	await _test_tethering(spider, level)
	await _test_wrapped_things_fall(spider, builder, level, webs)
	await _test_shooting(spider, builder, level, webs)
	await _test_taking_aim(spider, builder, level)
	await _test_a_shot_fits_a_corner(spider, builder, webs)
	await _test_silk_sits_on_what_it_sticks_to(spider, builder)
	_test_a_spiders_jump()
	await _test_the_bar(spider)
	await _test_the_larder(spider, builder, webs, level)
	await _test_three_lines(spider, builder)
	await _test_a_web_ends_with_its_catch(builder, webs, level)
	await _test_the_bag(spider, level, webs, builder)
	await _test_sandbox_wiring(level, spider)
	await _test_demolish(builder, webs)
	# Last, deliberately: buying traits reshapes the body for good, and every
	# test above this line was written against a spider the ladder alone made.
	await _test_the_tree(spider, level)

	_finish()


func _test_starting_state(spider: SpiderPlayer, builder: WebBuilder) -> void:
	var stage := spider.stage()
	_check(stage.display_name == "Spiderling", "starts as a spiderling")
	var capsule := spider.collision.shape as CapsuleShape3D
	_check(is_equal_approx(capsule.height, stage.body_height),
		"collider matches the size tier (%.2f)" % capsule.height)
	_check(is_equal_approx(spider.head.position.y, stage.body_height * 0.32),
		"eye height scaled to the body")
	_check(builder.patterns.size() >= 6, "loaded %d web patterns" % builder.patterns.size())
	_check(builder.unlocked_patterns().size() == 3,
		"frame line, tripline and sheet web to start with (%d)"
		% builder.unlocked_patterns().size())
	# Q spins nets and refuses strands, so a wheel parked on a strand is a
	# place key that silently does nothing. That is exactly how it shipped.
	var starting := builder.current_pattern()
	_check(starting != null and starting.shape == WebPattern.Shape.NET,
		"the wheel starts on a web Q can actually spin (%s)"
		% (starting.display_name if starting != null else "nothing"))


func _test_input_map(spider: SpiderPlayer, builder: WebBuilder) -> void:
	for action in ["web_build_mode", "web_place", "web_cancel", "web_finish",
			"web_next_pattern", "web_prev_pattern", "web_remove", "interact",
			"device_mode", "web_throw_mode", "web_tether", "web_shoot",
			"skill_tree", "hotbar_1", "hotbar_9", "hotbar_next", "toggle_help"]:
		_check(InputMap.has_action(action), "input action '%s' is set up" % action)

	# A headless display server cannot capture the mouse, so lift that gate.
	spider.require_captured_mouse = false

	var started_with := builder.current_pattern()
	_send(spider.input_next_pattern)
	await process_frame
	_check(builder.current_pattern() != started_with, "the wheel changes pattern")
	_send(spider.input_prev_pattern)
	await process_frame
	_check(builder.current_pattern() == started_with, "and changes back")

	# Grappling is not a mode any more, and Q spins a web where you point
	# rather than putting you in a state.
	_check(not builder.building, "there is no build mode to be in")
	_send(spider.input_build_mode)
	await process_frame
	_check(not builder.building, "and Q does not put you in one")
	builder.cancel_place()
	_send_release(spider.input_build_mode)


func _send(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	# Input is accumulated by default, so push it through now.
	Input.flush_buffered_events()


func _send_release(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _test_aiming(spider: SpiderPlayer, builder: WebBuilder) -> void:
	builder.start()
	# Look straight down at the floor. Aim lives on the camera rig now.
	spider.view.pitch = -PI / 2.0
	await process_frame
	builder._update_aim()
	_check(builder.aim_valid, "aiming at the floor finds an anchor point")
	_check(builder.aim_point.distance_to(spider.global_position) < spider.stage().anchor_range,
		"anchor point is inside the tier's reach")

	# Aiming at open sky should not find anything.
	spider.view.pitch = PI / 2.0
	await process_frame
	builder._update_aim()
	_check(not builder.aim_valid, "aiming at nothing gives no anchor")
	_check(builder.problem == WebBuilder.Problem.NO_SURFACE, "and says why")
	builder.stop()


func _test_building_a_net(spider: SpiderPlayer, builder: WebBuilder, webs: Node3D) -> void:
	_select_pattern(builder, "sheet_web")
	builder.start()
	var centre := spider.global_position + Vector3(0, 0.4, -1.0)

	var corners := _square(centre, 0.6)
	for point in corners:
		builder.add_anchor(point)
	_check(_web_count(webs) == 3, "three lines behind four anchors (%d)" % _web_count(webs))
	_check(builder.enclosed_area() > 0.0,
		"the run encloses %.2f m2" % builder.enclosed_area())

	builder.finish()
	await physics_frame

	var net := _newest_web(webs, "sheet_web") as WebNet
	if not _check(net != null, "a sheet web was woven inside it"):
		return
	_check(net.mesh_instance != null and net.mesh_instance.mesh.get_surface_count() > 0,
		"the web has a mesh")
	_check(net.catch_area != null, "the web has a catch volume")
	_check(net.area > 0.0, "the web encloses %.2f m2" % net.area)
	_check(net.global_position.distance_to(centre) < 0.5, "the web sits where it was strung")
	_check(net.durability > 0.0 and net.durability == net.max_durability, "it starts intact")
	_check(builder.anchors.is_empty(), "the run resets after weaving")
	_check(builder.building, "build mode stays on for the next one")

	# The frame outlives the web: roads are not traps.
	var lines_before := _count_pattern(webs, "frame_line")
	_check(lines_before == 4, "the ring left four lines standing (%d)" % lines_before)
	builder.stop()

	# Too few anchors must not weave anything.
	builder.start()
	builder.add_anchor(centre + Vector3(0, 1.5, 0))
	var webs_before := _web_count(webs)
	builder.finish()
	_check(_web_count(webs) == webs_before, "a lone anchor weaves nothing")
	builder.stop()


## Vertices in a web's drawn silk, or 0. A stand-in for "how much thread".
func _mesh_verts(web: WebStructure) -> int:
	if web == null or web.mesh_instance == null or web.mesh_instance.mesh == null:
		return 0
	if web.mesh_instance.mesh.get_surface_count() == 0:
		return 0
	return web.mesh_instance.mesh.surface_get_array_len(0)


func _count_pattern(webs: Node3D, pattern_id: String) -> int:
	var total := 0
	for child in webs.get_children():
		var web := child as WebStructure
		if web != null and not web.is_queued_for_deletion() and web.pattern.id == pattern_id:
			total += 1
	return total


func _test_catching(spider: SpiderPlayer, level: Node, webs: Node3D) -> void:
	var net := _first_web(webs) as WebNet
	if net == null:
		return
	_clear_prey_near(level, net.to_global(net.centre_local), net.radius * 3.0, null)
	await physics_frame
	await process_frame
	var fly := _spawn_fly(level, net.to_global(net.centre_local))
	await physics_frame
	await physics_frame

	if not _check(fly.is_stuck(), "a fly that flew into the web is stuck"):
		return
	_check(net.snared_count() == 1, "the web knows it caught something")

	# Struggling should be wearing the web down.
	var durability_before := net.durability
	for i in 10:
		await physics_frame
	_check(net.durability < durability_before, "struggling damages the web")

	spider._handle_prey(fly)
	_check(fly.wrapped, "the spider wrapped it")

	var steady := net.durability
	for i in 10:
		await physics_frame
	_check(is_equal_approx(net.durability, steady), "a wrapped fly stops wrecking the web")

	var biomass_before := spider.growth.biomass
	spider._handle_prey(fly)
	await process_frame
	_check(spider.growth.biomass > biomass_before, "draining it feeds the spider")
	_check(not is_instance_valid(fly) or fly.eaten, "the fly is gone")
	# And the web goes with it. A web is a larder while it holds something and
	# nothing once it does not — see _test_a_web_ends_with_its_catch.
	_check(not is_instance_valid(net), "and the web comes down with the catch")


func _test_strands(spider: SpiderPlayer, builder: WebBuilder, webs: Node3D) -> void:
	_select_pattern(builder, "trip_line")
	builder.start()
	var base := spider.global_position + Vector3(1.5, 0.3, 0)
	builder.add_anchor(base)
	builder.add_anchor(base + Vector3(0, 0, 1.2))
	await physics_frame

	var trip := _find_web(webs, "trip_line") as WebStrand
	if not _check(trip != null, "a tripline was spun"):
		return
	_check(trip.catch_area != null, "the tripline watches for crossings")
	_check(trip.get_node_or_null("Walkway") != null,
		"and you can walk along it, because every line is a road")
	builder.stop()


func _test_growth(spider: SpiderPlayer, builder: WebBuilder) -> void:
	var before_height := (spider.collision.shape as CapsuleShape3D).height
	var gained := spider.growth.feed(60.0, "test")
	await physics_frame
	_check(gained > 0, "eating enough grows the spider %d tier(s)" % gained)
	var stage := spider.stage()
	var capsule := spider.collision.shape as CapsuleShape3D
	_check(capsule.height > before_height, "the body got bigger (%.2f -> %.2f)" % [before_height, capsule.height])
	_check(is_equal_approx(capsule.height, stage.body_height), "and matches the new tier")
	_check(is_equal_approx(spider.jump_ability.height, stage.jump_velocity), "jump scaled with it")
	_check(builder.unlocked_patterns().size() > 2, "bigger spider, more web patterns")

	# A bridge is a tier-2 unlock, so it should build now.
	_select_pattern(builder, "silk_bridge")
	builder.start()
	var base := spider.global_position + Vector3(-1.5, 0.4, 0)
	builder.add_anchor(base)
	builder.add_anchor(base + Vector3(0, 0, 1.4))
	await physics_frame
	var webs := spider.get_parent().get_node("Webs") as Node3D
	var bridge := _find_web(webs, "silk_bridge") as WebStrand
	if _check(bridge != null, "a silk bridge was spun"):
		_check(bridge.get_node_or_null("Walkway") != null, "the bridge is solid enough to walk on")
		_check(bridge.catch_area == null, "but it does not catch anything")
	builder.stop()


func _test_tripline_alert(spider: SpiderPlayer, builder: WebBuilder, webs: Node3D, level: Node) -> void:
	var trip := _find_web(webs, "trip_line") as WebStrand
	if not _check(trip != null, "the tripline is still up"):
		return
	var tripped := [false]
	trip.tripped.connect(func(_web: WebStructure, _who: Node3D) -> void: tripped[0] = true)

	var fly := _spawn_fly(level, (trip.point_a + trip.point_b) * 0.5)
	await physics_frame
	await physics_frame
	_check(tripped[0], "walking through a tripline reports it")
	_check(not fly.is_stuck(), "but a tripline does not hold anything")
	_check(trip.snared_count() == 0, "and catches nothing")
	fly.queue_free()
	await physics_frame


func _test_pressure_snare(spider: SpiderPlayer, builder: WebBuilder, webs: Node3D, level: Node) -> void:
	spider.growth.feed(40.0, "test")
	await physics_frame
	_check(spider.growth.stage_index >= 2, "grown enough to build snares")

	_select_pattern(builder, "pressure_snare")
	var centre := spider.global_position + Vector3(0, 0.5, 2.0)
	# Clear the patch first. Some of what wanders the level walks on the floor
	# now, and a trap on the floor is exactly what a walker blunders into — so
	# without this the snare is sometimes already sprung before the first check
	# looks at it, which is a test of where the beetles happened to be.
	_clear_prey_near(level, centre, 8.0, null)
	await physics_frame
	await process_frame

	builder.start()
	for point in _square(centre, 0.7):
		builder.add_anchor(point)
	builder.finish()
	builder.stop()
	await physics_frame

	var snare := _find_web(webs, "pressure_snare") as WebNet
	if not _check(snare != null, "a pressure snare was spun"):
		return
	_check(snare.armed, "it starts armed")
	_check(not snare.needs_rearm(), "and does not want re-arming yet")
	_check(snare.snared_count() == 0,
		"with nothing already in it (%d)" % snare.snared_count())

	# A beetle walks, which is the whole reason a trap on the ground exists.
	var quarry := _spawn_species(level, "beetle", snare.to_global(snare.centre_local))
	if not _check(quarry != null, "a beetle to spring it on"):
		return
	await physics_frame
	await physics_frame
	_check(quarry.is_stuck(), "the snare caught a beetle")
	_check(not snare.armed, "the snare has sprung")
	_check(snare.needs_rearm(), "and now needs re-arming")

	# While the snare holds it rigid the fly cannot fight back.
	var durability := snare.durability
	for i in 8:
		await physics_frame
	_check(is_equal_approx(snare.durability, durability), "held prey cannot damage a sprung snare")

	_check(snare.rearm(), "the snare re-arms")
	_check(snare.armed and not snare.needs_rearm(), "and is ready again")
	quarry.consume()
	await physics_frame


## The point of the whole feature: a tripline metres away springs a snare, and
## the snare grabs prey that never touched it.
func _test_trigger_links(spider: SpiderPlayer, builder: WebBuilder, webs: Node3D, level: Node) -> void:
	var base := spider.global_position + Vector3(0, 0.4, -3.0)

	_select_pattern(builder, "pressure_snare")
	builder.start()
	for point in _square(base, 0.7):
		builder.add_anchor(point)
	builder.finish()
	builder.stop()
	await physics_frame
	var snare := _newest_web(webs, "pressure_snare") as WebNet
	if not _check(snare != null, "a snare to wire up"):
		return

	# A tripline well clear of the snare — nothing that crosses it is anywhere
	# near the silk.
	var trip_at := base + Vector3(3.5, 0, 0)
	_select_pattern(builder, "trip_line")
	builder.start()
	builder.add_anchor(trip_at + Vector3(0, -0.4, -0.6))
	builder.add_anchor(trip_at + Vector3(0, -0.4, 0.6))
	builder.stop()
	await physics_frame
	var trip := _newest_web(webs, "trip_line") as WebStrand
	if not _check(trip != null, "a tripline to wire it to"):
		return

	# Wire them together, both ends by hand the way the player does.
	_check(builder.link_nodes(trip, snare), "the two webs can be wired together")
	await physics_frame
	_check(trip.links.has(snare), "the tripline is wired to the snare")
	_check(not builder.is_linking(), "wiring finished")
	_check(trip.link_mesh != null and trip.link_mesh.mesh != null,
		"the signal line is drawn so the player can read it")
	# A solid line would be one segment: two crossed quads, twelve vertices.
	# Dashes are what stop it reading as structural silk.
	var wire_verts: int = trip.link_mesh.mesh.surface_get_array_len(0)
	_check(wire_verts > 12 * 4, "and drawn dashed, not as another strand of silk (%d verts)"
		% wire_verts)

	# A fly loitering near the snare, but not in it.
	var centre := snare.to_global(snare.centre_local)
	var bystander := _spawn_fly(level, centre + Vector3(0, 0, 1.3))
	await physics_frame
	await physics_frame
	var reach: float = snare.radius * snare.pattern.signal_strike_factor
	_check(not bystander.is_stuck(), "a fly beside the snare is not caught by it")
	_check(centre.distance_to(bystander.global_position) > snare.radius,
		"and is genuinely outside the web")
	_check(centre.distance_to(bystander.global_position) < reach,
		"but inside the snare's strike range (%.1fm)" % reach)

	# The level keeps a dozen flies wandering about, and a sprung snare grabs
	# the nearest thing in reach — so anything else that has drifted into range
	# would win the race and make this a test of where the spawner's flies
	# happened to be. Clear the field first.
	_clear_prey_near(level, centre, reach, bystander)
	await physics_frame
	await process_frame

	# Now set the line off, far away.
	_check(snare.armed, "the snare is armed before anything happens")
	var crosser := _spawn_fly(level, (trip.point_a + trip.point_b) * 0.5)
	await physics_frame
	await physics_frame

	# Fire the line directly rather than trusting a fly to blunder into a thread
	# two centimetres thick inside two frames. That a fly trips a line is
	# _test_tripline_alert's job; what is being tested here is that the signal
	# reaches a snare across the room, and that should not ride on spawn luck.
	trip.fire()
	await physics_frame
	await physics_frame

	_check(not snare.armed, "a signal down the line springs the distant snare")
	_check(bystander.is_stuck(),
		"and the snare drags in a fly that never touched it")
	_check(snare.snared_count() == 1, "the snare has it")
	_check(not crosser.is_stuck(), "while the fly on the tripline walks on")

	# Tensing: a plain web wired to something pulls taut instead of springing.
	_select_pattern(builder, "orb_web")
	builder.start()
	for point in _square(base + Vector3(-2.5, 0, 0), 0.6):
		builder.add_anchor(point)
	builder.finish()
	builder.stop()
	await physics_frame
	var orb := _newest_web(webs, "orb_web") as WebNet
	if _check(orb != null, "an orb web to tense"):
		var relaxed := orb.hold_strength()
		orb.receive_signal(trip, 1)
		_check(orb.is_tensed(), "a signal draws a plain web tight")
		_check(orb.hold_strength() > relaxed,
			"which makes it hold better (%.1f -> %.1f)" % [relaxed, orb.hold_strength()])
		_check(orb.armed, "and does not spring it — there is nothing to spring")

	# A chain of webs must not be able to ring round forever.
	trip.links.append(orb)
	orb.links.append(trip)
	trip.fire()
	_check(true, "a loop of wired webs settles instead of hanging")
	orb.links.erase(trip)
	trip.links.erase(orb)

	# Pulling a web down takes its wiring with it. The bystander is simply
	# removed rather than drained — draining it would take the snare down with
	# it, and the snare is the thing being demolished on purpose here.
	bystander.queue_free()
	var had_links := trip.links.size()
	_check(had_links > 0, "the tripline still has wiring to lose")
	snare.demolish()
	await physics_frame
	_check(trip.links.size() == had_links - 1, "demolishing a web unwires it")
	_check(trip.link_mesh.mesh == null, "and its signal line stops being drawn")


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


func _test_weave_modes(spider: SpiderPlayer, builder: WebBuilder, webs: Node3D) -> void:
	_select_pattern(builder, "orb_web")
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
	_check(off_plane > 0.1, "the test anchors genuinely do not lie flat (%.2fm)" % off_plane)

	for mode in [WebGeometry.Weave.STRETCHED, WebGeometry.Weave.INSCRIBED]:
		var label := "stretched" if mode == WebGeometry.Weave.STRETCHED else "inscribed"
		var layout = WebGeometry.layout_net(corner, pattern, centre, 1.0, mode)
		_check(layout.valid, "%s: the corner web holds together" % label)
		_check(layout.rim.size() == corner.size(), "%s: every anchor is on the frame" % label)
		var drift := _worst_anchor_drift(corner, layout)
		_check(drift < 0.001, "%s: the frame stays on the anchors (%.4fm drift)" % [label, drift])

	# Stretched fills the whole outline; inscribed keeps a round spiral inside it.
	var stretched = WebGeometry.layout_net(corner, pattern, centre, 1.0,
		WebGeometry.Weave.STRETCHED)
	var inscribed = WebGeometry.layout_net(corner, pattern, centre, 1.0,
		WebGeometry.Weave.INSCRIBED)
	_check(inscribed.spiral_radius > 0.0, "inscribed: there is a sticky disc (%.2fm across)"
		% (inscribed.spiral_radius * 2.0))
	_check(inscribed.area < stretched.area,
		"inscribed: it catches over less than the whole outline (%.2f vs %.2f m2)"
		% [inscribed.area, stretched.area])
	_check(stretched.spiral_radius == 0.0, "stretched: sticky all the way to the frame")

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
	_check(fat_disc.spiral_radius > sliver_disc.spiral_radius * 4.0,
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
	var spun := _newest_web(webs, "orb_web") as WebNet
	if _check(spun != null, "an inscribed web was spun"):
		_check(spun.weave == WebGeometry.Weave.INSCRIBED, "and it remembers how")
		_check(spun.spiral_radius > 0.0, "with a sticky disc")
		var collider := spun.catch_area.get_child(0) as CollisionShape3D
		_check(collider.shape is CylinderShape3D, "and only that disc catches")
		spun.demolish()
	builder.toggle_weave()
	_check(builder.weave == WebGeometry.Weave.STRETCHED, "K switches the weave back")
	await physics_frame


## Three lines slung across a gap, none of them touching another at an end,
## still enclose the triangle where they cross — and that triangle can be woven.
func _test_rings_of_silk(spider: SpiderPlayer, builder: WebBuilder, webs: Node3D) -> void:
	spider.view.pitch = 0.0
	spider.view.face(Vector3.FORWARD)
	await physics_frame
	var origin := spider.view.aim_origin()
	var forward := spider.view.aim_forward()
	var centre := origin + forward * 2.0
	var across := forward.cross(Vector3.UP).normalized()
	var up := across.cross(forward).normalized()

	# A triangle made only by crossings: each line runs well past the others.
	var frame := _pattern(builder, "frame_line")
	var lines: Array[WebStrand] = []
	for pair in [
			[centre - across * 1.0 - up * 0.35, centre + across * 1.0 - up * 0.35],
			[centre - across * 0.5 - up * 0.7, centre + across * 0.5 + up * 0.7],
			[centre + across * 0.5 - up * 0.7, centre - across * 0.5 + up * 0.7]]:
		var line := WebStrand.spin(frame, pair[0], pair[1], 1.0)
		if line != null:
			line.place_in(webs)
			lines.append(line)
	_check(lines.size() == 3, "three lines strung across the gap")
	await physics_frame

	var rings := builder.loops()
	if not _check(rings.size() > 0, "their crossings enclose something (%d ring%s)"
			% [rings.size(), "" if rings.size() == 1 else "s"]):
		return
	var smallest = rings[rings.size() - 1]
	_check(smallest.area > 0.01, "the ring has real area (%.3f m2)" % smallest.area)
	_check(smallest.points.size() == 3, "and three corners (%d)" % smallest.points.size())

	# None of those corners is the end of a line: they are all crossings.
	var corners_on_ends := 0
	for corner in smallest.points:
		for line in lines:
			if corner.distance_to(line.point_a) < 0.05 or corner.distance_to(line.point_b) < 0.05:
				corners_on_ends += 1
	_check(corners_on_ends == 0, "every corner is a crossing, not a line end")

	_select_pattern(builder, "sheet_web")
	builder.start()
	var aimed = builder.aimed_loop()
	_check(aimed != null, "the ring is found under the crosshair")
	var woven := builder.fill_aimed_loop()
	builder.stop()
	await physics_frame
	_check(woven, "and can be woven in one go")

	var net := _newest_web(webs, "sheet_web") as WebNet
	if _check(net != null, "a web is standing in the ring"):
		net.demolish()
	for line in lines:
		if is_instance_valid(line):
			_check(true, "the lines are still there afterwards")
			break
	for line in lines:
		if is_instance_valid(line):
			line.demolish()
	await physics_frame

	# And every strand is rideable now, not just the ones meant as roads.
	var opt_in := false
	for entry in _pattern(builder, "trip_line").get_property_list():
		if entry.get("name", "") == "ridable":
			opt_in = true
	_check(not opt_in, "there is no opt-in for riding any more — all silk is a zipline")


func _pattern(builder: WebBuilder, id: String) -> WebPattern:
	for pattern in builder.patterns:
		if pattern.id == id:
			return pattern
	return null


## A spider lives on its web. It has to hold the spider's weight and still let
## prey fly into it, which is why silk gets its own collision layer.
func _test_living_on_the_web(spider: SpiderPlayer, builder: WebBuilder, webs: Node3D, level: Node) -> void:

	# A web lying flat on the ground — the case worth checking, because a trap
	# underfoot is the one that sounds like it needs to be a special object.
	var floor_height := spider.global_position.y - spider.stage().body_height * 0.4
	var centre := spider.global_position + Vector3(2.5, 0, 2.5)
	centre.y = floor_height + 0.05
	_select_pattern(builder, "sheet_web")
	builder.start()
	for offset in [Vector3(-0.7, 0, -0.7), Vector3(0.7, 0, -0.7),
			Vector3(0.7, 0, 0.7), Vector3(-0.7, 0, 0.7)]:
		builder.add_anchor(centre + offset)
	builder.finish()
	builder.stop()
	await physics_frame

	var mat := _newest_web(webs, "sheet_web") as WebNet
	if not _check(mat != null, "a web woven flat on the ground"):
		return
	_check(absf(mat.plane_normal.dot(Vector3.UP)) > 0.9, "lying flat, as asked")

	# It must be solid enough to stand on...
	var walkway := mat.get_node_or_null("Walkway") as StaticBody3D
	if not _check(walkway != null, "the web is something to stand on"):
		return
	_check(walkway.collision_layer & GameLayers.WEB_WALK != 0, "on the silk layer")
	_check(spider.collision_mask & GameLayers.WEB_WALK != 0, "which the spider collides with")
	_check(builder._climb.climbable_layers & GameLayers.WEB_WALK != 0,
		"and can climb about on")

	# ...without being solid to the things it is meant to catch.
	var fly := _spawn_fly(level, centre + Vector3(0, 1.0, 0))
	await physics_frame
	_check(walkway.collision_layer & fly.collision_mask == 0,
		"but prey passes straight through it")
	_check(mat.catch_area.collision_mask & fly.collision_layer != 0,
		"into the catch volume underneath")

	# And it really does catch something walking over it.
	fly.global_position = mat.to_global(mat.centre_local)
	await physics_frame
	await physics_frame
	_check(fly.is_stuck(), "a fly that wandered onto it is caught")
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
	_check(spider.climb.is_attached(), "the spider settles onto the web")
	_check(spider.global_position.y > floor_height,
		"standing on the silk rather than through it (%.2f vs floor %.2f)"
		% [spider.global_position.y, floor_height])
	mat.demolish()
	await physics_frame


func _test_tuning_dials(spider: SpiderPlayer, builder: WebBuilder, webs: Node3D, level: Node) -> void:
	_select_pattern(builder, "orb_web")
	var pattern := builder.current_pattern()
	var tuning := builder.tuning_for(pattern)
	_check(tuning.is_default(), "a pattern starts on standard settings")

	# Tension: holding power against durability.
	tuning.tension = WebTuning.STEPS - 1
	var tight := tuning.apply_to(pattern)
	tuning.tension = 0
	var slack := tuning.apply_to(pattern)
	_check(tight.hold_strength > pattern.hold_strength, "spun tight, a web holds harder")
	_check(tight.durability < pattern.durability, "and tears sooner")
	_check(slack.hold_strength < pattern.hold_strength, "spun slack, it holds less")
	_check(slack.durability > pattern.durability, "and lasts longer")
	_check(is_equal_approx(tight.spin_time, slack.spin_time),
		"tension is free either way — it is purely a trade")
	tuning.tension = WebTuning.NEUTRAL

	# Weight: everything against how long it takes to spin.
	tuning.weight = WebTuning.STEPS - 1
	var heavy := tuning.apply_to(pattern)
	_check(heavy.hold_strength > pattern.hold_strength
		and heavy.durability > pattern.durability, "heavy silk is better in every way")
	_check(heavy.spin_time > pattern.spin_time,
		"and that is what you pay for: longer before the next one (%.2fx)"
		% heavy.spin_time)
	_check(heavy.strand_thickness > pattern.strand_thickness, "you can see the difference")
	tuning.weight = WebTuning.NEUTRAL

	# Mesh: what you catch against what you spend.
	tuning.mesh = WebTuning.STEPS - 1
	var open_mesh := tuning.apply_to(pattern)
	tuning.mesh = 0
	var close_mesh := tuning.apply_to(pattern)
	_check(open_mesh.radial_count < close_mesh.radial_count
		and open_mesh.ring_count < close_mesh.ring_count,
		"an open mesh is fewer threads (%d vs %d spokes)"
		% [open_mesh.radial_count, close_mesh.radial_count])
	_check(open_mesh.min_catch_size > close_mesh.min_catch_size,
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
		var web := _newest_web(webs, "orb_web")
		# Measured off the drawn geometry: a coarse mesh is literally fewer
		# threads, and vertices are what fewer threads look like from here.
		costs[setting] = float(_mesh_verts(web))
		if web != null:
			_check(web.tuning != null and web.tuning.mesh == setting,
				"the web remembers the dials it was spun with")
			web.demolish()
		await physics_frame
	var fine: float = costs[0]
	var coarse: float = costs[WebTuning.STEPS - 1]
	_check(coarse < fine, "an open mesh really is fewer threads (%.0f vs %.0f verts)"
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
	var coarse_web := _newest_web(webs, "orb_web") as WebNet
	if _check(coarse_web != null, "a coarse web to test the gate on"):
		_check(coarse_web.pattern.min_catch_size > 1, "it is meshed for bigger prey")
		var fly := _spawn_fly(level, coarse_web.to_global(coarse_web.centre_local))
		await physics_frame
		await physics_frame
		_check(not fly.is_stuck(), "and a fly goes straight through it")
		fly.queue_free()
		coarse_web.demolish()
	builder.reset_dials()
	_check(builder.current_tuning().is_default(), "the dials can be put back to standard")
	await physics_frame


func _test_saved_designs(spider: SpiderPlayer, builder: WebBuilder, webs: Node3D) -> void:
	var base := spider.global_position + Vector3(-5.0, 0.4, 0.0)

	# A two-piece rig: snare plus a tripline wired to it.
	_select_pattern(builder, "pressure_snare")
	builder.start()
	for point in _square(base, 0.6):
		builder.add_anchor(point)
	builder.finish()
	builder.stop()
	_select_pattern(builder, "trip_line")
	builder.start()
	builder.add_anchor(base + Vector3(1.6, -0.4, -0.5))
	builder.add_anchor(base + Vector3(1.6, -0.4, 0.5))
	builder.stop()
	await physics_frame

	var snare := _newest_web(webs, "pressure_snare") as WebNet
	var trip := _newest_web(webs, "trip_line") as WebStrand
	if not _check(snare != null and trip != null, "a rig to keep"):
		return
	_check(snare.anchors.size() == 4, "a spun web remembers its anchors")
	_check(builder.link_nodes(trip, snare), "wired the rig together")

	# Keep it.
	var design := DesignLibrary.capture(trip, Vector3.FORWARD, spider.growth.stage_index)
	if not _check(design != null, "the rig can be captured as a design"):
		return
	_check(design.piece_count() == 2, "both webs came along (%d)" % design.piece_count())
	_check(design.link_count() == 1, "and so did the wiring")
	_check(design.anchors.size() == 6, "every anchor was recorded (%d)" % design.anchors.size())

	_check(DesignLibrary.store(design), "the design saves to disk")
	var reloaded := DesignLibrary.load_all()
	var found: WebDesign = null
	for candidate in reloaded:
		if candidate.id == design.id:
			found = candidate
	_check(found != null, "and loads back again")
	if found != null:
		_check(found.piece_count() == design.piece_count(), "with its pieces intact")
		_check(found.link_count() == design.link_count(), "and its wiring intact")

	# Put it down somewhere else.
	builder.designs = reloaded
	for i in builder.designs.size():
		if builder.designs[i].id == design.id:
			builder.design_index = i
	builder.placing_design = true
	builder.aim_valid = true
	builder.aim_point = spider.global_position + Vector3(0, 0.5, -7.0)
	builder.aim_normal = Vector3.UP

	var before_webs := _web_count(webs)
	# Aim is recomputed every frame, so remember where this went.
	var placed_at := builder.aim_point
	_check(builder.place_design(), "the design can be spun somewhere new")
	await physics_frame
	_check(_web_count(webs) == before_webs + 2, "both webs went up")

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
	_check(wired_copies == 1, "the copy is wired to itself, not the original (%d)" % wired_copies)
	_check(trip.links.has(snare), "the original rig is untouched")

	# There is no being too poor for one any more, so what is left to check is
	# that a second copy is a second copy: the same design, somewhere else,
	# going up whole rather than borrowing from the first.
	var before_second := _web_count(webs)
	builder.aim_valid = true
	builder.aim_point = spider.global_position + Vector3(0, 0.5, -11.0)
	builder.aim_normal = Vector3.UP
	_check(builder.place_design(), "the same design goes up again elsewhere")
	await physics_frame
	_check(_web_count(webs) == before_second + design.piece_count(),
		"whole, with all %d of its pieces" % design.piece_count())

	builder.placing_design = false
	DesignLibrary.forget(design)


func _test_sandbox_wiring(level: Node, spider: SpiderPlayer) -> void:
	var spawner := level.get_node_or_null("PreySpawner") as PreySpawner
	if _check(spawner != null, "the level has a prey spawner"):
		_check(spawner.alive_count() > 0, "it stocked %d creatures" % spawner.alive_count())
		_check(spawner.stock.size() > 1,
			"from a mixed stock (%d species)" % spawner.stock.size())
	var hud := level.get_node_or_null("HUD") as SpiderHUD
	if _check(hud != null, "the level has a HUD"):
		_check(hud.stage_label.text.contains(spider.stage().display_name),
			"the HUD is showing the current stage (%s)" % hud.stage_label.text)
		_check(hud.web_bar.max_value == 1.0, "and showing when the next web is ready")


func _test_demolish(builder: WebBuilder, webs: Node3D) -> void:
	# Its own, rather than whatever the suite left standing: webs come down with
	# their catch now, so leftovers are not something to count on.
	var web := await _sheet_at(builder, webs, Vector3(90.0, 3.0, 40.0))
	var count := _web_count(webs)
	if not _check(web != null, "there is a web to pull down"):
		return
	web.demolish()
	await process_frame
	_check(_web_count(webs) == count - 1, "the web is gone")


## Three lines at a time, and the fourth takes the oldest down.
##
## This is what replaced the silk budget on lines: a line costs nothing to
## make and everything to keep, so the question is which three you want rather
## than whether you can afford another.
func _test_three_lines(spider: SpiderPlayer, builder: WebBuilder) -> void:
	_check(WebBuilder.MAX_LINES == 3, "three at a time (%d)" % WebBuilder.MAX_LINES)

	# Start from a known register — the suite has been grappling for a while.
	for strand in builder.lines():
		strand.demolish()
	builder._lines.clear()
	spider.climb.standing_on = null
	await physics_frame
	_check(builder.line_count() == 0, "starting with none up (%d)" % builder.line_count())

	var base := Vector3(60.0, 4.0, 60.0)
	_select_pattern(builder, "frame_line")
	var first := _run_a_line(builder, base, base + Vector3(2, 0, 0))
	var second := _run_a_line(builder, base + Vector3(2, 0, 0), base + Vector3(4, 0, 0))
	var third := _run_a_line(builder, base + Vector3(4, 0, 0), base + Vector3(6, 0, 0))
	await physics_frame
	if not _check(first != null and second != null and third != null, "three lines go up"):
		return
	_check(builder.line_count() == 3, "and all three are counted (%d)" % builder.line_count())

	var fourth := _run_a_line(builder, base + Vector3(6, 0, 0), base + Vector3(8, 0, 0))
	await physics_frame
	await process_frame
	_check(fourth != null, "a fourth can still be run")
	_check(builder.line_count() == 3, "but there are still three (%d)" % builder.line_count())
	_check(not is_instance_valid(first), "because the oldest came down for it")
	_check(is_instance_valid(second) and is_instance_valid(third) and is_instance_valid(fourth),
		"and the other three are standing")

	# The one holding you up is never the one that goes. Dropping the floor out
	# from under the player is the game taking the controls off them.
	spider.climb.standing_on = second
	var fifth := _run_a_line(builder, base + Vector3(8, 0, 0), base + Vector3(10, 0, 0))
	await physics_frame
	await process_frame
	_check(fifth != null, "a fifth while standing on the oldest")
	_check(is_instance_valid(second), "leaves the line under your feet alone")
	_check(not is_instance_valid(third), "and takes the next oldest instead")
	spider.climb.standing_on = null

	for strand in builder.lines():
		strand.demolish()
	builder._lines.clear()
	await physics_frame
	await process_frame


## A web is a larder while it holds something, and nothing once it does not.
func _test_a_web_ends_with_its_catch(builder: WebBuilder, webs: Node3D,
		level: Node) -> void:
	var centre := Vector3(70.0, 3.0, 30.0)
	_clear_prey_near(level, centre, 14.0, null)
	var net := await _sheet_at(builder, webs, centre)
	if not _check(net != null, "a web to fill and then empty"):
		return

	var at := net.to_global(net.centre_local)
	var one := _spawn_fly(level, at)
	var two := _spawn_fly(level, at + Vector3(0.12, 0.0, 0.12))
	await _run_frames(4)
	if not _check(one != null and two != null and one.is_stuck() and two.is_stuck(),
			"two flies in it"):
		return
	_check(net.snared_count() == 2, "which it is holding (%d)" % net.snared_count())

	one.wrap()
	one.consume()
	await physics_frame
	_check(is_instance_valid(net), "taking one out leaves the web up")
	_check(net.snared_count() == 1, "still holding the other (%d)" % net.snared_count())

	two.wrap()
	two.consume()
	await physics_frame
	await process_frame
	_check(not is_instance_valid(net), "and the last one takes the web with it")

	# Escaping is not harvesting. Something getting away is the web losing, and
	# taking the web as well would be losing twice for one mistake.
	var again := await _sheet_at(builder, webs, centre)
	if not _check(again != null, "another web, to lose one out of"):
		return
	var runner := _spawn_fly(level, again.to_global(again.centre_local))
	await _run_frames(4)
	if _check(runner != null and runner.is_stuck(), "a fly in this one"):
		again.on_prey_escaped(runner)
		await physics_frame
		_check(is_instance_valid(again), "one that gets away leaves the web standing")
		_check(again.snared_count() == 0, "and empty (%d)" % again.snared_count())
	if is_instance_valid(again):
		again.demolish()
	if is_instance_valid(runner):
		runner.queue_free()
	await physics_frame


## Spins a sheet web round a point, the scripted way.
func _sheet_at(builder: WebBuilder, webs: Node3D, centre: Vector3) -> WebNet:
	_select_pattern(builder, "sheet_web")
	builder.start()
	for point in _square(centre, 0.7):
		builder.add_anchor(point)
	builder.finish()
	builder.stop()
	await physics_frame
	return _newest_web(webs, "sheet_web") as WebNet


## Runs a line the way arriving from a grapple does, without the journey.
func _run_a_line(builder: WebBuilder, from: Vector3, to: Vector3) -> WebStrand:
	builder._launched_from = from
	builder._arrive_at(to)
	var up := builder.lines()
	return up[up.size() - 1] if up.size() > 0 else null


## A shot fits its rim to the room, the way the held placer always did.
##
## The bolt is the visual; the web it opens is the placer's geometry. Aligning
## that web to the surface it hit made corners strictly worse than the old
## system, because a web flat against a wall casts all sixteen rim rays parallel
## to that wall and none of them find anything.
func _test_a_shot_fits_a_corner(spider: SpiderPlayer, builder: WebBuilder,
		webs: Node3D) -> void:
	var host := spider.get_parent()
	_select_pattern(builder, "orb_web")
	builder.shot_cooldown = 0.0
	builder._cooling = 0.0
	# First person, so the bolt leaves along exactly the line being aimed. In
	# third person the cross and the muzzle are apart, and a bolt meant for the
	# wall ahead can arrive at the one beside it instead.
	var was_third := spider.view.third_person
	if was_third:
		spider.view.toggle_mode()
		spider.view.update(spider.stage().body_height)

	# A flat wall first, for the number a corner has to beat.
	var flat_at := Vector3(-140.0, 0.0, -140.0)
	var flat_floor := _test_slab(host, flat_at, Vector3(10, 0.5, 10))
	_test_slab(host, flat_at + Vector3(4.0, 2.0, 0.0), Vector3(0.4, 4.0, 10.0))
	await physics_frame
	_stand_on(spider, flat_floor.global_position + Vector3(-1.0, 0.25, 0.0))
	spider.view.face(Vector3.RIGHT)
	spider.view.pitch = 0.0
	await _run_frames(4)
	var flat_anchored := await _shoot_and_read_rim(builder, webs)

	# Then an inside corner: walls close on both sides of the one it hits, near
	# enough that a web of this size can actually reach them. A shot is 1.26m
	# across at this tier, so walls four metres out would make this test pass on
	# nothing at all.
	var corner_at := Vector3(-170.0, 0.0, -140.0)
	var corner_floor := _test_slab(host, corner_at, Vector3(10, 0.5, 10))
	_test_slab(host, corner_at + Vector3(4.0, 2.0, 0.0), Vector3(0.4, 4.0, 10.0))
	_test_slab(host, corner_at + Vector3(0.0, 2.0, 1.0), Vector3(10, 4.0, 0.4))
	_test_slab(host, corner_at + Vector3(0.0, 2.0, -1.0), Vector3(10, 4.0, 0.4))
	await physics_frame
	_stand_on(spider, corner_floor.global_position + Vector3(-1.0, 0.25, 0.0))
	spider.view.face(Vector3.RIGHT)
	spider.view.pitch = 0.0
	await _run_frames(4)
	var corner_anchored := await _shoot_and_read_rim(builder, webs)

	_check(corner_anchored > flat_anchored,
		"a shot into a corner finds more to hold on to than one at a flat wall (%d against %d of %d)"
		% [corner_anchored, flat_anchored, WebBuilder.PLACE_SIDES])
	_check(corner_anchored > 0,
		"so the web really is fitted to the gap rather than pasted on stone")
	if was_third and not spider.view.third_person:
		spider.view.toggle_mode()


## Fires one and reports how many of the web's corners found something.
func _shoot_and_read_rim(builder: WebBuilder, webs: Node3D) -> int:
	var built: Array[WebStructure] = []
	var catcher := func(web: WebStructure) -> void: built.append(web)
	# Nothing else in the air: shoot() refuses while a bolt is still flying, and
	# the test before this one ends on a tap whose silk is still out there.
	await _wait_until(func() -> bool: return not builder.shot_in_flight(), 240)
	builder.web_built.connect(catcher)
	builder._cooling = 0.0
	if not _check(builder.shoot(), "a bolt goes off toward the wall"):
		builder.web_built.disconnect(catcher)
		return -1
	await _wait_until(func() -> bool: return not built.is_empty(), 240)
	builder.web_built.disconnect(catcher)
	var anchored := builder.place_anchored
	for web in built:
		if is_instance_valid(web):
			web.demolish()
	await physics_frame
	return anchored


## Silk stuck to a wall should look stuck to it.
func _test_silk_sits_on_what_it_sticks_to(spider: SpiderPlayer,
		builder: WebBuilder) -> void:
	var host := spider.get_parent()
	var slab := _test_slab(host, Vector3(200.0, 0.0, 200.0))
	await physics_frame
	var top := slab.global_position.y + 0.25
	_stand_on(spider, slab.global_position + Vector3(0, 0.25, 0))
	await process_frame
	_select_pattern(builder, "frame_line")
	builder._update_aim()

	# Straight down at the slab: the anchor is on it, not hovering over it.
	var lift := builder.aim_point.y - top
	_check(lift >= 0.0,
		"an anchor never sinks into the surface it found (%.4fm)" % lift)
	_check(lift < 0.05,
		"and sits on it rather than above it (%.4fm off, was a third of a metre)"
		% lift)
	_check(lift > 0.0,
		"clear of it by something, so silk does not z-fight the stone (%.4fm)" % lift)

	# The same for a web's rim: a corner stops a strand short, not a hand's width.
	_select_pattern(builder, "orb_web")
	if _check(builder.begin_place(), "a web to measure against the floor"):
		builder.place_radius = clampf(1.0, builder._min_place_radius(),
			builder._max_place_radius())
		builder._update_placement()
		var off := builder.place_centre.y - top
		_check(off >= 0.0 and off < 0.08,
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
func _test_the_bag(spider: SpiderPlayer, level: Node, webs: Node3D,
		builder: WebBuilder) -> void:
	var bag := spider.bag
	var placer := spider.device_placer
	placer.notice.connect(func(text: String) -> void: print("        (%s)" % text))

	_check(bag.kinds.size() >= 3, "loaded %d kinds of device" % bag.kinds.size())
	var venom := bag.kind_by_id("venom_spur")
	var lure := bag.kind_by_id("scent_lure")
	var bell := bag.kind_by_id("signal_bell")
	if not _check(venom != null and lure != null and bell != null,
			"venom spur, scent lure and signal bell all exist"):
		return
	_check(bag.count(venom) == 2, "starts carrying two venom spurs")
	_check(bag.total() == 4, "and four devices in all (%d)" % bag.total())

	# N is a mode of its own, and it takes the mouse off the web builder.
	spider.require_captured_mouse = false
	builder.start()
	_send(spider.input_device_mode)
	await process_frame
	_check(placer.active, "N opens the bag")
	_check(not builder.building, "and puts build mode away — one tool at a time")
	_send(spider.input_device_mode)
	await process_frame
	_check(not placer.active, "N closes it again")

	# The wheel walks what you are carrying, not every kind that exists.
	placer.start()
	var first := placer.current_kind()
	placer.cycle(1)
	_check(placer.current_kind() != first, "the wheel changes device")
	placer.cycle(-1)
	_check(placer.current_kind() == first, "and changes back")

	# A slab of our own to work on, so what's under the crosshair is known
	# rather than whatever the demo level happens to have at that coordinate.
	var slab := _test_slab(level, Vector3(30, 0.0, 30))
	await physics_frame
	_stand_on(spider, slab.global_position + Vector3(0, 0.25, 0))
	await process_frame

	# Placing costs a device out of the bag and no silk at all: the bag is the
	# whole limit on them, which is why they are allowed to be better than silk.
	_select_device(placer, "venom_spur")
	var carried_before := bag.count(venom)
	var spur := placer.place()
	await physics_frame
	if not _check(spur != null, "put a venom spur down"):
		return
	_check(bag.count(venom) == carried_before - 1, "it came out of the bag")
	_check(spur.is_inside_tree(), "it is in the level")
	_check(spur.global_position.distance_to(placer.aim_point) < 1.0,
		"where the crosshair was")

	# Two in the same spot would be a mess, and no use.
	placer._update_aim()
	_check(placer.problem == DevicePlacer.Problem.CROWDED,
		"won't stack a second one on top of it")

	# Taking it back up is the whole reason a device isn't a web.
	_stand_on(spider, spur.global_position)
	await process_frame
	_check(placer.aimed_device() == spur, "looking at it finds it")
	_check(placer.pick_up_aimed(), "picked it back up")
	await physics_frame
	await process_frame
	_check(bag.count(venom) == carried_before, "and it is back in the bag")
	_check(not is_instance_valid(spur) or spur.is_queued_for_deletion(),
		"and gone from the level")

	# Run out and the wheel moves off it rather than sitting on an empty slot.
	_stand_on(spider, slab.global_position + Vector3(0, 0.25, 3.0))
	await process_frame
	_select_device(placer, "scent_lure")
	var only_lure := placer.place()
	await physics_frame
	if not _check(only_lure != null, "put the one scent lure down"):
		return
	_check(bag.count(lure) == 0, "that was the last one")
	_check(placer.current_kind() != lure, "the wheel moved off the empty slot")
	only_lure.pick_up()
	await physics_frame
	await process_frame

	await _test_venom_kills_what_silk_only_holds(spider, level, slab)
	await _test_wiring_a_device(spider, webs, builder, placer, slab)
	placer.stop()
	slab.queue_free()


## A bare platform a long way from everything else, so a device test is only
## ever about the device.
func _test_slab(level: Node, at: Vector3, size := Vector3(12, 0.5, 12)) -> StaticBody3D:
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	var slab := StaticBody3D.new()
	slab.name = "TestSlab"
	slab.collision_layer = GameLayers.WORLD
	slab.collision_mask = 0
	slab.add_child(collider)
	level.add_child(slab)
	slab.global_position = at
	return slab


## Puts the spider on top of a point, looking straight down at it.
func _stand_on(spider: SpiderPlayer, at: Vector3) -> void:
	spider.climb.release()
	spider.global_position = at + Vector3(0, 0.6, 0)
	spider.velocity = Vector3.ZERO
	spider.view.face(Vector3(0, 0, -1))
	spider.view.pitch = -PI / 2.0


## The point of the venom spur: a dead fly can be drained whatever its size,
## and silk can only ever hold something until you get there.
func _test_venom_kills_what_silk_only_holds(spider: SpiderPlayer, level: Node,
		slab: StaticBody3D) -> void:
	var placer := spider.device_placer
	var bag := spider.bag
	_stand_on(spider, slab.global_position + Vector3(4.0, 0.25, 0))
	await process_frame

	_select_device(placer, "venom_spur")
	var spur := placer.place()
	await physics_frame
	if not _check(spur != null, "a venom spur to fire"):
		return

	var fly := _spawn_fly(level, spur.global_position + Vector3(0, 0.3, 0))
	fly.size_class = spider.stage().bite_power + 3
	await physics_frame
	_check(not fly.subdued, "a live fly beside it, too big to bite")

	spur.receive_signal(null, 0)
	await physics_frame
	_check(fly.subdued, "a signal into the spur kills it")
	_check(fly.wrapped, "a dead fly needs no wrapping")
	_check(spur.spent, "and the spur is used up")
	_check(not spur.can_receive_signal(), "a spent spur does nothing more")

	# Too big to bite, but dead — so drainable. That is the trade the item buys.
	var biomass_before := spider.growth.biomass
	spider.global_position = fly.global_position + Vector3(0, 0.2, 0)
	await physics_frame
	spider._handle_prey(fly)
	_check(spider.growth.biomass > biomass_before,
		"drained something bigger than the spider could ever bite")

	# A spent device still sweeps up, so the level doesn't fill with litter.
	var spur_kind := spur.kind
	var held := bag.count(spur_kind)
	_stand_on(spider, spur.global_position)
	await process_frame
	if _check(placer.aimed_device() == spur, "the spent spur is still there to sweep up"):
		_check(placer.pick_up_aimed(), "swept it up")
		_check(bag.count(spur_kind) == held, "and a spent one does not go back in the bag")


## A device is a node on the same signal graph a web is, which is the whole
## reason it is worth having: the tripline you already built sets it off.
func _test_wiring_a_device(spider: SpiderPlayer, webs: Node3D, builder: WebBuilder,
		placer: DevicePlacer, slab: StaticBody3D) -> void:
	var at := slab.global_position + Vector3(-4.0, 0.25, 0)
	_stand_on(spider, at)
	await process_frame

	_select_device(placer, "signal_bell")
	var bell := placer.place()
	await physics_frame
	if not _check(bell != null, "a bell to wire up"):
		return

	_select_pattern(builder, "trip_line")
	builder.start()
	builder.add_anchor(at + Vector3(-0.6, 0.4, 0))
	builder.add_anchor(at + Vector3(0.6, 0.4, 0))
	builder.stop()
	await physics_frame
	var trip := _newest_web(webs, "trip_line") as WebStrand
	if not _check(trip != null, "a tripline to wire it to"):
		return

	_check(builder.link_nodes(trip, bell), "a web can be wired to a device")
	_check(trip.links.has(bell), "the tripline sets off the bell")

	# The bell reports, so it can be a source as well as a target — that is what
	# lets a rig across the level reach you.
	_check(bell.can_signal(), "a bell has something to report")
	var heard := []
	var handle := func(text: String) -> void: heard.append(text)
	spider.notice.connect(handle)
	trip.fire()
	await physics_frame
	spider.notice.disconnect(handle)
	_check(heard.size() > 0, "setting the tripline off rings the bell")

	# Wiring is aimed at whatever is under the crosshair, device or web alike.
	_stand_on(spider, bell.global_position)
	await process_frame
	_check(builder.aimed_node() == bell, "the wiring cursor picks devices up too")

	# Taking a device away takes its wiring with it, rather than leaving a line
	# hanging off nothing. Count the links rather than looking for the bell
	# among them: it has been freed by now, and a freed instance is never found
	# in a typed array, so that version passed whether or not unlinking worked.
	var wired_before := trip.links.size()
	bell.pick_up()
	await physics_frame
	_check(trip.links.size() == wired_before - 1,
		"picking the bell up unwires it (%d → %d)" % [wired_before, trip.links.size()])
	trip.queue_free()


func _select_device(placer: DevicePlacer, id: String) -> void:
	for i in placer._inventory.kinds.size():
		if placer._inventory.kinds[i].id == id:
			placer.kind_index = i
			return
	_check(false, "device '%s' exists" % id)


# --- the larder ---------------------------------------------------------

## A web is meant to be somewhere you leave things and come back to. That only
## works if a catch survives you walking away, and if a web can be full — so
## this is about both: what a web keeps, and how much of it.
func _test_the_larder(spider: SpiderPlayer, builder: WebBuilder, webs: Node3D,
		level: Node) -> void:
	# Out in open air, well clear of everything else the suite has built, and
	# with a full spool so this measures catching rather than what is left over.
	var centre := Vector3(30, 3, 20)
	_select_pattern(builder, "sheet_web")
	builder.start()
	for point in _square(centre, 0.7):
		builder.add_anchor(point)
	builder.finish()
	builder.stop()
	await physics_frame
	var net := _newest_web(webs, "sheet_web") as WebNet
	if not _check(net != null, "a sheet web to fill up"):
		return
	_check(net.capacity() == 2, "a sheet web holds two (%d)" % net.capacity())
	_check(not net.is_full(), "and starts empty")

	# The tuning spine: a web keeps a catch if it can out-hold the whole thrash.
	# A sheet web is meant to be exactly good enough for a fly.
	var at := net.to_global(net.centre_local)
	var first := _spawn_fly(level, at)
	await physics_frame
	await physics_frame
	if not _check(first.is_stuck(), "a fly flew into it"):
		return
	var thrash := first.struggle_power * first.struggle_stamina
	_check(thrash < net.hold_strength() * Prey.ESCAPE_MARGIN,
		"a fly's whole thrash (%.1f) is inside a sheet web's hold (%.1f)"
		% [thrash, net.hold_strength() * Prey.ESCAPE_MARGIN])
	_check(first.is_fighting(), "it is fighting at first — this is when you can lose it")

	# Fast-forward the fight rather than waiting five real seconds through it.
	first._fight_left = 0.15
	var fought_out: bool = await _wait_until(
		func() -> bool: return not first.is_fighting(), 120)
	_check(fought_out, "it tires itself out")
	_check(first.is_stuck(), "and is STILL in the web — this is the whole point")
	_check(first.is_secured(), "the web is holding it for you now")
	_check(not first.wrapped, "without you having been there to wrap it")

	# A tired catch still pulls, but nothing like a fighting one: the web is a
	# store that wears out slowly, not a countdown.
	var settled_before := net.durability
	await _run_frames(20)
	var settled_drain := settled_before - net.durability

	var second := _spawn_fly(level, at)
	await physics_frame
	await physics_frame
	if not _check(second.is_stuck(), "a second fly lands in it"):
		return
	var fighting_before := net.durability
	await _run_frames(20)
	var fighting_drain := fighting_before - net.durability
	_check(fighting_drain > settled_drain,
		"a fighting catch costs the web far more than a settled one (%.4f vs %.4f)"
		% [fighting_drain, settled_drain])

	# Full means full. This is what makes a second site worth walking to.
	_check(net.is_full(), "two catches fill a sheet web")
	_check(net.status_line().contains("FULL"), "and it says so: %s" % net.status_line())
	var turned_away := _spawn_fly(level, at)
	await physics_frame
	await physics_frame
	_check(not turned_away.is_stuck(), "a full web catches nothing more")
	turned_away.queue_free()

	# A catch that stops existing without telling the web must not leave it
	# retired: being full is what stops it catching, so a dead reference would
	# be a web that never works again.
	second.queue_free()
	await physics_frame
	await process_frame
	await physics_frame
	_check(not net.is_full(), "a catch vanishing frees the slot back up")
	_check(net.snared_count() == 1, "and the web counts what is actually there")

	# Wrapping is now preservation: it stops the catch costing you the web.
	first.wrap()
	await physics_frame
	var wrapped_at := net.durability
	await _run_frames(20)
	_check(is_equal_approx(net.durability, wrapped_at),
		"wrapping a catch stops it wearing the web at all")

	await _test_a_web_can_lose_a_fight(builder, webs, level)
	net.demolish()


## The other half of the deal: a catch is only kept if the web was good enough
## for it. Something that out-fights the silk still gets away, and takes a bite
## of the web with it — which is what stops "leave a web anywhere" being free.
func _test_a_web_can_lose_a_fight(builder: WebBuilder, webs: Node3D, level: Node) -> void:
	var centre := Vector3(30, 3, 26)
	_select_pattern(builder, "sheet_web")
	builder.start()
	for point in _square(centre, 0.7):
		builder.add_anchor(point)
	builder.finish()
	builder.stop()
	await physics_frame
	var net := _newest_web(webs, "sheet_web") as WebNet
	if not _check(net != null and not net.is_full(), "a fresh web for a real fight"):
		return

	var brute := _spawn_fly(level, net.to_global(net.centre_local))
	brute.species = "Test Brute"
	brute.struggle_power = 40.0
	await physics_frame
	await physics_frame
	if not _check(brute.is_stuck(), "something much stronger hits the web"):
		return
	var thrash := brute.struggle_power * brute.struggle_stamina
	_check(thrash > net.hold_strength() * Prey.ESCAPE_MARGIN,
		"it out-fights the silk on paper (%.0f vs %.0f)"
		% [thrash, net.hold_strength() * Prey.ESCAPE_MARGIN])

	var before := net.durability
	var escaped: bool = await _wait_until(
		func() -> bool: return not brute.is_stuck(), 240)
	_check(escaped, "and gets free in practice, inside its stamina")
	# Either it tore loose and left the web worse, or it wrecked the web on the
	# way out. Both are the web losing, which is the thing being asserted.
	if is_instance_valid(net) and not net.is_queued_for_deletion():
		_check(net.durability < before, "and the fight cost the web")
	else:
		_check(true, "and took the whole web with it")
	brute.queue_free()


## Runs physics until [param test] passes, or gives up. Returns whether it
## passed, so a test can say "this happened" rather than "this took N frames".
func _wait_until(test: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if test.call():
			return true
		await physics_frame
	return test.call()


func _run_frames(count: int) -> void:
	for i in count:
		await physics_frame


# --- spinning a web where you point -------------------------------------

## The main way a web gets made. Aim, hold, let go — no ring to have built
## first, and no area to have enclosed by accident.
func _test_placing_a_web(spider: SpiderPlayer, builder: WebBuilder, webs: Node3D) -> void:
	var slab := _test_slab(spider.get_parent(), Vector3(-30, 0.0, 30))
	await physics_frame
	_stand_on(spider, slab.global_position + Vector3(0, 0.25, 0))
	await process_frame

	_select_pattern(builder, "orb_web")
	var before := _web_count(webs)
	_check(builder.begin_place(), "Q starts spinning a web")
	_check(builder.placing, "and it grows while held")
	_check(builder.place_valid, "with somewhere to put it")
	var smallest := builder.place_radius

	# Holding is the only size control there is.
	await _run_frames(30)
	_check(builder.place_radius > smallest,
		"holding makes it bigger (%.2fm -> %.2fm)" % [smallest, builder.place_radius])
	var held := builder.place_radius

	var rim := builder.place_rim()
	_check(rim.size() >= 3, "it has a rim to spin round (%d corners)" % rim.size())
	var facing := builder.place_normal.dot(-spider.view.aim_forward())
	_check(facing > 0.9, "and it faces the player (%.2f)" % facing)

	# Catch the web it actually spins rather than searching for one afterwards:
	# an earlier test left orb webs about, and searching found one of those and
	# then cheerfully measured it when this placement had in fact failed.
	var spun: Array[WebStructure] = []
	var catcher := func(built: WebStructure) -> void: spun.append(built)
	builder.web_built.connect(catcher)
	_check(builder.commit_place(), "letting go spins it")
	builder.web_built.disconnect(catcher)
	_check(not builder.placing, "and stops the growing")
	await physics_frame
	if not _check(spun.size() == 1, "exactly one web came out of it (%d)" % spun.size()):
		return
	var web := spun[0] as WebNet
	if not _check(web != null and web.pattern.id == "orb_web",
			"and it is the pattern that was selected"):
		return
	_check(web.global_position.distance_to(builder.place_centre) < held * 2.0,
		"it sits where the ghost was")
	_check(web.radius > 0.0, "with real size to it (%.2fm)" % web.radius)
	_check(web.catch_area != null, "and something to catch with")

	# Web size is what growing buys now, so the ceiling moves with the tier
	# rather than being a flat number.
	var ceiling := builder._max_place_radius()
	_check(is_equal_approx(ceiling, spider.stage().max_strand_length * 0.5),
		"the biggest web a tier can spin comes from the tier (%.2fm)" % ceiling)
	_check(builder._min_place_radius() < ceiling, "and the smallest is smaller")
	_check(builder.place_radius <= ceiling + 0.001,
		"and nothing grew past it (%.2fm)" % builder.place_radius)

	# The tier's reach is now the only ceiling, so held long enough it goes all
	# the way there and then stops rather than being refused at the end.
	_check(builder.begin_place(), "spinning one and holding it")
	await _run_frames(120)
	var full_radius := builder.place_radius
	_check(builder.place_capped, "growth stops at the tier's own reach")
	builder.cancel_place()
	_check(full_radius > ceiling - 0.05,
		"having grown all the way to it (%.2fm)" % full_radius)

	# Drive it through the input system as well. Calling begin_place() straight
	# is how this shipped broken: the wheel sat on a strand, so the real key
	# refused every single press while the test never went near a key.
	_select_pattern(builder, "orb_web")
	var count_before := _web_count(webs)
	_send(spider.input_build_mode)
	await process_frame
	_check(builder.placing, "the Q key itself starts it")
	await _run_frames(20)
	_send_release(spider.input_build_mode)
	await process_frame
	await physics_frame
	_check(not builder.placing, "and letting the key go finishes it")
	_check(_web_count(webs) == count_before + 1,
		"leaving a web behind (%d -> %d)" % [count_before, _web_count(webs)])

	# A line is grappled across a gap, not spun in mid-air.
	_select_pattern(builder, "trip_line")
	_check(not builder.begin_place(), "a tripline refuses to be spun as a web")
	builder.cancel_place()
	_select_first_spinnable_again(builder)

	web.demolish()
	slab.queue_free()
	await physics_frame
	await process_frame


# --- webs take the shape of the space -----------------------------------

## Holding the key says how far a web is *allowed* to reach; the room decides
## where it actually stops. The same press should give a full circle in open
## air and something that fills the gap when there is a gap to fill.
func _test_a_web_fits_the_space(spider: SpiderPlayer, builder: WebBuilder) -> void:
	var host := spider.get_parent()
	_select_pattern(builder, "orb_web")

	# Open air: a slab to stand on and nothing beside it.
	var open_slab := _test_slab(host, Vector3(-60, 0.0, -60))
	await physics_frame
	_stand_on(spider, open_slab.global_position + Vector3(0, 0.25, 0))
	await process_frame
	if not _check(builder.begin_place(), "spinning one in the open"):
		return
	# Pin the reach rather than growing to it. Growth accumulates delta in
	# _process, and idle frames do not interleave with physics frames the same
	# way twice, so two timed presses are never bit-for-bit the same size —
	# and this test is about what the room does with a reach, not about growth.
	var reach: float = clampf(2.0, builder._min_place_radius(), builder._max_place_radius())
	builder.place_radius = reach
	builder._update_placement()
	var open_area := builder.place_area
	_check(builder.place_anchored == 0,
		"in open air nothing catches the edges (%d of %d)"
		% [builder.place_anchored, WebBuilder.PLACE_SIDES])
	_check(open_area > 0.0, "and it covers a plain %.2f m2" % open_area)
	builder.cancel_place()

	# A slot: two walls close either side, looking along it at the end.
	var floor_at := Vector3(-90, 0.0, -60)
	var slot_floor := _test_slab(host, floor_at, Vector3(10, 0.5, 10))
	_test_slab(host, floor_at + Vector3(0, 2.0, -0.9), Vector3(10, 4.0, 0.4))
	_test_slab(host, floor_at + Vector3(0, 2.0, 0.9), Vector3(10, 4.0, 0.4))
	_test_slab(host, floor_at + Vector3(4.0, 2.0, 0), Vector3(0.4, 4.0, 4.0))
	await physics_frame
	_stand_on(spider, slot_floor.global_position + Vector3(-2.0, 0.25, 0))
	spider.view.face(Vector3.RIGHT)
	spider.view.pitch = 0.0
	await process_frame
	await _run_frames(4)

	if not _check(builder.begin_place(), "spinning one down the slot"):
		return
	builder.place_radius = reach
	builder._update_placement()
	_check(is_equal_approx(builder.place_radius, reach),
		"the very same reach is allowed here (%.2fm)" % builder.place_radius)
	_check(builder.place_anchored > 0,
		"but here the edges find the walls (%d of %d)"
		% [builder.place_anchored, WebBuilder.PLACE_SIDES])
	_check(builder.place_area < open_area,
		"so the web covers less than open air would (%.2f vs %.2f m2)"
		% [builder.place_area, open_area])

	var rim := builder.place_rim()
	var nearest := INF
	var furthest := 0.0
	for point in rim:
		var span := builder.place_centre.distance_to(point)
		nearest = minf(nearest, span)
		furthest = maxf(furthest, span)
	_check(furthest <= builder.place_radius + 0.01,
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
	_check(buried == 0,
		"and no corner is inside the wall it found (%d of %d)" % [buried, rim.size()])
	_check(nearest < furthest * 0.9,
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
func _test_spitting_a_web_at_something(spider: SpiderPlayer, builder: WebBuilder,
		level: Node, webs: Node3D) -> void:
	var host := spider.get_parent()
	var before := _web_count(webs)
	var slab := _test_slab(host, Vector3(-120, 0.0, -60))
	await physics_frame
	_stand_on(spider, slab.global_position + Vector3(0, 0.25, 0))
	await process_frame
	_clear_prey_near(level, slab.global_position, 12.0, null)
	await physics_frame
	await process_frame

	# A fly sitting still, between the spider and the floor it is aiming at.
	builder._update_placement()
	if not _check(builder.place_valid, "somewhere to spin one"):
		return
	var floor_y := builder.aim_point.y
	var sitting := _spawn_fly(level, builder.aim_point + Vector3(0, 0.35, 0))
	await physics_frame
	await physics_frame
	_check(not sitting.is_stuck(), "a fly minding its own business")

	# Aiming down at the floor with a fly hanging in the way: the throw should
	# lock onto the fly rather than the floor a foot behind it.
	builder._update_placement()
	_check(builder.place_target == sitting,
		"the throw picks out the fly, not the floor behind it")
	_check(builder.place_centre.distance_to(sitting.global_position) < 0.01,
		"and centres on it (%.3fm off)"
		% builder.place_centre.distance_to(sitting.global_position))

	_select_pattern(builder, "orb_web")
	if not _check(builder.begin_place(), "spinning one straight onto it"):
		return
	builder.place_radius = clampf(1.6, builder._min_place_radius(),
		builder._max_place_radius())
	builder._update_placement()
	var spun: Array[WebStructure] = []
	var catcher := func(built: WebStructure) -> void: spun.append(built)
	builder.web_built.connect(catcher)
	var made := builder.commit_place()
	builder.web_built.disconnect(catcher)
	if not _check(made and spun.size() == 1, "the web goes up"):
		return

	# Taken on the spot, not on the next frame something happens to move.
	var net := spun[0] as WebNet
	_check(net.bundled_on_arrival == 1,
		"the web wraps it the moment it exists (%d)" % net.bundled_on_arrival)
	_check(sitting.wrapped, "the fly is wrapped in the silk")
	_check(sitting.is_bundled(), "and out of the web rather than hanging in it")
	_check(not sitting.is_fighting(), "with no fight left to put up")
	_check(net.snared_count() == 0,
		"so the web is not holding it (%d)" % net.snared_count())
	_check(net.caught_on_arrival == 1,
		"and it reads as a catch (%d)" % net.caught_on_arrival)

	# The silk went round the fly, so there is no web left hanging on the wall.
	await physics_frame
	await process_frame
	_check(not is_instance_valid(net) or net.is_queued_for_deletion(),
		"and the web goes with it rather than sitting there empty")
	_check(_web_count(webs) == before,
		"leaving nothing standing (%d, started %d)" % [_web_count(webs), before])

	# It has to come down, and come down to the floor — a bundle is dead weight
	# whether or not the thing inside it could fly, and it must not come to
	# rest on the silk it was caught with.
	var dropped_from := sitting.global_position.y
	await _wait_until(func() -> bool: return sitting.is_on_floor(), 240)
	var rest := sitting.global_position.y
	_check(rest < dropped_from - 0.05,
		"the bundle falls (%.2f -> %.2f)" % [dropped_from, rest])
	_check(rest < floor_y + 0.25,
		"all the way to the ground (%.2f, floor at %.2f)" % [rest, floor_y])
	_check(sitting.is_on_floor(), "and is standing on it")
	# Nothing may take it back: a bundle lands inside the catch volume of
	# whatever wrapped it, and a thing already wrapped is not catch.
	_check(not sitting.can_be_snared(), "and no web will take it back")
	_check(sitting.is_bundled(), "so it is still a bundle, not stuck again")

	# And is simply there to be drained off the floor.
	var fed := spider.growth.biomass
	spider._handle_prey(sitting)
	await process_frame
	_check(spider.growth.biomass > fed, "a bundle on the floor is drainable")

	# The silk still has to be up to it: one that out-fights the web is caught
	# the ordinary way and has to be held, exactly as if it had flown in — and
	# a web that only holds rather than wraps is a web that stays up.
	_stand_on(spider, slab.global_position + Vector3(2.5, 0.25, 0))
	await process_frame
	if not _check(builder.begin_place(), "a second throw, at something tougher"):
		return
	builder.place_radius = clampf(1.6, builder._min_place_radius(),
		builder._max_place_radius())
	builder._update_placement()
	var brute := _spawn_fly(level, builder.place_centre)
	brute.species = "Test Brute"
	brute.struggle_power = 40.0
	brute.flying = false
	await physics_frame
	await physics_frame

	var standing := _web_count(webs)
	var tough: Array[WebStructure] = []
	var second := func(built: WebStructure) -> void: tough.append(built)
	builder.web_built.connect(second)
	builder.commit_place()
	builder.web_built.disconnect(second)
	await physics_frame
	if not _check(tough.size() == 1, "the second web goes up"):
		return
	var held := tough[0] as WebNet
	_check(brute.total_thrash() > held.hold_strength() * Prey.ESCAPE_MARGIN,
		"it out-fights the silk (%.0f vs %.0f)"
		% [brute.total_thrash(), held.hold_strength() * Prey.ESCAPE_MARGIN])
	_check(held.bundled_on_arrival == 0, "so it is not wrapped outright")
	_check(brute.is_stuck() and not brute.is_bundled(),
		"it hangs in the web and has to be fought for")
	_check(_web_count(webs) == standing + 1,
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
func _test_throwing_a_bolt(spider: SpiderPlayer, builder: WebBuilder, level: Node,
		webs: Node3D) -> void:
	var host := spider.get_parent()
	var slab := _test_slab(host, Vector3(90, 0.0, -90))
	await physics_frame
	_stand_on(spider, slab.global_position + Vector3(0, 0.25, 0))
	await process_frame
	_clear_prey_near(level, slab.global_position, 16.0, null)
	await physics_frame
	_select_pattern(builder, "orb_web")

	_check(not builder.throwing, "webs go down where you point to start with")
	builder.toggle_throwing()
	_check(builder.throwing, "and the toggle switches to throwing them")
	_check(builder.throw_name().contains("thrown"),
		"which the readout says out loud (%s)" % builder.throw_name())

	if not _check(builder.begin_place(), "winding one up to throw"):
		builder.toggle_throwing()
		return
	builder.place_radius = clampf(1.2, builder._min_place_radius(),
		builder._max_place_radius())
	builder._update_placement()
	var aimed_at := builder.aim_point

	var thrown: Array[WebStructure] = []
	var catcher := func(built: WebStructure) -> void: thrown.append(built)
	builder.web_built.connect(catcher)

	var standing := _web_count(webs)
	_check(builder.commit_place(), "letting go throws it")
	_check(builder.shot_in_flight(), "and puts a bolt in the air")
	_check(thrown.is_empty(), "with no web yet — the silk has to get there first")
	_check(true,
		"and nothing paid for while it is still flying")
	_check(_web_count(webs) == standing, "nothing standing yet either")

	var arrived := await _wait_until(func() -> bool: return not thrown.is_empty(), 240)
	builder.web_built.disconnect(catcher)
	if not _check(arrived and thrown.size() == 1,
			"the bolt opens out into a web (%d)" % thrown.size()):
		builder.toggle_throwing()
		return
	_check(not builder.shot_in_flight(), "and the bolt itself is gone")

	var web := thrown[0] as WebNet
	if not _check(web != null, "and it is a net, like the pattern asked for"):
		builder.toggle_throwing()
		return
	_check(web.global_position.distance_to(aimed_at) < 1.5,
		"near where it was aimed (%.2fm off)"
		% web.global_position.distance_to(aimed_at))
	_check(web.radius > 0.0, "with real size to it (%.2fm)" % web.radius)
	_check(_web_count(webs) == standing + 1, "and it is standing there")
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
	var sitting := _spawn_fly(level,
		floor_point + (muzzle - floor_point).normalized() * 0.3)
	await physics_frame
	await physics_frame
	_check(not sitting.is_stuck(), "a fly in the way of the next one")
	builder._update_placement()
	_check(builder.place_target == sitting, "and the crosshair is on it")

	if not _check(builder.begin_place(), "winding up a throw at it"):
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
	var before_fly := _web_count(webs)
	_check(builder.commit_place(), "and throwing it")
	var hit := await _wait_until(func() -> bool: return not at_fly.is_empty(), 240)
	builder.web_built.disconnect(second)
	# Only ever the size of it: the one inside has been freed by now.
	if not _check(hit and at_fly.size() == 1,
			"the bolt reaches the fly (%d)" % at_fly.size()):
		builder.toggle_throwing()
		return

	_check(wrapped_on_arrival[0] == 1,
		"and wraps it on arrival (%d)" % wrapped_on_arrival[0])
	_check(sitting.wrapped and sitting.is_bundled(),
		"the fly is a bundle rather than stuck in a web")
	await physics_frame
	await process_frame
	_check(_web_count(webs) == before_fly,
		"and the silk goes with it, leaving nothing hanging (%d, started %d)"
		% [_web_count(webs), before_fly])

	# And back to putting them down where you point.
	builder.toggle_throwing()
	_check(not builder.throwing, "the toggle goes back the other way")
	_check(builder.throw_name().contains("placed"),
		"and says so (%s)" % builder.throw_name())
	_stand_on(spider, slab.global_position + Vector3(2.0, 0.25, 0))
	await process_frame
	var placed: Array[WebStructure] = []
	var third := func(built: WebStructure) -> void: placed.append(built)
	builder.web_built.connect(third)
	_check(builder.begin_place(), "one more, the old way")
	builder.place_radius = clampf(1.2, builder._min_place_radius(),
		builder._max_place_radius())
	builder.commit_place()
	builder.web_built.disconnect(third)
	_check(placed.size() == 1, "which goes up on the spot, with nothing in flight")
	_check(not builder.shot_in_flight(), "because nothing was thrown")
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
func _test_species(spider: SpiderPlayer, builder: WebBuilder, level: Node) -> void:
	var all := PreyLibrary.load_species()
	_check(all.size() >= 5, "the game has creatures in it (%d)" % all.size())
	var ids: Array[String] = []
	for kind in all:
		ids.append(kind.id)
	_check(ids.has("midge") and ids.has("fly") and ids.has("moth")
		and ids.has("beetle") and ids.has("wasp"),
		"five of them, smallest first: %s" % ", ".join(ids))

	var midge := PreyLibrary.find("midge")
	var fly := PreyLibrary.find("fly")
	var moth := PreyLibrary.find("moth")
	var beetle := PreyLibrary.find("beetle")
	var wasp := PreyLibrary.find("wasp")
	if not _check(midge != null and fly != null and moth != null
			and beetle != null and wasp != null, "all five load"):
		return

	# They have to fight differently, or the hold strengths decide nothing.
	_check(midge.total_thrash() < fly.total_thrash()
		and fly.total_thrash() < moth.total_thrash()
		and moth.total_thrash() < beetle.total_thrash()
		and beetle.total_thrash() < wasp.total_thrash(),
		"each fights harder than the last (%.1f, %.1f, %.1f, %.1f, %.1f)"
		% [midge.total_thrash(), fly.total_thrash(), moth.total_thrash(),
			beetle.total_thrash(), wasp.total_thrash()])
	_check(beetle.size_class > fly.size_class,
		"and a beetle is bigger than a fly (%d vs %d)"
		% [beetle.size_class, fly.size_class])
	_check(not beetle.flying and moth.flying,
		"a beetle walks and a moth flies, so they are caught in different places")
	_check(moth.wander_height.x > fly.wander_height.x,
		"and the moth lives higher up (%.1fm vs %.1fm)"
		% [moth.wander_height.x, fly.wander_height.x])
	_check(wasp.lure_susceptibility < fly.lure_susceptibility,
		"a wasp will not come to a lure the way a fly will (%.2f vs %.2f)"
		% [wasp.lure_susceptibility, fly.lure_susceptibility])

	# The ladder, measured against real patterns. At a stated silk quality
	# rather than whatever the spider happens to be: growth is *supposed* to
	# move every one of these lines, so reading the live stage would make this
	# a test of how much the earlier tests fed the spider.
	var mid := 1.8
	var sheet := _hold_of(builder, "sheet_web", mid)
	var orb := _hold_of(builder, "orb_web", mid)
	var snare := _hold_of(builder, "pressure_snare", mid)
	_check(sheet > 0.0 and orb > sheet and snare > orb,
		"the webs hold in order too (%.1f, %.1f, %.1f)" % [sheet, orb, snare])
	_check(fly.total_thrash() <= sheet and moth.total_thrash() > sheet,
		"a sheet web keeps a fly and loses a moth (%.1f, %.1f, holds %.1f)"
		% [fly.total_thrash(), moth.total_thrash(), sheet])
	_check(beetle.total_thrash() <= orb and wasp.total_thrash() > orb,
		"an orb web keeps a beetle and loses a wasp (%.1f, %.1f, holds %.1f)"
		% [beetle.total_thrash(), wasp.total_thrash(), orb])
	_check(wasp.total_thrash() <= snare,
		"and a pressure snare keeps the wasp (%.1f, holds %.1f)"
		% [wasp.total_thrash(), snare])

	# And growing is supposed to move the lines, not just the numbers: better
	# silk should turn the web that lost a moth into the web that keeps one.
	var grown := _hold_of(builder, "sheet_web", mid * 2.0)
	_check(moth.total_thrash() <= grown,
		"better silk turns the sheet web into one that keeps a moth (holds %.1f)"
		% grown)

	# Mesh is a dial rather than something baked into a pattern, so what a
	# species says about it is what it is worth catching in a web spun coarse.
	# The midge earns its place by being the cheap common thing that fills a
	# web you left out, not by being hard to catch.
	_check(midge.spawn_weight > wasp.spawn_weight,
		"midges are what you mostly get (%.1f against a wasp's %.1f)"
		% [midge.spawn_weight, wasp.spawn_weight])
	_check(midge.biomass < fly.biomass and wasp.biomass > moth.biomass,
		"and worth the least, while the hard ones are worth the most (%d, %d, %d)"
		% [midge.biomass, moth.biomass, wasp.biomass])

	# And one of them, in the world, built from nothing but its resource.
	var host := spider.get_parent()
	var slab := _test_slab(host, Vector3(-90, 0.0, 90))
	await physics_frame
	_clear_prey_near(level, slab.global_position, 16.0, null)
	await physics_frame
	var one := _spawn_species(level, "wasp", slab.global_position + Vector3(0, 1.2, 0))
	await physics_frame
	if _check(one != null, "a wasp can be put in the world"):
		_check(one.species == "Wasp", "it knows what it is (%s)" % one.species)
		_check(is_equal_approx(one.total_thrash(), wasp.total_thrash()),
			"and fights like the resource says (%.1f)" % one.total_thrash())
		_check(one.get_node_or_null("Body") != null,
			"with a body built from the species, not from a scene per creature")
		_check(one.get_node_or_null("Hitbox") != null, "and something to hit")
		one.queue_free()

	# A walker gets no wings, which is the visible half of "caught elsewhere".
	var walker := _spawn_species(level, "beetle", slab.global_position + Vector3(1.5, 0.6, 0))
	await physics_frame
	if _check(walker != null, "and so can a beetle"):
		_check(walker.get_node_or_null("WingLeft") == null,
			"which has no wings, because it does not fly")
		walker.queue_free()

	slab.queue_free()
	await physics_frame
	await process_frame


## The most a pattern can hold at a given silk quality, as the escape check
## measures it — pattern strength times quality, times the margin.
func _hold_of(builder: WebBuilder, id: String, quality: float) -> float:
	var pattern := _pattern(builder, id)
	if pattern == null:
		return 0.0
	return pattern.hold_strength * quality * Prey.ESCAPE_MARGIN


# --- dragging things about ----------------------------------------------

## A catch used to be something you walked back to. A tether makes it cargo:
## hook it and it comes with you. What matters is that it is a rope and not a
## rod — slack does nothing, so walking towards the thing you are towing is
## free, and only past the length of the line does it pull.
func _test_tethering(spider: SpiderPlayer, level: Node) -> void:
	var tether := spider.tether
	var host := spider.get_parent()
	var slab := _test_slab(host, Vector3(120, 0.0, 120))
	await physics_frame
	_stand_on(spider, slab.global_position + Vector3(0, 0.25, 0))
	await process_frame
	_clear_prey_near(level, slab.global_position, 18.0, null)
	await physics_frame

	_check(not tether.is_towing(), "you start with nothing on the line")
	_check(is_equal_approx(tether.drag_factor(), 1.0), "and nothing slowing you")

	# Something still fighting is not cargo. That is what the wrapping is for.
	var live := _spawn_species(level, "fly", slab.global_position + Vector3(0.5, 0.6, 0))
	if not _check(live != null, "a fly to try it on"):
		return
	await physics_frame
	_check(not tether.can_carry(live), "a fly going about its business is not cargo")
	_check(not tether.hook(live), "so it refuses the line")
	_check(not tether.is_towing(), "and nothing is on it")

	# Wrapped, it is finished business and can be dragged.
	_check(live.bundle(), "wrapping it makes it a bundle")
	await physics_frame
	_check(tether.can_carry(live), "and a bundle is cargo")

	if not _check(tether.hook(live), "the line goes on it"):
		return
	_check(tether.is_towing(), "and you are towing it")
	_check(tether.cargo_name() == "Fly", "which the HUD can name (%s)" % tether.cargo_name())

	# A rope, not a rod: standing still next to it does nothing at all.
	var resting := live.global_position
	await _run_frames(30)
	_check(tether.slack() > 0.5, "slack line, standing next to it (%.2f)" % tether.slack())
	_check(live.global_position.distance_to(resting) < 0.35,
		"which leaves the bundle where it lies (%.2fm)"
		% live.global_position.distance_to(resting))

	# Walk away and it has to come. Not snapped to a fixed distance — hauled.
	var started := live.global_position
	var rope: float = spider.stage().body_height * tether.rope_bodies
	spider.climb.release()
	spider.global_position = slab.global_position + Vector3(rope * 2.0, 0.85, 0)
	await _run_frames(90)
	var moved := live.global_position.distance_to(started)
	_check(moved > 0.5, "walking off drags it along (%.2fm)" % moved)
	_check(live.global_position.distance_to(spider.global_position)
		<= rope * tether.snap_strain,
		"and it stays on the end of the line (%.2fm of %.2fm)"
		% [live.global_position.distance_to(spider.global_position),
			rope * tether.snap_strain])
	_check(tether.is_towing(), "still towing after the haul")

	# Weight is the cost. Something three sizes up is a real drag.
	var light := tether.drag_factor()
	tether.cut()
	_check(not tether.is_towing(), "cutting the line lets go")
	var heavy_one := _spawn_species(level, "wasp", slab.global_position + Vector3(0, 0.6, 0))
	if _check(heavy_one != null, "something heavier to drag"):
		heavy_one.bundle()
		await physics_frame
		if _check(tether.hook(heavy_one), "hooked the wasp"):
			_check(tether.drag_factor() < light,
				"a wasp is heavier going than a fly (%.2f against %.2f)"
				% [tether.drag_factor(), light])
			spider.climb.haul = tether.drag_factor()
			_check(spider.climb._surface_speed(false) < spider.stage().move_speed,
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
	await _run_frames(10)
	_aim_at(spider, live.global_position)
	await _run_frames(2)
	_check(tether.aimed_cargo() == live,
		"the crosshair picks the bundle out from five metres")
	var strands := spider.get_tree().get_nodes_in_group("silk_webs").size()
	_check(tether.grab_aimed(), "and the grapple puts a line on it")
	_check(tether.is_towing(), "so you are towing rather than standing on it")
	var after := spider.get_tree().get_nodes_in_group("silk_webs").size()
	_check(after == strands, "with no line strung to go there (%d)" % after)

	# A long shot pays out the whole distance and then winds back in, so it
	# harpoons rather than yanking the thing to your feet.
	var reeled := live.global_position.distance_to(spider.global_position)
	_check(reeled > 4.0, "it is still out there to start with (%.2fm)" % reeled)
	await _run_frames(150)
	var closer := live.global_position.distance_to(spider.global_position)
	_check(closer < reeled - 0.8, "and it reels in (%.2fm from %.2fm)" % [closer, reeled])
	tether.cut()

	# But a click that merely passes a bundle on its way to a wall is a grapple.
	# Same aim, bundle moved off to the side of it.
	live.global_position = slab.global_position + Vector3(2.5, 0.35, -5.5)
	await physics_frame
	_check(tether.aimed_cargo() == null,
		"a bundle off to one side is not what the click meant")
	_check(not tether.grab_aimed(), "so the grapple stays a grapple")
	if was_third:
		spider.view.toggle_mode()

	# The line does not outlive what is on the end of it.
	live.global_position = slab.global_position + Vector3(0, 0.4, 0)
	await physics_frame
	if _check(tether.hook(live), "one more, to be eaten off the line"):
		live.consume()
		await physics_frame
		await physics_frame
		_check(not tether.is_towing(), "draining the cargo drops the line")

	slab.queue_free()
	await physics_frame
	await process_frame


# --- wrapped silk with nothing holding it -------------------------------

## Anything wrapped is finished business, and finished business obeys gravity.
## Two ways to end up wrapped in mid-air with nothing under you — killed by
## venom where you flew, and left behind when the web holding you comes down —
## and neither of them should leave a cocoon hovering in the air.
func _test_wrapped_things_fall(spider: SpiderPlayer, builder: WebBuilder, level: Node,
		webs: Node3D) -> void:
	var host := spider.get_parent()
	var slab := _test_slab(host, Vector3(-120, 0.0, -120))
	await physics_frame
	_stand_on(spider, slab.global_position + Vector3(0, 0.25, 0))
	await process_frame
	_clear_prey_near(level, slab.global_position, 18.0, null)
	await physics_frame
	var floor_y := slab.global_position.y + 0.25

	# Poisoned in mid-air, having never been in a web at all.
	var high := slab.global_position + Vector3(0, 2.4, 0)
	var flier := _spawn_species(level, "fly", high)
	if not _check(flier != null, "a fly in the air to poison"):
		return
	await physics_frame
	_check(flier.envenom(), "venom kills it where it flew")
	_check(flier.wrapped, "and wraps it")
	await _wait_until(func() -> bool: return flier.is_on_floor(), 300)
	_check(flier.global_position.y < high.y - 0.5,
		"a dead thing falls (%.2f from %.2f)" % [flier.global_position.y, high.y])
	_check(flier.global_position.y < floor_y + 0.3,
		"all the way down (%.2f, floor at %.2f)" % [flier.global_position.y, floor_y])
	# Not off across the level: with nowhere recorded to hang from, the old
	# behaviour dragged it towards the middle of the world instead.
	var drift := Vector2(flier.global_position.x - high.x, flier.global_position.z - high.z)
	_check(drift.length() < 2.0,
		"and lands under where it died rather than sailing off (%.2fm)" % drift.length())
	flier.queue_free()
	await physics_frame

	# Wrapped in a web, and then the web comes down around it. Built by hand
	# rather than by spinning one over it and hoping: what is being tested is
	# what happens to a wrapped catch when its web goes, so the catch has to be
	# wrapped and in a web before the test starts, not as a side effect.
	var second := _spawn_species(level, "fly", high)
	if not _check(second != null, "another fly, this one for a web"):
		slab.queue_free()
		return
	await physics_frame
	_select_pattern(builder, "sheet_web")
	builder.start()
	for point in _square(high, 0.8):
		builder.add_anchor(point)
	builder.finish()
	builder.stop()
	await physics_frame
	var holder := _newest_web(webs, "sheet_web") as WebNet
	if not _check(holder != null, "a web to hang it in"):
		second.queue_free()
		slab.queue_free()
		return

	second.on_snared(holder, high, 0.0)
	second.wrap()
	await physics_frame
	_check(second.wrapped and second.is_stuck(),
		"the fly is wrapped and hanging in it")
	var hung := second.global_position
	await _run_frames(20)
	_check(second.global_position.distance_to(hung) < 0.2,
		"and stays put while the web holds it (%.2fm)"
		% second.global_position.distance_to(hung))

	# Now take the web away. Nothing is holding it up any more.
	holder.demolish()
	await physics_frame
	var landed: bool = await _wait_until(func() -> bool: return second.is_on_floor(), 300)
	_check(landed, "with the web gone, a wrapped fly comes down")
	_check(second.global_position.y < floor_y + 0.3,
		"onto the floor (%.2f, floor at %.2f)" % [second.global_position.y, floor_y])
	_check(second.wrapped, "still wrapped when it lands — it is still finished business")
	second.queue_free()

	slab.queue_free()
	await physics_frame
	await process_frame


# --- aim and shoot ------------------------------------------------------

## The web verb, and now the only one the player has. Point, press, and a bolt
## leaves the spider: no ghost, no held key, and no asking the room whether
## there is a good enough spot. What it hits decides what happens.
func _test_shooting(spider: SpiderPlayer, builder: WebBuilder, level: Node,
		webs: Node3D) -> void:
	var host := spider.get_parent()
	var slab := _test_slab(host, Vector3(150, 0.0, -150))
	await physics_frame
	_stand_on(spider, slab.global_position + Vector3(0, 0.25, 0))
	await process_frame
	_clear_prey_near(level, slab.global_position, 18.0, null)
	await physics_frame
	_select_pattern(builder, "orb_web")

	_check(builder.shot_radius() > 0.0,
		"a shot has one size, from the body (%.2fm)" % builder.shot_radius())
	_check(not builder.cooling(), "and no wait on it to start with")

	# At a surface: a web, wherever it landed, with nothing asked of the room.
	var built: Array[WebStructure] = []
	var catcher := func(web: WebStructure) -> void: built.append(web)
	builder.web_built.connect(catcher)
	var standing := _web_count(webs)
	var from := spider.view.aim_origin()
	var along := spider.view.aim_forward().normalized()
	_check(builder.shoot(), "right mouse fires one")
	_check(builder.shot_in_flight(), "and it is in the air")
	_check(builder.cooling(), "with the wait already running (%.1fs)" % builder.cooldown_left())
	_check(built.is_empty(), "with nothing built yet — it has to get there")

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
	_check(watched > 0, "the bolt can be watched in flight (%d frames)" % watched)
	_check(drift < 0.01, "and holds the line it was fired along (%.4fm off it)" % drift)
	var landed: bool = await _wait_until(func() -> bool: return not built.is_empty(), 240)
	builder.web_built.disconnect(catcher)
	_check(landed and built.size() == 1, "it makes a web where it lands (%d)" % built.size())
	_check(_web_count(webs) == standing + 1, "which is standing there")
	if built.size() == 1:
		built[0].demolish()
	await physics_frame

	# The wait is the whole cost of a web now, so it has to actually bite. Set
	# by hand rather than measured off the last shot: how long the bolt spent in
	# the air must not decide whether this passes.
	builder._cooling = builder.shot_cooldown
	_check(builder.cooling(), "a shot starts a wait (%.1fs)" % builder.cooldown_left())
	_check(not builder.shoot(), "and nothing else goes while it runs")
	_check(builder.cooldown_progress() < 1.0,
		"with the readout part-way along it (%.2f)" % builder.cooldown_progress())
	builder._cooling = 0.0
	_check(not builder.cooling() and builder.cooldown_progress() >= 1.0,
		"and it comes back on its own, costing nothing that was being saved")
	# Tested once. The rest of the suite fires freely rather than sitting out a
	# wait between every check.
	builder.shot_cooldown = 0.0

	# At something alive: the creature is wrapped, and no web is left hanging.
	builder._update_aim()
	var victim := _spawn_species(level, "fly", builder.aim_point + Vector3(0, 0.4, 0))
	if not _check(victim != null, "a fly to shoot at"):
		slab.queue_free()
		return
	await physics_frame
	_check(not victim.wrapped, "going about its business")
	var after: Array[WebStructure] = []
	var second := func(web: WebStructure) -> void: after.append(web)
	builder.web_built.connect(second)
	var before_shot := _web_count(webs)
	_check(builder.shoot(), "a second shot, at the fly")
	var hit: bool = await _wait_until(func() -> bool: return victim.wrapped, 240)
	builder.web_built.disconnect(second)
	_check(hit, "hitting it wraps it where it stood")
	_check(victim.is_bundled(), "and drops it as a bundle")
	await physics_frame
	await process_frame
	_check(_web_count(webs) == before_shot,
		"with no web left hanging (%d, started %d)" % [_web_count(webs), before_shot])
	victim.queue_free()

	# Off the line on purpose. The bolt is a ball of silk, not a hairline: a fly
	# is five centimetres across and wandering, so a ray through the middle of
	# one is a shot nobody can make, which is why nothing could be caught.
	builder._update_aim()
	var reach := builder.catch_radius(builder.shot_radius())
	_check(reach > spider.stage().body_height,
		"the bolt catches within %.2fm, wider than the spider itself" % reach)
	var start := spider.view.aim_origin()
	var sideways := spider.view.aim_forward().cross(Vector3.UP)
	if sideways.length_squared() < 0.001:
		sideways = Vector3.RIGHT
	sideways = sideways.normalized()
	var beside := start + (builder.aim_point - start) * 0.5 + sideways * reach * 0.6
	_clear_prey_near(level, beside, 6.0, null)
	var grazed := _spawn_species(level, "fly", beside)
	if _check(grazed != null, "a fly beside the line, not on it"):
		await physics_frame
		_check(builder.shoot(), "a shot past it")
		var near: bool = await _wait_until(func() -> bool: return grazed.wrapped, 240)
		_check(near, "passing near enough is enough — it is wrapped")
		grazed.queue_free()
		await physics_frame

	# At nothing at all: the bolt has to stop being a bolt.
	spider.view.face(Vector3(0, 0, -1))
	spider.view.pitch = 1.2
	await _run_frames(4)
	_check(builder.shoot(), "a third, fired at the sky")
	_check(builder.shot_in_flight(), "which is away")
	var gone: bool = await _wait_until(func() -> bool: return not builder.shot_in_flight(), 300)
	_check(gone, "and gives up rather than flying off for ever")

	slab.queue_free()
	await physics_frame
	await process_frame


## Holding the shoot key: first person, a second on a creature, and a bolt that
## then cannot miss it.
func _test_taking_aim(spider: SpiderPlayer, builder: WebBuilder, level: Node) -> void:
	var host := spider.get_parent()
	var slab := _test_slab(host, Vector3(150, 0.0, 150))
	await physics_frame
	_stand_on(spider, slab.global_position + Vector3(0, 0.25, 0))
	await process_frame
	_clear_prey_near(level, spider.global_position, 30.0, null)
	_select_pattern(builder, "orb_web")
	await physics_frame

	var quarry := _spawn_species(level, "fly", spider.global_position + Vector3(3.0, 1.0, 0.0))
	if not _check(quarry != null, "a fly to take aim at"):
		slab.queue_free()
		return
	# Still, for the aiming half. What is being checked here is the lock, not
	# whether a test can hold a crosshair on a wandering insect.
	var wander := quarry.move_speed
	quarry.move_speed = 0.0
	await physics_frame

	var was_third := spider.view.third_person
	_check(builder.begin_shot(), "holding right mouse starts taking aim")
	_check(builder.aiming, "which is a state you are in")
	_check(not spider.view.third_person,
		"and it puts you in first person — the cross and the silk leave from one place")
	_check(builder.aim_locked_on == null, "with nothing in the cross yet")

	# No frames between here and letting go: a physics frame would see the key
	# is not really held down in a headless run and let go on the spider's
	# behalf, which is the safety net doing its job and ruining the test.
	_aim_at(spider, quarry.global_position)
	spider.view.update(spider.stage().body_height)
	builder.track(0.05)
	_check(builder.aim_locked_on == quarry, "putting the cross on it starts the clock")
	_check(not builder.locked, "which does not finish at once")
	var part := builder.lock_progress

	for i in 30:
		_aim_at(spider, quarry.global_position)
		spider.view.update(spider.stage().body_height)
		builder.track(0.05)
	_check(builder.lock_progress > part, "holding it there fills the second")
	_check(builder.locked, "and a second later it is locked on")

	# Now look somewhere else entirely and fire. A locked bolt is promised its
	# catch, and the promise is kept by the flight rather than by the aim.
	quarry.move_speed = wander
	spider.view.face(Vector3(0, 0, 1))
	spider.view.pitch = 0.4
	spider.view.update(spider.stage().body_height)
	_check(builder.release_shot(), "letting go fires it")
	_check(not builder.aiming, "and aiming is over")
	_check(spider.view.third_person == was_third, "with the camera put back where it was")
	var took: bool = await _wait_until(func() -> bool: return quarry.wrapped, 360)
	_check(took, "the bolt goes and finds it, whichever way you were looking")
	_check(not is_instance_valid(quarry) or quarry.is_bundled(),
		"and leaves it bundled")

	# A tap is still a tap: nothing held, nothing locked, ordinary straight shot.
	await _wait_until(func() -> bool: return not builder.shot_in_flight(), 200)
	_check(builder.begin_shot(), "a tap starts the same way")
	_check(builder.release_shot(), "and lets go before the second is up")
	_check(not builder.locked and builder.aim_locked_on == null,
		"with nothing locked, so it is the plain shot it always was")

	if is_instance_valid(quarry):
		quarry.queue_free()
	slab.queue_free()
	await physics_frame
	await process_frame


## A spider's jump, not a person's scaled down.
func _test_a_spiders_jump() -> void:
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	var ladder := WebLibrary.default_stages()
	if not _check(ladder.size() > 1, "there is a ladder to jump up"):
		return
	var first := ladder[0]
	var rise: float = first.jump_velocity * first.jump_velocity / (2.0 * gravity)
	_check(rise > first.body_height * 5.0,
		"a spiderling clears %.1f of its own body lengths (%.2fm)"
		% [rise / first.body_height, rise])

	var climbing := true
	for i in ladder.size() - 1:
		if ladder[i + 1].jump_velocity <= ladder[i].jump_velocity:
			climbing = false
	_check(climbing, "and every tier jumps harder than the one below it")

	# Bigger things jump fewer of their own lengths. That is not a concession,
	# it is what square-cube does to anything that jumps.
	var last := ladder[ladder.size() - 1]
	var last_rise: float = last.jump_velocity * last.jump_velocity / (2.0 * gravity)
	_check(last_rise / last.body_height < rise / first.body_height,
		"while the biggest clears fewer of its own (%.1f against %.1f)"
		% [last_rise / last.body_height, rise / first.body_height])



## Nine pockets, and the bar is the whole inventory.
func _test_the_bar(spider: SpiderPlayer) -> void:
	var bag := spider.bag
	_check(SpiderInventory.SLOTS == 9, "nine slots (%d)" % SpiderInventory.SLOTS)
	_check(bag.slots().size() == 9, "and the bar always has nine of them")
	_check(bag.selected == 0, "starting on the first")

	var filled := 0
	for kind in bag.slots():
		if kind != null:
			filled += 1
	_check(filled == bag.carried().size(),
		"what you carry is what is on the bar (%d)" % filled)
	_check(bag.in_hand() == bag.slots()[0], "and the first pocket is in hand")

	bag.select(3)
	_check(bag.selected == 3, "a number key picks a pocket outright")
	bag.select(20)
	_check(bag.selected == 3, "and an impossible one is ignored, not wrapped")

	bag.scroll(1)
	_check(bag.selected == 4, "the wheel steps along it")
	bag.select(8)
	bag.scroll(1)
	_check(bag.selected == 0, "and wraps round the end")
	bag.scroll(-1)
	_check(bag.selected == 8, "both ways")
	bag.select(0)


## Puts the wheel back on something spinnable, the way a fresh spider starts.
func _select_first_spinnable_again(builder: WebBuilder) -> void:
	builder._select_first_spinnable()


## Clears the spawner's wandering flies out of a patch, so a test about one
## particular fly is not quietly a test about where the others drifted.
func _clear_prey_near(level: Node, point: Vector3, radius: float, keep: Prey) -> void:
	for node in level.get_tree().get_nodes_in_group("prey"):
		var other := node as Prey
		if other == null or other == keep or not is_instance_valid(other):
			continue
		if point.distance_to(other.global_position) <= radius:
			other.queue_free()


## Points the spider's crosshair at a spot in the world, yaw and pitch both.
func _aim_at(spider: SpiderPlayer, point: Vector3) -> void:
	var offset := point - spider.view.aim_origin()
	var flat := Vector2(offset.x, offset.z).length()
	spider.view.face(Vector3(offset.x, 0.0, offset.z))
	spider.view.pitch = atan2(offset.y, maxf(flat, 0.0001))


## A plain fly, the baseline everything else is measured against.
func _spawn_fly(level: Node, at: Vector3) -> Prey:
	return _spawn_species(level, "fly", at)


## Callers check what comes back, so this does not add a check of its own —
## one per spawn buried the suite in "species 'fly' exists".
func _spawn_species(level: Node, id: String, at: Vector3) -> Prey:
	var prey := Prey.of(PreyLibrary.find(id))
	if prey == null:
		return null
	level.add_child(prey)
	prey.global_position = at
	return prey


func _select_pattern(builder: WebBuilder, id: String) -> void:
	for i in builder.patterns.size():
		if builder.patterns[i].id == id:
			builder.pattern_index = i
			return
	_check(false, "pattern '%s' exists" % id)


func _first_web(webs: Node3D) -> WebStructure:
	for child in webs.get_children():
		var web := child as WebStructure
		if web != null and not web.is_queued_for_deletion():
			return web
	return null


## Most recently built web of a kind — several of the same pattern exist by the
## time the later checks run.
func _newest_web(webs: Node3D, pattern_id: String) -> WebStructure:
	var found: WebStructure = null
	for child in webs.get_children():
		var web := child as WebStructure
		if web != null and not web.is_queued_for_deletion() and web.pattern.id == pattern_id:
			found = web
	return found


## The evolutionary tree: the larder as a currency, and a trait as a body.
func _test_the_tree(spider: SpiderPlayer, level: Node) -> void:
	var traits := spider.traits
	if not _check(traits != null, "the spider has an evolutionary tree"):
		return
	_check(traits.tree.size() == 9, "nine traits in it (%d)" % traits.tree.size())
	for which in SpiderTrait.BRANCH_NAMES.size():
		_check(traits.branch(which).size() == 3,
			"%s runs three deep" % SpiderTrait.BRANCH_NAMES[which])

	var wings := traits.by_id("wing_buds")
	var lean := traits.by_id("hollow_frame")
	var bulk := traits.by_id("heavy_frame")
	if not _check(wings != null and lean != null and bulk != null,
			"wings, a lean frame and a heavy one"):
		return
	_check(wings.effect_line() != "" and bulk.effect_line().contains("size"),
		"each one says what it does, off its own numbers (%s)" % bulk.effect_line())

	# The suite has been eating and building for a while. Start the ledger — and
	# the spool — somewhere known, or this is a test about what the earlier ones
	# happened to leave behind.
	traits.larder.clear()

	_check(traits.unlocked(wings), "a root is open from the start")
	_check(not traits.unlocked(lean), "and what stands on it is not")
	_check(not traits.affordable(wings), "an empty larder affords nothing")
	_check(traits.shortfall(wings).get("fly", 0) == int(wings.cost["fly"]),
		"and it says what you are short: %d flies" % int(wings.cost["fly"]))
	_check(not traits.buy(wings), "so it cannot be taken")
	_check(not traits.has("wing_buds"), "and nothing happened")

	# Eating fills the larder — through the real path, not by hand.
	var lunch := _spawn_species(level, "fly", spider.global_position + Vector3(0.3, 0.0, 0.0))
	await physics_frame
	if _check(lunch != null, "there is a fly to eat"):
		spider._handle_prey(lunch)
		_check(traits.eaten("fly") == 1,
			"draining one puts it in the larder (%d)" % traits.eaten("fly"))

	var wanted := int(wings.cost["fly"])
	_feed_larder(traits, "fly", wanted - traits.eaten("fly"))
	_check(traits.eaten("fly") == wanted, "eat enough and the trait is paid for")
	_check(traits.affordable(wings), "wings can be afforded")
	_check(not traits.affordable(bulk),
		"but not a heavy frame as well — it wants %d" % int(bulk.cost["fly"]))

	_check(traits.buy(wings), "so the wings are taken")
	_check(traits.has("wing_buds"), "and the spider has them")
	_check(traits.eaten("fly") == 0,
		"which spent the flies (%d left)" % traits.eaten("fly"))
	_check(not traits.buy(wings), "the same trait cannot be taken twice")
	_check(not traits.affordable(bulk),
		"and the same fly cannot buy both branches")
	_check(traits.unlocked(lean), "what stood on the wings is open now")

	# Wings are a lighter fall, with no key to hold.
	_check(traits.glide() > 0.0, "wings cancel some of a fall (%.2f)" % traits.glide())
	var gliding := _fall_gain(spider, traits.glide())
	var plummeting := _fall_gain(spider, 0.0)
	_check(gliding < plummeting,
		"so a fall picks up less speed (%.2f against %.2f m/s per tenth)"
		% [gliding, plummeting])
	_check(gliding > 0.0, "and it is still a fall — wings flatten it, not stop it")

	# A trait is a body, not a stat line: buying one resizes the spider the
	# same way growing a tier does, through the same signal.
	var tier := spider.growth.stage_index
	var tall := spider.stage().body_height
	var capsule := spider.collision.shape as CapsuleShape3D
	_feed_larder(traits, "midge", int(lean.cost["midge"]))
	_feed_larder(traits, "moth", int(lean.cost["moth"]))
	_check(traits.buy(lean), "a hollow frame can be taken once the wings are there")
	await physics_frame
	_check(spider.stage().body_height < tall,
		"which makes the spider smaller (%.3f -> %.3f)" % [tall, spider.stage().body_height])
	_check(is_equal_approx(capsule.height, spider.stage().body_height),
		"and the collider went with it")
	_check(spider.growth.stage_index == tier,
		"without moving it down a tier — you grew lean, not younger")
	_check(spider.growth.base_stage().body_height > spider.stage().body_height,
		"so it stands under its own tier (%.3f under %.3f)"
		% [spider.stage().body_height, spider.growth.base_stage().body_height])
	_check(spider.stage().move_speed > spider.growth.base_stage().move_speed,
		"and is quicker than its tier for it")

	# Bulk is the other end of the same ruler.
	_feed_larder(traits, "fly", int(bulk.cost["fly"]))
	var small := spider.stage().body_height
	_check(traits.buy(bulk), "a heavy frame can be taken alongside it")
	await physics_frame
	_check(spider.stage().body_height > small,
		"and puts the size back on (%.3f -> %.3f)" % [small, spider.stage().body_height])

	await _test_fangs(spider, traits, level)
	_test_the_tree_on_screen(level, traits)


## Venom's gift: a kill that needs no web behind it.
func _test_fangs(spider: SpiderPlayer, traits: SpiderTraits, level: Node) -> void:
	var fangs := traits.by_id("hunting_fangs")
	if not _check(fangs != null, "the tree has fangs at the end of venom"):
		return
	_check(not traits.has_fangs(), "a spider without them needs a web")

	# Something inside the bite either way, so this is about the fangs and not
	# about the bite power they also carry.
	var bite := spider.stage().bite_power
	var quarry: PreySpecies = null
	for kind in PreyLibrary.load_species():
		if kind.size_class <= bite and kind.size_class * 2 > bite + fangs.bite_bonus:
			quarry = kind
			break
	if not _check(quarry != null,
			"there is a creature inside a bite of %d but not by half" % bite):
		return

	var at := spider.global_position + Vector3(0.35, 0.0, 0.0)
	_clear_prey_near(level, at, 3.0, null)
	var caught := _spawn_species(level, quarry.id, at)
	await physics_frame
	if not _check(caught != null, "there is a %s to try it on" % quarry.display_name):
		return
	_check(not caught.is_stuck(), "which is not in a web")
	spider._handle_prey(caught)
	_check(is_instance_valid(caught) and not caught.eaten,
		"and cannot be taken bare-fanged, however small it is")

	var line: Array[String] = ["paralytic", "digestive", "hunting_fangs"]
	for step in line:
		var gift := traits.by_id(step)
		for species_id in gift.cost:
			_feed_larder(traits, str(species_id), int(gift.cost[species_id]))
		_check(traits.buy(gift), "the venom line goes up in order — %s" % gift.display_name)
	await physics_frame
	_check(traits.has_fangs(), "and ends in fangs")

	spider._handle_prey(caught)
	_check(not is_instance_valid(caught) or caught.eaten,
		"with which the %s goes down where it stands" % quarry.display_name)


## The screen the tree is spent on.
func _test_the_tree_on_screen(level: Node, traits: SpiderTraits) -> void:
	var hud := level.get_node_or_null("HUD") as SpiderHUD
	if not _check(hud != null, "the level has a HUD to hang the tree off"):
		return
	var screen := hud.get_node_or_null(NodePath("TraitTree")) as TraitTree
	if not _check(screen != null, "which built a tree screen"):
		return
	_check(not screen.open and not screen.visible, "shut until it is asked for")
	_check(screen._cards.size() == traits.tree.size(),
		"with a card for every trait (%d)" % screen._cards.size())

	var taken := screen._cards.get("wing_buds") as Panel
	var shut := screen._cards.get("girder_legs") as Panel
	if _check(taken != null and shut != null, "owned and locked ones both on it"):
		var cost := taken.get_node_or_null(NodePath("Lines/Cost")) as Label
		_check(cost != null and cost.text.contains("yours"),
			"an owned trait says so instead of a price (%s)"
			% (cost.text if cost != null else "—"))
		var locked := shut.get_node_or_null(NodePath("Lines/Cost")) as Label
		_check(locked != null and locked.text.begins_with("needs"),
			"and a locked one names what it stands on (%s)"
			% (locked.text if locked != null else "—"))

	screen.show_tree()
	_check(screen.open and screen.visible, "[E] opens it")
	_check(screen._larder.text != "", "with the larder across the top (%s)" % screen._larder.text)
	screen.close()
	_check(not screen.open and not screen.visible, "and [E] again puts it away")


## Puts creatures straight into the larder, for a test that is about spending
## them rather than about catching them.
func _feed_larder(traits: SpiderTraits, species_id: String, how_many: int) -> void:
	var kind := PreyLibrary.find(species_id)
	for i in maxi(how_many, 0):
		traits.record(kind)


## Speed one tenth of a second of falling adds, at a given glide. Measured well
## above the level so nothing is underfoot to cut the fall short.
func _fall_gain(spider: SpiderPlayer, glide: float) -> float:
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


func _find_web(webs: Node3D, pattern_id: String) -> WebStructure:
	for child in webs.get_children():
		var web := child as WebStructure
		if web != null and not web.is_queued_for_deletion() and web.pattern.id == pattern_id:
			return web
	return null


func _web_count(webs: Node3D) -> int:
	var total := 0
	for child in webs.get_children():
		var web := child as WebStructure
		if web != null and not web.is_queued_for_deletion():
			total += 1
	return total


func _check(condition: bool, message: String) -> bool:
	_checks += 1
	if condition:
		print("  ok    %s" % message)
	else:
		_failures += 1
		print("  FAIL  %s" % message)
	return condition


func _finish() -> void:
	if is_instance_valid(_level):
		current_scene = null
		_level.free()
	print("")
	if _failures == 0:
		print("%d checks passed" % _checks)
	else:
		print("%d of %d checks FAILED" % [_failures, _checks])
	quit(1 if _failures > 0 else 0)
