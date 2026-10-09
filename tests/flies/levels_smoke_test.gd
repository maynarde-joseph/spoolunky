extends TestSuite

## Every built-in level: that it is whole, that it survives being saved and loaded,
## that silk alone can't finish it (see [SilkReach]), and that it can be finished — each one played start to finish by a scripted
## route through the real controls: aiming, throwing, grappling, calling webs home,
## running and jumping. No teleporting: if a route here goes through, a player can.
##
##     godot --headless --path . --script res://tests/flies/levels_smoke_test.gd
##
## Name part of a level's file name after `--` to play only those routes, or
## `editor` for the level editor's checks alone.

var only: Array = []


func run_checks() -> void:
	only = Array(OS.get_cmdline_user_args())
	if only.is_empty():
		await _every_level_is_whole()
	if only.is_empty() or only.has("editor"):
		await _the_editor()
	if _wanted("01"):
		await _first_thread()
	if _wanted("02"):
		await _silk_stairs()
	if _wanted("03"):
		await _drop_in()
	if _wanted("04"):
		await _cut_lines()
	if _wanted("05"):
		await _call_it_back()
	if _wanted("06"):
		await _moving_parts()
	if _wanted("07"):
		await _pull_the_room()
	if _wanted("08"):
		await _all_together()
	if _wanted("09"):
		await _fly_paper()
	if _wanted("10"):
		await _clockwork_flies()


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
		if entry["built_in"]:
			# Each needs more than web, grapple, drop, repeat: something only the
			# Pullback, a crate or a moving part opens. See SilkReach.
			var run := LevelRun.new()
			run.require_captured_mouse = false
			run.setup(data)
			await stage(run)
			await run_frames(10)
			var found := SilkReach.explore(run)
			if not check(not found["reached"],
					"%s can't be finished with silk alone" % entry["name"]):
				note(found["how"])
		var again: Variant = JSON.parse_string(JSON.stringify(data))
		check(again is Dictionary and (again as Dictionary)["objects"].size()
			== data["objects"].size(), "%s survives being written and read" % entry["name"])
	await _reach_knows_flies()


## That the silk-alone check counts flies as somewhere to go: Fly Paper with its
## boards off can be crossed on its flies, and with its flies gone too, it can't.
func _reach_knows_flies() -> void:
	var data := LevelData.load_file(LevelData.BUILT_IN + "09_fly_paper.json")
	var open_hut: Array = data["objects"].filter(func(t: Dictionary) -> bool:
		return t["type"] != "panel")
	for with_flies in [true, false]:
		var objects := open_hut if with_flies else open_hut.filter(func(t: Dictionary) -> bool:
			return t["type"] != "fly")
		var level := data.duplicate(true)
		level["objects"] = objects.duplicate(true)
		var run := LevelRun.new()
		run.require_captured_mouse = false
		run.setup(level)
		await stage(run)
		await run_frames(10)
		var found := SilkReach.explore(run)
		if with_flies:
			check(found["reached"], "the silk-alone check goes from fly to fly")
		else:
			check(not found["reached"], "and without them, the void can't be crossed")


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
	check(not editor._dirty, "and once saved, nothing is unsaved")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
	await _editor_handles(editor)
	_editor_checks(editor)
	_editor_flies(editor)


## Presets, the handles that stretch and move a thing, and undo and redo.
func _editor_handles(editor: LevelEditor) -> void:
	editor.choose("slick block")
	var block := editor.place("piece", Vector3(0.0, 0.0, -8.0))
	check(block["surface"] == "slick" and LevelData.vec(block["size"]) == Vector3(2, 2, 2),
		"a slick block from the palette is a 2 m slick cube")
	check(editor._dirty, "and the level is marked unsaved")
	editor.choose("")
	var stretched := block.duplicate(true)
	EditorGizmo.resized(stretched, 0, 1, 2.0)
	check(LevelData.vec(stretched["size"]).x == 4.0 and LevelData.vec(stretched["pos"]).x == 1.0,
		"stretching from the +x face keeps the -x face where it was")
	EditorGizmo.resized(stretched, 1, -1, 1.0)
	check(LevelData.vec(stretched["size"]).y == 3.0 and LevelData.vec(stretched["pos"]).y == -1.0,
		"and from the bottom, the top stays")
	var kinds := editor._gizmo.handles.map(func(h: Dictionary) -> int: return h["kind"])
	check(kinds.count(EditorGizmo.Kind.SIZE) == 6 and kinds.count(EditorGizmo.Kind.MOVE) == 3,
		"a selected block has a handle on each face and an arrow for each axis")
	# Drag each arrow as the mouse would, seen from up and to one side.
	editor.camera.global_position = Vector3(9.0, 11.0, 6.0)
	editor.camera.look_at(Vector3(0.0, 1.0, -8.0))
	editor._gizmo.update_view(editor.camera)
	for axis in 3:
		var handle: Dictionary = editor._gizmo.handles.filter(func(h: Dictionary) -> bool:
			return h["kind"] == EditorGizmo.Kind.MOVE and h["axis"] == axis)[0]
		var was := LevelData.vec(block["pos"])
		var at: Vector3 = handle["at"]
		var away := Vector3.ZERO
		away[axis] = 3.0
		editor._begin_drag(handle, editor.camera.unproject_position(at))
		editor._drag_to(editor.camera.unproject_position(at + away), false)
		editor._release()
		var moved := LevelData.vec(block["pos"]) - was
		check(moved.is_equal_approx(away), "dragging the %s arrow moves it along %s only (%s)"
			% [["red", "green", "blue"][axis], ["x", "y", "z"][axis], moved])
		editor._gizmo.update_view(editor.camera)
	var size_handle: Dictionary = editor._gizmo.handles.filter(func(h: Dictionary) -> bool:
		return h["kind"] == EditorGizmo.Kind.SIZE and h["axis"] == 2 and h["sign"] == -1)[0]
	var size_at: Vector3 = size_handle["at"]
	editor._begin_drag(size_handle, editor.camera.unproject_position(size_at))
	editor._drag_to(editor.camera.unproject_position(size_at + Vector3(0.0, 0.0, -2.0)), false)
	editor._release()
	check(LevelData.vec(block["size"]).z == 4.0, "dragging a face's square stretches it (%s)"
		% LevelData.vec(block["size"]))
	var count: int = editor.level["objects"].size()
	editor.delete_selected()
	editor.undo()
	editor.redo()
	check(editor.level["objects"].size() == count - 1, "undo, then redo, deletes it again")
	editor._select_thing(editor.level["objects"][0])
	editor.duplicate_selected()
	editor._escape()
	check(editor.level["objects"].size() == count, "a copy set down with Esc stays")
	editor.undo()
	check(editor.level["objects"].size() == count - 1, "and one undo takes it away")


## Flies: put down in the air, and given each way of moving.
func _editor_flies(editor: LevelEditor) -> void:
	editor.open(LevelData.blank("Flies"), "")
	editor.choose("fly")
	var fly := editor.place("fly", Vector3(0.0, 0.0, -4.0))
	check(LevelData.vec(fly["pos"]).y >= 1.5, "a fly is put down in the air, not on the floor")
	LevelEditor.set_fly_move(fly, "line")
	check(fly.has("travel") and not fly.has("axis"), "back and forth: it gets a far end")
	editor._rebuild_thing(fly)
	check(editor._gizmo.handles.any(func(h: Dictionary) -> bool:
		return h["kind"] == EditorGizmo.Kind.END and h["key"] == "travel"),
		"with a ball to drag it to")
	LevelEditor.set_fly_move(fly, "orbit")
	check(fly.has("axis") and fly.has("radius") and not fly.has("travel"),
		"an orbit: an axis and how far out")
	LevelEditor.set_fly_move(fly, "still")
	check(not fly.has("axis") and not fly.has("travel"), "and still: neither")


## What the editor says is wrong with a level, and painting a cutter's lasers.
func _editor_checks(editor: LevelEditor) -> void:
	editor.open(LevelData.blank("Checks"), "")
	check(editor.problems().is_empty(), "a new level has nothing wrong with it")
	var door := editor.place("door", Vector3(0.0, 0.0, -4.0))
	door["channel"] = "gate"
	check(editor.problems().any(func(p: Dictionary) -> bool: return is_same(p["thing"], door)),
		"a door with no plate on its link is flagged")
	var plate := editor.place("plate", Vector3(0.0, 0.0, 2.0))
	plate["channel"] = "gate"
	var wrong := editor.problems()
	check(not wrong.any(func(p: Dictionary) -> bool: return is_same(p["thing"], door)),
		"a plate on the link answers it")
	check(wrong.any(func(p: Dictionary) -> bool: return String(p["text"]).contains("crate")),
		"and a plate with no crate to hold it down is flagged")
	check(editor.links() == ["gate"], "the links in use are listed")
	var cells := MaskGrid.new()
	cells.setup(Vector3(4.5, 4.5, 0.2), [])
	cells.set_cell(1, 1, false)
	check(cells.mask() == ["###", "#.#"], "painting a cell open makes a hole in the mask (%s)"
		% [cells.mask()])
	cells.free()


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


## Throws a web at [param point], grapples onto it in flight and rides it, until it
## sticks or stops dead (out of reach, or on slick) and the spider drops. Whether the
## spider is back on its feet.
func ride(run: LevelRun, point: Vector3) -> bool:
	var weaver := run.weaver
	var web := await throw_at(run, point, 0.6)
	if web == null:
		return false
	await run_frames(4)
	aim(run, web.global_position)
	if not weaver.fire_grapple():
		return false
	await wait_until(func() -> bool: return weaver.mode == Weaver.Mode.WEB, 60)
	if weaver.standing_web() != web:
		return false
	await wait_until(func() -> bool: return weaver.standing_web() != web or web.is_stuck(), 120)
	if OS.has_environment("ROUTE_DEBUG"):
		note("ride over %s" % where(run))
	return await wait_until(func() -> bool:
		return weaver.mode == Weaver.Mode.GROUND or weaver.mode == Weaver.Mode.WEB, 120)


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


func _first_of(type: Variant) -> Node:
	for node in get_root().get_tree().get_nodes_in_group(LevelBuilder.GROUP):
		if is_instance_of(node, type):
			return node
	return null


## Walks into the exit, and says whether the level was finished.
func finish(run: LevelRun, exit_at: Vector3) -> bool:
	await go(run, exit_at, 0.4)
	await wait_until(func() -> bool: return run.done, 60)
	return run.done


## Throws a web at [param fly], leading it if it moves, and waits to see it caught.
## The web, if it caught it; null if it missed.
func catch_fly(run: LevelRun, fly: Fly) -> ThrownWeb:
	var weaver := run.weaver
	var eye := weaver.view.aim_pivot()
	var aim_at := fly.global_position
	for i in 3:
		var flight := eye.distance_to(aim_at) / SilkCaster.SPEED
		aim_at = fly.where_at(run.time + flight + 0.03)
	var web := await throw_at(run, aim_at, 0.0)
	if web == null:
		return null
	var ref: WeakRef = weakref(web)
	await wait_until(func() -> bool:
		var w := ref.get_ref() as ThrownWeb
		return w == null or not w.is_flying(), 90)
	var now := ref.get_ref() as ThrownWeb
	return now if now != null and now.holds_fly() and now.fly == fly else null


## Catches [param fly] and grapples to it: strung up where it was. Whether it went.
func hop_to(run: LevelRun, fly: Fly) -> bool:
	var web := await catch_fly(run, fly)
	if web == null:
		return false
	var weaver := run.weaver
	aim(run, web.global_position)
	if not weaver.fire_grapple():
		return false
	await wait_until(func() -> bool: return weaver.mode != Weaver.Mode.GRAPPLE, 120)
	return weaver.mode == Weaver.Mode.HUNG


## The flies in the level, nearest the start first.
func flies_of(run: LevelRun) -> Array:
	var found: Array = run.get_tree().get_nodes_in_group(Fly.GROUP)
	found.sort_custom(func(a: Fly, b: Fly) -> bool: return a.global_position.z > b.global_position.z)
	return found


## From strung up, a web onto the stone floor at [param point], grappled to: down
## on it, and off it onto the floor.
func down_onto(run: LevelRun, point: Vector3) -> bool:
	var web := await throw_at(run, point, 0.0)
	if not await stuck(web):
		return false
	await grapple_to(run, web.global_position)
	return run.weaver.standing_web() == web or run.weaver.mode == Weaver.Mode.GROUND


func where(run: LevelRun) -> String:
	return "at %s, %s" % [run.weaver.global_position.snappedf(0.1),
		Weaver.Mode.keys()[run.weaver.mode]]


# --- the routes -------------------------------------------------------------------

func _first_thread() -> void:
	print("Route: First Thread")
	var run := await load_level("01_first_thread.json")
	var weaver := run.weaver
	await go(run, Vector3(0, 0, -5.4), 0.2, true)
	check(await leap(run, Vector3(0, 0, -12)) and weaver.global_position.z < -9.0,
		"a jump takes the gap (%s)" % where(run))
	await stop(run)
	await go(run, Vector3(0, 0, -19))
	check(await web_onto(run, Vector3(0, 2.5, -21.8)) and weaver.global_position.y > 3.9,
		"a web on the stone face, a grapple onto it, and up it onto the top (%s)" % where(run))
	await stop(run)
	await pull(run)
	await go(run, Vector3(0, 4, -33))
	await stop(run)
	var board := await throw_at(run, Vector3(0, 6, -36.6), 0.0)
	check(await stuck(board) and board.loose, "a web on the boards over the way out")
	aim(run, board.global_position)
	check(not weaver.fire_grapple(), "which won't hold the spider")
	await pull(run)
	await run_frames(10)
	check(await finish(run, Vector3(0, 4, -41)), "called home, it rips them off: and out")


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
	# The way out is shut by a block on an upright rail: web it, call it home, and it
	# slides up out of the doorway.
	var gate: SlideBlock = _first_of(SlideBlock) as SlideBlock
	await go(run, Vector3(0, 14, -15), 0.2)
	await stop(run)
	var on_gate := await throw_at(run, Vector3(0, 15.4, -19.6), 0.0)
	check(await stuck(on_gate) and on_gate.get_parent() == gate, "a web on the block in the doorway")
	await pull(run)
	await wait_until(func() -> bool: return gate.along() > 0.999, 180)
	check(gate.global_position.y > 16.1,
		"called home, it slides up to the top of its rail (base %.1f)" % gate.global_position.y)
	await go(run, Vector3(0, 14, -17.5))
	await stop(run)
	check(await finish(run, Vector3(0, 14, -25)), "and under it, out")


func _drop_in() -> void:
	print("Route: Drop In")
	var run := await load_level("03_drop_in.json")
	var weaver := run.weaver
	await go(run, Vector3(0, 0, -5.0))
	aim(run, Vector3(0, 0, -19))
	check(weaver.grapple.aimed().get("web") == null, "the island is slick: nothing to grapple")
	check(await ride(run, Vector3(0, 4, -21))
		and weaver.global_position.z < -16.5 and weaver.global_position.y > -0.5,
		"a web ridden out over the island, stopped dead on the hut's slick wall: a drop onto it (%s)"
		% where(run))
	await go(run, Vector3(0, 0, -18.5))
	await stop(run)
	var board := await throw_at(run, Vector3(0, 1.5, -20.7), 0.0)
	check(await stuck(board) and board.loose, "a web on the boards over the hut's door")
	await pull(run)
	await run_frames(10)
	check(await finish(run, Vector3(0, 0, -23.2)), "called home, it rips them off: and out")


func _cut_lines() -> void:
	print("Route: Cut Lines")
	var run := await load_level("04_cut_lines.json")
	var weaver := run.weaver
	await go(run, Vector3(3.5, 0, -5.0), 0.2)
	await stop(run)
	var straight := await throw_at(run, Vector3(-3, 3, -14), 0.0)
	await wait_until(func() -> bool:
		return not is_instance_valid(straight) or not straight.is_flying(), 60)
	check(not is_instance_valid(straight) or not straight.is_standing(),
		"a web thrown into the curtain is cut")
	check(await ride(run, Vector3(3.5, 3.5, -14)) and weaver.global_position.z < -22.0
		and weaver.global_position.y > -0.5,
		"one ridden through the window, out of reach over the far side, and a drop (%s)"
		% where(run))
	await go(run, Vector3(0, 0, -28))
	await stop(run)
	aim(run, Vector3(0, 1.5, -34.7))
	weaver.caster._cooling = 0.0
	var blocked := await throw_at(run, Vector3(0, 1.5, -34.7), 0.0)
	await wait_until(func() -> bool:
		return not is_instance_valid(blocked) or not blocked.is_flying(), 60)
	check(not is_instance_valid(blocked) or not blocked.is_standing(),
		"the boards are boxed in by cutters: a web at them from outside is cut")
	await go(run, Vector3(0, 0, -32.5), 0.2)
	await stop(run)
	check(weaver.global_position.z < -31.5, "but the spider walks through")
	var board := await throw_at(run, Vector3(0, 1.5, -34.7), 0.0)
	check(await stuck(board) and board.loose, "and from inside, a web on the boards")
	await pull(run)
	await run_frames(10)
	check(await finish(run, Vector3(0, 0, -37.5)), "called home, it rips them off: and out")


func _call_it_back() -> void:
	print("Route: Call It Back")
	var run := await load_level("05_call_it_back.json")
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
	var run := await load_level("06_moving_parts.json")
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
	check(await finish(run, Vector3(0, 10, -55.5)), "through the door the plate opened: out")


func _pull_the_room() -> void:
	print("Route: Pull the Room")
	var run := await load_level("07_pull_the_room.json")
	var weaver := run.weaver
	var plug: SlideBlock = null
	var step: SlideBlock = null
	for node in get_root().get_tree().get_nodes_in_group(LevelBuilder.GROUP):
		var block := node as SlideBlock
		if block != null:
			if absf(block.travel.y) > 0.5:
				step = block
			else:
				plug = block
	await go(run, Vector3(0, 0, -8))
	await stop(run)
	var on_plug := await throw_at(run, Vector3(0, 1.5, -14.1), 0.0)
	check(await stuck(on_plug) and on_plug.get_parent() == plug, "a web on the block in the doorway")
	await pull(run)
	await wait_until(func() -> bool: return plug.along() > 0.999, 180)
	check(plug.global_position.x > 4.9,
		"called home, it slides to the other end of its rail, out of the way (x %.1f)"
		% plug.global_position.x)
	await go(run, Vector3(0, 0, -13))
	await go(run, Vector3(0, 0, -25))
	await stop(run)
	var on_step := await throw_at(run, Vector3(0, 4.5, -29.6), 0.0)
	check(await stuck(on_step) and on_step.get_parent() == step,
		"a web on the block plugging the high doorway")
	await pull(run)
	await wait_until(func() -> bool: return step.along() > 0.999, 180)
	check(step.global_position.y < 0.05,
		"called home, it comes down out of the doorway (base %.1f)" % step.global_position.y)
	check(await web_onto(run, Vector3(0, 1.5, -29.6)) and weaver.global_position.y > 2.9,
		"and a web on it, now under the doorway, is the way up onto it (%s)" % where(run))
	await stop(run)
	check(await finish(run, Vector3(0, 3, -36)), "and through, out")


func _fly_paper() -> void:
	print("Route: Fly Paper")
	var run := await load_level("09_fly_paper.json")
	var weaver := run.weaver
	var flies := flies_of(run)
	var high: Fly = flies.filter(func(f: Fly) -> bool: return f.global_position.y > 6.0)[0]
	var hops: Array = flies.filter(func(f: Fly) -> bool: return f.global_position.y < 6.0)
	check(run.flies_total == 4 and not run.exit.open, "four flies, and the bag shut")
	await go(run, Vector3(0, 0, -3), 0.3)
	await stop(run)
	var far := await catch_fly(run, high)
	check(far != null, "the high fly, out over nothing, caught from the ledge")
	weaver.pullback._cooling = 0.0
	weaver.pullback.cast()
	await wait_until(func() -> bool: return run.flies_taken == 1, 90)
	check(run.flies_taken == 1, "and called home with the web")
	for i in hops.size():
		var went := await hop_to(run, hops[i])
		if not check(went, "fly %d: caught, grappled to, strung up (%s)" % [i + 1, where(run)]):
			return
	check(run.flies_taken == 4 and run.exit.open, "every fly taken: the bag opens")
	check(await down_onto(run, Vector3(0, 0, -36.5)), "from the last, a web onto the far side and down (%s)"
		% where(run))
	await go(run, Vector3(0, 0, -38.5), 0.3)
	await stop(run)
	var board := await throw_at(run, Vector3(0, 1.4, -40.7), 0.0)
	check(await stuck(board) and board.loose, "a web on the hut's boards")
	await pull(run)
	await run_frames(10)
	check(await finish(run, Vector3(0, 0, -43.2)), "ripped off: into the bag")


func _clockwork_flies() -> void:
	print("Route: Clockwork Flies")
	var run := await load_level("10_clockwork_flies.json")
	var flies := flies_of(run)
	check(run.flies_total == 3, "three flies, all moving")
	await go(run, Vector3(0, 0, -3), 0.3)
	await stop(run)
	for i in flies.size():
		var went := await hop_to(run, flies[i])
		if not check(went, "moving fly %d: led, caught, grappled to (%s)" % [i + 1, where(run)]):
			return
	check(run.exit.open, "every fly taken: the bag opens")
	check(await down_onto(run, Vector3(0, 0, -36.5)), "down onto the far side (%s)" % where(run))
	await go(run, Vector3(0, 0, -38.5), 0.3)
	await stop(run)
	var board := await throw_at(run, Vector3(0, 1.4, -40.7), 0.0)
	check(await stuck(board) and board.loose, "a web on the boards")
	await pull(run)
	await run_frames(10)
	check(await finish(run, Vector3(0, 0, -43.2)), "and into the bag")


func _all_together() -> void:
	print("Route: All Together")
	var run := await load_level("08_all_together.json")
	var weaver := run.weaver
	await go(run, Vector3(0, 0, -5.0))
	check(await web_onto(run, Vector3(0, 1.8, -24), 0.6),
		"over the drop: a web on the stone face, and a grapple to it, and up (%s)" % where(run))
	check(weaver.global_position.y > 3.9, "up and over the cap (%s)" % where(run))
	await go(run, Vector3(0, 0, -30))
	await stop(run)
	await pull(run)
	await go(run, Vector3(0, 0, -34.5))
	var low := await throw_at(run, Vector3(0, 2.4, -36))
	await stuck(low)
	await go(run, Vector3(0, 0, -36.5), 0.2)
	await climb(run, 50)
	var mid := await throw_at(run, Vector3(0, 6.5, -36))
	await stuck(mid)
	await grapple_to(run, mid.global_position)
	await pull(run)
	var high := await throw_at(run, Vector3(0, 9.4, -36))
	await stuck(high)
	await grapple_to(run, high.global_position)
	await climb(run)
	check(weaver.global_position.y > 11.9 and weaver.mode == Weaver.Mode.GROUND,
		"up the tower on two webs, leapfrogged (%s)" % where(run))
	await pull(run)
	await go(run, Vector3(4, 12, -45), 0.2)
	await stop(run)
	var board := await throw_at(run, Vector3(5.5, 15, -48.7), 0.0)
	check(await stuck(board) and board.loose, "a web on the boards over the crate's window")
	await pull(run)
	await run_frames(10)
	var went := await go(run, Vector3(4, 12, -43), 0.2)
	await stop(run)
	if OS.has_environment("ROUTE_DEBUG"):
		note("to the plate %s: %s, look %s" % [went, where(run), weaver.view.forward()])
	var crate := get_root().get_tree().get_nodes_in_group(Crate.GROUP)[0] as Crate
	var on_crate := await throw_at(run, crate.global_position, 0.0)
	check(await stuck(on_crate) and on_crate.carried == crate, "a web on the crate")
	await pull(run)
	await run_frames(100)
	if not check(run.is_powered("bag"), "brought onto the plate, it opens the exit's door"):
		note("crate at %s, spider %s" % [crate.global_position.snappedf(0.1), where(run)])
	await go(run, Vector3(0, 12, -48))
	check(await finish(run, Vector3(0, 12, -53)), "and out")
