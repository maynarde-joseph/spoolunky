class_name Cathedral
extends RefCounted

## A great church with its roof gone, under a sky that is about to rain.
##
## The nave runs west to east, twelve metres wide between two rows of piers twelve
## high, with an aisle down each side behind them and the walls of the aisles ten
## high, every bay a tall window. Over the piers the upper walls go on to twenty-two
## metres, every bay another window, held up from outside by flying buttresses off
## piers along the aisles, each with a pinnacle on top. Past the nave the transept
## crosses it, and past that the choir ends in a rounded apse of tall windows.
##
## The west front is a great doorway with a rose window over it and a gable over
## that, between two towers standing over the ends of the aisles. The south tower
## stands, a belfry and a spire on it; the north one broke off halfway and lies at
## its foot.
##
## Nothing is over any of it now. Some of the piers have come down across the nave
## and a stretch of the north aisle wall has fallen outward, and the stone is where
## it fell. It is a long open space with rows of things to climb and string silk
## between, and the high walls to get up on.
##
## This is the generator of record; `tools/bake_level.gd` saves what it makes to
## [constant SCENE].

const SCENE := "res://game/world/cathedral.tscn"

## What the HUD calls the place on the way in.
const NAME := "The Cathedral"

## Half the width of the nave, between the piers, and how wide each aisle is.
const NAVE := 6.0
const AISLE := 5.5

## How far apart the piers are along the nave, and where the nave starts and ends:
## the inside of the west front, and the crossing.
const BAY := 5.0
const WEST := -25.0
const CROSSING := 25.0

## The crossing and the choir past it, each two bays long, and the apse's radius.
const CHOIR := 45.0
const APSE := NAVE

## How tall the piers are, and the aisle walls, and the upper walls on the piers.
const PIERS := 12.0
const AISLE_WALL := 10.0
const UPPER := 22.0

## How far the transept reaches out from the middle either side.
const TRANSEPT := 21.5

## The bays of the north aisle wall that have fallen, counted from the west.
const FALLEN_BAYS: Array[int] = [3, 4, 5]

## Where the spider starts: just inside the great door, facing up the nave.
const START := Vector3(-22.0, 0.8, 0.0)
const START_TURN := -90.0


static func build(level: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1248
	Site.sky(level, "overcast")
	Site.ground(level)
	var church := WorldKit.group(level, "Church")
	_floor(church)
	var standing := _piers(WorldKit.group(church, "Piers"), rng)
	_upper_walls(WorldKit.group(church, "UpperWalls"), standing, rng)
	_aisles(WorldKit.group(church, "Aisles"), rng)
	_buttresses(WorldKit.group(church, "Buttresses"), standing)
	_transept(WorldKit.group(church, "Transept"))
	_apse(WorldKit.group(church, "Apse"))
	_west_front(WorldKit.group(church, "WestFront"))
	_towers(WorldKit.group(church, "Towers"), rng)
	_ruin(WorldKit.group(level, "Ruin"), rng)
	Site.zone(level, NAME, Vector2(60.0, 30.0), 40.0)
	Site.spider(level, START, START_TURN)


## The x of every pier down one side, west to east, crossing and choir included.
static func pier_xs() -> Array[float]:
	var xs: Array[float] = []
	var x := WEST + BAY
	while x <= CHOIR + 0.01:
		xs.append(x)
		x += BAY
	return xs


## A wall running east-west from [param from_x] to [param to_x] along [param z].
static func _along_x(parent: Node3D, part_name: String, piece: String, from_x: float, to_x: float,
		z: float, up: float, height: float, thick: float) -> KitBlock:
	return KitBlock.make(parent, part_name, piece, Vector3(to_x - from_x, height, thick),
		WorldKit.at(Vector3((from_x + to_x) * 0.5, up, z)))


## A wall running north-south from [param from_z] to [param to_z] along [param x].
static func _along_z(parent: Node3D, part_name: String, piece: String, from_z: float, to_z: float,
		x: float, up: float, height: float, thick: float) -> KitBlock:
	return KitBlock.make(parent, part_name, piece, Vector3(to_z - from_z, height, thick),
		WorldKit.at(Vector3(x, up, (from_z + to_z) * 0.5), 90.0))


# --- inside ----------------------------------------------------------------

static func _floor(church: Node3D) -> void:
	var wide := (NAVE + AISLE) * 2.0
	Site.floor_of(church, "Floor", Vector2(CHOIR + APSE - WEST, wide),
		Vector3((WEST + CHOIR + APSE) * 0.5, 0.0, 0.0), "stone_dark")
	for sign in [-1.0, 1.0]:
		var reach: float = TRANSEPT - (NAVE + AISLE)
		Site.floor_of(church, "TranseptFloor%s" % ("North" if sign < 0.0 else "South"),
			Vector2(BAY * 2.0, reach),
			Vector3(CROSSING + BAY, 0.0, sign * (NAVE + AISLE + reach * 0.5)), "stone_dark")


## The two rows of piers. A few are broken short and a few are gone — they lie
## across the nave — and what still stands to full height is returned, as the x of
## each, for the walls that sit on them.
static func _piers(piers: Node3D, rng: RandomNumberGenerator) -> Dictionary:
	var standing := {-1.0: [], 1.0: []}
	for side in [-1.0, 1.0]:
		var tag := "North" if side < 0.0 else "South"
		for x in pier_xs():
			var crossing := is_equal_approx(x, CROSSING) or is_equal_approx(x, CROSSING + BAY * 2.0)
			var thick := 2.0 if crossing else 1.4
			var height := PIERS + (2.0 if crossing else 0.0)
			var fate := rng.randf()
			if not crossing and x > WEST + BAY * 2.0 and x < CROSSING - BAY and fate < 0.14:
				continue
			if not crossing and fate < 0.26:
				height = rng.randf_range(4.0, 8.0)
			else:
				(standing[side] as Array).append(x)
			KitBlock.make(piers, "%sPier%d" % [tag, piers.get_child_count() + 1], "pillar3",
				Vector3(thick, height, thick), WorldKit.at(Vector3(x, 0.0, side * NAVE)))
	return standing


## Over the piers: a beam from one standing pier to the next, and on it the upper
## wall, every bay an open window — wherever both piers of the bay still stand.
static func _upper_walls(walls: Node3D, standing: Dictionary, rng: RandomNumberGenerator) -> void:
	for side in [-1.0, 1.0]:
		var tag := "North" if side < 0.0 else "South"
		var xs: Array = standing[side]
		for i in xs.size() - 1:
			var a: float = xs[i]
			var b: float = xs[i + 1]
			if b - a > BAY + 0.01 or a >= CROSSING - 0.01 and b <= CROSSING + BAY * 2.0 + 0.01:
				continue
			_along_x(walls, "%sBeam%d" % [tag, i + 1], "wall", a, b, side * NAVE, PIERS, 1.0, 1.2)
			if rng.randf() < 0.18:
				continue
			_along_x(walls, "%sClerestory%d" % [tag, i + 1], "wall window1", a, b, side * NAVE,
				PIERS + 1.0, UPPER - PIERS - 1.0, 1.0)


## The aisle walls, every bay a tall window, along the nave and the choir — but not
## across the transept, which opens off the crossing. A stretch of the north one has
## fallen outward and lies where it fell.
static func _aisles(aisles: Node3D, rng: RandomNumberGenerator) -> void:
	var z := NAVE + AISLE + 0.5
	for side in [-1.0, 1.0]:
		var tag := "North" if side < 0.0 else "South"
		var x := WEST
		var bay := 0
		while x < CHOIR - 0.01:
			var next := x + BAY
			bay += 1
			if x >= CROSSING - 0.01 and next <= CROSSING + BAY * 2.0 + 0.01 or bay == 1:
				x = next
				continue
			if side < 0.0 and FALLEN_BAYS.has(bay):
				var stump := rng.randf_range(1.0, 3.5)
				_along_x(aisles, "%sStump%d" % [tag, bay], "wall", x, next, side * z, 0.0, stump, 1.0)
				Site.rubble(aisles, rng, Vector3((x + next) * 0.5, 0.0, side * (z + 4.0)), 3.5, 8, 2.0)
			else:
				_along_x(aisles, "%sWall%d" % [tag, bay], "wall window1", x, next, side * z, 0.0,
					AISLE_WALL, 1.0)
			x = next


## Outside every pier along the aisles: a buttress with a pinnacle on it, and a
## flying buttress from its top over the aisle to the upper wall, where the upper
## wall still stands to be held up.
static func _buttresses(buttresses: Node3D, standing: Dictionary) -> void:
	var foot := NAVE + AISLE + 2.5
	for side in [-1.0, 1.0]:
		var tag := "North" if side < 0.0 else "South"
		for x in pier_xs():
			if x > CROSSING - 0.01 and x < CROSSING + BAY * 2.0 + 0.01:
				continue
			KitBlock.make(buttresses, "%sButtress%d" % [tag, buttresses.get_child_count() + 1],
				"wall", Vector3(1.2, PIERS, 3.0), WorldKit.at(Vector3(x, 0.0, side * foot)))
			KitBlock.make(buttresses, "%sPinnacle%d" % [tag, buttresses.get_child_count() + 1],
				"cone3", Vector3(1.2, 3.0, 1.2), WorldKit.at(Vector3(x, PIERS, side * foot)))
			if not (standing[side] as Array).has(x):
				continue
			var from := Vector3(x, PIERS - 1.5, side * (foot - 1.0))
			var to := Vector3(x, UPPER - 4.0, side * (NAVE + 0.6))
			var run := to - from
			var up := run.normalized()
			var across := Vector3.RIGHT
			KitBlock.make(buttresses, "%sFlyer%d" % [tag, buttresses.get_child_count() + 1], "wall",
				Vector3(0.8, run.length(), 0.8), Transform3D(Basis(across, up, across.cross(up)), from))


## The transept: the crossing's four great piers are in with the rest; this is the
## walls round its two arms, and a great window at the end of each.
static func _transept(transept: Node3D) -> void:
	var east := CROSSING + BAY * 2.0
	var aisle_edge := NAVE + AISLE
	for side in [-1.0, 1.0]:
		var tag := "North" if side < 0.0 else "South"
		var end_z: float = side * (TRANSEPT + 0.5)
		_along_x(transept, "%sEnd" % tag, "wall window1", CROSSING - 0.5, east + 0.5, end_z, 0.0,
			16.0, 1.2)
		for x in [CROSSING, east]:
			var from_z: float = side * aisle_edge
			var to_z: float = side * TRANSEPT
			_along_z(transept, "%sSide%d" % [tag, transept.get_child_count() + 1], "wall window1",
				minf(from_z, to_z), maxf(from_z, to_z), x, 0.0, AISLE_WALL + 2.0, 1.0)


## The east end: the aisles closed off, and a half ring of tall windows round the end
## of the choir.
static func _apse(apse: Node3D) -> void:
	for side in [-1.0, 1.0]:
		var from_z: float = side * NAVE
		var to_z: float = side * (NAVE + AISLE + 1.0)
		_along_z(apse, "%sAisleEnd" % ("North" if side < 0.0 else "South"), "wall",
			minf(from_z, to_z), maxf(from_z, to_z), CHOIR + 0.5, 0.0, AISLE_WALL, 1.0)
	var count := 5
	for i in count:
		var a := -PI * 0.5 + PI * float(i) / float(count)
		var b := -PI * 0.5 + PI * float(i + 1) / float(count)
		var from := Vector3(CHOIR + cos(a) * APSE, 0.0, sin(a) * APSE)
		var to := Vector3(CHOIR + cos(b) * APSE, 0.0, sin(b) * APSE)
		var middle := (from + to) * 0.5
		var run := (to - from).normalized()
		var turn := Basis(run, Vector3.UP, run.cross(Vector3.UP))
		KitBlock.make(apse, "Apse%d" % (i + 1), "wall window1",
			Vector3(from.distance_to(to) + 0.4, UPPER - 4.0, 1.0), Transform3D(turn, middle))


## The west front between the towers: the great door, the rose window over it in an
## open frame, and the gable on top.
static func _west_front(front: Node3D) -> void:
	var x := WEST - 0.75
	var nave_wide := NAVE * 2.0
	var frame_top := UPPER + 2.0
	_along_z(front, "GreatDoor", "wall door", -NAVE, NAVE, x, 0.0, 14.0, 1.5)
	_along_z(front, "RoseFrame", "wall window1", -NAVE, NAVE, x, 14.0, frame_top - 14.0, 1.5)
	# The kit's ring lies flat; stood on its edge it faces west, in the middle of
	# the frame's opening.
	var rose := (frame_top - 14.0) * 0.5
	KitBlock.make(front, "RoseWindow", "torus", Vector3(rose - 0.2, 0.5, rose - 0.2),
		Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(x + 0.25, 14.0 + (frame_top - 14.0) * 0.5, 0.0)))
	KitBlock.make(front, "Gable", "cone2", Vector3(1.5, 5.0, nave_wide), WorldKit.at(Vector3(x, frame_top, 0.0)))


## Two towers over the west ends of the aisles, their fronts in line with the west
## front. The south one stands to its belfry, open on every side, with a spire on it;
## the north one broke off halfway.
static func _towers(towers: Node3D, rng: RandomNumberGenerator) -> void:
	var wide := AISLE + 1.0
	var x := WEST - 1.5 + wide * 0.5
	for side in [-1.0, 1.0]:
		var z: float = side * (NAVE + wide * 0.5)
		var whole: bool = side > 0.0
		var height := 30.0 if whole else 18.0
		KitBlock.make(towers, "%sTower" % ("North" if side < 0.0 else "South"), "wall",
			Vector3(wide, height, wide), WorldKit.at(Vector3(x, 0.0, z)))
		if not whole:
			Site.rubble(towers, rng, Vector3(x - 6.0, 0.0, z + side * 5.0), 5.0, 14, 2.4)
			continue
		var belfry := 8.0
		for face in 4:
			var turn := Basis(Vector3.UP, PI * 0.5 * face)
			var at := Vector3(x, height, z) + turn * Vector3(0.0, 0.0, wide * 0.5 - 0.5)
			KitBlock.make(towers, "Belfry%d" % (face + 1), "wall window1", Vector3(wide, belfry, 1.0),
				Transform3D(turn, at))
		KitBlock.make(towers, "Spire", "cone3", Vector3(wide, 14.0, wide),
			WorldKit.at(Vector3(x, height + belfry, z)))


## What came down: piers lying across the nave, and loose stone about the floor.
static func _ruin(ruin: Node3D, rng: RandomNumberGenerator) -> void:
	Site.fallen(ruin, "FallenPier1", "pillar3", Vector3(-6.0, 0.0, -3.0), 30.0, 12.0, 1.4)
	Site.fallen(ruin, "FallenPier2", "pillar3", Vector3(9.0, 0.0, 2.5), -20.0, 12.0, 1.4)
	Site.fallen(ruin, "FallenPier3", "pillar3", Vector3(17.0, 0.0, 9.0), 75.0, 9.0, 1.4)
	for spot in [Vector3(-10.0, 0.0, 1.0), Vector3(4.0, 0.0, -2.0), Vector3(20.0, 0.0, 3.0),
			Vector3(30.0, 0.0, 14.0), Vector3(40.0, 0.0, -8.0)]:
		Site.rubble(ruin, rng, spot, 2.0, 5, 1.6)
