extends SceneTree

## Bakes every prop the world is furnished with into a scene of its own.
##
##     godot --headless --path . --script res://tools/bake_props.gd
##
## [Props] is the generator of record — it builds each one out of [WorldKit]
## solids — and this saves what it builds to `game/world/props/<name>.tscn`, so
## the world holds instances of them rather than copies and the editor has
## something to drag in. The paints go first: any in [constant Palette.PAINTS]
## with no file yet is written to `game/world/materials/`, so everything built
## after it is painted from those files and they stay the one place a colour is.
##
## Like the level bake, it leaves a prop that already has a scene alone, because
## that scene may have been changed by hand since. Name props after `--` to bake
## only those, and add `--force` to build them again from the script anyway:
##
##     godot --headless --path . --script res://tools/bake_props.gd -- --force bench


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
		wanted.assign(Props.ALL)

	var painted := Palette.save_missing()
	if painted > 0:
		print("mixed %d paint%s into %s" % [painted, "" if painted == 1 else "s", Palette.DIR])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Props.DIR))

	var failed := 0
	var baked := 0
	for id in wanted:
		if not Props.ALL.has(id):
			printerr("no such prop: %s" % id)
			failed += 1
			continue
		var path := Props.path_of(id)
		if ResourceLoader.exists(path) and not force:
			continue
		if not _bake(id, path):
			failed += 1
			continue
		baked += 1
	print("baked %d prop%s into %s" % [baked, "" if baked == 1 else "s", Props.DIR])
	quit(1 if failed > 0 else 0)


func _bake(id: String, path: String) -> bool:
	var made := Props.build(id)
	if made == null:
		return false
	for node in _every(made):
		node.owner = made
	var packed := PackedScene.new()
	var err := packed.pack(made)
	if err == OK:
		err = ResourceSaver.save(packed, path)
	made.free()
	if err != OK:
		printerr("could not bake %s: %d" % [id, err])
		return false
	return true


func _every(node: Node) -> Array[Node]:
	var found: Array[Node] = []
	for child in node.get_children():
		found.append(child)
		found.append_array(_every(child))
	return found
