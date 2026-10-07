class_name LevelData
extends RefCounted

## A level as it is kept: plain JSON, one file a level, readable and diffable and
## written by the level editor.
##
## A level is a few settings and a list of things in it. Every thing is a
## dictionary with a [code]type[/code], where it is ([code]pos[/code], metres) and
## how it is turned ([code]rot[/code], degrees about x, y and z), and whatever else
## its type takes:
##
## [codeblock]
## piece     piece, size, surface        — one of the kit's pieces, stretched to size
## start     —                           — where the spider starts, facing -z
## exit      —                           — walk into it to finish
## crate     —                           — a crate silk can stick to and bring home
## plate     channel                     — pressed by a crate, it powers its channel
## door      piece, size, surface, open, channel — slides by `open` while powered
## platform  piece, size, surface, path, speed, wait, loop, channel — moves along its path
## hazard    size                        — touch it and start again
## panel     piece, size                 — a loose board: holds silk, not you; the Pullback rips it off
## slider    piece, size, surface, travel, speed — a block on a rail; the Pullback slides it to the other end
## [/codeblock]
##
## A level's settings: [code]webs[/code], how many webs may be out at once (2);
## [code]kill_y[/code], how far down is falling out; [code]ceiling[/code], the height
## of the slick lid over the level (0 puts it a little over the top of everything);
## and [code]par[/code], a time to beat.
##
## The built-in levels live in `res://levels/`; levels made in the game's editor
## when the project folder cannot be written to go to `user://levels/`.

const BUILT_IN := "res://levels/"
const MADE := "user://levels/"

const TYPES := ["piece", "start", "exit", "crate", "plate", "door", "platform", "hazard", "panel",
	"slider"]


## A new, empty level: a floor, a start and an exit.
static func blank(title := "New level") -> Dictionary:
	return {
		"name": title,
		"webs": 2,
		"kill_y": -20.0,
		"ceiling": 0.0,
		"par": 60.0,
		"objects": [
			{"type": "piece", "piece": "cube", "pos": [0.0, -1.0, 0.0], "rot": [0.0, 0.0, 0.0],
				"size": [16.0, 1.0, 16.0], "surface": "stone"},
			{"type": "start", "pos": [0.0, 0.5, 6.0], "rot": [0.0, 0.0, 0.0]},
			{"type": "exit", "pos": [0.0, 0.5, -6.0], "rot": [0.0, 0.0, 0.0]},
		],
	}


## A thing of [param type] at [param at], with its type's defaults.
static func make(type: String, at: Vector3) -> Dictionary:
	var thing := {"type": type, "pos": vec_out(at), "rot": [0.0, 0.0, 0.0]}
	match type:
		"piece":
			thing["piece"] = "cube"
			thing["size"] = [2.0, 2.0, 2.0]
			thing["surface"] = Surfaces.STONE
		"plate":
			thing["channel"] = "a"
		"door":
			thing["piece"] = "cube"
			thing["size"] = [4.0, 4.0, 0.5]
			thing["surface"] = Surfaces.STONE
			thing["open"] = [0.0, 4.2, 0.0]
			thing["channel"] = "a"
		"platform":
			thing["piece"] = "cube5"
			thing["size"] = [3.0, 0.5, 3.0]
			thing["surface"] = Surfaces.STONE
			thing["path"] = [vec_out(at), vec_out(at + Vector3(0.0, 0.0, -6.0))]
			thing["speed"] = 3.0
			thing["wait"] = 0.8
			thing["loop"] = false
			thing["channel"] = ""
		"hazard":
			thing["size"] = [4.0, 0.4, 4.0]
		"panel":
			thing["piece"] = "cube"
			thing["size"] = [4.0, 4.0, 0.3]
		"slider":
			thing["piece"] = "cube"
			thing["size"] = [3.0, 1.0, 3.0]
			thing["surface"] = Surfaces.STONE
			thing["travel"] = [0.0, 0.0, -6.0]
			thing["speed"] = 6.0
	return thing


static func load_file(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		var level: Dictionary = parsed
		if not level.has("objects"):
			level["objects"] = []
		return level
	push_warning("Not a level: %s" % path)
	return {}


## Writes [param level] to [param path], making its folder if need be. True if it
## was written.
static func save_file(level: Dictionary, path: String) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(level, "\t", false))
	return true


## Where a level called [param title] is saved: with the built-in ones when the
## project folder can be written to — running from the project — and in the
## player's own folder when it cannot.
static func save_path(title: String) -> String:
	var file := slug(title) + ".json"
	var probe := FileAccess.open(BUILT_IN + ".write_probe", FileAccess.WRITE)
	if probe != null:
		probe.close()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BUILT_IN + ".write_probe"))
		return BUILT_IN + file
	return MADE + file


static func slug(title: String) -> String:
	var out := ""
	for c in title.to_lower():
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9"):
			out += c
		elif not out.ends_with("_") and out != "":
			out += "_"
	out = out.trim_suffix("_")
	return out if out != "" else "level"


## Every level there is, built-in first in their numbered order, then the
## player's own: an array of [code]{path, name, built_in}[/code].
static func catalogue() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for folder in [BUILT_IN, MADE]:
		if not DirAccess.dir_exists_absolute(folder):
			continue
		var files := Array(DirAccess.get_files_at(folder))
		files.sort()
		for file in files:
			if not String(file).ends_with(".json"):
				continue
			var path: String = folder + file
			if folder == MADE and found.any(func(e: Dictionary) -> bool:
					return String(e["path"]).get_file() == file):
				continue
			var level := load_file(path)
			if level.is_empty():
				continue
			found.append({"path": path, "name": level.get("name", file.get_basename()),
				"built_in": folder == BUILT_IN})
	return found


# --- reading and writing the pieces of a thing ------------------------------

static func vec(value: Variant, fallback := Vector3.ZERO) -> Vector3:
	if value is Array and (value as Array).size() >= 3:
		var a: Array = value
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return fallback


static func vec_out(value: Vector3) -> Array:
	return [snappedf(value.x, 0.001), snappedf(value.y, 0.001), snappedf(value.z, 0.001)]


## Where [param thing] is and how it is turned.
static func transform_of(thing: Dictionary) -> Transform3D:
	var turn := vec(thing.get("rot"))
	var basis := Basis.from_euler(Vector3(deg_to_rad(turn.x), deg_to_rad(turn.y),
		deg_to_rad(turn.z)), EULER_ORDER_YXZ)
	return Transform3D(basis, vec(thing.get("pos")))


static func path_of(thing: Dictionary) -> PackedVector3Array:
	var points := PackedVector3Array()
	var raw: Variant = thing.get("path", [])
	if raw is Array:
		for point in raw:
			points.append(vec(point))
	return points
