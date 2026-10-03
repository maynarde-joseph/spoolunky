class_name Watchtower
extends RefCounted

## A watchtower on a hill, high and pale in the wind, with its top broken off.
##
## The hill is three terraces stepped up to nine metres, stairs up the south face of
## each, with low walls that have mostly fallen along their edges and a ring of
## columns round the second, some of them broken. On the top terrace stands the
## tower: a hollow round of stone ten metres across and thirty-six high, a door at
## its foot and windows all the way up, open to the sky where its top came off —
## ragged, higher on one side than the other. Inside, what is left of each floor
## clings to one side or the other, so the way up is from ledge to ledge.
##
## Two thirds of the way up a stone bridge ran north from the tower to a lone pillar
## on the plain. It broke in the middle, and the gap is the kind silk was made for.
##
## This is the generator of record; `tools/bake_level.gd` saves what it makes to
## [constant SCENE].

const SCENE := "res://game/world/watchtower.tscn"

## What the HUD calls the place on the way in.
const NAME := "The Watchtower"

## The terraces: half the width of each, and how high each one's top is.
const TERRACES: Array[Vector2] = [Vector2(22.0, 3.0), Vector2(16.0, 6.0), Vector2(11.0, 9.0)]

## The tower: its radius to the outside of the wall, how thick the wall is, how many
## segments round it is built in, how tall each storey is and how many it had.
const RADIUS := 5.0
const THICK := 1.0
const SEGMENTS := 12
const STOREY := 6.0
const STOREYS := 6

## The storey the bridge left from, how far north the pillar it reached stands, and
## the gap in the middle of it.
const BRIDGE_STOREY := 4
const PILLAR := -30.0
const BRIDGE_GAP := 7.0

## Where the spider starts: on the grass south of the hill, facing it.
const START := Vector3(0.0, 0.8, 30.0)


static func build(level: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 905
	Site.sky(level, "windy")
	Site.ground(level)
	_terraces(WorldKit.group(level, "Hill"), rng)
	_tower(WorldKit.group(level, "Tower"), rng)
	_bridge(WorldKit.group(level, "Bridge"), rng)
	Site.zone(level, NAME, Vector2(40.0, 45.0), 60.0)
	Site.spider(level, START)


## The top of the hill, where the tower stands.
static func base() -> float:
	return TERRACES[TERRACES.size() - 1].y


## Three terraces, each a stair up its south face, with what is left of the walls
## along their edges and a ring of columns round the middle one.
static func _terraces(hill: Node3D, rng: RandomNumberGenerator) -> void:
	var below := 0.0
	for k in TERRACES.size():
		var half := TERRACES[k].x
		var top := TERRACES[k].y
		KitBlock.make(hill, "Terrace%d" % (k + 1), "wall", Vector3(half * 2.0, top, half * 2.0),
			WorldKit.at(Vector3.ZERO))
		KitBlock.make(hill, "Stairs%d" % (k + 1), "stairs", Vector3(4.0, top - below, top - below),
			WorldKit.at(Vector3(0.0, below, half + (top - below) * 0.5)))
		# What is left of a low wall round the edge: short stretches with gaps.
		for side in 4:
			var turn := Basis(Vector3.UP, PI * 0.5 * side)
			var x := -half + 1.0
			while x < half - 1.0:
				var length := rng.randf_range(2.0, 6.0)
				var stand := rng.randf() < 0.55 and absf(x + length * 0.5) > 3.0
				if stand:
					var at := turn * Vector3(x + length * 0.5, 0.0, half - 0.5) + Vector3.UP * top
					KitBlock.make(hill, "Wall%d_%d" % [k + 1, hill.get_child_count()], "wall",
						Vector3(length, rng.randf_range(0.6, 2.2), 0.8), Transform3D(turn, at))
				x += length + rng.randf_range(1.0, 3.0)
		below = top
	# A ring of columns round the middle terrace, some broken short.
	var ring := TERRACES[1].x - 2.5
	for i in 16:
		var bearing := TAU * float(i) / 16.0
		var at := Vector3(cos(bearing) * ring, TERRACES[1].y, sin(bearing) * ring)
		if absf(at.x) < 3.0 and at.z > 0.0:
			continue
		var height := 6.0 if rng.randf() < 0.55 else rng.randf_range(1.5, 4.0)
		KitBlock.make(hill, "Column%d" % (i + 1), "pillar3", Vector3(1.0, height, 1.0), WorldKit.at(at))


## The tower: a round wall a storey at a time, a door at the foot, windows on every
## other storey, ragged at the top; and inside, what is left of each floor.
static func _tower(tower: Node3D, rng: RandomNumberGenerator) -> void:
	var foot := base()
	var segments := Site.oval(RADIUS - THICK * 0.5, RADIUS - THICK * 0.5, SEGMENTS)
	for i in SEGMENTS:
		var segment: Dictionary = segments[i]
		# The broken top: whole on the west, down to four storeys on the east.
		var bearing: float = segment["bearing"]
		var east := (cos(deg_to_rad(bearing)) + 1.0) * 0.5
		var storeys := clampi(int(round(STOREYS - east * 2.0 + rng.randf_range(-0.6, 0.6))), 4, STOREYS)
		var length: float = segment["length"] + THICK * tan(PI / SEGMENTS) + 0.05
		for storey in storeys:
			var look := "wall window1" if storey % 2 == 1 else "wall"
			# The door faces south, at the top of the stairs.
			if storey == 0 and absf(bearing - 90.0) < 1.0:
				look = "wall door"
			KitBlock.make(tower, "Wall%d_%d" % [i + 1, storey + 1], look, Vector3(length, STOREY, THICK),
				Transform3D(segment["basis"], (segment["middle"] as Vector3) + Vector3.UP * (foot + STOREY * storey)))
	# Each floor is half a floor now, on alternate sides, broken off ragged — its
	# corners tucked into the round of the wall.
	var inner := RADIUS - THICK
	for storey in range(1, STOREYS):
		var side := 1.0 if storey % 2 == 1 else -1.0
		var depth := 3.0 - rng.randf_range(0.0, 0.8)
		KitBlock.make(tower, "Floor%d" % storey, "wall", Vector3(inner * 1.4, 0.5, depth),
			WorldKit.at(Vector3(0.0, foot + STOREY * storey - 0.5, side * (inner - depth * 0.5))))
	Site.rubble(tower, rng, Vector3(RADIUS + 4.0, foot, 2.0), 3.0, 8, 1.8)


## The bridge north from the tower to the pillar, broken in the middle, and the pillar
## itself on the plain.
static func _bridge(bridge: Node3D, rng: RandomNumberGenerator) -> void:
	var height := base() + STOREY * BRIDGE_STOREY
	var from := -RADIUS
	var to := PILLAR + 2.5
	var half := (from - to - BRIDGE_GAP) * 0.5
	KitBlock.make(bridge, "Pillar", "cylinder3", Vector3(5.0, height, 5.0), WorldKit.at(Vector3(0.0, 0.0, PILLAR)))
	KitBlock.make(bridge, "TowerEnd", "wall", Vector3(2.5, 0.6, half),
		WorldKit.at(Vector3(0.0, height - 0.6, from - half * 0.5)))
	KitBlock.make(bridge, "PillarEnd", "wall", Vector3(2.5, 0.6, half),
		WorldKit.at(Vector3(0.0, height - 0.6, to + half * 0.5)))
	# A low parapet along both sides of what is left of it.
	for middle in [from - half * 0.5, to + half * 0.5]:
		for side in [-1.0, 1.0]:
			KitBlock.make(bridge, "Parapet%d" % bridge.get_child_count(), "wall",
				Vector3(0.3, 0.8, half), WorldKit.at(Vector3(side * 1.1, height, middle)))
	Site.rubble(bridge, rng, Vector3(0.0, 0.0, (from + to) * 0.5), 3.0, 8, 1.6)
