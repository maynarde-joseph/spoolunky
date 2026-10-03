class_name Temple
extends RefCounted

## A walled square court with stands round it: the first thing built from the kit,
## and more temple than arena, so it is kept for a dungeon of its own.
##
## A square of sand thirty-six metres across, walled four high, with a way out in
## the middle of each side. Behind the wall the stands go up in three tiers, four
## metres a tier, to a rim of open windows twelve metres up. Each way out is a gate
## in the wall and a cut through the stands behind it, ending at a shut door in the
## outside wall.
##
## Everything is a piece of the kit, so everything is solid: the spider can climb
## the wall, string silk between the columns along it, walk the tiers and look out
## over the rim. The tiers are [KitBlock]s, the kit's wall stretched to the size of
## a tier, so the bulk is a few nodes and still takes the kit's look.
##
## This is the generator of record: `tools/bake_level.gd` runs it and saves what it
## makes to [constant SCENE], which is what the editor edits. Run the bake again and
## anything moved by hand is lost.

const SCENE := "res://game/world/temple.tscn"

## What the HUD calls the place on the way in.
const NAME := "The Temple"

## Half the width of the sand: from the middle to the face of the wall.
const ARENA := 18.0

## How deep each tier of the stands is, and how much higher than the one before.
const TIER := 4.0
const TIERS := 3

## Half the width of the way out through the stands on each side.
const WAY := 2.0

## From the middle to the outside of the stands.
const RIM := ARENA + TIER * TIERS

## Where the spider starts: on the sand, back from the south gate, facing in.
const START := Vector3(0.0, 0.8, 12.0)

## How far along each side the aisles climb the stands, either side of the middle.
const AISLE := 12.0

## How far along each side the columns stand in front of the wall.
const COLUMNS: Array[float] = [6.0, 10.0, 14.0]

## The four sides, by the way out of the court each one faces.
const SIDES := {
	"North": Vector3(0.0, 0.0, -1.0),
	"East": Vector3(1.0, 0.0, 0.0),
	"South": Vector3(0.0, 0.0, 1.0),
	"West": Vector3(-1.0, 0.0, 0.0),
}


## Builds the whole place under [param level]: sky, ground, court, stands, and the
## spider, the HUD and somewhere for webs to go.
static func build(level: Node3D) -> void:
	Site.sky(level, "clear")
	Site.ground(level)
	var court := WorldKit.group(level, "Court")
	Site.floor_of(court, "Floor", Vector2(ARENA * 2.0, ARENA * 2.0), Vector3.ZERO, "straw")
	_columns(court)
	var stands := WorldKit.group(level, "Stands")
	_tiers(stands)
	_aisles(stands)
	_ways(WorldKit.group(level, "Ways"))
	_rim(WorldKit.group(level, "Rim"))
	Site.zone(level, NAME, Vector2(RIM, RIM), 28.0)
	Site.spider(level, START)


## Columns along the foot of the wall, four metres apart, and one in each corner:
## something to climb, and posts to string silk between.
static func _columns(court: Node3D) -> void:
	var holder := WorldKit.group(court, "Columns")
	for side in SIDES:
		var facing: Vector3 = SIDES[side]
		for along in COLUMNS:
			for sign in [-1.0, 1.0]:
				Kit.place(holder, "pillar3", Site.frame(facing, sign * along, ARENA - 0.5, 0.0),
					"%sColumn%s" % [side, _toward(facing, sign)])
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var at := Vector3(corner.x, 0.0, corner.y) * (ARENA - 0.5)
		Kit.place(holder, "pillar3", WorldKit.at(at), "%sColumn" % _corner_name(corner))


## Three tiers, each four deep and four higher than the last, round all four sides
## and split down the middle of each by its way out. North and south run the full
## width, corners and all; east and west fit between them.
static func _tiers(stands: Node3D) -> void:
	for k in TIERS:
		var inner := ARENA + TIER * k
		var outer := inner + TIER
		var height := TIER * (k + 1)
		for side in SIDES:
			var facing: Vector3 = SIDES[side]
			var reach := outer if facing.z != 0.0 else inner
			var length := reach - WAY
			for sign in [-1.0, 1.0]:
				KitBlock.make(stands, "%sTier%d%s" % [side, k + 1, _toward(facing, sign)], "wall",
					Vector3(length, height, TIER),
					Site.frame(facing, sign * (WAY + length * 0.5), (inner + outer) * 0.5, 0.0))


## A flight of stairs up each step of the stands — from the sand to the first tier,
## and from each tier to the next — at the same place on every side, either side of
## the way out. Each step is four high: two flights of the kit's stairs, the upper
## one on a block.
static func _aisles(stands: Node3D) -> void:
	var holder := WorldKit.group(stands, "Aisles")
	for side in SIDES:
		var facing: Vector3 = SIDES[side]
		for sign in [-1.0, 1.0]:
			var along: float = sign * AISLE
			var tag := "%sAisle%s" % [side, _toward(facing, sign)]
			for step in TIERS:
				var foot := ARENA - TIER + TIER * step
				var floor_height := TIER * step
				Kit.place(holder, "stairs", Site.frame(facing, along, foot + 1.0, floor_height),
					"%sStep%dLow" % [tag, step + 1])
				Kit.place(holder, "cube", Site.frame(facing, along, foot + 3.0, floor_height),
					"%sStep%dBlock" % [tag, step + 1])
				Kit.place(holder, "stairs", Site.frame(facing, along, foot + 3.0, floor_height + 2.0),
					"%sStep%dHigh" % [tag, step + 1])


## Each way out: a gate in the wall, the cut through the stands behind it, and a shut
## door at the far end with the outside wall built up over it to the rim.
static func _ways(ways: Node3D) -> void:
	for side in SIDES:
		var facing: Vector3 = SIDES[side]
		Kit.place(ways, "wall door", Site.frame(facing, 0.0, ARENA + 0.5, 0.0), "%sGate" % side)
		Kit.place(ways, "wall door1", Site.frame(facing, 0.0, RIM - 0.5, 0.0), "%sDoor" % side)
		KitBlock.make(ways, "%sOverDoor" % side, "wall", Vector3(WAY * 2.0, TIER * TIERS - 4.0, 1.0),
			Site.frame(facing, 0.0, RIM - 0.5, 4.0))


## Round the top of the stands, along the outside edge: a wall of open windows to
## look out of, with a corner piece at each corner.
static func _rim(rim: Node3D) -> void:
	var top := TIER * TIERS
	var corner_at := RIM - 2.0
	for side in SIDES:
		var facing: Vector3 = SIDES[side]
		var along := -(corner_at - 4.0)
		var i := 0
		while along <= corner_at - 4.0 + 0.01:
			Kit.place(rim, "wall window1", Site.frame(facing, along, RIM - 0.5, top),
				"%sWindow%d" % [side, i + 1])
			along += 4.0
			i += 1
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		# The piece's own corner is its -X, +Z one; turned to face the corner it fills.
		var turn := Basis(Vector3.UP, atan2(corner.x, corner.y) + PI * 0.25)
		var at := Vector3(corner.x * corner_at, top, corner.y * corner_at)
		Kit.place(rim, "wall corner", Transform3D(turn, at), "%sCorner" % _corner_name(corner))


# --- names -----------------------------------------------------------------

## Which way [param sign] points along the side facing [param facing], as a compass
## word, for naming the two halves of a side.
static func _toward(facing: Vector3, sign: float) -> String:
	var side := Basis(Vector3.UP, atan2(-facing.x, -facing.z)) * Vector3.RIGHT * sign
	if absf(side.x) > absf(side.z):
		return "East" if side.x > 0.0 else "West"
	return "South" if side.z > 0.0 else "North"


static func _corner_name(corner: Vector2) -> String:
	return ("North" if corner.y < 0.0 else "South") + ("West" if corner.x < 0.0 else "East")
