class_name SkillLibrary
extends RefCounted

## Loads the spell tree.
##
## Same arrangement as the spells and the creatures: every skill is a plain
## resource in a folder, so the tree is data, and where a skill sits is its own
## [member SpellSkill.row] and [member SpellSkill.column] rather than a layout
## somebody has to keep in step.

const SKILL_DIR := "res://game/data/skills"


## Every skill in the tree, row by row and left to right.
static func load_skills() -> Array[SpellSkill]:
	var found: Array[SpellSkill] = []
	var dir := DirAccess.open(SKILL_DIR)
	if dir == null:
		return found
	var files := dir.get_files()
	files.sort()
	for file in files:
		var file_name := file.trim_suffix(".remap")
		if not file_name.ends_with(".tres"):
			continue
		var skill := ResourceLoader.load(SKILL_DIR.path_join(file_name)) as SpellSkill
		if skill != null:
			found.append(skill)
	found.sort_custom(_compare)
	return found


## One skill by id, or null.
static func find(id: String) -> SpellSkill:
	for skill in load_skills():
		if skill.id == id:
			return skill
	return null


static func _compare(a: SpellSkill, b: SpellSkill) -> bool:
	if a.row != b.row:
		return a.row < b.row
	if a.column != b.column:
		return a.column < b.column
	return a.id < b.id
