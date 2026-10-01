class_name Props
extends RefCounted

## Everything in the hunting ground that is a thing rather than a place: the ferns
## on the forest floor, the flowers in the glade, the stones of the ruins.
##
## Each is built here out of [WorldKit] solids, and baked once into its own scene
## in [constant DIR] so that the world holds instances of it rather than copies —
## change the fern and every fern changes, and the editor can drop another one
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
## They are all to one scale: a metre is about fourteen of them. A spiderling is a
## quarter of one, so a pebble is a boulder to it and a toadstool's cap is a roof;
## a fern is a thicket, and a tree of the old forest is somewhere to climb all
## day. The world is the size it is, and what changes is the spider.

const DIR := "res://game/world/props"

## Every prop there is, by the name its scene is saved under.
const ALL := [
	# The fern floor.
	"fern", "toadstool", "mushrooms", "pebble", "boulder", "acorn", "fallen_leaf",
	"fallen_leaf_rust", "twig", "anthill", "forest_tree",
	# The rootways.
	"bracket_fungus",
	# The bloom glade.
	"tree_oak", "tree_birch", "tall_grass", "wildflowers", "berry_bush", "beehive",
	"wasp_tree", "standing_stone",
	# The old ruins.
	"ruin_wall", "ruin_arch", "ruin_pillar", "fallen_pillar", "ruin_block", "flagstones",
	# The mere.
	"reeds", "lily_pad", "driftwood",
	# Wyrm's crag.
	"crag_rock", "crag_spire",
]


## How far off the small props are still drawn. Past this a pebble is a speck, and
## a valley strewn with them is mostly specks to draw; anything not here is drawn
## as far as the camera sees.
const DRAWN_TO := {
	"pebble": 90.0, "acorn": 90.0, "fallen_leaf": 90.0, "fallen_leaf_rust": 90.0, "twig": 100.0,
	"mushrooms": 140.0, "wildflowers": 150.0, "tall_grass": 150.0, "fern": 180.0, "anthill": 180.0,
	"toadstool": 200.0, "lily_pad": 200.0, "reeds": 240.0, "bracket_fungus": 260.0,
	"driftwood": 260.0, "flagstones": 260.0, "boulder": 320.0, "berry_bush": 320.0,
	"ruin_block": 320.0,
}


## Builds [param id] from scratch: a body with its solids on it, named for it,
## drawn as far off as [constant DRAWN_TO] says.
static func build(id: String) -> Node3D:
	var made := _make(id)
	if made != null and DRAWN_TO.has(id):
		draw_to(made, DRAWN_TO[id])
	return made


## Stops everything drawn in [param node] being drawn past [param distance], fading
## it out over the last tenth rather than popping.
static func draw_to(node: Node, distance: float) -> void:
	var view := node as GeometryInstance3D
	if view != null:
		view.visibility_range_end = distance
		view.visibility_range_end_margin = distance * 0.1
		view.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	for child in node.get_children():
		draw_to(child, distance)


static func _make(id: String) -> Node3D:
	match id:
		"tree_oak": return _tree_oak()
		"tree_birch": return _tree_birch()
		"reeds": return _reeds()
		"lily_pad": return _lily_pad()
		"fern": return _fern()
		"toadstool": return _toadstool()
		"mushrooms": return _mushrooms()
		"pebble": return _pebble()
		"boulder": return _boulder()
		"acorn": return _acorn()
		"fallen_leaf": return _fallen_leaf("FallenLeaf", "leaf_fallen")
		"fallen_leaf_rust": return _fallen_leaf("FallenLeafRust", "leaf_rust")
		"twig": return _twig()
		"anthill": return _anthill()
		"forest_tree": return _forest_tree()
		"bracket_fungus": return _bracket_fungus()
		"tall_grass": return _tall_grass()
		"wildflowers": return _wildflowers()
		"berry_bush": return _berry_bush()
		"beehive": return _beehive()
		"wasp_tree": return _wasp_tree()
		"standing_stone": return _standing_stone()
		"ruin_wall": return _ruin_wall()
		"ruin_arch": return _ruin_arch()
		"ruin_pillar": return _ruin_pillar()
		"fallen_pillar": return _fallen_pillar()
		"ruin_block": return _ruin_block()
		"flagstones": return _flagstones()
		"driftwood": return _driftwood()
		"crag_rock": return _crag_rock()
		"crag_spire": return _crag_spire()
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


# --- the fern floor ----------------------------------------------------

## A fern: a clump of fronds arching up and out from the middle, each a stalk with
## leaflets down both sides, shorter toward the tip. Half a metre tall, and the
## stalks are somewhere to climb.
static func _fern() -> Node3D:
	var it := WorldKit.body(null, "Fern")
	for i in 7:
		var turn := TAU * float(i) / 7.0 + 0.3 * sin(float(i) * 2.1)
		var out := Vector3(cos(turn), 0.0, sin(turn))
		var reach := 5.5 + 1.4 * fposmod(float(i) * 0.53, 1.0)
		var root := out * 0.3
		var bend := out * reach * 0.45 + Vector3.UP * (5.0 + 0.8 * fposmod(float(i) * 0.71, 1.0))
		var tip := out * reach + Vector3.UP * 2.8
		WorldKit.rod(it, "Stalk", root, bend, 0.13, "leaf_dark", true, 0.1, 6)
		WorldKit.rod(it, "Stalk", bend, tip, 0.1, "leaf_dark", true, 0.04, 6)
		for k in 7:
			var t := 0.12 + float(k) / 7.0 * 0.86
			var at := root.lerp(bend, t * 2.0) if t < 0.5 else bend.lerp(tip, t * 2.0 - 1.0)
			var run := (bend - root) if t < 0.5 else (tip - bend)
			run = run.normalized()
			var side := run.cross(Vector3.UP).normalized()
			var face := run.cross(side)
			if face.y < 0.0:
				face = -face
			var long := lerpf(1.3, 0.35, t)
			for flip: float in [-1.0, 1.0]:
				var arm := side * flip
				WorldKit.ball(it, "Leaflet", Vector3(long, 0.06, 0.22),
					Transform3D(Basis(arm, face, arm.cross(face)), at + arm * long * 0.85),
					"leaf" if k % 2 == 0 else "leaf_dark", false)
	return it


## A fly agaric: a white stem with a skirt, and a red cap spotted white. Five
## tall, and the cap is a roof.
static func _toadstool() -> Node3D:
	var it := WorldKit.body(null, "Toadstool")
	WorldKit.cylinder(it, "Stem", 0.6, 3.4, WorldKit.at(Vector3(0.0, 1.7, 0.0)), "stem", true, 0.45,
		14)
	WorldKit.ring(it, "Skirt", 0.55, 0.22, WorldKit.at(Vector3(0.0, 2.5, 0.0)), "stem")
	WorldKit.ball(it, "Cap", Vector3(2.4, 1.15, 2.4), WorldKit.at(Vector3(0.0, 3.5, 0.0)), "cap_red")
	for i in 11:
		var turn := float(i) * 2.4
		var up := 0.25 + 0.55 * fposmod(float(i) * 0.39, 1.0)
		var normal := Vector3(cos(turn) * sin(up * PI * 0.5), cos(up * PI * 0.5),
			sin(turn) * sin(up * PI * 0.5))
		var on := Vector3(normal.x * 2.4, normal.y * 1.15, normal.z * 2.4)
		WorldKit.ball(it, "Spot", Vector3(0.28, 0.08, 0.28),
			Transform3D(WorldKit.upright(normal), Vector3(0.0, 3.5, 0.0) + on), "petal_white", false)
	return it


## Three brown mushrooms grown up together, a big one and two smaller.
static func _mushrooms() -> Node3D:
	var it := WorldKit.body(null, "Mushrooms")
	var caps := [[Vector3(0.0, 0.0, 0.0), 2.2, 1.4], [Vector3(1.6, 0.0, 0.7), 1.4, 0.95],
		[Vector3(-1.1, 0.0, 1.2), 1.0, 0.7]]
	for cap in caps:
		var base: Vector3 = cap[0]
		var tall: float = cap[1]
		var wide: float = cap[2]
		WorldKit.cylinder(it, "Stem", wide * 0.25, tall, WorldKit.at(base + Vector3.UP * tall * 0.5),
			"stem", true, wide * 0.2, 10)
		WorldKit.ball(it, "Cap", Vector3(wide, wide * 0.5, wide), WorldKit.at(base + Vector3.UP * tall),
			"cap")
	return it


## A pebble, a few centimetres across: a boulder to a spiderling.
static func _pebble() -> Node3D:
	var it := WorldKit.body(null, "Pebble")
	WorldKit.ball(it, "Stone", Vector3(0.62, 0.36, 0.5), WorldKit.at(Vector3(0.0, 0.22, 0.0)),
		"rock_dark")
	return it


## A boulder half sunk in the ground, two rounded stones together, with moss on
## the top.
static func _boulder() -> Node3D:
	var it := WorldKit.body(null, "Boulder")
	WorldKit.ball(it, "Stone", Vector3(3.4, 2.4, 2.8), WorldKit.at(Vector3(0.0, 1.0, 0.0)), "rock")
	WorldKit.ball(it, "Stone", Vector3(2.0, 1.6, 2.2), WorldKit.at(Vector3(2.4, 0.6, 1.2)),
		"rock_dark")
	WorldKit.ball(it, "Moss", Vector3(2.4, 0.5, 2.0), WorldKit.at(Vector3(-0.3, 3.05, 0.1)), "moss",
		false)
	return it


## An acorn on its side, in its cup.
static func _acorn() -> Node3D:
	var it := WorldKit.body(null, "Acorn")
	var lying := Basis(Vector3.BACK, PI * 0.5)
	WorldKit.ball(it, "Nut", Vector3(0.3, 0.4, 0.3), Transform3D(lying, Vector3(0.1, 0.3, 0.0)),
		"acorn")
	WorldKit.ball(it, "Cup", Vector3(0.33, 0.18, 0.33),
		Transform3D(lying, Vector3(-0.25, 0.3, 0.0)), "acorn_cup")
	WorldKit.rod(it, "Stalk", Vector3(-0.42, 0.3, 0.0), Vector3(-0.62, 0.34, 0.0), 0.05, "acorn_cup",
		false)
	return it


## A leaf come down last autumn, lying flat: a pointed oval with a rib down it.
static func _fallen_leaf(part_name: String, paint: String) -> Node3D:
	var it := WorldKit.body(null, part_name)
	var outline := PackedVector3Array()
	for i in 14:
		var t := TAU * float(i) / 14.0
		# Pointed at both ends: narrow where the cosine is large.
		var across := sin(t) * 0.75 * (1.0 - 0.35 * absf(cos(t)))
		outline.append(Vector3(across, 0.06, cos(t) * 1.4))
	WorldKit.plate(it, "Blade", outline, 0.05, paint)
	WorldKit.rod(it, "Rib", Vector3(0.0, 0.1, 1.5), Vector3(0.0, 0.1, -1.4), 0.04, "leaf_rust", false)
	return it


## A twig with a fork in it.
static func _twig() -> Node3D:
	var it := WorldKit.body(null, "Twig")
	WorldKit.rod(it, "Stick", Vector3(-3.2, 0.12, 0.0), Vector3(3.2, 0.12, 0.3), 0.13, "bark", true,
		0.09, 8)
	WorldKit.rod(it, "Fork", Vector3(0.6, 0.12, 0.05), Vector3(2.6, 0.2, -1.6), 0.08, "bark", true,
		0.05, 6)
	return it


## A tree of the old forest, ten metres up to its crown: a trunk a spider can climb
## all day, roots spreading into the ground round its foot, and a crown so far up
## that the floor under it is in its shade.
static func _forest_tree() -> Node3D:
	var it := WorldKit.body(null, "ForestTree")
	WorldKit.cylinder(it, "Trunk", 6.0, 132.0, WorldKit.at(Vector3(0.0, 66.0, 0.0)), "bark", true,
		4.2, 16)
	for i in 5:
		var turn := TAU * float(i) / 5.0 + 0.4
		var out := Vector3(cos(turn), 0.0, sin(turn))
		WorldKit.rod(it, "Root", out * 3.5 + Vector3.UP * 7.0, out * 15.0 + Vector3.DOWN * 1.0, 2.4,
			"bark", true, 0.9, 10)
	var limbs := [
		[Vector3(1.0, 96.0, 0.0), Vector3(26.0, 124.0, 6.0)],
		[Vector3(-1.0, 102.0, 0.5), Vector3(-24.0, 128.0, -8.0)],
		[Vector3(0.0, 108.0, -1.0), Vector3(5.0, 132.0, -26.0)],
		[Vector3(0.0, 112.0, 1.0), Vector3(-6.0, 134.0, 25.0)],
	]
	for limb in limbs:
		WorldKit.rod(it, "Limb", limb[0], limb[1], 2.4, "bark", true, 1.3, 10)
	var crown := [
		[Vector3(0.0, 146.0, 0.0), Vector3(30.0, 16.0, 30.0), "leaf_dark"],
		[Vector3(24.0, 134.0, 6.0), Vector3(19.0, 12.0, 19.0), "leaf"],
		[Vector3(-22.0, 137.0, -8.0), Vector3(19.0, 12.5, 19.0), "leaf_dark"],
		[Vector3(5.0, 138.0, -24.0), Vector3(18.0, 12.0, 18.0), "leaf"],
		[Vector3(-6.0, 139.0, 23.0), Vector3(19.0, 12.0, 19.0), "leaf_light"],
	]
	for blob in crown:
		WorldKit.ball(it, "Leaves", blob[1], WorldKit.at(blob[0]), blob[2])
	return it


## An anthill: a mound of loose earth with the way in on one side.
static func _anthill() -> Node3D:
	var it := WorldKit.body(null, "Anthill")
	WorldKit.ball(it, "Mound", Vector3(3.2, 1.9, 3.2), WorldKit.at(Vector3(0.0, 0.0, 0.0)), "soil")
	WorldKit.ball(it, "Top", Vector3(1.4, 1.0, 1.4), WorldKit.at(Vector3(0.3, 1.4, -0.2)), "soil")
	WorldKit.ball(it, "WayIn", Vector3(0.45, 0.35, 0.2), WorldKit.at(Vector3(0.0, 0.7, -3.0)), "black",
		false)
	return it


# --- the rootways ------------------------------------------------------

## Shelf fungus, the way it grows out of a trunk: three half-discs one above the
## other, the biggest at the bottom, sticking out along -Z from a trunk that is
## behind them. Something to stand on halfway up a tree.
static func _bracket_fungus() -> Node3D:
	var it := WorldKit.body(null, "BracketFungus")
	var shelves := [[0.0, 4.2, 3.2], [2.6, 3.0, 2.3], [4.6, 2.0, 1.6]]
	for shelf in shelves:
		var wide: float = shelf[1]
		var deep: float = shelf[2]
		WorldKit.ball(it, "Shelf", Vector3(wide, 0.7, deep),
			WorldKit.at(Vector3(0.0, shelf[0], -deep * 0.45)), "fungus_shelf")
	return it


# --- the bloom glade ---------------------------------------------------

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


## A clump of meadow grass, waist high to a person and a forest to a spider:
## blades from one root, leaning out, each a stalk to climb and a post for silk.
static func _tall_grass() -> Node3D:
	var it := WorldKit.body(null, "TallGrass")
	for i in 11:
		var turn := float(i) * 2.39
		var lean := 0.15 + 0.3 * fposmod(float(i) * 0.47, 1.0)
		var tall := 7.0 + 6.0 * fposmod(float(i) * 0.61, 1.0)
		var base := Vector3(cos(turn), 0.0, sin(turn)) * (0.3 + 0.9 * fposmod(float(i) * 0.29, 1.0))
		var tip := base + Vector3(cos(turn) * lean * tall, tall, sin(turn) * lean * tall)
		WorldKit.rod(it, "Blade", base, tip, 0.22, "grass" if i % 3 != 0 else "leaf_light", true, 0.04,
			5)
		if i % 4 == 0:
			WorldKit.capsule(it, "Seed", 0.28, 1.8, Transform3D(WorldKit.upright(tip - base), tip),
				"straw", false)
	return it


## Wildflowers: stems of a few heights, a leaf or two on each, and a head of
## petals on top in one of the meadow's colours.
static func _wildflowers() -> Node3D:
	var it := WorldKit.body(null, "Wildflowers")
	var petals := ["petal_red", "petal_yellow", "petal_purple", "petal_white", "petal_yellow"]
	for i in 6:
		var turn := float(i) * 2.1
		var base := Vector3(cos(turn), 0.0, sin(turn)) * (0.5 + 1.2 * fposmod(float(i) * 0.37, 1.0))
		var tall := 5.0 + 3.5 * fposmod(float(i) * 0.53, 1.0)
		var tip := base + Vector3(cos(turn) * 0.5, tall, sin(turn) * 0.5)
		WorldKit.rod(it, "Stem", base, tip, 0.14, "leaf", true, 0.1, 6)
		WorldKit.ball(it, "Leaf", Vector3(0.9, 0.12, 0.35), WorldKit.at(base.lerp(tip, 0.4),
			float(i) * 61.0), "leaf_light", false)
		var paint: String = petals[i % petals.size()]
		for k in 5:
			var round := TAU * float(k) / 5.0
			WorldKit.ball(it, "Petal", Vector3(0.55, 0.12, 0.3), Transform3D(Basis(Vector3.UP, -round),
				tip + Vector3(cos(round), 0.0, sin(round)) * 0.45), paint, false)
		WorldKit.ball(it, "Heart", Vector3(0.3, 0.2, 0.3), WorldKit.at(tip + Vector3.UP * 0.08),
			"yellow" if paint != "petal_yellow" else "acorn")
	return it


## A bramble of berries: overlapping mounds of dark leaves, berries all over.
static func _berry_bush() -> Node3D:
	var it := WorldKit.body(null, "BerryBush")
	var mounds := [
		[Vector3(0.0, 5.0, 0.0), Vector3(7.0, 6.0, 7.0), "leaf_dark"],
		[Vector3(5.0, 3.6, 2.4), Vector3(4.6, 4.2, 4.6), "leaf"],
		[Vector3(-4.4, 3.4, -1.8), Vector3(4.8, 4.0, 4.6), "leaf_dark"],
	]
	for mound in mounds:
		WorldKit.ball(it, "Leaves", mound[1], WorldKit.at(mound[0]), mound[2])
	# On the big mound's skin, over its top and round its middle where they show.
	for i in 24:
		var around := float(i) * 2.4
		var down := PI * (0.12 + 0.45 * fposmod(float(i) * 0.37, 1.0))
		var at := Vector3(cos(around) * sin(down) * 7.0, 5.0 + cos(down) * 6.0,
			sin(around) * sin(down) * 7.0)
		WorldKit.ball(it, "Berry", Vector3.ONE * 0.65, WorldKit.at(at), "berry", false)
	return it


## A wild hive in an old stump: the comb built up out of the top of it, gold, with
## the way in dark at its foot.
static func _beehive() -> Node3D:
	var it := WorldKit.body(null, "Beehive")
	WorldKit.cylinder(it, "Stump", 3.4, 5.0, WorldKit.at(Vector3(0.0, 2.5, 0.0)), "bark", true, 3.0,
		16)
	WorldKit.cylinder(it, "Cut", 3.0, 0.3, WorldKit.at(Vector3(0.0, 5.05, 0.0)), "wood_light", false,
		-1.0, 16)
	WorldKit.ball(it, "Comb", Vector3(2.6, 3.2, 2.6), WorldKit.at(Vector3(0.0, 7.4, 0.0)), "honey")
	WorldKit.ball(it, "Comb", Vector3(1.8, 2.2, 1.8), WorldKit.at(Vector3(0.9, 9.6, 0.3)), "honey")
	WorldKit.ball(it, "WayIn", Vector3(0.6, 0.45, 0.25), WorldKit.at(Vector3(0.0, 5.8, -2.45)),
		"black", false)
	return it


## A dead tree, bare and grey, with a wasps' nest hanging off its one long limb.
static func _wasp_tree() -> Node3D:
	var it := WorldKit.body(null, "WaspTree")
	WorldKit.cylinder(it, "Trunk", 2.0, 26.0, WorldKit.at(Vector3(0.0, 13.0, 0.0)), "stone_dark",
		true, 1.2, 12)
	WorldKit.rod(it, "Limb", Vector3(0.0, 20.0, 0.0), Vector3(12.0, 26.0, 1.0), 0.9, "stone_dark",
		true, 0.4, 8)
	WorldKit.rod(it, "Limb", Vector3(0.0, 23.0, 0.0), Vector3(-6.0, 31.0, -3.0), 0.7, "stone_dark",
		true, 0.3, 8)
	WorldKit.rod(it, "Stalk", Vector3(9.0, 24.6, 0.8), Vector3(9.0, 22.6, 0.8), 0.3, "paper")
	WorldKit.ball(it, "Nest", Vector3(3.4, 4.2, 3.4), WorldKit.at(Vector3(9.0, 19.2, 0.8)), "paper")
	WorldKit.ball(it, "WayIn", Vector3(0.7, 0.7, 0.4), WorldKit.at(Vector3(9.0, 15.3, 0.8)), "black",
		false)
	return it


## A standing stone, older than anything else in the valley: tall, leaning a
## little, rough, with lichen on its shoulders.
static func _standing_stone() -> Node3D:
	var it := WorldKit.body(null, "StandingStone")
	WorldKit.ball(it, "Stone", Vector3(3.0, 11.0, 2.2), Transform3D(Basis(Vector3.BACK, 0.05),
		Vector3(0.0, 7.5, 0.0)), "rock")
	WorldKit.ball(it, "Lichen", Vector3(1.8, 0.6, 1.5), WorldKit.at(Vector3(0.6, 17.4, 0.2)), "moss",
		false)
	WorldKit.ball(it, "Lichen", Vector3(1.2, 1.6, 0.4), WorldKit.at(Vector3(-1.5, 11.0, -1.7)),
		"moss", false)
	return it


# --- the old ruins -----------------------------------------------------

## A length of ruined wall, thirty long and four thick: courses of big blocks laid
## in a running bond and broken off unevenly along the top, each block a little
## out of true with the next — which is what a spider climbs by.
static func _ruin_wall() -> Node3D:
	var it := WorldKit.body(null, "RuinWall")
	var course := 3.2
	var block := 6.0
	# How many courses still stand at each place along it, end to end.
	var standing := [9, 8, 8, 6, 7, 4, 3]
	for row in 9:
		var offset := block * 0.5 if row % 2 == 1 else 0.0
		var count := 5 if row % 2 == 0 else 4
		for k in count:
			var x := -15.0 + offset + block * (float(k) + 0.5)
			var column := clampi(int((x + 15.0) / 30.0 * float(standing.size())), 0,
				standing.size() - 1)
			if row >= int(standing[column]):
				continue
			var jog := 0.18 * sin(float(row * 7 + k * 3))
			var turn := 0.02 * sin(float(row * 5 + k * 11))
			WorldKit.box(it, "Block", Vector3(block - 0.15, course - 0.12, 4.0 + jog),
				Transform3D(Basis(Vector3.UP, turn), Vector3(x, course * (float(row) + 0.5), jog * 0.5)),
				"ruin" if (row + k) % 3 != 0 else "ruin_dark")
	WorldKit.ball(it, "Moss", Vector3(9.0, 1.4, 3.2), WorldKit.at(Vector3(-6.0, 0.4, 2.2)), "moss",
		false)
	WorldKit.ball(it, "Moss", Vector3(6.0, 1.1, 2.6), WorldKit.at(Vector3(8.0, 0.3, -2.0)), "moss",
		false)
	return it


## An arch between two pillars: each pillar a stack of drums with a square stone on
## top, and the arch sprung between them in wedge-shaped stones.
static func _ruin_arch() -> Node3D:
	var it := WorldKit.body(null, "RuinArch")
	var span := 10.0
	for side in [-1.0, 1.0]:
		var x: float = side * span
		WorldKit.box(it, "Base", Vector3(6.4, 2.0, 6.4), WorldKit.at(Vector3(x, 1.0, 0.0)), "ruin_dark")
		for drum in 3:
			WorldKit.cylinder(it, "Drum", 2.5, 7.4, WorldKit.at(Vector3(x, 2.0 + 7.5 * (float(drum)
				+ 0.5), 0.0), float(drum) * 23.0), "ruin", true, -1.0, 14)
		WorldKit.box(it, "Capital", Vector3(6.2, 1.6, 6.2), WorldKit.at(Vector3(x, 25.3, 0.0)),
			"ruin_dark")
	var stones := 9
	for k in stones:
		var angle := PI * (float(k) + 0.5) / float(stones)
		var at := Vector3(cos(angle) * span, 26.1 + sin(angle) * span, 0.0)
		var facing := Basis(Vector3.BACK, angle - PI * 0.5)
		WorldKit.box(it, "Voussoir", Vector3(3.3, 2.8, 5.0), Transform3D(facing, at),
			"ruin" if k % 2 == 0 else "ruin_dark")
	return it


## A column still standing on its base: three drums, the top one cracked off at a
## slant, and no capital any more.
static func _ruin_pillar() -> Node3D:
	var it := WorldKit.body(null, "RuinPillar")
	WorldKit.box(it, "Base", Vector3(6.4, 2.0, 6.4), WorldKit.at(Vector3(0.0, 1.0, 0.0)), "ruin_dark")
	WorldKit.cylinder(it, "Drum", 2.5, 7.4, WorldKit.at(Vector3(0.0, 5.75, 0.0)), "ruin", true, -1.0,
		14)
	WorldKit.cylinder(it, "Drum", 2.5, 7.4, Transform3D(Basis(Vector3.UP, 0.4), Vector3(0.12, 13.25,
		0.05)), "ruin", true, -1.0, 14)
	WorldKit.cylinder(it, "Broken", 2.5, 4.6, Transform3D(Basis(Vector3.BACK, 0.12), Vector3(0.1,
		19.3, 0.0)), "ruin_dark", true, -1.0, 14)
	return it


## A column that came down: its drums lying where they rolled, one broken.
static func _fallen_pillar() -> Node3D:
	var it := WorldKit.body(null, "FallenPillar")
	var lying := Basis(Vector3.BACK, PI * 0.5)
	WorldKit.box(it, "Base", Vector3(6.4, 2.0, 6.4), WorldKit.at(Vector3(-13.0, 1.0, 0.0)),
		"ruin_dark")
	for drum in 3:
		var turn := Basis(Vector3.UP, 0.12 * float(drum - 1))
		WorldKit.cylinder(it, "Drum", 2.5, 7.4, Transform3D(turn * lying, Vector3(-6.0 + 8.0
			* float(drum), 2.4, 0.6 * float(drum - 1))), "ruin", true, -1.0, 14)
	WorldKit.box(it, "Capital", Vector3(6.2, 1.6, 6.2), Transform3D(Basis(Vector3.UP, 0.5)
		* Basis(Vector3.RIGHT, 0.3), Vector3(20.0, 1.8, 2.0)), "ruin_dark")
	return it


## One block off a wall, lying where it fell.
static func _ruin_block() -> Node3D:
	var it := WorldKit.body(null, "RuinBlock")
	WorldKit.box(it, "Block", Vector3(5.85, 3.1, 4.0), Transform3D(Basis(Vector3.BACK, 0.12)
		* Basis(Vector3.RIGHT, -0.08), Vector3(0.0, 1.6, 0.0)), "ruin")
	return it


## Flagstones: a patch of old paving, the stones uneven and gapped, grass between.
static func _flagstones() -> Node3D:
	var it := WorldKit.body(null, "Flagstones")
	for i in 3:
		for k in 3:
			var size := Vector3(6.4 + 0.6 * sin(float(i * 3 + k)), 0.6, 6.0 + 0.5 * cos(float(i + k * 2)))
			var at := Vector3((float(i) - 1.0) * 7.0, 0.3 + 0.1 * sin(float(i * 5 + k)),
				(float(k) - 1.0) * 6.6)
			WorldKit.box(it, "Stone", size, Transform3D(Basis(Vector3.UP, 0.05 * sin(float(i + k))), at),
				"ruin" if (i + k) % 2 == 0 else "ruin_dark")
	return it


# --- the mere ----------------------------------------------------------

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


## A branch the water brought ashore and left, bleached pale: a length of it lying
## along the ground, a fork off one side, and a snapped-off stub sticking up.
static func _driftwood() -> Node3D:
	var it := WorldKit.body(null, "Driftwood")
	WorldKit.rod(it, "Log", Vector3(-9.0, 1.1, 0.0), Vector3(9.0, 0.9, 0.6), 1.3, "driftwood", true,
		0.8, 10)
	WorldKit.rod(it, "Fork", Vector3(2.0, 1.0, 0.3), Vector3(8.0, 1.6, -5.0), 0.6, "driftwood", true,
		0.25, 8)
	WorldKit.rod(it, "Stub", Vector3(-4.0, 1.4, 0.1), Vector3(-4.8, 5.2, 0.6), 0.55, "driftwood",
		true, 0.35, 8)
	return it


# --- wyrm's crag --------------------------------------------------------

## A heap of fallen crag: three angular blocks of rock leaning on one another,
## the way they came down.
static func _crag_rock() -> Node3D:
	var it := WorldKit.body(null, "CragRock")
	WorldKit.box(it, "Rock", Vector3(12.0, 9.0, 10.0), Transform3D(Basis.from_euler(Vector3(0.25,
		0.4, 0.12)), Vector3(0.0, 3.6, 0.0)), "rock")
	WorldKit.box(it, "Rock", Vector3(8.0, 7.0, 9.0), Transform3D(Basis.from_euler(Vector3(-0.3, 1.1,
		0.35)), Vector3(8.0, 2.4, 3.0)), "rock_dark")
	WorldKit.box(it, "Rock", Vector3(6.0, 5.0, 6.0), Transform3D(Basis.from_euler(Vector3(0.5, 0.2,
		-0.4)), Vector3(-6.5, 1.8, -4.0)), "rock")
	return it


## A spire of rock standing up off the crag: a tall pillar leaning a little, a
## broken cap on it, rubble round its foot. A perch.
static func _crag_spire() -> Node3D:
	var it := WorldKit.body(null, "CragSpire")
	WorldKit.box(it, "Pillar", Vector3(9.0, 34.0, 8.0), Transform3D(Basis.from_euler(Vector3(0.04,
		0.3, 0.06)), Vector3(0.0, 15.0, 0.0)), "rock")
	WorldKit.box(it, "Cap", Vector3(7.0, 9.0, 6.5), Transform3D(Basis.from_euler(Vector3(0.12, 0.9,
		-0.1)), Vector3(0.8, 34.5, 0.4)), "rock_dark")
	for i in 4:
		var turn := float(i) * 1.7
		WorldKit.box(it, "Rubble", Vector3(4.0, 3.0, 3.5), Transform3D(Basis.from_euler(Vector3(
			0.3 * float(i), turn, 0.2)), Vector3(cos(turn) * 7.0, 1.0, sin(turn) * 7.0)), "rock_dark")
	return it
