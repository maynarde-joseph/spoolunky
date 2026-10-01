class_name HuntingGround
extends Node3D

## The hunting ground: a wild valley, and everything that lives in it.
##
## Seven places in one space, the way a hunting ground in the games it is named
## for is laid out: a camp to set out from, and around it the places things live,
## each its own country with its own creatures and its own danger. Nothing shuts
## the way to any of them. What keeps a spiderling out of the crag is that the
## crag would eat it.
##
##     the Crag ............ north: a rock tower, and the wyvern's nest on top
##     the Old Ruins ....... north-west, up on a shelf of ground
##     the Bloom Glade ..... the middle: open meadow, flowers, deer and hares
##     the Mere ............ east: a round lake, an island, and what is in it
##     the Rootways ........ west: a great tree, and caves under its roots
##     the Fern Floor ...... south: forest floor, where everything starts small
##     the Camp ............ the south edge: a hollow stump, and nothing in it
##
## Every place is built for a stretch of the spider's sizes, smallest nearest the
## camp, so that the way across the valley is the way up the sizes — but a stag
## wanders where it likes, and the wyvern hunts the whole valley from the air.
##
## It is alive. An [Ecosystem] keeps the day and knows who is near whom; dens put
## creatures out and breed them on what they eat; patches of forage grow back;
## the big things roam between their haunts. None of it is scripted: a glade with
## too many hares on it is a glade with no grass on it.
##
## Everything is to the scale of the [Props], a metre about fourteen units, and
## built the way everything else here is built: [WorldKit] solids painted from
## the [Palette], with the ground itself one height map. Like the old world it is
## baked into its scene and taken off the node; this is the generator of record:
##
##     godot --headless --path . --script res://tools/bake_level.gd -- hunting_ground --force

# --- the valley -------------------------------------------------------------

## The ground is a square this many cells across, each this wide — a power of two
## cells, so that it collides as one height map.
const CELLS := 256
const CELL := 3.0

## Where the hills round the valley start rising, and how high they get: steep,
## so the valley reads as a valley, and climbable, because everything is.
const RIM_FROM := 312.0
const RIM_TO := 372.0
const RIM_HEIGHT := 75.0

## The way the sunlight goes before the day takes it over, for a level opened
## without one.
const SUNLIGHT := Vector3(-0.4, -0.8, 0.45)

# --- the places, by their middles in (x, z) ----------------------------------

const CAMP := Vector2(20.0, 268.0)
const FERN_FLOOR := Vector2(0.0, 185.0)
const ROOTWAYS := Vector2(-205.0, 160.0)
const GREAT_TREE := Vector2(-205.0, 140.0)
const GLADE := Vector2(10.0, 0.0)
const RUINS := Vector2(-215.0, -85.0)
const MERE := Vector2(235.0, -10.0)
const CRAG := Vector2(-20.0, -275.0)

## The shelf the ruins stand on, how high, and how far across.
const RUINS_SHELF := 8.0
const RUINS_REACH := 95.0

## The hollow under the great tree's roots, how deep, and how far across.
const HOLLOW := 5.0
const HOLLOW_REACH := 55.0

## The Mere: how far out its basin goes, the top of the water and the bottom of
## the lake, and the island in it.
const MERE_REACH := 125.0
const MERE_FLOOR := 30.0
const WATER_TOP := -3.0
const MERE_BED := -26.0
const WATER_EDGE := 104.0
const ISLAND := Vector2(258.0, -28.0)
const ISLAND_REACH := 20.0

## The crag: how far out its foot is, where it gets steep, and how high its top.
const CRAG_FOOT := 82.0
const CRAG_STEEP := 36.0
const CRAG_TOP := 104.0

## Where a new spider starts: inside the stump at the camp.
const SPAWN_HEIGHT := 1.0

## The puddle on the fern floor, and how far across.
const PUDDLE := Vector2(-45.0, 205.0)
const PUDDLE_REACH := 7.5

## The great tree's trunk: how thick at its foot and at the top of what is drawn,
## and how tall to its crown.
const TREE_GIRTH := 22.0
const TREE_TOP_GIRTH := 15.0
const TREE_HEIGHT := 230.0

## The hollow log on the floor of the rootways, end to end, and how big round.
const LOG_FROM := Vector2(-146.0, 218.0)
const LOG_TO := Vector2(-262.0, 244.0)
const LOG_RADIUS := 10.0
const LOG_WALL := 1.6

# --- the colours of the ground ---------------------------------------------

const MEADOW := Color(0.4, 0.55, 0.25)
const FOREST := Color(0.27, 0.33, 0.17)
const LOAM := Color(0.32, 0.25, 0.17)
const RUIN_GRASS := Color(0.45, 0.5, 0.3)
const SHORE := Color(0.52, 0.46, 0.33)
const LAKE_BED := Color(0.22, 0.27, 0.2)
const ROCK := Color(0.46, 0.45, 0.43)

var _broad: FastNoiseLite
var _fine: FastNoiseLite


func _ready() -> void:
	build()


func build() -> void:
	_noise()
	_sky()
	_life()
	_ground()
	_places()
	_camp()
	_fern_floor()
	_rootways()
	_bloom_glade()
	_place_the_spider()


# --- the shape of the ground -------------------------------------------------

## How high the ground is at (x, z): gently rolling, with the hills round the
## edge, the shelf under the ruins, the hollow under the great tree, the basin of
## the Mere with its island, and the crag standing up out of the north.
func ground_at(x: float, z: float) -> float:
	if _broad == null:
		_noise()
	var at := Vector2(x, z)
	var height := 2.2 * _broad.get_noise_2d(x, z) + 0.9 * _fine.get_noise_2d(x, z)
	var edge := maxf(absf(x), absf(z))
	height += RIM_HEIGHT * smoothstep(RIM_FROM, RIM_TO, edge) \
		* (0.8 + 0.4 * _broad.get_noise_2d(x * 0.5 + 100.0, z * 0.5))
	height += RUINS_SHELF * smoothstep(RUINS_REACH, RUINS_REACH * 0.62, at.distance_to(RUINS))
	height -= HOLLOW * smoothstep(HOLLOW_REACH, HOLLOW_REACH * 0.28, at.distance_to(GREAT_TREE))
	height -= 1.6 * smoothstep(PUDDLE_REACH + 1.5, PUDDLE_REACH * 0.4, at.distance_to(PUDDLE))
	var lake := at.distance_to(MERE)
	if lake < MERE_REACH:
		height = lerpf(MERE_BED, height, smoothstep(MERE_FLOOR, MERE_REACH, lake))
		var island := at.distance_to(ISLAND)
		if island < ISLAND_REACH:
			height = maxf(height, lerpf(3.0, WATER_TOP - 2.0, smoothstep(ISLAND_REACH * 0.35,
				ISLAND_REACH, island)))
	var crag := at.distance_to(CRAG)
	if crag < CRAG_FOOT:
		var rise := pow(smoothstep(CRAG_FOOT, CRAG_STEEP, crag), 0.7)
		var rough := 6.0 * _fine.get_noise_2d(x * 4.0, z * 4.0) * (1.0 - rise * 0.6)
		height = maxf(height, CRAG_TOP * rise + rough * rise)
		# A bowl in the top, where the nest is.
		height -= 5.0 * smoothstep(16.0, 4.0, crag)
	return height


## The colour of the ground at [param at], facing [param normal]: meadow, darker
## under the ferns, bare loam in the Rootways, sand round the Mere and weed under
## it, and rock wherever it is steep or high.
func ground_colour(at: Vector3, normal: Vector3) -> Color:
	var flat := Vector2(at.x, at.z)
	var colour := MEADOW
	colour = colour.lerp(FOREST, smoothstep(115.0, 55.0, flat.distance_to(FERN_FLOOR)))
	colour = colour.lerp(LOAM, smoothstep(95.0, 35.0, flat.distance_to(ROOTWAYS)))
	colour = colour.lerp(RUIN_GRASS, smoothstep(RUINS_REACH, RUINS_REACH * 0.6,
		flat.distance_to(RUINS)))
	var lake := flat.distance_to(MERE)
	colour = colour.lerp(SHORE, smoothstep(MERE_REACH, WATER_EDGE - 4.0, lake))
	colour = colour.lerp(LAKE_BED, smoothstep(WATER_EDGE - 6.0, WATER_EDGE - 22.0, lake))
	if flat.distance_to(ISLAND) < ISLAND_REACH:
		colour = colour.lerp(MEADOW, smoothstep(ISLAND_REACH, ISLAND_REACH * 0.5,
			flat.distance_to(ISLAND)))
	colour = colour.lerp(ROCK, smoothstep(0.32, 0.55, 1.0 - normal.y))
	colour = colour.lerp(ROCK, smoothstep(38.0, 70.0, at.y))
	var grain := 1.0 + 0.07 * _fine.get_noise_2d(at.x * 3.0, at.z * 3.0)
	return Color(colour.r * grain, colour.g * grain, colour.b * grain)


## The ground under (x, z), as a point on it.
func on_ground(x: float, z: float, lift := 0.0) -> Vector3:
	return Vector3(x, ground_at(x, z) + lift, z)


func _noise() -> void:
	_broad = FastNoiseLite.new()
	_broad.seed = 7
	_broad.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_broad.frequency = 0.008
	_fine = FastNoiseLite.new()
	_fine.seed = 11
	_fine.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_fine.frequency = 0.04


# --- sky, light and life --------------------------------------------------------

## A sky with a little haze in it, so the far side of the valley sits back, and one
## sun. The [DayNight] moves them.
func _sky() -> void:
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = Color(0.34, 0.52, 0.8)
	sky.sky_horizon_color = Color(0.72, 0.8, 0.86)
	sky.ground_bottom_color = Color(0.26, 0.3, 0.22)
	sky.ground_horizon_color = Color(0.62, 0.7, 0.66)
	sky.sun_angle_max = 20.0
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.sky.sky_material = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.74, 0.77, 0.8)
	environment.ambient_light_energy = 0.4
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.7, 0.77, 0.83)
	environment.fog_density = 0.0004
	environment.fog_aerial_perspective = 0.15
	environment.fog_sky_affect = 0.2
	var world := WorldEnvironment.new()
	world.name = "Sky"
	world.environment = environment
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 300.0
	add_child(sun)
	sun.global_position = Vector3(0.0, 200.0, 0.0)
	sun.look_at(sun.global_position + SUNLIGHT, Vector3.UP)


## The clock and the light that follows it. First in, so that everything alive
## that comes after finds them.
func _life() -> void:
	var clock := Ecosystem.new()
	clock.name = "Ecosystem"
	clock.start_time = 0.3
	add_child(clock)
	var day := DayNight.new()
	day.name = "DayNight"
	add_child(day)


func _ground() -> void:
	var ground := WorldKit.body(self, "Ground")
	WorldKit.terrain(ground, "Valley", Vector2.ZERO, CELLS, CELL, ground_at, ground_colour)


## The places, as zones that touch and never overlap — what the HUD names when
## the spider walks into one, and the sizes each was built for.
func _places() -> void:
	var low := -40.0
	var high := 220.0
	Zone.make(self, "The Camp", Vector3(-40.0, low, 260.0), Vector3(80.0, high, 340.0),
		Vector2(0.25, 0.4))
	Zone.make(self, "The Fern Floor", Vector3(-110.0, low, 100.0), Vector3(110.0, high, 260.0),
		Vector2(0.25, 0.7))
	Zone.make(self, "The Rootways", Vector3(-330.0, low, 60.0), Vector3(-110.0, high, 300.0),
		Vector2(0.7, 2.0))
	Zone.make(self, "The Bloom Glade", Vector3(-110.0, low, -120.0), Vector3(130.0, high, 100.0),
		Vector2(1.2, 3.4))
	Zone.make(self, "The Old Ruins", Vector3(-330.0, low, -200.0), Vector3(-110.0, high, 60.0),
		Vector2(2.0, 5.6))
	Zone.make(self, "The Mere", Vector3(130.0, low, -200.0), Vector3(380.0, high, 160.0),
		Vector2(3.4, 9.0))
	Zone.make(self, "Wyrm's Crag", Vector3(-180.0, low, -380.0), Vector3(130.0, high, -200.0),
		Vector2(9.0, 9.0))


# --- the camp -----------------------------------------------------------------

## A hollow stump at the south edge of the valley: a ring of bark open on the
## north side, toward everything, with moss on its floor and a glowcap for a
## lamp. Nothing lives here and nothing comes looking. It is where you start,
## and where you are put back.
func _camp() -> void:
	var at := on_ground(CAMP.x, CAMP.y)
	var stump := WorldKit.body(self, "Camp", Transform3D(Basis.IDENTITY, at))
	var outer := 8.5
	var thick := 1.6
	var tall := 7.0
	var staves := 14
	for i in staves:
		# The two staves facing north are left out: the way out.
		if i == 0 or i == staves - 1:
			continue
		var angle := TAU * (float(i) + 0.5) / float(staves) + PI * 0.5
		var out := Vector3(cos(angle), 0.0, -sin(angle))
		var height := tall * (0.82 + 0.3 * fposmod(float(i) * 0.37, 1.0))
		var width := TAU * outer / float(staves) * 1.08
		WorldKit.box(stump, "Bark", Vector3(width, height, thick),
			Transform3D(Basis.looking_at(out, Vector3.UP), out * (outer - thick * 0.5)
				+ Vector3.UP * (height * 0.5 - 0.6)), "bark")
	WorldKit.cylinder(stump, "Floor", outer - thick * 0.6, 0.6, WorldKit.at(Vector3(0.0, -0.1, 0.0)),
		"moss", true, -1.0, 24)
	# Rings in the cut top of the old wood, round the inside of the wall.
	WorldKit.ring(stump, "Rim", outer - thick * 0.5, thick * 0.7,
		WorldKit.at(Vector3(0.0, tall * 0.82 - 0.6, 0.0)), "wood_light")
	var lamp := WorldKit.group(stump, "Glowcap", WorldKit.at(Vector3(-4.0, 0.2, 3.2)))
	WorldKit.cylinder(lamp, "Stem", 0.28, 1.8, WorldKit.at(Vector3(0.0, 0.9, 0.0)), "stem", false,
		0.22)
	WorldKit.ball(lamp, "Cap", Vector3(1.1, 0.55, 1.1), WorldKit.at(Vector3(0.0, 1.9, 0.0)),
		"glowcap", false)
	var light := OmniLight3D.new()
	light.name = "Light"
	light.light_color = Color(0.55, 0.95, 0.8)
	light.light_energy = 0.8
	light.omni_range = 9.0
	light.position = Vector3(0.0, 2.6, 0.0)
	lamp.add_child(light)


# --- the fern floor -------------------------------------------------------------

## The forest floor south of the glade, where everything starts small: ferns
## overhead, toadstools, pebbles that are boulders, fallen leaves to cross, and a
## puddle. It is built for the first sizes, and what lives here is what a
## spiderling can take — midges and flies, beetles grazing the moss, an anthill,
## moths and fireflies at night, mosquitoes over the puddle.
func _fern_floor() -> void:
	var place := WorldKit.group(self, "FernFloor")
	var dice := _dice(101)
	var keep: Array[Vector2] = [CAMP, PUDDLE]
	var half := Vector2(100.0, 72.0)
	# The old forest's trees, round the edge of the floor, their crowns far over it.
	for spot: Vector2 in [Vector2(-82.0, 232.0), Vector2(72.0, 238.0), Vector2(-28.0, 132.0),
			Vector2(88.0, 150.0), Vector2(-98.0, 158.0)]:
		_prop(place, "forest_tree", spot, dice, Vector2(0.9, 1.15), 1.0)
		keep.append(spot)
	for i in 72:
		_prop(place, "fern", _scatter(dice, FERN_FLOOR, half, keep, 16.0), dice, Vector2(0.8, 1.4))
	for i in 7:
		_prop(place, "toadstool", _scatter(dice, FERN_FLOOR, half, keep, 16.0), dice)
	for i in 14:
		_prop(place, "mushrooms", _scatter(dice, FERN_FLOOR, half, keep, 14.0), dice)
	for i in 36:
		_prop(place, "pebble", _scatter(dice, FERN_FLOOR, half, keep, 12.0), dice, Vector2(0.6, 1.8))
	for i in 6:
		_prop(place, "boulder", _scatter(dice, FERN_FLOOR, half, keep, 20.0), dice, Vector2(0.8, 1.4),
			0.6)
	for i in 18:
		_prop(place, "acorn", _scatter(dice, FERN_FLOOR, half, keep, 12.0), dice)
	for i in 50:
		_prop(place, "fallen_leaf" if i % 3 != 0 else "fallen_leaf_rust",
			_scatter(dice, FERN_FLOOR, half, keep, 12.0), dice, Vector2(0.8, 1.5))
	for i in 16:
		_prop(place, "twig", _scatter(dice, FERN_FLOOR, half, keep, 14.0), dice, Vector2(0.7, 1.3))

	# The puddle, in its dip.
	var rim := ground_at(PUDDLE.x + PUDDLE_REACH, PUDDLE.y)
	var top := minf(rim, ground_at(PUDDLE.x - PUDDLE_REACH, PUDDLE.y)) - 0.25
	var bottom := ground_at(PUDDLE.x, PUDDLE.y) - 0.3
	WorldKit.round_water(place, "Puddle", PUDDLE_REACH, top - bottom,
		Transform3D(Basis.IDENTITY, Vector3(PUDDLE.x, bottom, PUDDLE.y)), "pond")

	# What grows, and what lives on it.
	for i in 10:
		_patch(place, "moss", _scatter(dice, FERN_FLOOR, half * 0.9, keep, 14.0), 3.5, 30.0, 0.2)
	var fungus: Array[Vector2] = []
	for i in 6:
		fungus.append(_scatter(dice, FERN_FLOOR, half * 0.9, keep, 14.0))
		_patch(place, "fungus", fungus[i], 3.0, 28.0, 0.15)
	var flowers: Array[Vector2] = []
	for i in 7:
		flowers.append(_scatter(dice, FERN_FLOOR, half * 0.9, keep, 14.0))
		_patch(place, "flowers", flowers[i], 3.2, 25.0, 0.25)
	for i in 2:
		_patch(place, "berries", _scatter(dice, FERN_FLOOR, half * 0.8, keep, 16.0), 4.0, 30.0, 0.1)

	var hill := _scatter(dice, FERN_FLOOR, half * 0.7, keep, 20.0)
	_prop(place, "anthill", hill, dice, Vector2(1.0, 1.0), 0.4)
	_den(place, "ant", hill, 6, 12, true)
	_den(place, "midge", flowers[0], 6, 10, false)
	_den(place, "midge", flowers[3], 6, 10, false)
	_den(place, "fly", fungus[0], 4, 8, false)
	_den(place, "beetle", _scatter(dice, FERN_FLOOR, half * 0.8, keep, 14.0), 3, 6, true)
	_den(place, "beetle", _scatter(dice, FERN_FLOOR, half * 0.8, keep, 14.0), 3, 6, true)
	_den(place, "firefly", flowers[5], 6, 10, false)
	_den(place, "moth", flowers[2], 3, 6, false)
	_den(place, "mosquito", PUDDLE + Vector2(PUDDLE_REACH + 3.0, 0.0), 4, 8, false)

	_haunt(place, "WestHaunt", FERN_FLOOR + Vector2(-70.0, -30.0), ["boar"], 18.0)
	_haunt(place, "NorthHaunt", FERN_FLOOR + Vector2(40.0, -65.0), ["deer", "boar"], 18.0)


# --- the rootways ---------------------------------------------------------------

## The great tree of the west side and what is under it: a trunk three and a half
## metres through, its roots arching out over the hollow it stands in so that
## under each is a cave, shelf fungus up the bark to climb by, and a hollow log
## lying on the floor to walk the length of. Glowcaps light the caves at night.
## It is built for the middle sizes, and what lives here comes out in the dark —
## cockroaches, rats, moths, beetles, and bats that hang under the roots by day.
func _rootways() -> void:
	var place := WorldKit.group(self, "Rootways")
	var foot := on_ground(GREAT_TREE.x, GREAT_TREE.y, -3.0)
	var tree := WorldKit.body(place, "GreatTree", Transform3D(Basis.IDENTITY, foot))
	WorldKit.cylinder(tree, "Trunk", TREE_GIRTH, TREE_HEIGHT, WorldKit.at(Vector3(0.0,
		TREE_HEIGHT * 0.5, 0.0)), "bark", true, TREE_TOP_GIRTH, 28)
	var crown := [
		[Vector3(0.0, 262.0, 0.0), Vector3(62.0, 30.0, 62.0), "leaf_dark"],
		[Vector3(46.0, 240.0, 12.0), Vector3(40.0, 22.0, 40.0), "leaf"],
		[Vector3(-44.0, 244.0, -16.0), Vector3(40.0, 24.0, 40.0), "leaf_dark"],
		[Vector3(10.0, 246.0, -46.0), Vector3(38.0, 22.0, 38.0), "leaf"],
		[Vector3(-12.0, 248.0, 44.0), Vector3(40.0, 22.0, 40.0), "leaf_light"],
	]
	for blob in crown:
		WorldKit.ball(tree, "Leaves", blob[1], WorldKit.at(blob[0]), blob[2])
	for i in 4:
		var turn := TAU * float(i) / 4.0 + 0.6
		var out := Vector3(cos(turn), 0.0, sin(turn))
		WorldKit.rod(tree, "Limb", out * 8.0 + Vector3.UP * 200.0, out * 52.0 + Vector3.UP * 236.0,
			6.0, "bark", true, 3.0, 12)

	# The roots: out from the trunk and down into the ground, arched high enough
	# over the hollow to walk under.
	var dice := _dice(202)
	var caves: Array[Vector2] = []
	for i in 10:
		var turn := TAU * (float(i) + dice.randf_range(-0.25, 0.25)) / 10.0
		var out := Vector3(cos(turn), 0.0, sin(turn))
		var reach := dice.randf_range(44.0, 58.0)
		var land := GREAT_TREE + Vector2(out.x, out.z) * reach
		var start := out * (TREE_GIRTH - 4.0) + Vector3.UP * 16.0
		var end := Vector3(out.x * reach, ground_at(land.x, land.y) - foot.y - 3.0, out.z * reach)
		var bend := out * reach * 0.5 + Vector3.UP * dice.randf_range(20.0, 26.0)
		_arch(tree, "Root", start, bend, end, dice.randf_range(5.0, 6.5), 2.6, "bark")
		caves.append(GREAT_TREE + Vector2(out.x, out.z) * reach * 0.55)

	# Shelf fungus up the trunk, to climb by.
	for i in 7:
		var turn := dice.randf() * TAU
		var up := 18.0 + float(i) * 22.0 + dice.randf_range(-4.0, 4.0)
		var girth := lerpf(TREE_GIRTH, TREE_TOP_GIRTH, up / TREE_HEIGHT)
		var out := Vector3(cos(turn), 0.0, sin(turn))
		var size := dice.randf_range(1.0, 1.6)
		Props.place(place, "bracket_fungus", Transform3D(Basis.looking_at(out, Vector3.UP).scaled(
			Vector3.ONE * size), foot + out * (girth - 0.6) + Vector3.UP * up))

	_hollow_log(place)

	var keep: Array[Vector2] = [GREAT_TREE, (LOG_FROM + LOG_TO) * 0.5, LOG_FROM, LOG_TO]
	var half := Vector2(105.0, 110.0)
	for i in 22:
		_prop(place, "mushrooms", _scatter(dice, ROOTWAYS, half, keep, 26.0), dice, Vector2(1.0, 2.2))
	for i in 5:
		_prop(place, "toadstool", _scatter(dice, ROOTWAYS, half, keep, 26.0), dice, Vector2(1.2, 2.0))
	for i in 12:
		_prop(place, "boulder", _scatter(dice, ROOTWAYS, half, keep, 30.0), dice, Vector2(1.0, 2.0),
			0.6)
	for i in 30:
		_prop(place, "fallen_leaf_rust" if i % 2 == 0 else "fallen_leaf",
			_scatter(dice, ROOTWAYS, half, keep, 24.0), dice, Vector2(1.2, 2.0))
	for i in 14:
		_prop(place, "twig", _scatter(dice, ROOTWAYS, half, keep, 24.0), dice, Vector2(1.4, 2.4))
	for i in 18:
		_prop(place, "fern", _scatter(dice, ROOTWAYS + Vector2(40.0, 40.0), half * 0.7, keep, 34.0),
			dice, Vector2(1.2, 1.8))

	# Glowcaps in the caves, and their light.
	for i in caves.size():
		_patch(place, "fungus", caves[i], 4.0, 34.0, 0.15, i % 2 == 0)
		if i % 3 == 0:
			var lamp := OmniLight3D.new()
			lamp.name = "Glow"
			lamp.light_color = Color(0.5, 0.95, 0.8)
			lamp.light_energy = 0.7
			lamp.omni_range = 16.0
			lamp.position = on_ground(caves[i].x, caves[i].y, 4.0)
			place.add_child(lamp, true)
	for i in 6:
		_patch(place, "moss", _scatter(dice, ROOTWAYS, half, keep, 26.0), 5.0, 36.0, 0.2)
	for i in 3:
		_patch(place, "fungus", _scatter(dice, ROOTWAYS, half, keep, 26.0), 4.0, 30.0, 0.15)
	for i in 2:
		_patch(place, "berries", _scatter(dice, ROOTWAYS + Vector2(50.0, -50.0), half * 0.5, keep,
			26.0), 6.0, 40.0, 0.1)

	_den(place, "bat", caves[0], 3, 5, false, 6.0)
	_den(place, "cockroach", caves[2], 3, 6, true, 4.0)
	_den(place, "cockroach", caves[6], 3, 6, true, 4.0)
	_den(place, "rat", caves[4], 2, 4, true, 6.0)
	_den(place, "rat", (LOG_FROM + LOG_TO) * 0.5 + Vector2(0.0, 18.0), 2, 4, true, 6.0)
	_den(place, "beetle", caves[8], 3, 6, true, 4.0)
	_den(place, "moth", caves[5], 3, 6, false, 5.0)
	_den(place, "fly", caves[1], 3, 6, false, 4.0)

	_haunt(place, "TreeHaunt", GREAT_TREE + Vector2(60.0, -55.0), ["boar", "wolf"], 22.0)
	_haunt(place, "LogHaunt", LOG_TO + Vector2(10.0, -30.0), ["wolf"], 22.0)


## A root, or anything else that arches: a thick rod curving from [param from]
## over [param bend] down to [param to], thinning from [param thick] to
## [param thin], in lengths with a ball at every joint so it reads as one curve.
func _arch(on: Node3D, part_name: String, from: Vector3, bend: Vector3, to: Vector3,
		thick: float, thin: float, paint: String, pieces := 7) -> void:
	var last := from
	for k in range(1, pieces + 1):
		var t := float(k) / float(pieces)
		var at := from.lerp(bend, t).lerp(bend.lerp(to, t), t)
		var girth := lerpf(thick, thin, t)
		WorldKit.rod(on, part_name, last, at, lerpf(thick, thin, float(k - 1) / float(pieces)),
			paint, true, girth, 12)
		if k < pieces:
			WorldKit.ball(on, part_name + "Knot", Vector3.ONE * girth, WorldKit.at(at), paint)
		last = at


## A hollow log lying across the floor of the rootways, open at both ends: bark
## outside, old dark wood inside, moss along its top. A tunnel the length of it.
func _hollow_log(place: Node3D) -> void:
	var run := LOG_TO - LOG_FROM
	var middle := (LOG_FROM + LOG_TO) * 0.5
	var low := minf(minf(ground_at(LOG_FROM.x, LOG_FROM.y), ground_at(LOG_TO.x, LOG_TO.y)),
		ground_at(middle.x, middle.y))
	var along := Vector3(run.x, 0.0, run.y).normalized()
	var where := Transform3D(Basis.looking_at(along, Vector3.UP),
		Vector3(middle.x, low + LOG_RADIUS - 3.0, middle.y))
	var hollow := WorldKit.body(place, "HollowLog", where)
	var inside := PackedVector2Array()
	var outside := PackedVector2Array()
	var dark := PackedColorArray()
	var bark := PackedColorArray()
	var sides := 22
	for i in sides + 1:
		var turn := TAU * float(i) / float(sides)
		inside.append(Vector2(cos(turn), sin(turn)) * (LOG_RADIUS - LOG_WALL))
		outside.append(Vector2(cos(-turn), sin(-turn)) * LOG_RADIUS)
		dark.append(Palette.colour("wood_dark"))
		bark.append(Palette.colour("bark"))
	var length := run.length()
	WorldKit.extrude(hollow, "Inside", inside, dark, length, Transform3D.IDENTITY)
	WorldKit.extrude(hollow, "Outside", outside, bark, length, Transform3D.IDENTITY)
	for end in [-0.5, 0.5]:
		WorldKit.ring(hollow, "End", LOG_RADIUS - LOG_WALL * 0.5, LOG_WALL,
			Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.0, 0.0, float(end) * length)),
			"wood_light", true)
	for i in 9:
		var t := (float(i) + 0.5) / 9.0 - 0.5
		WorldKit.ball(hollow, "Moss", Vector3(4.5, 1.2, 6.0), WorldKit.at(Vector3(0.0, LOG_RADIUS - 0.4,
			t * length * 0.9)), "moss", false)


# --- the bloom glade -------------------------------------------------------------

## The open middle of the valley: a meadow in flower, with tall grass and
## wildflowers to climb and string silk between, brambles of berries, a few
## trees, a ring of standing stones at its heart, a wild hive in a stump and a
## wasps' nest on a dead tree. It is built for the middle sizes, and it is the
## busiest place in the valley by day: bees and butterflies over the flowers and
## wasps hunting them, hares in the grass and a fox after the hares, songbirds in
## the trees, and the stags grazing all of it.
func _bloom_glade() -> void:
	var place := WorldKit.group(self, "BloomGlade")
	var dice := _dice(303)
	var half := Vector2(112.0, 100.0)
	var heart := GLADE + Vector2(-10.0, 10.0)
	var keep: Array[Vector2] = []
	for i in 7:
		var turn := TAU * float(i) / 7.0
		var stone := heart + Vector2(cos(turn), sin(turn)) * 26.0
		_prop(place, "standing_stone", stone, dice, Vector2(0.85, 1.25), 1.5)
		keep.append(stone)

	var trees: Array[Vector2] = [GLADE + Vector2(-85.0, -60.0), GLADE + Vector2(70.0, -78.0),
		GLADE + Vector2(95.0, 40.0), GLADE + Vector2(-92.0, 52.0), GLADE + Vector2(30.0, 80.0),
		GLADE + Vector2(-40.0, -85.0)]
	for i in trees.size():
		_prop(place, "tree_oak" if i % 2 == 0 else "tree_birch", trees[i], dice, Vector2(1.1, 1.5),
			0.5)
		keep.append(trees[i])
	var hive := GLADE + Vector2(48.0, -30.0)
	_prop(place, "beehive", hive, dice, Vector2(1.0, 1.1), 0.4)
	keep.append(hive)
	var wasps := GLADE + Vector2(-58.0, -20.0)
	_prop(place, "wasp_tree", wasps, dice, Vector2(1.0, 1.15), 0.5)
	keep.append(wasps)

	for i in 150:
		_prop(place, "tall_grass", _scatter(dice, GLADE, half, keep, 5.0), dice, Vector2(0.8, 1.5))
	for i in 64:
		_prop(place, "wildflowers", _scatter(dice, GLADE, half, keep, 5.0), dice, Vector2(0.8, 1.5))
	var brambles: Array[Vector2] = []
	for i in 8:
		brambles.append(_scatter(dice, GLADE, half * 0.9, keep, 14.0))
		_prop(place, "berry_bush", brambles[i], dice, Vector2(0.9, 1.3), 0.5)
		keep.append(brambles[i])
	for i in 10:
		_prop(place, "boulder", _scatter(dice, GLADE, half, keep, 10.0), dice, Vector2(1.2, 2.2), 0.6)

	var grass: Array[Vector2] = []
	for i in 14:
		grass.append(_scatter(dice, GLADE, half * 0.85, keep, 10.0))
		_patch(place, "grass", grass[i], 8.0, 80.0, 0.6)
	var flowers: Array[Vector2] = []
	for i in 12:
		flowers.append(_scatter(dice, GLADE, half * 0.85, keep, 10.0))
		_patch(place, "flowers", flowers[i], 5.0, 40.0, 0.4)
	for spot in brambles.slice(0, 5):
		_patch(place, "berries", spot + Vector2(8.0, 0.0), 7.0, 60.0, 0.2)
	for i in 3:
		_patch(place, "moss", _scatter(dice, GLADE, half, keep, 10.0), 5.0, 36.0, 0.2)

	_den(place, "bee", hive, 5, 8, true, 4.0)
	_den(place, "wasp", wasps + Vector2(9.0, 0.0), 3, 5, true, 4.0)
	_den(place, "butterfly", flowers[0], 3, 6, false, 5.0)
	_den(place, "butterfly", flowers[6], 3, 6, false, 5.0)
	_den(place, "midge", flowers[3], 5, 8, false, 4.0)
	_den(place, "hare", grass[2], 2, 4, true, 8.0)
	_den(place, "hare", grass[9], 2, 4, true, 8.0)
	_den(place, "songbird", trees[1] + Vector2(10.0, 0.0), 2, 3, false, 6.0)
	_den(place, "songbird", trees[3] + Vector2(10.0, 0.0), 2, 3, false, 6.0)
	_den(place, "fox", GLADE + Vector2(-100.0, 92.0), 1, 2, true, 8.0)
	_den(place, "deer", GLADE + Vector2(82.0, -90.0), 2, 3, false, 14.0)

	_haunt(place, "Heart", heart, ["deer", "boar", "wolf", "wyvern"], 24.0)
	_haunt(place, "EastMeadow", GLADE + Vector2(70.0, 20.0), ["deer", "wolf"], 24.0)
	_haunt(place, "WestMeadow", GLADE + Vector2(-70.0, 30.0), ["deer", "boar", "wyvern"], 24.0)


# --- putting things down ---------------------------------------------------------

## A die for one part of the level, so that what is scattered there lands in the
## same places every time it is built.
func _dice(seed_value: int) -> RandomNumberGenerator:
	var dice := RandomNumberGenerator.new()
	dice.seed = seed_value
	return dice


## Somewhere in the oval [param half] about [param middle], at least [param clear]
## from everything in [param keep] — tried a few times, and then wherever it fell.
func _scatter(dice: RandomNumberGenerator, middle: Vector2, half: Vector2,
		keep: Array[Vector2] = [], clear := 0.0) -> Vector2:
	var at := middle
	for attempt in 12:
		var turn := dice.randf() * TAU
		at = middle + Vector2(cos(turn) * half.x, sin(turn) * half.y) * sqrt(dice.randf())
		var clean := true
		for spot in keep:
			if at.distance_to(spot) < clear:
				clean = false
				break
		if clean:
			return at
	return at


## One of a prop, on the ground at [param at], turned any way and sized somewhere
## in [param sizes]; sunk [param sink] into the ground, for something that has sat
## there a while.
func _prop(parent: Node3D, id: String, at: Vector2, dice: RandomNumberGenerator,
		sizes := Vector2(0.85, 1.2), sink := 0.0) -> Node3D:
	var size := dice.randf_range(sizes.x, sizes.y)
	var turn := Basis(Vector3.UP, dice.randf() * TAU).scaled(Vector3.ONE * size)
	return Props.place(parent, id, Transform3D(turn, on_ground(at.x, at.y, -sink * size)))


## A patch of [param kind] on the ground at [param at].
func _patch(parent: Node3D, kind: String, at: Vector2, size: float, capacity: float,
		regrow: float, glows := false) -> Forage:
	var patch := Forage.new()
	patch.name = kind.capitalize()
	patch.kind = kind
	patch.size = size
	patch.capacity = capacity
	patch.regrow = regrow
	patch.glows = glows
	patch.position = on_ground(at.x, at.y)
	parent.add_child(patch, true)
	return patch


## A den of [param id] on the ground at [param at], opening with [param start] of
## them and holding [param capacity]. [param shelters]: somewhere to rest out of
## sight, a burrow or a hole; not, somewhere in the open.
func _den(parent: Node3D, id: String, at: Vector2, start: int, capacity: int,
		shelters: bool, spread := 3.0) -> Den:
	var den := Den.new()
	den.name = id.capitalize() + "Den"
	den.species_id = id
	den.start = start
	den.capacity = capacity
	den.shelters = shelters
	den.spread = spread
	den.position = on_ground(at.x, at.y, 0.2)
	parent.add_child(den, true)
	return den


## A haunt for [param kinds] at [param at], [param radius] across.
func _haunt(parent: Node3D, part_name: String, at: Vector2, kinds: Array[String],
		radius: float) -> Haunt:
	var haunt := Haunt.new()
	haunt.name = part_name
	haunt.species_ids = PackedStringArray(kinds)
	haunt.radius = radius
	haunt.position = on_ground(at.x, at.y)
	parent.add_child(haunt, true)
	return haunt


# --- the spider -----------------------------------------------------------------

## Puts the spider where a new one starts, in the middle of the stump facing the
## way out. It is in the scene rather than built here, so this moves the one that
## is there — which is also where the kill plane puts it back.
func _place_the_spider() -> void:
	var holder := get_parent()
	var spider := holder.get_node_or_null("Player") as Node3D if holder != null else null
	if spider != null:
		spider.global_transform = Transform3D(Basis.IDENTITY,
			on_ground(CAMP.x, CAMP.y, SPAWN_HEIGHT))
