extends TestSuite

## Headless check on how the spider gets about: walking, climbing whatever it
## walks into, jumping, and the grapple — and that nothing else is left. There is
## no hanging from silk any more, no dragline and no zip line.
##
##     godot --headless --path . --script res://tests/movement_smoke_test.gd

var _room: Node3D
var _spider: SpiderPlayer
var _wall: StaticBody3D
var _ledge: StaticBody3D


func run_checks() -> void:
	_room = FarmRoom.make(true, Vector3(0.0, 0.6, 0.0))
	_wall = _block(_room, "Wall", Vector3(8.0, 6.0, 0.6), Vector3(0.0, 3.0, -6.0))
	_ledge = _block(_room, "Ledge", Vector3(3.0, 4.0, 3.0), Vector3(12.0, 2.0, 0.0))
	await stage(_room)
	_spider = FarmRoom.spider_of(_room)
	await run_frames(30)
	_check_kept_simple()
	await _check_walk()
	await _check_climb()
	await _check_jump()
	await _check_grapple()


func _check_kept_simple() -> void:
	check(SpiderClimb.Mode.size() == 3, "the spider is on the ground, in the air or on a grapple — nothing else (%s)"
		% ", ".join(SpiderClimb.Mode.keys()))
	var climb := _spider.climb
	var gone := ["toggle_ride", "clip_on", "room_to_hang", "_drop_line", "toggle_grapple_style"]
	var left := gone.filter(func(method: String) -> bool: return climb.has_method(method))
	check(left.is_empty(), "no hanging from silk, no dragline, no zip lines (%s left)"
		% ("none" if left.is_empty() else ", ".join(left)))
	check(_spider.climb.is_attached(), "put down, it stands on the floor")


func _check_walk() -> void:
	var start := _spider.global_position
	_spider.view.face(Vector3.RIGHT)
	Input.action_press("move_forward")
	await run_frames(60)
	Input.action_release("move_forward")
	await run_frames(20)
	var moved := Vector2(_spider.global_position.x - start.x, _spider.global_position.z - start.z)
	check(moved.x > 2.0 and absf(moved.y) < 0.6, "W walks it the way the camera faces (%.1fm)" % moved.x)


func _check_climb() -> void:
	_put(Vector3(0.0, 0.6, -2.0))
	_spider.view.face(Vector3.FORWARD)
	Input.action_press("move_forward")
	var on_wall := await wait_until(func() -> bool:
		return _spider.climb.is_attached() and absf(_spider.climb.surface_normal.y) < 0.3, 180)
	var low := _spider.global_position.y
	await run_frames(60)
	Input.action_release("move_forward")
	check(on_wall, "walked into a wall, it takes the wall")
	check(_spider.global_position.y > low + 1.0, "and keeps going, up it (%.1fm up)"
		% (_spider.global_position.y - low))
	_put(Vector3(0.0, 0.6, 0.0))
	await run_frames(20)


func _check_jump() -> void:
	await wait_until(func() -> bool: return _spider.climb.is_attached(), 120)
	await run_frames(10)
	var floor_y := _spider.global_position.y
	Input.action_press("move_jump")
	await run_frames(2)
	Input.action_release("move_jump")
	var peak := floor_y
	for i in 40:
		await physics_frame
		peak = maxf(peak, _spider.global_position.y)
	check(peak > floor_y + 1.2, "Space jumps it — high enough to clear a fence (%.1fm)" % (peak - floor_y))
	var landed := await wait_until(func() -> bool: return _spider.climb.is_attached(), 120)
	check(landed, "and it lands")


func _check_grapple() -> void:
	_put(Vector3(0.0, 0.6, 0.0))
	await run_frames(10)
	# The ledge's near face, a little below its top.
	FarmRoom.aim(_spider, Vector3(10.5, 3.2, 0.0))
	check(_spider.grapple(), "left mouse grapples to where the cross is")
	var top := _spider.grappler.aim_point
	check(_spider.climb.is_grappling() and _spider.grappler.pulling(), "a thread out, pulling")
	var there := await wait_until(func() -> bool: return not _spider.climb.is_grappling(), 120)
	await run_frames(10)
	check(there and _spider.global_position.distance_to(top) < 1.5 and _spider.climb.is_attached(),
		"and it lands where it struck, on its feet (%.1fm off)" % _spider.global_position.distance_to(top))
	FarmRoom.aim(_spider, _spider.global_position + Vector3(0.0, 80.0, -10.0))
	check(not _spider.grapple(), "aimed at open sky, there is nothing to grapple to")
	Input.action_press("let_go")
	await run_frames(2)
	Input.action_release("let_go")
	check(not _spider.tether.is_towing(), "Q with nothing on the line does nothing")


func _put(where: Vector3) -> void:
	_spider.global_position = where
	_spider.velocity = Vector3.ZERO
	_spider.climb.stand_upright()
	_spider.view.settle()


func _block(room: Node3D, block_name: String, size: Vector3, middle: Vector3) -> StaticBody3D:
	var body := WorldKit.body(room, block_name)
	WorldKit.box(body, "Shape", size, WorldKit.at(middle), "rock")
	return body
