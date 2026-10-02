extends TestSuite

## Headless test for wall and ceiling climbing and the dragline.
##
##     godot --headless --script res://tests/climb_smoke_test.gd
##
## Builds a plain box room, drops a spider into it and walks it up a wall,
## across the ceiling, down on a thread and back to the floor, checking the
## body really does reorient onto each surface along the way.

const ROOM_HALF := Vector3(3.0, 1.6, 3.0)

var _room: Node3D
var _spider: SpiderPlayer


func run_checks() -> void:
	_room = _build_room()
	await stage(_room)

	_spider = load("res://game/player/spider.tscn").instantiate() as SpiderPlayer
	_room.add_child(_spider)
	_spider.global_position = Vector3(0, -ROOM_HALF.y + 0.6, 0)
	await physics_frame
	_spider.require_captured_mouse = false
	# Footsteps are not what this test is about, and a sound still being mixed
	# when the tree is torn down shows up as a leak at exit.
	var audio := _spider.get_node_or_null("Player Audios")
	if audio != null:
		audio.free()
	_spider.climb.notice.connect(func(text: String) -> void: note(text))

	await _test_floor()
	await _test_strafing()
	await _test_the_walk_fits_the_surface()
	await _test_walls_read_how_you_face_them()
	await _test_round_an_overhang()
	await _test_wall()
	await _test_ceiling()
	await _test_dragline()
	await _test_letting_go()
	await _test_leaping_off_a_wall()
	await _test_corners_do_not_bounce()
	await _test_climbing_with_the_camera_tipped_down()
	await _test_off_a_line_onto_a_wall()
	await _test_the_body_is_a_skeleton()
	await _test_three_looks_on_one_skeleton()
	await _test_eight_feet_on_whatever_is_underfoot()
	await _test_ziplining()
	await _test_grappling()
	await _test_grappling_without_a_mode()
	await _test_grappling_a_long_way()
	await _test_lines_are_roads()
	await _test_the_line_grapple()
	await _test_sloppy_normals()
	await _test_momentum_survives_a_grapple()
	await _test_a_steady_view()


func _test_floor() -> void:
	await run_frames(40)
	check(_spider.climb.is_attached(), "the spider settles onto the floor")
	check(_spider.climb.surface_normal.dot(Vector3.UP) > 0.95,
		"standing the right way up (normal %.2v)" % _spider.climb.surface_normal)
	check(not _spider.climb.on_steep_surface(), "the floor is not a steep surface")
	check(_spider.up_direction.dot(Vector3.UP) > 0.95, "the body's up matches the floor")


## Strafing has to mean the same thing the camera means by it, on every surface.
## The climb component drives the body itself rather than going through the
## template's mover, so nothing else checks that the two agree about which way
## is right — and a mirrored strafe is the kind of bug you feel long before you
## can name it.
func _test_strafing() -> void:
	release_all()
	_spider.global_position = Vector3(0, -ROOM_HALF.y + 0.6, 0)
	_spider.velocity = Vector3.ZERO
	# Looking down -Z, so "right" is +X by the usual right-handed reckoning,
	# and that is also what the camera rig reports.
	_spider.view.face(Vector3(0, 0, -1))
	_spider.view.pitch = 0.0
	await run_frames(20)
	check(_spider.view.right().dot(Vector3.RIGHT) > 0.95,
		"the camera agrees right is +X (%.2v)" % _spider.view.right())

	var moved := await _strafe("move_right")
	check(moved.dot(_spider.view.right()) > 0.05,
		"D goes the way the camera calls right (%.2v)" % moved)
	moved = await _strafe("move_left")
	check(moved.dot(_spider.view.right()) < -0.05,
		"and A goes the other way (%.2v)" % moved)
	moved = await _strafe("move_forward")
	check(moved.dot(_spider.view.forward()) > 0.05,
		"W goes where you are looking (%.2v)" % moved)


## Holds one movement key and reports how far the spider actually went.
func _strafe(action: String) -> Vector3:
	_spider.velocity = Vector3.ZERO
	await run_frames(6)
	var before := _spider.global_position
	Input.action_press(action)
	await run_frames(25)
	Input.action_release(action)
	await run_frames(2)
	return _spider.global_position - before


## What the keys mean on a floor, a wall and a ceiling, worked out directly
## rather than by walking about — so every surface is covered and the numbers are
## exact.
##
## Floors and ceilings read the keys off where the camera looks. Walls read them
## off which way you face the wall — see [method SpiderClimb._climbing_axes]:
## facing it W climbs, looking along it W goes the way you look and the key on the
## wall's side climbs, and looking away from it W comes back down.
##
## Three of these were wrong for a long time and nothing said so. On a ceiling D
## came out **fully mirrored**: the camera never turns over, so screen-right stays
## screen-right, but the walk was built from `forward.cross(up)` and with the
## ceiling's up pointing down that flips. On a wall seen at an angle, D ran **down
## the wall** rather than along its face. And on a wall in front of you W went
## **down** it as soon as the camera dipped eight degrees, which a camera behind the
## spider does most of the time.
func _test_the_walk_fits_the_surface() -> void:
	var climb := _spider.climb
	var rig := _spider.view
	var slope := Vector3(0.5, 0.866, 0.0).normalized()
	var up_slope := (Vector3.UP - slope * slope.y).normalized()
	var aslant := Vector3(-1, 0, -1).normalized()
	var across_slope := (aslant - slope * aslant.dot(slope)).normalized()
	# name, surface up, camera pitch, where the camera looks, where W goes, where D goes
	var probes := [
		["a floor", Vector3.UP, 0.0, Vector3.FORWARD, Vector3.FORWARD, Vector3.RIGHT],
		["a floor, looking down", Vector3.UP, -0.785, Vector3.FORWARD,
			Vector3.FORWARD, Vector3.RIGHT],
		["a ceiling", Vector3.DOWN, 0.0, Vector3.FORWARD, Vector3.FORWARD, Vector3.RIGHT],
		["a ceiling, looking up at it", Vector3.DOWN, 0.6, Vector3.FORWARD,
			Vector3.FORWARD, Vector3.RIGHT],
		["a ceiling, turned round", Vector3.DOWN, 0.0, Vector3.RIGHT, Vector3.RIGHT,
			Vector3.BACK],
		["a gentle slope, across it", slope, 0.0, aslant, across_slope,
			across_slope.cross(slope).normalized()],
		["a gentle slope, facing up it and looking well down", slope, -1.2,
			Vector3.LEFT, up_slope, Vector3.FORWARD],
		["a wall, facing it", Vector3.RIGHT, 0.0, Vector3.LEFT, Vector3.UP,
			Vector3.FORWARD],
		["a wall, facing it, looking down", Vector3.RIGHT, -0.785, Vector3.LEFT,
			Vector3.UP, Vector3.FORWARD],
		["a wall, facing it, looking up", Vector3.RIGHT, 0.6, Vector3.LEFT,
			Vector3.UP, Vector3.FORWARD],
		["a wall, at an angle", Vector3.RIGHT, 0.0, aslant, Vector3.UP, Vector3.FORWARD],
		["a wall on your left, looking along it", Vector3.RIGHT, -0.3,
			Vector3.FORWARD, Vector3.FORWARD, Vector3.DOWN],
		["a wall on your right, looking along it", Vector3.RIGHT, -0.3,
			Vector3.BACK, Vector3.BACK, Vector3.UP],
		["a wall behind you", Vector3.RIGHT, -0.3, Vector3.RIGHT, Vector3.DOWN,
			Vector3.BACK],
		["the far wall", Vector3.FORWARD, 0.0, Vector3.BACK, Vector3.UP, Vector3.LEFT],
	]
	for probe in probes:
		var what: String = probe[0]
		var up: Vector3 = probe[1]
		var w: Vector3 = probe[4]
		var d: Vector3 = probe[5]
		rig.pitch = probe[2]
		rig.face(probe[3])
		var axes: Array = climb._key_axes(up)
		if not check(axes.size() == 2, "the keys can be read on %s" % what):
			continue
		var right: Vector3 = axes[0]
		var ahead: Vector3 = axes[1]
		check(absf(right.dot(ahead)) < 0.01,
			"on %s the two keys are square to each other" % what)
		check(absf(right.dot(up)) < 0.01 and absf(ahead.dot(up)) < 0.01,
			"and both lie on the surface")
		check(ahead.dot(w) > 0.95, "W goes %.2v (%.2v)" % [w, ahead])
		check(right.dot(d) > 0.95, "and D goes %.2v (%.2v)" % [d, right])

	# The three that were wrong, named and nailed. Each compared against the old
	# construction, so a regression has to show up as the old number.
	rig.pitch = 0.0
	rig.face(Vector3.FORWARD)
	var ceiling := Vector3.DOWN
	var lead_up := climb._surface_forward(ceiling)
	var on_ceiling: Vector3 = climb._key_axes(ceiling)[0]
	var was_ceiling := lead_up.cross(ceiling).normalized()
	check(on_ceiling.dot(rig.right()) > 0.99,
		"upside down, D is still screen-right (%+.2f)" % on_ceiling.dot(rig.right()))
	check(was_ceiling.dot(rig.right()) < -0.99,
		"where the old construction had it exactly backwards (%+.2f)"
		% was_ceiling.dot(rig.right()))

	rig.face(aslant)
	var wall := Vector3.RIGHT
	var on_wall: Vector3 = climb._key_axes(wall)[0]
	var was_wall := climb._surface_forward(wall).cross(wall).normalized()
	check(absf(on_wall.dot(Vector3.UP)) < 0.1,
		"on a wall seen at an angle, D runs along the face (%.2v)" % on_wall)
	check(absf(was_wall.dot(Vector3.UP)) > 0.99,
		"where the old construction sent you down it (%.2v)" % was_wall)

	rig.face(Vector3.LEFT)
	rig.pitch = -0.3
	var climbs: Vector3 = climb._key_axes(wall)[1]
	var was_climbing: Vector3 = climb._surface_axes(wall, climb._surface_forward(wall))[1]
	check(climbs.dot(Vector3.UP) > 0.99,
		"facing a wall with the camera tipped down, W climbs it (%.2v)" % climbs)
	check(was_climbing.dot(Vector3.UP) < -0.99,
		"where reading the look laid flat sent you back down it (%.2v)" % was_climbing)
	rig.pitch = 0.0


## A wall reads the keys off which way you face it, and nothing else.
##
## How far the camera is tipped does not come into it at all, and turning past a
## wall turns the keys smoothly: a few degrees either side of looking along one
## used to swap W and D outright. Nor does anything else jump as the camera goes
## round, on any slope from a floor to a ceiling.
func _test_walls_read_how_you_face_them() -> void:
	var climb := _spider.climb
	var rig := _spider.view
	var wall := Vector3.RIGHT
	var tipped := 0.0
	for look in [Vector3.LEFT, Vector3(-1, 0, -1), Vector3.FORWARD, Vector3(1, 0, -1),
			Vector3.RIGHT]:
		rig.face(look)
		rig.pitch = 0.0
		var level: Array = climb._key_axes(wall)
		for step in range(-13, 14):
			rig.pitch = float(step) * 0.1
			tipped = maxf(tipped, _turned_by(climb._key_axes(wall), level))
	check(tipped < 0.5,
		"on a wall, tipping the camera from well down to well up never moves the keys (%.1f°)"
		% tipped)

	# Looking along a wall on your left, a few degrees either way.
	rig.pitch = -0.3
	var now := 0.0
	var was := 0.0
	var last_now: Array = []
	var last_was: Array = []
	for degrees in range(-12, 13, 2):
		rig.yaw = deg_to_rad(float(degrees))
		var reading: Array = climb._key_axes(wall)
		var flat: Array = climb._surface_axes(wall, climb._surface_forward(wall))
		if not last_now.is_empty():
			now = maxf(now, _turned_by(reading, last_now))
			was = maxf(was, _turned_by(flat, last_was))
		last_now = reading
		last_was = flat
	check(now < 10.0,
		"looking along a wall, turning a little either way turns the keys a little (%.0f° in a 2° turn)"
		% now)
	check(was > 80.0,
		"where reading the look laid flat swung them %.0f° in one" % was)

	# All the way round, on everything from a floor to a ceiling, at a few tips of
	# the camera.
	var worst := 0.0
	var where := ""
	for tilt in [0.0, 30.0, 60.0, 75.0, 90.0, 110.0, 125.0, 150.0, 180.0]:
		var up := Vector3(0.0, cos(deg_to_rad(tilt)), sin(deg_to_rad(tilt)))
		for pitch in [-0.7, 0.0, 0.5]:
			rig.pitch = pitch
			var last: Array = []
			for step in 181:
				rig.yaw = deg_to_rad(float(step) * 2.0)
				var axes: Array = climb._key_axes(up)
				if not last.is_empty() and _turned_by(axes, last) > worst:
					worst = _turned_by(axes, last)
					where = "%d° from flat, camera tipped %+.1f" % [tilt, pitch]
				last = axes
	check(worst < 10.0,
		"on any slope, two degrees of turn never turns the keys more than ten (%.1f°, %s)"
		% [worst, where])

	# Nor where a slope starts being climbed rather than walked.
	var seam := 0.0
	rig.pitch = -0.4
	var flatter := _tilted(SpiderClimb.FLOOR_UP + 0.001)
	var steeper := _tilted(SpiderClimb.FLOOR_UP - 0.001)
	for step in 36:
		rig.yaw = deg_to_rad(float(step) * 10.0)
		seam = maxf(seam, _turned_by(climb._key_axes(flatter), climb._key_axes(steeper)))
	check(seam < 3.0,
		"where a slope gets steep enough to climb, the keys hardly move (%.1f°)" % seam)
	rig.pitch = 0.0


## Crawling from an overhang round onto a ceiling keeps going the way it was going.
##
## An overhang is climbed — facing it, W goes up it, which is out towards you — and
## a ceiling is walked, W going where you look, which facing the same way is back
## in towards the wall. Nothing in between keeps both, so the reading has to flip
## somewhere, and where it does is a gentle bend rather than an edge. The keys held
## across it are carried over it all the same.
func _test_round_an_overhang() -> void:
	var climb := _spider.climb
	var rig := _spider.view
	var keep_up := climb._current_up
	var w := Vector2(0.0, 1.0)
	var overhang := Vector3(0.83, -0.55, 0.0).normalized()
	var ceiling := Vector3(0.76, -0.65, 0.0).normalized()
	rig.face(Vector3.LEFT)
	rig.pitch = 0.3
	climb._carried.clear()
	climb._current_up = overhang
	var climbing := climb._walk(w)
	climb._current_up = ceiling
	var fresh := climb._wish_direction(w, ceiling)
	check(rad_to_deg(fresh.angle_to(climbing)) > 90.0,
		"the camera reads W one way on an overhang and the other on a ceiling (%.0f° apart)"
		% rad_to_deg(fresh.angle_to(climbing)))
	climb._carry_over(overhang, w)
	var held := climb._walk(w)
	check(rad_to_deg(held.angle_to(climbing)) < 15.0,
		"but W held from one onto the other keeps going the way it was (%.0f° off)"
		% rad_to_deg(held.angle_to(climbing)))
	for i in 5:
		climb._carry_over(ceiling, w)
	check(climb._walk(w).angle_to(held) < deg_to_rad(1.0),
		"and on across the ceiling while it stays down")
	rig.yaw += deg_to_rad(climb.carry_release_angle + 15.0)
	var swung := climb._walk(w)
	check(swung.angle_to(climb._wish_direction(w, ceiling)) < deg_to_rad(1.0),
		"until the camera swings well away, which hands it back to the camera")
	rig.face(Vector3.LEFT)
	climb._carry_over(overhang, w)
	climb._walk(Vector2.ZERO)
	check(climb._walk(w).angle_to(fresh) < deg_to_rad(1.0),
		"as letting go and pressing again does")
	climb._carried.clear()
	climb._current_up = keep_up
	rig.pitch = 0.0


## The largest angle, in degrees, between two readings of the keys.
func _turned_by(a: Array, b: Array) -> float:
	if a.size() != 2 or b.size() != 2:
		return 180.0
	return rad_to_deg(maxf((a[0] as Vector3).angle_to(b[0]),
		(a[1] as Vector3).angle_to(b[1])))


## The up of a surface tipped over from a floor until its up is [param height] high.
func _tilted(height: float) -> Vector3:
	return Vector3(0.0, height, sqrt(1.0 - height * height))


func _test_wall() -> void:
	# Face the -X wall and walk into it.
	_spider.climb.face(Vector3.LEFT)
	await run_frames(2)
	var height_before := _spider.global_position.y
	Input.action_press("move_forward")
	await run_frames(90)

	check(_spider.climb.is_attached(), "still attached after walking into the wall")
	check(_spider.climb.surface_normal.dot(Vector3.RIGHT) > 0.9,
		"the spider is on the wall (normal %.2v)" % _spider.climb.surface_normal)
	check(_spider.climb.on_steep_surface(), "and knows the wall is steep")
	check(_spider.global_position.y > height_before + 0.3,
		"it climbed (%.2f -> %.2f)" % [height_before, _spider.global_position.y])
	check(_spider.global_basis.y.dot(Vector3.RIGHT) > 0.8,
		"the body rolled onto the wall")
	check(_spider.global_basis.y.dot(_spider.climb.body_up()) > 0.8,
		"and the camera came with it")

	# The camera did not roll onto the wall, and must not: a level horizon is what
	# makes the rig pleasant to look through. So the reconciling happens in the
	# walk. Screen-right, flattened onto the wall, is where D goes — which on a
	# wall facing you runs along the face. Derived from forward.cross(up), as this
	# used to be, it was *down the wall* instead.
	var normal := _spider.climb.surface_normal
	check(absf(_spider.view.up().dot(normal)) < 0.9,
		"the camera kept its own horizon (%.2v up)" % _spider.view.up())
	var across := _spider.view.right()
	var along_wall := across - normal * across.dot(normal)
	if check(along_wall.length_squared() > 0.02,
			"screen-right has somewhere to go on the wall (%.2v)" % along_wall):
		along_wall = along_wall.normalized()
		Input.action_release("move_forward")
		await run_frames(6)
		var from_wall := _spider.global_position
		Input.action_press("move_right")
		await run_frames(25)
		Input.action_release("move_right")
		await run_frames(2)
		var sideways := _spider.global_position - from_wall
		check(_spider.climb.surface_normal.dot(Vector3.RIGHT) > 0.9,
			"strafing keeps you on the wall")
		check(sideways.dot(along_wall) > 0.05,
			"and D runs along the face, where the screen says (%.2v)" % sideways)
		check(absf(sideways.dot(Vector3.UP)) < sideways.length() * 0.7,
			"rather than down it (%.2fm of %.2fm vertical)"
			% [absf(sideways.dot(Vector3.UP)), sideways.length()])
		Input.action_press("move_forward")


func _test_ceiling() -> void:
	# Keep walking up; the wall runs into the ceiling.
	await run_frames(150)
	check(_spider.climb.surface_normal.dot(Vector3.DOWN) > 0.9,
		"carried on over onto the ceiling (normal %.2v)" % _spider.climb.surface_normal)
	check(_spider.global_position.y > ROOM_HALF.y - 0.5, "and is up at ceiling height")
	# Movement is camera-relative now, so turn to look along the ceiling rather
	# than back at the wall that was just climbed.
	_spider.climb.face(Vector3.RIGHT)
	var across_before := _spider.global_position.x
	await run_frames(60)
	check(_spider.global_position.x > across_before + 0.2,
		"it walks along the ceiling upside down (%.2f -> %.2f)"
		% [across_before, _spider.global_position.x])
	check(_spider.global_basis.y.dot(Vector3.DOWN) > 0.8, "hanging upside down")
	Input.action_release("move_forward")
	await run_frames(20)

	# The bug the screen-axis walk exists to kill. Upside down, with the world
	# still drawn the right way up — and it stays that way, because the camera
	# never turns over — the body's right and the camera's right pointed opposite
	# ways, so pressing D walked you left. Nothing in the game said so; it just
	# felt wrong on every ceiling.
	check(_spider.view.up().dot(Vector3.UP) > 0.5,
		"the camera is still the right way up over a ceiling (%.2v)"
		% _spider.view.up())
	var beside := _spider.global_position
	Input.action_press("move_right")
	await run_frames(25)
	Input.action_release("move_right")
	await run_frames(2)
	var sideways := _spider.global_position - beside
	check(_spider.climb.surface_normal.dot(Vector3.DOWN) > 0.9,
		"strafing does not shake you off the ceiling")
	check(sideways.dot(_spider.view.right()) > 0.05,
		"and D still goes the way the camera calls right, upside down (%.2v)" % sideways)


func _test_dragline() -> void:
	var ceiling_height := _spider.global_position.y
	Input.action_press("move_crouch")
	await run_frames(6)

	check(_spider.climb.is_hanging(), "Ctrl on the ceiling drops the spider onto a line")
	check(_spider.climb.line_anchor.y > ceiling_height, "the line is anchored above it")

	var length_before := _spider.climb.line_length
	await run_frames(60)
	check(_spider.climb.line_length > length_before + 0.2,
		"holding Ctrl pays the line out (%.2f -> %.2f)"
		% [length_before, _spider.climb.line_length])
	check(_spider.global_position.y < ceiling_height - 0.2,
		"and the spider descends on it")
	check(_spider.global_position.distance_to(_spider.climb.line_anchor)
		<= _spider.climb.line_length + 0.15, "it never hangs below the line it has spun")
	Input.action_release("move_crouch")

	# Reel back up.
	var down_at := _spider.global_position.y
	Input.action_press("move_jump")
	await run_frames(50)
	check(_spider.global_position.y > down_at + 0.1, "Space climbs back up the line")
	Input.action_release("move_jump")
	await run_frames(5)


func _test_letting_go() -> void:
	if not check(_spider.climb.is_hanging(), "still on the line"):
		return
	var drop_from := _spider.global_position.y
	Input.action_press("web_cancel")
	await run_frames(2)
	Input.action_release("web_cancel")
	check(not _spider.climb.is_hanging(), "right mouse lets go of the line")
	await run_frames(60)
	check(_spider.global_position.y < drop_from, "and the spider drops")
	await run_frames(90)
	check(_spider.climb.is_attached(), "it catches whatever it lands on")


func _test_leaping_off_a_wall() -> void:
	# Put it back on a known wall rather than wherever it happened to land.
	_spider.climb.release()
	_spider.global_position = Vector3(-ROOM_HALF.x + 0.35, 0.0, 0.0)
	_spider.velocity = Vector3.ZERO
	await run_frames(30)
	if not check(_spider.climb.on_steep_surface(),
			"back on the wall to jump from (normal %.2v)" % _spider.climb.surface_normal):
		return

	var wall_normal := _spider.climb.surface_normal
	var distance_before := _spider.global_position.x
	Input.action_press("move_jump")
	await run_frames(3)
	Input.action_release("move_jump")
	check(not _spider.climb.is_attached(), "jumping lets go of the wall")
	await run_frames(12)
	var travelled := (_spider.global_position.x - distance_before) * wall_normal.x
	check(travelled > 0.05, "and pushes off away from it (%.2fm)" % travelled)


## Walking into a wall climbs it, however the camera happens to be tipped, and
## walking up it carries on over onto the ceiling.
##
## W is the camera's forward laid onto the surface, and across an edge that
## reading jumps. Tipped down even a little, W on a wall means *down* the wall —
## straight back into the floor. So the spider took the floor, then the wall, then
## the floor, a swap every three tenths of a second, and never climbed at all; the
## ceiling did the same from the wall, and every swap threw the camera half a body
## length. [method SpiderClimb._carry_over] keeps the keys going the way they were
## going across the edge.
##
## [method _test_wall] never saw it, because it walks in with the camera level,
## where the reading happens to agree.
func _test_corners_do_not_bounce() -> void:
	release_all()
	var floor_y := -ROOM_HALF.y + 0.2
	for tip in [-0.5, -0.25, 0.0]:
		await _set_down(Vector3(-ROOM_HALF.x + 0.9, floor_y + 0.2, 0.3), Vector3.LEFT, tip)
		var start_y := _spider.global_position.y
		var walk := await _walk_and_watch(80)
		var normal: Vector3 = walk["normal"]
		check(normal.dot(Vector3.RIGHT) > 0.9,
			"walking into a wall with the camera tipped %+.2f puts you on it (normal %.2v)"
			% [tip, normal])
		check(_spider.global_position.y > start_y + 0.3,
			"and climbs it (%.2fm up)" % (_spider.global_position.y - start_y))
		check(walk["returns"] == 0,
			"without going back to the floor it left (%d times)" % walk["returns"])
		check(walk["jerk"] < 1.0,
			"and the camera swings round the corner rather than jumping (%.2f body heights in a frame)"
			% walk["jerk"])

	# Up the wall and over onto the ceiling, looking up the way you would.
	await _set_down(Vector3(-ROOM_HALF.x + 0.35, ROOM_HALF.y - 0.6, 0.3), Vector3.LEFT, 0.3)
	if not check(_spider.climb.surface_normal.dot(Vector3.RIGHT) > 0.9,
			"on the wall below the ceiling (normal %.2v)" % _spider.climb.surface_normal):
		return
	var from_x := _spider.global_position.x
	var over := await _walk_and_watch(90)
	var on: Vector3 = over["normal"]
	check(on.dot(Vector3.DOWN) > 0.9,
		"keeping W down carries you over onto the ceiling (normal %.2v)" % on)
	check(_spider.global_position.x > from_x + 0.2,
		"and on across it, away from the wall (%.2fm)" % (_spider.global_position.x - from_x))
	check(over["returns"] == 0,
		"without dropping back onto the wall (%d times)" % over["returns"])


## Standing on a wall and pressing a key fresh, with the camera looking down at the
## spider the way a camera behind it does: W climbs. Looking along the wall, W goes
## the way you look and the key on the wall's side climbs; looking away from it, W
## comes back down.
##
## [method _test_corners_do_not_bounce] walks onto the wall with the key already
## down, which the edge carries. This is the press that starts on the wall, where
## the camera's reading is all there is — and where it used to send you down.
func _test_climbing_with_the_camera_tipped_down() -> void:
	release_all()
	await _set_down(Vector3(-ROOM_HALF.x + 0.35, -0.3, 0.3), Vector3.LEFT, -0.6)
	if not check(_spider.climb.surface_normal.dot(Vector3.RIGHT) > 0.9,
			"set down on a wall (normal %.2v)" % _spider.climb.surface_normal):
		return
	var moved := await _strafe("move_forward")
	check(moved.y > 0.1,
		"facing a wall with the camera tipped well down, W climbs it (%.2fm)" % moved.y)
	_spider.view.face(Vector3.FORWARD)
	_spider.view.pitch = -0.4
	moved = await _strafe("move_forward")
	check(moved.dot(Vector3.FORWARD) > 0.1 and absf(moved.y) < moved.length() * 0.3,
		"looking along it, W goes the way you are looking (%.2v)" % moved)
	moved = await _strafe("move_left")
	check(moved.y > 0.1, "and A, on the wall's side, climbs (%.2v)" % moved)
	moved = await _strafe("move_right")
	check(moved.y < -0.1, "while D comes back down (%.2v)" % moved)
	_spider.view.face(Vector3.RIGHT)
	_spider.view.pitch = -0.2
	moved = await _strafe("move_forward")
	check(moved.y < -0.1, "and with your back to it, W comes down (%.2v)" % moved)
	check(_spider.climb.surface_normal.dot(Vector3.RIGHT) > 0.9,
		"all of it on the wall (normal %.2v)" % _spider.climb.surface_normal)
	_spider.view.pitch = 0.0


## Walking along a line to the wall it is tied to takes you off the line and onto
## the wall, once.
##
## The same bounce as a corner, and the one that read as being unable to get off
## the rope: on the wall W pointed back down onto the line, the line took you back,
## and the line walked you into the wall again — the spider shuttling between the
## two for as long as the key was held.
func _test_off_a_line_onto_a_wall() -> void:
	release_all()
	var pattern: WebPattern = null
	for candidate in _spider.web_builder.patterns:
		if candidate.id == "frame_line":
			pattern = candidate
	if not check(pattern != null, "a frame line to walk"):
		return
	# Tied to the floor at one end and the +Z wall at the other, sloping up, the
	# way a grapple from the floor to the wall leaves one.
	var low := Vector3(0.0, -ROOM_HALF.y + 0.2 + 0.125, -1.0)
	var high := Vector3(0.0, -0.4, ROOM_HALF.z - 0.2)
	var line := WebStrand.spin(pattern, low, high, 1.0)
	if not check(line != null, "the line goes up"):
		return
	line.place_in(_room)
	await physics_frame
	await _set_down(low.lerp(high, 0.3) + Vector3.UP * 0.1, Vector3.BACK, -0.2)
	if check(_spider.climb.on_silk and _spider.climb.standing_on == line,
			"standing on the line"):
		# Long enough to reach the wall and go on up it, which is where W carries you
		# now: the wall is the next thing it stands on, whatever comes after.
		var walk := await _walk_and_watch(150, line)
		var visited: Array[Vector3] = walk["visited"]
		var next: Vector3 = visited[1] if visited.size() > 1 else Vector3.ZERO
		check(next.dot(Vector3.FORWARD) > 0.9,
			"walking it to the wall puts you on the wall next (normal %.2v)" % next)
		check(not _spider.climb.on_silk, "and off the silk")
		check(walk["remounts"] == 0,
			"without the line taking you back (%d times)" % walk["remounts"])
		check(walk["returns"] == 0,
			"or anything else you had already left (%d times)" % walk["returns"])
	line.queue_free()
	await physics_frame


## The body is a rig: a skeleton with named bones, one mesh skinned to it, and a
## gait running in the skeleton's own update. It used to be boxes swinging in two
## sets, which could say how big the spider was and which way it faced and nothing
## else; a rig can take a modelled spider later on the same bone names.
func _test_the_body_is_a_skeleton() -> void:
	var body := _spider.body
	var skeleton := body.skeleton
	if not check(skeleton != null, "the spider's body is a skeleton"):
		return
	check(skeleton.get_bone_count() >= 45,
		"with a bone for every part (%d)" % skeleton.get_bone_count())
	var missing: Array[String] = []
	for pair in 4:
		for side in SpiderRig.SIDES:
			for part in ["Coxa", "Femur", "Tibia", "Tarsus"]:
				var bone := "Leg.%s%d.%s" % [side, pair + 1, part]
				if skeleton.find_bone(bone) < 0:
					missing.append(bone)
	for part in ["Thorax", "Head", "Abdomen", "Spinnerets", "Chelicera.L", "Fang.R", "Palp.L.2"]:
		if skeleton.find_bone(part) < 0:
			missing.append(part)
	check(missing.is_empty(), "eight legs of four joints, and the rest of a spider (%s missing)"
		% (", ".join(missing) if not missing.is_empty() else "none"))
	var shell := body.mesh
	check(shell != null and shell.mesh != null and shell.skin != null
			and shell.get_node_or_null(shell.skeleton) == skeleton,
		"worn as one mesh, skinned to those bones")
	check(body.gait != null and body.gait.get_parent() == skeleton,
		"and moved by a gait that runs inside the skeleton")
	var size := skeleton.global_transform.basis.get_scale().x
	check(is_equal_approx(size, _spider.stage().body_height),
		"sized to the tier (%.3f for a %.2fm body)" % [size, _spider.stage().body_height])


## The spider can be drawn three ways, and every one of them is a mesh on the same
## bones: detailed, low poly — the same parts cut into flat faces — and minimal,
## two blobs on eight thin legs. O goes round them. Changing look swaps the mesh
## and touches nothing else, which is also the proof that a modelled spider could
## go onto these bones the same way.
func _test_three_looks_on_one_skeleton() -> void:
	var body := _spider.body
	var skeleton := body.skeleton
	var shell := body.mesh
	var bones := skeleton.get_bone_count()
	var was := body.look
	body.look = SpiderRig.Look.DETAILED
	await _set_down(Vector3(0.0, -ROOM_HALF.y + 0.5, 0.6), Vector3.FORWARD, -0.2)
	await wait_until(func() -> bool: return body.gait.lifted() == 0, 120)
	await run_frames(10)
	var feet := body.feet()
	var faces := {}
	for look in SpiderRig.Look.size():
		body.look = look as SpiderRig.Look
		var label := body.look_name()
		var mesh := shell.mesh as ArrayMesh
		if not check(mesh != null and mesh.get_surface_count() == 2,
				"the %s look is one mesh: a body and its eyes" % label):
			continue
		var stray := 0
		var count := 0
		var used := {}
		for surface in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(surface)
			var ids: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			for v in range(0, ids.size(), 4):
				if ids[v] < 0 or ids[v] >= bones or not is_equal_approx(weights[v], 1.0):
					stray += 1
				used[ids[v]] = true
			count += mesh.surface_get_array_len(surface) / 3
		faces[look] = count
		check(stray == 0, "with every vertex on one of the skeleton's bones (%d not)" % stray)
		check(shell.skin != null and shell.get_node_or_null(shell.skeleton) == skeleton,
			"worn on the same skeleton")
		if look == SpiderRig.Look.LOW_POLY:
			var normals: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
			var smooth := 0
			for i in range(0, normals.size(), 3):
				if not (normals[i].is_equal_approx(normals[i + 1])
						and normals[i].is_equal_approx(normals[i + 2])):
					smooth += 1
			check(smooth == 0, "shaded flat, one normal to a face (%d faces smooth)" % smooth)
		if look == SpiderRig.Look.MINIMAL:
			var extras: Array[String] = []
			for bone in used:
				var bone_name := skeleton.get_bone_name(bone)
				if not (bone_name == "Thorax" or bone_name == "Abdomen" or bone_name.begins_with("Leg.")):
					extras.append(bone_name)
			check(extras.is_empty(), "nothing on it but a body, an abdomen and legs (%s besides)"
				% (", ".join(extras) if not extras.is_empty() else "nothing"))
	if faces.size() == SpiderRig.Look.size():
		check(faces[SpiderRig.Look.LOW_POLY] * 4 < faces[SpiderRig.Look.DETAILED],
			"low poly is a fraction of the detailed look's faces (%d against %d)"
			% [faces[SpiderRig.Look.LOW_POLY], faces[SpiderRig.Look.DETAILED]])
		check(faces[SpiderRig.Look.MINIMAL] < faces[SpiderRig.Look.DETAILED],
			"and minimal is fewer too (%d)" % faces[SpiderRig.Look.MINIMAL])

	# O, from the start: round every look and back to where it began.
	check(InputMap.has_action(_spider.input_cycle_look), "there is a key for the spider's look")
	body.look = SpiderRig.Look.DETAILED
	var said: Array[String] = []
	var listen := func(text: String) -> void: said.append(text)
	_spider.notice.connect(listen)
	var seen: Array[String] = []
	for i in SpiderRig.Look.size():
		send_action(_spider.input_cycle_look)
		release_action(_spider.input_cycle_look)
		await process_frame
		seen.append(body.look_name())
	_spider.notice.disconnect(listen)
	check(seen == ["low poly", "minimal", "detailed"],
		"O goes round them all and back (%s)" % ", ".join(seen))
	check(said.size() == seen.size() and said.back().contains("detailed"),
		"saying which each time (%s)" % " / ".join(said))
	var moved := 0.0
	var now := body.feet()
	for leg in mini(feet.size(), now.size()):
		moved = maxf(moved, feet[leg].distance_to(now[leg]))
	check(moved < _spider.stage().body_height * 0.02,
		"and not one foot moved for it (%.3f body heights)" % (moved / _spider.stage().body_height))
	body.look = was


## Feet go down on whatever the spider is on, stay where they are put, and walk in
## two sets of four.
##
## That is the whole of the gait. A foot is planted in the world and does not move
## until the body has gone far enough past it, so nothing slides; the legs step in
## the tetrapod pattern real spiders use, so there are always four down; and the
## footholds are found by looking, so on a wall they are on the wall.
func _test_eight_feet_on_whatever_is_underfoot() -> void:
	var floor_y := -ROOM_HALF.y + 0.2
	var height: float = _spider.stage().body_height
	var gait := _spider.body.gait
	await _set_down(Vector3(0.0, floor_y + 0.3, 0.6), Vector3.FORWARD, -0.2)
	# A spider that has just landed shuffles its feet into place; standing is
	# once that is done.
	await wait_until(func() -> bool: return gait.lifted() == 0, 120)
	await run_frames(10)
	var feet := _spider.body.feet()
	if not check(feet.size() == 8, "eight feet (%d)" % feet.size()):
		return
	var highest := 0.0
	var nearest := INF
	for foot in feet:
		highest = maxf(highest, absf(foot.y - floor_y))
		var flat := Vector2(foot.x - _spider.global_position.x, foot.z - _spider.global_position.z)
		nearest = minf(nearest, flat.length())
	check(highest < height * 0.08,
		"standing, every foot is on the floor (%.3f body heights off at most)" % (highest / height))
	check(nearest > height * 0.35,
		"and spread round the body, not tucked under it (%.2f body heights out at least)"
		% (nearest / height))
	check(gait.lifted() == 0, "with none of them lifted (%d)" % gait.lifted())

	# Walking: count what is in the air each frame, and watch the feet that are not.
	var groups := gait.groups()
	var most := 0
	var both := 0
	var stepped := PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0])
	var slid := 0.0
	var was := gait.stepping()
	var tips := _spider.body.feet()
	var start := _spider.global_position
	Input.action_press("move_forward")
	# Every drawn frame, not every physics tick: the gait poses the legs once a
	# drawn frame, and a quick step can start and finish between two ticks. For
	# fifty ticks, which is well short of the far wall.
	var until := Engine.get_physics_frames() + 50
	while Engine.get_physics_frames() < until:
		await process_frame
		var up := gait.stepping()
		var now := _spider.body.feet()
		var sets := [0, 0]
		for leg in 8:
			if up[leg]:
				sets[groups[leg]] += 1
				stepped[leg] += 1
			elif not was[leg]:
				slid = maxf(slid, now[leg].distance_to(tips[leg]) / height)
		most = maxi(most, sets[0] + sets[1])
		if sets[0] > 0 and sets[1] > 0:
			both += 1
		was = up
		tips = now
	Input.action_release("move_forward")
	await run_frames(2)
	check(most <= 4, "walking, never more than four feet up at once (%d)" % most)
	check(both == 0, "in two sets of four that take turns (%d frames with both up)" % both)
	var lazy := 0
	for leg in 8:
		if stepped[leg] == 0:
			lazy += 1
	check(lazy == 0, "and every leg takes its steps (%d never lifted)" % lazy)
	check(slid < 0.03,
		"while a foot that is down stays exactly where it was put (%.3f body heights of slide)"
		% slid)

	# Up a wall: the footholds are on the wall.
	await _set_down(Vector3(-ROOM_HALF.x + 0.3, 0.0, 0.3), Vector3.LEFT, 0.0)
	if check(_spider.climb.surface_normal.dot(Vector3.RIGHT) > 0.9, "on the wall"):
		var wall_x := -ROOM_HALF.x + 0.2
		var off_wall := 0.0
		for foot in _spider.body.feet():
			off_wall = maxf(off_wall, absf(foot.x - wall_x))
		check(off_wall < height * 0.1,
			"with every foot on the wall rather than hanging off it (%.3f body heights off)"
			% (off_wall / height))

	# In the air: nothing under the feet, so none of them are put down, and the
	# legs spread the way a falling spider's do.
	_spider.climb.stand_upright()
	_spider.view.settle()
	_spider.global_position = Vector3(0.5, 0.6, 0.5)
	_spider.velocity = Vector3.ZERO
	await run_frames(12)
	if check(not _spider.climb.is_attached(), "falling"):
		var low := INF
		var tucked := INF
		for foot in _spider.body.feet():
			low = minf(low, foot.y)
			tucked = minf(tucked, Vector2(foot.x - _spider.global_position.x,
				foot.z - _spider.global_position.z).length())
		check(low > floor_y + height, "with no foot on the floor (%.2fm above it)" % (low - floor_y))
		check(tucked > height * 0.35,
			"and the legs spread wide (%.2f body heights out at least)" % (tucked / height))
		check(gait.lifted() == 0, "because nothing is stepping in the air")
	await run_frames(60)


## Puts the spider down at [param at], lets it take hold of whatever is nearest,
## and points the camera along [param look] tipped by [param tip] radians.
func _set_down(at: Vector3, look: Vector3, tip: float) -> void:
	release_all()
	_spider.climb.stand_upright()
	_spider.view.settle()
	_spider.global_position = at
	_spider.velocity = Vector3.ZERO
	_spider.view.face(look)
	_spider.view.pitch = tip
	await run_frames(40)


## Holds W for [param count] physics frames and says what the walk did: how many
## times it went back onto a surface it had already left, the surfaces it was on
## in order, where it ended up, and the most the camera moved in one frame beyond
## what the spider itself moved, in body heights. With a [param line], also how
## many times the spider got back onto it after stepping off.
func _walk_and_watch(count: int, line: WebStrand = null) -> Dictionary:
	var height: float = _spider.stage().body_height
	var visited: Array[Vector3] = [_spider.climb.body_up()]
	var returns := 0
	var remounts := 0
	var standing: WebStrand = _spider.climb.standing_on
	var jerk := 0.0
	var camera_was := _spider.view.camera.global_position
	var body_was := _spider.global_position
	Input.action_press("move_forward")
	for i in count:
		await physics_frame
		var now := _spider.climb.standing_on
		if line != null and now == line and standing != line:
			remounts += 1
		standing = now
		var up := _spider.climb.body_up()
		if up.angle_to(visited.back()) > deg_to_rad(45.0):
			for earlier in visited:
				if up.angle_to(earlier) < deg_to_rad(10.0):
					returns += 1
					break
			visited.append(up)
		var camera := _spider.view.camera.global_position
		var body := _spider.global_position
		jerk = maxf(jerk, ((camera - camera_was) - (body - body_was)).length() / height)
		camera_was = camera
		body_was = body
	Input.action_release("move_forward")
	await run_frames(2)
	return {"returns": returns, "remounts": remounts, "visited": visited,
		"jerk": jerk, "normal": _spider.climb.surface_normal}


## Stringing a line across the room and riding it: the ride should pick up
## speed going downhill and fling the spider off the far end.
func _test_ziplining() -> void:
	_spider.climb.release()
	_spider.global_position = Vector3(-ROOM_HALF.x + 0.6, ROOM_HALF.y - 0.5, 0.0)
	_spider.velocity = Vector3.ZERO
	# Bridges unlock at the second size tier, and build mode quietly falls back
	# to something spinnable if you have not got there.
	_spider.growth.feed(120.0, "test")
	await run_frames(10)

	# A line running downhill across the room.
	var builder := _spider.web_builder
	var top := Vector3(-ROOM_HALF.x + 0.5, ROOM_HALF.y - 0.4, 0.0)
	var bottom := Vector3(ROOM_HALF.x - 0.5, -ROOM_HALF.y + 0.9, 0.0)
	for i in builder.patterns.size():
		if builder.patterns[i].id == "silk_bridge":
			builder.pattern_index = i
	builder.start()
	builder.add_anchor(top)
	builder.add_anchor(bottom)
	builder.stop()
	await run_frames(2)

	var bridge: WebStrand = null
	for node in _spider.get_tree().get_nodes_in_group("silk_webs"):
		var strand := node as WebStrand
		if strand != null and strand.pattern.id == "silk_bridge":
			bridge = strand
	if not check(bridge != null, "a line to ride"):
		return
	check(bridge.pattern.shape == WebPattern.Shape.STRAND,
		"and it is a strand, which is all riding asks for now")

	_spider.global_position = top + Vector3(0.1, -0.1, 0)
	_spider.velocity = Vector3.ZERO
	await run_frames(2)
	check(_get_on_line(), "the spider clips onto the line")
	check(_spider.climb.is_riding(), "and is riding it")

	var started_at := _spider.global_position
	await run_frames(20)
	check(_spider.climb.ride_velocity() > 0.3,
		"it picks up speed going downhill (%.2f m/s)" % _spider.climb.ride_velocity())
	check(_spider.global_position.distance_to(started_at) > 0.2, "and travels along the line")
	check(_spider.global_position.y < started_at.y, "downwards, as gravity intends")

	# Ride it to the end and get thrown off.
	var top_speed := 0.0
	for i in 200:
		top_speed = maxf(top_speed, _spider.climb.ride_velocity())
		if not _spider.climb.is_riding():
			break
		await physics_frame
	check(not _spider.climb.is_riding(), "the far end throws it off the line")
	check(top_speed > 1.0, "after building real speed (%.2f m/s)" % top_speed)
	check(_spider.velocity.length() > 0.5,
		"and it carries that speed off the end (%.2f m/s)" % _spider.velocity.length())

	# Let go part way along instead.
	_spider.climb.release()
	_spider.global_position = top + Vector3(0.1, -0.1, 0)
	_spider.velocity = Vector3.ZERO
	await run_frames(4)
	_get_on_line()
	await run_frames(25)
	if check(_spider.climb.is_riding(), "back on the line"):
		_spider.climb.toggle_ride()
		check(not _spider.climb.is_riding(), "and can let go part way along")
		check(_spider.velocity.y > 0.0, "with a kick to clear the edge")
		# The other half of the pair: the line is still right there, so the same
		# key takes hold again rather than making you land on it a second time.
		check(_spider.climb.toggle_ride(), "and the same key takes hold again")
		check(_spider.climb.is_riding(), "back on the line straight away")
		_spider.climb.release()

	check(_spider.view.third_person, "the camera starts behind the spider")
	_spider.view.toggle_mode()
	check(not _spider.view.third_person, "and can be brought inside its head")
	_spider.view.toggle_mode()


## Gets the spider onto a line the way a player would. Dropping onto one clips
## you on by itself now, so pressing the key when you are already riding would
## take you straight back off — this only presses it when it has to.
func _get_on_line() -> bool:
	return _spider.climb.is_riding() or _spider.climb.toggle_ride()


## Placing an anchor is a journey: the spider hauls itself to the spot and
## leaves silk behind it, rather than pointing at it from across the room.
func _test_grappling() -> void:
	_spider.climb.release()
	_spider.global_position = Vector3(0, -ROOM_HALF.y + 0.6, 0)
	_spider.velocity = Vector3.ZERO
	await run_frames(20)

	var builder := _spider.web_builder
	for i in builder.patterns.size():
		if builder.patterns[i].id == "sheet_web":
			builder.pattern_index = i
	builder.start()

	# Look at the far wall and grapple to it.
	_spider.view.face(Vector3.RIGHT)
	_spider.view.pitch = 0.0
	await run_frames(2)
	var started_at := _spider.global_position
	builder.place()
	check(_spider.climb.is_grappling(), "clicking an anchor starts a grapple")

	for i in 120:
		if not _spider.climb.is_grappling():
			break
		await physics_frame
	check(not _spider.climb.is_grappling(), "the grapple finishes")
	check(_spider.global_position.distance_to(started_at) > 0.5,
		"the spider travelled to its anchor (%.2fm)"
		% _spider.global_position.distance_to(started_at))
	check(builder.anchors.size() == 1, "and the anchor landed there")

	# A second anchor should leave a line between the two.
	var webs_before := 0
	for node in _spider.get_tree().get_nodes_in_group("silk_webs"):
		webs_before += 1
	_spider.view.face(Vector3.FORWARD)
	await run_frames(2)
	builder.place()
	for i in 120:
		if not _spider.climb.is_grappling():
			break
		await physics_frame
	await run_frames(2)
	var webs_after := 0
	for node in _spider.get_tree().get_nodes_in_group("silk_webs"):
		webs_after += 1
	check(builder.anchors.size() == 2, "a second anchor lands too")
	check(webs_after > webs_before, "with a line dragged between them")
	builder.stop()


## The rig holds still, and winding a throw up frames it without moving.
func _test_a_steady_view() -> void:
	release_all()
	_spider.climb.release()
	_spider.global_position = Vector3(0, -ROOM_HALF.y + 0.6, 0)
	_spider.velocity = Vector3.ZERO
	_spider.view.face(Vector3(0, 0, -1))
	_spider.view.pitch = 0.0
	await run_frames(45)

	var height: float = _spider.stage().body_height
	var rig := _spider.view
	rig.aim_blend = 0.0

	# Placed, not eased. We tried easing it across the frames between physics
	# ticks and it was more movement than it was worth: a camera that lags is a
	# camera you can feel, and what it was hiding was a step of a few centimetres.
	rig.update(height)
	var settled := rig.camera.global_position
	rig.camera.global_position = settled + Vector3(0, 0, 4.0) * height
	rig.update(height)
	check(rig.camera.global_position.distance_to(settled) < 0.0001,
		"the arm goes where it belongs, the frame it is asked to")

	# Straight up the world at any pitch. Taking the lift from the look basis
	# instead slides the pivot forward and back every time you glance up or down,
	# which tilts everything worked out from the crosshair — a thrown web's plane
	# among it. Measured with the arm shortened to nothing so the camera sits *on*
	# the pivot: derived from a full-length arm it cannot be measured in a room
	# this size, because the arm is longer than the room is tall and gets pulled in
	# off a wall at most pitches.
	var arm := rig.distance
	rig.distance = 0.0
	var upright := true
	var worst := 0.0
	for tip in [0.0, -0.6, 0.5, 1.1]:
		rig.pitch = tip
		rig.update(height)
		var offset := rig.camera.global_position - _spider.global_position
		if offset.length_squared() < 0.000001:
			continue
		var along := offset.normalized().dot(Vector3.UP)
		worst = maxf(worst, absf(1.0 - along))
		if along < 0.999:
			upright = false
	rig.pitch = 0.0
	check(upright,
		"and stands off straight up the world at any pitch (%.4f off)" % worst)

	# Winding a throw up lifts the point the arm orbits, so the spider drops down
	# the screen and the room over its back opens out — which is where the silk is
	# about to go. Measured the same way: with no arm, the camera *is* the pivot.
	rig.update(height)
	var resting := rig.camera.global_position
	rig.aim_blend = 1.0
	rig.update(height)
	var raised := rig.camera.global_position
	rig.aim_blend = 0.0
	rig.distance = arm
	rig.update(height)
	check(raised.y > resting.y + height * 0.1,
		"the pivot rises for a throw (%.2fm up)" % (raised.y - resting.y))
	check(Vector2(raised.x - resting.x, raised.z - resting.z).length() < height * 0.01,
		"straight up, with no swing round the shoulder")
	check(is_equal_approx(rig.distance, arm),
		"and the arm keeps its length (%.2f body heights)" % rig.distance)

	# And the view widens with it. One owner for the angle, because the speed rush
	# writes it too and two things easing one number is two things fighting.
	check(rig.aim_fov_gain > 0.0,
		"a throw opens the view by %.0f°" % rig.aim_fov_gain)
	var lens := _spider.view.camera
	check(_spider._base_fov > 0.0,
		"the view has a resting angle (%.1f°)" % _spider._base_fov)
	check(absf(lens.fov - _spider._base_fov) < 0.5,
		"which is where it sits at rest (%.1f° against %.1f°)"
		% [lens.fov, _spider._base_fov])
	# Held each tick, because the builder eases the blend back to nothing whenever
	# nothing is actually being aimed — which is the right thing for it to do and
	# would quietly undo this from under the check.
	for i in 40:
		rig.aim_blend = 1.0
		await physics_frame
	check(lens.fov > _spider._base_fov + rig.aim_fov_gain * 0.5,
		"and it opens up while one is being wound (%.1f°)" % lens.fov)
	rig.aim_blend = 0.0
	for i in 40:
		await physics_frame
	check(absf(lens.fov - _spider._base_fov) < 1.0,
		"then closes again after (%.1f°)" % lens.fov)


# --- scaffolding --------------------------------------------------------

## A grapple keeps what it was carrying along the surface, and a skid is where
## that momentum lives.
##
## Arriving used to zero the velocity, which made every grapple a full stop. The
## three pieces are all needed: keep the tangential part on arrival, let speed
## above a walk bleed gently rather than being clamped, and let a jump carry what
## you already had. Any one of them alone is invisible.
func _test_momentum_survives_a_grapple() -> void:
	release_all()
	var climb := _spider.climb
	check(climb.grapple_carry > 0.0,
		"some of a grapple's travel survives the landing (%.0f%%)"
		% (climb.grapple_carry * 100.0))
	check(climb.skid_damping < climb.deceleration * 0.5,
		"and speed above a walk bleeds slower than a stop (%.1f against %.1f)"
		% [climb.skid_damping, climb.deceleration])

	# Head-on into a floor: all of the travel is into the stone, so all of it
	# goes. A stop is the right answer here and it has to stay the right answer.
	_spider.global_position = Vector3(0.0, -ROOM_HALF.y + 1.0, 0.0)
	climb.release()
	_spider.velocity = Vector3(0.0, -8.0, 0.0)
	climb.grapple_target = Vector3(0.0, -ROOM_HALF.y, 0.0)
	climb.grapple_normal = Vector3.UP
	climb._arrive()
	check(_spider.velocity.length() < 0.5,
		"straight down onto a floor still stops dead (%.2f m/s)"
		% _spider.velocity.length())

	# Glancing along it: the travel is mostly sideways, so most of it is kept.
	climb.release()
	_spider.velocity = Vector3(9.0, -2.0, 0.0)
	climb.grapple_target = Vector3(1.0, -ROOM_HALF.y, 0.0)
	climb.grapple_normal = Vector3.UP
	climb._arrive()
	var kept := _spider.velocity.length()
	check(kept > 5.0, "but skimming across it lands you running (%.2f m/s)" % kept)
	check(absf(_spider.velocity.y) < 0.01,
		"with the part aimed at the stone gone (%.3f downward)" % _spider.velocity.y)
	check(kept < 9.0, "and a little lost to the landing (%.2f of 9.00)" % kept)

	# The skid lasts long enough to be a thing you can use. Walk speed is about
	# 2.4, so this measures how long it takes to come back down toward it.
	var fast := _spider.velocity.length()
	await run_frames(12)
	var after := _spider.climb.tangent_velocity.length()
	check(after > _spider.stage().move_speed,
		"a fifth of a second later it is still above a walk (%.2f over %.2f)"
		% [after, _spider.stage().move_speed])
	check(after < fast, "and coming down (%.2f from %.2f)" % [after, fast])

	# And a jump out of that skid takes it with you, which is the chaining.
	var sideways := _spider.climb.tangent_velocity
	_spider.velocity = sideways
	climb._leap(Vector2.ZERO)
	var flat := Vector3(_spider.velocity.x, 0.0, _spider.velocity.z)
	check(flat.length() > sideways.length() * 0.8,
		"jumping out of a skid carries it into the air (%.2f of %.2f)"
		% [flat.length(), sideways.length()])
	check(_spider.velocity.y > 0.0,
		"while still going up (%.2f m/s)" % _spider.velocity.y)
	climb.release()
	_spider.global_position = Vector3(0.0, -ROOM_HALF.y + 0.6, 0.0)
	_spider.velocity = Vector3.ZERO
	await run_frames(10)


func _build_room() -> Node3D:
	var room := Node3D.new()
	room.name = "TestRoom"
	# floor, ceiling, then the four walls
	_add_slab(room, Vector3(0, -ROOM_HALF.y, 0), Vector3(ROOM_HALF.x, 0.2, ROOM_HALF.z))
	_add_slab(room, Vector3(0, ROOM_HALF.y, 0), Vector3(ROOM_HALF.x, 0.2, ROOM_HALF.z))
	_add_slab(room, Vector3(-ROOM_HALF.x, 0, 0), Vector3(0.2, ROOM_HALF.y, ROOM_HALF.z))
	_add_slab(room, Vector3(ROOM_HALF.x, 0, 0), Vector3(0.2, ROOM_HALF.y, ROOM_HALF.z))
	_add_slab(room, Vector3(0, 0, -ROOM_HALF.z), Vector3(ROOM_HALF.x, ROOM_HALF.y, 0.2))
	_add_slab(room, Vector3(0, 0, ROOM_HALF.z), Vector3(ROOM_HALF.x, ROOM_HALF.y, 0.2))
	return room


func _add_slab(room: Node3D, centre: Vector3, half_extents: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = GameLayers.WORLD
	body.position = centre
	var shape := BoxShape3D.new()
	shape.size = half_extents * 2.0
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	room.add_child(body)


## Grappling is the game's main verb and there is no mode around it any more:
## moving and building are the same act, so a click anywhere leaves a line.
func _test_grappling_without_a_mode() -> void:
	var builder := _spider.web_builder
	builder.stop()
	check(not builder.building, "there is no build mode to be in")

	_spider.climb.release()
	_spider.global_position = Vector3(0, -ROOM_HALF.y + 0.6, 0)
	_spider.velocity = Vector3.ZERO
	# Clear the lines the section before strung across this room. Grappling at a
	# line gets you on it rather than laying another, and the pick is forgiving
	# about aim, so with those still up whether this click lays a line came down
	# to a few centimetres of where the crosshair happened to sit.
	for node in _spider.get_tree().get_nodes_in_group("silk_webs"):
		if is_instance_valid(node):
			node.queue_free()
	await run_frames(20)

	var lines_before := _silk_count()
	check(lines_before == 0, "no silk left over to aim at by mistake (%d)" % lines_before)
	_spider.view.face(Vector3.FORWARD)
	_spider.view.pitch = 0.0
	await run_frames(2)
	var started_at := _spider.global_position

	builder.place()
	check(_spider.climb.is_grappling(), "a click with no mode still grapples")
	for i in 120:
		if not _spider.climb.is_grappling():
			break
		await physics_frame
	await run_frames(2)

	check(_spider.global_position.distance_to(started_at) > 0.5,
		"the spider travelled there (%.2fm)"
		% _spider.global_position.distance_to(started_at))
	check(_silk_count() > lines_before,
		"and left a line behind it (%d -> %d)" % [lines_before, _silk_count()])
	check(builder.anchors.is_empty(),
		"with no anchor list to keep track of (%d)" % builder.anchors.size())


## A grapple goes much further than a scripted build run may span, and it has an
## end, and the end is the body's.
##
## It used to have no end at all — anywhere you could see — and the report back
## was that the game felt too long ranged, which is what happens when nothing is
## out of reach: there is no distance left for growing to close. A long grapple
## also has to stay quick, or a big reach only buys a longer commute, so this
## checks the distance, the cut-off and the time.
func _test_grappling_a_long_way() -> void:
	var builder := _spider.web_builder
	builder.stop()

	_spider.climb.release()
	_spider.global_position = Vector3(60, 0.8, 0)
	_spider.velocity = Vector3.ZERO

	var arm := _spider.stage().reach
	var tier_range := _spider.stage().anchor_range
	var silk := builder.silk_reach()
	# A landing pad, a wall near the end of what silk reaches, and another one
	# past it. Both far outside the room and far beyond what a build run spans.
	_add_slab(_room, Vector3(60, 0, 0), Vector3(3.0, 0.2, 3.0))
	_add_slab(_room, Vector3(60 + silk * 0.8, 3, 0), Vector3(0.4, 6.0, 6.0))
	_add_slab(_room, Vector3(60 + silk + 14.0, 3, 0), Vector3(0.4, 6.0, 6.0))
	await run_frames(34)

	check(silk > tier_range * 2.0,
		"silk reaches %.1fm, well past the %.1fm a build run may span"
		% [silk, tier_range])

	_spider.view.face(Vector3.RIGHT)
	_spider.view.pitch = 0.0
	await run_frames(2)

	builder._update_aim()
	var span := _spider.global_position.distance_to(builder.aim_point)
	check(builder.aim_valid, "a wall %.0fm away is still something to aim at" % span)
	check(span > tier_range * 2.0,
		"and it is far past this tier's own span limit (%.1fm vs %.1fm)"
		% [span, tier_range])
	check(span < silk + 1.0,
		"while inside what silk reaches (%.1fm of %.1fm)" % [span, silk])

	var started_at := _spider.global_position
	builder.place()
	check(_spider.climb.is_grappling(), "the grapple starts")

	var frames := 0
	for i in 600:
		if not _spider.climb.is_grappling():
			break
		frames += 1
		await physics_frame
	var seconds := float(frames) / 60.0
	check(not _spider.climb.is_grappling(), "and finishes")
	var travelled := _spider.global_position.distance_to(started_at)
	check(travelled > tier_range * 2.0,
		"the spider crossed %.1fm, far more than a build run would have allowed"
		% travelled)
	check(seconds < 2.5, "and it took %.2fs, not a commute" % seconds)
	# Reaching for things did not change — only going places did.
	check(arm < travelled * 0.2,
		"while handling things is still arm's length (%.1fm reach vs %.1fm travelled)"
		% [arm, travelled])

	# The far wall is the point of the limit. Nothing to aim at, and the readout
	# says how far short it fell rather than just refusing the click.
	_spider.climb.release()
	_spider.global_position = Vector3(60, 0.8, 0)
	_spider.velocity = Vector3.ZERO
	await run_frames(30)
	var lines := _silk_count()
	_spider.view.face(Vector3.LEFT)
	_spider.view.pitch = 0.0
	await run_frames(2)
	builder._update_aim()
	check(not builder.aim_valid, "there is nothing to grapple to behind you")
	check(builder.problem_text().contains("%.0fm" % silk),
		"and the readout names the reach (%s)" % builder.problem_text())
	# Clicking says so out loud rather than failing silently, which is what turns
	# a limit into somewhere to come back to when you are bigger.
	var said: Array[String] = []
	var listen := func(text: String) -> void: said.append(text)
	builder.notice.connect(listen)
	builder.place()
	await run_frames(4)
	builder.notice.disconnect(listen)
	check(not _spider.climb.is_grappling(), "so the click takes you nowhere")
	check(_silk_count() == lines,
		"and leaves no line behind (%d)" % _silk_count())
	var told := false
	for text in said:
		if text.contains("%.0fm" % silk):
			told = true
	check(told, "while telling you why (%s)" % ", ".join(said))


## Silk is the road network: you can stand on any line, it is quicker under
## foot than the floor, and pointing at one and grappling puts you on it.
func _test_lines_are_roads() -> void:
	var builder := _spider.web_builder
	builder.stop()
	_spider.climb.release()
	_spider.global_position = Vector3(0, -ROOM_HALF.y + 0.6, 0)
	_spider.velocity = Vector3.ZERO
	await run_frames(20)

	# Clear the silk the earlier tests strung up. The pick takes whichever line
	# is nearest the crosshair, so leaving five of them about makes this a test
	# of which one happened to be closest rather than of the pick itself.
	for node in _spider.get_tree().get_nodes_in_group("silk_webs"):
		if is_instance_valid(node):
			node.queue_free()
	await physics_frame
	await process_frame
	check(_silk_count() == 0, "no silk left over from earlier (%d)" % _silk_count())

	# A plain line across the room, of the sort grappling leaves behind.
	var pattern: WebPattern = null
	for candidate in builder.patterns:
		if candidate.id == "frame_line":
			pattern = candidate
	if not check(pattern != null, "a frame line to lay"):
		return
	var eye := -ROOM_HALF.y + 0.6
	var a := Vector3(2.0, eye, -2.0)
	var b := Vector3(2.0, eye, 2.0)
	var line := WebStrand.spin(pattern, a, b, 1.0)
	if not check(line != null, "the line goes up"):
		return
	line.place_in(_room)
	await physics_frame

	check(not pattern.walkable,
		"it is not a bridge — nothing about it was built to be walked on")
	var walkway := line.get_node_or_null("Walkway")
	check(walkway != null, "and yet it has something to stand on")
	if walkway != null:
		check((walkway.collision_layer & GameLayers.WEB_WALK) != 0,
			"on the silk layer, so prey still goes straight through")

	# Standing on it is quicker than standing on the floor.
	_spider.climb.on_silk = false
	var ground_speed := _spider.climb._surface_speed(false)
	_spider.climb.on_silk = true
	var silk_speed := _spider.climb._surface_speed(false)
	_spider.climb.on_silk = false
	check(silk_speed > ground_speed,
		"and silk is quicker underfoot (%.2f vs %.2f)" % [silk_speed, ground_speed])

	# Point at it and grapple: you get on the line rather than stringing a new
	# one to it.
	#
	# Aimed at the line rather than levelled at it. The crosshair's ray goes
	# through the camera's pivot, which sits above the spider, so looking dead
	# level in third person puts the cross *over* a line at your own height — it
	# used to pick the line anyway, because the aim was taken from the spider and
	# the cross was a decoration that happened to be near it.
	var on_line := (a + b) * 0.5
	var toward := on_line - _spider.view.aim_pivot()
	_spider.view.face(Vector3(toward.x, 0.0, toward.z))
	_spider.view.pitch = atan2(toward.y, maxf(Vector2(toward.x, toward.z).length(), 0.0001))
	await run_frames(2)
	builder._update_aim()
	var aimed := builder.aimed_line()
	check(aimed == line, "the crosshair picks the line out")

	# Silk is sticky. Landing on a line leaves you standing on it, not railed
	# along it, and it holds you there until you jump off — a spider does not
	# fall off its own thread, and it does not get grabbed into a ride it never
	# asked for either.
	_spider.climb.release()
	_spider.global_position = Geometry3D.get_closest_point_to_segment(
		_spider.global_position, line.point_a, line.point_b) + Vector3.UP * 0.1
	_spider.velocity = Vector3.ZERO
	var stuck: bool = await wait_until(func() -> bool:
		return _spider.climb.is_attached() and _spider.climb.on_silk, 90)
	check(stuck, "dropping onto a line sticks you to it")
	check(not _spider.climb.is_riding(),
		"and does not grab you into a ride you never asked for")
	if stuck:
		var held := _spider.global_position
		await run_frames(40)
		check(_spider.climb.on_silk, "still on it a moment later")
		check(_spider.global_position.distance_to(held) < 0.5,
			"without sliding off (%.2fm)"
			% _spider.global_position.distance_to(held))

		# Facing across the line and pushing forward should get you nowhere: a
		# thread has one direction, and that is not it. Checking this on its own
		# would pass just as well if a thread could not be walked at all, so the
		# along-the-line case is checked straight after.
		var axis := (line.point_b - line.point_a).normalized()
		var sideways := axis.cross(Vector3.UP).normalized()
		_spider.view.face(sideways)
		_spider.view.pitch = 0.0
		await run_frames(4)
		var from := _spider.global_position
		await _walk_forward(30)
		var moved := _spider.global_position - from
		var across := (moved - axis * moved.dot(axis)).length()
		check(_spider.climb.on_silk, "pushing across it does not shake you off")
		check(across < 0.25, "and you stay over the thread (%.2fm off it)" % across)

		# Along it is the one direction it has, and you walk it under your own
		# power rather than being fed down it.
		_spider.view.face(axis)
		_spider.view.pitch = 0.0
		await run_frames(4)
		from = _spider.global_position
		# The body's up, frame by frame, while it walks. A tightrope's collider
		# is a box a few centimetres across: the surface probe used to find its
		# top face one frame and a side face the next, and the body rolled a
		# right angle between the two, every few frames, the whole way along.
		# That was the jank. An up taken from the thread's own axis cannot flip,
		# because the axis does not.
		var lurch := 0.0
		var leaning := 0.0
		var previous := _spider.climb.body_up()
		Input.action_press("move_forward")
		for i in 20:
			await physics_frame
			var now := _spider.climb.body_up()
			lurch = maxf(lurch, rad_to_deg(previous.angle_to(now)))
			leaning = maxf(leaning, absf(now.dot(axis)))
			previous = now
		Input.action_release("move_forward")
		await run_frames(2)
		moved = _spider.global_position - from
		check(absf(moved.dot(axis)) > 0.25,
			"and it walks you along it (%.2fm)" % absf(moved.dot(axis)))
		check((moved - axis * moved.dot(axis)).length() < 0.25,
			"still over the thread after walking it")
		check(_spider.climb.on_silk and not _spider.climb.is_riding(),
			"under your own power, not on a ride")
		check(lurch < 8.0,
			"and the walk is smooth — no roll worse than %.1f° in a frame" % lurch)
		check(leaning < 0.2,
			"with the body square to the thread all the way (%.3f along it)"
			% leaning)

		# And the way off is the jump.
		Input.action_press("move_jump")
		await run_frames(3)
		Input.action_release("move_jump")
		await run_frames(2)
		check(not _spider.climb.is_attached(), "and a jump is what takes you off")
		check(not _spider.climb.on_silk, "leaving the silk behind")

	_spider.climb.release()
	# Further off than the line's own thickness, and to one side, so the grapple
	# comes in across the thread rather than creeping along its edge. Arrival
	# stops within half a body height of the target, and against a plank a few
	# centimetres thick that is the difference between landing on it and landing
	# beside it.
	_spider.global_position = Vector3(-2.0, -ROOM_HALF.y + 0.6, -1.0)
	_spider.velocity = Vector3.ZERO
	await run_frames(20)
	# At the line, not level with it — see the pick above.
	var at_line := (line.point_a + line.point_b) * 0.5 - _spider.view.aim_pivot()
	_spider.view.face(Vector3(at_line.x, 0.0, at_line.z))
	_spider.view.pitch = atan2(at_line.y,
		maxf(Vector2(at_line.x, at_line.z).length(), 0.0001))
	await run_frames(2)
	builder._update_aim()

	var lines_before := _silk_count()
	builder.place()
	var arrived: bool = await wait_until(func() -> bool:
		return _spider.climb.on_silk, 180)
	check(arrived, "and grappling onto it puts you on it")
	check(_silk_count() == lines_before,
		"without spinning a second line to get there (%d)" % _silk_count())
	# The click was aimed at a line, not at a ride. Nothing but the key starts
	# one — a grapple that merely passed near silk must not take the controls.
	check(not _spider.climb.is_riding(),
		"and leaves the riding to you")
	check(_spider.climb.toggle_ride(), "which the key still does")
	check(_spider.climb.is_riding(), "and now it is a ride")

	_spider.climb.toggle_ride()
	line.queue_free()
	await physics_frame
	await process_frame


## The other grapple. Left mouse lays a line from your feet to wherever you point
## and stands you on it, and that is all: getting there is walking the line, which
## is quick, and as quick up it as down it. The pull is one key away, so the two
## can be played back to back.
func _test_the_line_grapple() -> void:
	var builder := _spider.web_builder
	var climb := _spider.climb
	builder.stop()
	climb.release()
	for node in _spider.get_tree().get_nodes_in_group("silk_webs"):
		if is_instance_valid(node):
			node.queue_free()
	_spider.global_position = Vector3(0, -ROOM_HALF.y + 0.6, 0)
	_spider.velocity = Vector3.ZERO
	await run_frames(30)
	check(climb.is_attached() and not climb.on_silk, "standing on the floor to start")
	var floor_speed := climb._surface_speed(false)

	check(not climb.shoots_lines(), "the pull is the grapple you start with")
	climb.toggle_grapple_style()
	check(climb.shoots_lines(), "and G swaps it for the line")

	# High on the far wall, so the line climbs.
	var target := Vector3(0.0, 0.2, -ROOM_HALF.z)
	var toward := target - _spider.view.aim_pivot()
	_spider.view.face(Vector3(toward.x, 0.0, toward.z))
	_spider.view.pitch = atan2(toward.y, Vector2(toward.x, toward.z).length())
	await run_frames(2)
	var started_at := _spider.global_position
	var before := _silk_count()
	builder.place()
	await run_frames(3)
	check(not climb.is_grappling(), "a click does not haul you anywhere")
	check(_silk_count() == before + 1,
		"it lays one line (%d -> %d)" % [before, _silk_count()])
	var line := climb.holding_line()
	if not check(line != null and climb.on_silk, "and stands you on it"):
		return
	check(_spider.global_position.distance_to(started_at) < 0.3,
		"right where you were (%.2fm away)" % _spider.global_position.distance_to(started_at))
	# The far wall is a slab 0.2 either side of the room's edge, so its face is
	# that far in.
	check(absf(line.point_b.z - (-ROOM_HALF.z + 0.2)) < 0.05,
		"out to the wall it was pointed at (%.2f)" % line.point_b.z)
	check(line.point_a.y < started_at.y,
		"from your feet (%.2f, the body at %.2f)" % [line.point_a.y, started_at.y])
	check(builder.lines().has(line), "and it is one of your three lines")

	var on_line := climb._surface_speed(false)
	check(is_equal_approx(on_line, _spider.speed * climb.line_speed),
		"walking a line is %.1f times a walk (%.2f, the floor %.2f)"
		% [climb.line_speed, on_line, floor_speed])

	# Up it, under your own power, and fast.
	var axis := (line.point_b - line.point_a).normalized()
	_spider.view.face(Vector3(axis.x, 0.0, axis.z))
	_spider.view.pitch = 0.0
	await run_frames(2)
	var from := _spider.global_position
	Input.action_press("move_forward")
	await run_frames(16)
	var up_speed := climb.tangent_velocity.length()
	Input.action_release("move_forward")
	await run_frames(2)
	var climbed := (_spider.global_position - from).dot(axis)
	check(climbed > floor_speed * 16.0 / 60.0 * 1.8,
		"walking it takes you up it fast (%.2fm, a walk would be %.2fm)"
		% [climbed, floor_speed * 16.0 / 60.0])
	check(climb.holding_line() == line, "still on the line")

	# Down it, at the same speed: the slope makes no difference.
	_spider.view.face(Vector3(-axis.x, 0.0, -axis.z))
	await run_frames(2)
	Input.action_press("move_forward")
	await run_frames(10)
	var down_speed := climb.tangent_velocity.length()
	Input.action_release("move_forward")
	await run_frames(2)
	check(absf(up_speed - down_speed) < on_line * 0.15,
		"and as quick down it as up it (%.2f up, %.2f down)" % [up_speed, down_speed])

	# A jump steps off it.
	Input.action_press("move_jump")
	await run_frames(3)
	Input.action_release("move_jump")
	await run_frames(2)
	check(not climb.on_silk, "and a jump steps off it")

	# Fired from the air, the line starts where you are and you are on it: silk
	# is sticky, and a line that left you falling would be no line at all.
	check(not climb.is_attached(), "in the air after the jump")
	_spider.view.face(Vector3(toward.x, 0.0, toward.z))
	_spider.view.pitch = atan2(toward.y, Vector2(toward.x, toward.z).length())
	builder.place()
	await run_frames(10)
	var caught := climb.holding_line()
	check(caught != null and caught != line and climb.on_silk,
		"a line fired from the air catches you on it")
	check(builder.lines().size() == 2, "and that is two lines up (%d)" % builder.lines().size())

	climb.toggle_grapple_style()
	check(not climb.shoots_lines(), "G again gives you the pull back")
	climb.release()
	await run_frames(30)
	_spider.global_position = Vector3(0, -ROOM_HALF.y + 0.6, 0)
	_spider.velocity = Vector3.ZERO
	await run_frames(20)
	_spider.view.face(Vector3(toward.x, 0.0, toward.z))
	_spider.view.pitch = atan2(toward.y, Vector2(toward.x, toward.z).length())
	await run_frames(2)
	builder.place()
	check(climb.is_grappling(), "which hauls you over, as it always did")
	for i in 120:
		if not climb.is_grappling():
			break
		await physics_frame
	for node in _spider.get_tree().get_nodes_in_group("silk_webs"):
		if is_instance_valid(node):
			node.queue_free()
	climb.release()
	await run_frames(20)


## The body's up is slerped towards a target every frame, and Vector3.slerp
## builds its rotation about the cross product of the two — so it refuses an
## axis that is not unit length. Physics hands back surface normals that are a
## shade under unit, 0.999263 among them, and that value used to become the
## body's up unexamined. One sloppy normal from the world was then an error
## every single frame until the spider next touched something else.
func _test_sloppy_normals() -> void:
	release_all()
	_spider.global_position = Vector3(0, -ROOM_HALF.y + 0.6, 0)
	_spider.velocity = Vector3.ZERO
	await run_frames(15)

	# The exact value the engine handed back when this turned up in play.
	var sloppy := Vector3(0.0, 0.0, 0.999263)
	check(not sloppy.is_normalized(),
		"a normal a shade under unit length (%.6f)" % sloppy.length())

	_spider.climb._adopt_surface(sloppy)
	check(_spider.climb.body_up().is_normalized(),
		"is cleaned up before it becomes the body's up (%.6f)"
		% _spider.climb.body_up().length())
	check(_spider.climb.surface_normal.is_normalized(),
		"and so is the surface normal (%.6f)" % _spider.climb.surface_normal.length())

	# And the blend itself has to cope, because that is where it threw. Airborne
	# in the middle of the room, which is the branch the stack trace named, and
	# far enough from anything that it stays airborne while the blend runs.
	_spider.climb._current_up = sloppy
	_spider.global_position = Vector3.ZERO
	_spider.velocity = Vector3.ZERO
	_spider.climb.release()
	await run_frames(5)
	check(_spider.climb.body_up().is_normalized(),
		"and a sloppy up set behind that guard is fixed by the blend (%.6f)"
		% _spider.climb.body_up().length())

	release_all()
	_spider.climb._current_up = Vector3.UP
	_spider.global_position = Vector3(0, -ROOM_HALF.y + 0.6, 0)
	_spider.velocity = Vector3.ZERO
	await run_frames(20)


## Holds W for a while and lets go.
func _walk_forward(count: int) -> void:
	Input.action_press("move_forward")
	await run_frames(count)
	Input.action_release("move_forward")
	await run_frames(2)


func _silk_count() -> int:
	var total := 0
	for node in _spider.get_tree().get_nodes_in_group("silk_webs"):
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			total += 1
	return total
