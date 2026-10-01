class_name HollowWood
extends Node3D

## The Hollow Wood: a stretch of old forest floor with ruins standing in it.
##
## Out in the open, under the sky, with somewhere to go in every direction: the
## wood is the world, and the structures are places in it you walk up to, scout
## from outside and go into. Everything in it is hostile, the spider is a Huntsman
## the whole way through, and the shape is still a souls-like's — shrines to come
## back to, a lair kept by a miniboss, a main boss that walks a beat, and doors
## you open from the inside so that the way in is short next time.
##
##     the Watchtower .......... north, on its hill: four floors, open at the top
##     the Barrow .............. north-east, dug into a mound: the Rat King's lair
##     the Chapel .............. west: a roof half fallen in, shelves, a gallery
##     the Ruined Court ........ the middle: paving, arches, a dry fountain
##     the Graveyard ........... east: a walled yard of stones, and a crypt
##     the Mire ................ south-west: a sunken bog, frogs in the reeds
##     the Shrine Clearing ..... south: a ring of standing stones, where you wake
##
## Between them, the wood: ferns, toadstools, fallen leaves and the old trees,
## with paths worn from the clearing to everything. The Hollow Wyrm goes the rounds
## of all of it in the open air. The chapel's side door and the watchtower's door
## are shut, and open from the inside — the tower's from the bottom, once you
## have climbed its outside and come down through it.
##
## Everything is to the scale of the [Props], a metre about fourteen units, the
## same as the hunting ground, and built the same way: [WorldKit] solids painted
## from the [Palette], the ground one height map. Baked into its scene and taken
## off the node; this is the generator of record:
##
##     godot --headless --path . --script res://tools/bake_level.gd -- hollow_wood --force

# --- the ground ---------------------------------------------------------------

## The ground: a square this many cells across, each this wide — a power of two
## cells, so that it collides as one height map.
const CELLS := 128
const CELL := 3.0

## Where the hills round the wood start rising, and how high they get.
const RIM_FROM := 150.0
const RIM_TO := 186.0
const RIM_HEIGHT := 46.0

## Thickness of the walls of everything built.
const W := 1.5

# --- the places, by their middles in (x, z) -----------------------------------

const CLEARING := Vector2(0.0, 130.0)
const CLEARING_REACH := 30.0

## The court: a square of old paving, and the height it was laid at.
const COURT := Vector2(0.0, 20.0)
const COURT_HALF := 40.0
const LEVEL := 1.0

## The graveyard's walled yard, corner to corner, and the crypt in it.
const YARD_LO := Vector2(90.0, 0.0)
const YARD_HI := Vector2(150.0, 60.0)
const CRYPT_LO := Vector3(130.0, LEVEL, 8.0)
const CRYPT_HI := Vector3(146.0, LEVEL + 10.0, 20.0)

## The chapel: the space inside its walls, and how high they stand.
const CHAPEL_LO := Vector3(-140.0, LEVEL, -10.0)
const CHAPEL_HI := Vector3(-100.0, LEVEL + 18.0, 50.0)

## The watchtower's hill, and the tower on top of it: the room inside its walls,
## and its floors by the height of each one's top.
const HILL := Vector2(-20.0, -120.0)
const HILL_TOP := 12.0
const TOWER_LO := Vector3(-30.0, HILL_TOP, -130.0)
const TOWER_HI := Vector3(-10.0, HILL_TOP + 60.0, -110.0)
const TOWER_FLOORS := [HILL_TOP + 16.0, HILL_TOP + 32.0, HILL_TOP + 48.0]

## The barrow: the hall inside the mound.
const BARROW_LO := Vector3(94.0, 2.0, -116.0)
const BARROW_HI := Vector3(126.0, 16.0, -84.0)

## The mire: a sunken bog, how far across and how far down.
const MIRE := Vector2(-110.0, 115.0)
const MIRE_REACH := 38.0
const MIRE_DEPTH := 4.0

## The paths worn between the places, as the points each runs through.
const PATHS := [
	[Vector2(0.0, 130.0), Vector2(4.0, 100.0), Vector2(-2.0, 60.0)],
	[Vector2(40.0, 28.0), Vector2(66.0, 32.0), Vector2(90.0, 30.0)],
	[Vector2(-40.0, 22.0), Vector2(-70.0, 18.0), Vector2(-100.0, 20.0)],
	[Vector2(-6.0, -20.0), Vector2(-12.0, -60.0), Vector2(-20.0, -108.0)],
	[Vector2(30.0, -20.0), Vector2(70.0, -45.0), Vector2(110.0, -70.0)],
	[Vector2(-20.0, 120.0), Vector2(-60.0, 118.0), Vector2(-85.0, 115.0)],
	[Vector2(-128.0, 52.0), Vector2(-90.0, 90.0), Vector2(-30.0, 125.0)],
]
const PATH_WIDE := 4.0

# --- what lives where -----------------------------------------------------------

## The hostile marks: species, and where in (x, z), and how far over the ground —
## walkers a little over it, to drop onto whatever the ground really is there, and
## fliers higher.
const HOSTILES := [
	["blade_rat", Vector2(-22.0, 2.0), 1.5],
	["blade_rat", Vector2(24.0, 44.0), 1.5],
	["blade_rat", Vector2(18.0, -6.0), 1.5],
	["charger_beetle", Vector2(-10.0, 40.0), 1.5],
	["charger_beetle", Vector2(34.0, -12.0), 1.5],

	["tongue_frog", Vector2(104.0, 40.0), 1.5],
	["tongue_frog", Vector2(122.0, 10.0), 1.5],
	["drill_mosquito", Vector2(100.0, 14.0), 3.0],
	["drill_mosquito", Vector2(138.0, 46.0), 3.0],
	["blade_rat", Vector2(116.0, 50.0), 1.5],

	["screech_bat", Vector2(-124.0, 6.0), 6.0],
	["screech_bat", Vector2(-116.0, 34.0), 6.0],
	["spitter_wasp", Vector2(-136.0, 20.0), 12.0],
	["spitter_wasp", Vector2(-106.0, -4.0), 8.0],
	["charger_beetle", Vector2(-120.0, 44.0), 1.5],

	["drill_mosquito", Vector2(-20.0, -116.0), 6.0],
	["screech_bat", Vector2(-16.0, -126.0), 22.0],
	["spitter_wasp", Vector2(-25.0, -114.0), 37.0],
	["screech_bat", Vector2(-14.0, -124.0), 40.0],

	["blade_rat", Vector2(104.0, -77.0), 1.5],
	["blade_rat", Vector2(116.0, -79.0), 1.5],

	["tongue_frog", Vector2(-120.0, 108.0), 1.5],
	["tongue_frog", Vector2(-96.0, 124.0), 1.5],
	["drill_mosquito", Vector2(-110.0, 96.0), 3.0],
	["drill_mosquito", Vector2(-126.0, 130.0), 3.0],

	["charger_beetle", Vector2(-60.0, -40.0), 1.5],
	["spitter_wasp", Vector2(60.0, 80.0), 4.0],
	["blade_rat", Vector2(60.0, -60.0), 1.5],
]

## The wyrm's beat: a loop round the whole wood in the open air, each point in
## sight of the next, from the court out past the graveyard and the barrow, round
## under the watchtower's hill and back by the chapel. Heights over the ground.
const WYRM_BEAT := [
	[Vector2(0.0, 20.0), 18.0],
	[Vector2(60.0, 26.0), 16.0],
	[Vector2(120.0, 34.0), 14.0],
	[Vector2(118.0, -40.0), 16.0],
	[Vector2(60.0, -82.0), 18.0],
	[Vector2(0.0, -78.0), 20.0],
	[Vector2(-62.0, -40.0), 16.0],
	[Vector2(-72.0, 18.0), 14.0],
]

## Colours of the ground.
const FOREST := Color(0.25, 0.3, 0.17)
const LITTER := Color(0.36, 0.27, 0.17)
const PATH := Color(0.5, 0.43, 0.32)
const PAVING := Color(0.55, 0.53, 0.48)
const GRAVE_GRASS := Color(0.3, 0.38, 0.22)
const BOG := Color(0.2, 0.22, 0.14)
const ROCK := Color(0.44, 0.43, 0.41)

const COURT_LAMP := Color(1.0, 0.8, 0.55)
const GRAVES_LAMP := Color(0.5, 0.95, 0.8)
const CHAPEL_LAMP := Color(1.0, 0.72, 0.42)
const TOWER_LAMP := Color(0.78, 0.6, 1.0)
const BARROW_LAMP := Color(1.0, 0.5, 0.3)

var _broad: FastNoiseLite
var _fine: FastNoiseLite


func _ready() -> void:
	build()


func build() -> void:
	_noise()
	_sky()
	_ground()
	_clearing()
	_court()
	_graveyard()
	_chapel()
	_watchtower()
	_barrow()
	_mire()
	_wood()
	_places()
	_shrines()
	_gates()
	_lair()
	_hostiles()
	_wyrm()
	_keeper()
	_place_the_spider()


# --- the shape of the ground ------------------------------------------------------

## How high the ground is at (x, z): gently rolling, with the hills round the edge,
## the watchtower's hill, the barrow's mound, the mire sunk into it, and level
## wherever something was built.
func ground_at(x: float, z: float) -> float:
	if _broad == null:
		_noise()
	var at := Vector2(x, z)
	var height := 1.6 * _broad.get_noise_2d(x, z) + 0.6 * _fine.get_noise_2d(x, z)
	var edge := maxf(absf(x), absf(z))
	height += RIM_HEIGHT * smoothstep(RIM_FROM, RIM_TO, edge) \
		* (0.8 + 0.4 * _broad.get_noise_2d(x * 0.5 + 100.0, z * 0.5))
	height -= MIRE_DEPTH * smoothstep(MIRE_REACH, MIRE_REACH * 0.4, at.distance_to(MIRE))
	# The watchtower's hill, flat on top where the tower stands.
	height = maxf(height, HILL_TOP * smoothstep(52.0, 20.0, at.distance_to(HILL)))
	height = _level(height, at, _rect(TOWER_LO, TOWER_HI), HILL_TOP, 6.0)
	# The barrow's mound: up to the roof round the back and sides, cut away in front
	# for the way in, and level inside.
	var barrow := _rect(BARROW_LO, BARROW_HI)
	var middle := barrow.get_center()
	var mound := (BARROW_HI.y + 1.0) * smoothstep(58.0, 26.0, at.distance_to(middle))
	var cutting := smoothstep(12.0, 6.0, absf(x - middle.x)) \
		* smoothstep(BARROW_HI.z - 4.0, BARROW_HI.z + 2.0, z)
	height = maxf(height, mound * (1.0 - cutting))
	height = _level(height, at, barrow.grow(W + 0.5), BARROW_LO.y, 0.0)
	# Level where things were built.
	height = _level(height, at, Rect2(COURT - Vector2.ONE * COURT_HALF, Vector2.ONE * COURT_HALF
		* 2.0), LEVEL, 10.0)
	height = _level(height, at, Rect2(YARD_LO, YARD_HI - YARD_LO), LEVEL, 10.0)
	height = _level(height, at, _rect(CHAPEL_LO, CHAPEL_HI), LEVEL, 10.0)
	height = lerpf(height, 0.0, smoothstep(CLEARING_REACH + 10.0, CLEARING_REACH,
		at.distance_to(CLEARING)))
	return height


## [param height] brought to [param level] inside [param area], and blended back to
## what it was over [param blend] outside it.
func _level(height: float, at: Vector2, area: Rect2, level: float, blend: float) -> float:
	var out := Vector2(maxf(maxf(area.position.x - at.x, at.x - area.end.x), 0.0),
		maxf(maxf(area.position.y - at.y, at.y - area.end.y), 0.0)).length()
	if blend <= 0.0:
		return level if out <= 0.0 else height
	return lerpf(level, height, smoothstep(0.0, blend, out))


func _rect(lo: Vector3, hi: Vector3) -> Rect2:
	return Rect2(Vector2(lo.x, lo.z), Vector2(hi.x - lo.x, hi.z - lo.z))


## The colour of the ground at [param at], facing [param normal]: forest floor, leaf
## litter, paths worn pale, paving in the court, grass in the yard, the mire dark,
## and rock wherever it is steep or high.
func ground_colour(at: Vector3, normal: Vector3) -> Color:
	var flat := Vector2(at.x, at.z)
	var colour := FOREST.lerp(LITTER, 0.5 + 0.5 * _fine.get_noise_2d(at.x * 0.7, at.z * 0.7))
	colour = colour.lerp(PATH, smoothstep(PATH_WIDE + 1.5, PATH_WIDE * 0.4, _to_path(flat)))
	if _in_square(flat, COURT, COURT_HALF):
		colour = PAVING
	if Rect2(YARD_LO, YARD_HI - YARD_LO).has_point(flat):
		colour = GRAVE_GRASS
	colour = colour.lerp(BOG, smoothstep(MIRE_REACH, MIRE_REACH * 0.6, flat.distance_to(MIRE)))
	colour = colour.lerp(ROCK, smoothstep(0.32, 0.55, 1.0 - normal.y))
	colour = colour.lerp(ROCK, smoothstep(24.0, 40.0, at.y))
	var grain := 1.0 + 0.07 * _fine.get_noise_2d(at.x * 3.0, at.z * 3.0)
	return Color(colour.r * grain, colour.g * grain, colour.b * grain)


## The ground under (x, z), as a point on it.
func on_ground(x: float, z: float, lift := 0.0) -> Vector3:
	return Vector3(x, ground_at(x, z) + lift, z)


func _to_path(at: Vector2) -> float:
	var nearest := INF
	for path in PATHS:
		for i in range(path.size() - 1):
			var a: Vector2 = path[i]
			var b: Vector2 = path[i + 1]
			nearest = minf(nearest, at.distance_to(Geometry2D.get_closest_point_to_segment(at, a, b)))
	return nearest


func _in_square(at: Vector2, middle: Vector2, half: float) -> bool:
	return absf(at.x - middle.x) <= half and absf(at.y - middle.y) <= half


func _noise() -> void:
	_broad = FastNoiseLite.new()
	_broad.seed = 23
	_broad.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_broad.frequency = 0.012
	_fine = FastNoiseLite.new()
	_fine.seed = 29
	_fine.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_fine.frequency = 0.05


# --- sky and light ------------------------------------------------------------------

## Late in a grey day: a low sun through mist, so that the far side of the wood
## sits back and the ruins come up out of it.
func _sky() -> void:
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = Color(0.3, 0.36, 0.46)
	sky.sky_horizon_color = Color(0.66, 0.62, 0.58)
	sky.ground_bottom_color = Color(0.2, 0.22, 0.18)
	sky.ground_horizon_color = Color(0.56, 0.55, 0.5)
	sky.sun_angle_max = 18.0
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.sky.sky_material = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72, 0.74, 0.8)
	environment.ambient_light_energy = 0.45
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.5, 0.54, 0.58)
	environment.fog_density = 0.0016
	environment.fog_sky_affect = 0.2
	var world := WorldEnvironment.new()
	world.name = "Sky"
	world.environment = environment
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.86, 0.7)
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 160.0
	add_child(sun)
	sun.look_at_from_position(Vector3(0.0, 100.0, 0.0), Vector3(-45.0, 0.0, -60.0), Vector3.UP)


## A lamp: an omni light at [param at], in a place's colour.
func _lamp(holder: Node3D, lamp_name: String, at: Vector3, colour: Color, reach := 18.0,
		energy := 1.4) -> OmniLight3D:
	var lamp := OmniLight3D.new()
	lamp.name = lamp_name
	lamp.light_color = colour
	lamp.light_energy = energy
	lamp.omni_range = reach
	lamp.shadow_enabled = false
	holder.add_child(lamp)
	lamp.global_position = at
	return lamp


func _ground() -> void:
	var ground := WorldKit.body(self, "Ground")
	WorldKit.terrain(ground, "Wood", Vector2.ZERO, CELLS, CELL, ground_at, ground_colour)


# --- the clearing ------------------------------------------------------------------

## A ring of standing stones round a dais, with the wood all round. Nothing hostile
## comes in, and it is where you wake.
func _clearing() -> void:
	var clearing := WorldKit.group(self, "ShrineClearing")
	var dais := WorldKit.body(clearing, "Dais")
	WorldKit.cylinder(dais, "Step", 7.0, 0.6, WorldKit.at(on_ground(CLEARING.x, CLEARING.y, 0.1)),
		"ruin_dark", true, -1.0, 20)
	for i in 9:
		var turn := TAU * float(i) / 9.0 + 0.2
		var at := CLEARING + Vector2(cos(turn), sin(turn)) * 22.0
		Props.place(clearing, "standing_stone", Transform3D(Basis(Vector3.UP, -turn
			+ PI * 0.5).scaled(Vector3.ONE * (0.8 + 0.15 * fposmod(float(i) * 0.61, 1.0))),
			on_ground(at.x, at.y, -0.5)))


# --- the court ---------------------------------------------------------------------

## Old paving in a square, broken walls and arches standing on it, columns and a
## dry fountain in the middle: the open ruin the wyrm likes.
func _court() -> void:
	var court := WorldKit.group(self, "RuinedCourt")
	var fountain := WorldKit.body(court, "Fountain",
		Transform3D(Basis.IDENTITY, on_ground(COURT.x, COURT.y)))
	WorldKit.cylinder(fountain, "Rim", 6.0, 1.4, WorldKit.at(Vector3(0.0, 0.7, 0.0)), "ruin",
		true, -1.0, 24)
	WorldKit.cylinder(fountain, "Post", 1.0, 7.0, WorldKit.at(Vector3(0.0, 3.5, 0.0)), "ruin_dark",
		true, -1.0, 12)
	for spot in [Vector3(-26.0, 0.0, -10.0), Vector3(26.0, 0.0, -12.0), Vector3(-28.0, 0.0, 46.0),
			Vector3(28.0, 0.0, 50.0), Vector3(0.0, 0.0, -16.0)]:
		Props.place(court, "flagstones", Transform3D(Basis(Vector3.UP, spot.x * 0.05),
			on_ground(COURT.x + spot.x, COURT.y + spot.z, -0.1)))
	Props.place(court, "ruin_wall", Transform3D(Basis(Vector3.UP, 0.1).scaled(Vector3.ONE * 0.6),
		on_ground(-24.0, 34.0, -0.4)))
	Props.place(court, "ruin_wall", Transform3D(Basis(Vector3.UP, 1.5).scaled(Vector3.ONE * 0.5),
		on_ground(30.0, 18.0, -0.4)))
	Props.place(court, "ruin_arch", Transform3D(Basis(Vector3.UP, 0.0).scaled(Vector3.ONE * 0.6),
		on_ground(0.0, -12.0)))
	Props.place(court, "ruin_arch", Transform3D(Basis(Vector3.UP, PI * 0.5).scaled(Vector3.ONE
		* 0.55), on_ground(-34.0, 12.0)))
	for spot in [Vector2(-14.0, 6.0), Vector2(14.0, 6.0), Vector2(-14.0, 36.0), Vector2(14.0, 36.0)]:
		Props.place(court, "ruin_pillar", Transform3D(Basis(Vector3.UP, spot.x).scaled(Vector3.ONE
			* 0.6), on_ground(COURT.x + spot.x, COURT.y + spot.y - 20.0)))
	Props.place(court, "fallen_pillar", Transform3D(Basis(Vector3.UP, 0.7).scaled(Vector3.ONE * 0.6),
		on_ground(18.0, 48.0)))
	for spot in [Vector2(-8.0, 46.0), Vector2(32.0, -6.0), Vector2(-32.0, 52.0)]:
		Props.place(court, "ruin_block", Transform3D(Basis(Vector3.UP, spot.y).scaled(Vector3.ONE
			* 0.6), on_ground(spot.x, spot.y)))
	for spot in [Vector3(-18.0, 10.0, 0.0), Vector3(18.0, 10.0, 40.0)]:
		_lamp(court, "Brazier", on_ground(spot.x, spot.z, spot.y), COURT_LAMP, 26.0, 1.0)


# --- the graveyard ---------------------------------------------------------------

## A yard of stones inside a low wall, gaps in it to the west and the north, dead
## trees, and a crypt in the far corner with a shrine inside it.
func _graveyard() -> void:
	var yard := WorldKit.group(self, "Graveyard")
	var wall := WorldKit.body(yard, "YardWall")
	var high := 3.0
	var gaps := {
		"west": Vector2(25.0, 35.0), "north": Vector2(115.0, 125.0),
	}
	_yard_wall(wall, Vector3(YARD_LO.x, LEVEL, YARD_LO.y), Vector3(YARD_HI.x, LEVEL, YARD_LO.y),
		high, gaps["north"])
	_yard_wall(wall, Vector3(YARD_LO.x, LEVEL, YARD_HI.y), Vector3(YARD_HI.x, LEVEL, YARD_HI.y),
		high, Vector2.ZERO)
	_yard_wall(wall, Vector3(YARD_LO.x, LEVEL, YARD_LO.y), Vector3(YARD_LO.x, LEVEL, YARD_HI.y),
		high, gaps["west"])
	_yard_wall(wall, Vector3(YARD_HI.x, LEVEL, YARD_LO.y), Vector3(YARD_HI.x, LEVEL, YARD_HI.y),
		high, Vector2.ZERO)
	var stones := WorldKit.body(yard, "Stones")
	var row := 0
	for z in range(6, 58, 7):
		var col := 0
		for x in range(95, 148, 5):
			var at := Vector2(float(x), float(z))
			if absf(at.y - 30.0) < 4.0 or absf(at.x - 120.0) < 3.0:
				continue
			if at.x > CRYPT_LO.x - 4.0 and at.y < CRYPT_HI.z + 4.0:
				continue
			var lean := float((row * 7 + col * 3) % 9) - 4.0
			WorldKit.box(stones, "Stone", Vector3(1.4, 1.7, 0.35),
				WorldKit.at(Vector3(at.x, LEVEL + 0.85, at.y), lean), "stone_dark")
			col += 1
		row += 1
	_room(yard, "Crypt", CRYPT_LO, CRYPT_HI, "rock", "rock_dark", {
		"west": [Rect2(11.0, CRYPT_LO.y, 6.0, 6.0)],
	})
	for tree in [Vector2(96.0, 54.0), Vector2(144.0, 50.0), Vector2(98.0, 6.0)]:
		var foot := Vector3(tree.x, LEVEL, tree.y)
		WorldKit.rod(stones, "DeadTree", foot, foot + Vector3(0.5, 9.0, 0.3), 0.5, "bark", true, 0.2)
		WorldKit.rod(stones, "Bough", foot + Vector3(0.3, 6.0, 0.2), foot + Vector3(3.5, 9.0, 1.0),
			0.25, "bark", true, 0.1)
	for spot in [Vector3(100.0, 7.0, 10.0), Vector3(140.0, 7.0, 50.0), Vector3(105.0, 7.0, 50.0),
			Vector3(138.0, LEVEL + 7.0, 14.0)]:
		_lamp(yard, "Lantern", spot, GRAVES_LAMP, 20.0, 1.2)


## A low wall from [param from] to [param to], with a gap across [param gap] (along
## its length, in world x or z) if there is one.
func _yard_wall(body: StaticBody3D, from: Vector3, to: Vector3, high: float, gap: Vector2) -> void:
	var along_x := absf(to.x - from.x) > absf(to.z - from.z)
	var start := from.x if along_x else from.z
	var end := to.x if along_x else to.z
	var spans: Array[Vector2] = []
	if gap == Vector2.ZERO:
		spans.append(Vector2(start, end))
	else:
		spans.append(Vector2(start, gap.x))
		spans.append(Vector2(gap.y, end))
	for span in spans:
		var long := span.y - span.x
		if long <= 0.01:
			continue
		var middle := (span.x + span.y) * 0.5
		var at := Vector3(middle, from.y + high * 0.5, from.z) if along_x \
			else Vector3(from.x, from.y + high * 0.5, middle)
		var size := Vector3(long, high, 1.0) if along_x else Vector3(1.0, high, long)
		WorldKit.box(body, "Wall", size, WorldKit.at(at), "rock")


# --- the chapel ---------------------------------------------------------------------

## A long hall with its roof fallen in over the south end: tall shelves in aisles,
## a gallery down the west wall with a shrine on it, windows high up, the great
## door to the east and a side door to the south that only opens from inside.
func _chapel() -> void:
	var chapel := WorldKit.group(self, "Chapel")
	_room(chapel, "ChapelWalls", CHAPEL_LO, CHAPEL_HI, "stone_dark", "wood_dark", {
		"east": [Rect2(15.0, CHAPEL_LO.y, 10.0, 10.0), Rect2(-4.0, 10.0, 6.0, 5.0),
			Rect2(36.0, 10.0, 6.0, 5.0)],
		"west": [Rect2(4.0, 12.0, 5.0, 4.0), Rect2(30.0, 12.0, 5.0, 4.0)],
		"south": [Rect2(-125.0, CHAPEL_LO.y, 10.0, 8.0)],
		"north": [Rect2(-126.0, 10.0, 12.0, 6.0)],
	}, ["roof"])
	# What is left of the roof: the north end, and a few beams over the rest.
	var roof := WorldKit.body(chapel, "Roof")
	var top := CHAPEL_HI.y
	WorldKit.box(roof, "Slab", Vector3(CHAPEL_HI.x - CHAPEL_LO.x + W * 2.0, 1.2, 30.0 + W),
		WorldKit.at(Vector3((CHAPEL_LO.x + CHAPEL_HI.x) * 0.5, top + 0.6, CHAPEL_LO.z - W + (30.0
		+ W) * 0.5)), "rock_dark")
	for z in [26.0, 34.0, 42.0]:
		WorldKit.box(roof, "Beam", Vector3(CHAPEL_HI.x - CHAPEL_LO.x + W * 2.0, 1.0, 1.0),
			WorldKit.at(Vector3((CHAPEL_LO.x + CHAPEL_HI.x) * 0.5, top + 0.5, z)), "wood_dark")
	var inside := WorldKit.body(chapel, "ChapelFurnishing")
	for block in [Vector2(-6.0, 12.0), Vector2(22.0, 44.0)]:
		for x in [-128.0, -120.0, -112.0]:
			var long: float = block.y - block.x
			WorldKit.box(inside, "Shelf", Vector3(1.6, 12.0, long),
				WorldKit.at(Vector3(x, LEVEL + 6.0, (block.x + block.y) * 0.5)), "wood_dark")
			for shelf_y in [3.5, 7.0, 10.5]:
				WorldKit.box(inside, "Books", Vector3(2.0, 0.25, long - 0.4),
					WorldKit.at(Vector3(x, LEVEL + shelf_y, (block.x + block.y) * 0.5)), "paper",
					false)
	# The gallery, ten up along the west wall.
	WorldKit.box(inside, "Gallery", Vector3(8.0, 1.0, CHAPEL_HI.z - CHAPEL_LO.z),
		WorldKit.at(Vector3(CHAPEL_LO.x + 4.0, LEVEL + 9.5, (CHAPEL_LO.z + CHAPEL_HI.z) * 0.5)),
		"wood_dark")
	for z in [0.0, 20.0, 40.0]:
		WorldKit.cylinder(inside, "GalleryPost", 0.5, 9.0,
			WorldKit.at(Vector3(CHAPEL_LO.x + 7.5, LEVEL + 4.5, z)), "wood_dark", true, -1.0, 8)
	for spot in [Vector3(-108.0, 12.0, 0.0), Vector3(-108.0, 12.0, 30.0), Vector3(-134.0, 15.0,
			10.0), Vector3(-134.0, 15.0, 36.0)]:
		_lamp(inside, "Candle", Vector3(spot.x, LEVEL + spot.y, spot.z), CHAPEL_LAMP, 20.0, 1.2)


# --- the watchtower ------------------------------------------------------------------

## A tower on a hill: four floors with a hole in each, open to the sky at the top
## and walled round with battlements. Its door is shut and opens from the inside —
## the way in is up its outside and down through it.
func _watchtower() -> void:
	var tower := WorldKit.group(self, "Watchtower")
	_room(tower, "TowerWalls", TOWER_LO, TOWER_HI, "rock", "rock_dark", {
		"south": [Rect2(-24.0, TOWER_LO.y, 8.0, 8.0), Rect2(-21.0, TOWER_LO.y + 22.0, 2.0, 5.0),
			Rect2(-21.0, TOWER_LO.y + 38.0, 2.0, 5.0)],
		"west": [Rect2(-124.0, TOWER_LO.y + 22.0, 2.0, 5.0), Rect2(-118.0, TOWER_LO.y + 38.0, 2.0,
			5.0)],
		"east": [Rect2(-124.0, TOWER_LO.y + 30.0, 2.0, 5.0)],
	}, ["roof"])
	var floors := WorldKit.body(tower, "TowerFloors")
	var holes := [Rect2(-18.0, -128.0, 6.0, 6.0), Rect2(-28.0, -118.0, 6.0, 6.0),
		Rect2(-18.0, -118.0, 6.0, 6.0)]
	for i in TOWER_FLOORS.size():
		var top: float = TOWER_FLOORS[i]
		_panel(floors, "Floor%d" % i, 1, top - W, top, Vector2(TOWER_LO.x, TOWER_HI.x),
			Vector2(TOWER_LO.z, TOWER_HI.z), [holes[i]], "rock_dark")
	# Battlements round the top: merlons on every wall, with gaps between.
	var crown := WorldKit.body(tower, "Battlements")
	for i in 6:
		var along := lerpf(TOWER_LO.x - W, TOWER_HI.x + W, (float(i) + 0.5) / 6.0)
		for z in [TOWER_LO.z - W * 0.5, TOWER_HI.z + W * 0.5]:
			WorldKit.box(crown, "Merlon", Vector3(2.0, 2.4, W), WorldKit.at(Vector3(along,
				TOWER_HI.y + 1.2, z)), "rock")
		var across := lerpf(TOWER_LO.z - W, TOWER_HI.z + W, (float(i) + 0.5) / 6.0)
		for x in [TOWER_LO.x - W * 0.5, TOWER_HI.x + W * 0.5]:
			WorldKit.box(crown, "Merlon", Vector3(W, 2.4, 2.0), WorldKit.at(Vector3(x,
				TOWER_HI.y + 1.2, across)), "rock")
	for top in [TOWER_LO.y] + TOWER_FLOORS:
		_lamp(tower, "Sconce", Vector3(-28.0, top + 6.0, -112.0), TOWER_LAMP, 16.0, 1.2)
		_lamp(tower, "Sconce", Vector3(-12.0, top + 6.0, -128.0), TOWER_LAMP, 16.0, 1.2)


# --- the barrow --------------------------------------------------------------------

## A hall dug into a mound, its way in a stone door at the end of a cutting: pillars
## inside, and a throne at the back. The Rat King's.
func _barrow() -> void:
	var barrow := WorldKit.group(self, "Barrow")
	_room(barrow, "BarrowWalls", BARROW_LO, BARROW_HI, "rock_dark", "rock", {
		"south": [Rect2(106.0, BARROW_LO.y, 8.0, 7.0)],
	})
	var inside := WorldKit.body(barrow, "BarrowFurnishing")
	for pillar in [Vector2(102.0, -108.0), Vector2(118.0, -108.0), Vector2(102.0, -92.0),
			Vector2(118.0, -92.0)]:
		WorldKit.cylinder(inside, "Pillar", 1.6, BARROW_HI.y - BARROW_LO.y,
			WorldKit.at(Vector3(pillar.x, (BARROW_LO.y + BARROW_HI.y) * 0.5, pillar.y)), "rock",
			true, -1.0, 12)
	WorldKit.box(inside, "Throne", Vector3(6.0, 2.0, 3.0), WorldKit.at(Vector3(110.0,
		BARROW_LO.y + 1.0, -114.0)), "rock")
	WorldKit.box(inside, "ThroneBack", Vector3(6.0, 6.0, 1.0), WorldKit.at(Vector3(110.0,
		BARROW_LO.y + 3.0, -115.5)), "rock_dark")
	# Standing stones either side of the way in.
	for side in [-1.0, 1.0]:
		var at := Vector2(110.0 + side * 9.0, BARROW_HI.z + 6.0)
		Props.place(barrow, "standing_stone", Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.7),
			on_ground(at.x, at.y, -0.5)))
	for spot in [Vector3(110.0, 10.0, -100.0), Vector3(98.0, 8.0, -88.0), Vector3(122.0, 8.0,
			-112.0)]:
		_lamp(inside, "Torch", Vector3(spot.x, BARROW_LO.y + spot.y, spot.z), BARROW_LAMP, 20.0, 1.3)


# --- the mire ---------------------------------------------------------------------

## A sunken bog: reeds round its edge, lily pads on the mud, old wood lying in it.
func _mire() -> void:
	var mire := WorldKit.group(self, "Mire")
	var dice := _dice(41)
	for i in 26:
		var at := _ring(dice, MIRE, MIRE_REACH * 0.55, MIRE_REACH * 0.85)
		_prop(mire, "reeds", at, dice, Vector2(0.8, 1.3))
	for i in 14:
		var at := MIRE + Vector2(dice.randf_range(-1.0, 1.0), dice.randf_range(-1.0, 1.0)) \
			* MIRE_REACH * 0.45
		_prop(mire, "lily_pad", at, dice, Vector2(0.9, 1.4))
	for i in 4:
		var at := MIRE + Vector2(dice.randf_range(-1.0, 1.0), dice.randf_range(-1.0, 1.0)) \
			* MIRE_REACH * 0.5
		_prop(mire, "driftwood", at, dice, Vector2(0.7, 1.0), 0.2)


# --- the wood ----------------------------------------------------------------------

## The forest floor between the places: old trees, ferns, toadstools, boulders,
## leaves and grass, kept off the places, the paths and the wyrm's way round.
func _wood() -> void:
	var wood := WorldKit.group(self, "TheWood")
	var dice := _dice(17)
	var spread := RIM_FROM - 8.0
	var plan := [
		["forest_tree", 9, Vector2(0.8, 1.0), 30.0],
		["tree_oak", 22, Vector2(0.8, 1.1), 18.0],
		["tree_birch", 14, Vector2(0.8, 1.1), 10.0],
		["fern", 140, Vector2(0.8, 1.4), 0.0],
		["toadstool", 30, Vector2(0.8, 1.5), 0.0],
		["mushrooms", 30, Vector2(0.8, 1.4), 0.0],
		["boulder", 26, Vector2(0.8, 1.6), 0.0],
		["pebble", 50, Vector2(0.8, 1.6), 0.0],
		["fallen_leaf", 50, Vector2(0.9, 1.3), 0.0],
		["fallen_leaf_rust", 40, Vector2(0.9, 1.3), 0.0],
		["twig", 30, Vector2(0.9, 1.3), 0.0],
		["tall_grass", 50, Vector2(0.8, 1.2), 0.0],
		["wildflowers", 26, Vector2(0.8, 1.2), 0.0],
	]
	for kind in plan:
		var id: String = kind[0]
		var count: int = kind[1]
		var sizes: Vector2 = kind[2]
		var crown: float = kind[3]
		var placed := 0
		var tries := 0
		while placed < count and tries < count * 30:
			tries += 1
			var at := Vector2(dice.randf_range(-spread, spread), dice.randf_range(-spread, spread))
			if not _open_wood(at, 4.0 + crown * 0.3):
				continue
			if crown > 0.0 and _near_beat(at, crown + 6.0):
				continue
			_prop(wood, id, at, dice, sizes, 0.05)
			placed += 1


## Whether (x, z) is out in the wood: off every place, every path and the edges,
## by [param clear].
func _open_wood(at: Vector2, clear: float) -> bool:
	if at.distance_to(CLEARING) < CLEARING_REACH + clear:
		return false
	if _in_square(at, COURT, COURT_HALF + clear):
		return false
	if Rect2(YARD_LO, YARD_HI - YARD_LO).grow(clear).has_point(at):
		return false
	if _rect(CHAPEL_LO, CHAPEL_HI).grow(clear + 4.0).has_point(at):
		return false
	if at.distance_to(HILL) < 24.0 + clear:
		return false
	if _rect(BARROW_LO, BARROW_HI).grow(clear + 6.0).has_point(at) \
			or Rect2(100.0, -84.0, 20.0, 30.0).grow(clear).has_point(at):
		return false
	if at.distance_to(MIRE) < MIRE_REACH + clear:
		return false
	if _to_path(at) < PATH_WIDE + clear:
		return false
	return true


## Whether (x, z) is within [param clear] of the line the wyrm flies round.
func _near_beat(at: Vector2, clear: float) -> bool:
	for i in WYRM_BEAT.size():
		var a: Vector2 = WYRM_BEAT[i][0]
		var b: Vector2 = WYRM_BEAT[(i + 1) % WYRM_BEAT.size()][0]
		if at.distance_to(Geometry2D.get_closest_point_to_segment(at, a, b)) < clear:
			return true
	return false


# --- what the places are called ------------------------------------------------------

## The places, as zones that never overlap — what the HUD names when the spider
## walks into one. The wood between them has no name. All of it built for one size,
## the Huntsman's.
func _places() -> void:
	var size := Vector2(0.7, 0.7)
	var low := -20.0
	var sky := 80.0
	Zone.make(self, "The Shrine Clearing", Vector3(CLEARING.x - CLEARING_REACH, low,
		CLEARING.y - CLEARING_REACH), Vector3(CLEARING.x + CLEARING_REACH, sky,
		CLEARING.y + CLEARING_REACH), size)
	Zone.make(self, "The Ruined Court", Vector3(COURT.x - COURT_HALF, low, COURT.y - COURT_HALF),
		Vector3(COURT.x + COURT_HALF, sky, COURT.y + COURT_HALF), size)
	Zone.make(self, "The Graveyard", Vector3(YARD_LO.x, low, YARD_LO.y),
		Vector3(YARD_HI.x, sky, YARD_HI.y), size)
	Zone.make(self, "The Chapel", Vector3(CHAPEL_LO.x - W, low, CHAPEL_LO.z - W),
		Vector3(CHAPEL_HI.x + W, sky, CHAPEL_HI.z + W), size)
	var belfry: float = TOWER_FLOORS[TOWER_FLOORS.size() - 1]
	Zone.make(self, "The Watchtower", Vector3(TOWER_LO.x - W, low, TOWER_LO.z - W),
		Vector3(TOWER_HI.x + W, belfry, TOWER_HI.z + W), size)
	Zone.make(self, "The Belfry", Vector3(TOWER_LO.x - W, belfry, TOWER_LO.z - W),
		Vector3(TOWER_HI.x + W, sky + 20.0, TOWER_HI.z + W), size)
	Zone.make(self, "The Barrow", Vector3(BARROW_LO.x - W, low, BARROW_LO.z - W),
		Vector3(BARROW_HI.x + W, sky, BARROW_HI.z + 30.0), size)
	Zone.make(self, "The Mire", Vector3(MIRE.x - MIRE_REACH, low, MIRE.y - MIRE_REACH),
		Vector3(MIRE.x + MIRE_REACH, sky, MIRE.y + MIRE_REACH), size)


# --- the shrines, the doors, the lair ---------------------------------------------------

func _shrines() -> void:
	Shrine.make(self, "Shrine of the Clearing", on_ground(CLEARING.x, CLEARING.y, 0.4),
		Vector3.FORWARD, true)
	Shrine.make(self, "Graveside Shrine", Vector3(142.0, LEVEL, 14.0), Vector3.LEFT)
	Shrine.make(self, "Gallery Shrine", Vector3(CHAPEL_LO.x + 3.0, LEVEL + 10.0, 18.0),
		Vector3.RIGHT)
	Shrine.make(self, "Belfry Shrine", Vector3(-26.0, TOWER_FLOORS[2], -126.0), Vector3(1.0, 0.0,
		1.0))
	var before := Vector2(110.0, BARROW_HI.z + 22.0)
	Shrine.make(self, "Barrow Shrine", on_ground(before.x, before.y), Vector3.BACK)


## The chapel's side door, opened from inside the chapel; and the watchtower's
## door, opened from the bottom of the tower.
func _gates() -> void:
	ShortcutGate.make(self, "Chapel Door", Vector3(-125.0, CHAPEL_LO.y, CHAPEL_HI.z),
		Vector3(-115.0, CHAPEL_LO.y + 8.0, CHAPEL_HI.z + W), Vector3(-120.0, CHAPEL_LO.y, 45.0))
	ShortcutGate.make(self, "Tower Door", Vector3(-24.0, TOWER_LO.y, TOWER_HI.z),
		Vector3(-16.0, TOWER_LO.y + 8.0, TOWER_HI.z + W), Vector3(-20.0, TOWER_LO.y, -115.0))


## The Rat King's hall: sealed at its door while the king lives.
func _lair() -> void:
	var lair := BossLair.make(self, "The Barrow", Vector3(BARROW_LO.x, BARROW_LO.y, BARROW_LO.z),
		Vector3(BARROW_HI.x, BARROW_HI.y, BARROW_HI.z - 2.5), "rat_king",
		Vector3(110.0, BARROW_LO.y + 0.4, -104.0), "wing_buds")
	lair.add_veil(Vector3(106.0, BARROW_LO.y, BARROW_HI.z),
		Vector3(114.0, BARROW_LO.y + 7.0, BARROW_HI.z + W))


# --- what lives here --------------------------------------------------------------------

func _hostiles() -> void:
	var holder := WorldKit.group(self, "Hostiles")
	var i := 0
	for entry in HOSTILES:
		var mark := HostileSpawn.new()
		mark.name = "%s%d" % [String(entry[0]).to_pascal_case(), i]
		mark.species_id = entry[0]
		holder.add_child(mark)
		var at: Vector2 = entry[1]
		mark.global_position = Vector3(at.x, _floor_at(at, float(entry[2])), at.y)
		i += 1


## The height something put at (x, z) [param lift] over whatever floor is there:
## the ground, or a floor inside the watchtower or on the chapel's gallery.
func _floor_at(at: Vector2, lift: float) -> float:
	if _rect(TOWER_LO, TOWER_HI).has_point(at):
		return TOWER_LO.y + lift
	return ground_at(at.x, at.y) + lift


func _wyrm() -> void:
	var mark := HostileSpawn.new()
	mark.name = "HollowWyrm"
	mark.species_id = "hollow_wyrm"
	mark.stays_beaten = true
	var beat := PackedVector3Array()
	for point in WYRM_BEAT:
		var at: Vector2 = point[0]
		beat.append(on_ground(at.x, at.y, point[1]))
	mark.route = beat
	add_child(mark)
	mark.global_position = beat[0]


func _keeper() -> void:
	var keeper := Checkpoints.new()
	keeper.name = "Checkpoints"
	add_child(keeper)


## Wakes the spider at the clearing's shrine.
func _place_the_spider() -> void:
	var holder := get_parent()
	var spider := holder.get_node_or_null("Player") as Node3D if holder != null else null
	var shrine := get_node_or_null("ShrineoftheClearing") as Shrine
	if spider != null and shrine != null:
		spider.global_transform = shrine.wake_transform()


# --- building -----------------------------------------------------------------------

## A room under [param parent] whose space to stand in runs from [param lo] to
## [param hi], its six sides built outside that, with holes cut where [param holes]
## says: side name to an array of holes, each a Rect2 in that side's own two axes —
## (x, y) for north and south, (z, y) for east and west, (x, z) for the floor and
## the roof. A side in [param open] is left off: open to the sky, or to the room
## next door.
func _room(parent: Node3D, room_name: String, lo: Vector3, hi: Vector3, paint: String,
		floor_paint: String, holes := {}, open: Array = []) -> StaticBody3D:
	var body := WorldKit.body(parent, room_name)
	var round_x := Vector2(lo.x - W, hi.x + W)
	var round_z := Vector2(lo.z - W, hi.z + W)
	var sides := {
		"floor": [1, lo.y - 0.6, lo.y, round_x, round_z, floor_paint],
		"roof": [1, hi.y, hi.y + W, round_x, round_z, paint],
		"north": [2, lo.z - W, lo.z, round_x, Vector2(lo.y - 0.6, hi.y), paint],
		"south": [2, hi.z, hi.z + W, round_x, Vector2(lo.y - 0.6, hi.y), paint],
		"west": [0, lo.x - W, lo.x, Vector2(lo.z, hi.z), Vector2(lo.y - 0.6, hi.y), paint],
		"east": [0, hi.x, hi.x + W, Vector2(lo.z, hi.z), Vector2(lo.y - 0.6, hi.y), paint],
	}
	for side: String in sides:
		if open.has(side):
			continue
		var plan: Array = sides[side]
		_panel(body, side.capitalize(), plan[0], plan[1], plan[2], plan[3], plan[4],
			holes.get(side, []), plan[5])
	return body


## A flat panel with rectangular holes in it, built as the boxes round them.
##
## [param axis] is the one it is thin across — 0 for a wall facing along x, 1 for a
## floor, 2 for a wall facing along z — and it runs from [param t0] to [param t1]
## that way. [param a] and [param b] are its extent in its own two axes, (z, y),
## (x, z) or (x, y) by the same rule as the holes. Cut into columns at every
## hole's edge; each column is solid wherever no hole covers it.
func _panel(body: StaticBody3D, panel_name: String, axis: int, t0: float, t1: float,
		a: Vector2, b: Vector2, holes: Array, paint: String) -> void:
	var cuts: Array[float] = [a.x, a.y]
	for hole: Rect2 in holes:
		cuts.append(clampf(hole.position.x, a.x, a.y))
		cuts.append(clampf(hole.end.x, a.x, a.y))
	cuts.sort()
	var piece := 0
	for i in cuts.size() - 1:
		var c0: float = cuts[i]
		var c1: float = cuts[i + 1]
		if c1 - c0 < 0.001:
			continue
		var middle := (c0 + c1) * 0.5
		var covered: Array[Vector2] = []
		for hole: Rect2 in holes:
			if hole.position.x <= middle and hole.end.x >= middle:
				covered.append(Vector2(hole.position.y, hole.end.y))
		covered.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
		var at := b.x
		for span in covered:
			if span.x > at + 0.001:
				_panel_box(body, "%s%d" % [panel_name, piece], axis, t0, t1, c0, c1, at,
					minf(span.x, b.y), paint)
				piece += 1
			at = maxf(at, span.y)
		if at < b.y - 0.001:
			_panel_box(body, "%s%d" % [panel_name, piece], axis, t0, t1, c0, c1, at, b.y, paint)
			piece += 1


func _panel_box(body: StaticBody3D, box_name: String, axis: int, t0: float, t1: float,
		a0: float, a1: float, b0: float, b1: float, paint: String) -> void:
	var size := Vector3.ZERO
	var middle := Vector3.ZERO
	match axis:
		0:
			size = Vector3(t1 - t0, b1 - b0, a1 - a0)
			middle = Vector3((t0 + t1) * 0.5, (b0 + b1) * 0.5, (a0 + a1) * 0.5)
		1:
			size = Vector3(a1 - a0, t1 - t0, b1 - b0)
			middle = Vector3((a0 + a1) * 0.5, (t0 + t1) * 0.5, (b0 + b1) * 0.5)
		_:
			size = Vector3(a1 - a0, b1 - b0, t1 - t0)
			middle = Vector3((a0 + a1) * 0.5, (b0 + b1) * 0.5, (t0 + t1) * 0.5)
	WorldKit.box(body, box_name, size, Transform3D(Basis.IDENTITY, middle), paint)


# --- putting things down ---------------------------------------------------------

## A die for one part of the level, so that what is scattered there lands in the
## same places every time it is built.
func _dice(seed_value: int) -> RandomNumberGenerator:
	var dice := RandomNumberGenerator.new()
	dice.seed = seed_value
	return dice


## Somewhere in the ring between [param inner] and [param outer] round [param middle].
func _ring(dice: RandomNumberGenerator, middle: Vector2, inner: float, outer: float) -> Vector2:
	var turn := dice.randf() * TAU
	return middle + Vector2(cos(turn), sin(turn)) * lerpf(inner, outer, dice.randf())


## One of a prop, on the ground at [param at], turned any way and sized somewhere
## in [param sizes]; sunk [param sink] into the ground, for something that has sat
## there a while.
func _prop(parent: Node3D, id: String, at: Vector2, dice: RandomNumberGenerator,
		sizes := Vector2(0.85, 1.2), sink := 0.0) -> Node3D:
	var size := dice.randf_range(sizes.x, sizes.y)
	var turn := Basis(Vector3.UP, dice.randf() * TAU).scaled(Vector3.ONE * size)
	return Props.place(parent, id, Transform3D(turn, on_ground(at.x, at.y, -sink * size)))
