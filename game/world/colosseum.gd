class_name Colosseum
extends RefCounted

## Where the game starts: an arena built from the kit in `Pieces/`.
##
## A square of sand thirty-six metres across, walled four high, with a way out in
## the middle of each side. Behind the wall the stands go up in three tiers, four
## metres a tier, to a rim of open windows twelve metres up. Each way out is a gate
## in the arena wall and a cut through the stands behind it, ending at a shut door
## in the outside wall — four ways to somewhere that is not built yet.
##
## Everything is a piece of the kit, so everything is solid: the spider can climb
## the wall, string silk between the columns along it, walk the tiers and look out
## over the rim. The tiers themselves are [KitBlock]s, the kit's wall stretched to
## the size of a tier, so the bulk is a few nodes and still takes the kit's look.
##
## This is the generator of record. `tools/bake_level.gd` runs it and saves what it
## makes to `game/world/colosseum.tscn`, which is what the game opens and what the
## editor edits; run the bake again and anything moved by hand is lost.

const SCENE := "res://game/world/colosseum.tscn"

## Half the width of the sand: from the middle to the face of the arena wall.
const ARENA := 18.0

## How deep each tier of the stands is, and how much higher than the one before.
const TIER := 4.0
const TIERS := 3

## Half the width of the way out through the stands on each side.
const WAY := 2.0

## From the middle to the outside of the stands.
const RIM := ARENA + TIER * TIERS

## How far out the ground goes from the middle, every way: far enough that the
## haze has it before its edge shows.
const GROUND := 1000.0

## Where the spider starts: on the sand, back from the south gate, facing in.
const START := Vector3(0.0, 0.8, 12.0)

## How far along each side the aisles climb the stands, either side of the middle.
const AISLE := 12.0

## How far along each side the columns stand in front of the arena wall.
const COLUMNS: Array[float] = [6.0, 10.0, 14.0]

## The four sides, by the way out of the arena each one faces.
const SIDES := {
	"North": Vector3(0.0, 0.0, -1.0),
	"East": Vector3(1.0, 0.0, 0.0),
	"South": Vector3(0.0, 0.0, 1.0),
	"West": Vector3(-1.0, 0.0, 0.0),
}


## Builds the whole place under [param level]: sky, ground, arena, stands, and the
## spider, the HUD and somewhere for webs to go.
static func build(level: Node3D) -> void:
	_sky(level)
	_ground(level)
	var arena := WorldKit.group(level, "Arena")
	_sand(arena)
	_columns(arena)
	var stands := WorldKit.group(level, "Stands")
	_tiers(stands)
	_aisles(stands)
	_ways(WorldKit.group(level, "Ways"))
	_rim(WorldKit.group(level, "Rim"))
	_zone(level)
	_spider(level)


# --- the frame of a side ---------------------------------------------------

## Where a point on the side facing [param facing] is — [param along] it, [param out]
## from the middle and [param up] off the ground — turned so that a piece put there
## runs along the side with its back to the outside. A piece's own -Z is outward.
static func frame(facing: Vector3, along: float, out: float, up: float) -> Transform3D:
	var turn := Basis(Vector3.UP, atan2(-facing.x, -facing.z))
	var side := turn * Vector3.RIGHT
	return Transform3D(turn, facing * out + side * along + Vector3.UP * up)


# --- sky and ground --------------------------------------------------------

## A clear afternoon: the sun high enough to light the sand and low enough that
## the arena wall throws a shadow across it.
static func _sky(level: Node3D) -> void:
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = Color(0.36, 0.52, 0.76)
	sky.sky_horizon_color = Color(0.72, 0.77, 0.82)
	# Below the horizon the sky is the colour of grass seen through haze, so the
	# ground meets it rather than stopping at an edge.
	sky.ground_bottom_color = Color(0.48, 0.58, 0.44)
	sky.ground_horizon_color = Color(0.64, 0.71, 0.66)
	sky.sun_angle_max = 18.0
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.sky.sky_material = sky
	# The kit is pure white, and pure white under a full sun and a full sky shows no
	# shading at all: every face comes out the same. So the light is held down, and
	# the shade between faces is what shows the shape.
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.62, 0.68, 0.78)
	environment.ambient_light_energy = 0.32
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.85
	environment.ssao_enabled = true
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.66, 0.72, 0.8)
	environment.fog_density = 0.002
	environment.fog_sky_affect = 0.1
	var world := WorldEnvironment.new()
	world.name = "Sky"
	world.environment = environment
	level.add_child(world)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.93, 0.82)
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 140.0
	var from := Vector3(-60.0, 90.0, 45.0)
	sun.transform = Transform3D(Basis.looking_at(-from, Vector3.UP), from)
	level.add_child(sun)


## Grass all the way out, under everything.
static func _ground(level: Node3D) -> void:
	var ground := WorldKit.body(level, "Ground")
	WorldKit.box(ground, "Grass", Vector3(GROUND * 2.0, 1.0, GROUND * 2.0),
		WorldKit.at(Vector3(0.0, -0.5, 0.0)), "grass")


# --- the arena -------------------------------------------------------------

## The sand, a hair above the grass, wall to wall.
static func _sand(arena: Node3D) -> void:
	var floor_body := WorldKit.body(arena, "Floor")
	WorldKit.box(floor_body, "Sand", Vector3(ARENA * 2.0, 0.1, ARENA * 2.0),
		WorldKit.at(Vector3(0.0, -0.04, 0.0)), "straw")


## Columns along the foot of the arena wall, four metres apart, and one in each
## corner: something to climb, and posts to string silk between.
static func _columns(arena: Node3D) -> void:
	var holder := WorldKit.group(arena, "Columns")
	for side in SIDES:
		var facing: Vector3 = SIDES[side]
		for along in COLUMNS:
			for sign in [-1.0, 1.0]:
				Kit.place(holder, "pillar3", frame(facing, sign * along, ARENA - 0.5, 0.0),
					"%sColumn%s" % [side, _toward(facing, sign)])
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var at := Vector3(corner.x, 0.0, corner.y) * (ARENA - 0.5)
		Kit.place(holder, "pillar3", WorldKit.at(at), "%sColumn" % _corner_name(corner))


# --- the stands ------------------------------------------------------------

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
				var block := KitBlock.new()
				block.name = "%sTier%d%s" % [side, k + 1, _toward(facing, sign)]
				block.size = Vector3(length, height, TIER)
				block.transform = frame(facing, sign * (WAY + length * 0.5), (inner + outer) * 0.5, 0.0)
				stands.add_child(block, true)


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
				Kit.place(holder, "stairs", frame(facing, along, foot + 1.0, floor_height),
					"%sStep%dLow" % [tag, step + 1])
				Kit.place(holder, "cube", frame(facing, along, foot + 3.0, floor_height),
					"%sStep%dBlock" % [tag, step + 1])
				Kit.place(holder, "stairs", frame(facing, along, foot + 3.0, floor_height + 2.0),
					"%sStep%dHigh" % [tag, step + 1])


## Each way out: a gate in the arena wall, the cut through the stands behind it, and
## a shut door at the far end with the outside wall built up over it to the rim.
static func _ways(ways: Node3D) -> void:
	for side in SIDES:
		var facing: Vector3 = SIDES[side]
		Kit.place(ways, "wall door", frame(facing, 0.0, ARENA + 0.5, 0.0), "%sGate" % side)
		Kit.place(ways, "wall door1", frame(facing, 0.0, RIM - 0.5, 0.0), "%sDoor" % side)
		var over := KitBlock.new()
		over.name = "%sOverDoor" % side
		over.size = Vector3(WAY * 2.0, TIER * TIERS - 4.0, 1.0)
		over.transform = frame(facing, 0.0, RIM - 0.5, 4.0)
		ways.add_child(over, true)


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
			Kit.place(rim, "wall window1", frame(facing, along, RIM - 0.5, top),
				"%sWindow%d" % [side, i + 1])
			along += 4.0
			i += 1
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		# The piece's own corner is its -X, +Z one; turned to face the corner it fills.
		var turn := Basis(Vector3.UP, atan2(corner.x, corner.y) + PI * 0.25)
		var at := Vector3(corner.x * corner_at, top, corner.y * corner_at)
		Kit.place(rim, "wall corner", Transform3D(turn, at), "%sCorner" % _corner_name(corner))


# --- what is not geometry --------------------------------------------------

## The place's name, for the HUD to show on the way in.
static func _zone(level: Node3D) -> void:
	Zone.make(level, "The Colosseum", Vector3(-RIM, -2.0, -RIM), Vector3(RIM, 28.0, RIM),
		Vector2.ZERO)


## The spider, held at one size with every spell open, the HUD, and a home for its
## webs.
static func _spider(level: Node3D) -> void:
	var webs := Node3D.new()
	webs.name = "Webs"
	level.add_child(webs)
	var spider := (load("res://game/player/spider.tscn") as PackedScene).instantiate() as SpiderPlayer
	spider.name = "Player"
	spider.position = START
	spider.grows_by_eating = false
	spider.start_stage = 2
	spider.evolves_by_eating = false
	spider.all_spells_open = true
	level.add_child(spider)
	var hud := (load("res://game/ui/hud.tscn") as PackedScene).instantiate()
	hud.name = "HUD"
	level.add_child(hud)


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
