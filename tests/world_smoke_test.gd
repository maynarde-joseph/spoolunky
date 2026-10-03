extends TestSuite

## Headless check on the colosseum, and on the kit it is built from.
##
##     godot --headless --script res://tests/world_smoke_test.gd
##
## A level's job is to be the right shape, so that is what is checked. Every piece
## of the kit comes in solid, on the world layer, centred on its origin with its
## base on the ground, and a stretched block is the size it says. The colosseum
## is what the game opens; the spider starts on the sand at one size with every
## spell open; everything in it is something to stand on; the arena is walled all
## round, with a gate in the middle of each side that you can walk through to a
## door at the end of the way out that you cannot; the tiers are where they should
## be, the aisles climb them, and there are windows in the rim to look out of. And
## the spider can walk on the sand, in the ways out, and outside.
##
## None of this looks at how it plays — that is what opening it is for.
##
## The training dummies are checked here too, on posts stood up for the purpose:
## they are part of the world rather than of any one creature, and the gym that
## used to hold them is gone.

func run_checks() -> void:
	_test_the_pieces()
	await _test_a_block()
	await _test_the_colosseum()
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


## A block is the size it says: its look stretched to fit and its box the same, so
## what you see is what you stand on, and changing its size changes both.
func _test_a_block() -> void:
	var holder := Node3D.new()
	var block := KitBlock.new()
	block.size = Vector3(10.0, 3.0, 2.0)
	holder.add_child(block)
	await stage(holder)
	await run_frames(2)
	var solid := _shape_of(block)
	check(solid != null and solid.size.is_equal_approx(Vector3(10.0, 3.0, 2.0)),
		"a block collides as the box it says it is (%s)" % (solid.size if solid != null else "none"))
	var seen := _seen(block)
	check(seen.size.is_equal_approx(Vector3(10.0, 3.0, 2.0)) and absf(seen.position.y) < 0.01,
		"and looks it, standing on its origin (%s)" % seen)
	var top := _reach(Vector3(3.0, 10.0, 0.0), Vector3(3.0, -1.0, 0.0))
	check(absf(top - 7.0) < 0.05, "and you stand on its top (%.2f down)" % top)
	block.size = Vector3(4.0, 6.0, 4.0)
	await run_frames(2)
	check(_shape_of(block).size.is_equal_approx(Vector3(4.0, 6.0, 4.0))
			and _seen(block).size.is_equal_approx(Vector3(4.0, 6.0, 4.0)),
		"and a new size changes both")
	close()


func _shape_of(block: KitBlock) -> BoxShape3D:
	for child in block.get_children(true):
		if child is CollisionShape3D:
			return (child as CollisionShape3D).shape as BoxShape3D
	return null


func _seen(block: KitBlock) -> AABB:
	for child in block.get_children(true):
		var view := child as MeshInstance3D
		if view != null and view.mesh != null:
			return view.transform * view.mesh.get_aabb()
	return AABB()


# --- the colosseum ----------------------------------------------------------

func _test_the_colosseum() -> void:
	check(str(ProjectSettings.get_setting("application/run/main_scene")) == Colosseum.SCENE,
		"the game opens in the colosseum")
	var level := await open(Colosseum.SCENE)
	if level == null:
		return
	var spider := root.get_tree().get_first_node_in_group("spider") as SpiderPlayer
	if not check(spider != null, "the colosseum has a spider in it"):
		return
	spider.require_captured_mouse = false
	await run_frames(60)

	# One size the whole way through, and every spell from the start: there is no
	# growing, and nothing to find yet.
	check(spider.growth.stage_index == 2 and not spider.growth.grows
		and not spider.traits.evolving,
		"the spider is a Huntsman and stays one (%s)" % spider.stage().display_name)
	check(spider.spells.open_spells().size() == spider.spells.book.size(),
		"with every spell open from the start (%d)" % spider.spells.open_spells().size())
	var here := Zone.at(root.get_tree(), spider.global_position)
	check(here != null and here.display_name == "The Colosseum",
		"and starts in the Colosseum (%s)" % (here.display_name if here != null else "nowhere"))
	check(spider.is_on_floor() and spider.global_position.distance_to(Colosseum.START) < 1.0,
		"standing on the sand where it was put (%s)" % spider.global_position)

	# Everything is something to stand on.
	var bodies := 0
	var loose := PackedStringArray()
	for node in all_under(level):
		var body := node as StaticBody3D
		if body == null:
			continue
		bodies += 1
		if body.collision_layer & GameLayers.WORLD == 0:
			loose.append(body.name)
	check(bodies > 150 and loose.is_empty(),
		"all %d solids in it are on the world layer %s" % [bodies, loose])

	_test_the_walls()
	_test_the_ways()
	_test_the_stands()
	await _test_walking(spider)


## Walled all round: from the middle of the sand every way but through a gate, the
## first thing you meet is the arena wall or a column in front of it.
func _test_the_walls() -> void:
	var open_sides := PackedStringArray()
	for degrees in range(15, 360, 30):
		var way := Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(degrees))
		var reach := _reach(Vector3(0.0, 2.0, 0.0), Vector3(0.0, 2.0, 0.0) + way * 60.0)
		if reach < 0.0 or reach > Colosseum.ARENA * sqrt(2.0) + 0.1:
			open_sides.append("%d°" % degrees)
	check(open_sides.is_empty(), "the arena is walled all round %s" % open_sides)

	var columns := 0
	for node in all_under(current_scene):
		if node.scene_file_path == Kit.path_of("pillar3"):
			columns += 1
	check(columns == Colosseum.COLUMNS.size() * 8 + 4,
		"with columns along the foot of the wall and in the corners (%d)" % columns)


## A gate in the middle of each side, low enough to walk through and no higher
## than a door, and through it a way out to a door at the far end that is shut.
func _test_the_ways() -> void:
	for side in Colosseum.SIDES:
		var facing: Vector3 = Colosseum.SIDES[side]
		var through := _reach(Vector3(0.0, 1.5, 0.0), facing * 60.0 + Vector3(0.0, 1.5, 0.0))
		# The door itself is set into the middle of the outside wall's thickness.
		check(through > Colosseum.RIM - 1.05 and through < Colosseum.RIM,
			"%s: through the gate to a shut door at the end of the way out (%.1f)"
			% [side, through])
		var lintel := _reach(Vector3(0.0, 3.5, 0.0), facing * 60.0 + Vector3(0.0, 3.5, 0.0))
		check(absf(lintel - Colosseum.ARENA) < 0.2,
			"%s: and the gate is a door's height, with wall over it (%.1f)" % [side, lintel])


## The tiers step up four at a time, the aisles climb them, and the rim has windows
## in it to look out of and wall under them to lean on.
func _test_the_stands() -> void:
	var wrong := PackedStringArray()
	for side in Colosseum.SIDES:
		var facing: Vector3 = Colosseum.SIDES[side]
		for k in Colosseum.TIERS:
			var middle := Colosseum.frame(facing, 6.0,
				Colosseum.ARENA + Colosseum.TIER * (k + 0.5), 0.0).origin
			var down := _reach(middle + Vector3.UP * 40.0, middle + Vector3.DOWN)
			var height := 40.0 - down
			if absf(height - Colosseum.TIER * (k + 1)) > 0.05:
				wrong.append("%s %d at %.1f" % [side, k + 1, height])
	check(wrong.is_empty(), "the tiers are four, eight and twelve high on every side %s" % wrong)

	var flights := 0
	for side in Colosseum.SIDES:
		var facing: Vector3 = Colosseum.SIDES[side]
		for k in Colosseum.TIERS:
			var foot := Colosseum.frame(facing, Colosseum.AISLE,
				Colosseum.ARENA - Colosseum.TIER + Colosseum.TIER * k + 1.0, 0.0).origin
			var step := 40.0 - _reach(foot + Vector3.UP * 40.0, foot + Vector3.DOWN)
			if step > Colosseum.TIER * k + 0.1 and step < Colosseum.TIER * k + 2.1:
				flights += 1
	check(flights == Colosseum.SIDES.size() * Colosseum.TIERS,
		"and a flight of stairs climbs each one (%d)" % flights)

	var top := Colosseum.TIER * Colosseum.TIERS
	var inside := Vector3(0.0, 0.0, Colosseum.RIM - 3.0)
	var out := Vector3(0.0, 0.0, Colosseum.RIM + 10.0)
	check(_reach(inside + Vector3.UP * (top + 2.0), out + Vector3.UP * (top + 2.0)) < 0.0,
		"there is a window in the rim to look out of")
	check(_reach(inside + Vector3.UP * (top + 0.5), out + Vector3.UP * (top + 0.5)) > 0.0,
		"and wall under it to lean on")


## The spider walks on the sand, and stands in the ways out and on the grass
## outside — everywhere it can get to is somewhere to stand.
func _test_walking(spider: SpiderPlayer) -> void:
	var from := spider.global_position
	Input.action_press("move_forward")
	await run_frames(90)
	Input.action_release("move_forward")
	var moved := Vector2(spider.global_position.x - from.x, spider.global_position.z - from.z).length()
	check(moved > 1.5 and spider.is_on_floor(),
		"the spider walks on the sand (%.1fm)" % moved)

	for spot in [Vector3(0.0, 0.8, Colosseum.ARENA + 6.0), Vector3(0.0, 0.8, Colosseum.RIM + 8.0)]:
		spider.global_position = spot
		spider.velocity = Vector3.ZERO
		await run_frames(40)
		check(spider.is_on_floor() and absf(spider.global_position.y - spot.y) < 0.6,
			"and stands at %s (%s)" % [spot, spider.global_position])
	release_all()


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
