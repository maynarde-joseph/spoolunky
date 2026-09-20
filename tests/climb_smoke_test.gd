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
	_spider.climb.notice.connect(func(text: String) -> void: print("        (%s)" % text))

	await _test_floor()
	await _test_wall()
	await _test_ceiling()
	await _test_dragline()
	await _test_letting_go()
	await _test_leaping_off_a_wall()

	_release_all()
	_silence(_spider)
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


## A footstep still playing when the tree is torn down shows up as a leaked
## audio stream at exit, which is just noise in the test output.
func _silence(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	var player := node as AudioStreamPlayer3D
	if player != null:
		player.stop()
	for child in node.get_children():
		_silence(child)


func _release_all() -> void:
	for action in ["move_forward", "move_back", "move_jump", "move_crouch", "web_cancel"]:
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
