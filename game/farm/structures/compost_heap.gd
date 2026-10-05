class_name CompostHeap
extends FarmStructure

## Where flies breed. Now and then, while two grown flies live in its pen and the
## pen has water and room for one more, a new fly crawls out of it — so a pen kept
## well enough keeps itself stocked, and an empire grows.

## Seconds between hatchlings.
const BREED_TIME := 30.0

var _breed_left := BREED_TIME


func draw(on: Node3D, solid: bool) -> void:
	WorldKit.ball(on, "Heap", Vector3(0.7, 0.45, 0.7), WorldKit.at(Vector3(0.0, 0.15, 0.0)),
		"soil", solid)
	WorldKit.ball(on, "Peel", Vector3(0.22, 0.08, 0.16), WorldKit.at(Vector3(0.2, 0.55, 0.1), 30.0),
		"yellow", false)
	WorldKit.ball(on, "Rind", Vector3(0.18, 0.09, 0.2), WorldKit.at(Vector3(-0.22, 0.5, -0.12)),
		"leaf_light", false)
	WorldKit.ball(on, "Core", Vector3(0.1, 0.12, 0.1), WorldKit.at(Vector3(0.0, 0.6, -0.2)),
		"petal_red", false)
	WorldKit.ball(on, "Straw", Vector3(0.3, 0.06, 0.25), WorldKit.at(Vector3(-0.1, 0.56, 0.22)),
		"straw", false)


func _physics_process(delta: float) -> void:
	_breed_left -= delta
	if _breed_left > 0.0:
		return
	_breed_left = BREED_TIME
	breed()


## Lays a hatchling, if the pen will have one: of whichever kind has the most grown,
## content insects in it, if that is two or more, with water in the pen and room
## for one more. Returns it, or null.
func breed() -> Insect:
	if farm == null:
		return null
	var here := region()
	if not farm.grid.is_pen(here) or not farm.has_in(here, "pond"):
		return null
	var living := farm.insects_in(here)
	var grown := {}
	var best: InsectSpecies = null
	for insect in living:
		if insect.is_grown() and insect.content and insect.kind != null:
			grown[insect.kind] = int(grown.get(insect.kind, 0)) + 1
			if best == null or int(grown[insect.kind]) > int(grown.get(best, 0)):
				best = insect.kind
	if best == null or int(grown[best]) < 2:
		return null
	var wanted := best.space
	for insect in living:
		wanted += insect.kind.space
	if wanted > farm.grid.area_of(here):
		return null
	var hatchling := farm.add_insect(best, global_position + Vector3(0.0, 0.0, 0.9))
	farm.notice.emit("A %s crawled out of the compost heap" % best.display_name.to_lower())
	return hatchling


func reach_radius() -> float:
	return 0.6


func describe() -> String:
	return "Compost heap · flies breed here"
