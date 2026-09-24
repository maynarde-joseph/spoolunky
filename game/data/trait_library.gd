class_name TraitLibrary
extends RefCounted

## Loads the evolutionary tree.
##
## Same arrangement as the patterns and the creatures: the traits are plain
## resources in a folder, so the tree is data. Its shape comes out of the
## resources themselves — branch, depth and requirements — rather than out of a
## layout somebody has to keep in step with them.

const TRAIT_DIR := "res://game/data/traits"


## Every trait in the game, branch by branch and shallowest first.
static func load_traits() -> Array[SpiderTrait]:
	var found: Array[SpiderTrait] = []
	var dir := DirAccess.open(TRAIT_DIR)
	if dir == null:
		return found
	var files := dir.get_files()
	files.sort()
	for file in files:
		var file_name := file.trim_suffix(".remap")
		if not file_name.ends_with(".tres"):
			continue
		var gift := ResourceLoader.load(TRAIT_DIR.path_join(file_name)) as SpiderTrait
		if gift != null:
			found.append(gift)
	found.sort_custom(_compare)
	return found


static func _compare(a: SpiderTrait, b: SpiderTrait) -> bool:
	if a.branch != b.branch:
		return a.branch < b.branch
	if a.depth != b.depth:
		return a.depth < b.depth
	return a.id < b.id
