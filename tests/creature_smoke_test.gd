extends TestSuite

## Headless check on the creatures' bodies.
##
##     godot --headless --path . --script res://tests/creature_smoke_test.gd
##
## Every species that has a body is let loose in an empty room and watched. It has
## to be built from that body — a skeleton, and one mesh on its bones, shared by
## every creature of its kind — and it has to hold itself the way what it is doing
## says: facing where it goes, wings beating in flight, feet on the floor if it
## walks, legs thrashing when it is caught, and everything folded up and still
## once it is wrapped. How it looks is for the eye, and
## tests/screenshot_creatures.gd is for that.

var _room: Node3D


func run_checks() -> void:
	_room = _build_room()
	await stage(_room)
	var bodied := 0
	for kind in PreyLibrary.load_species():
		if kind.body == null:
			continue
		bodied += 1
		await _test_species(kind)
	check(bodied > 0, "some creatures are drawn from bodies (%d)" % bodied)


func _test_species(kind: PreySpecies) -> void:
	var label := kind.display_name.to_lower()
	var one := ("an " if "aeiou".contains(label.left(1)) else "a ") + label
	var radius := kind.body_radius
	var prey := _put_down(kind)
	await run_frames(3)
	var view := prey.get_node_or_null("Body") as CreatureView
	if not check(view != null, "%s is drawn from its body" % one):
		prey.free()
		return
	check(prey.get_node_or_null("Hitbox") != null, "and still has a hitbox to shoot")
	check(is_equal_approx(view.scale.x, radius),
		"at the size its species says (%.3fm)" % view.scale.x)
	_check_bones(view, label)
	var twin := _put_down(kind)
	await run_frames(2)
	var other := twin.get_node_or_null("Body") as CreatureView
	check(other != null and other.shell.mesh == view.shell.mesh,
		"and every %s shares the one mesh" % label)
	twin.free()

	var motion := view.motion as InsectMotion
	if not check(motion != null, "moved by an insect's motion"):
		prey.free()
		return
	if kind.flying:
		await _check_flight(prey, view, motion)
	else:
		await _check_walk(prey, view, motion)
	await _check_caught(prey, view, motion)
	await _check_wrapped(prey, view, motion)
	prey.free()
	await run_frames(2)


## The bones an insect has to have, and a mesh with every vertex on one of them.
func _check_bones(view: CreatureView, label: String) -> void:
	var skeleton := view.skeleton
	var body := view.body as InsectBody
	var missing: Array[String] = []
	var wanted: Array[String] = ["Thorax", "Head", "Abdomen", "Antenna.L.1", "Antenna.R.2"]
	for pair in 3:
		for side in 2:
			for part in 3:
				wanted.append(InsectBody.leg_bone(pair, side, part))
	for hind in body.wing_pairs:
		for side in 2:
			wanted.append(InsectBody.wing_bone(hind == 1, side))
	for bone in wanted:
		if skeleton.find_bone(bone) < 0:
			missing.append(bone)
	check(missing.is_empty(), "with six legs, two feelers and %d wings (%s missing)"
		% [body.wing_pairs * 2, ", ".join(missing) if not missing.is_empty() else "none"])
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


## Left to fly about: facing where it goes, and its wings beating.
func _check_flight(prey: Prey, view: CreatureView, motion: InsectMotion) -> void:
	var facing := 0
	var moving := 0
	var low := INF
	var high := -INF
	await run_frames(30)
	for i in 90:
		await physics_frame
		var flat := Vector3(prey.velocity.x, 0.0, prey.velocity.z)
		if flat.length() > prey.move_speed * 0.3:
			moving += 1
			var ahead := -view.global_basis.z
			ahead.y = 0.0
			if ahead.normalized().dot(flat.normalized()) > 0.85:
				facing += 1
		var tip := view.to_local(motion.wing_tips()[0])
		low = minf(low, tip.y)
		high = maxf(high, tip.y)
	check(moving > 30 and facing >= moving * 0.8,
		"flying, it faces the way it is going (%d of %d frames)" % [facing, moving])
	check(high - low > 0.5, "and its wings beat (the tips sweep %.2f body radii)" % (high - low))


## Left to walk about: facing where it goes, its feet on the floor and stepping.
func _check_walk(prey: Prey, view: CreatureView, motion: InsectMotion) -> void:
	var facing := 0
	var moving := 0
	var sweep := 0.0
	var start := Vector3.ZERO
	await run_frames(30)
	for i in 90:
		await physics_frame
		var flat := Vector3(prey.velocity.x, 0.0, prey.velocity.z)
		if flat.length() > prey.move_speed * 0.3:
			moving += 1
			var ahead := -view.global_basis.z
			ahead.y = 0.0
			if ahead.normalized().dot(flat.normalized()) > 0.85:
				facing += 1
		var foot := view.to_local(motion.feet()[0])
		if i == 0:
			start = foot
		sweep = maxf(sweep, foot.distance_to(start))
	check(moving > 30 and facing >= moving * 0.8,
		"walking, it faces the way it is going (%d of %d frames)" % [facing, moving])
	check(sweep > 0.15, "and its legs step (a foot swings %.2f body radii)" % sweep)
	# Standing still, every foot is down.
	var was := prey.velocity
	prey.set_physics_process(false)
	prey.velocity = Vector3.ZERO
	await run_frames(40)
	var worst := 0.0
	for foot in motion.feet():
		worst = maxf(worst, absf(foot.y))
	var radius := _radius_of(prey)
	check(worst < radius * 0.3,
		"standing, its feet are on the floor (%.2f body radii off at most)" % (worst / radius))
	prey.velocity = was
	prey.set_physics_process(true)


## Caught: the legs thrash, far more than they move standing about. Held caught
## rather than put in a web, so this is at its gentlest — the thrashing a catch
## that has almost fought itself out still does.
func _check_caught(prey: Prey, view: CreatureView, motion: InsectMotion) -> void:
	prey.set_physics_process(false)
	prey.velocity = Vector3.ZERO
	view.held = CreatureMotion.Pose.WALKING
	await run_frames(30)
	var still := await _feet_sweep(view, motion, 40)
	view.held = CreatureMotion.Pose.STRUGGLING
	await run_frames(20)
	var thrash := await _feet_sweep(view, motion, 40)
	check(thrash > 0.2 and thrash > still * 4.0,
		"caught, its legs thrash (%.2f body radii, against %.2f standing)" % [thrash, still])
	view.held = -1
	prey.set_physics_process(true)


## How far any foot strays from where it started, over [param count] frames, in
## body radii.
func _feet_sweep(view: CreatureView, motion: InsectMotion, count: int) -> float:
	var sweep := 0.0
	var first := PackedVector3Array()
	for i in count:
		await physics_frame
		var feet := motion.feet()
		for leg in feet.size():
			var foot := view.to_local(feet[leg])
			if i == 0:
				first.append(foot)
			else:
				sweep = maxf(sweep, foot.distance_to(first[leg]))
	return sweep


## Wrapped where it is: it curls up and goes still — wings folded, legs in.
func _check_wrapped(prey: Prey, view: CreatureView, motion: InsectMotion) -> void:
	var spread := _spread_of(view, motion)
	check(prey.bundle(), "it can be wrapped up")
	await run_frames(60)
	var body := view.body as InsectBody
	if body.wing_pairs > 0:
		var before := view.to_local(motion.wing_tips()[0])
		await run_frames(10)
		var after := view.to_local(motion.wing_tips()[0])
		check(before.distance_to(after) < 0.03,
			"wrapped, its wings stop (%.3f body radii of movement)" % before.distance_to(after))
		var folded := true
		for tip in motion.wing_tips():
			var local := view.to_local(tip)
			if body.wings_up:
				folded = folded and local.y > 0.5
			else:
				folded = folded and local.z > 0.0
		check(folded, "and are folded, over its back rather than out to the sides")
	var curled := _spread_of(view, motion)
	check(curled < spread * 0.85,
		"and its legs curl in (feet %.2f body radii out, from %.2f)" % [curled, spread])


## How far out from the middle of the body its feet are, on average, in body radii.
func _spread_of(view: CreatureView, motion: InsectMotion) -> float:
	var total := 0.0
	var feet := motion.feet()
	for foot in feet:
		total += view.to_local(foot).length()
	return total / maxf(float(feet.size()), 1.0)


func _radius_of(prey: Prey) -> float:
	return prey.kind.body_radius if prey.kind != null else 0.045


func _put_down(kind: PreySpecies) -> Prey:
	var prey := Prey.of(kind)
	_room.add_child(prey)
	var lift := kind.body_radius * (3.0 if kind.flying else Prey.HITBOX_SCALE + 0.05)
	prey.global_position = Vector3(0.0, lift, 0.0)
	return prey


func _build_room() -> Node3D:
	var room := Node3D.new()
	room.name = "Room"
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = GameLayers.WORLD
	floor_body.position = Vector3(0.0, -0.1, 0.0)
	var shape := BoxShape3D.new()
	shape.size = Vector3(40.0, 0.2, 40.0)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	floor_body.add_child(collider)
	room.add_child(floor_body)
	return room
