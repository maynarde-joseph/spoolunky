extends SceneTree

## Renders the hunting ground from a set of named places to PNG files, for
## checking how a place reads without walking there. The level is loaded as it is
## baked, creatures and all, and photographed from a camera of its own, with the
## clock stopped at the hour the view is for. Needs a display; on a headless
## machine run it through xvfb:
##
##     xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 \\
##         --path . --script res://tests/screenshot_world.gd
##
## Name views after `--` to render only those. The shots land in the user data
## folder as `world_<view>.png`; the paths are printed on the way out.

const WORLD_PATH := "res://game/world/hunting_ground.tscn"

## Where each picture is taken from, what it looks at, and the hour, as a share of
## the day: a half is noon, and nought and one are midnight.
const VIEWS := {
	"camp": [Vector3(44.0, 9.0, 304.0), Vector3(18.0, 2.0, 262.0), 0.42],
	"fern_floor": [Vector3(20.0, 4.0, 262.0), Vector3(10.0, 3.0, 200.0), 0.42],
	"fern_floor_above": [Vector3(0.0, 60.0, 300.0), Vector3(0.0, 0.0, 180.0), 0.42],
	"rootways": [Vector3(-100.0, 40.0, 240.0), Vector3(-205.0, 30.0, 140.0), 0.42],
	"rootways_cave": [Vector3(-160.0, 4.0, 130.0), Vector3(-205.0, 6.0, 140.0), 0.42],
	"rootways_up": [Vector3(-175.0, 10.0, 160.0), Vector3(-205.0, 120.0, 140.0), 0.42],
	"glade": [Vector3(10.0, 90.0, 160.0), Vector3(0.0, 0.0, 0.0), 0.42],
	"glade_low": [Vector3(30.0, 6.0, 60.0), Vector3(-10.0, 6.0, 10.0), 0.42],
	"glade_hive": [Vector3(60.0, 10.0, -10.0), Vector3(58.0, 6.0, -30.0), 0.42],
	"glade_at_night": [Vector3(20.0, 26.0, 80.0), Vector3(0.0, 4.0, 10.0), 0.95],
	"ruins": [Vector3(-150.0, 70.0, -20.0), Vector3(-215.0, 0.0, -85.0), 0.42],
	"ruins_gate": [Vector3(-190.0, 14.0, -10.0), Vector3(-212.0, 12.0, -60.0), 0.42],
	"ruins_tower": [Vector3(-240.0, 10.0, -100.0), Vector3(-268.0, 30.0, -128.0), 0.42],
	"mere": [Vector3(120.0, 60.0, -10.0), Vector3(235.0, -10.0, -10.0), 0.42],
	"mere_shore": [Vector3(130.0, 4.0, -12.0), Vector3(200.0, 0.0, -20.0), 0.42],
	"mere_island": [Vector3(225.0, 8.0, -40.0), Vector3(258.0, 4.0, -28.0), 0.42],
	"mere_under": [Vector3(200.0, -10.0, 0.0), Vector3(235.0, -20.0, -10.0), 0.42],
	"mere_at_dusk": [Vector3(120.0, 60.0, -10.0), Vector3(235.0, -10.0, -10.0), 0.76],
	"crag": [Vector3(40.0, 50.0, -120.0), Vector3(-20.0, 50.0, -275.0), 0.42],
	"crag_nest": [Vector3(-5.0, 110.0, -258.0), Vector3(-20.0, 100.0, -275.0), 0.42],
	"from_above": [Vector3(0.0, 520.0, 520.0), Vector3(0.0, 0.0, -20.0), 0.42],
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
	# The spider is not in any of the pictures, and drawing what it sees as well
	# as what the camera does is time a software renderer does not have.
	var spider := get_first_node_in_group("spider")
	if spider != null:
		spider.process_mode = Node.PROCESS_MODE_DISABLED
	var eye := Camera3D.new()
	eye.fov = 60.0
	eye.near = 0.05
	eye.far = 3000.0
	world.add_child(eye)
	await _frames(10)
	var clock := get_first_node_in_group(Ecosystem.GROUP) as Ecosystem
	if clock != null:
		clock.running = false
	var day := world.find_child("DayNight", true, false) as DayNight
	for view in wanted:
		if not VIEWS.has(view):
			printerr("no such view: %s (try %s)" % [view, ", ".join(VIEWS.keys())])
			continue
		var pose: Array = VIEWS[view]
		if clock != null:
			clock.time_of_day = pose[2]
		if day != null:
			day.show_hour()
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
