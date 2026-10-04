extends TestSuite

## Headless check on the places built from the kit, and on the kit itself.
##
##     godot --headless --script res://tests/world_smoke_test.gd
##
## A level's job is to be the right shape, so that is what is checked. Every piece
## of the kit comes in solid, on the world layer, centred on its origin with its
## base on the ground, and a stretched block is the size it says and collides as the
## shape it looks.
##
## Every place opens with the spider standing where it was put, at one size with
## every spell open, under open sky, in a place the HUD names, among stone that is
## all something to stand on. Then each is checked for what it is: the colosseum
## walled round its sand with a gate in each end and side, the floor fallen into the
## passages in the middle and the outside wall fallen on the south; the cathedral
## roofless, its great door open, one tower whole and one broken; the castle's gate
## low enough to walk under the portcullis, its breach open and its stairs reaching
## the wall-walk; the aqueduct's channel walkable high up and broken by a gap a
## grapple can cross; the watchtower ragged at the top with floors inside and a
## broken bridge; and the temple walled with its gates, tiers, aisles and rim. The
## game opens in the colosseum, and the spider can walk about in it.
##
## None of this looks at how it plays — that is what opening each one is for.
##
## The dungeon is checked room by room and floor by floor: every room the same
## square, with its doorways where it says, each bricked up until it is opened and a
## way through once it is, and wall everywhere else; floors laid out from the top row
## to the bottom with every room reachable and fitted to its doorways, the same seed
## the same floor; and a floor put down with its doorways lining up room to room, the
## spider at the way in, and the pit taking it down to the next.
##
## The training dummies are checked here too, on posts stood up for the purpose:
## they are part of the world rather than of any one place.

func run_checks() -> void:
	_test_the_pieces()
	await _test_a_block()
	check(str(ProjectSettings.get_setting("application/run/main_scene")) == Colosseum.SCENE,
		"the game opens in the colosseum")
	for place in Site.PLACES:
		await _test_place(place)
	for room_id in Rooms.ROOMS:
		await _test_room(room_id)
	_test_floor_plans()
	await _test_the_dungeon()
	await _test_the_dummies()


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, GameLayers.WORLD)
	var world := (current_scene as Node3D).get_world_3d()
	return world.direct_space_state.intersect_ray(query)


## How far along [param from] to [param to] the first solid thing is, or -1 for
## nothing in the way.
func _reach(from: Vector3, to: Vector3) -> float:
	var hit := _ray(from, to)
	return from.distance_to(hit.position) if not hit.is_empty() else -1.0


# --- the kit ----------------------------------------------------------------

## Every piece in `Pieces/`, through the import: a body on the world layer with a
## collider, its footprint centred on its origin and its base on the ground. That is
## what makes a piece dropped at a point stand on that point, and anything you can
## see something you can stand on and stick silk to.
func _test_the_pieces() -> void:
	var names := Kit.names()
	if not check(names.size() >= 70, "the kit is here (%d pieces)" % names.size()):
		return
	var loose := PackedStringArray()
	var off_centre := PackedStringArray()
	var hollow := PackedStringArray()
	var one_sided := PackedStringArray()
	var sheets := 0
	for piece in names:
		var made := (load(Kit.path_of(piece)) as PackedScene).instantiate()
		var body := made as StaticBody3D
		if body == null or body.collision_layer != GameLayers.WORLD or body.collision_mask != 0:
			loose.append(piece)
		var box := AABB()
		var first := true
		var shapes := 0
		var sheet := false
		var backed := true
		for child in made.get_children():
			var view := child as MeshInstance3D
			if view != null and view.mesh != null:
				var seen := view.transform * view.mesh.get_aabb()
				box = seen if first else box.merge(seen)
				first = false
				sheet = sheet or _open(view.mesh)
			var solid := child as CollisionShape3D
			if solid != null and solid.shape != null:
				shapes += 1
				var trimesh := solid.shape as ConcavePolygonShape3D
				if trimesh != null and not trimesh.backface_collision:
					backed = false
		if shapes == 0:
			hollow.append(piece)
		if absf(box.get_center().x) > 0.01 or absf(box.get_center().z) > 0.01 \
				or absf(box.position.y) > 0.01:
			off_centre.append(piece)
		if sheet:
			sheets += 1
			if not backed:
				one_sided.append(piece)
		made.free()
	check(loose.is_empty(), "every piece is a body on the world layer %s" % loose)
	check(hollow.is_empty(), "with something to collide with %s" % hollow)
	check(off_centre.is_empty(),
		"centred on its origin with its base on the ground %s" % off_centre)
	check(sheets > 0 and one_sided.is_empty(),
		"and the %d that are sheets stop you from both sides %s" % [sheets, one_sided])

	# A piece added later comes in the same way, without anyone remembering to set
	# it up: the project's default for scenes names the same script.
	var defaults: Dictionary = ProjectSettings.get_setting("importer_defaults/scene", {})
	check(str(defaults.get("import_script/path", "")) == "res://tools/kit_import.gd",
		"and a piece added later is imported the same way")


## Whether a mesh has an edge only one of its faces uses: some of it is a sheet
## rather than the skin of a solid. Worked out here rather than asked of the import,
## so the check does not take the importer's word for what it did.
func _open(mesh: Mesh) -> bool:
	var uses := {}
	var faces := mesh.get_faces()
	for i in range(0, faces.size(), 3):
		for j in 3:
			var a := str(faces[i + j].snappedf(0.0001))
			var b := str(faces[i + (j + 1) % 3].snappedf(0.0001))
			var edge := a + "|" + b if a < b else b + "|" + a
			uses[edge] = int(uses.get(edge, 0)) + 1
	return uses.values().has(1)


## A block is the size it says: its look stretched to fit and its collider the same
## stretched shape, so what you see is what you stand on — a doorway made bigger is
## still a doorway — and changing its size changes both.
func _test_a_block() -> void:
	var holder := Node3D.new()
	var block := KitBlock.make(holder, "Block", "wall", Vector3(10.0, 3.0, 2.0), Transform3D.IDENTITY)
	KitBlock.make(holder, "Door", "wall door", Vector3(8.0, 12.0, 2.0),
		Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 20.0)))
	await stage(holder)
	await run_frames(2)
	check(_solid_box(block).size.is_equal_approx(Vector3(10.0, 3.0, 2.0)),
		"a block collides as the size it says (%s)" % _solid_box(block).size)
	var seen := _seen(block)
	check(seen.size.is_equal_approx(Vector3(10.0, 3.0, 2.0)) and absf(seen.position.y) < 0.01,
		"and looks it, standing on its origin (%s)" % seen)
	var top := _reach(Vector3(3.0, 10.0, 0.0), Vector3(3.0, -1.0, 0.0))
	check(absf(top - 7.0) < 0.05, "and you stand on its top (%.2f down)" % top)
	# The kit's doorway is half its width and three quarters of its height; at eight
	# by twelve that is a way through four wide and nine high.
	check(_reach(Vector3(0.0, 4.0, 10.0), Vector3(0.0, 4.0, 30.0)) < 0.0,
		"a doorway made bigger is still a way through")
	check(_reach(Vector3(0.0, 10.5, 10.0), Vector3(0.0, 10.5, 30.0)) > 0.0
			and _reach(Vector3(3.0, 4.0, 10.0), Vector3(3.0, 4.0, 30.0)) > 0.0,
		"with wall over it and either side")
	block.size = Vector3(4.0, 6.0, 4.0)
	await run_frames(2)
	check(_solid_box(block).size.is_equal_approx(Vector3(4.0, 6.0, 4.0))
			and _seen(block).size.is_equal_approx(Vector3(4.0, 6.0, 4.0)),
		"and a new size changes both")
	close()


## The box round what a block collides as.
func _solid_box(block: KitBlock) -> AABB:
	for child in block.get_children(true):
		var solid := child as CollisionShape3D
		if solid != null and solid.shape is ConcavePolygonShape3D:
			var faces := (solid.shape as ConcavePolygonShape3D).get_faces()
			var box := AABB(faces[0], Vector3.ZERO)
			for point in faces:
				box = box.expand(point)
			return box
	return AABB()


func _seen(block: KitBlock) -> AABB:
	for child in block.get_children(true):
		var view := child as MeshInstance3D
		if view != null and view.mesh != null:
			return view.transform * view.mesh.get_aabb()
	return AABB()


# --- the places -------------------------------------------------------------

## What every place has to be: somewhere to start, standing, at one size with every
## spell, under open sky, in a place the HUD names, among stone that is all solid —
## and then what this one in particular has to be.
func _test_place(place: String) -> void:
	var builder := Site.builder(place)
	if not check(builder != null, "%s has a builder" % place):
		return
	var constants := builder.get_script_constant_map()
	var level := await open(constants["SCENE"])
	if level == null:
		return
	var spider := root.get_tree().get_first_node_in_group("spider") as SpiderPlayer
	if not check(spider != null, "%s: there is a spider in it" % place):
		return
	spider.require_captured_mouse = false
	await run_frames(60)
	var start: Vector3 = constants["START"]
	check(spider.growth.stage_index == 2 and not spider.growth.grows and not spider.traits.evolving
			and spider.spells.open_spells().size() == spider.spells.book.size(),
		"%s: the spider is a Huntsman that stays one, with every spell open" % place)
	check(spider.is_on_floor() and Vector2(spider.global_position.x - start.x,
			spider.global_position.z - start.z).length() < 1.0,
		"%s: and stands where it was put (%s)" % [place, spider.global_position])
	check(_reach(spider.global_position + Vector3.UP, spider.global_position + Vector3.UP * 80.0) < 0.0,
		"%s: under open sky" % place)
	var here := Zone.at(root.get_tree(), spider.global_position)
	check(here != null and here.display_name == constants["NAME"],
		"%s: which the HUD calls %s (%s)" % [place, constants["NAME"],
			here.display_name if here != null else "nothing"])
	var bodies := 0
	var loose := PackedStringArray()
	for node in all_under(level):
		var body := node as StaticBody3D
		if body == null:
			continue
		bodies += 1
		if body.collision_layer & GameLayers.WORLD == 0:
			loose.append(body.name)
	check(bodies > 60 and loose.is_empty(),
		"%s: all %d solids in it are on the world layer %s" % [place, bodies, loose])
	match place:
		"colosseum":
			await _shape_colosseum(spider)
		"cathedral":
			_shape_cathedral()
		"castle":
			_shape_castle()
		"aqueduct":
			_shape_aqueduct(spider)
		"watchtower":
			_shape_watchtower(spider)
		"temple":
			_shape_temple()
	release_all()


# --- the dungeon ------------------------------------------------------------

## Every room is the same square: its doorways where it says, each bricked up with a
## plug that stops anything going through until it is opened and a way through once
## it is, solid wall on every other side, a roof over it, everything in it solid on the
## world layer, and the marks its job needs.
func _test_room(room_id: String) -> void:
	var packed := load(Rooms.scene_of(room_id)) as PackedScene
	if not check(packed != null, "%s: the room is baked" % room_id):
		return
	var room := packed.instantiate() as DungeonRoom
	if not check(room != null and room.room_id == room_id,
			"%s: its scene is a room that knows its name" % room_id):
		return
	var holder := Node3D.new()
	holder.add_child(room)
	await stage(holder)
	await physics_frame
	var doors := Rooms.doors_of(room_id)
	check(room.doors == doors and not doors.is_empty(),
		"%s: with doorways on %s" % [room_id, _sides(doors)])
	check(room.height >= Rooms.FRAME.y, "%s: tall enough inside for a doorway's frame (%.0f m)"
		% [room_id, room.height])
	var unplugged := PackedStringArray()
	var gaps := PackedStringArray()
	for side in 4:
		var blocked := _reach(_beside_door(side, -3.0), _beside_door(side, 2.0)) >= 0.0
		if room.has_door(side) and (room.plug(side) == null or not blocked):
			unplugged.append(Rooms.SIDE_NAMES[side])
		elif not room.has_door(side) and not blocked:
			gaps.append(Rooms.SIDE_NAMES[side])
	check(unplugged.is_empty(), "%s: every doorway bricked up with its plug to begin with %s"
		% [room_id, unplugged])
	check(gaps.is_empty(), "%s: and solid wall where there is no doorway %s" % [room_id, gaps])
	for side in doors:
		room.open(side)
	await physics_frame
	await physics_frame
	var shut := PackedStringArray()
	for side in doors:
		if not room.is_open(side) or _reach(_beside_door(side, -3.0), _beside_door(side, 2.0)) >= 0.0:
			shut.append(Rooms.SIDE_NAMES[side])
	check(shut.is_empty(), "%s: opened, every doorway is a way through %s" % [room_id, shut])
	check(_reach(Vector3(5.0, 2.0, 5.0), Vector3(5.0, 40.0, 5.0)) > 0.0,
		"%s: and there is a roof over it" % room_id)
	var loose := PackedStringArray()
	var bodies := 0
	for node in all_under(room):
		var body := node as StaticBody3D
		if body != null:
			bodies += 1
			if body.collision_layer & GameLayers.WORLD == 0:
				loose.append(body.name)
	check(bodies > 15 and loose.is_empty(),
		"%s: all %d solids in it on the world layer %s" % [room_id, bodies, loose])
	if Rooms.role_of(room_id) != Rooms.ENTRANCE:
		check(room.spawns().size() >= 2,
			"%s: with places for creatures to stand (%d)" % [room_id, room.spawns().size()])
	match Rooms.role_of(room_id):
		Rooms.ENTRANCE:
			check(room.entry() != null, "%s: a way in, with a mark where the spider comes in"
				% room_id)
		Rooms.EXIT:
			var drop := room.way_down()
			check(drop != null and drop.collision_mask & GameLayers.PLAYER != 0,
				"%s: a way down, with a drop that knows the spider" % room_id)
	match room_id:
		"entrance":
			var entry := room.entry()
			check(entry != null and _reach(entry.global_position, entry.global_position
				+ Vector3.UP * 40.0) < 0.0, "entrance: the way in comes down a shaft through its roof")
		"pit":
			var drop := room.way_down()
			check(drop != null and drop.global_position.y < -5.0,
				"pit: its way down is at the bottom of a shaft")
			check(_reach(Vector3(0.0, 1.0, 0.0), Vector3(0.0, -15.0, 0.0)) < 0.0,
				"pit: and the shaft goes on down past it")
		"chasm":
			check(_reach(Vector3(0.0, 1.0, 0.0), Vector3(0.0, -8.0, 0.0)) < 0.0,
				"chasm: its bridge is broken over a drop")
		"vault":
			check(room.get_node_or_null("Marks/Loot") != null, "vault: with somewhere to leave the loot")
	close()


## A point [param out] metres out from a room's wall on [param side], through the
## middle of where its doorway would be, two metres up.
func _beside_door(side: int, out: float) -> Vector3:
	return Rooms.FACING[side] * (Rooms.CELL * 0.5 + out) + Vector3.UP * 2.0


func _sides(sides: Array[int]) -> String:
	var named := PackedStringArray()
	for side in sides:
		named.append(Rooms.SIDE_NAMES[side])
	return ", ".join(named)


## A floor is laid out the Spelunky way: from a room in the top row to one in the
## bottom, the way in and the way down at the two ends, every room reachable from the
## way in, every open doorway open from both sides, every room with a doorway
## wherever its square has one open, and every room only where what it is for says.
## Across many floors every room turns up, and no floor is too small to be worth going
## down to. The same seed lays out the same floor.
func _test_floor_plans() -> void:
	var misplaced := PackedStringArray()
	var unreachable := PackedStringArray()
	var lopsided := PackedStringArray()
	var unfit := PackedStringArray()
	var astray := PackedStringArray()
	var kinds := {}
	var sizes := Vector2i(1000, 0)
	for floor_seed in range(1, 201):
		var plan := FloorPlan.make(floor_seed)
		sizes = Vector2i(mini(sizes.x, plan.cells.size()), maxi(sizes.y, plan.cells.size()))
		if plan.start.y != 0 or plan.finish.y != FloorPlan.ROWS - 1 \
				or Rooms.role_of(plan.cells[plan.start]["room"]) != Rooms.ENTRANCE \
				or Rooms.role_of(plan.cells[plan.finish]["room"]) != Rooms.EXIT:
			misplaced.append(str(floor_seed))
		if plan.reachable() != plan.cells.size():
			unreachable.append(str(floor_seed))
		for cell: Vector2i in plan.cells:
			var info: Dictionary = plan.cells[cell]
			var open: Array[int] = []
			open.assign(info["open"])
			for side in open:
				if not plan.is_open(FloorPlan.beside(cell, side), posmod(side + 2, 4)):
					lopsided.append("%d %s" % [floor_seed, cell])
			var sides := Rooms.turned(Rooms.doors_of(info["room"]), info["turn"])
			for side in open:
				if not sides.has(side):
					unfit.append("%d %s %s" % [floor_seed, cell, info["room"]])
			var straight := open.size() == 2 and posmod(open[0] - open[1], 4) == 2
			match Rooms.role_of(info["room"]):
				Rooms.ENTRANCE, Rooms.EXIT:
					if cell != plan.start and cell != plan.finish:
						astray.append("%d %s %s" % [floor_seed, cell, info["room"]])
				Rooms.DEAD_END:
					if open.size() != 1:
						astray.append("%d %s %s" % [floor_seed, cell, info["room"]])
				Rooms.CROSSING:
					if not straight:
						astray.append("%d %s %s" % [floor_seed, cell, info["room"]])
			kinds[info["room"]] = int(kinds.get(info["room"], 0)) + 1
	check(misplaced.is_empty(), "200 floors: each from the way in on the top row to the way "
		+ "down on the bottom row %s" % misplaced)
	check(unreachable.is_empty(), "every room on every floor reachable from the way in %s"
		% unreachable)
	check(lopsided.is_empty(), "every open doorway open from both sides, into a room %s" % lopsided)
	check(unfit.is_empty(), "every room with a doorway wherever its square has one open %s" % unfit)
	check(astray.is_empty(), "every room where it is for: a way in or down only at the two ends, "
		+ "a room for a dead end only at one, a crossing only on a straight way %s" % astray)
	check(kinds.size() == Rooms.ROOMS.size(), "every room turns up (%s)" % str(kinds))
	check(sizes.x >= FloorPlan.LEAST, "a floor is %d to %d rooms, never fewer than %d"
		% [sizes.x, sizes.y, FloorPlan.LEAST])
	var once := FloorPlan.make(77)
	var again := FloorPlan.make(77)
	check(str(once.cells) == str(again.cells) and once.start == again.start,
		"the same seed lays out the same floor")
	check(str(FloorPlan.make(78).cells) != str(once.cells), "and another seed another")


## The dungeon opens on a floor put down from the rooms' scenes: a room in every
## square the plan fills, the doorways between them lining up into ways through and
## every other side shut, the spider at the way in and on its feet, and the HUD naming
## the floor. Dropping down the pit puts the next floor down in its place, laid out
## afresh, the spider in at its way in.
func _test_the_dungeon() -> void:
	var packed := load(Dungeon.SCENE) as PackedScene
	if not check(packed != null, "the dungeon is baked"):
		return
	var level := packed.instantiate()
	var run := level.get_node_or_null("Run") as DungeonRun
	if not check(run != null, "the dungeon has a run to lay its floors out"):
		level.free()
		return
	run.run_seed = 4242
	await stage(level)
	await run_frames(10)
	var spider := root.get_tree().get_first_node_in_group("spider") as SpiderPlayer
	if not check(spider != null, "the dungeon has a spider in it"):
		return
	spider.require_captured_mouse = false
	var plan := run.plan
	if not check(plan != null and run.rooms.size() == plan.cells.size()
			and plan.cells.size() >= FloorPlan.LEAST,
			"a floor is put down, a room in every square the plan fills (%d)" % run.rooms.size()):
		return
	var astray := PackedStringArray()
	var shut := PackedStringArray()
	var leaky := PackedStringArray()
	for cell: Vector2i in plan.cells:
		var room: DungeonRoom = run.rooms[cell]
		var centre := run.centre_of(cell)
		if room.global_position.distance_to(centre) > 0.01 or room.room_id != plan.cells[cell]["room"]:
			astray.append(str(cell))
		for side in 4:
			var facing := Rooms.FACING[side]
			var a := centre + facing * (Rooms.CELL * 0.5 - 2.5) + Vector3.UP * 2.0
			var b := centre + facing * (Rooms.CELL * 0.5 + 2.5) + Vector3.UP * 2.0
			var open := plan.is_open(cell, side)
			var blocked := _reach(a, b) >= 0.0
			if open and blocked:
				shut.append("%s %s" % [cell, Rooms.SIDE_NAMES[side]])
			elif not open and not blocked:
				leaky.append("%s %s" % [cell, Rooms.SIDE_NAMES[side]])
	check(astray.is_empty(), "each the room the plan says, in its square %s" % astray)
	check(run.entrance().global_position.distance_to(run.global_position) < 0.01,
		"with the way in under the run, wherever the plan put it")
	check(shut.is_empty(), "every doorway the plan opens is a way through into the next room %s"
		% shut)
	check(leaky.is_empty(), "and every other side is wall, or a doorway bricked up %s" % leaky)
	var way_in := run.entrance().entry().global_position
	check(Vector2(spider.global_position.x - way_in.x, spider.global_position.z - way_in.z).length()
		< 1.5, "the spider comes in at the way in")
	var landed: bool = await wait_until(func() -> bool: return spider.is_on_floor(), 180)
	check(landed, "and lands on its floor")
	var here := Zone.at(root.get_tree(), spider.global_position)
	check(here != null and here.display_name == "Floor 1",
		"which the HUD calls Floor 1 (%s)" % (here.display_name if here != null else "nothing"))
	var first := str(plan.cells)
	var drop := run.way_down()
	if not check(drop != null, "the floor has a way down"):
		return
	spider.global_position = drop.global_position
	var down: bool = await wait_until(func() -> bool: return run.floor_number == 2, 180)
	check(down, "dropping down the pit takes the spider down to floor 2")
	check(run.plan.seed != plan.seed and str(run.plan.cells) != first, "laid out afresh")
	way_in = run.entrance().entry().global_position
	check(Vector2(spider.global_position.x - way_in.x, spider.global_position.z - way_in.z).length()
		< 1.5, "with the spider in at its way in")
	await run_frames(5)
	here = Zone.at(root.get_tree(), spider.global_position)
	check(here != null and here.display_name == "Floor 2",
		"which the HUD calls Floor 2 (%s)" % (here.display_name if here != null else "nothing"))
	check(run.get_node_or_null("Floor1") == null and run.get_node_or_null("Floor2") != null,
		"and the floor above is taken up")
	release_all()
	close()


## How high the first solid thing is straight down from high over [param at].
func _top(at: Vector3) -> float:
	var hit := _ray(Vector3(at.x, 120.0, at.z), Vector3(at.x, -20.0, at.z))
	return (hit.position as Vector3).y if not hit.is_empty() else -INF


## The oval's radius at [param bearing] degrees from east towards south.
func _radius(across: float, deep: float, bearing: float) -> float:
	var turn := deg_to_rad(bearing)
	return 1.0 / sqrt(pow(cos(turn) / across, 2.0) + pow(sin(turn) / deep, 2.0))


func _shape_colosseum(spider: SpiderPlayer) -> void:
	# Walled all round the sand but at the gates, which are at the ends and sides.
	var open_sides := PackedStringArray()
	for bearing in range(20, 360, 30):
		var way := Vector3(cos(deg_to_rad(bearing)), 0.0, sin(deg_to_rad(bearing)))
		var wall := _radius(Colosseum.ARENA.x, Colosseum.ARENA.y, bearing)
		var reach := _reach(Vector3(0.0, 2.0, 0.0), way * 80.0 + Vector3(0.0, 2.0, 0.0))
		if reach < 0.0 or reach > wall + 0.6 or reach < wall - 1.5:
			open_sides.append("%d° at %.1f against %.1f" % [bearing, reach, wall])
	check(open_sides.is_empty(), "colosseum: the sand is walled all round %s" % open_sides)
	var shut := PackedStringArray()
	for bearing in [0.0, 90.0, 180.0, 270.0]:
		var way := Vector3(cos(deg_to_rad(bearing)), 0.0, sin(deg_to_rad(bearing)))
		var wall := _radius(Colosseum.ARENA.x, Colosseum.ARENA.y, bearing)
		var reach := _reach(Vector3(0.0, 1.5, 0.0), way * 80.0 + Vector3(0.0, 1.5, 0.0))
		if reach >= 0.0 and reach < wall + 2.0:
			shut.append("%d°" % bearing)
	check(shut.is_empty(), "colosseum: but for a gate at each end and side, and a way out %s" % shut)
	# The floor has given way over the passages, four metres down.
	var pit := _top(Vector3(0.0, 0.0, 0.0))
	check(absf(pit + Colosseum.PIT_DEPTH) < 0.1, "colosseum: the middle has fallen into the passages (%.2f)" % pit)
	check(absf(_top(Vector3(0.0, 0.0, Colosseum.PIT.y * 0.45))) < 0.1,
		"colosseum: whose walls stand up to where the floor was")
	# The seats rise behind the wall.
	var seats := Colosseum.ring(Colosseum.PODIUM.x, Colosseum.TIER)[18]
	var seat := _top(seats["middle"])
	check(seat > Colosseum.PODIUM.y - 0.1 and seat < Colosseum.PODIUM.y + Colosseum.TIER + 0.1,
		"colosseum: the seats rise behind the wall (%.1f)" % seat)
	# Whole on the north, fallen on the south.
	var facade := Colosseum.ring(Colosseum.PODIUM.x + Colosseum.TIER * Colosseum.TIERS + Colosseum.WALK,
		Colosseum.FACADE)
	var north := _top(facade[Colosseum.SEGMENTS * 3 / 4]["middle"])
	var south := _top(facade[Colosseum.SEGMENTS / 4]["middle"])
	check(north > Colosseum.STOREY * Colosseum.STOREYS - 0.1,
		"colosseum: the outside wall stands three storeys and more on the north (%.1f)" % north)
	check(south < Colosseum.STOREY, "colosseum: and has fallen on the south (%.1f)" % south)
	# And the spider walks on the sand, and stands in the walk round, outside and down
	# in the passages.
	var from := spider.global_position
	Input.action_press("move_forward")
	await run_frames(90)
	Input.action_release("move_forward")
	var moved := Vector2(spider.global_position.x - from.x, spider.global_position.z - from.z).length()
	check(moved > 1.5 and spider.is_on_floor(), "colosseum: the spider walks on the sand (%.1fm)" % moved)
	var walk := Colosseum.ring(Colosseum.PODIUM.x + Colosseum.TIER * Colosseum.TIERS, Colosseum.WALK)
	for spot in [(walk[Colosseum.SEGMENTS * 3 / 4]["middle"] as Vector3) + Vector3.UP * 0.8,
			Vector3(0.0, 0.8, -Colosseum.ARENA.y - 22.0), Vector3(0.0, -Colosseum.PIT_DEPTH + 0.8, 0.0)]:
		spider.global_position = spot
		spider.velocity = Vector3.ZERO
		await run_frames(40)
		check(spider.is_on_floor() and absf(spider.global_position.y - spot.y) < 0.6,
			"colosseum: and stands at %s (%s)" % [spot, spider.global_position])


func _shape_cathedral() -> void:
	check(_reach(Vector3(0.0, 2.0, 0.0), Vector3(0.0, 80.0, 0.0)) < 0.0
			and _reach(Vector3(Cathedral.CROSSING + Cathedral.BAY, 2.0, 0.0),
				Vector3(Cathedral.CROSSING + Cathedral.BAY, 80.0, 0.0)) < 0.0,
		"cathedral: nothing over the nave or the crossing")
	var through := _ray(Vector3(Cathedral.WEST - 20.0, 3.0, 0.0), Vector3(Cathedral.CHOIR + 30.0, 3.0, 0.0))
	check(not through.is_empty() and (through.position as Vector3).x > Cathedral.WEST + 10.0,
		"cathedral: the great door is open, and up the nave to the far end")
	var piers := 0
	for node in all_under(current_scene):
		var block := node as KitBlock
		if block != null and block.piece == "pillar3" and block.get_parent().name == "Piers":
			piers += 1
	check(piers >= 20, "cathedral: with the piers down it in rows (%d)" % piers)
	var wide := Cathedral.AISLE + 1.0
	var tower_x := Cathedral.WEST - 1.5 + wide * 0.5
	var south := _top(Vector3(tower_x, 0.0, Cathedral.NAVE + wide * 0.5))
	var north := _top(Vector3(tower_x, 0.0, -Cathedral.NAVE - wide * 0.5))
	check(south > 40.0, "cathedral: the south tower stands to its spire (%.1f)" % south)
	check(north > 15.0 and north < 20.0, "cathedral: and the north one broke off halfway (%.1f)" % north)


func _shape_castle() -> void:
	var gate := Vector3(0.0, 0.0, Castle.YARD.y - 8.0)
	check(_reach(gate + Vector3.UP * 1.5, gate + Vector3(0.0, 1.5, 50.0)) < 0.0,
		"castle: there is a way out under the portcullis")
	var bars := _reach(gate + Vector3.UP * 5.0, gate + Vector3(0.0, 5.0, 50.0))
	check(bars > 0.0 and absf(bars - (8.0 + Castle.WALL.x * 0.5)) < 0.6,
		"castle: which is stuck partway down the gate (%.1f)" % bars)
	var breach := Vector3(-Castle.YARD.x + 8.0, 3.0, (Castle.BREACH.x + Castle.BREACH.y) * 0.5)
	check(_reach(breach, breach + Vector3(-50.0, 0.0, 0.0)) < 0.0,
		"castle: the west wall is breached")
	var wall := _reach(Vector3(-Castle.YARD.x + 8.0, 3.0, -6.0), Vector3(-Castle.YARD.x - 50.0, 3.0, -6.0))
	check(wall > 0.0 and absf(wall - 8.0) < 0.2, "castle: and stands either side of the breach (%.1f)" % wall)
	var landing := _top(Vector3(-Castle.YARD.x + 0.6, 0.0, -10.0))
	var walk := _top(Vector3(-Castle.YARD.x - 1.0, 0.0, -10.0))
	check(absf(landing - Castle.WALL.y) < 0.6 and absf(walk - Castle.WALL.y) < 0.1,
		"castle: and stairs climb to the walk along its top (%.1f, %.1f)" % [landing, walk])
	var roofed := _top(Vector3(-Castle.YARD.x - Castle.WALL.x * 0.5, 0.0, -Castle.YARD.y - Castle.WALL.x * 0.5))
	var broken := _top(Vector3(Castle.YARD.x + Castle.WALL.x * 0.5, 0.0, -Castle.YARD.y - Castle.WALL.x * 0.5))
	check(roofed > Castle.TOWER.y + 2.0 and broken < Castle.TOWER.y - 2.0,
		"castle: one tower still roofed and another broken off (%.1f, %.1f)" % [roofed, broken])


func _shape_aqueduct(spider: SpiderPlayer) -> void:
	var top := Aqueduct.LOWER.x + Aqueduct.UPPER.x + Aqueduct.CHANNEL
	var channel := _top(Vector3(-20.0, 0.0, 0.0))
	check(absf(channel - top) < 0.1, "aqueduct: a channel to walk along %.0f metres up (%.1f)" % [top, channel])
	var west_end := Aqueduct.FALLEN[0] - Aqueduct.SPAN * 0.5
	var east_end := Aqueduct.FALLEN[Aqueduct.FALLEN.size() - 1] + Aqueduct.SPAN * 0.5
	# A little back from the broken edges, which have stone heaped on them.
	check(absf(_top(Vector3(west_end - 2.5, 0.0, 0.0)) - top) < 0.1
			and absf(_top(Vector3(east_end + 2.5, 0.0, 0.0)) - top) < 0.1
			and _top(Vector3((west_end + east_end) * 0.5, 0.0, 0.0)) < 0.0,
		"aqueduct: broken over the river")
	var reach := spider.web_builder.silk_reach()
	check(east_end - west_end < reach,
		"aqueduct: by a gap a grapple can cross (%.0fm against %.1f)" % [east_end - west_end, reach])
	check(absf(_top(Vector3(Aqueduct.BROKEN_TOP[0], 0.0, 0.0)) - Aqueduct.LOWER.x) < 0.1,
		"aqueduct: and dropping to the lower arches where the upper ones fell")
	check(_top(Vector3(Aqueduct.HALF + 2.0, 0.0, 0.0)) > top - 3.0
			and _top(Vector3(Aqueduct.HALF + 28.0, 0.0, 0.0)) < 4.0,
		"aqueduct: with a ramp down to the grass at the east end")


func _shape_watchtower(spider: SpiderPlayer) -> void:
	var foot := Watchtower.base()
	var tops: Array[float] = []
	for segment in Site.oval(Watchtower.RADIUS - Watchtower.THICK * 0.5,
			Watchtower.RADIUS - Watchtower.THICK * 0.5, Watchtower.SEGMENTS):
		tops.append(_top(segment["middle"]))
	var lowest: float = tops.min()
	var highest: float = tops.max()
	check(lowest > foot + Watchtower.STOREY * 4.0 - 0.1
			and highest > foot + Watchtower.STOREY * 5.0 - 0.1 and highest > lowest + 1.0,
		"watchtower: a tower over thirty metres, ragged at the top (%.0f to %.0f)" % [lowest, highest])
	var floor_top := _top(Vector3(0.0, 0.0, Watchtower.RADIUS - Watchtower.THICK - 1.0))
	check(absf(floor_top - (foot + Watchtower.STOREY * (Watchtower.STOREYS - 1))) < 0.1,
		"watchtower: with what is left of its floors inside (%.1f)" % floor_top)
	var height := foot + Watchtower.STOREY * Watchtower.BRIDGE_STOREY
	var from := -Watchtower.RADIUS
	var to := Watchtower.PILLAR + 2.5
	var half := (from - to - Watchtower.BRIDGE_GAP) * 0.5
	check(absf(_top(Vector3(0.0, 0.0, from - half * 0.5)) - height) < 0.1
			and absf(_top(Vector3(0.0, 0.0, to + half * 0.5)) - height) < 0.1,
		"watchtower: and a bridge from it to the pillar")
	check(_top(Vector3(0.0, 0.0, (from + to) * 0.5)) < height - 10.0
			and Watchtower.BRIDGE_GAP < spider.web_builder.silk_reach(),
		"watchtower: broken in the middle, by a gap a grapple can cross")


## The temple: walled all round with a gate in the middle of each side, tiers up
## behind the wall four at a time with a flight of stairs up each, and windows in the
## rim to look out of over wall to lean on.
func _shape_temple() -> void:
	var open_sides := PackedStringArray()
	for degrees in range(15, 360, 30):
		var way := Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(degrees))
		var reach := _reach(Vector3(0.0, 2.0, 0.0), Vector3(0.0, 2.0, 0.0) + way * 60.0)
		if reach < 0.0 or reach > Temple.ARENA * sqrt(2.0) + 0.1:
			open_sides.append("%d°" % degrees)
	check(open_sides.is_empty(), "temple: walled all round %s" % open_sides)
	for side in Temple.SIDES:
		var facing: Vector3 = Temple.SIDES[side]
		var through := _reach(Vector3(0.0, 1.5, 0.0), facing * 60.0 + Vector3(0.0, 1.5, 0.0))
		var lintel := _reach(Vector3(0.0, 3.5, 0.0), facing * 60.0 + Vector3(0.0, 3.5, 0.0))
		check(through > Temple.RIM - 1.05 and through < Temple.RIM and absf(lintel - Temple.ARENA) < 0.2,
			"temple: %s gate a door's height, and through it a way out to a shut door (%.1f, %.1f)"
			% [side, through, lintel])
	var wrong := PackedStringArray()
	var flights := 0
	for side in Temple.SIDES:
		var facing: Vector3 = Temple.SIDES[side]
		for k in Temple.TIERS:
			var middle := Site.frame(facing, 6.0, Temple.ARENA + Temple.TIER * (k + 0.5), 0.0).origin
			if absf(_top(middle) - Temple.TIER * (k + 1)) > 0.05:
				wrong.append("%s %d" % [side, k + 1])
			var foot := Site.frame(facing, Temple.AISLE,
				Temple.ARENA - Temple.TIER + Temple.TIER * k + 1.0, 0.0).origin
			var step := _top(foot)
			if step > Temple.TIER * k + 0.1 and step < Temple.TIER * k + 2.1:
				flights += 1
	check(wrong.is_empty() and flights == Temple.SIDES.size() * Temple.TIERS,
		"temple: tiers four, eight and twelve high, with stairs up each %s (%d)" % [wrong, flights])
	var top := Temple.TIER * Temple.TIERS
	var inside := Vector3(0.0, 0.0, Temple.RIM - 3.0)
	var out := Vector3(0.0, 0.0, Temple.RIM + 10.0)
	check(_reach(inside + Vector3.UP * (top + 2.0), out + Vector3.UP * (top + 2.0)) < 0.0
			and _reach(inside + Vector3.UP * (top + 0.5), out + Vector3.UP * (top + 0.5)) > 0.0,
		"temple: a window in the rim to look out of, over wall to lean on")


# --- training dummies -------------------------------------------------------

## Three creatures on posts with their numbers over their heads, for trying a fight
## against something that holds still and says what it is doing.
##
## They are creatures rather than special cases, so silk, venom, webs, hauling and
## eating all work on them the way they work on anything — which is the point, and
## also the thing that would quietly stop being true if they were ever turned into
## a bespoke target.
func _test_the_dummies() -> void:
	var yard := Node3D.new()
	yard.name = "Yard"
	var ground := WorldKit.body(yard, "Ground")
	WorldKit.box(ground, "Slab", Vector3(40.0, 1.0, 40.0), WorldKit.at(Vector3(0.0, -0.5, 0.0)),
		"straw")
	var posts: Array[TrainingDummy] = []
	for i in 3:
		var post := TrainingDummy.new()
		post.species_id = ["dummy_post", "dummy_runner", "dummy_biter"][i]
		post.name = "Dummy_" + post.species_id
		post.position = Vector3(-8.0 + 8.0 * i, 0.45, 0.0)
		yard.add_child(post)
		posts.append(post)
	await stage(yard)

	await run_frames(20)
	var kinds: Array[String] = []
	for post in posts:
		var standing: Prey = post._standing
		if not check(is_instance_valid(standing),
				"%s has something standing on it" % post.species_id):
			close()
			return
		kinds.append(standing.species)
	check(kinds.size() == 3 and kinds[0] != kinds[1] and kinds[1] != kinds[2],
		"and they are three different things (%s)" % ", ".join(kinds))

	# One stands still, one runs, one comes for you. Those are the three questions
	# a fight asks and there is a target for each.
	var still := 0
	var runners := 0
	var hunters := 0
	for post in posts:
		var standing: Prey = post._standing
		if standing.aggression > 0.0:
			hunters += 1
		elif standing.move_speed <= 0.0:
			still += 1
		else:
			runners += 1
	check(still == 1 and runners == 1 and hunters == 1,
		"one that stands, one that runs, one that bites (%d/%d/%d)"
		% [still, runners, hunters])

	# And the one that bites can never see further than the post will let it walk.
	# The biter shipped with a 14m acquire radius against a 9m leash, so it picked
	# fights with anyone who spawned across the room and then spent the whole thing
	# being snapped back to its plinth — which from in front read as one creature
	# that would not let go. The post clamps it now, so a `.tres` edited by hand
	# cannot put it back.
	for post in posts:
		var hunter: Prey = post._standing
		if hunter.aggression <= 0.0:
			continue
		check(hunter.hunt_range < post.leash,
			"%s cannot see past its own leash (%.1fm against %.1f)"
			% [post.species_id, hunter.hunt_range, post.leash])
		# Losing the spider on distance is `hunt_range * 1.8`, so that has to fit
		# inside the leash too, or it never gives up that way either.
		check(hunter.hunt_range * 1.8 <= post.leash,
			"and gives up on distance inside it (%.1fm against %.1f)"
			% [hunter.hunt_range * 1.8, post.leash])

	# The readout is the whole reason the post exists.
	var target: Prey = posts[0]._standing
	target.bind(0.4)
	target.poison(6.0)
	await run_frames(4)
	var lines: String = posts[0]._readout.text
	check(lines.contains("bound") and lines.contains("40%"),
		"the readout says how much silk is on it")
	check(lines.contains("venom"), "and how long the venom has left")
	check(lines.contains("a web needs"),
		"and what a web would have to hold to take it")

	# Something a web could actually take, once softened. A practice target no web
	# in the game can hold is a target you cannot practise the web on.
	var snare := WebLibrary.load_patterns()
	var strongest := 0.0
	for spun in snare:
		strongest = maxf(strongest, spun.hold_strength)
	check(target.total_thrash() / Prey.ESCAPE_MARGIN <= strongest,
		"and at 40%% wrapped a real web could take it (%.1f needed, %.1f is the best there is)"
		% [target.total_thrash() / Prey.ESCAPE_MARGIN, strongest])

	# Finish one and the post stands another up, or it is a one-shot target.
	var was: Prey = posts[0]._standing
	was.eaten = true
	posts[0]._waiting = 0.05
	await run_frames(20)
	check(posts[0]._standing != was and is_instance_valid(posts[0]._standing),
		"and finishing one puts a fresh one up")

	# The clamp above is what makes the leash rule true, not the `.tres` happening
	# to agree with it today — and with the clamp in place the two checks up there
	# cannot fail, so this is the one that has anything to prove. Put the shipped
	# 14m back on the species and stand a fresh one up.
	var biter: TrainingDummy = null
	for post in posts:
		if is_instance_valid(post._standing) and post._standing.aggression > 0.0:
			biter = post
	if check(biter != null, "there is a hunter to try that on"):
		var kind: PreySpecies = biter._kind
		var was_range := kind.hunt_range
		kind.hunt_range = 14.0
		biter._standing.eaten = true
		biter._waiting = 0.05
		await run_frames(20)
		check(is_instance_valid(biter._standing)
				and biter._standing.hunt_range <= biter.leash * 0.6,
			"and a 14m species on a %.0fm leash still stands up seeing %.1fm"
			% [biter.leash, biter._standing.hunt_range])
		kind.hunt_range = was_range

	# Practice targets stay out of the game: the spawner, the larder and the
	# catalogue all read the species folder, and none of them want these.
	var shipped: Array[String] = []
	for kind in PreyLibrary.load_species():
		shipped.append(kind.id)
	check(not shipped.has("dummy_post"),
		"and none of them are in the game's own species (%d)" % shipped.size())
	close()
