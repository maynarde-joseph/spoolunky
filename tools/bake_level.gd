extends SceneTree

## Turns a level that builds itself at startup into one made of real nodes.
##
##     godot --headless --script res://tools/bake_level.gd -- testbed hunting_ground
##
## The greybox used to be assembled in _ready(), which is fine for getting a
## shape down quickly and useless the moment you want to nudge one wall: there is
## nothing in the editor to nudge. This runs the builder once, packs what it made
## into the scene file, and takes the script off the node so it does not build
## over the top next time.
##
## The builders stay where they are. They are the generator of record — run this
## again and you get the shape back — but doing so **discards anything moved by
## hand**, which after the first bake is the whole point of the file. So it says
## so and asks for --force.

const LEVELS := {
	"testbed": "res://game/world/testbed.tscn",
	"hunting_ground": "res://game/world/hunting_ground.tscn",
}

## Made while the game runs rather than placed by the builder: creatures a dummy
## stands up, and silk. They come back on their own and a baked copy would simply
## be a second one.
##
## Not silk_devices. The gym's loose pickups are in that group and they are level
## content — placed on purpose, at a spot chosen for being within reach of where
## you start. Stripping them cost two checks the first time round.
const RUNTIME_GROUPS := ["prey", "silk_webs"]

## Where the props live. An instance of one is kept as an instance, like any other,
## and so is anything the builder hung on it after putting it down. A prop has no
## script to make anything for itself, so whatever is on one that its own scene
## did not bring was put there by the builder, and is this level's to keep.
const PROPS_DIR := "res://game/world/props/"

## Where the shapes a builder makes a point at a time are kept — the valley's
## ground, the hollow log in the Rootways, and what they collide as. They are the bulk of a
## level: written into the scene they are most of the file, and as numbers in
## text, which is the most room they could take. In files of their own they are
## compressed binary, and the scene reads as the nodes it is.
const MESHES_DIR := "res://game/world/meshes"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var force := args.has("--force")
	var wanted: Array[String] = []
	for arg in args:
		if not arg.begins_with("-"):
			wanted.append(arg)
	if wanted.is_empty():
		wanted.assign(LEVELS.keys())

	var failed := 0
	for name in wanted:
		if not LEVELS.has(name):
			printerr("no such level: %s (try %s)" % [name, ", ".join(LEVELS.keys())])
			failed += 1
			continue
		if not await _bake(str(name), str(LEVELS[name]), force):
			failed += 1
	quit(1 if failed > 0 else 0)


func _bake(name: String, path: String, force: bool) -> bool:
	var packed := load(path) as PackedScene
	if packed == null:
		printerr("could not load %s" % path)
		return false
	var root := packed.instantiate()
	root_node().add_child(root)
	current_scene = root
	# Two frames: one for _ready to build, one for anything it deferred.
	await physics_frame
	await process_frame

	var maker := _builder_in(root)
	if maker == null:
		print("%s is already baked — %d nodes and no builder script on it." % [
			name, _count(root) - 1])
		if not force:
			print("  Nothing to do. Pass --force to build it again from the script,")
			print("  which throws away anything that has been moved by hand.")
			root.free()
			return true
		print("  --force given: rebuilding from the script.")
		if not await _rebuild(root, name):
			root.free()
			return false
		maker = _builder_in(root)

	var built := _count(maker)
	# The script has done its job. Left on, it would build a second copy over the
	# baked one every time the scene is opened.
	maker.set_script(null)
	_drop_runtime_nodes(root)
	_take_ownership(root, root)
	var apart := _keep_apart(root, name)
	if apart > 0:
		print("  %d built shapes kept in %s" % [apart, MESHES_DIR.path_join(name)])

	var out := PackedScene.new()
	var err := out.pack(root)
	if err != OK:
		printerr("could not pack %s: %d" % [name, err])
		root.free()
		return false
	err = ResourceSaver.save(out, path)
	root.free()
	if err != OK:
		printerr("could not save %s: %d" % [path, err])
		return false
	print("baked %s — %d nodes now in %s, editable" % [name, built, path])
	return true


## The node carrying the build script, if the scene still has one.
func _builder_in(root: Node) -> Node:
	for node in _every(root):
		var script: Variant = node.get_script()
		if script == null:
			continue
		var file: String = str(script.resource_path)
		if file.ends_with("/testbed.gd") or file.ends_with("/hunting_ground.gd"):
			return node
	return null


## Puts the script back on a baked node and lets it build again, for --force.
func _rebuild(root: Node, name: String) -> bool:
	var holder := root.get_node_or_null("Greybox")
	if holder == null:
		printerr("%s has no Greybox node to rebuild into" % name)
		return false
	for child in holder.get_children():
		child.free()
	var script := load("res://game/world/%s.gd" % name)
	if script == null:
		printerr("no builder script for %s" % name)
		return false
	holder.set_script(script)
	if holder.has_method("build"):
		holder.call("build")
	await process_frame
	return true


## Saves every mesh and every triangle collider the builder made a point at a time
## to a file of its own, named for where it is in the level, so the scene refers
## to it rather than holding it. Starts from an empty folder, so a part that has
## been renamed or taken out does not leave its old file behind.
func _keep_apart(root: Node, level: String) -> int:
	var folder := MESHES_DIR.path_join(level)
	var absolute := ProjectSettings.globalize_path(folder)
	if DirAccess.dir_exists_absolute(absolute):
		for file in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(absolute.path_join(file))
	var kept := 0
	for node in _every(root):
		# Inside an instance is that scene's business, not this level's.
		if node.owner != root:
			continue
		var view := node as MeshInstance3D
		if view != null and view.mesh is ArrayMesh and view.mesh.resource_path.is_empty():
			if _keep(view.mesh, folder, _file_name(root, node) + ".mesh.res"):
				kept += 1
		var solid := node as CollisionShape3D
		if solid != null and (solid.shape is ConcavePolygonShape3D
				or solid.shape is HeightMapShape3D) and solid.shape.resource_path.is_empty():
			if _keep(solid.shape, folder, _file_name(root, node) + ".shape.res"):
				kept += 1
	return kept


func _keep(resource: Resource, folder: String, file: String) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var path := folder.path_join(file)
	var err := ResourceSaver.save(resource, path, ResourceSaver.FLAG_COMPRESS)
	if err != OK:
		printerr("could not save %s: %d" % [path, err])
		return false
	resource.take_over_path(path)
	return true


## Where a node is in the level, as a file name.
func _file_name(root: Node, node: Node) -> String:
	var where := str(root.get_path_to(node))
	for bad in ["/", ":", "@", "\"", " "]:
		where = where.replace(bad, "_")
	return where.trim_prefix("Greybox_")


## Anything the game makes for itself while it runs. A training dummy builds its
## own readout and stands a creature up; both come back on load, and a baked copy
## would simply be a second one.
func _drop_runtime_nodes(root: Node) -> void:
	for node in _every(root):
		if not is_instance_valid(node):
			continue
		for group in RUNTIME_GROUPS:
			if node.is_in_group(group):
				node.free()
				break
	for node in _every(root):
		if is_instance_valid(node) and node is TrainingDummy:
			for child in node.get_children():
				child.free()


## A node is only saved into a scene if the scene root owns it.
##
## Instanced scenes are the exception that matters: the instance root gets an
## owner so it is written out as an instance, and its insides are left alone so
## they stay part of *their* scene rather than being flattened into this one —
## all but what the builder added to a prop, which nothing else would keep.
func _take_ownership(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		if child.scene_file_path.is_empty():
			_take_ownership(child, root)
		elif child.scene_file_path.begins_with(PROPS_DIR):
			for added in child.get_children():
				if added.owner == null:
					added.owner = root
					_take_ownership(added, root)


func _every(node: Node) -> Array[Node]:
	var found: Array[Node] = []
	for child in node.get_children():
		found.append(child)
		found.append_array(_every(child))
	return found


func _count(node: Node) -> int:
	return _every(node).size() + 1


func root_node() -> Node:
	return root
