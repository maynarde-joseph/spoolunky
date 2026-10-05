class_name ShadeTree
extends FarmStructure

## A tree to stand under. Everything in its pen keeps a little better, and its
## grade climbs faster for it — see [constant Insect.SHADE_KEEP]. And it is
## something to climb.


func draw(on: Node3D, solid: bool) -> void:
	WorldKit.cylinder(on, "Trunk", 0.2, 2.3, WorldKit.at(Vector3(0.0, 1.15, 0.0)), "bark", solid,
		0.14, 10)
	WorldKit.ball(on, "Canopy", Vector3(1.05, 0.8, 1.05), WorldKit.at(Vector3(0.0, 2.6, 0.0)),
		"leaf", solid)
	WorldKit.ball(on, "CanopyLow", Vector3(0.75, 0.55, 0.75),
		WorldKit.at(Vector3(0.45, 2.15, 0.3)), "leaf_dark", solid)
	WorldKit.ball(on, "CanopyHigh", Vector3(0.6, 0.5, 0.6),
		WorldKit.at(Vector3(-0.3, 3.1, -0.2)), "leaf_light", solid)


func reach_radius() -> float:
	return 0.3


func describe() -> String:
	return "Shade tree · everything in its pen keeps better"
