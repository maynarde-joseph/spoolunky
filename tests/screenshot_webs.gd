extends SceneTree

## Renders the web patterns to PNG files, for eyeballing changes to the silk
## geometry without opening the editor. Needs a display — under a headless
## machine run it through xvfb:
##
##     xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 \\
##         --script res://tests/screenshot_webs.gd
##
## The shots land in the user data folder; the path is printed on the way out.

const LEVEL_PATH := "res://addons/character-controller/example/main/level.tscn"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var level: Node = load(LEVEL_PATH).instantiate()
	root.add_child(level)
	current_scene = level
	await physics_frame
	await physics_frame

	var spider := root.get_tree().get_first_node_in_group("spider") as SpiderPlayer
	spider.global_position = Vector3(12, 0.5, 6)
	spider.growth.feed(200.0, "shot")
	await physics_frame
	var builder := spider.web_builder
	spider.silk.refill(9000.0)

	_spin(builder, "orb_web", Vector3(12, 1.0, 0.0), 0.75)
	_spin(builder, "sheet_web", Vector3(10.0, 1.0, 0.0), 0.6)
	_spin(builder, "pressure_snare", Vector3(14.0, 1.0, 0.0), 0.6)
	_strand(builder, "silk_bridge", Vector3(9.0, 1.7, 0.6), Vector3(15.0, 1.7, 0.6))
	_strand(builder, "trip_line", Vector3(9.0, 0.25, -0.6), Vector3(15.0, 0.25, -0.6))
	await physics_frame

	# Leave build mode mid-web so the preview lines show up too.
	_select(builder, "orb_web")
	builder.start()
	builder.add_anchor(Vector3(11.4, 2.2, 1.2))
	builder.add_anchor(Vector3(12.6, 2.2, 1.2))
	builder.add_anchor(Vector3(12.6, 2.9, 1.2))

	var camera := Camera3D.new()
	level.add_child(camera)
	camera.global_position = Vector3(12, 1.7, 4.2)
	camera.look_at(Vector3(12, 1.0, 0), Vector3.UP)
	camera.fov = 60.0
	camera.near = 0.01
	camera.make_current()

	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png("user://webs_overview.png")
	print("saved ", ProjectSettings.globalize_path("user://webs_overview.png"),
		"  ", image.get_width(), "x", image.get_height())

	# Second angle: close on the orb web.
	camera.global_position = Vector3(12.9, 1.25, 1.35)
	camera.look_at(Vector3(12, 1.0, 0), Vector3.UP)
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://webs_orb_closeup.png")
	print("saved ", ProjectSettings.globalize_path("user://webs_orb_closeup.png"))

	# Third shot: a wired trap chain — tripline into a snare, with prey waiting.
	builder.stop()
	spider.silk.refill(9000.0)
	# Off to one side, clear of the pattern line-up, so the wire is readable.
	_spin(builder, "pressure_snare", Vector3(-11.0, 1.2, -1.8), 0.7)
	_strand(builder, "trip_line", Vector3(-11.0, 0.35, 1.8), Vector3(-11.0, 2.0, 1.8))
	await physics_frame
	var webs := level.get_node("Webs")
	var snare: WebStructure = null
	var trip: WebStructure = null
	for child in webs.get_children():
		var web := child as WebStructure
		if web == null:
			continue
		if web.pattern.id == "pressure_snare":
			snare = web
		elif web.pattern.id == "trip_line":
			trip = web
	if trip != null and snare != null:
		builder.link_webs(trip, snare)
		trip.fire()
	await physics_frame

	camera.global_position = Vector3(-7.0, 1.9, 0.0)
	camera.look_at(Vector3(-11.0, 1.2, 0.0), Vector3.UP)
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://webs_trigger_link.png")
	print("saved ", ProjectSettings.globalize_path("user://webs_trigger_link.png"))

	current_scene = null
	level.free()
	await process_frame
	quit(0)


func _select(builder: WebBuilder, id: String) -> void:
	for i in builder.patterns.size():
		if builder.patterns[i].id == id:
			builder.pattern_index = i
			return

func _spin(builder: WebBuilder, id: String, centre: Vector3, half: float) -> void:
	_select(builder, id)
	builder.start()
	for point in [centre + Vector3(-half, -half, 0), centre + Vector3(half, -half, 0),
			centre + Vector3(half, half, 0), centre + Vector3(-half, half, 0)]:
		builder.add_anchor(point)
	builder.finish()
	builder.stop()

func _strand(builder: WebBuilder, id: String, a: Vector3, b: Vector3) -> void:
	_select(builder, id)
	builder.start()
	builder.add_anchor(a)
	builder.add_anchor(b)
	builder.stop()
