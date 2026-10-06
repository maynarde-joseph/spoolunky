class_name LevelBuilder
extends RefCounted

## Turns a level's data into nodes: the same build for playing it and for
## editing it. Every thing it builds carries the dictionary it was built from, as
## the meta [constant THING], so the editor can find a thing by clicking it and
## change it by changing that dictionary and building it again.

const THING := "level_thing"
const GROUP := "level_things"


## Builds every thing in [param level] under [param parent]. [param editing] adds
## what only the editor shows — the start, and the paths things move along.
static func build(level: Dictionary, parent: Node3D, editing := false) -> void:
	for thing in level.get("objects", []):
		build_thing(thing, parent, editing)


## Builds one thing. Null for a type it does not know.
static func build_thing(thing: Dictionary, parent: Node3D, editing := false) -> Node3D:
	var made: Node3D = null
	var type := String(thing.get("type", ""))
	var size := LevelData.vec(thing.get("size"), PieceLook.size_of(String(thing.get("piece", "cube"))))
	var surface := String(thing.get("surface", Surfaces.STONE))
	match type:
		"piece":
			var body := StaticBody3D.new()
			body.collision_layer = GameLayers.WORLD
			body.collision_mask = 0
			made = body
			parent.add_child(made, true)
			made.transform = LevelData.transform_of(thing)
			PieceLook.dress(body, String(thing.get("piece", "cube")), size, surface)
		"start":
			made = Node3D.new()
			made.name = "Start"
			parent.add_child(made, true)
			made.transform = LevelData.transform_of(thing)
			if editing:
				_marker(made, Color(0.3, 0.9, 0.4))
		"exit":
			var bag := ExitBag.new()
			bag.name = "Exit"
			made = bag
			parent.add_child(made, true)
			made.transform = LevelData.transform_of(thing)
		"fly":
			var fly := Fly.new()
			fly.path = LevelData.path_of(thing)
			fly.speed = float(thing.get("speed", 2.5))
			fly.loops = bool(thing.get("loop", true))
			made = fly
			made.transform = LevelData.transform_of(thing)
			parent.add_child(made, true)
			if editing:
				fly.set_physics_process(false)
				_path_line(parent, made, fly.path, true, Color(1.0, 0.8, 0.3))
		"crate":
			var crate := Crate.new()
			made = crate
			made.transform = LevelData.transform_of(thing)
			if editing:
				crate.freeze = true
			parent.add_child(made, true)
		"plate":
			var plate := PressurePlate.new()
			plate.channel = String(thing.get("channel", "a"))
			made = plate
			parent.add_child(made, true)
			made.transform = LevelData.transform_of(thing)
		"door":
			var door := SlideDoor.new()
			door.channel = String(thing.get("channel", "a"))
			door.open_by = LevelData.vec(thing.get("open"), Vector3(0.0, 4.2, 0.0))
			made = door
			made.transform = LevelData.transform_of(thing)
			parent.add_child(made, true)
			PieceLook.dress(door, String(thing.get("piece", "cube")), size, surface, true)
			if editing:
				_path_line(parent, made, PackedVector3Array([made.position,
					made.position + door.open_by]), false, Color(0.4, 0.8, 0.9))
		"platform":
			var platform := MovingPlatform.new()
			platform.path = LevelData.path_of(thing)
			platform.speed = float(thing.get("speed", 3.0))
			platform.wait = float(thing.get("wait", 0.8))
			platform.loops = bool(thing.get("loop", false))
			platform.channel = String(thing.get("channel", ""))
			made = platform
			made.transform = LevelData.transform_of(thing)
			parent.add_child(made, true)
			PieceLook.dress(platform, String(thing.get("piece", "cube5")), size,
				String(thing.get("surface", Surfaces.STONE)), true)
			if editing:
				platform.set_physics_process(false)
				_path_line(parent, made, platform.path, platform.loops, Color(0.9, 0.9, 0.5))
		"hazard":
			var hazard := Hazard.new()
			hazard.size = size
			made = hazard
			made.transform = LevelData.transform_of(thing)
			parent.add_child(made, true)
	if made == null:
		push_warning("A level thing of no type anything builds: %s" % type)
		return null
	made.set_meta(THING, thing)
	made.add_to_group(GROUP)
	return made


## The thing data a node was built from, walking up from whatever was clicked.
static func thing_of(node: Node) -> Node3D:
	while node != null:
		if node.has_meta(THING):
			return node as Node3D
		node = node.get_parent()
	return null


## A green arrow where the spider starts, pointing the way it faces.
static func _marker(on: Node3D, tint: Color) -> void:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = tint
	paint.emission_enabled = true
	paint.emission = tint
	paint.emission_energy_multiplier = 0.6
	var post := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.35
	cone.height = 0.9
	post.mesh = cone
	post.rotation.x = -PI * 0.5
	post.position = Vector3(0.0, 0.4, -0.3)
	post.material_override = paint
	on.add_child(post)
	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	ball.mesh = sphere
	ball.position.y = 0.4
	ball.material_override = paint
	on.add_child(ball)
	# Something to click.
	var pick := StaticBody3D.new()
	pick.collision_layer = 1 << 15
	var shape := CollisionShape3D.new()
	var round := SphereShape3D.new()
	round.radius = 0.5
	shape.shape = round
	shape.position.y = 0.4
	pick.add_child(shape)
	on.add_child(pick)


## A line through [param points], drawn for the editor, owned by [param owner_node]
## so it goes when the thing does.
static func _path_line(_parent: Node3D, owner_node: Node3D, points: PackedVector3Array,
		closed: bool, tint: Color) -> void:
	if points.size() < 2:
		return
	var mesh := ImmediateMesh.new()
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.albedo_color = tint
	paint.no_depth_test = true
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, paint)
	var count := points.size() if closed and points.size() >= 3 else points.size() - 1
	for i in count:
		mesh.surface_add_vertex(points[i])
		mesh.surface_add_vertex(points[(i + 1) % points.size()])
	mesh.surface_end()
	var view := MeshInstance3D.new()
	view.name = "PathLine"
	view.mesh = mesh
	view.top_level = true
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	owner_node.add_child(view)
	view.global_transform = Transform3D.IDENTITY
	for point in points:
		var dot := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.12
		sphere.height = 0.24
		dot.mesh = sphere
		dot.material_override = paint
		dot.top_level = true
		owner_node.add_child(dot)
		dot.global_position = point
