extends SceneTree

## Headless test for wall and ceiling climbing and the dragline.
##
##     godot --headless --script res://tests/climb_smoke_test.gd
##
## Builds a plain box room, drops a spider into it and walks it up a wall,
## across the ceiling, down on a thread and back to the floor, checking the
## body really does reorient onto each surface along the way.

const ROOM_HALF := Vector3(3.0, 1.6, 3.0)

var _checks := 0
var _failures := 0
var _room: Node3D
var _spider: SpiderPlayer


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_room = _build_room()
	root.add_child(_room)
	current_scene = _room

	_spider = load("res://game/player/spider.tscn").instantiate() as SpiderPlayer
	_room.add_child(_spider)
	_spider.global_position = Vector3(0, -ROOM_HALF.y + 0.6, 0)
	await physics_frame
	_spider.require_captured_mouse = false
	# These suites assert that things cost silk, so the sandbox switch is off.
	_spider.silk.unlimited = false
	# Footsteps are not what this test is about, and a sound still being mixed
	# when the tree is torn down shows up as a leak at exit.
	var audio := _spider.get_node_or_null("Player Audios")
	if audio != null:
		audio.free()
	_spider.climb.notice.connect(func(text: String) -> void: print("        (%s)" % text))

	await _test_floor()
	await _test_strafing()
	await _test_wall()
	await _test_ceiling()
	await _test_dragline()
	await _test_letting_go()
	await _test_leaping_off_a_wall()
	await _test_ziplining()
	await _test_grappling()
	await _test_grappling_without_a_mode()
	await _test_grappling_a_long_way()
	await _test_lines_are_roads()

	_release_all()
	current_scene = null
	_spider = null
	_room.free()
	_room = null
	# Let the freed nodes release what they were holding — including any audio
	# still being mixed — before we pull the plug.
	await process_frame
	await process_frame
	print("")
	if _failures == 0:
		print("%d checks passed" % _checks)
	else:
		print("%d of %d checks FAILED" % [_failures, _checks])
	quit(1 if _failures > 0 else 0)


func _test_floor() -> void:
	await _run_frames(40)
	_check(_spider.climb.is_attached(), "the spider settles onto the floor")
	_check(_spider.climb.surface_normal.dot(Vector3.UP) > 0.95,
		"standing the right way up (normal %.2v)" % _spider.climb.surface_normal)
	_check(not _spider.climb.on_steep_surface(), "the floor is not a steep surface")
	_check(_spider.up_direction.dot(Vector3.UP) > 0.95, "the body's up matches the floor")


## Strafing has to mean the same thing the camera means by it, on every surface.
## The climb component drives the body itself rather than going through the
## template's mover, so nothing else checks that the two agree about which way
## is right — and a mirrored strafe is the kind of bug you feel long before you
## can name it.
func _test_strafing() -> void:
	_release_all()
	_spider.global_position = Vector3(0, -ROOM_HALF.y + 0.6, 0)
	_spider.velocity = Vector3.ZERO
	# Looking down -Z, so "right" is +X by the usual right-handed reckoning,
	# and that is also what the camera rig reports.
	_spider.view.face(Vector3(0, 0, -1))
	_spider.view.pitch = 0.0
	await _run_frames(20)
	_check(_spider.view.right().dot(Vector3.RIGHT) > 0.95,
		"the camera agrees right is +X (%.2v)" % _spider.view.right())

	var moved := await _strafe("move_right")
	_check(moved.dot(_spider.view.right()) > 0.05,
		"D goes the way the camera calls right (%.2v)" % moved)
	moved = await _strafe("move_left")
	_check(moved.dot(_spider.view.right()) < -0.05,
		"and A goes the other way (%.2v)" % moved)
	moved = await _strafe("move_forward")
	_check(moved.dot(_spider.view.forward()) > 0.05,
		"W goes where you are looking (%.2v)" % moved)


## Holds one movement key and reports how far the spider actually went.
func _strafe(action: String) -> Vector3:
	_spider.velocity = Vector3.ZERO
	await _run_frames(6)
	var before := _spider.global_position
	Input.action_press(action)
	await _run_frames(25)
	Input.action_release(action)
	await _run_frames(2)
	return _spider.global_position - before


func _test_wall() -> void:
	# Face the -X wall and walk into it.
	_spider.climb.face(Vector3.LEFT)
	await _run_frames(2)
	var height_before := _spider.global_position.y
	Input.action_press("move_forward")
	await _run_frames(90)

	_check(_spider.climb.is_attached(), "still attached after walking into the wall")
	_check(_spider.climb.surface_normal.dot(Vector3.RIGHT) > 0.9,
		"the spider is on the wall (normal %.2v)" % _spider.climb.surface_normal)
	_check(_spider.climb.on_steep_surface(), "and knows the wall is steep")
	_check(_spider.global_position.y > height_before + 0.3,
		"it climbed (%.2f -> %.2f)" % [height_before, _spider.global_position.y])
	_check(_spider.global_basis.y.dot(Vector3.RIGHT) > 0.8,
		"the body rolled onto the wall")
	_check(_spider.global_basis.y.dot(_spider.climb.body_up()) > 0.8,
		"and the camera came with it")


func _test_ceiling() -> void:
	# Keep walking up; the wall runs into the ceiling.
	await _run_frames(150)
	_check(_spider.climb.surface_normal.dot(Vector3.DOWN) > 0.9,
		"carried on over onto the ceiling (normal %.2v)" % _spider.climb.surface_normal)
	_check(_spider.global_position.y > ROOM_HALF.y - 0.5, "and is up at ceiling height")
	# Movement is camera-relative now, so turn to look along the ceiling rather
	# than back at the wall that was just climbed.
	_spider.climb.face(Vector3.RIGHT)
	var across_before := _spider.global_position.x
	await _run_frames(60)
	_check(_spider.global_position.x > across_before + 0.2,
		"it walks along the ceiling upside down (%.2f -> %.2f)"
		% [across_before, _spider.global_position.x])
	_check(_spider.global_basis.y.dot(Vector3.DOWN) > 0.8, "hanging upside down")
	Input.action_release("move_forward")
	await _run_frames(20)


func _test_dragline() -> void:
	var silk_before := _spider.silk.current
	var ceiling_height := _spider.global_position.y
	Input.action_press("move_crouch")
	await _run_frames(6)

	_check(_spider.climb.is_hanging(), "Ctrl on the ceiling drops the spider onto a line")
	_check(_spider.climb.line_anchor.y > ceiling_height, "the line is anchored above it")
	_check(_spider.silk.current < silk_before, "the line costs silk")

	var length_before := _spider.climb.line_length
	await _run_frames(60)
	_check(_spider.climb.line_length > length_before + 0.2,
		"holding Ctrl pays the line out (%.2f -> %.2f)"
		% [length_before, _spider.climb.line_length])
	_check(_spider.global_position.y < ceiling_height - 0.2,
		"and the spider descends on it")
	_check(_spider.global_position.distance_to(_spider.climb.line_anchor)
		<= _spider.climb.line_length + 0.15, "it never hangs below the line it has spun")
	Input.action_release("move_crouch")

	# Reel back up.
	var down_at := _spider.global_position.y
	var silk_at_bottom := _spider.silk.current
	Input.action_press("move_jump")
	await _run_frames(50)
	_check(_spider.global_position.y > down_at + 0.1, "Space climbs back up the line")
	_check(_spider.silk.current > silk_at_bottom, "reeling the line in recovers silk")
	Input.action_release("move_jump")
	await _run_frames(5)


func _test_letting_go() -> void:
	if not _check(_spider.climb.is_hanging(), "still on the line"):
		return
	var drop_from := _spider.global_position.y
	Input.action_press("web_cancel")
	await _run_frames(2)
	Input.action_release("web_cancel")
	_check(not _spider.climb.is_hanging(), "right mouse lets go of the line")
	await _run_frames(60)
	_check(_spider.global_position.y < drop_from, "and the spider drops")
	await _run_frames(90)
	_check(_spider.climb.is_attached(), "it catches whatever it lands on")


func _test_leaping_off_a_wall() -> void:
	# Put it back on a known wall rather than wherever it happened to land.
	_spider.climb.release()
	_spider.global_position = Vector3(-ROOM_HALF.x + 0.35, 0.0, 0.0)
	_spider.velocity = Vector3.ZERO
	await _run_frames(30)
	if not _check(_spider.climb.on_steep_surface(),
			"back on the wall to jump from (normal %.2v)" % _spider.climb.surface_normal):
		return

	var wall_normal := _spider.climb.surface_normal
	var distance_before := _spider.global_position.x
	Input.action_press("move_jump")
	await _run_frames(3)
	Input.action_release("move_jump")
	_check(not _spider.climb.is_attached(), "jumping lets go of the wall")
	await _run_frames(12)
	var travelled := (_spider.global_position.x - distance_before) * wall_normal.x
	_check(travelled > 0.05, "and pushes off away from it (%.2fm)" % travelled)


## Stringing a line across the room and riding it: the ride should pick up
## speed going downhill and fling the spider off the far end.
func _test_ziplining() -> void:
	_spider.climb.release()
	_spider.global_position = Vector3(-ROOM_HALF.x + 0.6, ROOM_HALF.y - 0.5, 0.0)
	_spider.velocity = Vector3.ZERO
	# Bridges unlock at the second size tier, and build mode quietly falls back
	# to something spinnable if you have not got there.
	_spider.growth.feed(120.0, "test")
	_spider.silk.refill(_spider.silk.maximum)
	await _run_frames(10)

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
	await _run_frames(2)

	var bridge: WebStrand = null
	for node in _spider.get_tree().get_nodes_in_group("silk_webs"):
		var strand := node as WebStrand
		if strand != null and strand.pattern.id == "silk_bridge":
			bridge = strand
	if not _check(bridge != null, "a line to ride"):
		return
	_check(bridge.pattern.shape == WebPattern.Shape.STRAND,
		"and it is a strand, which is all riding asks for now")

	_spider.global_position = top + Vector3(0.1, -0.1, 0)
	_spider.velocity = Vector3.ZERO
	await _run_frames(2)
	_check(_spider.climb.toggle_ride(), "the spider clips onto the line")
	_check(_spider.climb.is_riding(), "and is riding it")

	var started_at := _spider.global_position
	await _run_frames(20)
	_check(_spider.climb.ride_velocity() > 0.3,
		"it picks up speed going downhill (%.2f m/s)" % _spider.climb.ride_velocity())
	_check(_spider.global_position.distance_to(started_at) > 0.2, "and travels along the line")
	_check(_spider.global_position.y < started_at.y, "downwards, as gravity intends")

	# Ride it to the end and get thrown off.
	var top_speed := 0.0
	for i in 200:
		top_speed = maxf(top_speed, _spider.climb.ride_velocity())
		if not _spider.climb.is_riding():
			break
		await physics_frame
	_check(not _spider.climb.is_riding(), "the far end throws it off the line")
	_check(top_speed > 1.0, "after building real speed (%.2f m/s)" % top_speed)
	_check(_spider.velocity.length() > 0.5,
		"and it carries that speed off the end (%.2f m/s)" % _spider.velocity.length())

	# Let go part way along instead.
	_spider.climb.release()
	_spider.global_position = top + Vector3(0.1, -0.1, 0)
	_spider.velocity = Vector3.ZERO
	await _run_frames(4)
	_spider.climb.toggle_ride()
	await _run_frames(25)
	if _check(_spider.climb.is_riding(), "back on the line"):
		_spider.climb.toggle_ride()
		_check(not _spider.climb.is_riding(), "and can let go part way along")
		_check(_spider.velocity.y > 0.0, "with a kick to clear the edge")

	_check(_spider.view.third_person, "the camera starts behind the spider")
	_spider.view.toggle_mode()
	_check(not _spider.view.third_person, "and can be brought inside its head")
	_spider.view.toggle_mode()


## Placing an anchor is a journey: the spider hauls itself to the spot and
## leaves silk behind it, rather than pointing at it from across the room.
func _test_grappling() -> void:
	_spider.climb.release()
	_spider.global_position = Vector3(0, -ROOM_HALF.y + 0.6, 0)
	_spider.velocity = Vector3.ZERO
	_spider.silk.refill(_spider.silk.maximum)
	await _run_frames(20)

	var builder := _spider.web_builder
	for i in builder.patterns.size():
		if builder.patterns[i].id == "sheet_web":
			builder.pattern_index = i
	builder.start()

	# Look at the far wall and grapple to it.
	_spider.view.face(Vector3.RIGHT)
	_spider.view.pitch = 0.0
	await _run_frames(2)
	var started_at := _spider.global_position
	builder.place()
	_check(_spider.climb.is_grappling(), "clicking an anchor starts a grapple")

	for i in 120:
		if not _spider.climb.is_grappling():
			break
		await physics_frame
	_check(not _spider.climb.is_grappling(), "the grapple finishes")
	_check(_spider.global_position.distance_to(started_at) > 0.5,
		"the spider travelled to its anchor (%.2fm)"
		% _spider.global_position.distance_to(started_at))
	_check(builder.anchors.size() == 1, "and the anchor landed there")

	# A second anchor should leave a line between the two.
	var webs_before := 0
	for node in _spider.get_tree().get_nodes_in_group("silk_webs"):
		webs_before += 1
	var silk_before := _spider.silk.current
	_spider.view.face(Vector3.FORWARD)
	await _run_frames(2)
	builder.place()
	for i in 120:
		if not _spider.climb.is_grappling():
			break
		await physics_frame
	await _run_frames(2)
	var webs_after := 0
	for node in _spider.get_tree().get_nodes_in_group("silk_webs"):
		webs_after += 1
	_check(builder.anchors.size() == 2, "a second anchor lands too")
	_check(webs_after > webs_before, "with a line dragged between them")
	_check(_spider.silk.current < silk_before, "which is what the silk went on")
	builder.stop()


# --- scaffolding --------------------------------------------------------

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


func _run_frames(count: int) -> void:
	for i in count:
		await physics_frame


## Grappling is the game's main verb and there is no mode around it any more:
## moving and building are the same act, so a click anywhere leaves a line.
func _test_grappling_without_a_mode() -> void:
	var builder := _spider.web_builder
	builder.stop()
	_check(not builder.building, "there is no build mode to be in")

	_spider.climb.release()
	_spider.global_position = Vector3(0, -ROOM_HALF.y + 0.6, 0)
	_spider.velocity = Vector3.ZERO
	_spider.silk.refill(_spider.silk.maximum)
	await _run_frames(20)

	var lines_before := _silk_count()
	var silk_before := _spider.silk.current
	_spider.view.face(Vector3.FORWARD)
	_spider.view.pitch = 0.0
	await _run_frames(2)
	var started_at := _spider.global_position

	builder.place()
	_check(_spider.climb.is_grappling(), "a click with no mode still grapples")
	for i in 120:
		if not _spider.climb.is_grappling():
			break
		await physics_frame
	await _run_frames(2)

	_check(_spider.global_position.distance_to(started_at) > 0.5,
		"the spider travelled there (%.2fm)"
		% _spider.global_position.distance_to(started_at))
	_check(_silk_count() > lines_before,
		"and left a line behind it (%d -> %d)" % [lines_before, _silk_count()])
	_check(_spider.silk.current < silk_before, "which is what the silk went on")
	_check(builder.anchors.is_empty(),
		"with no anchor list to keep track of (%d)" % builder.anchors.size())


## Reach is not a size tier any more. A spiderling can go anywhere it can see,
## and a long grapple has to stay quick or unlimited range just buys a longer
## commute — so this checks both the distance and the time.
func _test_grappling_a_long_way() -> void:
	var builder := _spider.web_builder
	builder.stop()

	# A landing pad and a wall to aim at, far outside the room and far beyond
	# anything the tier would have allowed.
	_add_slab(_room, Vector3(60, 0, 0), Vector3(3.0, 0.2, 3.0))
	_add_slab(_room, Vector3(100, 3, 0), Vector3(0.4, 6.0, 6.0))
	await _run_frames(4)

	_spider.climb.release()
	_spider.global_position = Vector3(60, 0.8, 0)
	_spider.velocity = Vector3.ZERO
	_spider.silk.refill(_spider.silk.maximum)
	await _run_frames(30)

	var reach := _spider.stage().reach
	var tier_range := _spider.stage().anchor_range
	_spider.view.face(Vector3.RIGHT)
	_spider.view.pitch = 0.0
	await _run_frames(2)

	builder._update_aim()
	var span := _spider.global_position.distance_to(builder.aim_point)
	_check(builder.aim_valid, "a wall %.0fm away is still something to aim at" % span)
	_check(span > tier_range * 3.0,
		"and it is far past this tier's own reach (%.1fm vs %.1fm)" % [span, tier_range])

	var started_at := _spider.global_position
	builder.place()
	_check(_spider.climb.is_grappling(), "the grapple starts anyway")

	var frames := 0
	for i in 600:
		if not _spider.climb.is_grappling():
			break
		frames += 1
		await physics_frame
	var seconds := float(frames) / 60.0
	_check(not _spider.climb.is_grappling(), "and finishes")
	var travelled := _spider.global_position.distance_to(started_at)
	_check(travelled > tier_range * 3.0,
		"the spider crossed %.1fm, far more than the tier allowed" % travelled)
	_check(seconds < 2.5, "and it took %.2fs, not a commute" % seconds)
	# Reaching for things did not change — only going places did.
	_check(reach < travelled * 0.2,
		"while handling things is still arm's length (%.1fm reach vs %.1fm travelled)"
		% [reach, travelled])


## Silk is the road network: you can stand on any line, it is quicker under
## foot than the floor, and pointing at one and grappling puts you on it.
func _test_lines_are_roads() -> void:
	var builder := _spider.web_builder
	builder.stop()
	_spider.climb.release()
	_spider.silk.refill(_spider.silk.maximum)
	_spider.global_position = Vector3(0, -ROOM_HALF.y + 0.6, 0)
	_spider.velocity = Vector3.ZERO
	await _run_frames(20)

	# Clear the silk the earlier tests strung up. The pick takes whichever line
	# is nearest the crosshair, so leaving five of them about makes this a test
	# of which one happened to be closest rather than of the pick itself.
	for node in _spider.get_tree().get_nodes_in_group("silk_webs"):
		if is_instance_valid(node):
			node.queue_free()
	await physics_frame
	await process_frame
	_check(_silk_count() == 0, "no silk left over from earlier (%d)" % _silk_count())

	# A plain line across the room, of the sort grappling leaves behind.
	var pattern: WebPattern = null
	for candidate in builder.patterns:
		if candidate.id == "frame_line":
			pattern = candidate
	if not _check(pattern != null, "a frame line to lay"):
		return
	var eye := -ROOM_HALF.y + 0.6
	var a := Vector3(2.0, eye, -2.0)
	var b := Vector3(2.0, eye, 2.0)
	var line := WebStrand.spin(pattern, a, b, 1.0)
	if not _check(line != null, "the line goes up"):
		return
	line.place_in(_room)
	await physics_frame

	_check(not pattern.walkable,
		"it is not a bridge — nothing about it was built to be walked on")
	var walkway := line.get_node_or_null("Walkway")
	_check(walkway != null, "and yet it has something to stand on")
	if walkway != null:
		_check((walkway.collision_layer & GameLayers.WEB_WALK) != 0,
			"on the silk layer, so prey still goes straight through")

	# Standing on it is quicker than standing on the floor.
	_spider.climb.on_silk = false
	var ground_speed := _spider.climb._surface_speed(false)
	_spider.climb.on_silk = true
	var silk_speed := _spider.climb._surface_speed(false)
	_spider.climb.on_silk = false
	_check(silk_speed > ground_speed,
		"and silk is quicker underfoot (%.2f vs %.2f)" % [silk_speed, ground_speed])

	# Point at it and grapple: you get on the line rather than stringing a new
	# one to it.
	_spider.view.face(Vector3.RIGHT)
	_spider.view.pitch = 0.0
	await _run_frames(2)
	builder._update_aim()
	var aimed := builder.aimed_line()
	_check(aimed == line, "the crosshair picks the line out")

	var lines_before := _silk_count()
	builder.place()
	for i in 180:
		if _spider.climb.is_riding():
			break
		await physics_frame
	_check(_spider.climb.is_riding(), "and grappling onto it starts a ride")
	_check(_silk_count() == lines_before,
		"without spinning a second line to get there (%d)" % _silk_count())

	_spider.climb.toggle_ride()
	line.queue_free()
	await physics_frame
	await process_frame


func _silk_count() -> int:
	var total := 0
	for node in _spider.get_tree().get_nodes_in_group("silk_webs"):
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			total += 1
	return total


func _release_all() -> void:
	for action in ["move_forward", "move_backward", "move_left", "move_right",
			"move_jump", "move_crouch", "web_cancel"]:
		if InputMap.has_action(action) and Input.is_action_pressed(action):
			Input.action_release(action)


func _check(condition: bool, message: String) -> bool:
	_checks += 1
	if condition:
		print("  ok    %s" % message)
	else:
		_failures += 1
		print("  FAIL  %s" % message)
	return condition
