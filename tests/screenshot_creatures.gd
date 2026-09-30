extends SceneTree

## Renders every body there is, close up, in each way it holds itself — flying,
## swimming or walking, at rest, caught in a web, wrapped up — to PNG files, and
## tiles them all into one sheet. For checking how a body reads without opening
## the editor. A body nothing wears yet is shown on a [StandIn]. Needs a display;
## on a headless machine run it through xvfb:
##
##     xvfb-run -a godot --rendering-driver opengl3 --resolution 800x600 \\
##         --script res://tests/screenshot_creatures.gd
##
## Name bodies (`fly`, `rat` ...) or poses (`flying`, `walking`, `resting`,
## `caught`, `wrapped`) after `--` to render only those; `flying` takes in
## swimming. The shots land in the user data folder as
## `creature_<body>_<pose>.png`, the sheet as `creatures.png`; the paths are
## printed on the way out.

const POSES := ["flying", "walking", "resting", "caught", "wrapped"]
const TILE := Vector2i(320, 240)

var _room: Node3D
var _eye: Camera3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var names: Array[String] = []
	var poses: Array[String] = []
	for arg in OS.get_cmdline_user_args():
		if arg == "swimming":
			arg = "flying"
		if POSES.has(arg):
			poses.append(arg)
		else:
			names.append(arg)
	if poses.is_empty():
		poses.assign(POSES)
	_build_room()
	_eye = Camera3D.new()
	_eye.fov = 40.0
	_eye.near = 0.005
	_room.add_child(_eye)
	_eye.make_current()
	await physics_frame

	var rows: Array[Array] = []
	for kind in StandIn.every_body():
		if not names.is_empty() and not names.has(kind.id):
			continue
		var shots: Array[Image] = []
		for pose in poses:
			# A flier is not shown walking, nor a walker flying.
			if (pose == "flying" and not kind.flying) or (pose == "walking" and kind.flying):
				continue
			shots.append(await _shoot(kind, pose))
		rows.append(shots)
	_save_sheet(rows)

	current_scene = null
	_room.free()
	quit(0)


## One creature in one pose: put down in the middle of the room, facing across
## the camera, held there, and photographed from above and in front — from
## further off the more of it there is, so a tail or a wingspan stays in the shot.
func _shoot(kind: PreySpecies, pose: String) -> Image:
	var prey := Prey.of(kind)
	_room.add_child(prey)
	# Held still: the pose, not the wandering. After it is in the tree, because
	# becoming ready switches physics back on for anything that has it.
	prey.set_physics_process(false)
	var radius := kind.body_radius
	var ground := -0.5
	var at := Vector3(0.0, ground + radius * 3.0, 0.0)
	if not kind.flying:
		at.y = ground + radius * Prey.HITBOX_SCALE
	prey.global_position = at
	var view := prey.get_node("Body") as CreatureView
	# Moving, so that it turns to face the way it is going: across the shot.
	prey.velocity = Vector3(-1.0, 0.0, 0.35).normalized() * radius * 12.0
	view.held = CreatureMotion.Pose.FLYING if kind.flying else CreatureMotion.Pose.WALKING
	await _frames(30)
	match pose:
		"flying":
			view.held = CreatureMotion.Pose.FLYING
		"walking":
			view.held = CreatureMotion.Pose.WALKING
		"resting":
			prey.velocity = Vector3.ZERO
			view.held = CreatureMotion.Pose.WALKING
		"caught":
			prey.velocity = Vector3.ZERO
			view.held = CreatureMotion.Pose.STRUGGLING
		"wrapped":
			prey.velocity = Vector3.ZERO
			view.held = CreatureMotion.Pose.CURLED
	await _frames(40)
	# At the middle of what is drawn — which a walker carries lower than its own
	# middle, down on its legs, and a tail takes back — from far enough off to fit
	# it all in. An insect, the size of its wingspan across, is shot from about
	# seven body radii.
	var box := view.shell.mesh.get_aabb()
	var target := view.global_transform * box.get_center() + Vector3.UP * radius * 0.2
	var reach := maxf(box.size.x, maxf(box.size.y, box.size.z)) * 0.5
	var away := Vector3(2.2, 3.4, 5.6).normalized() * radius * maxf(6.9, reach * 4.9)
	_eye.global_position = target + away
	_eye.look_at(target, Vector3.UP)
	for i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var doing := StandIn.going(kind) if pose == "flying" else pose
	var path := "user://creature_%s_%s.png" % [kind.id, doing]
	image.save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))
	prey.free()
	return image


## A row a species, a column a pose.
func _save_sheet(rows: Array[Array]) -> void:
	var columns := 0
	for row in rows:
		columns = maxi(columns, row.size())
	if rows.is_empty() or columns == 0:
		return
	var sheet := Image.create(columns * TILE.x, rows.size() * TILE.y, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.12, 0.12, 0.12))
	for r in rows.size():
		var row: Array = rows[r]
		for c in row.size():
			var shot := (row[c] as Image).duplicate() as Image
			shot.convert(Image.FORMAT_RGB8)
			shot.resize(TILE.x, TILE.y, Image.INTERPOLATE_BILINEAR)
			sheet.blit_rect(shot, Rect2i(Vector2i.ZERO, TILE), Vector2i(c * TILE.x, r * TILE.y))
	var path := "user://creatures.png"
	sheet.save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _build_room() -> void:
	_room = Node3D.new()
	_room.name = "Room"
	root.add_child(_room)
	current_scene = _room
	# Mid-grey and lit gently: a creature a few centimetres long is photographed
	# from a hand's width away, and a bright floor that close is all glare.
	_slab(Vector3(0, -0.6, 0), Vector3(2.0, 0.1, 2.0), Color(0.42, 0.4, 0.37))
	_slab(Vector3(0, 0.4, -1.2), Vector3(2.0, 1.0, 0.1), Color(0.46, 0.45, 0.43))
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-55), deg_to_rad(35), 0)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	_room.add_child(sun)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.3, 0.32, 0.35)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(0.75, 0.75, 0.8)
	world.environment.ambient_light_energy = 0.55
	_room.add_child(world)


func _slab(centre: Vector3, half: Vector3, colour: Color) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = GameLayers.WORLD
	body.position = centre
	var shape := BoxShape3D.new()
	shape.size = half * 2.0
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	var view := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = half * 2.0
	view.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	view.material_override = material
	body.add_child(view)
	_room.add_child(body)
