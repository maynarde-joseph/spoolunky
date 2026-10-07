extends TestSuite

## Every built-in level: that it is whole, that it survives being saved and loaded,
## and that it can be finished — each one played start to finish by a scripted
## route through the real controls: aiming, throwing, grappling, calling webs home,
## running and jumping. No teleporting: if a route here goes through, a player can.
##
##     godot --headless --path . --script res://tests/flies/levels_smoke_test.gd
##
## Name part of a level's file name after `--` to play only those routes.

var only: Array = []


func run_checks() -> void:
	only = Array(OS.get_cmdline_user_args())
	if only.is_empty():
		await _every_level_is_whole()
		await _the_editor()
	if _wanted("01"):
		await _first_thread()
	if _wanted("02"):
		await _silk_stairs()
	if _wanted("03"):
		await _ride_the_gap()
	if _wanted("04"):
		await _call_it_back()
	if _wanted("05"):
		await _moving_parts()
	if _wanted("06"):
		await _all_together()


func _wanted(part: String) -> bool:
	return only.is_empty() or only.has(part)


# --- whole levels ---------------------------------------------------------------

func _every_level_is_whole() -> void:
	print("Every level")
	var all := LevelData.catalogue()
	check(all.size() >= 6, "there are %d built-in levels" % all.size())
	for entry in all:
		var data := LevelData.load_file(entry["path"])
		var counts := {}
		for thing in data.get("objects", []):
			var type := String(thing.get("type"))
			counts[type] = int(counts.get(type, 0)) + 1
		check(counts.get("start", 0) == 1 and counts.get("exit", 0) == 1,
			"%s has a start and an exit" % entry["name"])
		var again: Variant = JSON.parse_string(JSON.stringify(data))
		check(again is Dictionary and (again as Dictionary)["objects"].size()
			== data["objects"].size(), "%s survives being written and read" % entry["name"])


func _the_editor() -> void:
	print("The editor")
	var editor := LevelEditor.new()
	editor.open(LevelData.blank("Test bench"), "")
	await stage(editor)
	await run_frames(3)
	var before: int = editor.level["objects"].size()
	editor.choose("wall")
	var wall := editor.place("piece", Vector3(0.0, 0.0, -4.0))
	check(editor.level["objects"].size() == before + 1 and wall["piece"] == "wall",
		"a kit piece goes down where it is put")
	check(editor.selected != null, "and is selected")
	editor.choose("platform")
	var lift := editor.place("platform", Vector3(2.0, 0.0, 0.0))
	editor.add_path_point(lift, Vector3(6.0, 0.0, 0.0))
	check(LevelData.path_of(lift).size() == 3, "a platform is given another stop on its path")
	editor.duplicate_selected()
	editor._escape()
	check(editor.level["objects"].size() == before + 3, "and can be copied")
	editor.delete_selected()
	check(editor.level["objects"].size() == before + 2, "and deleted")
	editor.undo()
	check(editor.level["objects"].size() == before + 3, "and the delete undone")
	editor.choose("exit")
	editor.place("exit", Vector3(5.0, 0.0, 5.0))
	var exits := (editor.level["objects"] as Array).filter(func(t: Dictionary) -> bool:
		return t["type"] == "exit")
	check(exits.size() == 1 and LevelData.vec(exits[0]["pos"]).x == 5.0,
		"putting down an exit moves the one there is")
	var file := "user://levels/test_bench.json"
	editor.path = file
	check(editor.save(), "it saves")
	var back := LevelData.load_file(file)
	check(back.get("objects", []).size() == editor.level["objects"].size(),
		"and what is saved is what was made")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(file))


# --- driving ----------------------------------------------------------------------

func load_level(file: String) -> LevelRun:
	var data := LevelData.load_file(LevelData.BUILT_IN + file)
	var run := LevelRun.new()
	run.require_captured_mouse = false
	run.setup(data)
	await stage(run)
	await run_frames(10)
	return run


func aim(run: LevelRun, point: Vector3) -> void:
	var weaver := run.weaver
	for i in 4:
		weaver.view.update(Weaver.HEIGHT, weaver.global_basis.y)
		var from := weaver.view.aim_pivot()
		var d := (point - from).normalized()
		weaver.view.yaw = atan2(-d.x, -d.z)
		weaver.view.pitch = asin(clampf(d.y, -1.0, 1.0))
	weaver.view.update(Weaver.HEIGHT, weaver.global_basis.y)


## Runs to [param target] on the flat, looking where it is going. Keeps running at
## the end if [param keep_going], for a jump.
func go(run: LevelRun, target: Vector3, tolerance := 0.5, keep_going := false,
		limit := 400) -> bool:
	var weaver := run.weaver
	for i in limit:
		var flat := target - weaver.global_position
		flat.y = 0.0
		if flat.length() < tolerance:
			if not keep_going:
				weaver.drive(Vector2.ZERO)
			return true
		weaver.view.yaw = atan2(-flat.x, -flat.z)
		weaver.view.pitch = -0.2
		weaver.drive(Vector2(0.0, 1.0))
		await physics_frame
	weaver.drive(Vector2.ZERO)
	return false


## Runs at [param target] from wherever the spider is, jumping at once, and waits to
## land.
func leap(run: LevelRun, target: Vector3) -> bool:
	var weaver := run.weaver
	var flat := target - weaver.global_position
	weaver.view.yaw = atan2(-flat.x, -flat.z)
	weaver.drive(Vector2(0.0, 1.0), true)
	await run_frames(6)
	var landed := await wait_until(func() -> bool:
		return weaver.mode == Weaver.Mode.GROUND or weaver.mode == Weaver.Mode.WEB, 120)
	weaver.drive(Vector2.ZERO)
	return landed


func stop(run: LevelRun) -> void:
	run.weaver.drive(Vector2.ZERO)
	await run_frames(10)
	await wait_until(func() -> bool: return run.weaver.mode != Weaver.Mode.AIR, 120)
	await run_frames(4)


## Throws a web wound to [param wound] at [param point]. Returns it.
func throw_at(run: LevelRun, point: Vector3, wound := 1.0) -> ThrownWeb:
	var weaver := run.weaver
	await wait_until(func() -> bool: return weaver.caster._cooling <= 0.0, 30)
	aim(run, point)
	var had := weaver.webs().duplicate()
	if not weaver.caster.throw(wound):
		return null
	for web in weaver.webs():
		if not had.has(web):
			return web
	return null


func stuck(web: ThrownWeb) -> bool:
	if web == null:
		return false
	var ref: WeakRef = weakref(web)
	await wait_until(func() -> bool:
		var w := ref.get_ref() as ThrownWeb
		return w == null or w.is_stuck() or not w.is_standing(), 120)
	var now := ref.get_ref() as ThrownWeb
	return now != null and now.is_stuck()


func grapple_to(run: LevelRun, point: Vector3) -> bool:
	var weaver := run.weaver
	aim(run, point)
	if not weaver.fire_grapple():
		return false
	await wait_until(func() -> bool: return weaver.mode != Weaver.Mode.GRAPPLE, 120)
	await run_frames(4)
	return true


## Throws a web at [param point], grapples onto it when it sticks, and walks on
## up or across it until it puts the spider somewhere else. Whether it all went.
func web_onto(run: LevelRun, point: Vector3, wound := 1.0) -> bool:
	var web := await throw_at(run, point, wound)
	if not await stuck(web):
		return false
	if OS.has_environment("ROUTE_DEBUG"):
		note("before grapple: look %s" % run.weaver.view.forward())
	if not await grapple_to(run, web.global_position):
		return false
	if OS.has_environment("ROUTE_DEBUG"):
		note("after grapple: look %s, %s" % [run.weaver.view.forward(), where(run)])
	if run.weaver.standing_web() != web:
		return false
	return await climb(run)


## Walks up the web underfoot until it takes the spider somewhere else.
func climb(run: LevelRun, limit := 150) -> bool:
	var weaver := run.weaver
	weaver.view.pitch = 0.0
	# Facing into the wall the web is on, W walks up it, the way a player would look.
	var under := weaver.standing_web()
	if under != null:
		var into := -under.normal()
		into.y = 0.0
		if into.length() > 0.5:
			weaver.view.yaw = atan2(-into.x, -into.z)
	weaver.drive(Vector2(0.0, 1.0))
	var left := await wait_until(func() -> bool: return weaver.mode != Weaver.Mode.WEB, limit)
	if OS.has_environment("ROUTE_DEBUG"):
		var web := weaver.standing_web()
		note("climb ended %s, web %s r %.2f, look %s" % [where(run),
			web.global_position if web != null else Vector3.ZERO,
			web.radius if web != null else 0.0, weaver.view.forward()])
	weaver.drive(Vector2.ZERO)
	await run_frames(4)
	return left


## Calls every web home — first thrown, first home, a press each — and waits for
## them to arrive.
func pull(run: LevelRun) -> void:
	var weaver := run.weaver
	while weaver.pullback.next_web() != null:
		await wait_until(func() -> bool: return weaver.pullback._cooling <= 0.0, 30)
		weaver.pullback.cast()
	await wait_until(func() -> bool:
		return get_root().get_tree().get_nodes_in_group(ThrownWeb.GROUP).filter(
			func(n: Node) -> bool: return (n as ThrownWeb).state == ThrownWeb.State.RETURNING
		).is_empty(), 120)
	await run_frames(4)


## Walks into the exit, and says whether the level was finished.
func finish(run: LevelRun, exit_at: Vector3) -> bool:
	await go(run, exit_at, 0.4)
	await wait_until(func() -> bool: return run.done, 60)
	return run.done


func where(run: LevelRun) -> String:
	return "at %s, %s" % [run.weaver.global_position.snappedf(0.1),
		Weaver.Mode.keys()[run.weaver.mode]]


# --- the routes -------------------------------------------------------------------

func _first_thread() -> void:
	print("Route: First Thread")
	var run := await load_level("01_first_thread.json")
	await go(run, Vector3(0, 0, -4.5), 0.2, true)
	check(await leap(run, Vector3(0, 0, -12)) and run.weaver.global_position.z < -8.0,
		"a jump takes the first gap (%s)" % where(run))
	await stop(run)
	await go(run, Vector3(0, 0, -15))
	aim(run, Vector3(0, 0, -33))
	check(run.weaver.grapple.aimed().get("web") == null, "bare stone gives the grapple nothing")
	check(await web_onto(run, Vector3(0, 0, -33)),
		"a web on the far pad, and a grapple onto it, take the long gap")
	check(run.weaver.global_position.z < -29.5 and run.weaver.mode == Weaver.Mode.GROUND,
		"walking off it onto the pad (%s)" % where(run))
	await pull(run)
	await go(run, Vector3(0, 0, -39))
	check(await web_onto(run, Vector3(0, 2.6, -42)) and run.weaver.global_position.y > 3.9,
		"a web on the ledge's face, a grapple onto it, and up it onto the top (%s)"
		% where(run))
	await stop(run)
	await pull(run)
	var weaver := run.weaver
	aim(run, Vector3(0, 4, -58))
	check(weaver.grapple.aimed().get("web") == null,
		"the last pad is slick: nothing for silk, nothing for the grapple")
	await go(run, Vector3(0, 4, -49.6), 0.2, true)
	check(await leap(run, Vector3(0, 4, -58)) and weaver.global_position.z < -53.0
		and weaver.global_position.y > 3.9, "a running jump onto it (%s)" % where(run))
	await stop(run)
	check(await finish(run, Vector3(0, 4, -60)), "and out")


func _silk_stairs() -> void:
	print("Route: Silk Stairs")
	var run := await load_level("02_silk_stairs.json")
	var weaver := run.weaver
	await go(run, Vector3(0, 0, -5.5))
	var low := await throw_at(run, Vector3(0, 2.4, -7))
	check(await stuck(low), "a big web low on the wall")
	await go(run, Vector3(0, 0, -7.5), 0.2)
	check(weaver.mode == Weaver.Mode.WEB, "running into it takes the spider onto it")
	await climb(run, 50)
	var high := await throw_at(run, Vector3(0, 7.0, -7))
	check(await stuck(high), "from up the first web, a second higher still")
	await grapple_to(run, high.global_position)
	check(weaver.standing_web() == high, "a grapple onto it")
	await pull(run)
	check(weaver.standing_web() == high and weaver.webs_left() == 1,
		"the Pullback takes back the lower web and leaves the spider on the higher")
	var top := await throw_at(run, Vector3(0, 11.4, -7))
	check(await stuck(top), "the same silk thrown higher again")
	await grapple_to(run, top.global_position)
	await climb(run)
	check(weaver.global_position.y > 13.9 and weaver.mode == Weaver.Mode.GROUND,
		"and walking off the top of it, over the slick band onto the top (%s)" % where(run))
	await pull(run)
	check(await finish(run, Vector3(0, 14, -19)), "and out")


func _ride_the_gap() -> void:
	print("Route: Ride the Gap")
	var run := await load_level("03_ride_the_gap.json")
	var weaver := run.weaver
	await go(run, Vector3(0, 0, -5.0))
	check(weaver.global_position.distance_to(Vector3(0, 2.5, -36)) > Grapple.REACH,
		"the far side is out of the grapple's reach")
	var web := await throw_at(run, Vector3(0, 2.5, -36), 0.6)
	await run_frames(5)
	aim(run, web.global_position)
	check(weaver.fire_grapple(), "a grapple onto the web as it goes")
	await wait_until(func() -> bool: return weaver.mode == Weaver.Mode.WEB, 60)
	check(weaver.standing_web() == web, "riding it")
	check(await stuck(web), "across, until it sticks to the far wall")
	await climb(run)
	check(weaver.global_position.y > 5.0 and weaver.mode == Weaver.Mode.GROUND,
		"up the web onto the top (%s)" % where(run))
	check(await finish(run, Vector3(0, 5, -44)), "and out")


func _call_it_back() -> void:
	print("Route: Call It Back")
	var run := await load_level("04_call_it_back.json")
	var weaver := run.weaver
	await go(run, Vector3(-6, 0, 7.5))
	await web_onto(run, Vector3(-2, 4.5, 7.5))
	check(weaver.global_position.y > 5.9, "a web up the pulpit's side, and onto it (%s)"
		% where(run))
	await pull(run)
	await go(run, Vector3(0, 6, 7.5), 0.3)
	var crate := get_root().get_tree().get_nodes_in_group(Crate.GROUP)[0] as Crate
	var on_crate := await throw_at(run, crate.global_position, 0.0)
	check(await stuck(on_crate) and on_crate.carried == crate, "a web on the crate in the red")
	await go(run, Vector3(-6, 0, 6.5), 0.2)
	await stop(run)
	await go(run, Vector3(-6, 0, 6.5), 0.2)
	await stop(run)
	await pull(run)
	await run_frames(40)
	check(run.is_powered("door"), "brought home onto the plate, it opens the door")
	await run_frames(60)
	await go(run, Vector3(3, 0, 1))
	await go(run, Vector3(7.5, 0, 1.5))
	check(await finish(run, Vector3(8, 0, 6.5)), "and through it, out")


func _moving_parts() -> void:
	print("Route: Moving Parts")
	var run := await load_level("05_moving_parts.json")
	var weaver := run.weaver
	var ferry: MovingPlatform = null
	var lift: MovingPlatform = null
	for node in get_root().get_tree().get_nodes_in_group(LevelBuilder.GROUP):
		if node is MovingPlatform:
			if (node as MovingPlatform).channel == "":
				ferry = node
			else:
				lift = node
	await go(run, Vector3(0, 0, -2.0), 0.3)
	await wait_until(func() -> bool: return ferry.position.z < -10.0, 900)
	await wait_until(func() -> bool: return ferry.position.z > -9.5, 900)
	await go(run, Vector3(0, 0, -4.3), 0.3, true)
	await leap(run, Vector3(0, 0, -9))
	await stop(run)
	check(weaver.global_position.distance_to(ferry.global_position) < 3.0,
		"a jump onto the ferry (%s)" % where(run))
	await wait_until(func() -> bool: return ferry.position.z < -26.5, 600)
	check(weaver.global_position.z < -24.0, "it carries the spider across (%s)" % where(run))
	await go(run, Vector3(0, 0, -32))
	# Back across the pad, so the line to the crate clears the slick post under it.
	await go(run, Vector3(5, 0, -31))
	await stop(run)
	var crate := get_root().get_tree().get_nodes_in_group(Crate.GROUP)[0] as Crate
	var web := await throw_at(run, crate.global_position + Vector3.UP * 0.3, 0.0)
	check(await stuck(web) and web.carried == crate, "a web on the crate up on its post")
	await go(run, Vector3(3, 0, -34), 0.2)
	await stop(run)
	await pull(run)
	await run_frames(40)
	check(run.is_powered("lift"), "brought onto the plate, it starts the lift")
	# Round the crate, now on the plate.
	await go(run, Vector3(0, 0, -33.5))
	await go(run, Vector3(0, 0, -39.5))
	await stop(run)
	# Wait for the lift to come down, then go for it while it waits at the bottom.
	await wait_until(func() -> bool: return lift.position.y > 1.0, 900)
	await wait_until(func() -> bool: return lift.position.y < -0.45, 900)
	if OS.has_environment("ROUTE_DEBUG"):
		note("lift at %s, powered %s, spider %s" % [lift.position, run.is_powered("lift"),
			where(run)])
	await go(run, Vector3(0, 0, -44), 0.4)
	await stop(run)
	check(weaver.global_position.distance_to(lift.global_position) < 3.0,
		"onto the lift (%s)" % where(run))
	await wait_until(func() -> bool: return lift.position.y > 9.4, 900)
	await go(run, Vector3(0, 10, -45.6), 0.3, true)
	await leap(run, Vector3(0, 10, -51))
	await stop(run)
	check(weaver.global_position.y > 9.9, "and from the top of it a jump to the high pad (%s)"
		% where(run))
	check(await finish(run, Vector3(0, 10, -55)), "and out")


func _all_together() -> void:
	print("Route: All Together")
	var run := await load_level("06_all_together.json")
	var weaver := run.weaver
	await go(run, Vector3(0, 0, -5.0))
	var ride := await throw_at(run, Vector3(0, 1.8, -34), 0.6)
	await run_frames(5)
	aim(run, ride.global_position)
	weaver.fire_grapple()
	await wait_until(func() -> bool: return weaver.mode == Weaver.Mode.WEB, 60)
	var rode := await stuck(ride)
	if OS.has_environment("ROUTE_DEBUG"):
		note("ride web %s %s, spider %s on %s" % [ride.global_position if is_instance_valid(ride)
			else Vector3.ZERO, ride.state if is_instance_valid(ride) else -1, where(run),
			weaver.standing_web()])
	check(rode and weaver.standing_web() == ride, "a ride over the drop to the stone face")
	await climb(run)
	check(weaver.global_position.y > 3.9, "up and over the cap (%s)" % where(run))
	await go(run, Vector3(0, 0, -40))
	await stop(run)
	await pull(run)
	await go(run, Vector3(0, 0, -44.5))
	var low := await throw_at(run, Vector3(0, 2.4, -46))
	await stuck(low)
	await go(run, Vector3(0, 0, -46.5), 0.2)
	await climb(run, 50)
	var mid := await throw_at(run, Vector3(0, 6.5, -46))
	await stuck(mid)
	await grapple_to(run, mid.global_position)
	await pull(run)
	var high := await throw_at(run, Vector3(0, 9.4, -46))
	await stuck(high)
	await grapple_to(run, high.global_position)
	await climb(run)
	check(weaver.global_position.y > 11.9 and weaver.mode == Weaver.Mode.GROUND,
		"up the tower on two webs, leapfrogged (%s)" % where(run))
	await pull(run)
	await go(run, Vector3(4, 12, -53), 0.2)
	await stop(run)
	var crate := get_root().get_tree().get_nodes_in_group(Crate.GROUP)[0] as Crate
	var on_crate := await throw_at(run, crate.global_position, 0.0)
	check(await stuck(on_crate) and on_crate.carried == crate, "a web on the crate")
	await pull(run)
	await run_frames(100)
	check(run.is_powered("bag"), "brought onto the plate, it opens the exit's door")
	await go(run, Vector3(0, 12, -58))
	check(await finish(run, Vector3(0, 12, -61.3)), "and out")
