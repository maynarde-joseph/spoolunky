extends SceneTree

## Renders the places built from the kit from a set of named views to PNG files, for
## checking how a place reads without walking there. Each is loaded as it is baked
## and photographed from a camera of its own. Needs a display; on a headless machine
## run it through xvfb:
##
##     xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 \\
##         --path . --script res://tests/screenshot_world.gd -- castle
##
## Name a place after `--` to render only its views, and views after it to render
## only those (`-- castle gate yard`); name nothing and every view of every place is
## rendered, which takes a while. The shots land in the user data folder as
## `world_<place>_<view>.png`; the paths are printed on the way out.

## Where each picture is taken from, and what it looks at, place by place.
const VIEWS := {
	"colosseum": {
		"from_above": [Vector3(-70.0, 60.0, 80.0), Vector3(0.0, 0.0, 0.0)],
		"start": [Vector3(-19.0, 1.4, 0.0), Vector3(10.0, 2.0, 0.0)],
		"north_side": [Vector3(0.0, 26.0, -55.0), Vector3(0.0, 4.0, 10.0)],
		"fallen_side": [Vector3(10.0, 8.0, 60.0), Vector3(0.0, 6.0, 0.0)],
	},
	"cathedral": {
		"from_above": [Vector3(-60.0, 45.0, 55.0), Vector3(10.0, 4.0, 0.0)],
		"nave": [Vector3(-22.0, 2.0, 0.0), Vector3(30.0, 8.0, 0.0)],
		"west_front": [Vector3(-55.0, 8.0, -10.0), Vector3(-20.0, 12.0, 0.0)],
		"north_side": [Vector3(10.0, 14.0, -45.0), Vector3(10.0, 8.0, 0.0)],
	},
	"castle": {
		"from_above": [Vector3(-45.0, 40.0, 50.0), Vector3(0.0, 2.0, 0.0)],
		"gate": [Vector3(0.0, 1.6, 14.0), Vector3(0.0, 4.0, -10.0)],
		"yard": [Vector3(14.0, 10.0, 12.0), Vector3(-10.0, 3.0, -6.0)],
		"outside": [Vector3(-50.0, 8.0, 30.0), Vector3(0.0, 6.0, 0.0)],
	},
	"aqueduct": {
		"from_above": [Vector3(-60.0, 40.0, 60.0), Vector3(0.0, 10.0, 0.0)],
		"river": [Vector3(8.0, 3.0, 30.0), Vector3(8.0, 10.0, 0.0)],
		"channel": [Vector3(-30.0, 23.0, 0.0), Vector3(20.0, 21.0, 0.0)],
		"start": [Vector3(-6.0, 1.6, 14.0), Vector3(4.0, 12.0, 0.0)],
	},
	"watchtower": {
		"from_above": [Vector3(-50.0, 45.0, 50.0), Vector3(0.0, 15.0, 0.0)],
		"approach": [Vector3(0.0, 1.6, 30.0), Vector3(0.0, 20.0, 0.0)],
		"inside": [Vector3(0.0, 15.0, 0.5), Vector3(0.0, 40.0, 0.0)],
		"terrace": [Vector3(18.0, 12.0, -4.0), Vector3(0.0, 20.0, 0.0)],
	},
	"temple": {
		"from_above": [Vector3(-55.0, 48.0, 62.0), Vector3(0.0, 2.0, 0.0)],
		"court": [Vector3(-14.0, 1.2, 14.0), Vector3(8.0, 3.0, -10.0)],
		"from_the_rim": [Vector3(0.0, 13.5, -27.5), Vector3(0.0, 1.0, 6.0)],
		"way_out": [Vector3(0.6, 1.4, 27.5), Vector3(0.0, 1.6, 10.0)],
		"outside": [Vector3(40.0, 6.0, 52.0), Vector3(0.0, 6.0, 0.0)],
	},
}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var places: Array = VIEWS.keys()
	var wanted: Array[String] = []
	if not args.is_empty():
		if not VIEWS.has(args[0]):
			printerr("no such place: %s (try %s)" % [args[0], ", ".join(places)])
			quit(1)
			return
		places = [args[0]]
		for i in range(1, args.size()):
			wanted.append(args[i])
	for place in places:
		await _photograph(place, wanted)
	quit()


func _photograph(place: String, wanted: Array[String]) -> void:
	var views: Dictionary = VIEWS[place]
	var names: Array = wanted if not wanted.is_empty() else views.keys()
	var builder := Site.builder(place)
	var world := (load(builder.get_script_constant_map()["SCENE"]) as PackedScene).instantiate()
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
	eye.far = 1500.0
	world.add_child(eye)
	await _frames(10)
	for view in names:
		if not views.has(view):
			printerr("no such view of %s: %s (try %s)" % [place, view, ", ".join(views.keys())])
			continue
		var pose: Array = views[view]
		eye.global_position = pose[0]
		eye.look_at(pose[1], Vector3.UP)
		eye.make_current()
		await _frames(8)
		var image := root.get_viewport().get_texture().get_image()
		var path := "user://world_%s_%s.png" % [place, view]
		image.save_png(path)
		print("saved ", ProjectSettings.globalize_path(path))
	current_scene = null
	world.free()
	await _frames(2)


func _frames(count: int) -> void:
	for i in count:
		await process_frame
