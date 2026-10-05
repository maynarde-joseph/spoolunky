class_name SugarBowl
extends FarmStructure

## A bowl of sugar: a fly's treat. Every fly in its pen keeps better for it, and its
## grade climbs faster — see [constant Insect.SUGAR_KEEP].


func draw(on: Node3D, solid: bool) -> void:
	WorldKit.cylinder(on, "Plinth", 0.32, 0.4, WorldKit.at(Vector3(0.0, 0.2, 0.0)), "stone_dark",
		solid, 0.26, 12)
	WorldKit.cylinder(on, "Bowl", 0.42, 0.18, WorldKit.at(Vector3(0.0, 0.49, 0.0)), "white", solid,
		0.5, 18)
	WorldKit.ball(on, "Sugar", Vector3(0.4, 0.1, 0.4), WorldKit.at(Vector3(0.0, 0.58, 0.0)),
		"petal_white", false)


func reach_radius() -> float:
	return 0.55


func describe() -> String:
	return "Sugar bowl · flies in its pen keep better"
