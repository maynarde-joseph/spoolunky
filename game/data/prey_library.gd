class_name PreyLibrary
extends RefCounted

## Loads the creatures.
##
## Species are plain resources in [code]res://game/data/prey/[/code], so adding
## something new to catch is a matter of dropping a .tres in the folder. The
## spawner picks its stock up from here when nothing has been set by hand.

const SPECIES_DIR := "res://game/data/prey"


## Every species in the game, smallest first.
static func load_species() -> Array[PreySpecies]:
	var species: Array[PreySpecies] = []
	var dir := DirAccess.open(SPECIES_DIR)
	if dir == null:
		return species
	var files := dir.get_files()
	files.sort()
	for file in files:
		var file_name := file.trim_suffix(".remap")
		if not file_name.ends_with(".tres"):
			continue
		var kind := ResourceLoader.load(SPECIES_DIR.path_join(file_name)) as PreySpecies
		if kind != null:
			species.append(kind)
	species.sort_custom(_compare)
	return species


## The one with this id, or null.
static func find(id: String) -> PreySpecies:
	for kind in load_species():
		if kind.id == id:
			return kind
	return null


static func _compare(a: PreySpecies, b: PreySpecies) -> bool:
	if a.sort_order != b.sort_order:
		return a.sort_order < b.sort_order
	return a.id < b.id
