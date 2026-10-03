extends SceneTree

## Renders the colosseum from a set of named places to PNG files, for checking how
## it reads without walking there. The level is loaded as it is baked and
## photographed from a camera of its own. Needs a display; on a headless machine
## run it through xvfb:
##
##     xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 \\
##         --path . --script res://tests/screenshot_world.gd
##
## Name views after `--` to render only those. The shots land in the user data
## folder as `world_<view>.png`; the paths are printed on the way out.

## Where each picture is taken from, and what it looks at.
const VIEWS := {
	"from_above": [Vector3(-55.0, 48.0, 62.0), Vector3(0.0, 2.0, 0.0)],
	"arena": [Vector3(-14.0, 1.2, 14.0), Vector3(8.0, 3.0, -10.0)],
	"from_the_rim": [Vector3(0.0, 13.5, -27.5), Vector3(0.0, 1.0, 6.0)],
	"south_gate": [Vector3(6.0, 2.2, 8.0), Vector3(0.0, 1.5, 18.5)],
	"way_out": [Vector3(0.6, 1.4, 27.5), Vector3(0.0, 1.6, 10.0)],
	"outside": [Vector3(40.0, 6.0, 52.0), Vector3(0.0, 6.0, 0.0)],
}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var wanted: Array[String] = []
	for arg in OS.get_cmdline_user_args():
		wanted.append(arg)
	if wanted.is_empty():
		wanted.assign(VIEWS.keys())
	var packed := load(Colosseum.SCENE) as PackedScene
	var world := packed.instantiate()
	root.add_child(world)
	current_scene = world
	var hud := world.get_node_or_null("HUD") as CanvasLayer
	if hud != null:
		hud.visible = false
	# The spider is not in any of the pictures, and drawing what it sees as well
	# as what the camera does is time a software renderer does not have.
	var spider := get_first_node_in_group("spider")
	if spider != null:
		spider.process_mode = Node.PROCESS_MODE_DISABLED
	var eye := Camera3D.new()
	eye.fov = 70.0
	eye.near = 0.05
	eye.far = 1000.0
	world.add_child(eye)
	await _frames(10)
	for view in wanted:
		if not VIEWS.has(view):
			printerr("no such view: %s (try %s)" % [view, ", ".join(VIEWS.keys())])
			continue
		var pose: Array = VIEWS[view]
		eye.global_position = pose[0]
		eye.look_at(pose[1], Vector3.UP)
		eye.make_current()
		await _frames(8)
		var image := root.get_viewport().get_texture().get_image()
		var path := "user://world_%s.png" % view
		image.save_png(path)
		print("saved ", ProjectSettings.globalize_path(path))
	quit()


func _frames(count: int) -> void:
	for i in count:
		await process_frame
