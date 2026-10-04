class_name ChasmRoom
extends RefCounted

## A chasm: the floor has fallen into a trench ten metres deep right across the room,
## spikes at the bottom, and the bridge over it has broken in the middle. Two pillars
## stand up out of the trench to swing from. Its doorways are at the two ends, north
## and south, so the way through is always over it.

const SCENE := "res://game/world/dungeon/chasm.tscn"
const DOORS: Array[int] = [Rooms.Side.NORTH, Rooms.Side.SOUTH]
const ROLE := Rooms.CROSSING
const HEIGHT := 14.0

## Half the trench's width north to south, how deep it is, and the gap in the bridge.
const TRENCH := 4.0
const DEPTH := 10.0
const GAP := 2.4


static func build(room: DungeonRoom) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2207
	var inside := Rooms.CELL * 0.5 - Rooms.WALL
	Rooms.shell(room, HEIGHT, DOORS, Rect2(-inside, -TRENCH, inside * 2.0, TRENCH * 2.0))
	var trench := WorldKit.group(room, "Trench")
	Site.floor_of(trench, "Bottom", Vector2(inside * 2.0, TRENCH * 2.0), Vector3(0.0, -DEPTH, 0.0),
		"soil")
	for sign in [-1.0, 1.0]:
		KitBlock.make(trench, "Side%s" % ("North" if sign < 0.0 else "South"), "wall",
			Vector3(inside * 2.0, DEPTH, Rooms.WALL),
			WorldKit.at(Vector3(0.0, -DEPTH, sign * (TRENCH + Rooms.WALL * 0.5))))
		KitBlock.make(trench, "End%s" % ("West" if sign < 0.0 else "East"), "wall",
			Vector3(TRENCH * 2.0, DEPTH, Rooms.WALL),
			WorldKit.at(Vector3(sign * (inside + Rooms.WALL * 0.5), -DEPTH, 0.0), 90.0))
	for i in 14:
		var at := Vector3(rng.randf_range(-inside + 0.6, inside - 0.6), -DEPTH,
			rng.randf_range(-TRENCH + 0.5, TRENCH - 0.5))
		Kit.place(trench, "spikes big", WorldKit.at(at, rng.randf() * 360.0), "Spikes%d" % (i + 1))
	var features := WorldKit.group(room, "Features")
	var half := (TRENCH - GAP * 0.5)
	for sign in [-1.0, 1.0]:
		KitBlock.make(features, "Bridge%s" % ("North" if sign < 0.0 else "South"), "cube5",
			Vector3(2.0, 0.5, half), WorldKit.at(Vector3(0.0, -0.5, sign * (TRENCH - half * 0.5))))
		Rooms.column(features, "Pillar%s" % ("West" if sign < 0.0 else "East"),
			Vector3(sign * 6.0, -DEPTH, 0.0), DEPTH + 5.0, 1.6)
		Rooms.column(features, "Stump%s" % ("West" if sign < 0.0 else "East"),
			Vector3(sign * 9.0, -DEPTH, -2.2 * sign), 6.0, 1.2)
	var lights := WorldKit.group(room, "Lights")
	Rooms.lamp(lights, "Deep", Vector3(0.0, -6.0, 0.0), Color(0.45, 0.6, 1.0), 14.0, 1.4)
	Rooms.brazier(lights, "BrazierNorthWest", Vector3(-8.5, 0.0, -8.5))
	Rooms.brazier(lights, "BrazierSouthEast", Vector3(8.5, 0.0, 8.5))
	Rooms.spawns(room, [Vector3(5.0, 0.0, -8.0), Vector3(-5.0, 0.0, 8.0), Vector3(-6.0, 5.0, 0.0),
		Vector3(6.0, 5.0, 0.0)])
