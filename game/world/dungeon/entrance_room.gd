class_name EntranceRoom
extends RefCounted

## The way in: where the spider drops into a floor, through a shaft in the roof with
## the light coming down it. Broken columns stand round the landing and two braziers
## burn in the far corners. Nothing waits here: it is the one room on a floor that is
## quiet when you arrive.

const SCENE := "res://game/world/dungeon/entrance.tscn"
const DOORS: Array[int] = [Rooms.Side.NORTH, Rooms.Side.EAST, Rooms.Side.SOUTH, Rooms.Side.WEST]
const ROLE := Rooms.ENTRANCE
const HEIGHT := 12.0

## Half the width of the shaft down through the roof, and how far it goes up.
const SHAFT := 3.0
const SHAFT_UP := 6.0


static func build(room: DungeonRoom) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1101
	Rooms.shell(room, HEIGHT, DOORS, Rect2(), Rect2(-SHAFT, -SHAFT, SHAFT * 2.0, SHAFT * 2.0))
	var features := WorldKit.group(room, "Features")
	# The shaft: four walls up from the hole, open to the sky.
	var top := HEIGHT + Rooms.WALL
	for side in 4:
		var facing := Rooms.FACING[side]
		var length := SHAFT * 2.0 + Rooms.WALL * 2.0 if facing.z != 0.0 else SHAFT * 2.0
		KitBlock.make(features, "Shaft%s" % Rooms.SIDE_NAMES[side], "wall",
			Vector3(length, SHAFT_UP, Rooms.WALL), Site.frame(facing, 0.0, SHAFT + Rooms.WALL * 0.5, top))
	# Columns round the landing, broken off at all heights; one still holds the roof.
	var heights := [HEIGHT, 7.0, 4.5, 9.0]
	var corners := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	for i in corners.size():
		var corner: Vector2 = corners[i]
		Rooms.column(features, "Column%d" % (i + 1), Vector3(corner.x * 6.0, 0.0, corner.y * 6.0),
			heights[i], 1.4)
	Site.rubble(features, rng, Vector3(-5.0, 0.0, 3.5), 1.6, 5, 1.2)
	Site.rubble(features, rng, Vector3(6.5, 0.0, -2.5), 1.2, 4, 1.0)
	var lights := WorldKit.group(room, "Lights")
	Rooms.brazier(lights, "BrazierNorthWest", Vector3(-9.0, 0.0, -9.0))
	Rooms.brazier(lights, "BrazierSouthEast", Vector3(9.0, 0.0, 9.0))
	Rooms.lamp(lights, "Daylight", Vector3(0.0, HEIGHT - 2.0, 0.0), Color(0.78, 0.86, 1.0), 14.0, 1.2)
	# In under the shaft, a few metres up, facing south into the room.
	Rooms.mark(room.marks(), "Entry", Vector3(0.0, 6.0, 0.0), Vector3.BACK)
