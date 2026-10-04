class_name PitRoom
extends RefCounted

## The way down: a pit in the middle of the floor, the shaft under it going down
## into a glow, and the railing round its edge mostly fallen in. Drop down it and you
## are on the next floor.

const SCENE := "res://game/world/dungeon/pit.tscn"
const DOORS: Array[int] = [Rooms.Side.NORTH, Rooms.Side.EAST, Rooms.Side.SOUTH, Rooms.Side.WEST]
const ROLE := Rooms.EXIT
const HEIGHT := 12.0

## Half the pit's width, and how far down its shaft goes.
const PIT := 3.0
const SHAFT := 24.0

## Where in the shaft falling counts as going down, from the floor: the top and the
## bottom of the drop's trigger.
const DROP := Vector2(12.0, 20.0)


static func build(room: DungeonRoom) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4409
	Rooms.shell(room, HEIGHT, DOORS, Rect2(-PIT, -PIT, PIT * 2.0, PIT * 2.0))
	var shaft := WorldKit.group(room, "Shaft")
	for side in 4:
		var facing := Rooms.FACING[side]
		var length := PIT * 2.0 + Rooms.WALL * 2.0 if facing.z != 0.0 else PIT * 2.0
		KitBlock.make(shaft, "Side%s" % Rooms.SIDE_NAMES[side], "wall",
			Vector3(length, SHAFT, Rooms.WALL), Site.frame(facing, 0.0, PIT + Rooms.WALL * 0.5, -SHAFT))
	Site.floor_of(shaft, "Bottom", Vector2(PIT * 2.0, PIT * 2.0), Vector3(0.0, -SHAFT, 0.0), "soil")
	var drop := Area3D.new()
	drop.name = "WayDown"
	drop.collision_layer = 0
	drop.collision_mask = GameLayers.PLAYER
	drop.monitorable = false
	var box := BoxShape3D.new()
	box.size = Vector3(PIT * 2.0 - 0.4, DROP.y - DROP.x, PIT * 2.0 - 0.4)
	var shape := CollisionShape3D.new()
	shape.name = "Drop"
	shape.shape = box
	drop.add_child(shape)
	drop.position = Vector3(0.0, -(DROP.x + DROP.y) * 0.5, 0.0)
	room.add_child(drop)
	var features := WorldKit.group(room, "Features")
	# What is left of the railing round the edge.
	for piece in [[Vector3(-1.4, 0.0, -PIT - 0.2), 0.0, 2.6], [Vector3(PIT + 0.2, 0.0, 1.0), 90.0, 3.0],
			[Vector3(0.8, 0.0, PIT + 0.2), 0.0, 1.8]]:
		KitBlock.make(features, "Railing%d" % features.get_child_count(), "fence3",
			Vector3(piece[2], 1.1, 0.3), WorldKit.at(piece[0], piece[1]))
	Site.rubble(features, rng, Vector3(-5.5, 0.0, -4.5), 1.5, 5, 1.1)
	Site.rubble(features, rng, Vector3(5.0, 0.0, 5.5), 1.2, 4, 1.0)
	var lights := WorldKit.group(room, "Lights")
	Rooms.lamp(lights, "Glow", Vector3(0.0, -8.0, 0.0), Color(0.62, 0.45, 1.0), 16.0, 2.0)
	Rooms.brazier(lights, "BrazierNorthEast", Vector3(8.5, 0.0, -8.5))
	Rooms.brazier(lights, "BrazierSouthWest", Vector3(-8.5, 0.0, 8.5))
	Rooms.spawns(room, [Vector3(7.0, 0.0, 7.0), Vector3(-7.0, 0.0, -7.0), Vector3(7.0, 0.0, -7.0),
		Vector3(-7.0, 0.0, 7.0)])
