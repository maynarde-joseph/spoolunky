class_name Pond
extends FarmStructure

## Water for the pen it stands in, ringed with stones. It never runs dry; a pen
## without one is a pen of thirsty insects.

## From its middle to the stones round it, in metres.
const RIM := 1.62


func draw(on: Node3D, solid: bool) -> void:
	WorldKit.cylinder(on, "Bed", RIM + 0.05, 0.03, WorldKit.at(Vector3(0.0, 0.015, 0.0)),
		"soil", false, -1.0, 32)
	WorldKit.cylinder(on, "Water", RIM - 0.05, 0.04, WorldKit.at(Vector3(0.0, 0.07, 0.0)),
		"pond", false, -1.0, 32)
	var stones := 14
	for i in stones:
		var turn := TAU * float(i) / float(stones)
		var size := 0.2 + 0.06 * sin(float(i) * 2.3)
		WorldKit.ball(on, "Stone%d" % (i + 1), Vector3(size * 1.3, size * 0.7, size),
			Transform3D(Basis(Vector3.UP, -turn), Vector3(cos(turn) * RIM, size * 0.35,
				sin(turn) * RIM)), "rock" if i % 3 != 0 else "rock_dark", solid)


func reach_radius() -> float:
	return RIM + 0.15


func has_water() -> bool:
	return true


func water(_insect: Insect) -> bool:
	return true


func describe() -> String:
	return "Pond"
