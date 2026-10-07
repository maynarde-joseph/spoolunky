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
## door; a platform carrying a web; and the exit.

const FLOOR_TOP := 0.0


func run_checks() -> void:
	await _running_and_walls()
	await _throwing_silk()
	await _slick_and_reach()
	await _walking_on_webs()
	await _grappling()
	await _riding_a_web()
	await _rides_go_nowhere_for_free()
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
	await run_frames(2)
	check(weaver.mode == Weaver.Mode.AIR and weaver.velocity.length() < 7.0,
		"jumping off a flying web keeps none of its speed (%.1f m/s)" % weaver.velocity.length())

	# A web in flight gives the grapple back once, until the spider next lands.
	await wait_until(func() -> bool: return weaver.mode == Weaver.Mode.GROUND, 120)
	await put(run, Vector3(0.0, 0.3, 8.0))
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


## Throwing a web in the air holds the spider up for a moment, once until it lands;
## and a web coming home catches it only once until it lands, too — or throw, call
## home, throw, call home would be a way to hover.
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
	weaver.pullback._cooling = 0.0
	weaver.pullback.cast()
	await wait_until(func() -> bool: return weaver.is_stalled(), 40)
	check(weaver.is_stalled(), "a web called home still catches it, once")
	await wait_until(func() -> bool: return not weaver.is_stalled(), 90)
	weaver.pullback._cooling = 0.0
	weaver.pullback.cast()
	await run_frames(20)
	check(not weaver.is_stalled() and weaver.mode == Weaver.Mode.AIR,
		"and the next one home doesn't: no hovering on throws and calls")
	await wait_until(func() -> bool: return weaver.mode == Weaver.Mode.GROUND, 200)
	await pull(run)
	weaver.velocity = Vector3.ZERO
	await put(run, Vector3(0.0, 8.0, 10.0))
	aim(run, Vector3(0.0, 10.0, 40.0))
	weaver.caster._cooling = 0.0
	weaver.caster.throw(0.0)
	await run_frames(1)
	check(weaver.is_stalled(), "landing gives it back")


## A web called home that reaches the spider in the air catches it: a moment held
## up, its speed mostly gone. What it carried still comes.
func _caught_by_your_web() -> void:
	print("Caught by your own web")
	var objects: Array = [{"type": "crate", "pos": [4.0, 0.6, -6.0]}]
	var run := await arena(objects)
	var weaver := run.weaver
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
	# Up in the air, out from the wall web.
	var home := web.global_position + (Vector3(0.0, 5.0, -4.0) - web.global_position) * 2.2
	await put(run, home)
	weaver.velocity = Vector3(6.0, 0.0, 0.0)
	weaver.pullback.cast()
	check(not weaver.is_stalled(), "calling it in the air: not held up yet")
	await wait_until(func() -> bool: return weaver.is_stalled(), 60)
	if not check(weaver.is_stalled(), "when it reaches the spider in the air, it catches it"):
		note(where_is(weaver))
	var height := weaver.global_position.y
	await run_frames(8)
	check(weaver.global_position.y > height - 0.15, "held up, not falling (%.2f to %.2f)"
		% [height, weaver.global_position.y])
	check(weaver.velocity.length() < 1.0, "with the speed it had mostly gone (%.1f m/s)"
		% weaver.velocity.length())
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
