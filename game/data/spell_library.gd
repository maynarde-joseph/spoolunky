class_name SpellLibrary
extends RefCounted

## Loads the spells.
##
## Same arrangement as the traits and the creatures: every spell is a plain
## resource in a folder, so the book is data, and its order is each spell's own
## [member SpiderSpell.order] rather than a list somebody has to keep in step.

const SPELL_DIR := "res://game/data/spells"


## Every spell in the game, first on the strip to last.
static func load_spells() -> Array[SpiderSpell]:
	var found: Array[SpiderSpell] = []
	var dir := DirAccess.open(SPELL_DIR)
	if dir == null:
		return found
	var files := dir.get_files()
	files.sort()
	for file in files:
		var file_name := file.trim_suffix(".remap")
		if not file_name.ends_with(".tres"):
			continue
		var spell := ResourceLoader.load(SPELL_DIR.path_join(file_name)) as SpiderSpell
		if spell != null:
			found.append(spell)
	found.sort_custom(_compare)
	return found


## One spell by id, or null.
static func find(id: String) -> SpiderSpell:
	for spell in load_spells():
		if spell.id == id:
			return spell
	return null


static func _compare(a: SpiderSpell, b: SpiderSpell) -> bool:
	if a.order != b.order:
		return a.order < b.order
	return a.id < b.id
