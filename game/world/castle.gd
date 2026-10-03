class_name Castle
extends RefCounted

## The courtyard of a castle that burned, the sun going down red behind it.
##
## A yard forty-four metres by thirty-six inside curtain walls nine high and three
## thick, with a walk along their tops behind battlements. A round tower stands at
## each corner, fourteen high; two still have their roofs, and two broke off and lie
## in heaps at their feet. The gatehouse is in the middle of the south wall, two
## towers either side of an arch with the portcullis stuck halfway down it — low
## enough to stop a horse and high enough to go under.
##
## The keep stands in the yard's north-east corner, three storeys of hollow walls
## round floors that have mostly gone, and its south-west corner has fallen away so
## you can see into it. A breach has been knocked in the west wall, and the rubble
## lies in a slope up into the gap from both sides. Otherwise the yard is what was
## left: a well, the stairs up to the wall-walk, crates and barrels against the walls.
##
## This is the generator of record; `tools/bake_level.gd` saves what it makes to
## [constant SCENE].

const SCENE := "res://game/world/castle.tscn"

## What the HUD calls the place on the way in.
const NAME := "The Castle"

## Half the yard's width east-west and north-south, to the walls' inside faces.
const YARD := Vector2(22.0, 18.0)

## The curtain walls: how thick and how high.
const WALL := Vector2(3.0, 9.0)

## The corner towers: how wide and how high.
const TOWER := Vector2(8.0, 14.0)

## The gatehouse: half the width of the way through, and how far its towers stand.
const GATE := 3.0

## The keep: its north-west corner's place in the yard, how wide, how many storeys,
## and how high each is.
const KEEP_CORNER := Vector2(6.0, -16.0)
const KEEP := 12.0
const KEEP_STOREYS := 3
const KEEP_STOREY := 7.0

## Where the west wall is breached, north to south.
const BREACH := Vector2(3.0, 11.0)

## Where the spider starts: just inside the gate, facing into the yard.
const START := Vector3(0.0, 0.8, 14.0)


static func build(level: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1347
	Site.sky(level, "dusk")
	Site.ground(level)
	var castle := WorldKit.group(level, "Castle")
	Site.floor_of(castle, "Yard", YARD * 2.0, Vector3.ZERO, "ruin")
	_curtain(WorldKit.group(castle, "Walls"), rng)
	_towers(WorldKit.group(castle, "Towers"), rng)
	_gatehouse(WorldKit.group(castle, "Gatehouse"))
	_keep(WorldKit.group(castle, "Keep"), rng)
	_yard(WorldKit.group(castle, "Yard"), rng)
	Site.zone(level, NAME, YARD + Vector2.ONE * 14.0, 30.0)
	Site.spider(level, START)


## A stretch of curtain wall from [param from] to [param to] — two points along its
## inside face — with the battlements on its outer edge.
static func _stretch(walls: Node3D, part_name: String, from: Vector3, to: Vector3,
		out: Vector3) -> void:
	var run := to - from
	var length := run.length()
	if length < 0.5:
		return
	var along := run / length
	var turn := Basis(along, Vector3.UP, along.cross(Vector3.UP))
	if (turn * Vector3.BACK).dot(out) > 0.0:
		turn = Basis(-along, Vector3.UP, -along.cross(Vector3.UP))
	var middle := (from + to) * 0.5 + out * WALL.x * 0.5
	KitBlock.make(walls, part_name, "wall", Vector3(length, WALL.y, WALL.x), Transform3D(turn, middle))
	# Battlements: a merlon every two and a half metres along the outer edge.
	var count := int(floor(length / 2.5))
	for i in count:
		var at := from + along * (length * (float(i) + 0.5) / float(count)) + out * (WALL.x - 0.3)
		KitBlock.make(walls, "%sMerlon%d" % [part_name, i + 1], "wall", Vector3(1.2, 1.4, 0.6),
			Transform3D(turn, at + Vector3.UP * WALL.y))


## The four curtain walls, broken for the gatehouse in the south one and the breach
## in the west.
static func _curtain(walls: Node3D, rng: RandomNumberGenerator) -> void:
	var x := YARD.x
	var z := YARD.y
	_stretch(walls, "North", Vector3(-x, 0.0, -z), Vector3(x, 0.0, -z), Vector3.FORWARD)
	_stretch(walls, "East", Vector3(x, 0.0, -z), Vector3(x, 0.0, z), Vector3.RIGHT)
	_stretch(walls, "SouthWest", Vector3(-x, 0.0, z), Vector3(-GATE - 2.5, 0.0, z), Vector3.BACK)
	_stretch(walls, "SouthEast", Vector3(GATE + 2.5, 0.0, z), Vector3(x, 0.0, z), Vector3.BACK)
	_stretch(walls, "WestNorth", Vector3(-x, 0.0, -z), Vector3(-x, 0.0, BREACH.x), Vector3.LEFT)
	_stretch(walls, "WestSouth", Vector3(-x, 0.0, BREACH.y), Vector3(-x, 0.0, z), Vector3.LEFT)
	# What is left in the breach: a stump of wall, and the rest in a slope both sides.
	var middle := Vector3(-x - WALL.x * 0.5, 0.0, (BREACH.x + BREACH.y) * 0.5)
	KitBlock.make(walls, "BreachStump", "wall", Vector3(BREACH.y - BREACH.x, 2.0, WALL.x),
		WorldKit.at(middle, 90.0))
	for side in [-1.0, 1.0]:
		KitBlock.make(walls, "BreachSlope%s" % ("In" if side > 0.0 else "Out"), "ramp",
			Vector3(BREACH.y - BREACH.x, 2.0, 4.0),
			Transform3D(Basis(Vector3.UP, PI * 0.5 * side), middle + Vector3(side * (WALL.x * 0.5 + 2.0), 0.0, 0.0)))
		Site.rubble(walls, rng, middle + Vector3(side * 5.0, 0.0, 0.0), 3.5, 10, 1.8)


## A round tower at each corner. Two still have their conical roofs, ringed with
## battlements; two broke off short and lie in a heap at their feet.
static func _towers(towers: Node3D, rng: RandomNumberGenerator) -> void:
	var corners := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	var names := ["NorthWest", "NorthEast", "SouthEast", "SouthWest"]
	for i in corners.size():
		var corner: Vector2 = corners[i]
		var at := Vector3(corner.x * (YARD.x + WALL.x * 0.5), 0.0, corner.y * (YARD.y + WALL.x * 0.5))
		var whole := i % 2 == 0
		var height := TOWER.y if whole else rng.randf_range(7.0, 10.0)
		KitBlock.make(towers, "%sTower" % names[i], "cylinder3", Vector3(TOWER.x, height, TOWER.x),
			WorldKit.at(at))
		if not whole:
			Site.rubble(towers, rng, at + Vector3(corner.x, 0.0, corner.y) * 6.0, 4.5, 14, 2.2)
			continue
		for k in 10:
			var bearing := TAU * float(k) / 10.0
			var rim := at + Vector3(cos(bearing), 0.0, sin(bearing)) * (TOWER.x * 0.5 - 0.4)
			KitBlock.make(towers, "%sMerlon%d" % [names[i], k + 1], "wall", Vector3(1.0, 1.4, 0.6),
				Transform3D(Basis(Vector3.UP, -bearing + PI * 0.5), rim + Vector3.UP * height))
		KitBlock.make(towers, "%sRoof" % names[i], "cone4", Vector3(TOWER.x - 1.6, 6.0, TOWER.x - 1.6),
			WorldKit.at(at + Vector3.UP * height))


## The gatehouse: two towers standing out from the south wall either side of the
## way in, an arch over the way, and the portcullis stuck partway down in it.
static func _gatehouse(gatehouse: Node3D) -> void:
	var z := YARD.y
	for side in [-1.0, 1.0]:
		KitBlock.make(gatehouse, "%sTower" % ("West" if side < 0.0 else "East"), "wall",
			Vector3(5.0, WALL.y + 4.0, 8.0), WorldKit.at(Vector3(side * (GATE + 2.5), 0.0, z + 3.0)))
	KitBlock.make(gatehouse, "Arch", "wall door", Vector3(GATE * 2.0, WALL.y + 2.0, WALL.x),
		WorldKit.at(Vector3(0.0, 0.0, z + WALL.x * 0.5)))
	KitBlock.make(gatehouse, "Portcullis", "ladder1", Vector3(GATE, 4.0, 0.3),
		WorldKit.at(Vector3(0.0, 3.0, z + WALL.x * 0.5)))


## The keep: three storeys of walls round a hollow, a door on the yard side, what is
## left of its floors, and its south-west corner fallen away.
static func _keep(keep: Node3D, rng: RandomNumberGenerator) -> void:
	var west := KEEP_CORNER.x
	var north := KEEP_CORNER.y
	var east := west + KEEP
	var south := north + KEEP
	var half := KEEP * 0.5
	# Each face is two halves a storey, so the fallen corner can take only its own.
	var faces := {
		"North": [Vector3(west + half * 0.5, 0.0, north + 0.5), 0.0, false],
		"North2": [Vector3(east - half * 0.5, 0.0, north + 0.5), 0.0, false],
		"East": [Vector3(east - 0.5, 0.0, north + half * 0.5), 90.0, false],
		"East2": [Vector3(east - 0.5, 0.0, south - half * 0.5), 90.0, false],
		"South": [Vector3(west + half * 0.5, 0.0, south - 0.5), 0.0, true],
		"South2": [Vector3(east - half * 0.5, 0.0, south - 0.5), 0.0, false],
		"West": [Vector3(west + 0.5, 0.0, north + half * 0.5), 90.0, false],
		"West2": [Vector3(west + 0.5, 0.0, south - half * 0.5), 90.0, true],
	}
	for face in faces:
		var place: Array = faces[face]
		var corner: bool = place[2]
		for storey in KEEP_STOREYS:
			# The fallen corner keeps only its ground storey, broken short.
			if corner and storey > 0:
				break
			var height := KEEP_STOREY if not (corner and storey == 0) else rng.randf_range(2.0, 4.0)
			var look := "wall"
			if storey > 0:
				look = "wall window1"
			elif face == "West":
				look = "wall door"
			KitBlock.make(keep, "%s%d" % [face, storey + 1], look, Vector3(half, height, 1.0),
				WorldKit.at((place[0] as Vector3) + Vector3.UP * KEEP_STOREY * storey, place[1]))
	# The floors that are left: the north half of each, broken off ragged.
	for storey in range(1, KEEP_STOREYS):
		KitBlock.make(keep, "Floor%d" % storey, "wall", Vector3(KEEP - 2.0, 0.6, half - 1.0 + storey),
			WorldKit.at(Vector3((west + east) * 0.5, KEEP_STOREY * storey - 0.6,
				north + 1.0 + (half - 1.0 + storey) * 0.5)))
	Site.rubble(keep, rng, Vector3(west - 2.0, 0.0, south + 2.0), 4.0, 12, 2.0)


## What is left in the yard: a well, stairs up to the wall-walk on the west and east
## walls, and crates and barrels against the walls.
static func _yard(yard: Node3D, rng: RandomNumberGenerator) -> void:
	KitBlock.make(yard, "Well", "cube4", Vector3(3.0, 1.2, 3.0), WorldKit.at(Vector3(-6.0, 0.0, 2.0)))
	# A flight up each of two walls, rising towards the wall it stands against.
	KitBlock.make(yard, "WestStairs", "stairs", Vector3(3.0, WALL.y, WALL.y),
		Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-YARD.x + WALL.y * 0.5, 0.0, -10.0)))
	KitBlock.make(yard, "EastStairs", "stairs", Vector3(3.0, WALL.y, WALL.y),
		Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(YARD.x - WALL.y * 0.5, 0.0, 10.0)))
	for spot in [Vector3(-19.0, 0.0, 15.5), Vector3(-17.5, 0.0, 16.0), Vector3(19.5, 0.0, -3.0),
			Vector3(19.0, 0.0, -0.8), Vector3(-19.5, 0.0, -15.0)]:
		Kit.place(yard, "box", Transform3D(Basis(Vector3.UP, rng.randf_range(-0.4, 0.4)), spot),
			"Crate%d" % yard.get_child_count())
	for spot in [Vector3(-15.0, 0.0, 16.5), Vector3(-14.0, 0.0, 15.2), Vector3(20.0, 0.0, 2.0),
			Vector3(2.0, 0.0, -16.5), Vector3(3.4, 0.0, -16.0)]:
		KitBlock.make(yard, "Barrel%d" % yard.get_child_count(), "cylinder1", Vector3(1.2, 1.5, 1.2),
			WorldKit.at(spot))
	for spot in [Vector3(-10.0, 0.0, -6.0), Vector3(8.0, 0.0, 9.0), Vector3(14.0, 0.0, 4.0)]:
		Site.rubble(yard, rng, spot, 1.5, 4, 1.2)
