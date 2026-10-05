class_name FarmLand
extends RefCounted

## The farm: a square of empty meadow with nothing on it yet, and everything round
## it that is not the spider's to build on.
##
## The land is the [Farm]'s grid — [constant Farm.cells] squares a side — laid out as
## a meadow a shade lighter than the grass round it, with a post at each corner so
## its edges can be found. South of it runs a dirt road, and on the road stands the
## market, where the dishes are sold. Round the rest of it there is a hedge, and
## trees beyond. The spider starts by the market, looking north over the empty land.
##
## This is the generator of record: `tools/bake_level.gd` runs it and saves what it
## makes to [constant SCENE], which is what the game opens. Run the bake again and
## anything moved by hand is lost.

const SCENE := "res://game/world/farm.tscn"

## What the HUD calls the place.
const NAME := "The Farm"

## Where the market stands, and where the spider starts: south of the land, by the
## road.
const MARKET := Vector3(-8.0, 0.0, 27.5)
const START := Vector3(-4.0, 0.6, 21.5)


static func build(level: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	Site.sky(level, "bright")
	Site.ground(level, "grass")
	var farm := Farm.new()
	farm.name = "Farm"
	level.add_child(farm)
	var half := float(farm.cells) * farm.cell_size * 0.5
	var scenery := WorldKit.group(level, "Scenery")
	_land(scenery, half)
	_road(scenery, half)
	_hedge(scenery, half, rng)
	_trees(scenery, half, rng)
	var market := MarketStall.new()
	market.name = "Market"
	market.position = MARKET
	level.add_child(market)
	Site.spider(level, START)


## The meadow the farm is built on, a shade off the grass, and a post at each of its
## corners.
static func _land(on: Node3D, half: float) -> void:
	WorldKit.box(on, "Meadow", Vector3(half * 2.0, 0.02, half * 2.0),
		WorldKit.at(Vector3(0.0, 0.0, 0.0)), "meadow", false)
	var posts := WorldKit.body(on, "CornerPosts")
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			var at := Vector3(x * half, 0.0, z * half)
			WorldKit.box(posts, "Post%s%s" % ["W" if x < 0.0 else "E", "N" if z < 0.0 else "S"],
				Vector3(0.22, 1.4, 0.22), WorldKit.at(at + Vector3(0.0, 0.7, 0.0)), "wood_dark")
			WorldKit.box(posts, "Cap%s%s" % ["W" if x < 0.0 else "E", "N" if z < 0.0 else "S"],
				Vector3(0.3, 0.08, 0.3), WorldKit.at(at + Vector3(0.0, 1.44, 0.0)), "gate_red", false)


## A dirt road along the south, past the market.
static func _road(on: Node3D, half: float) -> void:
	WorldKit.box(on, "Road", Vector3(half * 2.0 + 40.0, 0.03, 5.0),
		WorldKit.at(Vector3(0.0, 0.0, half + 4.5)), "dirt", false)


## A low hedge round the north, east and west of the land, a few metres out, with
## gaps in it.
static func _hedge(on: Node3D, half: float, rng: RandomNumberGenerator) -> void:
	var hedge := WorldKit.body(on, "Hedge")
	var out := half + 3.0
	var n := 0
	for side in 3:
		for i in 18:
			if rng.randf() < 0.12:
				continue
			var along := lerpf(-out, out, (float(i) + 0.5) / 18.0)
			var at := Vector3(along, 0.0, -out) if side == 0 else (
				Vector3(-out, 0.0, along) if side == 1 else Vector3(out, 0.0, along))
			var size := rng.randf_range(0.9, 1.4)
			n += 1
			WorldKit.ball(hedge, "Bush%d" % n, Vector3(size * 1.3, size * 0.8, size),
				WorldKit.at(at + Vector3(0.0, size * 0.5, 0.0), rng.randf() * 360.0),
				["leaf", "leaf_dark", "leaf_light"][n % 3])


## Trees round the farm, beyond the hedge and the road, thinning out with distance.
static func _trees(on: Node3D, half: float, rng: RandomNumberGenerator) -> void:
	var trees := WorldKit.body(on, "Trees")
	var count := 0
	for i in 70:
		var angle := rng.randf() * TAU
		var reach := rng.randf_range(half + 9.0, half + 45.0)
		var at := Vector3(cos(angle) * reach, 0.0, sin(angle) * reach)
		# Off the road.
		if absf(at.z - (half + 4.5)) < 4.0:
			continue
		count += 1
		var tall := rng.randf_range(3.5, 6.5)
		WorldKit.cylinder(trees, "Trunk%d" % count, 0.25, tall, WorldKit.at(at + Vector3(0.0, tall * 0.5, 0.0)),
			"bark", true, 0.16, 10)
		var crown := rng.randf_range(1.6, 2.6)
		WorldKit.ball(trees, "Crown%d" % count, Vector3(crown, crown * 0.85, crown),
			WorldKit.at(at + Vector3(0.0, tall + crown * 0.4, 0.0)),
			["leaf", "leaf_dark", "leaf_light"][count % 3])
