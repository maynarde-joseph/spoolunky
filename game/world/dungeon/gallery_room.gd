class_name GalleryRoom
extends RefCounted

## A gallery: a balcony all the way round seven metres up, on columns, with a
## railing along its edge, and a flight of stairs up to it from two corners. What
## stands up there sees the whole room, and what is down on the floor is under it.
## A fallen chandelier lies in the middle.

const SCENE := "res://game/world/dungeon/gallery.tscn"
const DOORS: Array[int] = [Rooms.Side.NORTH, Rooms.Side.EAST, Rooms.Side.SOUTH, Rooms.Side.WEST]
const ROLE := Rooms.ANY
const HEIGHT := 14.0

## How high the balcony's floor is, how deep it is out from the wall, and how thick.
const BALCONY := 7.0
const DEEP := 3.0
const SLAB := 0.5

## How wide each flight of stairs is, and how far from the middle across it stands.
const STAIRS := 2.4
const STAIRS_AT := 6.0


static func build(room: DungeonRoom) -> void:
	Rooms.shell(room, HEIGHT, DOORS)
	var features := WorldKit.group(room, "Features")
	var inside := Rooms.CELL * 0.5 - Rooms.WALL
	var edge := inside - DEEP
	var under := BALCONY - SLAB
	# North and south run the width; east and west fit between them.
	for sign in [-1.0, 1.0]:
		var tag := "North" if sign < 0.0 else "South"
		KitBlock.make(features, "Balcony%s" % tag, "cube5", Vector3(inside * 2.0, SLAB, DEEP),
			WorldKit.at(Vector3(0.0, under, sign * (inside - DEEP * 0.5))))
		tag = "West" if sign < 0.0 else "East"
		KitBlock.make(features, "Balcony%s" % tag, "cube5", Vector3(DEEP, SLAB, edge * 2.0),
			WorldKit.at(Vector3(sign * (inside - DEEP * 0.5), under, 0.0)))
	# Columns under its inside edge, clear of the doorways.
	var posts := [Vector2(-edge, -edge), Vector2(edge, -edge), Vector2(edge, edge), Vector2(-edge, edge),
		Vector2(-4.0, -edge), Vector2(4.0, -edge), Vector2(-4.0, edge), Vector2(4.0, edge),
		Vector2(-edge, -4.0), Vector2(-edge, 4.0), Vector2(edge, -4.0), Vector2(edge, 4.0)]
	for i in posts.size():
		var post: Vector2 = posts[i]
		Rooms.column(features, "Post%d" % (i + 1), Vector3(post.x, 0.0, post.y), under, 0.9)
	# Stairs up to it, between the columns: rising north to the north side, and south
	# to the south side.
	KitBlock.make(features, "StairsWest", "stairs", Vector3(STAIRS, BALCONY, BALCONY),
		WorldKit.at(Vector3(-STAIRS_AT, 0.0, -edge + BALCONY * 0.5)))
	KitBlock.make(features, "StairsEast", "stairs", Vector3(STAIRS, BALCONY, BALCONY),
		WorldKit.at(Vector3(STAIRS_AT, 0.0, edge - BALCONY * 0.5), 180.0))
	# The railing along the edge, open where the stairs come up.
	var open_from := STAIRS_AT - STAIRS * 0.5
	var rails := [
		[Vector3((edge - open_from) * 0.5, BALCONY, -edge - 0.15), 0.0, edge + open_from],
		[Vector3(-(edge - open_from) * 0.5, BALCONY, edge + 0.15), 0.0, edge + open_from],
		[Vector3(edge + 0.15, BALCONY, 0.0), 90.0, edge * 2.0],
		[Vector3(-edge - 0.15, BALCONY, 0.0), 90.0, edge * 2.0],
	]
	for i in rails.size():
		var rail: Array = rails[i]
		KitBlock.make(features, "Railing%d" % (i + 1), "fence3", Vector3(rail[2], 1.1, 0.3),
			WorldKit.at(rail[0], rail[1]))
	KitBlock.make(features, "Chandelier", "torus", Vector3(4.0, 0.6, 4.0),
		Transform3D(Basis(Vector3.RIGHT, 0.25), Vector3(0.6, 0.15, -0.4)))
	var lights := WorldKit.group(room, "Lights")
	Rooms.brazier(lights, "BrazierNorthEast", Vector3(inside - DEEP * 0.5, BALCONY, -inside + DEEP * 0.5))
	Rooms.brazier(lights, "BrazierSouthWest", Vector3(-inside + DEEP * 0.5, BALCONY, inside - DEEP * 0.5))
	Rooms.lamp(lights, "Below", Vector3(0.0, 3.0, 0.0), Color(1.0, 0.7, 0.45), 9.0, 0.9)
	Rooms.spawns(room, [Vector3(5.0, 0.0, 5.0), Vector3(-5.0, 0.0, -5.0),
		Vector3(inside - DEEP * 0.5, BALCONY, 2.0), Vector3(-inside + DEEP * 0.5, BALCONY, -2.0)])
