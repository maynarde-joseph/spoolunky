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
	_mark_body()

	await _shot_wall()
	await _shot_ceiling()
	await _shot_dragline()

	current_scene = null
	_level.free()
	quit(0)


## On a wall: the world tips ninety degrees because the spider's floor did.
func _shot_wall() -> void:
	_place(Vector3(0, 1.2, -17.0), Vector3.FORWARD)
	Input.action_press("move_forward")
	await _frames(120)
	Input.action_release("move_forward")
	_spider.head.rotation.x = deg_to_rad(-15)
	await _save("climb_wall", "on a wall, normal %.2v" % _spider.climb.surface_normal)


## On a ceiling: upside down under the bridge.
func _shot_ceiling() -> void:
	_place(UNDER_BRIDGE, Vector3.RIGHT)
	await _frames(40)
	Input.action_press("move_forward")
	await _frames(40)
	Input.action_release("move_forward")
	_spider.head.rotation.x = deg_to_rad(-10)
	await _save("climb_ceiling", "on the ceiling, normal %.2v" % _spider.climb.surface_normal)


## Hanging from a thread under the bridge, seen from the spider and from beside it.
func _shot_dragline() -> void:
	_spider.silk.refill(_spider.silk.maximum)
	Input.action_press("move_crouch")
	await _frames(45)
	Input.action_release("move_crouch")
	await _frames(20)
	_spider.head.rotation.x = deg_to_rad(55)
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


# --- scaffolding --------------------------------------------------------

func _place(at: Vector3, facing: Vector3) -> void:
	_spider.climb.release()
	_spider.global_position = at
	_spider.velocity = Vector3.ZERO
	_spider.climb.face(facing)


## The player has no body mesh yet, so give it a blob for the outside shot.
func _mark_body() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.09
	mesh.height = 0.16
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.06, 0.05, 0.07)
	material.roughness = 0.6
	var body := MeshInstance3D.new()
	body.name = "BodyBlob"
	body.mesh = mesh
	body.material_override = material
	_spider.add_child(body)


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
