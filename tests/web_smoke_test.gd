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
	await _test_tuning_dials(spider, builder, webs, silk, level)
	await _test_saved_designs(spider, builder, webs, silk)
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


func _test_input_map(spider: SpiderPlayer, builder: WebBuilder) -> void:
	for action in ["web_build_mode", "web_place", "web_cancel", "web_finish",
			"web_next_pattern", "web_prev_pattern", "web_remove", "interact", "toggle_help"]:
		_check(InputMap.has_action(action), "input action '%s' is set up" % action)

	# Drive build mode the way the player does, through the input system. A
	# headless display server cannot capture the mouse, so lift that gate.
	spider.require_captured_mouse = false
	_send(spider.input_build_mode)
	await process_frame
	_check(builder.building, "Q turns build mode on")

	var started_with := builder.current_pattern()
	_send(spider.input_next_pattern)
	await process_frame
	_check(builder.current_pattern() != started_with, "the wheel changes pattern")
	_send(spider.input_prev_pattern)
	await process_frame
	_check(builder.current_pattern() == started_with, "and changes back")

	_send(spider.input_build_mode)
	await process_frame
	_check(not builder.building, "Q turns it off again")


func _send(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	# Input is accumulated by default, so push it through now.
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
	_check(builder.link_webs(trip, snare), "the two webs can be wired together")
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

	# Now trip the line, far away.
	_check(snare.armed, "the snare is armed before anything happens")
	var crosser := _spawn_fly(level, (trip.point_a + trip.point_b) * 0.5)
	await physics_frame
	await physics_frame

	_check(not snare.armed, "crossing the tripline springs the distant snare")
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
	_check(builder.link_webs(trip, snare), "wired the rig together")

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
				and web.global_position.distance_to(builder.aim_point) < 6.0:
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
