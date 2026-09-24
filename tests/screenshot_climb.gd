extends SceneTree

## Renders the climbing states to PNG files, for checking how a wall, a ceiling
## and a dragline actually read from inside the spider's head. Needs a display;
## on a headless machine run it through xvfb:
##
##     xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 \\
##         --script res://tests/screenshot_climb.gd
##
## The shots land in the user data folder; the paths are printed on the way out.

const LEVEL_PATH := "res://addons/character-controller/example/main/level.tscn"

## Underside of the demo level's bridge — a ready-made ceiling.
const UNDER_BRIDGE := Vector3(0, 3.05, 13.5)

var _level: Node
var _spider: SpiderPlayer


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_level = load(LEVEL_PATH).instantiate()
	root.add_child(_level)
	current_scene = _level
	await physics_frame
	_spider = root.get_tree().get_first_node_in_group("spider") as SpiderPlayer
	_spider.require_captured_mouse = false

	_spider.view.third_person = true
	await _shot_scale()
	await _shot_wall()
	await _shot_ceiling()
	await _shot_dragline()
	await _shot_zipline()

	current_scene = null
	_level.free()
	quit(0)


## Just standing there, so the size of the thing reads against the level.
func _shot_scale() -> void:
	_spider.view.distance = 3.0
	_place(Vector3(-11.0, 1.5, 4.0), Vector3.FORWARD)
	await _frames(80)
	_spider.view.pitch = deg_to_rad(-22.0)
	await _save("body_scale", "a spiderling at stage 1, third person")
	_spider.growth.feed(400.0, "shot")
	await _frames(30)
	await _save("body_scale_grown", "the same spider several tiers up")
	_spider.view.distance = 4.5
	_spider.growth.biomass = 0.0
	_spider.growth.stage_index = 0
	_spider.growth.stage_changed.emit(_spider.growth.current_stage(), 0)
	await _frames(10)


## On a wall: the body rolls onto it, the horizon does not.
func _shot_wall() -> void:
	_place(Vector3(0, 1.2, -17.0), Vector3.FORWARD)
	Input.action_press("move_forward")
	await _frames(120)
	Input.action_release("move_forward")
	_spider.view.pitch = deg_to_rad(-15)
	await _save("climb_wall", "on a wall, normal %.2v" % _spider.climb.surface_normal)


## On a ceiling: upside down under the bridge.
func _shot_ceiling() -> void:
	_place(UNDER_BRIDGE, Vector3.RIGHT)
	await _frames(40)
	Input.action_press("move_forward")
	await _frames(40)
	Input.action_release("move_forward")
	_spider.view.pitch = deg_to_rad(-10)
	await _save("climb_ceiling", "on the ceiling, normal %.2v" % _spider.climb.surface_normal)


## Hanging from a thread under the bridge, seen from the spider and from beside it.
func _shot_dragline() -> void:
	Input.action_press("move_crouch")
	await _frames(45)
	Input.action_release("move_crouch")
	await _frames(20)
	_spider.view.pitch = deg_to_rad(55)
	await _save("climb_hanging", "hanging, line %.2fm" % _spider.climb.line_length)

	# And from outside, so the thread itself is visible.
	var camera := Camera3D.new()
	_level.add_child(camera)
	var spot := _spider.global_position
	camera.global_position = spot + Vector3(2.2, 0.9, 2.2)
	camera.look_at(spot + Vector3(0, 0.6, 0), Vector3.UP)
	camera.near = 0.02
	camera.make_current()
	await _save("climb_hanging_outside", "the line from outside")


## Riding a line strung across the arena — the thing the whole traversal side
## of the game hangs off.
func _shot_zipline() -> void:
	_spider.climb.release()
	_spider.growth.feed(200.0, "shot")
	var top := Vector3(-9.0, 7.5, 6.0)
	var bottom := Vector3(9.0, 1.4, 6.0)
	var builder := _spider.web_builder
	for i in builder.patterns.size():
		if builder.patterns[i].id == "silk_bridge":
			builder.pattern_index = i
	builder.start()
	builder.add_anchor(top)
	builder.add_anchor(bottom)
	builder.stop()
	_spider.global_position = top + Vector3(0.3, -0.2, 0)
	_spider.velocity = Vector3.ZERO
	await _frames(3)
	_spider.climb.toggle_ride()
	await _frames(45)
	_spider.view.pitch = deg_to_rad(-8)
	await _save("zipline_riding", "riding at %.1f m/s" % _spider.climb.ride_velocity())

	# And from outside, so the line and the rider both read.
	var camera := Camera3D.new()
	_level.add_child(camera)
	var spot := _spider.global_position
	camera.global_position = spot + Vector3(-3.0, 2.0, 5.0)
	camera.look_at(spot, Vector3.UP)
	camera.near = 0.02
	camera.make_current()
	await _save("zipline_outside", "the line from beside it")


# --- scaffolding --------------------------------------------------------

func _place(at: Vector3, facing: Vector3) -> void:
	_spider.climb.release()
	_spider.global_position = at
	_spider.velocity = Vector3.ZERO
	_spider.climb.face(facing)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _save(name: String, note: String) -> void:
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := "user://%s.png" % name
	root.get_texture().get_image().save_png(path)
	print("saved ", ProjectSettings.globalize_path(path), "  — ", note)
