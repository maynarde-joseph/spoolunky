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
	_check(builder.unlocked_patterns().size() == 2,
		"only the two starter patterns are unlocked (%d)" % builder.unlocked_patterns().size())
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
	# Look straight down at the floor.
	spider.head.rotation.x = -PI / 2.0
	await process_frame
	builder._update_aim()
	_check(builder.aim_valid, "aiming at the floor finds an anchor point")
	_check(builder.aim_point.distance_to(spider.global_position) < spider.stage().anchor_range,
		"anchor point is inside the tier's reach")

	# Aiming at open sky should not find anything.
	spider.head.rotation.x = PI / 2.0
	await process_frame
	builder._update_aim()
	_check(not builder.aim_valid, "aiming at nothing gives no anchor")
	_check(builder.problem == WebBuilder.Problem.NO_SURFACE, "and says why")
	builder.stop()


func _test_building_a_net(spider: SpiderPlayer, builder: WebBuilder, webs: Node3D, silk: SilkPool) -> void:
	_select_pattern(builder, "sheet_web")
	builder.start()
	var centre := spider.global_position + Vector3(0, 0.4, -1.0)
	for point in _square(centre, 0.6):
		builder.add_anchor(point)

	var before := silk.current
	builder.finish()
	# Read the spend before the pool has a frame to regenerate.
	var spent := before - silk.current
	await physics_frame

	var net := _first_web(webs) as WebNet
	if not _check(net != null, "a sheet web was spun"):
		return
	_check(spent > 0.0, "silk was spent (%.1f -> %.1f)" % [before, before - spent])
	_check(is_equal_approx(spent, net.silk_cost), "the charge matches the web's cost")
	_check(net.mesh_instance != null and net.mesh_instance.mesh.get_surface_count() > 0,
		"the web has a mesh")
	_check(net.catch_area != null, "the web has a catch volume")
	_check(net.area > 0.0, "the web encloses %.2f m2" % net.area)
	_check(net.global_position.distance_to(centre) < 0.5, "the web sits where it was strung")
	_check(net.durability > 0.0 and net.durability == net.max_durability, "it starts intact")
	_check(builder.anchors.is_empty(), "anchors reset after spinning")
	_check(builder.building, "build mode stays on for the next web")
	builder.stop()

	# Too few anchors must not build anything or charge for it.
	builder.start()
	builder.add_anchor(centre)
	var silk_before := silk.current
	builder.finish()
	_check(is_equal_approx(silk.current, silk_before), "an unfinishable web costs nothing")
	_check(_web_count(webs) == 1, "and spawns nothing")
	builder.stop()


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
