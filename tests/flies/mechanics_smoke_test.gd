extends TestSuite

## The three verbs and everything they touch, each in a fresh arena:
##
##     godot --headless --path . --script res://tests/flies/mechanics_smoke_test.gd
##
## Walking and jumping; walls that cannot be climbed; silk wound up and thrown,
## sticking flat, sliding off slick metal and coming apart at the end of its
## reach; walking onto a web and up a wall on it; the grapple, spent in the air
## and back on landing, and holding to a wall; riding a thrown web; the ceiling;
## webs walked on one face; a crate brought home and onto a plate that opens a
## door; a platform carrying a web; flies caught, reached, hung from and called
## home; and the exit.

const FLOOR_TOP := 0.0


func run_checks() -> void:
	await _running_and_walls()
	await _throwing_silk()
	await _slick_and_reach()
	await _walking_on_webs()
	await _grappling()
	await _riding_a_web()
	await _grapple_to_the_middle()
	await _rides_go_nowhere_for_free()
	await _silk_cutters()
	await _cutter_masks()
	await _catching_flies()
	await _riding_into_a_fly()
	await _flies_that_move()
	await _fly_bodies()
	await _dropping_mid_pull()
	await _the_ceiling()
	await _one_face()
	await _pullback()
	await _caught_by_your_web()
	await _throwing_in_the_air()
	await _crates_plates_doors()
	await _boards_and_blocks()
	await _platforms()
	await _the_exit()


# --- the arena -----------------------------------------------------------------

## A floor, a stone wall to the north, a slick one to the east, a ledge to the
## west, and whatever [param extra] adds.
func arena(extra: Array = [], webs := 3) -> LevelRun:
	var objects: Array = [
		{"type": "piece", "piece": "cube", "pos": [0.0, -1.0, 0.0], "size": [80.0, 1.0, 80.0]},
		{"type": "piece", "piece": "cube", "pos": [0.0, 0.0, -12.0], "size": [14.0, 8.0, 1.0]},
		{"type": "piece", "piece": "cube", "pos": [14.0, 0.0, 0.0], "rot": [0.0, 90.0, 0.0],
			"size": [14.0, 8.0, 1.0], "surface": "slick"},
		{"type": "piece", "piece": "cube", "pos": [-12.0, 0.0, 0.0], "size": [6.0, 4.0, 6.0]},
		{"type": "start", "pos": [0.0, 0.2, 4.0]},
	]
	objects.append_array(extra)
	var level := {"name": "Arena", "webs": webs, "kill_y": -20.0,
		"objects": objects}
	var run := LevelRun.new()
	run.require_captured_mouse = false
	run.setup(level)
	await stage(run)
	await run_frames(10)
	return run


## Turns the view so the cross is on [param point].
func aim(run: LevelRun, point: Vector3) -> void:
	var weaver := run.weaver
	for i in 4:
		weaver.view.update(Weaver.HEIGHT, weaver.global_basis.y)
		var from := weaver.view.aim_pivot()
		var d := (point - from).normalized()
		weaver.view.yaw = atan2(-d.x, -d.z)
		weaver.view.pitch = asin(clampf(d.y, -1.0, 1.0))
	weaver.view.update(Weaver.HEIGHT, weaver.global_basis.y)


func put(run: LevelRun, at: Vector3) -> void:
	run.weaver.put_at(Transform3D(Basis.IDENTITY, at))
	await run_frames(4)


func first_web(run: LevelRun) -> ThrownWeb:
	var webs := run.weaver.webs()
	return webs[0] if not webs.is_empty() else null


# --- the sections -------------------------------------------------------------

func _running_and_walls() -> void:
	print("Running, and walls")
	var run := await arena()
	var weaver := run.weaver
	check(weaver.mode == Weaver.Mode.GROUND, "the spider starts on its feet")
	check(absf(weaver.global_position.y - (FLOOR_TOP + Weaver.RADIUS)) < 0.05,
		"standing on the floor")
	aim(run, Vector3(0.0, 0.3, -20.0))
	weaver.drive(Vector2(0.0, 1.0))
	await run_frames(20)
	var speed := Vector2(weaver.velocity.x, weaver.velocity.z).length()
	check(absf(speed - Weaver.WALK) < 0.3, "walks at a walk (%.1f m/s)" % speed)
	await run_frames(140)
	check(weaver.global_position.z > -11.6 and weaver.global_position.y < 0.6,
		"walking into a stone wall does not take it up the wall (y %.2f)" % weaver.global_position.y)
	weaver.drive(Vector2.ZERO, true)
	await run_frames(8)
	check(weaver.mode == Weaver.Mode.AIR and weaver.velocity.y > 0.0, "jumps")
	await wait_until(func() -> bool: return weaver.mode == Weaver.Mode.GROUND, 120)
	check(weaver.mode == Weaver.Mode.GROUND, "and comes back down")


func _throwing_silk() -> void:
	print("Throwing silk")
	var run := await arena()
	var weaver := run.weaver
	await put(run, Vector3(0.0, 0.3, 0.0))
	aim(run, Vector3(0.0, 3.0, -11.5))
	weaver.caster.begin()
	check(weaver.caster.held_ball() != null, "holding silk winds a ball up over the spider")
	await run_frames(70)
	check(weaver.caster.charge > 0.99, "a second's hold winds it all the way")
	check(weaver.caster.release(), "letting go throws")
	var web := first_web(run)
	if not check(web != null and web.is_flying(), "a web is in the air"):
		return
	check(is_equal_approx(web.radius, SilkCaster.BIGGEST), "wound right up, it is the biggest")
	check(weaver.webs_left() == 2, "one of three webs is out")
	await wait_until(func() -> bool: return web.is_stuck(), 90)
	if not check(web.is_stuck(), "it sticks where it lands"):
		return
	check(web.normal().dot(Vector3.BACK) > 0.98, "flat against the wall it hit, facing out")
	check(absf(web.global_position.z - (-11.5)) < 0.1, "on the wall's face (z %.2f)"
		% web.global_position.z)
	weaver.caster.throw(0.0)
	var small: ThrownWeb = weaver.webs()[1]
	check(is_equal_approx(small.radius, SilkCaster.SMALLEST), "a tap throws the smallest")
	weaver.caster._cooling = 0.0
	weaver.caster.throw(0.0)
	weaver.caster._cooling = 0.0
	check(weaver.webs_left() == 0, "three out, none left")
	check(not weaver.caster.throw(0.0), "and a fourth will not go")


func _slick_and_reach() -> void:
	print("Slick, and the end of silk's reach")
	var run := await arena()
	var weaver := run.weaver
	await put(run, Vector3(0.0, 0.3, 0.0))
	aim(run, Vector3(13.5, 2.0, 0.0))
	weaver.caster.throw(0.0)
	var web := first_web(run)
	await wait_until(func() -> bool: return not is_instance_valid(web) or not web.is_standing(), 60)
	check(not is_instance_valid(web) or web.state == ThrownWeb.State.GONE,
		"a web thrown at slick metal slides off and comes apart")
	check(weaver.webs_left() == 3, "and its silk is back")
	var target := aim_line(run)
	check(not target.is_empty() and target.get("web") == null,
		"the grapple finds no silk on slick metal")
	check(not weaver.fire_grapple(), "and will not hold on it")
	aim(run, Vector3(0.0, 40.0, 30.0))
	weaver.caster.throw(0.0)
	web = first_web(run)
	await run_frames(150)
	check(not is_instance_valid(web) or not web.is_standing(),
		"thrown at the open sky, it comes apart at the end of its reach")


func aim_line(run: LevelRun) -> Dictionary:
	return run.weaver.grapple.aimed()


func _walking_on_webs() -> void:
	print("Walking on webs")
	var run := await arena()
	var weaver := run.weaver
	await put(run, Vector3(0.0, 0.3, -6.0))
	# Low on the wall, so the bottom of it meets the floor.
	aim(run, Vector3(0.0, 1.0, -11.5))
	weaver.caster.throw(1.0)
	var web := first_web(run)
	await wait_until(func() -> bool: return web.is_stuck(), 60)
	aim(run, Vector3(0.0, 0.5, -11.5))
	weaver.drive(Vector2(0.0, 1.0))
	await wait_until(func() -> bool: return weaver.mode == Weaver.Mode.WEB, 90)
	if not check(weaver.mode == Weaver.Mode.WEB, "running into a web on a wall takes you onto it"):
		return
	check(weaver.standing_web() == web, "onto that web")
	var low := weaver.global_position.y
	await run_frames(40)
	check(weaver.global_position.y > low + 0.8, "and W walks up it (%.2f to %.2f)"
		% [low, weaver.global_position.y])
	check(weaver.global_basis.y.dot(Vector3.BACK) > 0.8, "with its back to the room")
	check(weaver.global_position.distance_to(web.global_position) < web.radius,
		"and stops at the rim rather than walking off it")
	weaver.drive(Vector2.ZERO, true)
	await run_frames(4)
	check(weaver.mode == Weaver.Mode.AIR, "jump lets go")
	await wait_until(func() -> bool: return weaver.mode == Weaver.Mode.GROUND, 120)
	check(weaver.global_position.z > -11.0, "and pushes off away from the wall")

	# A web on a ceiling: jump up into it and you hang there.
	var objects: Array = [{"type": "piece", "piece": "cube", "pos": [0.0, 1.5, 0.0],
		"size": [8.0, 1.0, 8.0]}]
	run = await arena(objects)
	weaver = run.weaver
	await put(run, Vector3(6.0, 0.3, 6.0))
	aim(run, Vector3(2.0, 1.5, 2.0))
	weaver.caster.throw(1.0)
	web = first_web(run)
	await wait_until(func() -> bool: return web.is_stuck(), 60)
	check(web.normal().dot(Vector3.DOWN) > 0.98, "a web on a ceiling faces down")
	await put(run, Vector3(web.global_position.x, 0.3, web.global_position.z))
	weaver.drive(Vector2.ZERO, true)
	await wait_until(func() -> bool: return weaver.mode == Weaver.Mode.WEB, 60)
	check(weaver.mode == Weaver.Mode.WEB, "jumping up into it, the spider holds on")
	await run_frames(30)
	check(weaver.mode == Weaver.Mode.WEB and weaver.global_basis.y.y < -0.8,
		"and hangs from it upside down")


func _grappling() -> void:
	print("Grappling")
	var run := await arena()
	var weaver := run.weaver
	await put(run, Vector3(0.0, 0.3, 10.0))
	aim(run, Vector3(-9.0, 3.0, 0.0))
	var target := weaver.grapple.aimed()
	check(not target.is_empty() and target.get("web") == null,
		"the cross on bare stone: nothing for the grapple")
	check(not weaver.fire_grapple(), "and left mouse does nothing there")
	weaver.caster.throw(0.0)
	var web := first_web(run)
	check(await wait_until(func() -> bool: return web.is_stuck(), 60),
		"a web thrown at the ledge's face sticks there")
	aim(run, web.global_position)
	check(weaver.grapple.aimed().get("web") == web, "and the grapple finds it")
	check(weaver.fire_grapple(), "left mouse puts a line on it")
	check(weaver.mode == Weaver.Mode.GRAPPLE and not weaver.grapple_ready,
		"and pulls, spending the grapple")
	check(not weaver.fire_grapple(), "with no second line while the first pulls")
	await wait_until(func() -> bool: return weaver.mode != Weaver.Mode.GRAPPLE, 90)
	check(weaver.standing_web() == web, "the pull ends on the web")
	check(weaver.grapple_ready, "and landing on a web that has stuck gives the grapple back")
	weaver.view.yaw = PI * 0.5
	weaver.view.pitch = 0.0
	weaver.drive(Vector2(0.0, 1.0))
	await wait_until(func() -> bool: return weaver.mode == Weaver.Mode.GROUND, 120)
	weaver.drive(Vector2.ZERO)
	check(weaver.global_position.y > 3.9, "up the web and over onto the ledge (y %.2f)"
		% weaver.global_position.y)

	await put(run, Vector3(0.0, 0.3, 2.0))
	await pull(run)
	aim(run, Vector3(0.0, 2.0, -11.5))
	weaver.caster.throw(0.0)
	web = first_web(run)
	await wait_until(func() -> bool: return web.is_stuck(), 60)
	aim(run, web.global_position)
	await put(run, Vector3(0.0, 0.3, 30.0))
	aim(run, web.global_position)
	check(weaver.grapple.aimed().get("web") == web,
		"a web forty metres off is in reach: the grapple goes as far as you can see")
	await put(run, Vector3(-12.0, 0.3, 6.0))
	aim(run, web.global_position)
	check(weaver.grapple.aimed().get("web") == null, "but not one out of sight, behind the ledge")


func _riding_a_web() -> void:
	print("Riding a web")
	var run := await arena()
	var weaver := run.weaver
	await put(run, Vector3(0.0, 0.3, 8.0))
	aim(run, Vector3(0.0, 2.5, -11.5))
	weaver.caster.throw(0.5)
	var web := first_web(run)
	await run_frames(8)
	aim(run, web.global_position)
	check(weaver.grapple.aimed().get("web") == web, "a web in the air can be grappled")
	check(weaver.fire_grapple(), "and the line goes onto it")
	await wait_until(func() -> bool: return weaver.mode == Weaver.Mode.WEB, 60)
	if not check(weaver.mode == Weaver.Mode.WEB and weaver.standing_web() == web,
			"the spider lands on the flying web"):
		return
	check(web.is_flying(), "while it is still flying")
	check(not weaver.grapple_ready, "a ride gives nothing back: the grapple stays spent")
	var before := weaver.global_position
	await run_frames(5)
	check(weaver.global_position.z < before.z - 1.0, "the web carries the spider along")
	await wait_until(func() -> bool: return web.is_stuck(), 120)
	check(web.is_stuck() and weaver.standing_web() == web,
		"and when the web sticks, the spider is standing on it on the wall")
	check(weaver.grapple_ready, "landed with it: the grapple is back")
	check(weaver.global_position.z > -11.5, "on the room's side of it")



## A grapple lands you in the middle of the web, wherever on it you aimed.
func _grapple_to_the_middle() -> void:
	print("Grappling to the middle")
	var run := await arena()
	var weaver := run.weaver
	await put(run, Vector3(0.0, 0.3, 4.0))
	aim(run, Vector3(0.0, 3.0, -11.5))
	weaver.caster.throw(1.0)
	var web := first_web(run)
	await wait_until(func() -> bool: return web.is_stuck(), 60)
	var rim := web.global_position + web.global_basis.x.normalized() * (web.radius - 0.3)
	aim(run, rim)
	check(weaver.grapple.aimed().get("web") == web, "aimed at the web's rim")
	weaver.fire_grapple()
	await wait_until(func() -> bool: return weaver.mode != Weaver.Mode.GRAPPLE, 120)
	var off := web.to_local(weaver.global_position)
	check(weaver.standing_web() == web and Vector2(off.x, off.y).length() < 0.15,
		"the pull ends at its middle (%.2f m off)" % Vector2(off.x, off.y).length())

## What stops throw-and-ride from being a way to fly anywhere.
func _rides_go_nowhere_for_free() -> void:
	print("Rides go nowhere for free")
	var run := await arena()
	var weaver := run.weaver
	# Thrown at the open sky and ridden: at the end of its reach it stops dead.
	await put(run, Vector3(0.0, 0.3, 20.0))
	aim(run, Vector3(0.0, 30.0, 60.0))
	weaver.caster.throw(0.5)
	var web := first_web(run)
	await run_frames(6)
	aim(run, web.global_position)
	weaver.fire_grapple()
	await wait_until(func() -> bool: return weaver.mode == Weaver.Mode.WEB, 60)
	check(weaver.standing_web() == web, "riding a web thrown at nothing")
	await wait_until(func() -> bool: return weaver.mode != Weaver.Mode.WEB, 200)
	check(weaver.mode == Weaver.Mode.AIR, "at the end of its reach it comes apart under you")
	await run_frames(2)
	check(Vector2(weaver.velocity.x, weaver.velocity.z).length() < 1.0,
		"and you drop where it stopped, with none of its speed (%.1f m/s)"
		% Vector2(weaver.velocity.x, weaver.velocity.z).length())

	# A ride is a commitment: jump does nothing, and the keys can't walk it off.
	await wait_until(func() -> bool: return weaver.mode == Weaver.Mode.GROUND, 120)
	await put(run, Vector3(0.0, 0.3, 8.0))
	aim(run, Vector3(0.0, 2.5, -11.5))
	weaver.caster._cooling = 0.0
	weaver.caster.throw(0.5)
	web = weaver.webs()[weaver.webs().size() - 1]
	await run_frames(6)
	aim(run, web.global_position)
	weaver.fire_grapple()
	await wait_until(func() -> bool: return weaver.mode == Weaver.Mode.WEB, 60)
	weaver.drive(Vector2.ZERO, true)
	await run_frames(3)
	check(weaver.standing_web() == web and web.is_flying(), "jumping off a web in flight does nothing")
	weaver.drive(Vector2(1.0, 0.0))
	await run_frames(12)
	check(weaver.standing_web() == web or web.is_stuck(), "nor does walking off its rim")
	weaver.drive(Vector2.ZERO)
	await wait_until(func() -> bool: return web.is_stuck(), 120)
	check(weaver.standing_web() == web, "you go where the web goes")


## Silk cutters cut any web that flies through them, stop a ride dead there, and
## won't let a grapple line across; the spider walks through them.
func _silk_cutters() -> void:
	print("Silk cutters")
	var objects: Array = [{"type": "cutter", "pos": [0.0, 0.0, -4.0], "size": [6.0, 6.0, 0.2]}]
	var run := await arena(objects)
	var weaver := run.weaver
	await put(run, Vector3(0.0, 0.3, 2.0))
	aim(run, Vector3(0.0, 2.0, -11.5))
	weaver.caster.throw(0.0)
	var web := first_web(run)
	await wait_until(func() -> bool: return not is_instance_valid(web) or not web.is_flying(), 60)
	check(not is_instance_valid(web) or (not web.is_standing() and web.global_position.z > -4.6),
		"a web thrown through a silk cutter is cut there")
	check(weaver.webs_left() == 3, "and its silk is back")
	# A web stuck past the cutter, put there from the side: the line won't cross.
	await put(run, Vector3(6.0, 0.3, -6.0))
	aim(run, Vector3(0.0, 2.0, -11.5))
	weaver.caster._cooling = 0.0
	weaver.caster.throw(0.0)
	var past := weaver.webs()[weaver.webs().size() - 1]
	await wait_until(func() -> bool: return past.is_stuck(), 60)
	await put(run, Vector3(0.0, 0.3, 2.0))
	aim(run, past.global_position)
	check(weaver.grapple.aimed().get("web") == null and weaver.grapple.aimed().get("cut", false),
		"a grapple line won't cross a silk cutter")
	check(not weaver.fire_grapple(), "so it doesn't go")
	await pull(run)
	# Ridden into a cutter: the ride stops dead there.
	await put(run, Vector3(0.0, 0.3, 8.0))
	aim(run, Vector3(0.0, 2.5, -11.5))
	weaver.caster._cooling = 0.0
	weaver.caster.throw(0.5)
	var ride := weaver.webs()[weaver.webs().size() - 1]
	await run_frames(4)
	aim(run, ride.global_position)
	weaver.fire_grapple()
	await wait_until(func() -> bool: return weaver.mode == Weaver.Mode.WEB, 60)
	check(weaver.standing_web() == ride, "riding a web at the cutter")
	await wait_until(func() -> bool: return weaver.mode != Weaver.Mode.WEB, 120)
	check(weaver.mode == Weaver.Mode.AIR and weaver.global_position.z > -4.5
		and Vector2(weaver.velocity.x, weaver.velocity.z).length() < 1.0,
		"cut under it, the ride stops dead and the spider drops (%s)" % where_is(weaver))
	# Walking through one.
	await wait_until(func() -> bool: return weaver.mode == Weaver.Mode.GROUND, 120)
	await put(run, Vector3(0.0, 0.3, -1.0))
	aim(run, Vector3(0.0, 0.3, -10.0))
	weaver.drive(Vector2(0.0, 1.0))
	await run_frames(70)
	weaver.drive(Vector2.ZERO)
	check(weaver.global_position.z < -6.0, "and the spider walks through it (z %.1f)"
		% weaver.global_position.z)



## A cutter laid out like a tile map: its mask leaves a hole silk can pass, and
## the frame runs only round the hole and the outside.
func _cutter_masks() -> void:
	print("Cutter masks")
	# 6 m square in 1.5 m cells: x -3..3, y 0..6; the hole is x -1.5..0, y 1.5..4.5.
	var objects: Array = [{"type": "cutter", "pos": [0.0, 0.0, -4.0], "size": [6.0, 6.0, 0.2],
		"mask": ["####", "#.##", "#.##", "####"]}]
	var run := await arena(objects)
	var weaver := run.weaver
	var cutter := run.get_tree().get_nodes_in_group(SilkCutter.GROUP)[0] as SilkCutter
	check(not cutter.filled(1, 1) and not cutter.filled(1, 2) and cutter.filled(0, 1)
		and cutter.filled(1, 0) and cutter.filled(1, 3), "the mask's rows run top first")
	var solids := 0
	for child in cutter.get_children():
		if child is CollisionShape3D:
			solids += 1
	check(solids == 6, "one solid per run of filled cells along a row (%d)" % solids)
	var space := cutter.get_world_3d().direct_space_state
	check(SilkCutter.crossing(space, Vector3(-0.75, 3.0, -2.0), Vector3(-0.75, 3.0, -6.0)).is_empty(),
		"a line through the hole crosses nothing")
	check(not SilkCutter.crossing(space, Vector3(1.5, 3.0, -2.0), Vector3(1.5, 3.0, -6.0)).is_empty(),
		"a line beside it is cut")
	await put(run, Vector3(-0.75, 0.3, 2.0))
	aim(run, Vector3(-0.75, 5.0, -11.5))
	weaver.caster.throw(0.0)
	var through := first_web(run)
	await wait_until(func() -> bool: return not is_instance_valid(through) or not through.is_flying(), 90)
	check(is_instance_valid(through) and through.is_stuck() and through.global_position.z < -10.0,
		"a web thrown through the hole goes on and sticks past it (%s)" % [through.global_position if is_instance_valid(through) else "gone"])
	await pull(run)
	await put(run, Vector3(1.5, 0.3, 2.0))
	aim(run, Vector3(1.5, 5.0, -11.5))
	weaver.caster._cooling = 0.0
	weaver.caster.throw(0.0)
	var beside := weaver.webs()[weaver.webs().size() - 1]
	await wait_until(func() -> bool: return not is_instance_valid(beside) or not beside.is_flying(), 90)
	check(not is_instance_valid(beside) or (not beside.is_stuck() and beside.global_position.z > -4.6),
		"one thrown beside it is cut")


## A fly caught in a web: a grapple point in the air, taken by reaching it — strung
## up for a moment, grapple and web given back — or by calling the web home. The
## bag stays shut until every fly is taken.
func _catching_flies() -> void:
	print("Catching flies")
	var objects: Array = [
		{"type": "fly", "pos": [0.0, 3.0, -6.0]},
		{"type": "fly", "pos": [4.0, 3.0, -6.0]},
		{"type": "fly", "pos": [-4.0, 3.0, -6.0]},
		{"type": "exit", "pos": [8.0, 0.0, 8.0]},
	]
	var run := await arena(objects)
	var weaver := run.weaver
	var flies: Array = run.get_tree().get_nodes_in_group(Fly.GROUP)
	check(run.flies_total == 3 and not run.exit.open, "a level with flies starts with the bag shut")
	var fly: Fly = flies.filter(func(f: Fly) -> bool: return f.global_position.x == 0.0)[0]
	var second: Fly = flies.filter(func(f: Fly) -> bool: return f.global_position.x == 4.0)[0]
	var third: Fly = flies.filter(func(f: Fly) -> bool: return f.global_position.x == -4.0)[0]
	await put(run, Vector3(0.0, 0.3, 2.0))
	aim(run, fly.global_position)
	weaver.caster.throw(0.0)
	var web := first_web(run)
	await wait_until(func() -> bool: return not web.is_flying(), 60)
	check(web.holds_fly() and fly.is_caught(), "a web that hits a fly wraps it and stops there")
	check(weaver.webs_left() == 2, "and stays one of your webs out")
	check(not web.holds_weight(), "it holds a fly, not the spider: nothing to stand on")
	aim(run, fly.global_position)
	check(weaver.grapple.aimed().get("web") == web, "a caught fly is a grapple point")
	var used := weaver.global_position
	weaver.fire_grapple()
	await wait_until(func() -> bool: return weaver.mode == Weaver.Mode.HUNG, 90)
	check(weaver.mode == Weaver.Mode.HUNG and weaver.global_position.distance_to(Vector3(0, 3, -6)) < 0.6,
		"grappled to, it takes you there, strung up in the air (%s)" % weaver.global_position)
	check(run.flies_taken == 1 and weaver.webs_left() == 3,
		"the fly is yours and the web comes back")
	check(weaver.grapple_ready, "and so does the grapple")
	check(used.distance_to(weaver.global_position) > 5.0, "pulled across to it")
	await run_frames(60)
	check(weaver.mode == Weaver.Mode.HUNG and absf(weaver.global_position.y - 3.0) < 0.1,
		"you hang there, not falling, for a while")
	await run_frames(75)
	check(weaver.mode != Weaver.Mode.HUNG, "and after two seconds the frame tears and you drop")
	# Strung up, Space cuts you down at once.
	await put(run, Vector3(4.0, 0.3, 2.0))
	aim(run, second.global_position)
	weaver.caster._cooling = 0.0
	weaver.caster.throw(0.0)
	var other := weaver.webs()[weaver.webs().size() - 1]
	await wait_until(func() -> bool: return not other.is_flying(), 60)
	aim(run, second.global_position)
	weaver.fire_grapple()
	await wait_until(func() -> bool: return weaver.mode == Weaver.Mode.HUNG, 90)
	weaver.drive(Vector2.ZERO, true)
	await run_frames(3)
	check(weaver.mode == Weaver.Mode.AIR and run.flies_taken == 2, "Space drops you out of the frame")
	# Caught from afar and called home: the fly comes with the web.
	await put(run, Vector3(-4.0, 0.3, 2.0))
	aim(run, third.global_position)
	weaver.caster._cooling = 0.0
	weaver.caster.throw(0.0)
	var far := weaver.webs()[weaver.webs().size() - 1]
	await wait_until(func() -> bool: return not far.is_flying(), 60)
	check(third.is_caught(), "a third caught from the ground")
	weaver.pullback._cooling = 0.0
	weaver.pullback.cast()
	await wait_until(func() -> bool: return run.flies_taken == 3, 90)
	check(run.flies_taken == 3 and weaver.webs_left() == 3,
		"called home, the web brings the fly with it, and it is yours")
	check(run.exit.open, "every fly taken: the bag opens")


## A web being ridden that flies into a fly stops there, and the spider takes it.
func _riding_into_a_fly() -> void:
	print("Riding into a fly")
	var run := await arena([{"type": "fly", "pos": [0.0, 2.1, -6.0]}])
	var weaver := run.weaver
	await put(run, Vector3(0.0, 0.3, 8.0))
	aim(run, Vector3(0.0, 2.5, -11.5))
	weaver.caster.throw(0.5)
	var web := first_web(run)
	await run_frames(8)
	aim(run, web.global_position)
	weaver.fire_grapple()
	await wait_until(func() -> bool: return weaver.mode == Weaver.Mode.WEB, 60)
	check(weaver.standing_web() == web and not weaver.grapple_ready, "riding a web at a fly")
	await wait_until(func() -> bool: return weaver.mode != Weaver.Mode.WEB, 120)
	check(weaver.mode == Weaver.Mode.HUNG and run.flies_taken == 1,
		"the ride ends at the fly, and takes it (%s)" % where_is(weaver))
	check(weaver.grapple_ready and weaver.webs_left() == 3, "with the grapple and the web back")


## The three ways a fly goes: still, there and back, and round — on the level's clock.
func _flies_that_move() -> void:
	print("Flies that move")
	var objects: Array = [
		{"type": "fly", "pos": [0.0, 3.0, -4.0], "move": "line", "travel": [6.0, 0.0, 0.0],
			"period": 4.0, "phase": 0.0},
		{"type": "fly", "pos": [0.0, 3.0, -8.0], "move": "orbit", "axis": [0.0, 1.0, 0.0],
			"radius": 2.0, "period": 4.0, "phase": 0.0},
	]
	var run := await arena(objects)
	var flies: Array = run.get_tree().get_nodes_in_group(Fly.GROUP)
	var line: Fly = flies.filter(func(f: Fly) -> bool: return f.move == "line")[0]
	var orbit: Fly = flies.filter(func(f: Fly) -> bool: return f.move == "orbit")[0]
	check(line.where_at(0.0).is_equal_approx(Vector3(0, 3, -4))
		and line.where_at(2.0).is_equal_approx(Vector3(6, 3, -4))
		and line.where_at(4.0).is_equal_approx(Vector3(0, 3, -4)),
		"a fly on a line goes to its far end and back in one trip")
	var round_ok := true
	for i in 8:
		var at := orbit.where_at(float(i) * 0.5)
		round_ok = round_ok and absf(at.distance_to(Vector3(0, 3, -8)) - 2.0) < 0.01 \
			and absf(at.y - 3.0) < 0.01
	check(round_ok, "an orbiting fly keeps its distance, flat about its axis")
	check(line.global_position.is_equal_approx(Vector3(0, 3, -4)), "before the clock starts, flies wait")
	run.running = true
	run.time = 1.0
	await run_frames(2)
	check(line.global_position.distance_to(line.where_at(run.time)) < 0.2,
		"on the clock, they go where the clock says")


## A fly's body has a skeleton: its wings beat and its legs twitch while it flies,
## and everything goes still once a web has it.
func _fly_bodies() -> void:
	print("Fly bodies")
	var run := await arena([{"type": "fly", "pos": [0.0, 3.0, -6.0]}])
	var fly := run.get_tree().get_nodes_in_group(Fly.GROUP)[0] as Fly
	var body := fly.get_node("Body") as FlyBody
	var bones := body.skeleton.get_bone_count()
	var named := func(part: String) -> int:
		var count := 0
		for i in bones:
			if body.skeleton.get_bone_name(i).begins_with(part):
				count += 1
		return count
	check(named.call("wing") == 2 and named.call("femur") == 6 and named.call("tibia") == 6,
		"a fly has two wing bones and six legs of two bones each")
	var wing := body.skeleton.find_bone("wing.L")
	var leg := body.skeleton.find_bone("tibia1.L")
	var wing_was := body.skeleton.get_bone_pose_rotation(wing)
	var leg_was := body.skeleton.get_bone_pose_rotation(leg)
	await run_frames(3)
	check(not body.skeleton.get_bone_pose_rotation(wing).is_equal_approx(wing_was),
		"its wings beat while it flies")
	await run_frames(20)
	check(not body.skeleton.get_bone_pose_rotation(leg).is_equal_approx(leg_was),
		"and its legs move")
	await put(run, Vector3(0.0, 0.3, 2.0))
	aim(run, fly.global_position)
	run.weaver.caster.throw(0.0)
	await wait_until(func() -> bool: return fly.is_caught(), 60)
	var folded := body.skeleton.get_bone_pose_rotation(wing)
	await run_frames(5)
	check(fly.is_caught() and body.skeleton.get_bone_pose_rotation(wing).is_equal_approx(folded),
		"caught, it folds up and goes still")

## Space mid-pull: the line lets go, and the spider drops where it is.
func _dropping_mid_pull() -> void:
	print("Dropping mid-pull")
	var run := await arena()
	var weaver := run.weaver
	await put(run, Vector3(0.0, 0.3, 8.0))
	await pull(run)
	aim(run, Vector3(0.0, 4.0, -11.5))
	weaver.caster._cooling = 0.0
	weaver.caster.throw(0.0)
	var pull_web: ThrownWeb = weaver.webs()[weaver.webs().size() - 1]
	await wait_until(func() -> bool: return pull_web.is_stuck(), 60)
	await put(run, Vector3(0.0, 0.3, 2.0))
	aim(run, pull_web.global_position)
	weaver.fire_grapple()
	await run_frames(15)
	var at := weaver.global_position
	weaver.drive(Vector2.ZERO, true)
	await run_frames(2)
	check(weaver.mode == Weaver.Mode.AIR
		and Vector2(weaver.velocity.x, weaver.velocity.z).length() < 0.5
		and weaver.global_position.distance_to(at) < 0.3,
		"jump mid-pull: the line lets go, and the spider drops where it is (%s)"
		% where_is(weaver))


func where_is(weaver: Weaver) -> String:
	return "at %s, %s" % [weaver.global_position.snappedf(0.1), Weaver.Mode.keys()[weaver.mode]]


func pull(run: LevelRun) -> void:
	while run.weaver.pullback.next_web() != null:
		run.weaver.pullback._cooling = 0.0
		run.weaver.pullback.cast()
		await run_frames(60)


func _pullback() -> void:
	print("Pullback")
	var run := await arena()
	var weaver := run.weaver
	await put(run, Vector3(-4.0, 0.3, 6.0))
	aim(run, Vector3(0.0, 2.5, -11.5))
	weaver.caster.throw(0.0)
	var web := first_web(run)
	await wait_until(func() -> bool: return web.is_stuck(), 60)
	await put(run, Vector3(4.0, 0.3, 6.0))
	check(weaver.pullback.callable_webs().size() == 1, "the web is in the Pullback's reach")
	check(weaver.pullback.cast(), "the Pullback calls it home")
	check(web.state == ThrownWeb.State.RETURNING, "it comes off the wall")
	check(weaver.webs_left() == 3, "and its silk counts as back straight away")
	var ref: WeakRef = weakref(web)
	await wait_until(func() -> bool: return ref.get_ref() == null, 90)
	check(ref.get_ref() == null, "it reaches the spider and is gone")

	# Standing on one web, the others come home and that one stays: two webs climb.
	weaver.pullback._cooling = 0.0
	await put(run, Vector3(0.0, 0.3, -6.0))
	aim(run, Vector3(-3.0, 1.0, -11.5))
	weaver.caster.throw(1.0)
	var low := first_web(run)
	weaver.caster._cooling = 0.0
	aim(run, Vector3(3.0, 1.0, -11.5))
	weaver.caster.throw(1.0)
	var other: ThrownWeb = weaver.webs()[1]
	await wait_until(func() -> bool: return low.is_stuck() and other.is_stuck(), 60)
	weaver.attach_to_web(low)
	await run_frames(3)
	check(weaver.mode == Weaver.Mode.WEB, "on a web")
	check(weaver.pullback.callable_webs() == [other], "the Pullback leaves the web underfoot alone")
	weaver.pullback.cast()
	await run_frames(2)
	check(weaver.standing_web() == low and low.is_stuck(), "and the spider stays on it")
	check(other.state == ThrownWeb.State.RETURNING, "while the other comes home")
	check(weaver.webs_left() == 2, "and its silk is back")

	# First thrown, first home: one press, the oldest web; the next press, the next.
	await put(run, Vector3(0.0, 0.3, -4.0))
	await run_frames(40)
	weaver.caster._cooling = 0.0
	aim(run, Vector3(0.0, 4.0, -11.5))
	weaver.caster.throw(0.0)
	var newer: ThrownWeb = weaver.webs()[weaver.webs().size() - 1]
	await wait_until(func() -> bool: return newer.is_stuck(), 60)
	check(weaver.pullback.next_web() == low, "with two out, the next to come home is the oldest")
	weaver.pullback._cooling = 0.0
	weaver.pullback.cast()
	await run_frames(2)
	check(low.state == ThrownWeb.State.RETURNING and newer.is_stuck(),
		"one press calls the oldest and leaves the newer where it is")
	await run_frames(20)
	weaver.pullback.cast()
	await run_frames(2)
	check(newer.state == ThrownWeb.State.RETURNING, "and the next press calls the newer")


## Throwing a web in the air holds the spider up for a moment, once until it lands
## — or throw, call home, throw would be a way to hover.
func _throwing_in_the_air() -> void:
	print("Throwing in the air")
	var run := await arena()
	var weaver := run.weaver
	await put(run, Vector3(0.0, 8.0, 10.0))
	weaver.velocity = Vector3(0.0, 0.0, -6.0)
	aim(run, Vector3(0.0, 10.0, 40.0))
	weaver.caster.throw(0.0)
	await run_frames(1)
	check(weaver.is_stalled() and weaver.velocity.length() < 2.0,
		"a throw in the air holds the spider up, its speed mostly gone")
	var height := weaver.global_position.y
	await run_frames(15)
	check(weaver.global_position.y > height - 0.2, "for a moment (%.2f to %.2f)"
		% [height, weaver.global_position.y])
	await wait_until(func() -> bool: return not weaver.is_stalled(), 60)
	weaver.caster._cooling = 0.0
	aim(run, Vector3(6.0, 10.0, 40.0))
	weaver.caster.throw(0.0)
	await run_frames(1)
	check(not weaver.is_stalled(), "but only once until it lands")
	await wait_until(func() -> bool: return weaver.mode == Weaver.Mode.GROUND, 200)
	await pull(run)
	weaver.velocity = Vector3.ZERO
	await put(run, Vector3(0.0, 8.0, 10.0))
	aim(run, Vector3(0.0, 10.0, 40.0))
	weaver.caster._cooling = 0.0
	weaver.caster.throw(0.0)
	await run_frames(1)
	check(weaver.is_stalled(), "landing gives it back")


## A web called home that reaches the spider in the air just arrives: nothing
## holds the spider up, and it keeps falling. What it carried still comes.
func _caught_by_your_web() -> void:
	print("A web home in the air")
	var objects: Array = [{"type": "crate", "pos": [4.0, 0.6, -6.0]}]
	var run := await arena(objects)
	var weaver := run.weaver
	var crate := get_root().get_tree().get_nodes_in_group(Crate.GROUP)[0] as Crate
	await put(run, Vector3(-4.0, 0.3, 4.0))
	aim(run, crate.global_position)
	weaver.caster.throw(0.0)
	var on_crate := first_web(run)
	await wait_until(func() -> bool: return on_crate.is_stuck(), 60)
	check(on_crate.carried == crate, "a web on a crate")
	await put(run, Vector3(-2.0, 6.0, 4.0))
	var falling_from := weaver.global_position.y
	weaver.pullback._cooling = 0.0
	weaver.pullback.cast()
	var ref: WeakRef = weakref(on_crate)
	await wait_until(func() -> bool: return ref.get_ref() == null, 60)
	check(ref.get_ref() == null, "called home in the air, it reaches the spider")
	check(not weaver.is_stalled(), "and holds nothing up")
	await run_frames(6)
	check(weaver.global_position.y < falling_from - 1.0 or weaver.mode == Weaver.Mode.GROUND,
		"the spider just keeps falling (%.2f from %.2f)" % [weaver.global_position.y, falling_from])
	await run_frames(60)
	check(crate.global_position.distance_to(weaver.global_position) < 4.0 and not crate.freeze,
		"and the crate it brought is put down beside it")


func _crates_plates_doors() -> void:
	print("Crates, plates and doors")
	var objects: Array = [
		{"type": "crate", "pos": [-4.0, 0.6, -4.0]},
		{"type": "plate", "pos": [6.0, 0.0, 6.0], "channel": "gate"},
		{"type": "door", "pos": [8.0, 0.0, -6.0], "size": [4.0, 4.0, 0.5], "open": [0.0, 4.2, 0.0],
			"channel": "gate"},
	]
	var run := await arena(objects)
	var weaver := run.weaver
	await run_frames(30)
	var crate := get_root().get_tree().get_nodes_in_group(Crate.GROUP)[0] as Crate
	var door: SlideDoor = null
	for node in get_root().get_tree().get_nodes_in_group(LevelBuilder.GROUP):
		if node is SlideDoor:
			door = node
	var shut := door.position
	await put(run, Vector3(0.0, 0.3, 0.0))
	aim(run, crate.global_position)
	weaver.caster.throw(0.0)
	var web := first_web(run)
	await wait_until(func() -> bool: return web.is_stuck(), 60)
	check(web.carried == crate, "a web thrown at a crate sticks to it")
	# On the plate, facing away from the wall.
	await put(run, Vector3(6.0, 0.4, 7.0))
	weaver.global_basis = Basis.IDENTITY
	weaver.pullback.cast()
	var ref: WeakRef = weakref(web)
	await wait_until(func() -> bool: return ref.get_ref() == null, 90)
	check(crate.global_position.distance_to(weaver.global_position) < 2.0,
		"the Pullback brings the crate to the spider's feet")
	await run_frames(40)
	check(run.is_powered("gate"), "dropped on the plate, the crate presses it")
	await run_frames(60)
	check(door.position.y > shut.y + 3.5, "and the door on its channel slides open")


## The Pullback moves the level: a loose board holds silk but not the spider, and a
## web on it called home rips it away; a web on a block on a rail called home sends
## the block to the other end of its rail.
func _boards_and_blocks() -> void:
	print("Loose boards and blocks on rails")
	var objects: Array = [
		{"type": "panel", "piece": "cube", "pos": [0.0, 0.0, -11.2], "size": [4.0, 4.0, 0.3]},
		{"type": "slider", "piece": "cube", "pos": [6.0, 0.0, -4.0], "size": [2.0, 1.0, 2.0],
			"surface": "stone", "travel": [0.0, 0.0, 8.0], "speed": 6.0},
	]
	var run := await arena(objects)
	var weaver := run.weaver
	var board := get_root().get_tree().get_nodes_in_group(LoosePanel.GROUP)[0] as LoosePanel
	await put(run, Vector3(0.0, 0.3, -4.0))
	aim(run, Vector3(0.0, 2.0, -11.0))
	weaver.caster.throw(0.0)
	var web := first_web(run)
	await wait_until(func() -> bool: return not web.is_flying(), 60)
	check(web.is_stuck() and web.loose, "silk sticks to a loose board")
	aim(run, web.global_position)
	check(weaver.grapple.aimed().get("web") == null and not weaver.fire_grapple(),
		"but the grapple won't take a web on it: it won't hold the spider")
	weaver.pullback.cast()
	await run_frames(3)
	check(board.is_gone() and board.collision_layer == 0,
		"called home, the web rips the board away")
	await run_frames(80)
	check(not is_instance_valid(board), "and it's gone")
	await pull(run)
	weaver.caster._cooling = 0.0
	aim(run, Vector3(0.0, 2.0, -11.5))
	weaver.caster.throw(0.0)
	var behind: ThrownWeb = weaver.webs()[weaver.webs().size() - 1]
	await wait_until(func() -> bool: return not behind.is_flying(), 60)
	aim(run, behind.global_position)
	check(behind.holds_weight() and weaver.grapple.aimed().get("web") == behind,
		"leaving the stone behind it, where a web holds")
	await pull(run)

	var block: SlideBlock = null
	for node in get_root().get_tree().get_nodes_in_group(LevelBuilder.GROUP):
		if node is SlideBlock:
			block = node
	await put(run, Vector3(10.0, 0.3, 2.0))
	aim(run, block.global_position + Vector3(1.0, 0.5, 0.0))
	weaver.caster._cooling = 0.0
	weaver.caster.throw(0.0)
	var on_block: ThrownWeb = weaver.webs()[weaver.webs().size() - 1]
	await wait_until(func() -> bool: return not on_block.is_flying(), 60)
	check(on_block.is_stuck() and on_block.get_parent() == block, "a web on a block on a rail")
	weaver.pullback._cooling = 0.0
	weaver.pullback.cast()
	await run_frames(120)
	check(absf(block.global_position.z - 4.0) < 0.05,
		"called home, it slides to the other end of its rail (z %.1f)" % block.global_position.z)
	var arrow := block.get_children().filter(func(n: Node) -> bool:
		return n.has_meta("face"))[0] as Node3D
	check(block.heading() == -1.0 and arrow.global_basis.x.z < -0.5,
		"and its arrows turn round, to point back the way it came")
	aim(run, block.global_position + Vector3(1.0, 0.5, 0.0))
	weaver.caster._cooling = 0.0
	weaver.caster.throw(0.0)
	on_block = weaver.webs()[weaver.webs().size() - 1]
	await wait_until(func() -> bool: return not on_block.is_flying(), 60)
	weaver.pullback._cooling = 0.0
	weaver.pullback.cast()
	await run_frames(120)
	check(absf(block.global_position.z + 4.0) < 0.05,
		"and called again, back to the first (z %.1f)" % block.global_position.z)
	var arrows := block.get_children().filter(func(n: Node) -> bool: return n.has_meta("face"))
	check(arrows.size() >= 2 and block.heading() == 1.0,
		"arrows on its sides point the way it will go next: along its rail (%d)" % arrows.size())

	# Up and down: a rail can stand on end, and the block doesn't fall.
	objects = [{"type": "slider", "piece": "cube", "pos": [-3.0, 0.0, 0.0], "size": [2.0, 1.0, 2.0],
		"surface": "stone", "travel": [0.0, 3.0, 0.0], "speed": 6.0}]
	run = await arena(objects)
	weaver = run.weaver
	var lift: SlideBlock = null
	for node in get_root().get_tree().get_nodes_in_group(LevelBuilder.GROUP):
		if node is SlideBlock:
			lift = node
	await put(run, Vector3(2.0, 0.3, 0.0))
	aim(run, lift.global_position + Vector3(1.0, 0.5, 0.0))
	weaver.caster.throw(0.0)
	var on_lift := first_web(run)
	await wait_until(func() -> bool: return not on_lift.is_flying(), 60)
	check(on_lift.is_stuck() and on_lift.get_parent() == lift, "a web on a block on an upright rail")
	weaver.pullback.cast()
	await run_frames(90)
	check(absf(lift.global_position.y - 3.0) < 0.05,
		"called home, it rises to the top of its rail (base %.2f)" % lift.global_position.y)
	await run_frames(30)
	check(absf(lift.global_position.y - 3.0) < 0.05, "and stays up: it doesn't fall")
	aim(run, lift.global_position + Vector3(1.0, 0.5, 0.0))
	weaver.caster._cooling = 0.0
	weaver.caster.throw(0.0)
	on_lift = weaver.webs()[weaver.webs().size() - 1]
	await wait_until(func() -> bool: return not on_lift.is_flying(), 60)
	weaver.pullback._cooling = 0.0
	weaver.pullback.cast()
	await run_frames(90)
	check(lift.global_position.y < 0.05, "and called again, it comes back down (base %.2f)"
		% lift.global_position.y)


func _platforms() -> void:
	print("Moving platforms")
	var objects: Array = [{"type": "platform", "piece": "cube", "pos": [0.0, 0.0, -6.0],
		"size": [4.0, 4.0, 1.0], "path": [[0.0, 0.0, -6.0], [8.0, 0.0, -6.0]], "speed": 4.0,
		"wait": 0.0}]
	var run := await arena(objects)
	var weaver := run.weaver
	await put(run, Vector3(-1.0, 0.3, 2.0))
	aim(run, Vector3(2.5, 2.0, -5.5))
	weaver.caster.throw(0.0)
	var web := first_web(run)
	await wait_until(func() -> bool: return web.is_stuck(), 40)
	if not check(web.get_parent() is MovingPlatform, "a web on a moving platform sticks to it"):
		note("stuck %s on %s at %s" % [web.is_stuck(), web.get_parent(), web.global_position])
	var x := web.global_position.x
	await run_frames(30)
	check(absf(web.global_position.x - x) > 1.0, "and goes where it goes")


## Every level has a lid: silk thrown at the sky meets slick, and slides off it.
func _the_ceiling() -> void:
	print("The ceiling")
	var run := await arena()
	var weaver := run.weaver
	var lid: StaticBody3D = null
	for node in LevelBuilder._all_under(run):
		if node is StaticBody3D and (node as Node).name == "Ceiling":
			lid = node
	if not check(lid != null, "the arena has a ceiling"):
		return
	check(lid.is_in_group(Surfaces.SLICK_GROUP) and lid.global_position.y > 8.0,
		"slick, over the top of everything (y %.1f)" % lid.global_position.y)
	await put(run, Vector3(0.0, 0.3, 20.0))
	aim(run, Vector3(0.0, 30.0, 22.0))
	weaver.caster.throw(0.5)
	var web := first_web(run)
	await run_frames(4)
	aim(run, web.global_position)
	weaver.fire_grapple()
	await wait_until(func() -> bool: return weaver.mode != Weaver.Mode.GRAPPLE, 90)
	var highest := weaver.global_position.y
	for i in 90:
		await physics_frame
		highest = maxf(highest, weaver.global_position.y)
	check(weaver.mode != Weaver.Mode.GRAPPLE, "launched off a web thrown straight up")
	check(highest < lid.global_position.y,
		"the ceiling stops the spider going over everything (highest y %.1f)" % highest)
	check(not is_instance_valid(web) or not web.is_standing(), "and the web slid off it")
	await wait_until(func() -> bool: return weaver.mode == Weaver.Mode.GROUND, 200)
	check(weaver.mode == Weaver.Mode.GROUND, "back down on the floor")


## A web is walked on one face: its rim holds the spider, and never takes it round.
func _one_face() -> void:
	print("One face")
	var objects: Array = [{"type": "piece", "piece": "cube", "pos": [6.0, 0.0, 6.0],
		"size": [1.0, 2.0, 1.0]}]
	var run := await arena(objects)
	var weaver := run.weaver
	await put(run, Vector3(6.0, 0.3, 10.0))
	# Dropped straight down onto the post from over it.
	var web := ThrownWeb.throw(weaver.web_container(), weaver, Vector3(6.0, 5.0, 6.0),
		Vector3.DOWN, SilkCaster.SPEED, SilkCaster.BIGGEST, SilkCaster.REACH)
	weaver.adopt_web(web)
	await wait_until(func() -> bool: return web.is_stuck(), 60)
	check(web.normal().y > 0.95, "a big web flat on top of a narrow post, overhanging it")
	weaver.attach_to_web(web, web.global_position + Vector3.UP * 0.3)
	await run_frames(3)
	check(weaver.standing_web() == web and weaver.global_basis.y.y > 0.5, "standing on top")
	weaver.view.yaw = 0.0
	weaver.view.pitch = -0.3
	weaver.drive(Vector2(0.0, 1.0))
	await run_frames(90)
	var top := web.to_local(weaver.global_position)
	if not check(weaver.standing_web() == web and top.z > 0.0 and weaver.global_basis.y.y > 0.5,
			"walking at its rim, the spider stays on top: a web has one face"):
		note("%s on %s, local %s" % [where_is(weaver), weaver.standing_web(), top])
	check(Vector2(top.x, top.y).length() < web.current_radius(), "and the rim holds it")
	weaver.drive(Vector2.ZERO)

	# A web flat on a wall: walked on the room's side.
	await put(run, Vector3(0.0, 0.3, -6.0))
	aim(run, Vector3(0.0, 3.0, -11.5))
	weaver.caster._cooling = 0.0
	weaver.caster.throw(0.0)
	var wall := weaver.webs()[weaver.webs().size() - 1]
	await wait_until(func() -> bool: return wall.is_stuck(), 60)
	weaver.attach_to_web(wall)
	weaver.view.yaw = PI * 0.5
	weaver.view.pitch = 0.0
	weaver.drive(Vector2(0.0, 1.0))
	await run_frames(60)
	check(weaver.standing_web() == wall and wall.to_local(weaver.global_position).z > 0.0,
		"on a web flat on a wall, the rim holds the spider on the room's side")
	weaver.drive(Vector2.ZERO)


func _the_exit() -> void:
	print("The exit")
	var objects: Array = [{"type": "exit", "pos": [6.0, 0.0, 0.0]}]
	var run := await arena(objects)
	var finished := [false]
	var restarted := [false]
	run.finished.connect(func(_t: float, _b: float) -> void: finished[0] = true)
	check(run.exit.open, "the exit is open from the start")
	await put(run, Vector3(0.0, 0.3, 2.0))
	run.weaver.drive(Vector2(0.0, 1.0))
	await run_frames(10)
	run.weaver.drive(Vector2.ZERO)
	await put(run, Vector3(6.0, 0.4, 0.0))
	await wait_until(func() -> bool: return finished[0], 30)
	check(finished[0], "and walking in finishes the level")
	check(run.time > 0.0, "against the clock (%.2fs)" % run.time)

	run = await arena()
	restarted = [false]
	run.restart_requested.connect(func() -> void: restarted[0] = true)
	await put(run, Vector3(40.5, 0.3, 0.0))
	run.weaver.drive(Vector2(1.0, 0.0))
	await wait_until(func() -> bool: return restarted[0], 200)
	check(restarted[0], "falling out of the level starts it again")
