class_name CryptRoom
extends RefCounted

## A crypt: low — the roof no higher than a doorway's frame — and close, with thick
## columns and stone coffins in the dark between them, and two candles' worth of
## light. Short sight lines, and nowhere far to go up to.

const SCENE := "res://game/world/dungeon/crypt.tscn"
const DOORS: Array[int] = [Rooms.Side.NORTH, Rooms.Side.EAST, Rooms.Side.SOUTH, Rooms.Side.WEST]
const ROLE := Rooms.ANY
const HEIGHT := 8.0


static func build(room: DungeonRoom) -> void:
	Rooms.shell(room, HEIGHT, DOORS)
	var features := WorldKit.group(room, "Features")
	for i in 4:
		var corner := Vector2(-1 if i % 3 == 0 else 1, -1 if i < 2 else 1)
		Rooms.column(features, "Column%d" % (i + 1), Vector3(corner.x * 6.0, 0.0, corner.y * 6.0),
			HEIGHT, 1.6)
	var coffins := [Vector3(0.0, 0.0, 0.0), Vector3(-9.0, 0.0, -6.0), Vector3(9.0, 0.0, -6.0),
		Vector3(-9.0, 0.0, 6.0), Vector3(9.0, 0.0, 6.0)]
	for i in coffins.size():
		KitBlock.make(features, "Coffin%d" % (i + 1), "cube7", Vector3(1.6, 1.1, 3.4),
			WorldKit.at(coffins[i]))
	var lights := WorldKit.group(room, "Lights")
	var candle := Color(1.0, 0.62, 0.32)
	Rooms.brazier(lights, "CandleNorthEast", Vector3(9.5, 0.0, -9.5), candle, 8.0)
	Rooms.brazier(lights, "CandleSouthWest", Vector3(-9.5, 0.0, 9.5), candle, 8.0)
	Rooms.spawns(room, [Vector3(3.5, 0.0, 3.5), Vector3(-3.5, 0.0, -3.5), Vector3(3.5, 0.0, -3.5),
		Vector3(-3.5, 0.0, 3.5)])
