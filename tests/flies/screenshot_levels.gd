extends SceneTree

## Renders every level to PNG: from above and behind its start, and over the
## spider's shoulder as it starts. Needs a display; headless, run it through xvfb:
##
##     xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 \
##         --path . --script res://tests/flies/screenshot_levels.gd -- 03
##
## Name part of a level's file name after `--` to render only those. The shots land
## in the user data folder as `level_<file>_<view>.png`; their paths are printed.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var only := Array(OS.get_cmdline_user_args())
	for entry in LevelData.catalogue():
		var file := String(entry["path"]).get_file().get_basename()
		if not only.is_empty() and not only.any(func(part: String) -> bool:
				return file.contains(part)):
			continue
		var data := LevelData.load_file(entry["path"])
		var run := LevelRun.new()
		run.require_captured_mouse = false
		run.setup(data)
		root.add_child(run)
		for i in 20:
			await physics_frame
		await process_frame
		await _shoot(file + "_play")
		var box := _bounds(run.world)
		var overview := Camera3D.new()
		overview.fov = 55.0
		overview.far = 800.0
		run.add_child(overview)
		var start := run.weaver.global_position
		var middle := box.get_center()
		var span := maxf(box.size.x, box.size.z)
		var from := start + (start - middle).normalized() * span * 0.35 \
			+ Vector3.UP * span * 0.55
		overview.look_at_from_position(from, middle)
		overview.make_current()
		await process_frame
		await _shoot(file + "_above")
		run.free()
	quit()


func _bounds(world: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for node in world.get_children():
		var spatial := node as Node3D
		if spatial == null:
			continue
		var at := AABB(spatial.global_position, Vector3.ZERO)
		box = at if first else box.merge(at)
		first = false
	return box


func _shoot(label: String) -> void:
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "user://level_%s.png" % label
	image.save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))
