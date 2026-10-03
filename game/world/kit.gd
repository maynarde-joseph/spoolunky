@tool
class_name Kit
extends RefCounted

## The pieces in `Pieces/`: walls, pillars, stairs and the rest, each one a solid
## the spider can stand on, centred on its origin with its base on the ground.
##
## The import does the work — see `tools/kit_import.gd`. This is how a builder
## asks for a piece by its file name, and how a [KitBlock] borrows one's look.

const DIR := "res://Pieces/"

## What each piece looks like, by name, once asked for: its mesh, where that mesh
## sits in the piece, and how big the piece is.
static var _looks := {}


## Where the piece called [param piece] is kept.
static func path_of(piece: String) -> String:
	return DIR + piece + ".fbx"


## Every piece in the folder, by name.
static func names() -> Array[String]:
	var found: Array[String] = []
	for file in DirAccess.get_files_at(DIR):
		if file.ends_with(".fbx"):
			found.append(file.get_basename())
		elif file.ends_with(".fbx.import"):
			var named := file.trim_suffix(".import").get_basename()
			if not found.has(named):
				found.append(named)
	found.sort()
	return found


## Puts a [param piece] under [param parent] at [param where], named [param part_name].
static func place(parent: Node, piece: String, where: Transform3D, part_name: String) -> StaticBody3D:
	var scene := load(path_of(piece)) as PackedScene
	if scene == null:
		push_warning("No piece called %s in %s" % [piece, DIR])
		return null
	var made := scene.instantiate() as StaticBody3D
	made.name = part_name
	made.transform = where
	parent.add_child(made, true)
	return made


## The mesh of [param piece], the transform that puts it in the piece, and the
## size of the piece — what [KitBlock] stretches to fit. Empty if there is no such
## piece or it has nothing to see.
static func look_of(piece: String) -> Dictionary:
	if _looks.has(piece):
		return _looks[piece]
	var look := {}
	var scene := load(path_of(piece)) as PackedScene if ResourceLoader.exists(path_of(piece)) else null
	if scene != null:
		var made := scene.instantiate()
		for child in made.get_children():
			var view := child as MeshInstance3D
			if view != null and view.mesh != null:
				var box := view.transform * view.mesh.get_aabb()
				look = {"mesh": view.mesh, "where": view.transform, "size": box.size}
				break
		made.free()
	_looks[piece] = look
	return look
