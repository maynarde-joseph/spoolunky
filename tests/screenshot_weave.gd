extends SceneTree

## Renders the same anchors woven both ways, in a room corner, so the two
## weave modes can be compared by eye. Needs a display; headless:
##
##     xvfb-run -a godot --rendering-driver opengl3 --resolution 1100x740 \\
##         --script res://tests/screenshot_weave.gd

const BRICK := "res://addons/character-controller/example/main/materials/bricks.tres"
const WOOD := "res://addons/character-controller/example/main/materials/wood.tres"

## Four anchors folded round a corner: three up one wall, one on the other.
const ANCHORS: Array[Vector3] = [
	Vector3(0.02, 0.18, 0.25), Vector3(0.02, 0.18, 1.0),
	Vector3(0.02, 0.95, 0.6), Vector3(0.75, 0.55, 0.02),
]

var _room: Node3D
var _spider: SpiderPlayer


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_room = Node3D.new()
	root.add_child(_room)
	current_scene = _room
	_slab(Vector3(1.5, -0.1, 1.5), Vector3(1.6, 0.1, 1.6), WOOD)
	_slab(Vector3(-0.1, 1.0, 1.5), Vector3(0.1, 1.1, 1.6), BRICK)
	_slab(Vector3(1.5, 1.0, -0.1), Vector3(1.6, 1.1, 0.1), BRICK)
	_light()

	_spider = load("res://game/player/spider.tscn").instantiate() as SpiderPlayer
	_room.add_child(_spider)
	_spider.global_position = Vector3(1.2, 0.4, 1.2)
	await physics_frame
	_spider.require_captured_mouse = false
	_spider.growth.feed(120.0, "shot")
	await physics_frame

	var camera := Camera3D.new()
	_room.add_child(camera)
	camera.near = 0.01
	camera.fov = 60.0
	camera.global_position = Vector3(1.5, 0.78, 1.5)
	camera.look_at(Vector3(0.25, 0.5, 0.45), Vector3.UP)
	camera.make_current()

	await _shot_frame()
	await _shot(WebGeometry.Weave.STRETCHED, "weave_stretched")
	await _shot(WebGeometry.Weave.INSCRIBED, "weave_inscribed")

	current_scene = null
	_room.free()
	await process_frame
	quit(0)


## Walking a triangle into the corner, then weaving inside it. The frame is
## real silk standing in the world before any web exists.
func _shot_frame() -> void:
	_clear()
	_spider.silk.refill(9000.0)
	_spider.view.third_person = true
	_spider.view.distance = 11.0
	_spider.global_position = Vector3(1.15, 0.55, 1.15)
	_spider.view.face(Vector3(-1, 0, -1))
	_spider.view.pitch = deg_to_rad(-10.0)
	await _frames(4)

	var builder := _spider.web_builder
	for i in builder.patterns.size():
		if builder.patterns[i].id == "sheet_web":
			builder.pattern_index = i
	builder.start()
	for point in [Vector3(0.55, 0.02, 0.55), Vector3(0.02, 0.62, 0.55),
			Vector3(0.55, 0.62, 0.02)]:
		builder.add_anchor(point)
	await _frames(4)
	await _save("frame_walked", "frame up, %.2f m2 enclosed" % builder.enclosed_area())

	builder.finish()
	builder.stop()
	await _frames(4)
	await _save("frame_woven", "woven inside the frame")


func _clear() -> void:
	var container := _room.get_node_or_null("Webs")
	if container != null:
		for child in container.get_children():
			child.free()


func _shot(weave: WebGeometry.Weave, name: String) -> void:
	_clear()
	_spider.silk.refill(9000.0)
	var builder := _spider.web_builder
	builder.weave = weave
	for i in builder.patterns.size():
		if builder.patterns[i].id == "orb_web":
			builder.pattern_index = i
	builder.start()
	for point in ANCHORS:
		builder.add_anchor(point)
	builder.finish()
	builder.stop()
	await physics_frame
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := "user://%s.png" % name
	root.get_texture().get_image().save_png(path)
	print("saved ", ProjectSettings.globalize_path(path), "  — ", builder.weave_name())


func _save(name: String, note: String) -> void:
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := "user://%s.png" % name
	root.get_texture().get_image().save_png(path)
	print("saved ", ProjectSettings.globalize_path(path), "  — ", note)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _slab(centre: Vector3, half: Vector3, material_path: String) -> void:
	var mesh := BoxMesh.new()
	mesh.size = half * 2.0
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.position = centre
	view.material_override = load(material_path)
	var body := StaticBody3D.new()
	body.collision_layer = GameLayers.WORLD
	var shape := BoxShape3D.new()
	shape.size = half * 2.0
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	view.add_child(body)
	_room.add_child(view)


func _light() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-42, -125, 0)
	light.light_energy = 1.4
	_room.add_child(light)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.07, 0.08, 0.1)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.5, 0.55, 0.65)
	environment.ambient_light_energy = 0.7
	world.environment = environment
	_room.add_child(world)
