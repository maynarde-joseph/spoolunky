extends SceneTree

## Builds places from their generators and saves each as a scene of real nodes.
##
##     godot --headless --path . --script res://tools/bake_level.gd -- colosseum castle
##
## Each place in [constant Site.PLACES] has a class that says where every piece goes
## — the generator of record — and a scene it is saved to, which is what the game
## opens and what you move things about in, in the editor. So does each of the
## dungeon's rooms in [constant Rooms.ROOMS]. Name them after `--` to bake only those
## (`-- hall crypt`); name none and everything is baked. A place that already has
## a scene is left alone unless told otherwise, because building it again throws
## away anything moved by hand:
##
##     godot --headless --path . --script res://tools/bake_level.gd -- --force castle
##
## Nothing is added to the tree while a place builds, so nothing in it runs: the
## spider does not set itself up and the blocks do not fit their looks, and what is
## saved is exactly what the generator said and no more.


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
		wanted.assign(_all())
	var failed := 0
	for place in wanted:
		if not _all().has(place):
			printerr("no such place: %s (try %s)" % [place, ", ".join(_all())])
			failed += 1
			continue
		if not _bake(place, force):
			failed += 1
	quit(1 if failed > 0 else 0)


## Everything there is to bake: the places and the dungeon's rooms.
func _all() -> Array[String]:
	var names: Array[String] = []
	names.assign(Site.PLACES.keys() + Rooms.ROOMS.keys())
	return names


func _builder(place: String) -> Script:
	if Site.PLACES.has(place):
		return Site.builder(place)
	return Rooms.builder(place)


func _bake(place: String, force: bool) -> bool:
	var builder := _builder(place)
	if builder == null:
		printerr("no builder for %s" % place)
		return false
	var path: String = builder.get_script_constant_map()["SCENE"]
	if ResourceLoader.exists(path) and not force:
		print("%s is already baked — left alone. Pass --force to build it again, which" % path)
		print("  throws away anything that has been moved by hand.")
		return true
	# A room's root is a room, which carries its doorways for the floor plan.
	var level: Node3D = DungeonRoom.new() if Rooms.ROOMS.has(place) else Node3D.new()
	level.name = builder.get_global_name()
	if level is DungeonRoom:
		(level as DungeonRoom).room_id = place
	builder.call("build", level)
	_own(level, level)
	var nodes := _count(level)
	var scene := PackedScene.new()
	var err := scene.pack(level)
	if err == OK:
		err = ResourceSaver.save(scene, path)
	level.free()
	if err != OK:
		printerr("could not bake %s: %d" % [path, err])
		return false
	print("baked %s — %d nodes, editable" % [path, nodes])
	return true


## A node is only saved into a scene if the scene's root owns it. An instance of
## another scene — a piece, the spider, the HUD — is owned as a whole and saved as
## an instance, and what is inside it stays that scene's business.
func _own(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		if child.scene_file_path.is_empty():
			_own(child, root)


func _count(node: Node) -> int:
	var total := 1
	for child in node.get_children():
		total += _count(child)
	return total
