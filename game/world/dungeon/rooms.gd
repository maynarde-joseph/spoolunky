class_name Rooms
extends RefCounted

## The dungeon's rooms: what each is called and the class that builds it, the sides
## it can have a doorway on, and the shell they are all built in.
##
## Every room is the same square on the floor plan, [constant CELL] metres across,
## walled all round and roofed — a spider climbs anything, so a room open to the sky
## is a room it leaves — with a doorway in the middle of each side it has one on.
## A doorway is the same size in every room, so any two rooms meet: the floor plan
## lays them side by side and opens the doorways between them, and a doorway that
## leads nowhere stays bricked up with its plug.
##
## Each room is made by hand, a class of its own, and baked into a scene by
## `tools/bake_level.gd`; the floor plan puts the scenes down. Open one in the editor
## to change it — and bake it again only to start it over.

## How far across a room is, outside wall to outside wall, and how thick its walls
## and its roof are.
const CELL := 24.0
const WALL := 1.0

## A doorway: how wide and how tall the way through is, and the frame round it —
## the kit's doorway, stretched, whose opening is half its width and three quarters
## of its height.
const DOOR := Vector2(4.0, 6.0)
const FRAME := Vector2(8.0, 8.0)

## The four sides, clockwise from north as the floor plan counts them, which way each
## faces, and what each is called in a room's node names.
enum Side { NORTH, EAST, SOUTH, WEST }
const FACING: Array[Vector3] = [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 0, 1),
	Vector3(-1, 0, 0)]
const SIDE_NAMES: Array[String] = ["North", "East", "South", "West"]

## What a room is for on the floor plan: anywhere, the way in, the way down, or off
## to one side at the end of a way.
const ANY := "any"
const ENTRANCE := "entrance"
const EXIT := "exit"
const DEAD_END := "dead end"

## Every room, by the name the floor plan and the bake know it by, and the class
## that builds it.
const ROOMS := {
	"entrance": "res://game/world/dungeon/entrance_room.gd",
	"hall": "res://game/world/dungeon/hall_room.gd",
	"gallery": "res://game/world/dungeon/gallery_room.gd",
	"crypt": "res://game/world/dungeon/crypt_room.gd",
	"chasm": "res://game/world/dungeon/chasm_room.gd",
	"vault": "res://game/world/dungeon/vault_room.gd",
	"pit": "res://game/world/dungeon/pit_room.gd",
}


## The class that builds [param room_id], or null.
static func builder(room_id: String) -> Script:
	return load(ROOMS[room_id]) as Script if ROOMS.has(room_id) else null


## The scene [param room_id] is baked to.
static func scene_of(room_id: String) -> String:
	var made := builder(room_id)
	return made.get_script_constant_map()["SCENE"] if made != null else ""


## The sides [param room_id] has doorways on, before it is turned.
static func doors_of(room_id: String) -> Array[int]:
	var found: Array[int] = []
	var made := builder(room_id)
	if made != null:
		found.assign(made.get_script_constant_map()["DOORS"])
	return found


## What [param room_id] is for: [constant ANY], [constant ENTRANCE], [constant EXIT]
## or [constant DEAD_END].
static func role_of(room_id: String) -> String:
	var made := builder(room_id)
	return made.get_script_constant_map()["ROLE"] if made != null else ANY


## [param sides] turned [param turns] quarter turns clockwise, seen from above.
static func turned(sides: Array[int], turns: int) -> Array[int]:
	var found: Array[int] = []
	for side in sides:
		found.append(posmod(side + turns, 4))
	return found


## The turn that takes a room's own sides round [param turns] quarter turns
## clockwise, seen from above: north to east, and so on.
static func turn_basis(turns: int) -> Basis:
	return Basis(Vector3.UP, -PI * 0.5 * float(turns))


# --- the shell --------------------------------------------------------------

## The shell of a room [param height] high inside: a stone floor, the walls, a
## doorway in the middle of each of [param doors] — bricked up with its plug until
## the floor plan opens it — and the roof. [param floor_hole] and [param roof_hole]
## are ways down and up through them, rectangles across the room from its middle.
static func shell(room: DungeonRoom, height: float, doors: Array[int],
		floor_hole := Rect2(), roof_hole := Rect2()) -> Node3D:
	room.doors = doors
	room.height = height
	var shell_node := WorldKit.group(room, "Shell")
	var inside := CELL - WALL * 2.0
	Site.floor_of(shell_node, "Floor", Vector2(inside, inside), Vector3.ZERO, "stone_dark",
		floor_hole)
	var whole := Rect2(-CELL * 0.5, -CELL * 0.5, CELL, CELL)
	var parts := Site.cut(whole, roof_hole)
	for i in parts.size():
		var part := parts[i]
		var middle := part.get_center()
		KitBlock.make(shell_node, "Roof%d" % (i + 1), "cube5",
			Vector3(part.size.x, WALL, part.size.y), WorldKit.at(Vector3(middle.x, height, middle.y)))
	for side in 4:
		_side(shell_node, side, height, doors.has(side))
	return shell_node


## One wall, along [param side]: whole, or in three with the doorway's frame in the
## middle, its plug in it, and the wall carried on over the frame to the roof.
static func _side(shell_node: Node3D, side: int, height: float, doorway: bool) -> void:
	var facing := FACING[side]
	var tag := SIDE_NAMES[side]
	var out := CELL * 0.5 - WALL * 0.5
	# North and south run the full width, corners and all; east and west fit between.
	var run := CELL if facing.z != 0.0 else CELL - WALL * 2.0
	if not doorway:
		KitBlock.make(shell_node, "Wall%s" % tag, "wall", Vector3(run, height, WALL),
			Site.frame(facing, 0.0, out, 0.0))
		return
	var beside := (run - FRAME.x) * 0.5
	for sign in [-1.0, 1.0]:
		KitBlock.make(shell_node, "Wall%s%d" % [tag, 1 if sign < 0.0 else 2], "wall",
			Vector3(beside, height, WALL),
			Site.frame(facing, sign * (FRAME.x + beside) * 0.5, out, 0.0))
	KitBlock.make(shell_node, "Door%s" % tag, "wall door", Vector3(FRAME.x, FRAME.y, WALL),
		Site.frame(facing, 0.0, out, 0.0))
	if height > FRAME.y:
		KitBlock.make(shell_node, "Over%s" % tag, "wall", Vector3(FRAME.x, height - FRAME.y, WALL),
			Site.frame(facing, 0.0, out, FRAME.y))
	KitBlock.make(shell_node, "Plug%s" % tag, "wall", Vector3(DOOR.x, DOOR.y, WALL * 0.9),
		Site.frame(facing, 0.0, out, 0.0))


# --- what rooms are furnished with --------------------------------------------

## A column of the kit's, [param thick] through and [param tall] high, standing at
## [param at].
static func column(parent: Node3D, part_name: String, at: Vector3, tall: float,
		thick := 1.4) -> KitBlock:
	return KitBlock.make(parent, part_name, "pillar3", Vector3(thick, tall, thick), WorldKit.at(at))


## A brazier: a bowl on a short stand at [param at], and the light it gives —
## warm, a few metres round, and without shadows, so a room can have several.
static func brazier(parent: Node3D, part_name: String, at: Vector3,
		tint := Color(1.0, 0.68, 0.38), reach := 10.0) -> Node3D:
	var holder := WorldKit.group(parent, part_name, WorldKit.at(at))
	KitBlock.make(holder, "Stand", "pillar", Vector3(0.45, 0.9, 0.45), Transform3D.IDENTITY)
	KitBlock.make(holder, "Bowl", "cylinder1", Vector3(1.1, 0.45, 1.1),
		WorldKit.at(Vector3(0.0, 0.9, 0.0)))
	lamp(holder, "Flame", Vector3(0.0, 1.9, 0.0), tint, reach)
	return holder


## A light at [param at], [param reach] metres round.
static func lamp(parent: Node3D, part_name: String, at: Vector3, tint: Color,
		reach := 10.0, energy := 1.6) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = part_name
	light.light_color = tint
	light.light_energy = energy
	light.omni_range = reach
	light.omni_attenuation = 1.2
	light.shadow_enabled = false
	light.position = at
	parent.add_child(light)
	return light


## A mark at [param at], facing [param facing]: where the spider comes in, where a
## creature can stand, where something can be left.
static func mark(parent: Node3D, part_name: String, at: Vector3,
		facing := Vector3.FORWARD) -> Marker3D:
	var marker := Marker3D.new()
	marker.name = part_name
	var flat := Vector3(facing.x, 0.0, facing.z)
	var turn := Basis.looking_at(flat.normalized()) if flat.length_squared() > 0.0001 \
		else Basis.IDENTITY
	marker.transform = Transform3D(turn, at)
	parent.add_child(marker)
	return marker


## The marks where creatures can stand, at [param points], under the room's marks.
static func spawns(room: DungeonRoom, points: Array[Vector3]) -> void:
	var holder := room.marks().get_node_or_null("Spawns") as Node3D
	if holder == null:
		holder = WorldKit.group(room.marks(), "Spawns")
	for i in points.size():
		mark(holder, "Spawn%d" % (i + 1), points[i])
