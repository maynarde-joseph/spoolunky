class_name VaultRoom
extends RefCounted

## A vault at the end of a way: one doorway, two rows of columns, and at the far end
## a dais with a pedestal on it, a key left on the pedestal and coins round it —
## where whatever a floor hides will be found. Braziers either side of the dais.

const SCENE := "res://game/world/dungeon/vault.tscn"
const DOORS: Array[int] = [Rooms.Side.SOUTH]
const ROLE := Rooms.DEAD_END
const HEIGHT := 10.0


static func build(room: DungeonRoom) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3313
	Rooms.shell(room, HEIGHT, DOORS)
	var features := WorldKit.group(room, "Features")
	KitBlock.make(features, "Dais", "cube5", Vector3(12.0, 0.5, 6.0),
		WorldKit.at(Vector3(0.0, 0.0, -8.0)))
	KitBlock.make(features, "DaisTop", "cube5", Vector3(8.0, 0.5, 4.0),
		WorldKit.at(Vector3(0.0, 0.5, -8.5)))
	KitBlock.make(features, "Pedestal", "cube", Vector3(1.2, 1.2, 1.2),
		WorldKit.at(Vector3(0.0, 1.0, -8.5)))
	Kit.place(features, "key", WorldKit.at(Vector3(0.0, 2.2, -8.5), 30.0), "Key")
	for i in 7:
		var at := Vector3(rng.randf_range(-3.5, 3.5), 1.0, -8.5 + rng.randf_range(-1.6, 1.6))
		if absf(at.x) < 0.9 and absf(at.z + 8.5) < 0.9:
			at.x += 1.6
		Kit.place(features, "coin", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), at),
			"Coin%d" % (i + 1))
	for x in [-5.0, 5.0]:
		for z in [-2.0, 4.0]:
			Rooms.column(features, "Column%d" % features.get_child_count(), Vector3(x, 0.0, z),
				HEIGHT, 1.2)
	for spot in [Vector3(-9.5, 0.0, 5.0), Vector3(9.5, 0.0, 5.5)]:
		Kit.place(features, "box", WorldKit.at(spot, 12.0), "Crate%d" % features.get_child_count())
	var lights := WorldKit.group(room, "Lights")
	Rooms.brazier(lights, "BrazierWest", Vector3(-5.0, 0.5, -9.0))
	Rooms.brazier(lights, "BrazierEast", Vector3(5.0, 0.5, -9.0))
	Rooms.mark(room.marks(), "Loot", Vector3(0.0, 2.2, -8.5), Vector3.BACK)
	Rooms.spawns(room, [Vector3(-3.0, 0.0, 5.0), Vector3(3.0, 0.0, 5.0)])
