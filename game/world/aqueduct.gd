class_name Aqueduct
extends RefCounted

## An aqueduct striding across a river valley on a bright morning, broken.
##
## Eighty metres of it, east to west: a row of arches fourteen high, a row of smaller
## ones on top of them, and on top of those the channel the water ran in, twenty-two
## metres up, walled low either side — a path along the sky a spider can walk.
##
## Two spans have fallen into the river, arches, channel and all, and left a gap of
## sixteen metres in the channel with the water under it: inside a grapple's reach,
## if you are brave, and a swim if you are not. Further west the upper row of one
## span has come down too, leaving a drop to the lower arch and a climb back up.
## The east end runs down a long ramp to the grass; the west end stands against the
## ruin of the tower the water was gathered in.
##
## This is the generator of record; `tools/bake_level.gd` saves what it makes to
## [constant SCENE].

const SCENE := "res://game/world/aqueduct.tscn"

## What the HUD calls the place on the way in.
const NAME := "The Aqueduct"

## How far it runs either side of the middle, and how long a span is.
const HALF := 40.0
const SPAN := 8.0

## The lower arches, the upper ones and the channel on top: heights and thickness.
const LOWER := Vector2(14.0, 3.0)
const UPPER := Vector2(7.0, 2.0)
const CHANNEL := 1.0

## The river: where it runs, west bank to east bank, and how deep it is.
const RIVER := Vector2(2.0, 14.0)
const RIVER_DEPTH := 3.0

## The spans that are gone, and the one that has lost its upper arches, by the x of
## their middles.
const FALLEN: Array[float] = [4.0, 12.0]
const BROKEN_TOP: Array[float] = [-28.0]

## Where the spider starts: on the grass south of the arches, near the river.
const START := Vector3(-6.0, 0.8, 14.0)


static func build(level: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 312
	Site.sky(level, "bright")
	Site.ground(level, "grass", Rect2(RIVER.x, -Site.GROUND, RIVER.y - RIVER.x, Site.GROUND * 2.0))
	_river(WorldKit.group(level, "River"), rng)
	_arches(WorldKit.group(level, "Arches"), rng)
	_ends(WorldKit.group(level, "Ends"), rng)
	Site.zone(level, NAME, Vector2(HALF + 30.0, 30.0), 40.0)
	Site.spider(level, START)


## The middles of every span, west to east.
static func spans() -> Array[float]:
	var middles: Array[float] = []
	var x := -HALF + SPAN * 0.5
	while x < HALF:
		middles.append(x)
		x += SPAN
	return middles


## The river in its bed: stone banks, a floor of mud, water to the brim, and what fell
## into it.
static func _river(river: Node3D, rng: RandomNumberGenerator) -> void:
	var length := Site.GROUND * 2.0
	var wide := RIVER.y - RIVER.x
	var middle := (RIVER.x + RIVER.y) * 0.5
	Site.floor_of(river, "Bed", Vector2(wide, length), Vector3(middle, -RIVER_DEPTH, 0.0), "soil")
	for side in [-1.0, 1.0]:
		var x: float = middle + side * (wide * 0.5 - 0.5)
		KitBlock.make(river, "Bank%s" % ("West" if side < 0.0 else "East"), "wall",
			Vector3(length, RIVER_DEPTH, 1.0), WorldKit.at(Vector3(x, -RIVER_DEPTH, 0.0), 90.0))
	WorldKit.water(river, "Water", Vector3(wide - 2.0, RIVER_DEPTH - 0.5, length),
		WorldKit.at(Vector3(middle, -RIVER_DEPTH + (RIVER_DEPTH - 0.5) * 0.5, 0.0)), "pond")
	for x in FALLEN:
		Site.rubble(river, rng, Vector3(x, -RIVER_DEPTH + 0.5, 0.0), 4.0, 9, 2.6)


## The arches: a row of tall ones, a row of short ones on them, and the channel on
## top — missing where the spans fell, with the channel's lip gone and stone heaped
## at the edges they broke from. The gap the fall left is the length of the two
## spans and no more, so it stays inside a grapple's reach.
static func _arches(arches: Node3D, rng: RandomNumberGenerator) -> void:
	var middles := spans()
	for i in middles.size():
		var x: float = middles[i]
		if FALLEN.has(x):
			continue
		var tag := "Span%d" % (i + 1)
		KitBlock.make(arches, tag + "Lower", "wall door", Vector3(SPAN, LOWER.x, LOWER.y),
			WorldKit.at(Vector3(x, 0.0, 0.0)))
		if BROKEN_TOP.has(x):
			Site.rubble(arches, rng, Vector3(x, 0.0, 5.0), 3.5, 7, 2.0)
			continue
		var fall_east := FALLEN.has(x + SPAN)
		var fall_west := FALLEN.has(x - SPAN)
		if fall_east or fall_west:
			Site.rubble(arches, rng, Vector3(x + (SPAN * 0.45 if fall_east else -SPAN * 0.45),
				LOWER.x + UPPER.x + CHANNEL, 0.0), 1.0, 3, 0.9)
		for half in [-1.0, 1.0]:
			var at := Vector3(x + half * SPAN * 0.25, LOWER.x, 0.0)
			KitBlock.make(arches, tag + ("UpperWest" if half < 0.0 else "UpperEast"), "wall door",
				Vector3(SPAN * 0.5, UPPER.x, UPPER.y), WorldKit.at(at))
			KitBlock.make(arches, tag + ("ChannelWest" if half < 0.0 else "ChannelEast"), "wall",
				Vector3(SPAN * 0.5, CHANNEL, UPPER.y + 1.0), WorldKit.at(at + Vector3.UP * UPPER.x))
			# The lip is gone on the half that broke off at the fall.
			var broken_edge: bool = (half > 0.0 and fall_east) or (half < 0.0 and fall_west)
			for side in [-1.0, 1.0]:
				if broken_edge and side > 0.0:
					continue
				KitBlock.make(arches, tag + "%sLip%s" % ["West" if half < 0.0 else "East",
						"North" if side < 0.0 else "South"], "wall",
					Vector3(SPAN * 0.5, 0.8, 0.4),
					WorldKit.at(at + Vector3(0.0, UPPER.x + CHANNEL, side * (UPPER.y * 0.5 + 0.3))))


## The ends: a ramp down from the channel to the grass in the east, and in the west
## the stump of the tower the water was gathered in.
static func _ends(ends: Node3D, rng: RandomNumberGenerator) -> void:
	var top := LOWER.x + UPPER.x + CHANNEL
	var run := 32.0
	KitBlock.make(ends, "Ramp", "ramp", Vector3(5.0, top, run),
		Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(HALF + run * 0.5, 0.0, 0.0)))
	KitBlock.make(ends, "Castellum", "wall", Vector3(10.0, top + 3.0, 10.0),
		WorldKit.at(Vector3(-HALF - 5.0, 0.0, 0.0)))
	for face in 4:
		var turn := Basis(Vector3.UP, PI * 0.5 * face)
		var at := Vector3(-HALF - 5.0, top + 3.0, 0.0) + turn * Vector3(0.0, 0.0, 4.5)
		if face == 1:
			continue
		KitBlock.make(ends, "CastellumWall%d" % (face + 1), "wall window1", Vector3(10.0, 4.0, 1.0),
			Transform3D(turn, at))
	Site.rubble(ends, rng, Vector3(-HALF - 10.0, 0.0, 6.0), 4.0, 10, 2.0)
