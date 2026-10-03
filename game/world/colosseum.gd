class_name Colosseum
extends RefCounted

## The great arena, long abandoned: an oval of stacked arches round a floor of sand,
## standing the way the one in Rome stands now.
##
## The arena is forty-eight metres by thirty-two, walled four high, with a gate at
## each end and in each side. Two tiers of seats go up behind the wall, cut through
## at every gate, and behind them a walk runs all the way round under the sky — the
## vaults that roofed it are gone. Then the outside wall: three storeys of arches
## and an attic over them, twenty-two metres up, with a column standing between
## every two arches. Along the south side the outside wall has fallen, the way
## Rome's did: storey by storey down to nothing at the worst of it, with the stone
## in heaps where it came down.
##
## And the floor has given way in the middle. Under it are the passages the beasts
## were kept in, four metres down, their walls reaching up to where the floor was —
## a maze to drop into, string silk across and climb out of.
##
## Everything is a piece of the kit, most of it stretched: an arch is the kit's
## doorway at the size of a storey, a seat row its stairs the length of a segment.
## This is the generator of record; `tools/bake_level.gd` saves what it makes to
## [constant SCENE], which is what the game opens.

const SCENE := "res://game/world/colosseum.tscn"

## What the HUD calls the place on the way in.
const NAME := "The Colosseum"

## Half the length and half the width of the sand, east-west and north-south.
const ARENA := Vector2(24.0, 16.0)

## How many segments the oval is built in. Four divides it, so a segment is centred
## on each end and each side, and that is where the gates are.
const SEGMENTS := 32

## The arena wall: how thick, and how high.
const PODIUM := Vector2(1.0, 4.0)

## The seats: how deep each tier is and how many there are. Each rises four.
const TIER := 4.0
const TIERS := 2

## The walk round behind the seats.
const WALK := 4.0

## The outside wall: how thick, how tall each storey of arches, how many storeys,
## and the attic over them.
const FACADE := 2.0
const STOREY := 6.0
const STOREYS := 3
const ATTIC := 4.0

## Where the outside wall has fallen: the bearing of the worst of it, in degrees
## from east towards south, and how far round either side the damage reaches.
const FALLEN_AT := 90.0
const FALLEN_SPREAD := 60.0

## The pit where the floor gave way: half its length and width, and how deep.
const PIT := Vector2(13.0, 5.0)
const PIT_DEPTH := 4.0

## Where the spider starts: on the sand at the west end, facing down the arena.
const START := Vector3(-19.0, 0.8, 0.0)
const START_TURN := -90.0

## The segments the gates are in: east, south, west and north.
const GATES: Array[int] = [0, SEGMENTS / 4, SEGMENTS / 2, SEGMENTS * 3 / 4]


static func build(level: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1784
	Site.sky(level, "warm")
	var hole := Rect2(-PIT.x - 1.0, -PIT.y - 1.0, (PIT.x + 1.0) * 2.0, (PIT.y + 1.0) * 2.0)
	Site.ground(level, "grass", hole)
	var arena := WorldKit.group(level, "Arena")
	Site.floor_of(arena, "Sand", ARENA * 2.0, Vector3.ZERO, "straw", hole)
	_podium(arena)
	_pit(WorldKit.group(arena, "Pit"))
	var seats := WorldKit.group(level, "Seats")
	_seats(seats, rng)
	_facade(WorldKit.group(level, "Facade"), rng)
	_ruin(WorldKit.group(level, "Ruin"), rng)
	Site.zone(level, NAME, ARENA + Vector2.ONE * (PODIUM.x + TIER * TIERS + WALK + FACADE + 6.0),
		32.0)
	Site.spider(level, START, START_TURN)


## The ring of segments [param depth] deep starting [param from] out from the edge
## of the sand.
static func ring(from: float, depth: float) -> Array[Dictionary]:
	var middle := from + depth * 0.5
	return Site.oval(ARENA.x + middle, ARENA.y + middle, SEGMENTS)


## How long a block [param depth] deep has to be on segment [param i] of
## [param segments] for it to meet its neighbours on its outside edge — they meet on
## the line through their middles, so each end reaches out by half its depth times
## how sharply the oval turns there. On the inside they overlap, out of sight.
static func reach(segments: Array[Dictionary], i: int, depth: float) -> float:
	var here: Vector3 = segments[i]["along"]
	var before: Vector3 = segments[(i - 1 + segments.size()) % segments.size()]["along"]
	var after: Vector3 = segments[(i + 1) % segments.size()]["along"]
	var turn := maxf(here.angle_to(before), here.angle_to(after))
	return segments[i]["length"] + depth * tan(turn * 0.5) + 0.05


static func _place(segments: Array[Dictionary], i: int, up: float) -> Transform3D:
	return Transform3D(segments[i]["basis"], segments[i]["middle"] + Vector3.UP * up)


# --- the arena -------------------------------------------------------------

## The wall round the sand, with a gate in it at each end and in each side.
static func _podium(arena: Node3D) -> void:
	var holder := WorldKit.group(arena, "Wall")
	var segments := ring(0.0, PODIUM.x)
	for i in SEGMENTS:
		var gate := GATES.has(i)
		KitBlock.make(holder, ("Gate%d" if gate else "Wall%d") % (i + 1),
			"wall door" if gate else "wall",
			Vector3(reach(segments, i, PODIUM.x), PODIUM.y, PODIUM.x), _place(segments, i, 0.0))


## Where the floor gave way: a pit lined with stone, and the walls of the passages
## under it standing up to floor level, with gaps to go through.
static func _pit(pit: Node3D) -> void:
	var low := -PIT_DEPTH
	Site.floor_of(pit, "Bottom", (PIT + Vector2.ONE) * 2.0, Vector3(0.0, low, 0.0), "soil")
	var long_side := (PIT.x + 1.0) * 2.0
	for sign in [-1.0, 1.0]:
		KitBlock.make(pit, "Lining%s" % ("North" if sign < 0.0 else "South"), "wall",
			Vector3(long_side, PIT_DEPTH, 1.0), WorldKit.at(Vector3(0.0, low, sign * (PIT.y + 0.5))))
		KitBlock.make(pit, "Lining%s" % ("West" if sign < 0.0 else "East"), "wall",
			Vector3(PIT.y * 2.0, PIT_DEPTH, 1.0),
			WorldKit.at(Vector3(sign * (PIT.x + 0.5), low, 0.0), 90.0))
	# Two long walls down the length, each broken into three with a way through
	# between, and short ones across them.
	for side in [-1.0, 1.0]:
		var z: float = side * PIT.y * 0.45
		for piece in [[-PIT.x, -5.0], [-3.0, 3.0], [5.0, PIT.x]]:
			var length: float = piece[1] - piece[0]
			KitBlock.make(pit, "Passage%s%d" % ["North" if side < 0.0 else "South", pit.get_child_count()],
				"wall", Vector3(length, PIT_DEPTH, 0.8),
				WorldKit.at(Vector3((piece[0] + piece[1]) * 0.5, low, z)))
	for x in [-8.0, 8.0]:
		for z in [-PIT.y * 0.72, PIT.y * 0.72]:
			KitBlock.make(pit, "Cross%d" % pit.get_child_count(), "wall",
				Vector3(PIT.y * 0.5, PIT_DEPTH, 0.8), WorldKit.at(Vector3(x, low, z), 90.0))


# --- the seats -------------------------------------------------------------

## Two tiers of seats behind the wall, each a row of the kit's stairs the length of
## a segment on a block of stone, cut through at every gate. Here and there a
## stretch of seats has come down.
static func _seats(seats: Node3D, rng: RandomNumberGenerator) -> void:
	for k in TIERS:
		var from := PODIUM.x + TIER * k
		var base := PODIUM.y + TIER * k
		var segments := ring(from, TIER)
		for i in SEGMENTS:
			if GATES.has(i):
				continue
			var length := reach(segments, i, TIER)
			KitBlock.make(seats, "Tier%dBase%d" % [k + 1, i + 1], "wall",
				Vector3(length, base, TIER), _place(segments, i, 0.0))
			# The upper tier has gone in places, more of it on the fallen side.
			var bearing: float = segments[i]["bearing"]
			var gone := 0.12 + (0.25 if _fallen_share(bearing) < 1.0 else 0.0)
			if k == TIERS - 1 and rng.randf() < gone:
				Site.rubble(seats, rng, segments[i]["middle"] + Vector3.UP * base, length * 0.4, 3, 1.4)
				continue
			KitBlock.make(seats, "Tier%dSeats%d" % [k + 1, i + 1], "stairs",
				Vector3(length, TIER, TIER), _place(segments, i, base))


# --- the outside wall ------------------------------------------------------

## How far a bearing is from the worst of the fall, as a share of how far the damage
## reaches: nought at the worst, one and over where the wall stands whole.
static func _fallen_share(bearing: float) -> float:
	var off := absf(fposmod(bearing - FALLEN_AT + 180.0, 360.0) - 180.0)
	return off / FALLEN_SPREAD


## How many storeys of the outside wall still stand on a segment at [param bearing],
## the attic counted as one more: all of them away from the fall, fewer towards the
## worst of it, and none there.
static func standing(bearing: float, rng: RandomNumberGenerator) -> int:
	var share := _fallen_share(bearing)
	var whole := STOREYS + 1
	if share >= 1.0:
		# Whole, but for an attic lost here and there.
		return whole - (1 if rng.randf() < 0.15 else 0)
	return clampi(int(floor(share * float(whole) + rng.randf_range(-0.45, 0.45))), 0, whole)


## Three storeys of arches and an attic of small windows, with a column between
## every two arches on every storey that still stands on both sides of it.
static func _facade(facade: Node3D, rng: RandomNumberGenerator) -> void:
	var from := PODIUM.x + TIER * TIERS + WALK
	var segments := ring(from, FACADE)
	var heights: Array[int] = []
	for i in SEGMENTS:
		heights.append(standing(segments[i]["bearing"], rng))
	for i in SEGMENTS:
		var length := reach(segments, i, FACADE)
		for storey in heights[i]:
			var attic := storey == STOREYS
			KitBlock.make(facade, ("Attic%d" if attic else "Arches%d") % (i + 1) \
					+ ("" if attic else "_%d" % (storey + 1)),
				"wall window" if attic else "wall door",
				Vector3(length, ATTIC if attic else STOREY, FACADE),
				_place(segments, i, STOREY * storey))
	# The columns stand on the outside face where two segments meet.
	for i in SEGMENTS:
		var before: Dictionary = segments[(i - 1 + SEGMENTS) % SEGMENTS]
		var here: Dictionary = segments[i]
		var out: Vector3 = ((before["out"] as Vector3) + (here["out"] as Vector3)).normalized()
		var foot: Vector3 = (here["from"] as Vector3) + out * (FACADE * 0.5 + 0.45)
		var turn := Basis(Vector3.UP, atan2(-out.x, -out.z))
		var storeys := mini(mini(heights[i], heights[(i - 1 + SEGMENTS) % SEGMENTS]), STOREYS)
		for storey in storeys:
			KitBlock.make(facade, "Column%d_%d" % [i + 1, storey + 1], "pillar3",
				Vector3(0.9, STOREY, 0.9), Transform3D(turn, foot + Vector3.UP * STOREY * storey))


# --- what fell -------------------------------------------------------------

## The stone that came down: heaps outside and inside the fallen stretch of the
## outside wall, a few blocks strewn on the sand, and columns lying where they fell.
static func _ruin(ruin: Node3D, rng: RandomNumberGenerator) -> void:
	var outside := ring(PODIUM.x + TIER * TIERS + WALK + FACADE + 3.0, 1.0)
	var walk := ring(PODIUM.x + TIER * TIERS + WALK * 0.5, 1.0)
	for i in SEGMENTS:
		var share := _fallen_share(outside[i]["bearing"])
		if share >= 1.0:
			continue
		var heap := int(lerpf(9.0, 2.0, share))
		Site.rubble(ruin, rng, outside[i]["middle"], 3.5, heap, 2.2)
		Site.rubble(ruin, rng, walk[i]["middle"], 1.6, heap / 2, 1.4)
	for spot in [Vector3(-8.0, 0.0, 11.0), Vector3(16.0, 0.0, -9.0), Vector3(3.0, 0.0, 9.0)]:
		Site.rubble(ruin, rng, spot, 1.5, 4, 1.2)
	Site.fallen(ruin, "FallenColumn1", "pillar3", Vector3(-12.0, 0.0, -9.5), 20.0, 6.0, 0.9)
	Site.fallen(ruin, "FallenColumn2", "pillar3", Vector3(10.0, 0.0, 11.0), -35.0, 6.0, 0.9)
	Site.fallen(ruin, "FallenColumn3", "pillar3", Vector3(6.0, 0.0, 47.0), 70.0, 6.0, 0.9)
	Site.fallen(ruin, "FallenColumn4", "pillar3", Vector3(-18.0, 0.0, 44.0), 10.0, 6.0, 0.9)
