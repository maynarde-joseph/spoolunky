extends SceneTree

## Renders the spider's body in every state the gait has a pose for, close up, in
## every look, to PNG files — for checking how the rig reads without opening the
## editor. Needs a display; on a headless machine run it through xvfb:
##
##     xvfb-run -a godot --rendering-driver opengl3 --resolution 800x600 \\
##         --script res://tests/screenshot_body.gd
##
## Name states (`walk`, `wall` ...) or looks (`detailed`, `low_poly`, `minimal`)
## after `--` to render only those. The shots land in the user data folder as
## `body_<look>_<state>.png`; the paths are printed on the way out.

const ROOM_HALF := Vector3(3.0, 1.6, 3.0)

var _room: Node3D
var _spider: SpiderPlayer
var _eye: Camera3D
var _states: Array[String] = []
var _look := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var names: Array[String] = []
	for label in SpiderRig.LOOK_NAMES:
		names.append(String(label).replace(" ", "_"))
	var looks: Array[int] = []
	for arg in OS.get_cmdline_user_args():
		if names.has(arg):
			looks.append(names.find(arg))
		else:
			_states.append(arg)
	if looks.is_empty():
		looks.assign(range(names.size()))
	_build_room()
	await physics_frame

	_spider = load("res://game/player/spider.tscn").instantiate() as SpiderPlayer
	_room.add_child(_spider)
	_spider.global_position = Vector3(0, -ROOM_HALF.y + 0.5, 0)
	await physics_frame
	_spider.require_captured_mouse = false
	var audio := _spider.get_node_or_null("Player Audios")
	if audio != null:
		audio.free()
	# The builder's aim line is not the body; it stays out of shot unless the
	# shot is about aiming.
	_spider.web_builder.visible = false
	_eye = Camera3D.new()
	_eye.fov = 45.0
	_room.add_child(_eye)
	for look in looks:
		_spider.body.look = look as SpiderRig.Look
		_look = names[look]
		await _pose_all()

	current_scene = null
	_room.free()
	quit(0)


## Every state asked for, in the look being worn.
func _pose_all() -> void:
	await _reset()
	if _want("stand"):
		await _save("stand_front", Vector3(0.9, 0.9, -2.6))
		await _save("stand_side", Vector3(3.0, 0.6, 0.0))
	# Close, from above and in front: the back, the face and the finish of the
	# mesh, which is what tells one look from another.
	if _want("portrait"):
		await _save("portrait", Vector3(1.0, 1.1, -0.9))
	if _want("walk"):
		Input.action_press("move_forward")
		await _frames(20)
		await _save("walk", Vector3(2.4, 0.5, 1.2), 0)
		Input.action_release("move_forward")
	await _reset()
	if _want("aim"):
		_spider.web_builder.visible = true
		Input.action_press("web_shoot")
		_spider.web_builder.begin_shot()
		await _frames(50)
		await _save("aim", Vector3(2.2, 0.8, 1.8), 0)
		Input.action_release("web_shoot")
		_spider.web_builder.cancel_shot()
		_spider.web_builder.visible = false
	await _reset()
	if _want("feed"):
		var fly := Prey.of(PreyLibrary.find("fly"))
		_room.add_child(fly)
		fly.global_position = _spider.global_position + _spider.global_basis * Vector3(0, -0.05, -0.2)
		fly.move_speed = 0.0
		fly.bundle()
		await _frames(2)
		Input.action_press("interact")
		_spider.jaws.begin(fly)
		await _frames(30)
		await _save("feed", Vector3(1.6, 0.6, -1.6), 0)
		Input.action_release("interact")
		_spider.jaws.stop()
		if is_instance_valid(fly):
			fly.queue_free()
	await _reset()
	if _want("hurt"):
		_spider.take_bite(0.5)
		await _frames(3)
		await _save("hurt", Vector3(2.4, 0.6, 1.2), 0)
	if _want("air"):
		_spider.climb.stand_upright()
		_spider.global_position = Vector3(0.5, 1.1, 0.5)
		_spider.velocity = Vector3.ZERO
		await _frames(10)
		# Held still for the picture: the pose, not the fall.
		_spider.set_physics_process(false)
		await _save("air", Vector3(2.2, 0.6, 1.6), 0, true)
		_spider.set_physics_process(true)
	await _reset()
	if _want("grapple"):
		_spider.climb.grapple_to(Vector3(0.0, 0.5, -ROOM_HALF.z + 0.2), Vector3.BACK)
		await _frames(6)
		await _save("grapple", Vector3(2.4, 0.4, 1.0), 0)
		await _frames(60)
	if _want("wall"):
		await _reset(Vector3(-ROOM_HALF.x + 0.6, -ROOM_HALF.y + 0.3, 0.4), Vector3.LEFT)
		Input.action_press("move_forward")
		await _frames(40)
		Input.action_release("move_forward")
		await _frames(30)
		await _save("wall", Vector3(2.5, 0.6, 2.2), 0, true)
	# Hanging starts from the ceiling, so asking for either sets that up.
	if _want("ceiling") or _want("hang"):
		await _reset(Vector3(0.0, ROOM_HALF.y - 0.4, 0.0), Vector3.FORWARD)
		await _frames(20)
		if _want("ceiling"):
			await _save("ceiling", Vector3(2.4, -0.8, 1.4), 0, true)
		if _want("hang"):
			Input.action_press("move_crouch")
			await _frames(40)
			Input.action_release("move_crouch")
			await _frames(20)
			await _save("hang", Vector3(2.4, 0.2, 1.4), 0, true)
	if _want("ride"):
		var line := WebStrand.spin(_frame_line(), Vector3(-2.0, 1.0, 0.8),
			Vector3(2.0, -0.6, 0.8), 1.0)
		line.place_in(_room)
		await _reset(Vector3(-1.9, 0.9, 0.8), Vector3.FORWARD, 2)
		_spider.climb.toggle_ride()
		await _frames(12)
		await _save("ride", Vector3(0.5, 0.3, 3.0), 0, true)
		# Off it and down, so the next look's shots are not strung with it.
		_spider.climb.release()
		line.demolish()
		await _frames(2)


func _want(what: String) -> bool:
	return _states.is_empty() or _states.has(what)


## Back to standing in the middle of the room, or wherever [param at] says,
## level and facing [param look], with nothing held down.
func _reset(at := Vector3(0.0, -ROOM_HALF.y + 0.5, 0.5), look := Vector3.FORWARD,
		settle := 40) -> void:
	for action in InputMap.get_actions():
		if Input.is_action_pressed(action):
			Input.action_release(action)
	_spider.climb.stand_upright()
	_spider.view.settle()
	_spider.global_position = at
	_spider.velocity = Vector3.ZERO
	_spider.view.face(look)
	_spider.view.pitch = -0.2
	await _frames(settle)


func _frame_line() -> WebPattern:
	for candidate in _spider.web_builder.patterns:
		if candidate.id == "frame_line":
			return candidate
	return null


func _frames(count: int) -> void:
	for i in count:
		await process_frame


## Frames the spider from [param offset], in body heights — in the spider's own
## frame, or the world's with [param world] — and saves the shot.
func _save(label: String, offset: Vector3, settle := 20, world := false) -> void:
	await _frames(settle)
	var height: float = _spider.stage().body_height
	var basis := Basis.IDENTITY if world else _spider.global_basis.orthonormalized()
	var target := _spider.global_position
	_eye.global_position = target + basis * (offset * height)
	var sight := (target - _eye.global_position).normalized()
	_eye.look_at(target, Vector3.UP if absf(sight.y) < 0.98 else Vector3.FORWARD)
	_eye.make_current()
	for i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := "user://body_%s_%s.png" % [_look, label]
	root.get_texture().get_image().save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))
	_spider.view.camera.make_current()


func _build_room() -> void:
	_room = Node3D.new()
	_room.name = "Room"
	root.add_child(_room)
	current_scene = _room
	_slab(Vector3(0, -ROOM_HALF.y, 0), Vector3(ROOM_HALF.x, 0.2, ROOM_HALF.z), Color(0.62, 0.58, 0.52))
	_slab(Vector3(0, ROOM_HALF.y, 0), Vector3(ROOM_HALF.x, 0.2, ROOM_HALF.z), Color(0.6, 0.6, 0.62))
	_slab(Vector3(-ROOM_HALF.x, 0, 0), Vector3(0.2, ROOM_HALF.y, ROOM_HALF.z), Color(0.7, 0.68, 0.62))
	_slab(Vector3(0, 0, -ROOM_HALF.z), Vector3(ROOM_HALF.x, ROOM_HALF.y, 0.2), Color(0.66, 0.64, 0.6))
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-55), deg_to_rad(35), 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	_room.add_child(sun)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.3, 0.32, 0.35)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(0.75, 0.75, 0.8)
	world.environment.ambient_light_energy = 0.8
	_room.add_child(world)


func _slab(centre: Vector3, half: Vector3, colour: Color) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = GameLayers.WORLD
	body.position = centre
	var shape := BoxShape3D.new()
	shape.size = half * 2.0
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	var view := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = half * 2.0
	view.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	view.material_override = material
	body.add_child(view)
	_room.add_child(body)
