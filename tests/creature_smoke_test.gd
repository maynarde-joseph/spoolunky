extends TestSuite

## Headless check on the insects' bodies.
##
##     godot --headless --path . --script res://tests/creature_smoke_test.gd
##
## Every kind of insect the farm raises gets let loose in an empty room and
## watched. It has to be built from its body — a skeleton, one mesh on its bones
## shared by every insect of its kind, and a motion that finds every bone it poses
## — and it has to hold itself the way what it is doing says: facing where it
## goes, beating its wings if it flies, feet on the floor if it walks, and curled
## up and still once it is wrapped. It has to grow, too: a hatchling is drawn
## smaller than a grown one. How it looks is for the eye, and
## tests/screenshot_farm.gd is for that.

var _room: Node3D


func run_checks() -> void:
	_room = _build_room()
	await stage(_room)
	var kinds := Catalogue.insects()
	check(not kinds.is_empty(), "there are insects to check (%d)" % kinds.size())
	for kind in kinds:
		await _test_body(kind)


func _test_body(kind: InsectSpecies) -> void:
	var label := kind.display_name.to_lower()
	var one := ("an " if "aeiou".contains(label.left(1)) else "a ") + label
	var insect := _put_down(kind, 1.0)
	await run_frames(3)
	var view := insect.get_node_or_null("Body") as CreatureView
	if not check(view != null, "%s is drawn from its body" % one):
		insect.free()
		return
	check(insect.get_node_or_null("Hitbox") != null, "and has a hitbox for silk to hit")
	check(is_equal_approx(view.scale.x, kind.adult_radius),
		"grown, at the size its species says (%.3fm)" % view.scale.x)
	_check_build(view)
	var young := _put_down(kind, 0.0)
	await run_frames(2)
	var other := young.get_node_or_null("Body") as CreatureView
	check(other != null and other.shell.mesh == view.shell.mesh,
		"and every %s shares the one mesh" % label)
	check(other != null and other.scale.x < view.scale.x * 0.6,
		"a hatchling is drawn smaller (%.2f of grown)" % (other.scale.x / view.scale.x if other != null else 0.0))
	young.free()
	var motion := view.motion
	if kind.flying:
		await _check_flight(insect, view, motion)
	else:
		await _check_walk(insect, view, motion)
	await _check_caught(insect, view, motion)
	await _check_wrapped(insect, view, motion)
	insect.free()
	await run_frames(2)


## A skeleton, a motion that finds every bone it poses, and one mesh with every
## vertex on one of them.
func _check_build(view: CreatureView) -> void:
	var skeleton := view.skeleton
	var missing := view.motion.missing()
	check(skeleton.get_bone_count() > 1 and missing.is_empty(),
		"on a skeleton of %d bones, every one its motion poses among them (%s missing)"
		% [skeleton.get_bone_count(), ", ".join(missing) if not missing.is_empty() else "none"])
	var stray := 0
	var mesh := view.shell.mesh as ArrayMesh
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var ids: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		for v in range(0, ids.size(), 4):
			if ids[v] < 0 or ids[v] >= skeleton.get_bone_count() or not is_equal_approx(weights[v], 1.0):
				stray += 1
	check(stray == 0 and view.shell.skin != null,
		"one mesh, every vertex on a bone of its own skeleton (%d not)" % stray)


## Left to fly about: facing where it goes, and beating its wings.
func _check_flight(insect: Insect, view: CreatureView, motion: CreatureMotion) -> void:
	var facing := 0
	var moving := 0
	await run_frames(30)
	var first := _local(view, motion.strokes())
	var sweep := 0.0
	for i in 150:
		await physics_frame
		var flat := Vector3(insect.velocity.x, 0.0, insect.velocity.z)
		if flat.length() > insect.pace() * 0.3:
			moving += 1
			var ahead := -view.global_basis.z
			ahead.y = 0.0
			if ahead.normalized().dot(flat.normalized()) > 0.85:
				facing += 1
		sweep = maxf(sweep, _furthest(first, _local(view, motion.strokes())))
	check(moving > 30 and facing >= moving * 0.75,
		"flying about, it faces the way it is going (%d of %d frames)" % [facing, moving])
	check(not first.is_empty() and sweep > 0.5,
		"and beats its wings (%d tips, sweeping %.2f body radii)" % [first.size(), sweep])


## Left to walk about: facing where it goes, its feet on the floor and stepping.
func _check_walk(insect: Insect, view: CreatureView, motion: CreatureMotion) -> void:
	var facing := 0
	var moving := 0
	var sweep := 0.0
	var start := Vector3.ZERO
	await run_frames(30)
	if not check(not motion.feet().is_empty(), "walking, it has feet to walk on"):
		return
	for i in 120:
		await physics_frame
		var flat := Vector3(insect.velocity.x, 0.0, insect.velocity.z)
		if flat.length() > insect.pace() * 0.3:
			moving += 1
			var ahead := -view.global_basis.z
			ahead.y = 0.0
			if ahead.normalized().dot(flat.normalized()) > 0.85:
				facing += 1
		var foot := view.to_local(motion.feet()[0])
		if i == 0:
			start = foot
		sweep = maxf(sweep, foot.distance_to(start))
	check(moving > 30 and facing >= moving * 0.75,
		"walking, it faces the way it is going (%d of %d frames)" % [facing, moving])
	check(sweep > 0.15, "and its legs step (a foot swings %.2f body radii)" % sweep)


## Held struggling: it thrashes, far more than it moves standing about.
func _check_caught(insect: Insect, view: CreatureView, motion: CreatureMotion) -> void:
	insect.set_physics_process(false)
	insect.velocity = Vector3.ZERO
	view.held = CreatureMotion.Pose.WALKING
	await run_frames(30)
	var still := await _ends_sweep(view, motion, 40)
	view.held = CreatureMotion.Pose.STRUGGLING
	motion.effort = 1.0
	await run_frames(20)
	var thrash := await _ends_sweep(view, motion, 40)
	check(thrash > 0.2 and thrash > still * 2.0,
		"struggling, it thrashes (%.2f body radii, against %.2f standing)" % [thrash, still])
	view.held = -1
	insect.set_physics_process(true)
	if kind_walks(insect):
		await run_frames(40)
		var worst := 0.0
		for foot in motion.feet():
			worst = maxf(worst, absf(foot.y))
		check(worst < insect.radius() * 0.4,
			"standing, its feet are on the floor (%.2f body radii off at most)" % (worst / insect.radius()))


func kind_walks(insect: Insect) -> bool:
	return not insect.flies()


## Wrapped where it is: it curls up and goes still, wings folded, in a bundle that
## rests on the floor.
func _check_wrapped(insect: Insect, view: CreatureView, motion: CreatureMotion) -> void:
	var limbs := motion.feet()
	var spread := _spread_of(_local(view, limbs))
	check(insect.wrap(), "it can be wrapped up")
	await run_frames(60)
	var before := _local(view, _ends(motion))
	await run_frames(10)
	var moved := _furthest(before, _local(view, _ends(motion)))
	check(moved < 0.03, "wrapped, it goes still (%.3f body radii of movement)" % moved)
	var body := view.body as InsectBody
	if body != null and body.wing_pairs > 0:
		var folded := true
		for tip in motion.strokes():
			var local := view.to_local(tip)
			if body.wings_up:
				folded = folded and local.y > 0.5
			else:
				folded = folded and local.z > 0.0
		check(folded, "with its wings folded over its back rather than out to the sides")
	var curled := _spread_of(_local(view, motion.feet()))
	check(curled < spread * 0.9, "and its legs curl in (%.2f body radii out, from %.2f)" % [curled, spread])
	var cocoon := view.get_node_or_null("Cocoon") as MeshInstance3D
	check(cocoon != null and cocoon.visible, "and there is a bundle of silk round it")
	check(insect.is_on_floor() and insect.global_position.y < insect.radius() * 1.3,
		"lying on the floor (%.2fm up)" % insect.global_position.y)


## Every end it draws: feet, and what it flies or swims with. A copy: a packed
## array is handed over by reference, and appending to the motion's own list of
## feet would give it wings until it next drew them.
func _ends(motion: CreatureMotion) -> PackedVector3Array:
	var ends := motion.feet().duplicate()
	ends.append_array(motion.strokes())
	return ends


## How far any end strays from where it started, over [param count] frames, in
## body radii.
func _ends_sweep(view: CreatureView, motion: CreatureMotion, count: int) -> float:
	await physics_frame
	var first := _local(view, _ends(motion))
	var sweep := 0.0
	for i in count - 1:
		await physics_frame
		sweep = maxf(sweep, _furthest(first, _local(view, _ends(motion))))
	return sweep


## The points in the body's own space, which is in body radii.
func _local(view: CreatureView, points: PackedVector3Array) -> PackedVector3Array:
	var local := PackedVector3Array()
	for point in points:
		local.append(view.to_local(point))
	return local


## The furthest any point in [param now] is from the same one in [param was].
func _furthest(was: PackedVector3Array, now: PackedVector3Array) -> float:
	var most := 0.0
	for i in mini(was.size(), now.size()):
		most = maxf(most, was[i].distance_to(now[i]))
	return most


## How far out from the middle of the body the points are, on average.
func _spread_of(points: PackedVector3Array) -> float:
	var total := 0.0
	for point in points:
		total += point.length()
	return total / maxf(float(points.size()), 1.0)


func _put_down(kind: InsectSpecies, grown: float) -> Insect:
	var insect := Insect.of(kind, grown)
	_room.add_child(insect)
	var lift := kind.adult_radius * (3.0 if kind.flying else Insect.HITBOX_SCALE + 0.05)
	insect.global_position = Vector3(0.0, lift, 0.0)
	return insect


func _build_room() -> Node3D:
	var room := Node3D.new()
	room.name = "Room"
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = GameLayers.WORLD
	floor_body.position = Vector3(0.0, -0.1, 0.0)
	var shape := BoxShape3D.new()
	shape.size = Vector3(200.0, 0.2, 200.0)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	floor_body.add_child(collider)
	room.add_child(floor_body)
	return room
