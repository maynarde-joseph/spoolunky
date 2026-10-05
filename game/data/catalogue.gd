class_name Catalogue
extends RefCounted

## Loads what the game is made of: the spells, the insects the farm can raise, and
## the things it can build.
##
## Every one of them is a plain resource in a folder, so each list is data, and its
## order is each entry's own sort number rather than a list somebody has to keep in
## step. Read once and kept: nothing in these folders changes while the game runs.

const SPELL_DIR := "res://game/data/spells"
const INSECT_DIR := "res://game/data/insects"
const STRUCTURE_DIR := "res://game/data/structures"

static var _spells: Array[SpiderSpell] = []
static var _insects: Array[InsectSpecies] = []
static var _structures: Array[StructureKind] = []


## Every spell, first on the disc to last.
static func spells() -> Array[SpiderSpell]:
	if _spells.is_empty():
		for resource in _load(SPELL_DIR):
			var spell := resource as SpiderSpell
			if spell != null:
				_spells.append(spell)
		_spells.sort_custom(func(a: SpiderSpell, b: SpiderSpell) -> bool:
			return a.order < b.order if a.order != b.order else a.id < b.id)
	return _spells.duplicate()


## Every insect the farm can raise, in the shop's order.
static func insects() -> Array[InsectSpecies]:
	if _insects.is_empty():
		for resource in _load(INSECT_DIR):
			var kind := resource as InsectSpecies
			if kind != null:
				_insects.append(kind)
		_insects.sort_custom(func(a: InsectSpecies, b: InsectSpecies) -> bool:
			return a.sort_order < b.sort_order if a.sort_order != b.sort_order else a.id < b.id)
	return _insects.duplicate()


## Everything the farm can build, in the shop's order.
static func structures() -> Array[StructureKind]:
	if _structures.is_empty():
		for resource in _load(STRUCTURE_DIR):
			var kind := resource as StructureKind
			if kind != null:
				_structures.append(kind)
		_structures.sort_custom(func(a: StructureKind, b: StructureKind) -> bool:
			return a.sort_order < b.sort_order if a.sort_order != b.sort_order else a.id < b.id)
	return _structures.duplicate()


static func spell(id: String) -> SpiderSpell:
	for found in spells():
		if found.id == id:
			return found
	return null


static func insect(id: String) -> InsectSpecies:
	for found in insects():
		if found.id == id:
			return found
	return null


static func structure(id: String) -> StructureKind:
	for found in structures():
		if found.id == id:
			return found
	return null


## Every resource in [param folder], by file name. An exported game keeps them as
## .remap files pointing at the real thing, so those count too.
static func _load(folder: String) -> Array[Resource]:
	var found: Array[Resource] = []
	var dir := DirAccess.open(folder)
	if dir == null:
		return found
	var files := dir.get_files()
	files.sort()
	for file in files:
		var file_name := file.trim_suffix(".remap")
		if not file_name.ends_with(".tres"):
			continue
		var resource := ResourceLoader.load(folder.path_join(file_name))
		if resource != null:
			found.append(resource)
	return found
