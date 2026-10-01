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
