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
	var silk := spider.silk
	builder.notice.connect(func(text: String) -> void: print("        (%s)" % text))

	# Somewhere flat and open to work in.
	spider.global_position = Vector3(12, 0.5, 0)
	# These suites assert that things cost silk, so the sandbox switch is off.
	spider.silk.unlimited = false
	await physics_frame

	_test_starting_state(spider, builder)
	await _test_input_map(spider, builder)
	await _test_aiming(spider, builder)
	await _test_building_a_net(spider, builder, webs, silk)
	await _test_catching(spider, level, webs)
	await _test_strands(spider, builder, webs, silk)
	await _test_growth(spider, builder)
	await _test_tripline_alert(spider, builder, webs, level)
	await _test_pressure_snare(spider, builder, webs, silk, level)
	await _test_trigger_links(spider, builder, webs, silk, level)
	await _test_weave_modes(spider, builder, webs, silk)
	await _test_rings_of_silk(spider, builder, webs, silk)
	await _test_living_on_the_web(spider, builder, webs, silk, level)
	await _test_tuning_dials(spider, builder, webs, silk, level)
	await _test_saved_designs(spider, builder, webs, silk)
	await _test_placing_a_web(spider, builder, webs, silk)
	await _test_a_web_fits_the_space(spider, builder, silk)
	await _test_spitting_a_web_at_something(spider, builder, level, silk)
	await _test_the_larder(spider, builder, webs, level)
	await _test_the_bag(spider, level, webs, builder, silk)
	await _test_sandbox_wiring(level, spider)
	await _test_demolish(builder, webs, silk)

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
	_check(spider.silk.maximum == stage.silk_capacity, "silk capacity comes from the tier")
	# Q spins nets and refuses strands, so a wheel parked on a strand is a
	# place key that silently does nothing. That is exactly how it shipped.
	var starting := builder.current_pattern()
	_check(starting != null and starting.shape == WebPattern.Shape.NET,
		"the wheel starts on a web Q can actually spin (%s)"
		% (starting.display_name if starting != null else "nothing"))


func _test_input_map(spider: SpiderPlayer, builder: WebBuilder) -> void:
	for action in ["web_build_mode", "web_place", "web_cancel", "web_finish",
			"web_next_pattern", "web_prev_pattern", "web_remove", "interact",
			"device_mode", "toggle_help"]:
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


func _test_building_a_net(spider: SpiderPlayer, builder: WebBuilder, webs: Node3D, silk: SilkPool) -> void:
	_select_pattern(builder, "sheet_web")
	builder.start()
	var centre := spider.global_position + Vector3(0, 0.4, -1.0)

	# Walking the frame is what costs silk, one line at a time.
	var before_frame := silk.current
	var corners := _square(centre, 0.6)
	for point in corners:
		builder.add_anchor(point)
	var frame_spent := before_frame - silk.current
	_check(frame_spent > 0.0, "laying the frame costs silk (%.1f)" % frame_spent)
	_check(_web_count(webs) == 3, "three lines behind four anchors (%d)" % _web_count(webs))
	_check(builder.enclosed_area() > 0.0,
		"the run encloses %.2f m2" % builder.enclosed_area())

	var before := silk.current
	builder.finish()
	# Read the spend before the pool has a frame to regenerate.
	var spent := before - silk.current
	await physics_frame

	var net := _newest_web(webs, "sheet_web") as WebNet
	if not _check(net != null, "a sheet web was woven inside it"):
		return
	_check(spent > 0.0, "weaving costs silk (%.1f)" % spent)
	_check(is_equal_approx(spent - net.silk_cost, _closing_line_cost(webs)),
		"the charge is the weave plus the one line that closed the ring")
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
	var silk_before := silk.current
	var webs_before := _web_count(webs)
	builder.finish()
	_check(is_equal_approx(silk.current, silk_before), "a lone anchor weaves nothing")
	_check(_web_count(webs) == webs_before, "and spawns nothing")
	builder.stop()


## Cost of the last frame line laid, the one that closed the ring.
func _closing_line_cost(webs: Node3D) -> float:
	var newest := _newest_web(webs, "frame_line")
	return newest.silk_cost if newest != null else 0.0


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

	var silk_before := spider.silk.current
	spider._handle_prey(fly)
	_check(fly.wrapped, "the spider wrapped it")
	_check(spider.silk.current < silk_before, "wrapping costs silk")

	var steady := net.durability
	for i in 10:
		await physics_frame
	_check(is_equal_approx(net.durability, steady), "a wrapped fly stops wrecking the web")

	var biomass_before := spider.growth.biomass
	spider._handle_prey(fly)
	await process_frame
	_check(spider.growth.biomass > biomass_before, "draining it feeds the spider")
	_check(not is_instance_valid(fly) or fly.eaten, "the fly is gone")
	_check(net.snared_count() == 0, "the web is empty again")


func _test_strands(spider: SpiderPlayer, builder: WebBuilder, webs: Node3D, silk: SilkPool) -> void:
	silk.refill(silk.maximum)
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
	_check(trip.get_node_or_null("Walkway") == null, "you cannot walk on a tripline")
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
	_check(spider.silk.maximum == stage.silk_capacity, "silk capacity grew")
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


func _test_pressure_snare(spider: SpiderPlayer, builder: WebBuilder, webs: Node3D,
		silk: SilkPool, level: Node) -> void:
	spider.growth.feed(40.0, "test")
	await physics_frame
	_check(spider.growth.stage_index >= 2, "grown enough to build snares")
	silk.refill(silk.maximum)

	_select_pattern(builder, "pressure_snare")
	builder.start()
	var centre := spider.global_position + Vector3(0, 0.5, 2.0)
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

	var fly := _spawn_fly(level, snare.to_global(snare.centre_local))
	await physics_frame
	await physics_frame
	_check(fly.is_stuck(), "the snare caught a fly")
	_check(not snare.armed, "the snare has sprung")
	_check(snare.needs_rearm(), "and now needs re-arming")

	# While the snare holds it rigid the fly cannot fight back.
	var durability := snare.durability
	for i in 8:
		await physics_frame
	_check(is_equal_approx(snare.durability, durability), "held prey cannot damage a sprung snare")

	var before := silk.current
	_check(silk.spend(snare.pattern.rearm_cost), "re-arming is affordable")
	_check(snare.rearm(), "the snare re-arms")
	_check(snare.armed and not snare.needs_rearm(), "and is ready again")
	_check(silk.current < before, "re-arming costs silk")
	fly.consume()
	await physics_frame


## The point of the whole feature: a tripline metres away springs a snare, and
## the snare grabs prey that never touched it.
func _test_trigger_links(spider: SpiderPlayer, builder: WebBuilder, webs: Node3D,
		silk: SilkPool, level: Node) -> void:
	silk.refill(silk.maximum)
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
	var before := silk.current
	_check(builder.link_nodes(trip, snare), "the two webs can be wired together")
	await physics_frame
	_check(trip.links.has(snare), "the tripline is wired to the snare")
	_check(silk.current < before, "the signal line costs silk")
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
	silk.refill(silk.maximum)
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

	# Pulling a web down takes its wiring with it.
	bystander.consume()
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


func _test_weave_modes(spider: SpiderPlayer, builder: WebBuilder, webs: Node3D,
		silk: SilkPool) -> void:
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
	silk.refill(silk.maximum)
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
func _test_rings_of_silk(spider: SpiderPlayer, builder: WebBuilder, webs: Node3D,
		silk: SilkPool) -> void:
	silk.refill(silk.maximum)
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
	var before := silk.current
	var woven := builder.fill_aimed_loop()
	var spent := before - silk.current
	builder.stop()
	await physics_frame
	_check(woven, "and can be woven in one go")
	_check(spent > 0.0, "which costs silk (%.1f)" % spent)

	var net := _newest_web(webs, "sheet_web") as WebNet
	if _check(net != null, "a web is standing in the ring"):
		_check(is_equal_approx(spent, net.silk_cost), "charged for the inside only")
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
func _test_living_on_the_web(spider: SpiderPlayer, builder: WebBuilder, webs: Node3D,
		silk: SilkPool, level: Node) -> void:
	silk.refill(silk.maximum)

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
	fly.consume()

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


func _test_tuning_dials(spider: SpiderPlayer, builder: WebBuilder, webs: Node3D,
		silk: SilkPool, level: Node) -> void:
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
	_check(is_equal_approx(tight.silk_per_metre, slack.silk_per_metre),
		"tension is free either way — it is purely a trade")
	tuning.tension = WebTuning.NEUTRAL

	# Weight: everything against silk.
	tuning.weight = WebTuning.STEPS - 1
	var heavy := tuning.apply_to(pattern)
	_check(heavy.hold_strength > pattern.hold_strength
		and heavy.durability > pattern.durability, "heavy silk is better in every way")
	_check(heavy.silk_per_metre > pattern.silk_per_metre, "and that is what you pay for")
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
	silk.refill(silk.maximum)
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
		costs[setting] = web.silk_cost if web != null else 0.0
		if web != null:
			_check(web.tuning != null and web.tuning.mesh == setting,
				"the web remembers the dials it was spun with")
			web.demolish()
		await physics_frame
	var fine: float = costs[0]
	var coarse: float = costs[WebTuning.STEPS - 1]
	_check(coarse < fine, "an open mesh really is cheaper to spin (%.1f vs %.1f)"
		% [coarse, fine])
	tuning.mesh = WebTuning.NEUTRAL

	# And the size gate has teeth: a fly ignores a web meshed for bigger things.
	silk.refill(silk.maximum)
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


func _test_saved_designs(spider: SpiderPlayer, builder: WebBuilder, webs: Node3D,
		silk: SilkPool) -> void:
	silk.refill(silk.maximum)
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
	_check(design.recorded_silk > 0.0, "it remembers what it cost")
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
	var before_silk := silk.current
	# Aim is recomputed every frame, so remember where this went.
	var placed_at := builder.aim_point
	_check(builder.place_design(), "the design can be spun somewhere new")
	var spent := before_silk - silk.current
	await physics_frame
	_check(_web_count(webs) == before_webs + 2, "both webs went up")
	_check(spent > 0.0, "placing it costs silk (%.1f)" % spent)

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

	# Too poor to afford it: nothing appears and nothing is charged.
	var broke_webs := _web_count(webs)
	silk.spend(silk.current)
	builder.aim_valid = true
	builder.aim_point = spider.global_position + Vector3(0, 0.5, -11.0)
	builder.aim_normal = Vector3.UP
	_check(builder.aim_valid, "aiming somewhere valid for the broke attempt")
	_check(not builder.place_design(), "a design you cannot afford is refused")
	_check(_web_count(webs) == broke_webs, "and leaves no half-built rig behind")
	_check(silk.current <= 0.01, "and charges nothing")

	builder.placing_design = false
	silk.refill(silk.maximum)
	DesignLibrary.forget(design)


func _test_sandbox_wiring(level: Node, spider: SpiderPlayer) -> void:
	var spawner := level.get_node_or_null("PreySpawner") as PreySpawner
	if _check(spawner != null, "the level has a prey spawner"):
		_check(spawner.alive_count() > 0, "it stocked %d flies" % spawner.alive_count())
	var hud := level.get_node_or_null("HUD") as SpiderHUD
	if _check(hud != null, "the level has a HUD"):
		_check(hud.stage_label.text.contains(spider.stage().display_name),
			"the HUD is showing the current stage (%s)" % hud.stage_label.text)
		_check(hud.silk_bar.max_value == spider.silk.maximum, "and tracking the silk pool")


func _test_demolish(builder: WebBuilder, webs: Node3D, silk: SilkPool) -> void:
	# Leave room in the pool, or a refund has nowhere to land.
	silk.spend(silk.current * 0.5)
	var count := _web_count(webs)
	var web := _first_web(webs)
	if not _check(web != null, "there is a web to pull down"):
		return
	var cost := web.silk_cost
	var before := silk.current
	var refund := web.demolish()
	silk.refill(refund)
	await process_frame
	_check(refund > 0.0 and refund < cost,
		"pulling a web down refunds some silk (%.1f of %.1f)" % [refund, cost])
	_check(silk.current > before, "the silk came back")
	_check(_web_count(webs) == count - 1, "the web is gone")


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
		builder: WebBuilder, silk: SilkPool) -> void:
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
	silk.refill(silk.maximum)
	await process_frame

	# Placing costs a device out of the bag and no silk at all: the bag is the
	# whole limit on them, which is why they are allowed to be better than silk.
	_select_device(placer, "venom_spur")
	var silk_before := silk.current
	var carried_before := bag.count(venom)
	var spur := placer.place()
	await physics_frame
	if not _check(spur != null, "put a venom spur down"):
		return
	_check(bag.count(venom) == carried_before - 1, "it came out of the bag")
	_check(is_equal_approx(silk.current, silk_before), "and cost no silk")
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
	await _test_wiring_a_device(spider, webs, builder, placer, silk, slab)
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
		placer: DevicePlacer, silk: SilkPool, slab: StaticBody3D) -> void:
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

	var before := silk.current
	_check(builder.link_nodes(trip, bell), "a web can be wired to a device")
	_check(trip.links.has(bell), "the tripline sets off the bell")
	_check(silk.current < before, "and the line costs silk, same as any other")

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
	spider.silk.refill(spider.silk.maximum)
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
func _test_placing_a_web(spider: SpiderPlayer, builder: WebBuilder, webs: Node3D,
		silk: SilkPool) -> void:
	silk.refill(silk.maximum)
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
	_check(builder.estimated_cost > 0.0,
		"and it can be priced before you commit (~%d silk)" % ceili(builder.estimated_cost))

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
	var spent_before := silk.current
	_check(builder.commit_place(), "letting go spins it")
	builder.web_built.disconnect(catcher)
	_check(not builder.placing, "and stops the growing")
	await physics_frame
	_check(_web_count(webs) == before + 1, "a web is standing there")
	if not _check(spun.size() == 1, "exactly one web came out of it (%d)" % spun.size()):
		return
	var web := spun[0] as WebNet
	if not _check(web != null and web.pattern.id == "orb_web",
			"and it is the pattern that was selected"):
		return
	_check(silk.current < spent_before, "which cost silk (%.1f)" % web.silk_cost)
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

	# Measure what this tier's smallest and largest webs actually cost rather
	# than guessing numbers that will rot the next time a pattern is tuned.
	silk.unlimited = true
	_check(builder.begin_place(), "spinning one with silk to spare")
	var small_cost := builder.estimated_cost
	await _run_frames(120)
	var full_cost := builder.estimated_cost
	var full_radius := builder.place_radius
	builder.cancel_place()
	silk.unlimited = false
	_check(full_radius > ceiling - 0.05,
		"unlimited silk grows it to the tier ceiling (%.2fm)" % full_radius)
	_check(full_cost > small_cost,
		"and a big web costs more than a small one (%d vs %d)"
		% [ceili(full_cost), ceili(small_cost)])

	# Silk is the other ceiling, and it has to stop the web growing rather than
	# refuse it at the end — holding a key down for a web you cannot buy is a
	# nasty way to find out you are broke.
	var thin: float = clampf((small_cost + full_cost) * 0.5, small_cost + 1.0, silk.maximum)
	silk.refill(silk.maximum)
	silk.spend(maxf(silk.current - thin, 0.0))
	_check(builder.begin_place(), "spinning another on a thin reserve")
	await _run_frames(120)
	_check(silk.can_afford(builder.estimated_cost),
		"what it grew to is affordable (~%d of %d silk)"
		% [ceili(builder.estimated_cost), floori(silk.current)])
	if thin < full_cost:
		_check(builder.place_capped, "growth stopped when the silk ran out")
		_check(builder.place_radius < ceiling,
			"short of what the tier would otherwise allow (%.2fm of %.2fm)"
			% [builder.place_radius, ceiling])
	builder.cancel_place()

	# And below even a small web's price it refuses to start, rather than
	# letting you hold the key down for something you cannot buy.
	silk.spend(silk.current)
	_check(not builder.begin_place(), "with nothing in the spool it will not start")
	_check(not builder.placing, "and leaves you holding nothing")
	silk.refill(silk.maximum)

	# Drive it through the input system as well. Calling begin_place() straight
	# is how this shipped broken: the wheel sat on a strand, so the real key
	# refused every single press while the test never went near a key.
	_select_pattern(builder, "orb_web")
	silk.refill(silk.maximum)
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
func _test_a_web_fits_the_space(spider: SpiderPlayer, builder: WebBuilder,
		silk: SilkPool) -> void:
	var host := spider.get_parent()
	silk.unlimited = true
	_select_pattern(builder, "orb_web")

	# Open air: a slab to stand on and nothing beside it.
	var open_slab := _test_slab(host, Vector3(-60, 0.0, -60))
	await physics_frame
	_stand_on(spider, open_slab.global_position + Vector3(0, 0.25, 0))
	await process_frame
	if not _check(builder.begin_place(), "spinning one in the open"):
		silk.unlimited = false
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
		silk.unlimited = false
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
	_check(nearest < furthest * 0.9,
		"and the shape is genuinely the gap, not a disc (%.2f to %.2f)"
		% [nearest, furthest])
	builder.cancel_place()

	silk.unlimited = false
	open_slab.queue_free()
	await physics_frame
	await process_frame


# --- catching something by spinning a web over it ------------------------

## The other half of what webs are for. A web is somewhere you leave a trap,
## and it is also something you throw over a thing that is right there — and
## the second only works if a new web catches what is already inside it, since
## a catch volume otherwise only ever hears about arrivals.
func _test_spitting_a_web_at_something(spider: SpiderPlayer, builder: WebBuilder,
		level: Node, silk: SilkPool) -> void:
	var host := spider.get_parent()
	silk.unlimited = true
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
		silk.unlimited = false
		return
	var sitting := _spawn_fly(level, builder.aim_point + Vector3(0, 0.15, 0))
	sitting.flying = false
	await physics_frame
	await physics_frame
	_check(not sitting.is_stuck(), "a fly minding its own business")

	_select_pattern(builder, "orb_web")
	var caught: Array[Node3D] = []
	var watcher := func(_web: WebStructure, prey: Node3D) -> void: caught.append(prey)
	if not _check(builder.begin_place(), "spinning one straight onto it"):
		silk.unlimited = false
		return
	builder.place_radius = clampf(1.2, builder._min_place_radius(),
		builder._max_place_radius())
	builder._update_placement()
	var spun: Array[WebStructure] = []
	var catcher := func(built: WebStructure) -> void:
		spun.append(built)
		if built is WebNet:
			built.prey_caught.connect(watcher)
	builder.web_built.connect(catcher)
	var made := builder.commit_place()
	builder.web_built.disconnect(catcher)
	if not _check(made and spun.size() == 1, "the web goes up"):
		silk.unlimited = false
		return

	# Caught on the spot, not on the next frame something happens to move.
	_check(sitting.is_stuck(), "and the fly is caught the moment it exists")
	var net := spun[0] as WebNet
	_check(net.snared_count() == 1, "the web knows it has it (%d)" % net.snared_count())
	_check(sitting.is_fighting(), "and it is fighting, same as anything else caught")

	# It is still a web, so the larder rules apply — no free kill for a big one.
	var thrash := sitting.struggle_power * sitting.struggle_stamina
	_check(thrash < net.hold_strength() * Prey.ESCAPE_MARGIN,
		"an orb web holds a fly thrown into it (%.1f vs %.1f)"
		% [thrash, net.hold_strength() * Prey.ESCAPE_MARGIN])

	net.demolish()
	sitting.queue_free()
	slab.queue_free()
	silk.unlimited = false
	await physics_frame
	await process_frame


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


func _spawn_fly(level: Node, at: Vector3) -> Prey:
	var fly := load("res://game/prey/fly.tscn").instantiate() as Prey
	level.add_child(fly)
	fly.global_position = at
	return fly


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
