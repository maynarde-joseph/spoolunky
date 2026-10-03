extends SceneTree

## Builds the colosseum from its generator and saves it as a scene of real nodes.
##
##     godot --headless --path . --script res://tools/bake_level.gd
##
## [Colosseum] is the generator of record: it says where every piece goes. This runs
## it once and saves what it made to [constant Colosseum.SCENE], which is what the
## game opens, and from then on what you move things about in, in the editor. So it
## leaves a scene that is already there alone unless told otherwise, because building
## it again throws away anything moved by hand:
##
##     godot --headless --path . --script res://tools/bake_level.gd -- --force
##
## Nothing is added to the tree while it builds, so nothing in the level runs: the
## spider does not set itself up and the tiers do not fit their looks, and what is
## saved is exactly what the generator said and no more.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var path := Colosseum.SCENE
	if ResourceLoader.exists(path) and not OS.get_cmdline_user_args().has("--force"):
		print("%s is already baked — nothing to do." % path)
		print("  Pass --force to build it again from the script, which throws away")
		print("  anything that has been moved by hand.")
		quit(0)
		return
	var level := Node3D.new()
	level.name = "Colosseum"
	Colosseum.build(level)
	_own(level, level)
	var nodes := _count(level)
	var scene := PackedScene.new()
	var err := scene.pack(level)
	if err == OK:
		err = ResourceSaver.save(scene, path)
	level.free()
	if err != OK:
		printerr("could not bake %s: %d" % [path, err])
		quit(1)
		return
	print("baked %s — %d nodes, editable" % [path, nodes])
	quit(0)


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
