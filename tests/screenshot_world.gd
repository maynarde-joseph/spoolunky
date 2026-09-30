extends SceneTree

## Renders the world from a set of named places to PNG files, for checking how a
## place reads without walking there. The level is loaded as it is baked, spider,
## creatures and all, and photographed from a camera of its own. Needs a display;
## on a headless machine run it through xvfb:
##
##     xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 \\
##         --path . --script res://tests/screenshot_world.gd
##
## Name views after `--` to render only those. The shots land in the user data
## folder as `world_<view>.png`; the paths are printed on the way out.

const WORLD_PATH := "res://game/world/world.tscn"

## Where each picture is taken from and what it looks at.
const VIEWS := {
	"shed": [Vector3(-151.0, 20.0, 12.0), Vector3(-176.0, 8.0, -6.0)],
	"shed_bench": [Vector3(-168.0, 16.0, 8.0), Vector3(-184.0, 14.0, 0.0)],
	"shed_floor": [Vector3(-170.0, 2.2, 9.0), Vector3(-166.0, 1.5, 0.0)],
	"shed_rafters": [Vector3(-152.0, 26.0, 10.0), Vector3(-172.0, 32.0, -4.0)],
	"shed_outside": [Vector3(-110.0, 28.0, 48.0), Vector3(-166.0, 14.0, 0.0)],
}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var wanted: Array[String] = []
	for arg in OS.get_cmdline_user_args():
		wanted.append(arg)
	if wanted.is_empty():
		wanted.assign(VIEWS.keys())
	var packed := load(WORLD_PATH) as PackedScene
	var world := packed.instantiate()
	root.add_child(world)
	current_scene = world
	var hud := world.get_node_or_null("HUD") as CanvasLayer
	if hud != null:
		hud.visible = false
	var eye := Camera3D.new()
	eye.fov = 60.0
	eye.near = 0.05
	eye.far = 1200.0
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
		await _frames(6)
		var image := root.get_viewport().get_texture().get_image()
		var path := "user://world_%s.png" % view
		image.save_png(path)
		print("saved ", ProjectSettings.globalize_path(path))
	quit()


func _frames(count: int) -> void:
	for i in count:
		await process_frame
