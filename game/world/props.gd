class_name Props
extends RefCounted

## Everything in the world that is a thing rather than a place: the tools on the
## bench, the benches in the park, the boats on the lake.
##
## Each is built here out of [WorldKit] solids, and baked once into its own scene
## in [constant DIR] so that the world holds instances of it rather than copies —
## change the bench and every bench changes, and the editor can drop another one
## wherever it is wanted. Run
##
##     godot --headless --path . --script res://tools/bake_props.gd
##
## to bake the ones that have no scene yet, and add `-- --force` to build them all
## again from here, which throws away anything changed in the scenes by hand.
##
## They are drawn the way the creatures are: smooth parts, a few flat colours,
## matte, and no detail that is not the shape of the thing. Every one stands on
## its origin and faces -Z, and every part of one is something to stand on unless
## it is too fine to matter — which, for something the size of a spiderling, is
## very little.
##
## They are all to one scale, the scale of the shed: a metre is about fourteen of
## them. A spiderling is a quarter of one, so a paint tin is ten times its height
## and a rake is a tree; a park bench is two shelves wide, and a rowing boat is a
## boat. The world is the size it is, and what changes is the spider.

const DIR := "res://game/world/props"

## Every prop there is, by the name its scene is saved under.
const ALL := [
	# The shed.
	"shelves", "workbench", "pegboard", "hammer", "saw", "spanner", "screwdriver",
	"paint_tin_red", "paint_tin_blue", "paint_tin_white", "paint_tin_yellow",
	"flowerpot", "flowerpot_stack", "watering_can", "toolbox", "jar", "bucket",
	"rake", "spade", "broom", "lawnmower", "sack", "hose", "crate", "seed_tray",
	"oil_can", "twine", "bulb",
	# The sewers.
	"sewer_lamp", "pipe_mouth", "valve_wheel", "tyre", "traffic_cone",
	# The park.
	"bench", "bin", "lamp_post", "tree_oak", "tree_birch", "tree_pine", "bush",
	"bush_flowering", "flower_bed", "railing", "picket_fence", "aviary", "kennel",
	"dog_bowl", "ball", "sign", "water_butt", "compost_bin", "wheelbarrow",
	# The lake.
	"boat_red", "boat_blue", "boat_green", "boat_yellow", "bandstand", "lifebuoy",
	"reeds", "lily_pad",
]


## Builds [param id] from scratch: a body with its solids on it, named for it.
static func build(id: String) -> Node3D:
	match id:
		"shelves": return _shelves()
		"workbench": return _workbench()
		"pegboard": return _pegboard()
		"hammer": return _hammer()
		"saw": return _saw()
		"spanner": return _spanner()
		"screwdriver": return _screwdriver()
		"paint_tin_red": return _paint_tin("PaintTinRed", "red")
		"paint_tin_blue": return _paint_tin("PaintTinBlue", "blue")
		"paint_tin_white": return _paint_tin("PaintTinWhite", "white")
		"paint_tin_yellow": return _paint_tin("PaintTinYellow", "yellow")
		"flowerpot": return _flowerpot()
		"flowerpot_stack": return _flowerpot_stack()
		"watering_can": return _watering_can()
		"toolbox": return _toolbox()
		"jar": return _jar()
		"bucket": return _bucket()
		"rake": return _rake()
		"spade": return _spade()
		"broom": return _broom()
		"lawnmower": return _lawnmower()
		"sack": return _sack()
		"hose": return _hose()
		"crate": return _crate()
		"seed_tray": return _seed_tray()
		"oil_can": return _oil_can()
		"twine": return _twine()
		"bulb": return _bulb()
		"sewer_lamp": return _sewer_lamp()
		"pipe_mouth": return _pipe_mouth()
		"valve_wheel": return _valve_wheel()
		"tyre": return _tyre()
		"traffic_cone": return _traffic_cone()
		"bench": return _bench()
		"bin": return _bin()
		"lamp_post": return _lamp_post()
		"tree_oak": return _tree_oak()
		"tree_birch": return _tree_birch()
		"tree_pine": return _tree_pine()
		"bush": return _bush(false)
		"bush_flowering": return _bush(true)
		"flower_bed": return _flower_bed()
		"railing": return _railing()
		"picket_fence": return _picket_fence()
		"aviary": return _aviary()
		"kennel": return _kennel()
		"dog_bowl": return _dog_bowl()
		"ball": return _ball()
		"sign": return _sign()
		"water_butt": return _water_butt()
		"compost_bin": return _compost_bin()
		"wheelbarrow": return _wheelbarrow()
		"boat_red": return _boat("BoatRed", "red")
		"boat_blue": return _boat("BoatBlue", "blue")
		"boat_green": return _boat("BoatGreen", "green")
		"boat_yellow": return _boat("BoatYellow", "yellow")
		"bandstand": return _bandstand()
		"lifebuoy": return _lifebuoy()
		"reeds": return _reeds()
		"lily_pad": return _lily_pad()
	push_error("no such prop: %s" % id)
	return null


## Where [param id]'s scene is kept.
static func path_of(id: String) -> String:
	return DIR.path_join(id + ".tscn")


## Puts one [param id] in [param parent] at [param where]: an instance of its baked
## scene when there is one, and one built on the spot when there is not.
static func place(parent: Node, id: String, where: Transform3D, part_name := "") -> Node3D:
	var made: Node3D = null
	var path := path_of(id)
	if ResourceLoader.exists(path):
		var scene := load(path) as PackedScene
		if scene != null:
			made = scene.instantiate() as Node3D
	if made == null:
		made = build(id)
	if made == null:
		return null
	if not part_name.is_empty():
		made.name = part_name
	made.transform = where
	parent.add_child(made, true)
	return made


# --- the shed ------------------------------------------------------------

## Shelving: two sides, a back, and five boards, the top one at a little over a
## metre and a half. Seventeen wide, five deep.
static func _shelves() -> Node3D:
	var it := WorldKit.body(null, "Shelves")
	var width := 17.0
	var depth := 5.0
	var height := 25.5
	for side in [-1.0, 1.0]:
		WorldKit.block(it, "Side", Vector3(side * width * 0.5 - 0.3, 0.0, -depth * 0.5),
			Vector3(side * width * 0.5 + 0.3, height, depth * 0.5), "wood")
	WorldKit.block(it, "Back", Vector3(-width * 0.5 + 0.3, 0.0, depth * 0.5 - 0.3),
		Vector3(width * 0.5 - 0.3, height, depth * 0.5), "wood_dark")
	for i in 5:
		var y := 0.6 + float(i) * 6.1
		WorldKit.block(it, "Board", Vector3(-width * 0.5 + 0.3, y - 0.5, -depth * 0.5),
			Vector3(width * 0.5 - 0.3, y, depth * 0.5 - 0.3), "wood_light")
	return it


## A workbench along a wall: a thick top on four legs, a shelf underneath, and a
## vice on the front corner.
static func _workbench() -> Node3D:
	var it := WorldKit.body(null, "Workbench")
	var length := 26.0
	var depth := 8.6
	WorldKit.block(it, "Top", Vector3(-length * 0.5, 11.2, -depth * 0.5),
		Vector3(length * 0.5, 12.5, depth * 0.5), "wood_warm")
	for x in [-length * 0.5 + 1.0, length * 0.5 - 1.0]:
		for z in [-depth * 0.5 + 1.0, depth * 0.5 - 1.0]:
			WorldKit.box(it, "Leg", Vector3(1.2, 11.2, 1.2),
				WorldKit.at(Vector3(x, 5.6, z)), "wood_dark")
	WorldKit.block(it, "Shelf", Vector3(-length * 0.5 + 0.4, 2.4, -depth * 0.5 + 0.4),
		Vector3(length * 0.5 - 0.4, 3.0, depth * 0.5 - 0.4), "wood")
	WorldKit.block(it, "Rail", Vector3(-length * 0.5 + 1.6, 8.0, depth * 0.5 - 1.3),
		Vector3(length * 0.5 - 1.6, 9.4, depth * 0.5 - 0.7), "wood_dark")
	# The vice, bolted to the front at the right-hand end.
	var vice := Vector3(length * 0.5 - 3.0, 12.5, -depth * 0.5)
	WorldKit.block(it, "Vice", vice + Vector3(-1.4, 0.0, 0.2), vice + Vector3(1.4, 1.8, 2.4), "blue")
	WorldKit.block(it, "Jaw", vice + Vector3(-1.4, 0.0, -1.0), vice + Vector3(1.4, 1.8, -0.2), "blue")
	WorldKit.rod(it, "Screw", vice + Vector3(0.0, 0.8, 0.8), vice + Vector3(0.0, 0.8, -2.6),
		0.2, "steel")
	WorldKit.rod(it, "Tommy", vice + Vector3(-1.5, 0.8, -2.5), vice + Vector3(1.5, 0.8, -2.5),
		0.14, "steel")
	return it


## A pegboard for the wall above the bench, with pegs out of it to hang tools on.
## It faces -Z, standing on its own bottom edge.
static func _pegboard() -> Node3D:
	var it := WorldKit.body(null, "Pegboard")
	WorldKit.block(it, "Board", Vector3(-10.0, 0.0, -0.2), Vector3(10.0, 12.0, 0.2), "canvas")
	for x in [-7.0, -2.5, 2.5, 7.0]:
		for y in [3.0, 8.5]:
			WorldKit.rod(it, "Peg", Vector3(x, y, -0.2), Vector3(x, y + 0.3, -1.0), 0.09,
				"steel", false)
	return it


## A claw hammer lying on its side: the handle along X, the head across it.
static func _hammer() -> Node3D:
	var it := WorldKit.body(null, "Hammer")
	WorldKit.rod(it, "Handle", Vector3(-2.4, 0.26, 0.0), Vector3(1.6, 0.26, 0.0), 0.22, "wood_light")
	WorldKit.box(it, "Head", Vector3(0.55, 0.55, 1.6), WorldKit.at(Vector3(1.9, 0.275, 0.1)), "iron")
	WorldKit.rod(it, "Face", Vector3(1.9, 0.275, -0.7), Vector3(1.9, 0.275, -1.1), 0.3, "iron")
	# The claw: two tines splayed back and down off the other end of the head.
	for side in [-1.0, 1.0]:
		WorldKit.rod(it, "Claw", Vector3(1.9 + side * 0.12, 0.3, 0.8),
			Vector3(1.9 + side * 0.18, 0.12, 1.5), 0.1, "iron", false)
	return it


## A handsaw lying flat: a blade narrowing to its tip, and a closed wooden grip.
static func _saw() -> Node3D:
	var it := WorldKit.body(null, "Saw")
	var y := 0.2
	WorldKit.plate(it, "Blade", PackedVector3Array([
		Vector3(-1.8, y, -0.55), Vector3(3.9, y, -0.35), Vector3(3.9, y, 0.2),
		Vector3(-1.8, y, 0.95)]), 0.06, "steel")
	# The grip: a closed loop of wood round the hand's way in.
	WorldKit.box(it, "Grip", Vector3(0.5, 0.4, 1.9), WorldKit.at(Vector3(-2.0, y, 0.2)), "wood_warm")
	WorldKit.box(it, "Grip", Vector3(0.5, 0.4, 1.9), WorldKit.at(Vector3(-3.3, y, 0.2)), "wood_warm")
	WorldKit.box(it, "Grip", Vector3(1.8, 0.4, 0.45), WorldKit.at(Vector3(-2.65, y, -0.55)), "wood_warm")
	WorldKit.box(it, "Grip", Vector3(1.8, 0.4, 0.45), WorldKit.at(Vector3(-2.65, y, 0.95)), "wood_warm")
	return it


## An open-ended spanner, flat: a bar with a ring at one end and jaws at the other.
static func _spanner() -> Node3D:
	var it := WorldKit.body(null, "Spanner")
	WorldKit.box(it, "Bar", Vector3(2.6, 0.12, 0.34), WorldKit.at(Vector3(0.0, 0.1, 0.0)), "steel")
	WorldKit.ring(it, "Ring", 0.42, 0.2, WorldKit.at(Vector3(-1.65, 0.1, 0.0)), "steel", true)
	for side in [-1.0, 1.0]:
		WorldKit.box(it, "Jaw", Vector3(0.7, 0.14, 0.22),
			WorldKit.at(Vector3(1.6, 0.1, side * 0.32), side * 25.0), "steel")
	return it


## A screwdriver lying down: a fat red handle and a thin steel shaft.
static func _screwdriver() -> Node3D:
	var it := WorldKit.body(null, "Screwdriver")
	WorldKit.capsule(it, "Handle", 0.3, 1.6, Transform3D(Basis(Vector3.BACK, PI * 0.5),
		Vector3(-1.0, 0.3, 0.0)), "red")
	WorldKit.rod(it, "Shaft", Vector3(-0.3, 0.3, 0.0), Vector3(1.8, 0.3, 0.0), 0.07, "steel")
	WorldKit.box(it, "Tip", Vector3(0.3, 0.05, 0.18), WorldKit.at(Vector3(1.9, 0.3, 0.0)), "steel",
		false)
	return it


## A tin of paint: a steel can with a band of its colour round it and a lid.
static func _paint_tin(part_name: String, colour: String) -> Node3D:
	var it := WorldKit.body(null, part_name)
	WorldKit.cylinder(it, "Can", 1.2, 2.5, WorldKit.at(Vector3(0.0, 1.25, 0.0)), "steel")
	WorldKit.cylinder(it, "Label", 1.22, 1.5, WorldKit.at(Vector3(0.0, 1.15, 0.0)), colour, false)
	WorldKit.ring(it, "Rim", 1.1, 0.14, WorldKit.at(Vector3(0.0, 2.5, 0.0)), "steel")
	# The wire handle, laid over to one side.
	WorldKit.rod(it, "Handle", Vector3(-1.2, 2.0, 0.0), Vector3(-0.2, 2.62, 0.9), 0.05, "iron", false)
	WorldKit.rod(it, "Handle", Vector3(-0.2, 2.62, 0.9), Vector3(1.2, 2.0, 0.0), 0.05, "iron", false)
	return it


## A terracotta flowerpot with a rim, and earth in it.
static func _flowerpot() -> Node3D:
	var it := WorldKit.body(null, "Flowerpot")
	WorldKit.cylinder(it, "Pot", 0.8, 1.7, WorldKit.at(Vector3(0.0, 0.85, 0.0)), "terracotta",
		true, 1.05)
	WorldKit.cylinder(it, "Rim", 1.18, 0.4, WorldKit.at(Vector3(0.0, 1.85, 0.0)), "terracotta")
	WorldKit.cylinder(it, "Earth", 1.0, 0.1, WorldKit.at(Vector3(0.0, 1.95, 0.0)), "soil", false)
	return it


## Three pots nested in each other, the way they are always kept.
static func _flowerpot_stack() -> Node3D:
	var it := WorldKit.body(null, "FlowerpotStack")
	for i in 3:
		var y := float(i) * 0.6
		WorldKit.cylinder(it, "Pot", 0.8, 1.7, WorldKit.at(Vector3(0.0, 0.85 + y, 0.0)),
			"terracotta", i == 0, 1.05)
		WorldKit.cylinder(it, "Rim", 1.18, 0.4, WorldKit.at(Vector3(0.0, 1.85 + y, 0.0)),
			"terracotta", i == 2)
	WorldKit.cylinder(it, "Inside", 0.95, 1.2, WorldKit.at(Vector3(0.0, 1.9, 0.0)), "terracotta",
		true)
	return it


## A watering can: a round body, a long spout out of the front with its rose, and a
## handle over the top.
static func _watering_can() -> Node3D:
	var it := WorldKit.body(null, "WateringCan")
	WorldKit.cylinder(it, "Body", 1.6, 3.2, WorldKit.at(Vector3(0.0, 1.6, 0.0)), "green")
	WorldKit.cylinder(it, "Top", 1.3, 0.5, WorldKit.at(Vector3(0.0, 3.4, 0.0)), "green", true, 0.7)
	WorldKit.rod(it, "Spout", Vector3(0.0, 0.8, -1.2), Vector3(0.0, 3.8, -4.2), 0.22, "green",
		true, 0.14)
	WorldKit.cylinder(it, "Rose", 0.4, 0.4, Transform3D(WorldKit.upright(Vector3(0.0, 1.0, -1.0)),
		Vector3(0.0, 3.95, -4.35)), "green", false, 0.55)
	WorldKit.ring(it, "Handle", 1.1, 0.24, Transform3D(Basis(Vector3.RIGHT, PI * 0.5)
		* Basis(Vector3.BACK, PI * 0.5), Vector3(0.0, 3.4, 0.4)), "green")
	return it


## A red metal toolbox with a carrying handle.
static func _toolbox() -> Node3D:
	var it := WorldKit.body(null, "Toolbox")
	WorldKit.block(it, "Box", Vector3(-3.1, 0.0, -1.4), Vector3(3.1, 2.3, 1.4), "red")
	WorldKit.block(it, "Lid", Vector3(-3.15, 2.3, -1.45), Vector3(3.15, 2.6, 1.45), "red")
	for x in [-1.8, 1.8]:
		WorldKit.rod(it, "Post", Vector3(x, 2.6, 0.0), Vector3(x, 3.4, 0.0), 0.12, "iron", false)
	WorldKit.rod(it, "Handle", Vector3(-1.9, 3.4, 0.0), Vector3(1.9, 3.4, 0.0), 0.2, "black")
	for x in [-2.3, 2.3]:
		WorldKit.box(it, "Catch", Vector3(0.5, 0.6, 0.1), WorldKit.at(Vector3(x, 2.2, -1.45)),
			"steel", false)
	return it


## A jam jar of screws: glass, with the screws showing through it.
static func _jar() -> Node3D:
	var it := WorldKit.body(null, "Jar")
	WorldKit.cylinder(it, "Glass", 0.7, 1.8, WorldKit.at(Vector3(0.0, 0.9, 0.0)), "glass")
	WorldKit.cylinder(it, "Screws", 0.6, 1.0, WorldKit.at(Vector3(0.0, 0.52, 0.0)), "steel", false)
	WorldKit.cylinder(it, "Lid", 0.72, 0.28, WorldKit.at(Vector3(0.0, 1.94, 0.0)), "yellow")
	return it


## A galvanised bucket, wider at the top, with its handle up.
static func _bucket() -> Node3D:
	var it := WorldKit.body(null, "Bucket")
	WorldKit.cylinder(it, "Pail", 1.4, 3.6, WorldKit.at(Vector3(0.0, 1.8, 0.0)), "steel", true, 1.8)
	WorldKit.ring(it, "Rim", 1.8, 0.16, WorldKit.at(Vector3(0.0, 3.6, 0.0)), "steel")
	WorldKit.ring(it, "Handle", 1.8, 0.1, Transform3D(Basis(Vector3.BACK, PI * 0.5),
		Vector3(0.0, 3.6, 0.0)), "iron")
	return it


## A garden rake standing on its tines: the handle a metre and a half of it.
static func _rake() -> Node3D:
	var it := WorldKit.body(null, "Rake")
	WorldKit.rod(it, "Handle", Vector3(0.0, 1.2, 0.0), Vector3(0.0, 22.0, 0.0), 0.28, "wood_light")
	WorldKit.rod(it, "Head", Vector3(-2.8, 1.0, 0.0), Vector3(2.8, 1.0, 0.0), 0.28, "iron")
	for i in 11:
		var x := -2.5 + float(i) * 0.5
		WorldKit.rod(it, "Tine", Vector3(x, 1.0, 0.0), Vector3(x, 0.05, -0.35), 0.07, "iron", false)
	return it


## A spade standing on its blade, with a D-grip at the top.
static func _spade() -> Node3D:
	var it := WorldKit.body(null, "Spade")
	WorldKit.box(it, "Blade", Vector3(2.8, 3.6, 0.15), WorldKit.at(Vector3(0.0, 1.8, 0.0)), "steel")
	WorldKit.cylinder(it, "Socket", 0.55, 1.2, WorldKit.at(Vector3(0.0, 4.1, 0.0)), "iron",
		true, 0.32)
	WorldKit.rod(it, "Shaft", Vector3(0.0, 4.6, 0.0), Vector3(0.0, 12.4, 0.0), 0.3, "wood_light")
	WorldKit.ring(it, "Grip", 0.75, 0.24, Transform3D(Basis(Vector3.RIGHT, PI * 0.5),
		Vector3(0.0, 13.1, 0.0)), "wood_light", false)
	return it


## A yard broom: a long handle in a head of bristles, standing on the bristles.
static func _broom() -> Node3D:
	var it := WorldKit.body(null, "Broom")
	WorldKit.block(it, "Bristles", Vector3(-2.4, 0.0, -0.5), Vector3(2.4, 1.6, 0.5), "straw")
	WorldKit.block(it, "Head", Vector3(-2.6, 1.6, -0.6), Vector3(2.6, 2.5, 0.6), "wood")
	WorldKit.rod(it, "Handle", Vector3(0.0, 2.5, 0.0), Vector3(0.0, 18.5, 1.4), 0.28, "wood_light")
	return it


## A rotary mower: a round deck on four wheels, the motor on top, and the handle
## back and up to where a hand would be.
static func _lawnmower() -> Node3D:
	var it := WorldKit.body(null, "Lawnmower")
	WorldKit.cylinder(it, "Deck", 3.4, 1.4, WorldKit.at(Vector3(0.0, 1.9, 0.0)), "green")
	WorldKit.cylinder(it, "Motor", 1.7, 2.0, WorldKit.at(Vector3(0.0, 3.6, 0.2)), "black", true, 1.4)
	WorldKit.cylinder(it, "Cap", 0.6, 0.5, WorldKit.at(Vector3(0.0, 4.85, 0.2)), "red")
	var across := Basis(Vector3.BACK, PI * 0.5)
	for x in [-3.2, 3.2]:
		for z in [-2.4, 2.4]:
			WorldKit.cylinder(it, "Wheel", 1.1, 0.6, Transform3D(across, Vector3(x, 1.1, z)),
				"rubber")
	for x in [-2.2, 2.2]:
		WorldKit.rod(it, "Handle", Vector3(x, 2.2, 2.6), Vector3(x, 12.0, 9.0), 0.2, "iron")
	WorldKit.rod(it, "Bar", Vector3(-2.3, 12.0, 9.0), Vector3(2.3, 12.0, 9.0), 0.26, "black")
	WorldKit.block(it, "Catcher", Vector3(-2.0, 1.2, 3.2), Vector3(2.0, 4.4, 6.8), "canvas")
	return it


## A sack of compost lying on its side.
static func _sack() -> Node3D:
	var it := WorldKit.body(null, "Sack")
	WorldKit.ball(it, "Sack", Vector3(3.2, 1.2, 2.2), WorldKit.at(Vector3(0.0, 1.2, 0.0)), "canvas")
	WorldKit.ball(it, "Tie", Vector3(0.6, 0.5, 0.9), WorldKit.at(Vector3(3.1, 1.0, 0.0)), "canvas",
		false)
	return it


## A garden hose coiled on the floor.
static func _hose() -> Node3D:
	var it := WorldKit.body(null, "Hose")
	for i in 5:
		WorldKit.ring(it, "Turn", 2.6 - float(i % 2) * 0.12, 0.5,
			WorldKit.at(Vector3(0.0, 0.25 + float(i) * 0.46, 0.0), float(i) * 23.0), "hose")
	WorldKit.cylinder(it, "Coil", 2.85, 2.5, WorldKit.at(Vector3(0.0, 1.25, 0.0)), "hose", true)
	it.get_node("Coil").visible = false
	WorldKit.rod(it, "End", Vector3(2.6, 0.25, 0.0), Vector3(4.6, 0.25, -1.2), 0.25, "hose", false)
	return it


## A slatted wooden crate: solid to walk on, with its slats showing.
static func _crate() -> Node3D:
	var it := WorldKit.body(null, "Crate")
	var size := Vector3(6.0, 4.0, 4.0)
	WorldKit.collider(it, "Solid", size, WorldKit.at(Vector3(0.0, size.y * 0.5, 0.0)))
	WorldKit.block(it, "Inside", Vector3(-2.8, 0.1, -1.8), Vector3(2.8, 3.8, 1.8), "wood_dark", false)
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		WorldKit.box(it, "Post", Vector3(0.5, size.y, 0.5), WorldKit.at(Vector3(
			corner.x * (size.x * 0.5 - 0.25), size.y * 0.5, corner.y * (size.z * 0.5 - 0.25))),
			"wood", false)
	for i in 3:
		var y := 0.6 + float(i) * 1.35
		for z in [-size.z * 0.5 + 0.1, size.z * 0.5 - 0.1]:
			WorldKit.box(it, "Slat", Vector3(size.x, 0.8, 0.2), WorldKit.at(Vector3(0.0, y, z)),
				"wood_warm", false)
		for x in [-size.x * 0.5 + 0.1, size.x * 0.5 - 0.1]:
			WorldKit.box(it, "Slat", Vector3(0.2, 0.8, size.z), WorldKit.at(Vector3(x, y, 0.0)),
				"wood_warm", false)
	return it


## A seed tray of earth with seedlings coming up in rows.
static func _seed_tray() -> Node3D:
	var it := WorldKit.body(null, "SeedTray")
	WorldKit.block(it, "Tray", Vector3(-2.5, 0.0, -1.7), Vector3(2.5, 0.8, 1.7), "black")
	WorldKit.block(it, "Earth", Vector3(-2.35, 0.8, -1.55), Vector3(2.35, 0.85, 1.55), "soil", false)
	for i in 5:
		for j in 3:
			var at := Vector3(-2.0 + float(i), 0.85, -1.0 + float(j))
			WorldKit.rod(it, "Shoot", at, at + Vector3(0.0, 0.55, 0.0), 0.05, "leaf_light", false)
			WorldKit.ball(it, "Leaf", Vector3(0.22, 0.08, 0.14), WorldKit.at(at + Vector3(0.0, 0.58,
				0.0), float(i * 40 + j * 70)), "leaf_light", false)
	return it


## A little oil can with a long spout.
static func _oil_can() -> Node3D:
	var it := WorldKit.body(null, "OilCan")
	WorldKit.cylinder(it, "Body", 0.8, 1.1, WorldKit.at(Vector3(0.0, 0.55, 0.0)), "red")
	WorldKit.cylinder(it, "Shoulder", 0.8, 0.6, WorldKit.at(Vector3(0.0, 1.4, 0.0)), "red", true, 0.2)
	WorldKit.rod(it, "Spout", Vector3(0.0, 1.6, 0.0), Vector3(0.0, 3.4, -1.6), 0.07, "steel", false)
	return it


## A ball of garden twine.
static func _twine() -> Node3D:
	var it := WorldKit.body(null, "Twine")
	WorldKit.ball(it, "Ball", Vector3(0.7, 0.62, 0.7), WorldKit.at(Vector3(0.0, 0.62, 0.0)), "straw")
	return it


## A bare bulb under an enamel shade, on a flex. It hangs from its origin, which
## is where the flex meets the ceiling, and it lights the room.
static func _bulb() -> Node3D:
	var it := WorldKit.body(null, "Bulb")
	WorldKit.rod(it, "Flex", Vector3(0.0, 0.0, 0.0), Vector3(0.0, -6.0, 0.0), 0.06, "black", false)
	WorldKit.cylinder(it, "Shade", 2.2, 1.6, WorldKit.at(Vector3(0.0, -6.6, 0.0)), "green", true, 0.35)
	WorldKit.ball(it, "Glass", Vector3(0.55, 0.65, 0.55), WorldKit.at(Vector3(0.0, -7.6, 0.0)),
		"bulb", false)
	_light(it, Vector3(0.0, -7.9, 0.0), 46.0, 2.4, Color(1.0, 0.88, 0.7))
	return it


# --- the sewers ----------------------------------------------------------

## A caged lamp on a bracket out of a wall. Its origin is on the wall and it
## sticks out towards -Z.
static func _sewer_lamp() -> Node3D:
	var it := WorldKit.body(null, "SewerLamp")
	WorldKit.box(it, "Plate", Vector3(1.4, 2.0, 0.3), WorldKit.at(Vector3(0.0, 0.0, -0.15)), "iron")
	WorldKit.rod(it, "Arm", Vector3(0.0, 0.3, -0.2), Vector3(0.0, 0.3, -2.2), 0.14, "iron")
	WorldKit.cylinder(it, "Cap", 0.8, 0.4, WorldKit.at(Vector3(0.0, 0.1, -2.4)), "iron", true, 0.4)
	WorldKit.ball(it, "Glass", Vector3(0.55, 0.7, 0.55), WorldKit.at(Vector3(0.0, -0.7, -2.4)),
		"bulb", false)
	for i in 3:
		WorldKit.ring(it, "Cage", 0.72, 0.08, WorldKit.at(Vector3(0.0, -0.2 - float(i) * 0.5, -2.4)),
			"iron")
	_light(it, Vector3(0.0, -0.8, -2.8), 30.0, 1.5, Color(1.0, 0.78, 0.5))
	return it


## The mouth of a pipe coming out of a wall, towards -Z: a stub with a lip and
## the dark inside it.
static func _pipe_mouth() -> Node3D:
	var it := WorldKit.body(null, "PipeMouth")
	var out := Basis(Vector3.RIGHT, PI * 0.5)
	WorldKit.cylinder(it, "Pipe", 1.6, 2.2, Transform3D(out, Vector3(0.0, 0.0, -1.1)), "stone_dark")
	WorldKit.ring(it, "Lip", 1.6, 0.4, Transform3D(out, Vector3(0.0, 0.0, -2.2)), "stone_dark")
	WorldKit.cylinder(it, "Dark", 1.35, 0.05, Transform3D(out, Vector3(0.0, 0.0, -2.2)), "black",
		false)
	WorldKit.cylinder(it, "Slime", 1.2, 0.3, Transform3D(Basis.IDENTITY, Vector3(0.0, -1.3, -2.0)),
		"moss", false, 1.0)
	return it


## A red valve wheel on a stem out of a wall, towards -Z.
static func _valve_wheel() -> Node3D:
	var it := WorldKit.body(null, "ValveWheel")
	var out := Basis(Vector3.RIGHT, PI * 0.5)
	WorldKit.cylinder(it, "Stem", 0.3, 1.8, Transform3D(out, Vector3(0.0, 0.0, -0.9)), "iron")
	WorldKit.ring(it, "Wheel", 1.3, 0.3, Transform3D(out, Vector3(0.0, 0.0, -1.8)), "red", true)
	for i in 3:
		var angle := float(i) * PI / 3.0
		var reach := Vector3(cos(angle), sin(angle), 0.0) * 1.2
		WorldKit.rod(it, "Spoke", Vector3(0.0, 0.0, -1.8) - reach, Vector3(0.0, 0.0, -1.8) + reach,
			0.1, "red", false)
	return it


## An old tyre, lying flat.
static func _tyre() -> Node3D:
	var it := WorldKit.body(null, "Tyre")
	WorldKit.ring(it, "Tyre", 2.0, 1.1, WorldKit.at(Vector3(0.0, 0.55, 0.0)), "rubber", true)
	return it


## A traffic cone, washed down from somewhere it made sense.
static func _traffic_cone() -> Node3D:
	var it := WorldKit.body(null, "TrafficCone")
	WorldKit.block(it, "Foot", Vector3(-1.6, 0.0, -1.6), Vector3(1.6, 0.3, 1.6), "black")
	WorldKit.cylinder(it, "Cone", 1.25, 4.6, WorldKit.at(Vector3(0.0, 2.6, 0.0)), "red", true, 0.2)
	WorldKit.cylinder(it, "Band", 0.86, 0.9, WorldKit.at(Vector3(0.0, 2.9, 0.0)), "white", false, 0.7)
	return it


# --- the park ------------------------------------------------------------

## A park bench: three slats to sit on and two to lean on, on cast iron ends.
static func _bench() -> Node3D:
	var it := WorldKit.body(null, "Bench")
	var half := 12.8
	for x in [-half + 1.4, half - 1.4]:
		WorldKit.box(it, "Leg", Vector3(0.7, 6.2, 0.7), WorldKit.at(Vector3(x, 3.1, -2.6)), "iron")
		WorldKit.rod(it, "Back", Vector3(x, 0.0, 2.6), Vector3(x, 12.2, 4.2), 0.4, "iron")
		WorldKit.box(it, "Rest", Vector3(0.7, 0.6, 6.4), WorldKit.at(Vector3(x, 6.0, 0.0)), "iron")
		WorldKit.rod(it, "Arm", Vector3(x, 9.0, -3.0), Vector3(x, 9.0, 2.9), 0.35, "iron")
		WorldKit.rod(it, "Post", Vector3(x, 6.2, -2.8), Vector3(x, 9.0, -3.0), 0.3, "iron")
	for z in [-2.4, -0.2, 2.0]:
		WorldKit.box(it, "Seat", Vector3(half * 2.0, 0.5, 1.8), WorldKit.at(Vector3(0.0, 6.55, z)),
			"wood_light")
	for y in [8.6, 11.0]:
		var at := Vector3(0.0, y, 2.6 + (y - 1.0) * 0.13)
		WorldKit.box(it, "Slat", Vector3(half * 2.0 - 1.0, 1.6, 0.5), Transform3D(
			Basis(Vector3.RIGHT, -0.13), at), "wood_light")
	return it


## A litter bin: a green drum with a band round it and an iron rim.
static func _bin() -> Node3D:
	var it := WorldKit.body(null, "Bin")
	WorldKit.cylinder(it, "Drum", 2.8, 12.0, WorldKit.at(Vector3(0.0, 6.0, 0.0)), "green")
	WorldKit.ring(it, "Rim", 2.8, 0.5, WorldKit.at(Vector3(0.0, 12.0, 0.0)), "iron")
	WorldKit.cylinder(it, "Band", 2.86, 1.2, WorldKit.at(Vector3(0.0, 9.0, 0.0)), "iron", false)
	WorldKit.cylinder(it, "Litter", 2.5, 0.2, WorldKit.at(Vector3(0.0, 11.0, 0.0)), "black", false)
	return it


## A park lamp post: an iron column with a lantern on top. The lantern glows, but
## it is day, so it lights nothing.
static func _lamp_post() -> Node3D:
	var it := WorldKit.body(null, "LampPost")
	WorldKit.cylinder(it, "Foot", 1.5, 3.0, WorldKit.at(Vector3(0.0, 1.5, 0.0)), "iron", true, 1.1)
	WorldKit.cylinder(it, "Post", 0.65, 44.0, WorldKit.at(Vector3(0.0, 25.0, 0.0)), "iron", true, 0.5)
	WorldKit.ring(it, "Collar", 0.8, 0.4, WorldKit.at(Vector3(0.0, 46.8, 0.0)), "iron")
	WorldKit.cylinder(it, "Lantern", 1.4, 4.0, WorldKit.at(Vector3(0.0, 49.0, 0.0)), "bulb", true, 2.0)
	WorldKit.cylinder(it, "Hood", 2.6, 1.8, WorldKit.at(Vector3(0.0, 51.9, 0.0)), "iron", true, 0.3)
	WorldKit.ball(it, "Finial", Vector3.ONE * 0.5, WorldKit.at(Vector3(0.0, 53.2, 0.0)), "iron")
	return it


## A broad oak: a thick trunk, four limbs, and a crown of leaves in a few greens.
static func _tree_oak() -> Node3D:
	var it := WorldKit.body(null, "TreeOak")
	WorldKit.cylinder(it, "Trunk", 3.0, 30.0, WorldKit.at(Vector3(0.0, 15.0, 0.0)), "bark", true, 2.0)
	var limbs := [
		[Vector3(0.8, 20.0, 0.0), Vector3(13.0, 33.0, 2.0)],
		[Vector3(-0.8, 22.0, 0.4), Vector3(-12.0, 34.0, -3.0)],
		[Vector3(0.0, 24.0, -0.8), Vector3(2.0, 35.0, -13.0)],
		[Vector3(0.0, 25.0, 0.8), Vector3(-3.0, 36.0, 12.0)],
	]
	for limb in limbs:
		WorldKit.rod(it, "Limb", limb[0], limb[1], 1.3, "bark", true, 0.7)
	var crown := [
		[Vector3(0.0, 42.0, 0.0), Vector3(15.0, 11.0, 15.0), "leaf"],
		[Vector3(11.0, 36.0, 3.0), Vector3(10.0, 8.0, 10.0), "leaf_light"],
		[Vector3(-10.0, 37.0, -4.0), Vector3(10.0, 8.5, 10.0), "leaf_dark"],
		[Vector3(2.0, 37.5, -11.0), Vector3(9.5, 8.0, 9.5), "leaf_light"],
		[Vector3(-3.0, 38.0, 11.0), Vector3(10.0, 8.0, 10.0), "leaf"],
	]
	for blob in crown:
		WorldKit.ball(it, "Leaves", blob[1], WorldKit.at(blob[0]), blob[2])
	return it


## A birch: a slender white trunk and a tall, narrow crown.
static func _tree_birch() -> Node3D:
	var it := WorldKit.body(null, "TreeBirch")
	WorldKit.cylinder(it, "Trunk", 1.5, 46.0, WorldKit.at(Vector3(0.0, 23.0, 0.0)), "white", true, 0.8)
	for i in 5:
		var y := 8.0 + float(i) * 7.0
		WorldKit.cylinder(it, "Mark", 1.5 - float(i) * 0.12, 0.6, WorldKit.at(Vector3(0.0, y, 0.0)),
			"black", false, 1.45 - float(i) * 0.12)
	WorldKit.rod(it, "Limb", Vector3(0.0, 26.0, 0.0), Vector3(6.0, 34.0, 1.0), 0.6, "white", true, 0.3)
	WorldKit.rod(it, "Limb", Vector3(0.0, 30.0, 0.0), Vector3(-5.0, 38.0, -2.0), 0.55, "white", true,
		0.3)
	WorldKit.ball(it, "Leaves", Vector3(8.0, 13.0, 8.0), WorldKit.at(Vector3(0.0, 44.0, 0.0)),
		"leaf_light")
	WorldKit.ball(it, "Leaves", Vector3(6.5, 9.0, 6.5), WorldKit.at(Vector3(4.0, 35.0, 1.0)), "leaf")
	WorldKit.ball(it, "Leaves", Vector3(6.0, 8.5, 6.0), WorldKit.at(Vector3(-4.0, 38.0, -2.0)),
		"leaf_light")
	return it


## A pine: a straight trunk and tiers of dark green going up it.
static func _tree_pine() -> Node3D:
	var it := WorldKit.body(null, "TreePine")
	WorldKit.cylinder(it, "Trunk", 1.9, 52.0, WorldKit.at(Vector3(0.0, 26.0, 0.0)), "bark", true, 0.5)
	var tiers := [[12.0, 15.0, 14.0], [22.0, 12.0, 13.0], [31.0, 9.5, 12.0], [40.0, 7.0, 11.0],
		[48.0, 4.5, 9.0]]
	for tier in tiers:
		WorldKit.cylinder(it, "Tier", tier[1], tier[2], WorldKit.at(Vector3(0.0, tier[0], 0.0)),
			"leaf_dark", true, 0.3, 16)
	return it


## A round bush of a few overlapping mounds, with flowers on it if it is that kind.
static func _bush(flowering: bool) -> Node3D:
	var it := WorldKit.body(null, "BushFlowering" if flowering else "Bush")
	var mounds := [
		[Vector3(0.0, 4.5, 0.0), Vector3(6.5, 5.5, 6.5), "leaf"],
		[Vector3(4.5, 3.4, 2.0), Vector3(4.5, 4.0, 4.5), "leaf_dark"],
		[Vector3(-4.0, 3.2, -1.5), Vector3(4.6, 3.8, 4.4), "leaf_light"],
		[Vector3(0.5, 3.0, -4.2), Vector3(4.0, 3.5, 4.0), "leaf_dark"],
	]
	for mound in mounds:
		WorldKit.ball(it, "Leaves", mound[1], WorldKit.at(mound[0]), mound[2])
	if flowering:
		var petals := ["petal_red", "petal_white", "petal_yellow"]
		for i in 14:
			var around := float(i) * 2.4
			var up := 0.35 + 0.5 * fposmod(float(i) * 0.37, 1.0)
			var at := Vector3(cos(around) * sin(up * PI) * 6.6, 4.5 + cos(up * PI) * 5.6,
				sin(around) * sin(up * PI) * 6.6)
			WorldKit.ball(it, "Flower", Vector3.ONE * 0.7, WorldKit.at(at), petals[i % petals.size()],
				false)
	return it


## A round flower bed: earth in a stone edge, and flowers on stems in rings.
static func _flower_bed() -> Node3D:
	var it := WorldKit.body(null, "FlowerBed")
	WorldKit.cylinder(it, "Earth", 10.0, 0.9, WorldKit.at(Vector3(0.0, 0.45, 0.0)), "soil", true,
		-1.0, 32)
	WorldKit.ring(it, "Edge", 10.2, 0.9, WorldKit.at(Vector3(0.0, 0.45, 0.0)), "stone")
	var petals := ["petal_red", "petal_yellow", "petal_purple", "petal_white"]
	var rings := [[3.0, 6, 5.5], [5.8, 11, 4.4], [8.4, 16, 3.2]]
	var n := 0
	for band in rings:
		for i in int(band[1]):
			var angle := TAU * (float(i) + 0.5 * float(n % 2)) / float(band[1])
			var base := Vector3(cos(angle) * band[0], 0.9, sin(angle) * band[0])
			var top := base + Vector3(0.0, band[2] + 0.4 * sin(float(n) * 1.7), 0.0)
			WorldKit.rod(it, "Stem", base, top, 0.14, "leaf", true, -1.0, 6)
			WorldKit.ball(it, "Leaf", Vector3(0.6, 0.15, 0.3), WorldKit.at(base + (top - base) * 0.4,
				float(n) * 57.0), "leaf_light", false)
			WorldKit.ball(it, "Flower", Vector3(0.75, 0.45, 0.75), WorldKit.at(top),
				petals[n % petals.size()])
			n += 1
	return it


## A stretch of iron railings, twenty-four long: two posts, two rails, and bars with
## points on them close enough that nothing big gets between.
static func _railing() -> Node3D:
	var it := WorldKit.body(null, "Railing")
	var half := 12.0
	for x in [-half, half]:
		WorldKit.box(it, "Post", Vector3(1.0, 17.0, 1.0), WorldKit.at(Vector3(x, 8.5, 0.0)), "iron")
		WorldKit.ball(it, "Knob", Vector3.ONE * 0.8, WorldKit.at(Vector3(x, 17.4, 0.0)), "iron")
	for y in [4.0, 14.0]:
		WorldKit.box(it, "Rail", Vector3(half * 2.0, 0.5, 0.5), WorldKit.at(Vector3(0.0, y, 0.0)), "iron")
	for i in 11:
		var x := -half + 2.0 * float(i + 1)
		WorldKit.box(it, "Bar", Vector3(0.3, 15.0, 0.3), WorldKit.at(Vector3(x, 7.5, 0.0)), "iron")
		WorldKit.cylinder(it, "Point", 0.4, 1.2, WorldKit.at(Vector3(x, 15.6, 0.0)), "iron", false, 0.0,
			6)
	return it


## A stretch of white picket fence, twenty long.
static func _picket_fence() -> Node3D:
	var it := WorldKit.body(null, "PicketFence")
	var half := 10.0
	for x in [-half, half]:
		WorldKit.box(it, "Post", Vector3(1.0, 13.0, 1.0), WorldKit.at(Vector3(x, 6.5, 0.0)), "white")
	for y in [3.0, 9.5]:
		WorldKit.box(it, "Rail", Vector3(half * 2.0, 1.0, 0.5), WorldKit.at(Vector3(0.0, y, 0.4)),
			"white")
	for i in 9:
		var x := -half + 2.0 * float(i + 1)
		WorldKit.box(it, "Picket", Vector3(1.2, 10.5, 0.4), WorldKit.at(Vector3(x, 5.25, -0.1)), "white")
		WorldKit.prism(it, "Point", Vector3(1.2, 1.0, 0.4), WorldKit.at(Vector3(x, 11.0, -0.1)), "white")
	return it


## An aviary: a frame of posts, walls and roof of wire netting, perches at several
## heights, and a door in the front for the keeper. Forty across, thirty-six
## deep and forty-four high; the netting is solid to anything that flies, and
## something with legs can climb it.
static func _aviary() -> Node3D:
	var it := WorldKit.body(null, "Aviary")
	var half := Vector3(20.0, 44.0, 18.0)
	var door := Vector2(4.5, 13.0)
	for x in [-half.x, half.x]:
		for z in [-half.z, half.z]:
			WorldKit.box(it, "Post", Vector3(1.4, half.y, 1.4), WorldKit.at(Vector3(x, half.y * 0.5, z)),
				"green")
	for y in [half.y, 16.0]:
		for z in [-half.z, half.z]:
			WorldKit.box(it, "Beam", Vector3(half.x * 2.0, 1.2, 1.2), WorldKit.at(Vector3(0.0, y, z)),
				"green")
		for x in [-half.x, half.x]:
			WorldKit.box(it, "Beam", Vector3(1.2, 1.2, half.z * 2.0), WorldKit.at(Vector3(x, y, 0.0)),
				"green")
	# The netting: back, sides, roof, and the front round the door.
	WorldKit.block(it, "Netting", Vector3(-half.x, 0.0, half.z - 0.15), Vector3(half.x, half.y,
		half.z + 0.15), "netting")
	for x in [-half.x, half.x]:
		WorldKit.block(it, "Netting", Vector3(x - 0.15, 0.0, -half.z), Vector3(x + 0.15, half.y,
			half.z), "netting")
	WorldKit.block(it, "Roof", Vector3(-half.x, half.y - 0.15, -half.z), Vector3(half.x,
		half.y + 0.15, half.z), "netting")
	WorldKit.block(it, "Netting", Vector3(-half.x, 0.0, -half.z - 0.15), Vector3(-door.x,
		half.y, -half.z + 0.15), "netting")
	WorldKit.block(it, "Netting", Vector3(door.x, 0.0, -half.z - 0.15), Vector3(half.x, half.y,
		-half.z + 0.15), "netting")
	WorldKit.block(it, "Netting", Vector3(-door.x, door.y, -half.z - 0.15), Vector3(door.x,
		half.y, -half.z + 0.15), "netting")
	for x in [-door.x, door.x]:
		WorldKit.box(it, "Jamb", Vector3(0.8, door.y, 0.8), WorldKit.at(Vector3(x, door.y * 0.5,
			-half.z)), "green")
	WorldKit.box(it, "Lintel", Vector3(door.x * 2.0 + 0.8, 0.8, 0.8), WorldKit.at(Vector3(0.0,
		door.y, -half.z)), "green")
	# Perches, a dead branch to climb about on, and a feeding table.
	var perches := [
		[Vector3(-16.0, 12.0, -6.0), Vector3(-4.0, 12.0, -6.0)],
		[Vector3(4.0, 20.0, 8.0), Vector3(17.0, 20.0, 8.0)],
		[Vector3(-12.0, 28.0, 10.0), Vector3(6.0, 28.0, 10.0)],
		[Vector3(-18.0, 34.0, -8.0), Vector3(-6.0, 36.0, 2.0)],
	]
	for perch in perches:
		WorldKit.rod(it, "Perch", perch[0], perch[1], 0.5, "wood")
	WorldKit.rod(it, "Branch", Vector3(10.0, 0.0, -8.0), Vector3(8.0, 30.0, -4.0), 1.2, "bark", true, 0.5)
	WorldKit.rod(it, "Twig", Vector3(8.8, 18.0, -5.6), Vector3(15.0, 26.0, -10.0), 0.6, "bark", true, 0.3)
	WorldKit.rod(it, "Twig", Vector3(8.4, 24.0, -4.8), Vector3(2.0, 32.0, -6.0), 0.5, "bark", true, 0.25)
	WorldKit.rod(it, "Stand", Vector3(-10.0, 0.0, 8.0), Vector3(-10.0, 9.0, 8.0), 0.5, "wood")
	WorldKit.block(it, "Table", Vector3(-14.0, 9.0, 4.0), Vector3(-6.0, 9.6, 12.0), "wood_light")
	WorldKit.ball(it, "Seed", Vector3(2.6, 0.6, 2.6), WorldKit.at(Vector3(-10.0, 9.8, 8.0)), "straw",
		false)
	return it


## A dog kennel: a box with a doorway in the front and a pitched red roof.
static func _kennel() -> Node3D:
	var it := WorldKit.body(null, "Kennel")
	var half := Vector3(5.7, 7.0, 4.3)
	var door := Vector2(2.4, 5.6)
	WorldKit.block(it, "Floor", Vector3(-half.x, 0.0, -half.z), Vector3(half.x, 0.5, half.z), "wood_dark")
	WorldKit.block(it, "Back", Vector3(-half.x, 0.0, half.z - 0.5), Vector3(half.x, half.y, half.z),
		"wood_warm")
	for x in [-half.x, half.x - 0.5]:
		WorldKit.block(it, "Side", Vector3(x, 0.0, -half.z), Vector3(x + 0.5, half.y, half.z), "wood_warm")
	WorldKit.block(it, "Front", Vector3(-half.x, 0.0, -half.z), Vector3(-door.x, half.y,
		-half.z + 0.5), "wood_warm")
	WorldKit.block(it, "Front", Vector3(door.x, 0.0, -half.z), Vector3(half.x, half.y,
		-half.z + 0.5), "wood_warm")
	WorldKit.block(it, "Front", Vector3(-door.x, door.y, -half.z), Vector3(door.x, half.y,
		-half.z + 0.5), "wood_warm")
	for z in [-half.z, half.z - 0.5]:
		WorldKit.prism(it, "Gable", Vector3(half.x * 2.0, 3.6, 0.5), WorldKit.at(Vector3(0.0,
			half.y + 1.8, z + 0.25)), "wood_warm")
	for side in [-1.0, 1.0]:
		WorldKit.box(it, "Roof", Vector3(7.2, 0.5, half.z * 2.0 + 1.6), Transform3D(
			Basis(Vector3.BACK, side * -0.56), Vector3(side * 3.0, half.y + 2.0, 0.0)), "red")
	WorldKit.box(it, "Name", Vector3(3.0, 1.0, 0.1), WorldKit.at(Vector3(0.0, half.y - 0.7,
		-half.z - 0.05)), "white", false)
	return it


## A dog's water bowl.
static func _dog_bowl() -> Node3D:
	var it := WorldKit.body(null, "DogBowl")
	WorldKit.cylinder(it, "Bowl", 1.8, 1.0, WorldKit.at(Vector3(0.0, 0.5, 0.0)), "blue", true, 1.5)
	WorldKit.cylinder(it, "Water", 1.3, 0.05, WorldKit.at(Vector3(0.0, 0.9, 0.0)), "pond", false)
	return it


## A dog's ball.
static func _ball() -> Node3D:
	var it := WorldKit.body(null, "Ball")
	WorldKit.ball(it, "Ball", Vector3.ONE * 1.1, WorldKit.at(Vector3(0.0, 1.1, 0.0)), "red")
	return it


## A signboard on two posts. The board faces -Z; what it says is set where it is
## put up.
static func _sign() -> Node3D:
	var it := WorldKit.body(null, "Sign")
	for x in [-6.0, 6.0]:
		WorldKit.box(it, "Post", Vector3(0.8, 14.0, 0.8), WorldKit.at(Vector3(x, 7.0, 0.0)), "wood_dark")
	WorldKit.block(it, "Board", Vector3(-7.4, 9.0, -0.5), Vector3(7.4, 14.0, 0.0), "green")
	var words := Label3D.new()
	words.name = "Words"
	words.text = "Sign"
	words.font_size = 96
	words.pixel_size = 0.02
	words.modulate = Color(0.96, 0.94, 0.86)
	words.outline_size = 0
	words.position = Vector3(0.0, 11.5, -0.56)
	words.rotation = Vector3(0.0, PI, 0.0)
	it.add_child(words)
	return it


## A water butt under the shed's gutter.
static func _water_butt() -> Node3D:
	var it := WorldKit.body(null, "WaterButt")
	WorldKit.cylinder(it, "Butt", 4.0, 12.0, WorldKit.at(Vector3(0.0, 6.0, 0.0)), "green")
	WorldKit.cylinder(it, "Lid", 4.2, 0.6, WorldKit.at(Vector3(0.0, 12.3, 0.0)), "black")
	for y in [3.0, 9.0]:
		WorldKit.ring(it, "Hoop", 4.0, 0.4, WorldKit.at(Vector3(0.0, y, 0.0)), "black")
	WorldKit.rod(it, "Tap", Vector3(0.0, 1.8, -3.9), Vector3(0.0, 1.8, -5.0), 0.3, "steel", false)
	return it


## A slatted compost bin with a heap showing over the top.
static func _compost_bin() -> Node3D:
	var it := WorldKit.body(null, "CompostBin")
	WorldKit.collider(it, "Solid", Vector3(10.0, 8.0, 10.0), WorldKit.at(Vector3(0.0, 4.0, 0.0)))
	for i in 4:
		var y := 1.0 + float(i) * 2.0
		for side in [-1.0, 1.0]:
			WorldKit.box(it, "Slat", Vector3(10.0, 1.6, 0.5), WorldKit.at(Vector3(0.0, y, side * 4.75)),
				"wood", false)
			WorldKit.box(it, "Slat", Vector3(0.5, 1.6, 10.0), WorldKit.at(Vector3(side * 4.75, y, 0.0)),
				"wood", false)
	WorldKit.ball(it, "Heap", Vector3(4.6, 2.2, 4.6), WorldKit.at(Vector3(0.0, 7.4, 0.0)), "soil")
	return it


## A wheelbarrow: a tray on one wheel and two legs, handles out behind.
static func _wheelbarrow() -> Node3D:
	var it := WorldKit.body(null, "Wheelbarrow")
	WorldKit.cylinder(it, "Wheel", 2.0, 0.9, Transform3D(Basis(Vector3.BACK, PI * 0.5),
		Vector3(0.0, 2.0, -6.5)), "rubber")
	WorldKit.cylinder(it, "Tray", 3.2, 3.2, Transform3D(Basis.IDENTITY, Vector3(0.0, 5.4, -1.0)),
		"red", true, 4.6)
	for x in [-2.0, 2.0]:
		WorldKit.rod(it, "Handle", Vector3(x * 0.5, 2.6, -6.4), Vector3(x, 5.0, 7.0), 0.3, "iron")
		WorldKit.rod(it, "Leg", Vector3(x, 3.8, 1.8), Vector3(x, 0.0, 2.4), 0.3, "iron")
	return it


# --- the lake ------------------------------------------------------------

## A rowing boat, thirty-one long and fourteen across: a flat bottom, flared sides
## that meet in a raked stem at the bow, a square stern, two seats and a pair of
## oars. White, with its [param trim] along the gunwale. It is a moving platform,
## so its body is one that can be moved and carry what stands on it — and every
## part of it is convex, because a body that moves cannot collide as triangles.
static func _boat(part_name: String, trim: String) -> Node3D:
	var it := AnimatableBody3D.new()
	it.name = part_name
	it.collision_layer = GameLayers.WORLD
	it.collision_mask = 0
	it.sync_to_physics = true
	var stern := 13.0
	var shoulder := -5.0
	var keel := Vector3(0.0, 0.35, -15.5)
	var stem := Vector3(0.0, 6.2, -18.0)
	var floor_half := 4.6
	var rail := Vector2(7.0, 5.8)
	WorldKit.plate(it, "Bottom", PackedVector3Array([
		Vector3(-floor_half, 0.35, stern), Vector3(floor_half, 0.35, stern),
		Vector3(floor_half, 0.35, shoulder), keel, Vector3(-floor_half, 0.35, shoulder)]),
		0.7, "wood")
	for side in [-1.0, 1.0]:
		var low_aft := Vector3(side * floor_half, 0.35, stern)
		var low_fore := Vector3(side * floor_half, 0.35, shoulder)
		var high_aft := Vector3(side * rail.x, rail.y, stern)
		var high_fore := Vector3(side * rail.x, rail.y, shoulder)
		WorldKit.plate(it, "Side", PackedVector3Array([low_aft, low_fore, high_fore, high_aft]),
			0.6, "white")
		WorldKit.plate(it, "Bow", PackedVector3Array([low_fore, keel, stem, high_fore]), 0.6,
			"white")
		WorldKit.rod(it, "Gunwale", high_aft + Vector3(0.0, 0.1, 0.3), high_fore + Vector3(0.0, 0.1,
			0.0), 0.45, trim)
		WorldKit.rod(it, "Gunwale", high_fore + Vector3(0.0, 0.1, 0.0), stem + Vector3(0.0, 0.1, 0.0),
			0.45, trim)
	WorldKit.rod(it, "Stem", keel + Vector3(0.0, -0.2, -0.1), stem + Vector3(0.0, 0.4, -0.3), 0.5, trim)
	WorldKit.plate(it, "Stern", PackedVector3Array([
		Vector3(-floor_half, 0.0, stern + 0.3), Vector3(floor_half, 0.0, stern + 0.3),
		Vector3(rail.x + 0.3, rail.y + 0.1, stern + 0.3), Vector3(-rail.x - 0.3, rail.y + 0.1,
		stern + 0.3)]), 0.6, "white")
	for z in [-2.0, 7.0]:
		WorldKit.block(it, "Seat", Vector3(-5.8, 3.4, z - 1.3), Vector3(5.8, 4.0, z + 1.3),
			"wood_light")
	for side in [-1.0, 1.0]:
		WorldKit.rod(it, "Oar", Vector3(side * 2.2, 4.3, -10.0), Vector3(side * 3.2, 4.3, 9.0), 0.35,
			"wood_light")
		WorldKit.box(it, "Blade", Vector3(1.4, 0.2, 4.4), WorldKit.at(Vector3(side * 3.3, 4.3, 10.8),
			side * -3.0), "wood_light", false)
	return it


## A bandstand for the island: an eight-sided stone base, a wooden floor, eight
## white posts and a pointed roof.
static func _bandstand() -> Node3D:
	var it := WorldKit.body(null, "Bandstand")
	WorldKit.cylinder(it, "Base", 15.0, 2.4, WorldKit.at(Vector3(0.0, 1.2, 0.0)), "stone", true, -1.0, 8)
	WorldKit.cylinder(it, "Floor", 14.2, 0.4, WorldKit.at(Vector3(0.0, 2.6, 0.0)), "wood_warm", true,
		-1.0, 8)
	for i in 8:
		var angle := TAU * (float(i) + 0.5) / 8.0
		var at := Vector3(cos(angle), 0.0, sin(angle)) * 12.8
		WorldKit.rod(it, "Post", at + Vector3(0.0, 2.8, 0.0), at + Vector3(0.0, 19.0, 0.0), 0.55, "white")
		var next := Vector3(cos(angle + TAU / 8.0), 0.0, sin(angle + TAU / 8.0)) * 12.8
		WorldKit.rod(it, "Rail", at + Vector3(0.0, 7.0, 0.0), next + Vector3(0.0, 7.0, 0.0), 0.3,
			"white")
	WorldKit.cylinder(it, "Eaves", 16.5, 1.0, WorldKit.at(Vector3(0.0, 19.5, 0.0)), "white", true, -1.0, 8)
	WorldKit.cylinder(it, "Roof", 16.5, 8.5, WorldKit.at(Vector3(0.0, 24.25, 0.0)), "green", true,
		0.6, 8)
	WorldKit.ball(it, "Finial", Vector3.ONE * 0.9, WorldKit.at(Vector3(0.0, 29.0, 0.0)), "yellow")
	return it


## A lifebuoy on its post by the water.
static func _lifebuoy() -> Node3D:
	var it := WorldKit.body(null, "Lifebuoy")
	WorldKit.box(it, "Post", Vector3(0.9, 14.0, 0.9), WorldKit.at(Vector3(0.0, 7.0, 0.0)), "white")
	WorldKit.box(it, "Board", Vector3(6.0, 7.0, 0.4), WorldKit.at(Vector3(0.0, 10.0, -0.6)), "white")
	var upright := Basis(Vector3.RIGHT, PI * 0.5)
	WorldKit.ring(it, "Buoy", 2.2, 0.9, Transform3D(upright, Vector3(0.0, 10.0, -1.4)), "red", true)
	for i in 4:
		var angle := TAU * (float(i) + 0.5) / 4.0
		WorldKit.box(it, "Band", Vector3(1.0, 1.1, 1.1), Transform3D(Basis(Vector3.BACK, angle),
			Vector3(cos(angle) * 2.2, 10.0 + sin(angle) * 2.2, -1.4)), "white", false)
	return it


## A clump of bulrushes for the water's edge: stems and brown heads.
static func _reeds() -> Node3D:
	var it := WorldKit.body(null, "Reeds")
	for i in 9:
		var angle := float(i) * 2.2
		var out := 0.6 + fposmod(float(i) * 0.61, 1.0) * 2.6
		var base := Vector3(cos(angle) * out, 0.0, sin(angle) * out)
		var height := 10.0 + fposmod(float(i) * 0.43, 1.0) * 6.0
		var top := base + Vector3(cos(angle) * 0.8, height, sin(angle) * 0.8)
		WorldKit.rod(it, "Stem", base, top, 0.22, "leaf_dark" if i % 2 == 0 else "leaf", true, 0.12, 6)
		if i % 3 != 2:
			WorldKit.capsule(it, "Head", 0.45, 2.4, Transform3D(WorldKit.upright(top - base),
				base + (top - base) * 0.86), "bark", false)
	return it


## A lily pad, flat on the water, with a flower on some.
static func _lily_pad() -> Node3D:
	var it := WorldKit.body(null, "LilyPad")
	WorldKit.cylinder(it, "Pad", 3.2, 0.2, WorldKit.at(Vector3(0.0, 0.1, 0.0)), "leaf", true, -1.0, 16)
	WorldKit.ball(it, "Flower", Vector3(0.9, 0.6, 0.9), WorldKit.at(Vector3(1.0, 0.5, -0.6)),
		"petal_white", false)
	return it


# --- helpers -------------------------------------------------------------

## A light hung in a prop: shadows on, because a room lit by a bulb is a room of
## shadows, and that is most of what makes a shape read.
static func _light(on: Node3D, at: Vector3, reach: float, energy: float, colour: Color) -> void:
	var lamp := OmniLight3D.new()
	lamp.name = "Light"
	lamp.omni_range = reach
	lamp.light_energy = energy
	lamp.light_color = colour
	lamp.shadow_enabled = true
	lamp.position = at
	on.add_child(lamp)
