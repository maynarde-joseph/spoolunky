extends TestSuite

## The three verbs and everything they touch, each in a fresh arena:
##
##     godot --headless --path . --script res://tests/flies/mechanics_smoke_test.gd
##
## Walking and jumping; walls that cannot be climbed; silk wound up and thrown,
## sticking flat, sliding off slick metal and coming apart at the end of its
## reach; walking onto a web and up a wall on it; the grapple, spent in the air
## and back on landing, and holding to a wall; riding a thrown web; flies taken
## by a throw and by a web called home, banking jumps; flies as grapple anchors and
## Shift locking on to them; the ceiling; a crate brought home and onto a plate
## that opens a door; a platform carrying a web; and the exit and the bag.

const FLOOR_TOP := 0.0


func run_checks() -> void:
	await _running_and_walls()
	await _throwing_silk()
	await _slick_and_reach()
	await _walking_on_webs()
	await _grappling()
	await _riding_a_web()
	await _rides_go_nowhere_for_free()
	await _catching_flies()
	await _fly_jumps()
	await _the_ceiling()
	await _round_the_rim()
	await _pullback()
	await _caught_by_your_web()
	await _crates_plates_doors()
	await _platforms()
	await _the_exit()


# --- the arena -----------------------------------------------------------------

## A floor, a stone wall to the north, a slick one to the east, a ledge to the
## west, and whatever [param extra] adds.
func arena(extra: Array = [], webs := 3, needed := 0) -> LevelRun:
	var objects: Array = [
		{"type": "piece", "piece": "cube", "pos": [0.0, -1.0, 0.0], "size": [80.0, 1.0, 80.0]},
		{"type": "piece", "piece": "cube", "pos": [0.0, 0.0, -12.0], "size": [14.0, 8.0, 1.0]},
		{"type": "piece", "piece": "cube", "pos": [14.0, 0.0, 0.0], "rot": [0.0, 90.0, 0.0],
			"size": [14.0, 8.0, 1.0], "surface": "slick"},
		{"type": "piece", "piece": "cube", "pos": [-12.0, 0.0, 0.0], "size": [6.0, 4.0, 6.0]},
		{"type": "start", "pos": [0.0, 0.2, 4.0]},
	]
	objects.append_array(extra)
	var level := {"name": "Arena", "webs": webs, "flies_needed": needed, "kill_y": -20.0,
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

	await put(run, Vector3(0.0, 0.3, 10.0))
	await pull(run)
	aim(run, Vector3(0.0, 2.0, -11.5))
	weaver.caster.throw(0.0)
	web = first_web(run)
	await wait_until(func() -> bool: return web.is_stuck(), 60)
	aim(run, web.global_position)
	check(not weaver.grapple.aimed().is_empty(), "a web twenty metres off is in reach")
	await put(run, Vector3(0.0, 0.3, 22.0))
	aim(run, web.global_position)
	check(weaver.grapple.aimed().is_empty(), "one thirty off is not")


func _riding_a_web() -> void:
	print("Riding a web")
	var run := await arena()
	var weaver := run.weaver
	await put(run, Vector3(0.0, 0.3, 20.0))
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
	check(weaver.grapple_ready, "and landing on it gives the grapple back")
	var before := weaver.global_position
	await run_frames(5)
	check(weaver.global_position.z < before.z - 1.0, "the web carries the spider along")
	await wait_until(func() -> bool: return web.is_stuck(), 120)
	check(web.is_stuck() and weaver.standing_web() == web,
		"and when the web sticks, the spider is standing on it on the wall")
	check(weaver.global_position.z > -11.5, "on the room's side of it")


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

	# Jumping off a web in flight is a hop, not a sling.
	await wait_until(func() -> bool: return weaver.mode == Weaver.Mode.GROUND, 120)
	await put(run, Vector3(0.0, 0.3, 20.0))
	aim(run, Vector3(0.0, 2.5, -11.5))
	weaver.caster._cooling = 0.0
	weaver.caster.throw(0.5)
	web = weaver.webs()[weaver.webs().size() - 1]
	await run_frames(6)
	aim(run, web.global_position)
	weaver.fire_grapple()
	await wait_until(func() -> bool: return weaver.mode == Weaver.Mode.WEB, 60)
	weaver.drive(Vector2.ZERO, true)
	await run_frames(2)
	check(weaver.mode == Weaver.Mode.AIR and weaver.velocity.length() < 7.0,
		"jumping off a flying web keeps none of its speed (%.1f m/s)" % weaver.velocity.length())

	# A web in flight gives the grapple back once, until the spider next lands.
	await wait_until(func() -> bool: return weaver.mode == Weaver.Mode.GROUND, 120)
	await put(run, Vector3(0.0, 0.3, 20.0))
	await pull(run)
	# Both thrown from the ground, a beat apart. Grapple onto the later one, which
	# is nearer; then, the grapple spent, land on the earlier one still in flight.
	aim(run, Vector3(6.0, 2.5, -11.5))
	weaver.caster._cooling = 0.0
	weaver.caster.throw(0.0)
	var second := weaver.webs()[0]
	await run_frames(10)
	aim(run, Vector3(-6.0, 2.5, -11.5))
	weaver.caster._cooling = 0.0
	weaver.caster.throw(0.0)
	var first := weaver.webs()[1]
	await run_frames(4)
	aim(run, first.global_position)
	weaver.fire_grapple()
	await wait_until(func() -> bool: return weaver.standing_web() == first, 60)
	if not check(weaver.standing_web() == first and weaver.grapple_ready,
			"the first web in flight gives the grapple back"):
		note("on %s (first %s, second %s), ready %s, mode %s, refund spent %s" % [
			weaver.standing_web(), first, second, weaver.grapple_ready,
			Weaver.Mode.keys()[weaver.mode], weaver._air_refund_spent])
	# Spend it, then land on the second while it is still flying.
	weaver.grapple_ready = false
	check(second.is_flying(), "the second web still in the air")
	weaver.attach_to_web(second)
	check(weaver.standing_web() == second and not weaver.grapple_ready,
		"a second one, before landing, does not")
	await wait_until(func() -> bool: return second.is_stuck(), 120)
	await run_frames(2)
	if not check(weaver.grapple_ready, "and it comes back when the ridden web lands"):
		note("web %s stuck %s, on %s, mode %s" % [second.global_position, second.is_stuck(),
			weaver.standing_web(), Weaver.Mode.keys()[weaver.mode]])


func where_is(weaver: Weaver) -> String:
	return "at %s, %s" % [weaver.global_position.snappedf(0.1), Weaver.Mode.keys()[weaver.mode]]


func pull(run: LevelRun) -> void:
	while run.weaver.pullback.next_web() != null:
		run.weaver.pullback._cooling = 0.0
		run.weaver.pullback.cast()
		await run_frames(60)


func _catching_flies() -> void:
	print("Catching flies")
	var objects: Array = [
		{"type": "fly", "pos": [0.0, 1.5, -6.0]},
		{"type": "fly", "pos": [8.0, 1.0, 6.0], "path": [[8.0, 1.0, 6.0], [8.0, 1.0, 0.0]],
			"speed": 3.0},
	]
	var run := await arena(objects)
	var weaver := run.weaver
	var flies := get_root().get_tree().get_nodes_in_group(Fly.GROUP)
	check(flies.size() == 2 and run.flies_total == 2, "the arena has two flies")
	var still: Fly = null
	var moving: Fly = null
	for node in flies:
		var fly := node as Fly
		if fly.path.size() >= 2:
			moving = fly
		else:
			still = fly
	var start_z := moving.global_position.z
	await run_frames(20)
	check(absf(moving.global_position.z - start_z) > 0.5, "a fly with a path flies it")
	await put(run, Vector3(0.0, 0.3, 4.0))
	aim(run, still.global_position)
	check(weaver.caster.picked_fly() == still, "with the cross on a fly, the throw is aimed at it")
	weaver.caster.throw(0.0)
	await wait_until(func() -> bool: return not still.is_free(), 40)
	check(still.state == Fly.State.CAUGHT, "a thrown web takes the fly")
	check(weaver.fly_line.count() == 1 and run.caught() == 1, "and it goes on the line")
	await run_frames(60)
	check(still.global_position.distance_to(weaver.global_position) < FlyLine.LINK * 1.6,
		"trailing behind the spider")
	weaver.caster._cooling = 0.0
	aim(run, moving.global_position)
	weaver.caster.throw(1.0)
	await wait_until(func() -> bool: return not moving.is_free(), 60)
	check(not moving.is_free(), "a flying fly is led, and taken")
	check(weaver.fly_line.count() == 2, "and goes on the line behind the first")


func _pullback() -> void:
	print("Pullback")
	var objects: Array = [{"type": "fly", "pos": [0.0, 2.0, -2.0]}]
	var run := await arena(objects)
	var weaver := run.weaver
	var fly := get_root().get_tree().get_nodes_in_group(Fly.GROUP)[0] as Fly
	await put(run, Vector3(-4.0, 0.3, 6.0))
	aim(run, Vector3(0.0, 2.5, -11.5))
	# Thrown past the fly, wide of it.
	weaver.caster.throw(0.0)
	var web := first_web(run)
	await wait_until(func() -> bool: return web.is_stuck(), 60)
	check(fly.is_free(), "a web that stuck past the fly did not take it")
	await run_frames(30)
	check(fly.is_free(), "and a web on a wall does not catch a fly near it")
	# Stand where the way home runs through the fly.
	var home := web.global_position + (fly.global_position - web.global_position) * 3.0
	home.y = 0.3
	await put(run, home)
	check(weaver.pullback.callable_webs().size() == 1, "the web is in the Pullback's reach")
	check(weaver.pullback.cast(), "the Pullback calls it home")
	check(web.state == ThrownWeb.State.RETURNING, "it comes off the wall")
	check(weaver.webs_left() == 3, "and its silk counts as back straight away")
	var ref: WeakRef = weakref(web)
	await wait_until(func() -> bool: return ref.get_ref() == null, 90)
	check(ref.get_ref() == null, "it reaches the spider and is gone")
	check(not fly.is_free(), "wrapping the fly it passed on the way")

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


## A web called home that reaches the spider in the air catches it: a moment held
## up, its speed mostly gone. On the way it has still done its work.
func _caught_by_your_web() -> void:
	print("Caught by your own web")
	var objects: Array = [
		{"type": "fly", "pos": [0.0, 5.0, -4.0]},
		{"type": "crate", "pos": [4.0, 0.6, -6.0]},
	]
	var run := await arena(objects)
	var weaver := run.weaver
	var fly := get_root().get_tree().get_nodes_in_group(Fly.GROUP)[0] as Fly
	var crate := get_root().get_tree().get_nodes_in_group(Crate.GROUP)[0] as Crate
	await put(run, Vector3(-4.0, 0.3, 4.0))
	aim(run, Vector3(-4.0, 3.0, -11.5))
	weaver.caster.throw(0.0)
	var web := first_web(run)
	await wait_until(func() -> bool: return web.is_stuck(), 60)
	await put(run, Vector3(-4.0, 0.3, 4.0))
	aim(run, crate.global_position)
	weaver.caster._cooling = 0.0
	weaver.caster.throw(0.0)
	var on_crate: ThrownWeb = weaver.webs()[1]
	await wait_until(func() -> bool: return on_crate.is_stuck(), 60)
	check(on_crate.carried == crate, "one web on the wall, one on a crate")
	# Up in the air, on the line home from the wall web through the fly.
	var home := web.global_position + (fly.global_position - web.global_position) * 2.2
	await put(run, home)
	weaver.velocity = Vector3(6.0, 0.0, 0.0)
	weaver.pullback.cast()
	check(not weaver.is_stalled(), "calling it in the air: not held up yet")
	await wait_until(func() -> bool: return weaver.is_stalled(), 60)
	if not check(weaver.is_stalled(), "when it reaches the spider in the air, it catches it"):
		note("%s, fly free %s" % [where_is(weaver), fly.is_free()])
	var height := weaver.global_position.y
	await run_frames(8)
	check(weaver.global_position.y > height - 0.15, "held up, not falling (%.2f to %.2f)"
		% [height, weaver.global_position.y])
	check(weaver.velocity.length() < 1.0, "with the speed it had mostly gone (%.1f m/s)"
		% weaver.velocity.length())
	check(not fly.is_free(), "and it still took the fly it passed on the way")
	await wait_until(func() -> bool: return not weaver.is_stalled(), 60)
	var held_at := weaver.global_position.y
	await run_frames(10)
	check(weaver.global_position.y < held_at - 0.2 or weaver.mode == Weaver.Mode.GROUND,
		"then the spider falls again (%.2f to %.2f, %s)" % [held_at, weaver.global_position.y,
		Weaver.Mode.keys()[weaver.mode]])
	# The crate web, called in the air: the crate still comes, and is put down.
	await wait_until(func() -> bool: return weaver.mode == Weaver.Mode.GROUND, 120)
	await put(run, Vector3(-2.0, 3.0, 4.0))
	weaver.pullback._cooling = 0.0
	weaver.pullback.cast()
	await wait_until(func() -> bool: return weaver.is_stalled(), 60)
	check(weaver.is_stalled(), "a web bringing a crate catches the spider too")
	await run_frames(60)
	check(crate.global_position.distance_to(weaver.global_position) < 3.0 and not crate.freeze,
		"and the crate it brought is put down beside it")
	# On the ground, a web coming home is just home.
	await wait_until(func() -> bool: return weaver.mode == Weaver.Mode.GROUND, 120)
	aim(run, Vector3(0.0, 3.0, -11.5))
	weaver.caster._cooling = 0.0
	weaver.caster.throw(0.0)
	var last := weaver.webs()[weaver.webs().size() - 1]
	await wait_until(func() -> bool: return last.is_stuck(), 60)
	weaver.pullback._cooling = 0.0
	weaver.pullback.cast()
	var ref: WeakRef = weakref(last)
	await wait_until(func() -> bool: return ref.get_ref() == null, 90)
	check(not weaver.is_stalled() and weaver.mode == Weaver.Mode.GROUND,
		"on the ground, a web coming home holds nothing up")


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


## A fly taken with silk is a jump banked for the air; a fly grappled to is an
## anchor, hopped off; Shift locks both on to the fly nearest the cross.
func _fly_jumps() -> void:
	print("Flies are jumps and anchors")
	var objects: Array = [{"type": "fly", "pos": [0.0, 1.0, -3.0]},
		{"type": "fly", "pos": [3.0, 1.0, -3.0]}]
	var run := await arena(objects)
	var weaver := run.weaver
	var flies := get_root().get_tree().get_nodes_in_group(Fly.GROUP)
	await put(run, Vector3(0.0, 0.3, 6.0))
	for node in flies:
		var fly := node as Fly
		aim(run, fly.global_position)
		weaver.caster._cooling = 0.0
		weaver.caster.throw(0.0)
		await wait_until(func() -> bool: return not fly.is_free(), 40)
	check(run.caught() == 2 and weaver.air_jumps == 2,
		"each fly taken with silk banks a jump, and they keep (%d)" % weaver.air_jumps)
	weaver.drive(Vector2.ZERO, true)
	await run_frames(2)
	check(weaver.mode == Weaver.Mode.AIR and weaver.air_jumps == 2,
		"a jump from the ground spends none")
	await wait_until(func() -> bool: return weaver.velocity.y < -1.0, 60)
	weaver.drive(Vector2.ZERO, true)
	await run_frames(2)
	check(weaver.velocity.y > Weaver.JUMP * 0.8 and weaver.air_jumps == 1,
		"falling, jump spends a banked one (%.1f m/s up, %d left)"
		% [weaver.velocity.y, weaver.air_jumps])
	await wait_until(func() -> bool: return weaver.mode == Weaver.Mode.GROUND, 120)
	check(weaver.air_jumps == 1, "and the one left is still banked on landing")

	# Grappled to, a fly is an anchor: caught at the end of the pull, hopped off,
	# the grapple back.
	objects = [{"type": "fly", "pos": [0.0, 4.0, -4.0]}]
	run = await arena(objects)
	weaver = run.weaver
	var anchor := get_root().get_tree().get_nodes_in_group(Fly.GROUP)[0] as Fly
	await put(run, Vector3(0.0, 0.3, 6.0))
	aim(run, anchor.global_position + Vector3(0.3, 0.2, 0.0))
	check(weaver.grapple.aimed().get("fly") == anchor,
		"the grapple takes a fly with the cross a little off it")
	check(weaver.fire_grapple(), "and the line goes onto it")
	await wait_until(func() -> bool: return weaver.mode != Weaver.Mode.GRAPPLE, 90)
	if not check(not anchor.is_free() and run.caught() == 1 and weaver.air_jumps == 0,
			"pulled to it, the fly is caught — an anchor, not a banked jump"):
		note("fly %s, caught %d, jumps %d, %s" % [Fly.State.keys()[anchor.state], run.caught(),
			weaver.air_jumps, where_is(weaver)])
	if not check(weaver.mode == Weaver.Mode.AIR and weaver.velocity.y > 3.0 and weaver.grapple_ready,
			"and the spider hops off it with the grapple back (%.1f m/s up)" % weaver.velocity.y):
		note("ready %s, %s" % [weaver.grapple_ready, where_is(weaver)])

	# Shift: the fly nearest the cross, wherever the cross is.
	objects = [{"type": "fly", "pos": [-6.0, 2.0, -4.0]}, {"type": "fly", "pos": [6.0, 2.0, -4.0]}]
	run = await arena(objects)
	weaver = run.weaver
	var left: Fly = null
	var right: Fly = null
	for node in get_root().get_tree().get_nodes_in_group(Fly.GROUP):
		if (node as Fly).global_position.x < 0.0:
			left = node
		else:
			right = node
	await put(run, Vector3(0.0, 0.3, 6.0))
	aim(run, Vector3(2.0, 2.0, -4.0))
	check(weaver.grapple.aimed().get("fly") == null, "with the cross between flies, none is taken")
	weaver.locking = true
	await run_frames(2)
	weaver.locking = true
	check(weaver.lock_target == right, "Shift locks on to the fly nearest the cross")
	check(weaver.grapple.aimed().get("fly") == right and weaver.caster.picked_fly() == right,
		"and the grapple and the silk both go to it")
	aim(run, Vector3(-2.0, 2.0, -4.0))
	await run_frames(2)
	check(weaver.lock_target == right, "kept while it stays in sight")
	weaver.locking = false
	await run_frames(1)
	check(weaver.lock_target == null, "and let go with Shift")
	weaver.locking = true
	await run_frames(1)
	check(weaver.lock_target == left, "held again, it takes the one nearest the cross now")
	weaver.locking = false


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
	await wait_until(func() -> bool: return weaver.mode == Weaver.Mode.WEB, 60)
	check(weaver.standing_web() == web, "riding a web thrown straight up")
	await wait_until(func() -> bool: return weaver.mode != Weaver.Mode.WEB, 200)
	check(weaver.global_position.y < lid.global_position.y,
		"it comes apart under the ceiling and the spider drops (y %.1f)" % weaver.global_position.y)
	await wait_until(func() -> bool: return weaver.mode == Weaver.Mode.GROUND, 200)
	check(weaver.mode == Weaver.Mode.GROUND, "back down on the floor")


## Round the rim of a web onto its other face, where there is room for it.
func _round_the_rim() -> void:
	print("Round the rim")
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
	await wait_until(func() -> bool: return weaver.global_basis.y.y < -0.5, 120)
	if not check(weaver.standing_web() == web and weaver.global_basis.y.y < -0.5,
			"walking off its rim takes the spider round onto the underside"):
		note("%s on %s, local %s, radius %.2f" % [where_is(weaver), weaver.standing_web(),
			web.to_local(weaver.global_position), web.current_radius()])
	await run_frames(20)
	var under := web.to_local(weaver.global_position)
	if not check(under.z < 0.0 and weaver.standing_web() == web,
			"and holding on, it carries on along the underside"):
		note("%s on %s, local %s" % [where_is(weaver), weaver.standing_web(), under])
	weaver.drive(Vector2.ZERO)

	# A web flat on a wall has no other side to go round to.
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
	print("The exit and the bag")
	var objects: Array = [
		{"type": "exit", "pos": [6.0, 0.0, 0.0]},
		{"type": "fly", "pos": [0.0, 1.5, -6.0]},
	]
	var run := await arena(objects)
	check(run.exit.open and run.flies_needed == 0,
		"a level that asks for no flies has its bag open from the start")
	run = await arena(objects, 3, 1)
	var weaver := run.weaver
	var finished := [false]
	var restarted := [false]
	run.finished.connect(func(_t: float, _b: float) -> void: finished[0] = true)
	run.restart_requested.connect(func() -> void: restarted[0] = true)
	check(not run.exit.open, "one that asks for a fly keeps it shut until there is one")
	await put(run, Vector3(6.0, 0.4, 0.0))
	await run_frames(10)
	check(not finished[0], "and walking into it shut does nothing")
	await put(run, Vector3(0.0, 0.3, 2.0))
	var fly := get_root().get_tree().get_nodes_in_group(Fly.GROUP)[0] as Fly
	aim(run, fly.global_position)
	weaver.caster.throw(0.0)
	await wait_until(func() -> bool: return not fly.is_free(), 40)
	await run_frames(2)
	check(run.exit.open, "with the fly caught, it opens")
	await put(run, Vector3(6.0, 0.4, 0.0))
	await wait_until(func() -> bool: return finished[0], 30)
	check(finished[0], "and walking in finishes the level")
	await run_frames(60)
	check(fly.state == Fly.State.BAGGED and run.bagged == 1, "with the fly in the bag")
	check(run.time > 0.0, "against the clock (%.2fs)" % run.time)

	run = await arena()
	restarted = [false]
	run.restart_requested.connect(func() -> void: restarted[0] = true)
	await put(run, Vector3(40.5, 0.3, 0.0))
	run.weaver.drive(Vector2(1.0, 0.0))
	await wait_until(func() -> bool: return restarted[0], 200)
	check(restarted[0], "falling out of the level starts it again")
