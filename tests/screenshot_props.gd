extends SceneTree

## Renders every prop the world is furnished with, one at a time from the front
## corner, to PNG files, and tiles them into one sheet: for checking how a prop
## reads without opening the editor. Built from [Props] each time rather than
## loaded from its scene, so a change shows before it is baked. Needs a display;
## on a headless machine run it through xvfb:
##
##     xvfb-run -a godot --rendering-driver opengl3 --resolution 800x600 \\
##         --path . --script res://tests/screenshot_props.gd
##
## Name props after `--` to render only those. The shots land in the user data
## folder as `prop_<name>.png`, the sheet as `props.png`; the paths are printed
## on the way out.

const TILE := Vector2i(320, 240)
const COLUMNS := 8

var _room: Node3D
var _eye: Camera3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var names: Array[String] = []
	for arg in OS.get_cmdline_user_args():
		names.append(arg)
	if names.is_empty():
		names.assign(Props.ALL)
	_build_room()
	_eye = Camera3D.new()
	_eye.fov = 35.0
	_room.add_child(_eye)
	_eye.make_current()
	await physics_frame

	var shots: Array[Image] = []
	for id in names:
		var shot := await _shoot(id)
		if shot != null:
			shots.append(shot)
	_save_sheet(shots)
	quit()


func _shoot(id: String) -> Image:
	var prop := Props.build(id)
	if prop == null:
		return null
	_room.add_child(prop)
	var box := _bounds(prop)
	var middle := box.get_center()
	var reach := maxf(box.size.length() * 0.5, 0.5)
	var from := Vector3(-0.75, 0.55, -1.0).normalized()
	_eye.near = reach * 0.02
	_eye.far = reach * 20.0
	_eye.global_position = middle + from * reach / sin(deg_to_rad(_eye.fov * 0.5)) * 1.05
	_eye.look_at(middle, Vector3.UP)
	await _frames(4)
	var image := _room.get_viewport().get_texture().get_image()
	var path := "user://prop_%s.png" % id
	image.save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))
	prop.free()
	return image


## Everything the prop draws, in the world.
func _bounds(prop: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for node in _every(prop):
		var view := node as MeshInstance3D
		if view == null or view.mesh == null:
			continue
		var part := view.global_transform * view.mesh.get_aabb()
		box = part if first else box.merge(part)
		first = false
	return box


func _save_sheet(shots: Array[Image]) -> void:
	if shots.is_empty():
		return
	var rows := ceili(float(shots.size()) / float(COLUMNS))
	var columns := mini(shots.size(), COLUMNS)
	var sheet := Image.create(columns * TILE.x, rows * TILE.y, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.12, 0.12, 0.12))
	for i in shots.size():
		var shot := shots[i].duplicate() as Image
		shot.convert(Image.FORMAT_RGB8)
		shot.resize(TILE.x, TILE.y, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(shot, Rect2i(Vector2i.ZERO, TILE),
			Vector2i((i % COLUMNS) * TILE.x, (i / COLUMNS) * TILE.y))
	var path := "user://props.png"
	sheet.save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _every(node: Node) -> Array[Node]:
	var found: Array[Node] = [node]
	for child in node.get_children():
		found.append_array(_every(child))
	return found


func _build_room() -> void:
	_room = Node3D.new()
	_room.name = "Room"
	root.add_child(_room)
	current_scene = _room
	var floor_view := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400.0, 400.0)
	floor_view.mesh = plane
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.42, 0.41, 0.39)
	floor_view.material_override = grey
	_room.add_child(floor_view)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(-150), 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	_room.add_child(sun)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.3, 0.32, 0.35)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(0.75, 0.75, 0.8)
	world.environment.ambient_light_energy = 0.5
	world.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_room.add_child(world)
