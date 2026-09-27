extends SceneTree

## Renders the dummies station, for eyeballing the readout without opening the
## editor. Needs a display — under a headless machine run it through xvfb:
##
##     xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 \
##         --script res://tests/shot_dummies.gd

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var bed: Node = load("res://game/world/testbed.tscn").instantiate()
	root.add_child(bed)
	current_scene = bed
	await physics_frame
	await process_frame

	# Some silk and some venom on them, so the readout has something to say.
	var posts: Array[Node] = []
	for node in _all_under(bed):
		if node is TrainingDummy:
			posts.append(node)
	for i in posts.size():
		await physics_frame
		var standing: Prey = posts[i]._standing
		if is_instance_valid(standing):
			standing.bind(0.25 + 0.3 * float(i))
			standing.poison(9.0)
	for i in 30:
		await physics_frame

	for layer in _all_under(bed):
		if layer is CanvasLayer:
			layer.visible = false

	var camera := Camera3D.new()
	bed.add_child(camera)
	# Close, so the neighbouring stations' signs stay out of it.
	camera.global_position = SpiderTestbed.DUMMIES + Vector3(0.0, 1.7, 3.4)
	camera.look_at(SpiderTestbed.DUMMIES + Vector3(0.0, 1.4, 0.0), Vector3.UP)
	camera.fov = 58.0
	camera.near = 0.01
	camera.make_current()

	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://dummies.png")
	print("saved ", ProjectSettings.globalize_path("user://dummies.png"))
	quit(0)

func _all_under(node: Node) -> Array[Node]:
	var found: Array[Node] = []
	for child in node.get_children():
		found.append(child)
		found.append_array(_all_under(child))
	return found
