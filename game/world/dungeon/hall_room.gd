class_name HallRoom
extends RefCounted

## A pillared hall: four great columns holding up the roof round a dais in the
## middle, braziers on the dais, crates and barrels against the walls. The plainest
## room on a floor, and the commonest — columns to swing round and string silk
## between, a dais to fight from.

const SCENE := "res://game/world/dungeon/hall.tscn"
const DOORS: Array[int] = [Rooms.Side.NORTH, Rooms.Side.EAST, Rooms.Side.SOUTH, Rooms.Side.WEST]
const ROLE := Rooms.ANY
const HEIGHT := 12.0


static func build(room: DungeonRoom) -> void:
	Rooms.shell(room, HEIGHT, DOORS)
	var features := WorldKit.group(room, "Features")
	for i in 4:
		var corner := Vector2(-1 if i % 3 == 0 else 1, -1 if i < 2 else 1)
		Rooms.column(features, "Column%d" % (i + 1), Vector3(corner.x * 6.5, 0.0, corner.y * 6.5),
			HEIGHT, 1.6)
	KitBlock.make(features, "Dais", "cube5", Vector3(8.0, 0.5, 8.0), WorldKit.at(Vector3.ZERO))
	KitBlock.make(features, "DaisTop", "cube5", Vector3(5.0, 0.5, 5.0),
		WorldKit.at(Vector3(0.0, 0.5, 0.0)))
	for spot in [Vector3(9.0, 0.0, -8.5), Vector3(9.0, 0.0, -6.3), Vector3(-9.0, 0.0, 8.5)]:
		Kit.place(features, "box", WorldKit.at(spot), "Crate%d" % features.get_child_count())
	for spot in [Vector3(-9.2, 0.0, -9.2), Vector3(-7.9, 0.0, -9.5), Vector3(8.6, 0.0, 9.3)]:
		KitBlock.make(features, "Barrel%d" % features.get_child_count(), "cylinder1",
			Vector3(1.1, 1.4, 1.1), WorldKit.at(spot))
	var lights := WorldKit.group(room, "Lights")
	Rooms.brazier(lights, "BrazierEast", Vector3(3.2, 0.5, -3.2))
	Rooms.brazier(lights, "BrazierWest", Vector3(-3.2, 0.5, 3.2))
	Rooms.spawns(room, [Vector3(0.0, 0.0, 8.0), Vector3(0.0, 0.0, -8.0), Vector3(8.0, 0.0, 0.0),
		Vector3(-8.0, 0.0, 0.0)])
