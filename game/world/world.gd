class_name SpiderWorld
extends Node3D

## The whole world: a garden shed, the sewers under the park, and the park with
## its lake.
##
## Three places in one space rather than three scenes, because the payoff of a
## game about scale is standing by the lake and looking back at the shed you
## started in — and that only works if the shed is really over there.
##
## It is laid out as a way down and then out. The spider starts in the shed at
## the west edge of the park and goes down the drain in its floor into the sewers
## that run under the park; a storm grate brings it back up onto the park's main
## path, and the path runs on east to the lake. Each place is built for a stretch
## of the tier table, and the gate out of one gives when the spider is big enough
## for the next.
##
## Everything is to one scale, the scale of the [Props] — a metre is about
## fourteen of the world's units — so the shed is a shed and a rowing boat is a
## boat. The places are the size they would be. What they are built for is how big
## the spider is by the time it gets there.
##
## Built in code because that is how everything else in this project makes
## geometry: [WorldKit] solids painted from the [Palette], and the props, which
## are baked into scenes of their own and placed here as instances. The constants
## below are the layout.
##
## **This no longer runs at load.** The level is baked into its .tscn as real
## nodes so it can be moved about in the editor, and the script is taken off the
## node when that happens. What is here is the generator of record: run
##
##     godot --headless --path . --script res://tools/bake_level.gd -- world --force
##
## to build the shape again from scratch, which **throws away anything moved by
## hand**. Without --force the bake leaves a baked level alone.

# --- outdoors ------------------------------------------------------------

## The grass everything stands on. Its top is at nought.
const GROUND_LO := Vector3(-240.0, -2.0, -240.0)
const GROUND_HI := Vector3(520.0, 0.0, 240.0)

## The way the sunlight goes: down, and from the south-east, so that it comes in
## at the shed's window.
const SUNLIGHT := Vector3(-0.5, -0.8, -0.45)

# --- the shed, at the west edge of the park -------------------------------

## The inside of the shed, floor to eaves. The roof rises from the eaves to a
## ridge down the middle, the length of it.
const SHED_LO := Vector3(-186.0, 1.0, -15.0)
const SHED_HI := Vector3(-148.0, 27.0, 15.0)
const RIDGE := 37.0

## Plank walls, a board thick.
const BOARD := 1.0

## The door, in the east wall: across it (z) and up it (y).
const DOOR := Rect2(-6.0, 1.0, 12.0, 21.0)

## The window, in the south wall: along it (x) and up it (y).
const WINDOW := Rect2(-172.0, 11.0, 12.0, 9.0)

## The drain in the shed floor, and how far down the shaft under it goes: to the
## roof of the chamber under the shed. Its south side is that chamber's south
## wall, so the rungs down the shaft go on down the wall to the walkway.
const DRAIN_LO := Vector2(-168.6, 2.8)
const DRAIN_HI := Vector2(-165.4, 6.0)
const DRAIN_BOTTOM := -4.5

## Where a new spider starts: on the shed floor, between the bench and the drain,
## facing the drain.
const SPAWN := Vector3(-173.0, 1.4, 6.5)

# --- the sewers, under the park -------------------------------------------

## The line the sewer runs along, west to east under the park, and its section:
## a channel of water down the middle, a walkway either side of it behind a kerb,
## upright walls, and an arched roof springing from them.
const SEWER_Z := -4.0
## Half the channel's width, and half the tunnel's, wall to wall.
const CHANNEL := 4.0
const WALKWAY := 10.0
## The channel's bottom, the walkways, the top of the water, and where the arch
## springs from the walls.
const BED := -26.0
const WALK := -23.0
const WATER_TOP := -23.8
const SPRING := -16.0

## The three chambers the tunnel runs between, walkway to ceiling: the one under
## the shed that the drain comes down into, the hall halfway along where a pipe
## comes in from the north, and the one under the park where the storm drain goes
## up.
const DRAIN_ROOM_LO := Vector3(-178.0, WALK, -16.0)
const DRAIN_ROOM_HI := Vector3(-154.0, -5.0, 6.0)
const HALL_LO := Vector3(-64.0, WALK, -30.0)
const HALL_HI := Vector3(-24.0, -4.0, 22.0)
const STORM_ROOM_LO := Vector3(10.0, WALK, -16.0)
const STORM_ROOM_HI := Vector3(34.0, -5.0, 8.0)

## Where the channel starts in the drain chamber, and where it ends in the storm
## chamber, at a grating.
const CHANNEL_FROM := -178.0
const CHANNEL_TO := 22.0

## The pipe into the hall from the north, and where it ends.
const PIPE_X := -44.0
const PIPE_RADIUS := 5.0
const PIPE_END := -70.0

## The storm drain up to the park: a shaft from the storm chamber's roof to the
## grate on the park's main path, against the chamber's east wall.
const STORM_LO := Vector2(26.0, -8.0)
const STORM_HI := Vector2(34.0, 0.0)

## All of the sewers, for the zone.
const SEWERS_LO := Vector3(-180.0, -28.0, -72.0)
const SEWERS_HI := Vector3(36.0, -4.0, 24.0)

# --- the park ------------------------------------------------------------

## The park: the grass between the shed and the lake.
const PARK_LO := Vector3(-130.0, 0.0, -120.0)
const PARK_HI := Vector3(110.0, 120.0, 120.0)

## Half the width of the main path, which runs from the shed door east to the
## lake, and the reach of the paved ring round the storm grate on it.
const PATH_HALF := 9.0
const PLAZA := 24.0

## The animal area in the north-west corner, and the gap in its fence.
const PETS_LO := Vector2(-120.0, -110.0)
const PETS_HI := Vector2(-40.0, -30.0)
const PETS_GATE := Vector2(-80.0, -60.0)

## How far out the hedge round the park stands, north and south, and at the back
## of the shed.
const HEDGE := 124.0
const HEDGE_WEST := -205.0

# --- the lake -------------------------------------------------------------

## The lake: past the railings at the east end of the park, the park's second
## half.
const LAKE_LO := Vector3(110.0, -24.0, -180.0)
const LAKE_HI := Vector3(484.0, 120.0, 180.0)

## Its middle, how far out the water reaches, where the stone bank round it tops
## out, and how far the paving round that goes.
const LAKE_MIDDLE := Vector3(290.0, 0.0, 0.0)
const WATER_EDGE := 140.0
const BANK := 144.0
const PROMENADE := 169.0

## The top of the water, and the bottom of the lake.
const LAKE_TOP := -1.5
const LAKE_BED := -22.0

## The island in the middle: how high its grass is and how far across, and the
## ring the boats go round it on.
const ISLAND_TOP := 5.0
const ISLAND := 22.0
const BOAT_RING := 88.0

## How far out from the middle the jetty stops: just short of where the boats go
## by, so a spider at the end of it can step aboard.
const JETTY_END := 97.0

## Half the gap in the railings that the path comes through.
const GATEWAY := 12.0


func _ready() -> void:
	build()


func build() -> void:
	_sky()
	_ground()
	_shed()
	_sewers()
	_park()
	_lake()
	_place_the_spider()


# --- outdoors ------------------------------------------------------------

## A day sky and one sun. The sun lights everything outdoors, and the shed and
## the sewers are closed boxes it only reaches through their windows and grates;
## a little light from everywhere keeps what it misses from going black.
func _sky() -> void:
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = Color(0.36, 0.56, 0.84)
	sky.sky_horizon_color = Color(0.74, 0.81, 0.88)
	sky.ground_bottom_color = Color(0.28, 0.32, 0.26)
	sky.ground_horizon_color = Color(0.66, 0.72, 0.7)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.sky.sky_material = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.74, 0.76, 0.8)
	environment.ambient_light_energy = 0.35
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.name = "Sky"
	world.environment = environment
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 320.0
	add_child(sun)
	sun.global_position = Vector3(0.0, 200.0, 0.0)
	sun.look_at(sun.global_position + SUNLIGHT, Vector3.UP)


## The grass, with holes let into it where something goes down through it.
func _ground() -> void:
	var ground := WorldKit.body(self, "Ground")
	WorldKit.slab(ground, "Grass", GROUND_LO, GROUND_HI, _holes_in_the_ground(), "grass")


## Where the ground is open: the drain shaft under the shed, and the storm drain
## up from the sewers.
func _holes_in_the_ground() -> Array[Rect2]:
	var holes: Array[Rect2] = [Rect2(DRAIN_LO, DRAIN_HI - DRAIN_LO),
		Rect2(STORM_LO, STORM_HI - STORM_LO)]
	# The lake, as three rectangles crossed over its middle: between them they clear
	# its bowl, and every corner of them is under the paving that goes round it.
	for turn in [31.8, 45.0, 58.2]:
		var half := Vector2(cos(deg_to_rad(turn)), sin(deg_to_rad(turn))) * PROMENADE
		holes.append(Rect2(LAKE_MIDDLE.x - half.x, LAKE_MIDDLE.z - half.y, half.x * 2.0,
			half.y * 2.0))
	return holes


# --- the shed ------------------------------------------------------------

## A garden shed on a concrete base: plank walls, a window to the south and a door
## to the east, a pitched roof on its rafters, shelves along the back and a bench
## along the end. The spider starts here, and a spiderling finds it enormous: a
## paint tin is ten of it tall, and the bench is a cliff with a view.
##
## It taxes nothing. It is dry and still, and nothing comes through to take silk
## back off you; what it teaches is anchors, and there is always one in reach.
## The way on is the drain in the floor, under an iron lid that gives to a
## Huntsman — or to a Hollow Frame lean enough to fold through its slots.
func _shed() -> void:
	var zone := Zone.make(self, "The Shed", SHED_LO, Vector3(SHED_HI.x, RIDGE, SHED_HI.z),
		Vector2(0.25, 0.7))
	_shed_shell(zone)
	_shed_roof(zone)
	_shed_insides(zone)
	_shed_yard(zone)
	_drain(zone)
	Props.place(zone, "bulb", WorldKit.at(Vector3(-167.0, RIDGE - 0.7, 0.0)))
	_indoors(zone, "Indoors", SHED_LO - Vector3(BOARD, 1.0, BOARD),
		Vector3(SHED_HI.x + BOARD, RIDGE + 1.0, SHED_HI.z + BOARD), Color(0.82, 0.74, 0.64), 0.3)
	_stock(zone, "Insects", Vector3(-167.0, 9.0, -2.0), Vector3(34.0, 14.0, 24.0),
		["midge", "mosquito", "fly", "ant", "beetle", "wasp"], 9)
	# Moths where moths always are: round the bulb.
	_stock(zone, "Moths", Vector3(-167.0, 22.0, 0.0), Vector3(10.0, 4.0, 10.0), ["moth"], 3)


## The floor, the four walls and the gable ends.
func _shed_shell(zone: Node3D) -> void:
	var lo := SHED_LO
	var hi := SHED_HI
	var shell := WorldKit.body(zone, "Shell")
	var drain: Array[Rect2] = [Rect2(DRAIN_LO, DRAIN_HI - DRAIN_LO)]
	var outer_lo := Vector3(lo.x - BOARD, 0.0, lo.z - BOARD)
	var outer_hi := Vector3(hi.x + BOARD, lo.y, hi.z + BOARD)
	# One slab to stand on, with the drain through it: a floor of boards to look at
	# is forty seams to catch on, so the boards are only drawn.
	WorldKit.slab(shell, "Floor", outer_lo, outer_hi, drain)
	WorldKit.slab(shell, "Base", outer_lo, Vector3(outer_hi.x, lo.y - 0.1, outer_hi.z), drain,
		"concrete", false)
	var z := lo.z
	var n := 0
	while z < hi.z - 0.01:
		var next := minf(z + 2.5, hi.z)
		var paint := "wood" if n % 2 == 0 else "wood_warm"
		if next > DRAIN_LO.y and z < DRAIN_HI.y:
			WorldKit.block(shell, "Floorboard", Vector3(lo.x, lo.y - 0.1, z),
				Vector3(DRAIN_LO.x - 0.6, lo.y, next), paint, false)
			WorldKit.block(shell, "Floorboard", Vector3(DRAIN_HI.x + 0.6, lo.y - 0.1, z),
				Vector3(hi.x, lo.y, next), paint, false)
		else:
			WorldKit.block(shell, "Floorboard", Vector3(lo.x, lo.y - 0.1, z),
				Vector3(hi.x, lo.y, next), paint, false)
		z = next
		n += 1

	# The walls stand round the outside of the floor, so the room is the size asked
	# for. The long ones run the full length, corners and all.
	_plank_wall(shell, Vector3(lo.x - BOARD, lo.y, lo.z - BOARD), Vector3(hi.x + BOARD, hi.y, lo.z), 0)
	_plank_wall(shell, Vector3(lo.x - BOARD, lo.y, hi.z), Vector3(hi.x + BOARD, hi.y, hi.z + BOARD), 0,
		WINDOW)
	_plank_wall(shell, Vector3(lo.x - BOARD, lo.y, lo.z), Vector3(lo.x, hi.y, hi.z), 2)
	_plank_wall(shell, Vector3(hi.x, lo.y, lo.z), Vector3(hi.x + BOARD, hi.y, hi.z), 2)
	# Gable ends, up to the ridge.
	for x in [lo.x - BOARD * 0.5, hi.x + BOARD * 0.5]:
		WorldKit.prism(shell, "Gable", Vector3(hi.z - lo.z + BOARD * 2.0, RIDGE - hi.y, BOARD),
			Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(x, (hi.y + RIDGE) * 0.5, 0.0)), "wood")

	_window(zone, shell)
	_door(shell)


## A wall of upright boards between two corners, running along [param along]
## (0 for x, 2 for z). Solid as one piece, or as the four round [param hole] if it
## has one (along the wall and up it); the boards are drawn over it in turn in two
## tones, and stop at the hole.
func _plank_wall(on: Node3D, lo: Vector3, hi: Vector3, along: int, hole := Rect2()) -> void:
	for piece in _around(lo, hi, along, hole):
		WorldKit.collider(on, "Wall", piece.size, Transform3D(Basis.IDENTITY, piece.get_center()))
	var a: float = lo[along]
	var n := 0
	while a < hi[along] - 0.01:
		var b := minf(a + 2.4, hi[along])
		var board_lo := lo
		var board_hi := hi
		board_lo[along] = a
		board_hi[along] = b
		var paint := "wood" if n % 2 == 0 else "wood_warm"
		if hole.has_area() and b > hole.position.x and a < hole.end.x:
			if hole.position.y > lo.y:
				var under := board_hi
				under.y = hole.position.y
				WorldKit.block(on, "Board", board_lo, under, paint, false)
			if hole.end.y < hi.y:
				var over := board_lo
				over.y = hole.end.y
				WorldKit.block(on, "Board", over, board_hi, paint, false)
		else:
			WorldKit.block(on, "Board", board_lo, board_hi, paint, false)
		a = b
		n += 1


## A wall between two corners as boxes: all of it, or the four pieces round a hole
## given along it and up it.
func _around(lo: Vector3, hi: Vector3, along: int, hole: Rect2) -> Array[AABB]:
	var pieces: Array[AABB] = []
	if not hole.has_area():
		pieces.append(AABB(lo, hi - lo))
		return pieces
	var spans := [
		[lo[along], hole.position.x, lo.y, hi.y],
		[hole.end.x, hi[along], lo.y, hi.y],
		[hole.position.x, hole.end.x, lo.y, hole.position.y],
		[hole.position.x, hole.end.x, hole.end.y, hi.y],
	]
	for span in spans:
		if span[1] - span[0] <= 0.001 or span[3] - span[2] <= 0.001:
			continue
		var from := lo
		var to := hi
		from[along] = span[0]
		to[along] = span[1]
		from.y = span[2]
		to.y = span[3]
		pieces.append(AABB(from, to - from))
	return pieces


## The window in the south wall: glass in a frame with a bar across each way, and
## a sill inside to sit on. The glass is its own body, in the group the climbing
## will not stick to, because nothing walks up a window.
func _window(zone: Node3D, shell: Node3D) -> void:
	var hole := WINDOW
	var z := SHED_HI.z + BOARD * 0.5
	var glass := WorldKit.body(zone, "Window")
	glass.add_to_group("no_climb", true)
	WorldKit.box(glass, "Glass", Vector3(hole.size.x, hole.size.y, 0.15),
		WorldKit.at(Vector3(hole.get_center().x, hole.get_center().y, z)), "glass")
	var frame := 0.5
	for side in [-1.0, 1.0]:
		var x: float = hole.get_center().x + side * (hole.size.x * 0.5 + frame * 0.5)
		WorldKit.box(shell, "Frame", Vector3(frame, hole.size.y + frame * 2.0, BOARD + 0.3),
			WorldKit.at(Vector3(x, hole.get_center().y, z)), "wood_dark")
	WorldKit.box(shell, "Frame", Vector3(hole.size.x, frame, BOARD + 0.3),
		WorldKit.at(Vector3(hole.get_center().x, hole.end.y + frame * 0.5, z)), "wood_dark")
	WorldKit.box(shell, "Sill", Vector3(hole.size.x + 1.4, 0.5, 2.6),
		WorldKit.at(Vector3(hole.get_center().x, hole.position.y - 0.25, z - 0.6)), "wood_dark")
	WorldKit.box(shell, "Bar", Vector3(0.4, hole.size.y, 0.4),
		WorldKit.at(Vector3(hole.get_center().x, hole.get_center().y, z)), "wood_dark")
	WorldKit.box(shell, "Bar", Vector3(hole.size.x, 0.4, 0.4),
		WorldKit.at(Vector3(hole.get_center().x, hole.get_center().y, z)), "wood_dark")


## The door in the east wall, shut: planks in a frame on both faces, braced on the
## outside, a latch each side.
func _door(shell: Node3D) -> void:
	var door := DOOR
	for side in [-1.0, 1.0]:
		var x: float = SHED_HI.x + BOARD * 0.5 + side * (BOARD * 0.5 + 0.1)
		WorldKit.box(shell, "Door", Vector3(0.2, door.size.y, door.size.x),
			WorldKit.at(Vector3(x, door.get_center().y, door.get_center().x)), "wood_light", false)
		var edge: float = x + side * 0.15
		for z in [door.position.x - 0.3, door.end.x + 0.3]:
			WorldKit.box(shell, "Jamb", Vector3(0.3, door.size.y + 0.6, 0.6),
				WorldKit.at(Vector3(edge, door.get_center().y + 0.3, z)), "wood_dark", false)
		WorldKit.box(shell, "Head", Vector3(0.3, 0.6, door.size.x + 1.2),
			WorldKit.at(Vector3(edge, door.end.y + 0.3, door.get_center().x)), "wood_dark", false)
		WorldKit.ball(shell, "Latch", Vector3.ONE * 0.45,
			WorldKit.at(Vector3(edge + side * 0.3, 11.0, door.position.x + 1.4)), "iron", false)
		if side > 0.0:
			for y in [door.position.y + 3.0, door.end.y - 3.0]:
				WorldKit.box(shell, "Ledge", Vector3(0.3, 1.4, door.size.x - 0.6),
					WorldKit.at(Vector3(edge, y, door.get_center().x)), "wood_dark", false)
			var brace := Vector3(edge, door.get_center().y, door.get_center().x)
			var rise := door.size.y - 6.0
			WorldKit.box(shell, "Brace", Vector3(0.3, sqrt(rise * rise + door.size.x * door.size.x)
				* 0.9, 1.2), Transform3D(Basis(Vector3.RIGHT, atan2(door.size.x, rise)), brace),
				"wood_dark", false)


## The pitched roof and what holds it up: two slopes of felt meeting at a capped
## ridge, and inside, a rafter pair every few steps with a tie beam across its
## foot, a ridge beam, and the plates along the tops of the walls. The tie beams
## are the shed's first crossing: a spiderling that gets up to one can walk from
## wall to wall.
func _shed_roof(zone: Node3D) -> void:
	var lo := SHED_LO
	var hi := SHED_HI
	var roof := WorldKit.body(zone, "Roof")
	var rise := RIDGE - hi.y
	var run := hi.z + BOARD
	var reach := run + 2.4
	var eave := RIDGE - reach * rise / run
	var ends := Vector2(lo.x - BOARD - 3.0, hi.x + BOARD + 3.0)
	for side in [-1.0, 1.0]:
		WorldKit.plate(roof, "Slope", PackedVector3Array([
			Vector3(ends.x, RIDGE + 0.5, 0.0), Vector3(ends.y, RIDGE + 0.5, 0.0),
			Vector3(ends.y, eave + 0.5, side * reach), Vector3(ends.x, eave + 0.5, side * reach)]),
			0.8, "roof")
	WorldKit.rod(roof, "Cap", Vector3(ends.x, RIDGE + 1.0, 0.0), Vector3(ends.y, RIDGE + 1.0, 0.0),
		0.8, "roof")

	var x := lo.x + 2.5
	while x < hi.x:
		for side in [-1.0, 1.0]:
			WorldKit.rod(roof, "Rafter", Vector3(x, hi.y, side * hi.z), Vector3(x, RIDGE - 0.6, 0.0),
				0.5, "wood_dark")
		WorldKit.rod(roof, "Tie", Vector3(x, hi.y - 0.4, lo.z), Vector3(x, hi.y - 0.4, hi.z), 0.55,
			"wood_dark")
		x += 5.5
	WorldKit.rod(roof, "RidgeBeam", Vector3(lo.x, RIDGE - 0.8, 0.0), Vector3(hi.x, RIDGE - 0.8, 0.0),
		0.7, "wood_dark")
	for z in [lo.z + 0.5, hi.z - 0.5]:
		WorldKit.rod(roof, "WallPlate", Vector3(lo.x, hi.y - 0.5, z), Vector3(hi.x, hi.y - 0.5, z), 0.5,
			"wood_dark")


## What is in the shed: the bench along the west wall with a pegboard of tools
## over it, two shelving units along the back loaded with tins and pots, garden
## tools leaning on the walls, the mower, and the odd thing left on the floor.
func _shed_insides(zone: Node3D) -> void:
	var things := WorldKit.group(zone, "Things")
	var floor_y := SHED_LO.y
	var facing_east := Basis(Vector3.UP, -PI * 0.5)
	var facing_south := Basis(Vector3.UP, PI)

	# The bench, its back to the west wall, and the pegboard over it.
	var bench := Vector3(SHED_LO.x + 4.4, floor_y, 2.4)
	Props.place(things, "workbench", Transform3D(facing_east, bench))
	Props.place(things, "pegboard", Transform3D(facing_east, Vector3(SHED_LO.x + 0.2, 15.0, 2.4)))
	# Tools on the pegs, hanging by their handles with their flat side to the board.
	var hanging := Basis(Vector3(0.0, -1.0, 0.0), Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.0, 1.0))
	var pegs := [["saw", -4.6], ["hammer", 0.1], ["spanner", 4.9], ["screwdriver", 9.4]]
	for peg in pegs:
		Props.place(things, peg[0], Transform3D(hanging, Vector3(SHED_LO.x + 0.6, 21.3,
			float(peg[1]))))
	# On the bench top.
	var top := floor_y + 12.5
	var on_bench := [
		["toolbox", Vector3(SHED_LO.x + 4.0, top, -6.0), 90.0],
		["jar", Vector3(SHED_LO.x + 2.2, top, 0.4), 0.0],
		["oil_can", Vector3(SHED_LO.x + 6.4, top, -1.2), 30.0],
		["hammer", Vector3(SHED_LO.x + 5.4, top, 3.6), 70.0],
		["seed_tray", Vector3(SHED_LO.x + 3.6, top, 7.4), 90.0],
		["twine", Vector3(SHED_LO.x + 6.8, top, 10.0), 0.0],
	]
	for thing in on_bench:
		Props.place(things, thing[0], WorldKit.at(thing[1], thing[2]))

	# The shelving along the back, and what is on it, a board at a time.
	var shelf_z := SHED_LO.z + 2.5
	for x in [-176.2, -158.7]:
		Props.place(things, "shelves", Transform3D(facing_south, Vector3(x, floor_y, shelf_z)))
	var boards := [floor_y + 0.6, floor_y + 6.7, floor_y + 12.8, floor_y + 18.9]
	var z := shelf_z + 0.2
	var loaded := [
		[0, "paint_tin_red", -182.0], [0, "paint_tin_blue", -178.8], [0, "paint_tin_white", -175.6],
		[0, "bucket", -171.3],
		[1, "flowerpot_stack", -182.4], [1, "flowerpot_stack", -179.4], [1, "seed_tray", -173.6],
		[2, "jar", -183.0], [2, "jar", -181.2], [2, "jar", -179.4], [2, "oil_can", -176.0],
		[2, "twine", -172.4],
		[3, "paint_tin_yellow", -182.4], [3, "paint_tin_red", -179.2], [3, "flowerpot", -175.0],
		[3, "flowerpot", -172.2],
		[0, "toolbox", -162.4], [0, "paint_tin_white", -155.8], [0, "paint_tin_blue", -152.8],
		[1, "sack", -162.2], [1, "jar", -156.2], [1, "flowerpot", -153.2],
		[2, "seed_tray", -163.4], [2, "seed_tray", -157.6], [2, "twine", -153.0],
		[3, "flowerpot_stack", -164.0], [3, "flowerpot_stack", -160.8], [3, "paint_tin_yellow",
			-155.4],
	]
	for thing in loaded:
		Props.place(things, thing[1], WorldKit.at(Vector3(thing[2], boards[thing[0]], z)))

	# Leaning on the walls, and standing about on the floor.
	var lean := deg_to_rad(8.0)
	Props.place(things, "spade", Transform3D(Basis(Vector3.RIGHT, lean), Vector3(-175.1, floor_y,
		SHED_HI.z - 2.6)))
	Props.place(things, "rake", Transform3D(Basis(Vector3.RIGHT, lean), Vector3(-157.0, floor_y,
		SHED_HI.z - 3.4)))
	Props.place(things, "broom", Transform3D(Basis(Vector3.RIGHT, lean * 0.6), Vector3(-151.6,
		floor_y, SHED_HI.z - 3.2)))
	var on_floor := [
		["lawnmower", Vector3(-154.0, floor_y, 3.0), 0.0],
		["sack", Vector3(-152.4, floor_y, -7.9), 0.0],
		["hose", Vector3(-172.0, floor_y, -7.0), 0.0],
		["watering_can", Vector3(-163.0, floor_y, -6.8), 60.0],
		["bucket", Vector3(-160.5, floor_y, 11.2), 0.0],
		["flowerpot_stack", Vector3(-164.6, floor_y, 12.4), 0.0],
	]
	for thing in on_floor:
		Props.place(things, thing[0], WorldKit.at(thing[1], thing[2]))


## Round the outside: a water butt at the corner by the door, the compost bin at
## the back, a barrow and some pots.
func _shed_yard(zone: Node3D) -> void:
	var yard := WorldKit.group(zone, "Yard")
	var outside := [
		["water_butt", Vector3(-141.5, 0.0, -11.0), 0.0],
		["compost_bin", Vector3(-196.0, 0.0, 6.0), 10.0],
		["wheelbarrow", Vector3(-138.0, 0.0, 16.0), -120.0],
		["crate", Vector3(-141.0, 0.0, -21.0), 15.0],
		["flowerpot", Vector3(-143.6, 0.0, 9.0), 0.0],
		["flowerpot", Vector3(-143.4, 0.0, 11.6), 0.0],
		["flowerpot_stack", Vector3(-176.0, 0.0, 19.6), 0.0],
	]
	for thing in outside:
		Props.place(yard, thing[0], WorldKit.at(thing[1], thing[2]))


## The way down: a stone shaft under the drain, iron rungs down one side of it,
## and over it an iron lid in a frame, which is the gate. It gives to a Huntsman,
## or to a Hollow Frame lean enough to fold through its slots.
func _drain(zone: Node3D) -> void:
	var shaft := WorldKit.body(zone, "DrainShaft")
	var lo := DRAIN_LO
	var hi := DRAIN_HI
	var t := BOARD
	var top := GROUND_LO.y
	WorldKit.block(shaft, "West", Vector3(lo.x - t, DRAIN_BOTTOM, lo.y - t), Vector3(lo.x, top,
		hi.y + t), "stone")
	WorldKit.block(shaft, "East", Vector3(hi.x, DRAIN_BOTTOM, lo.y - t), Vector3(hi.x + t, top,
		hi.y + t), "stone")
	WorldKit.block(shaft, "North", Vector3(lo.x, DRAIN_BOTTOM, lo.y - t), Vector3(hi.x, top, lo.y),
		"stone")
	WorldKit.block(shaft, "South", Vector3(lo.x, DRAIN_BOTTOM, hi.y), Vector3(hi.x, top, hi.y + t),
		"stone")
	_rungs(shaft, Vector3((lo.x + hi.x) * 0.5, top - 0.8, hi.y), Vector3.FORWARD, DRAIN_BOTTOM,
		1.2, 0.5)

	var frame := WorldKit.body(zone, "DrainFrame")
	var y := SHED_LO.y + 0.03
	for piece in [
		[Vector3(lo.x - 0.5, y - 0.1, lo.y - 0.5), Vector3(hi.x + 0.5, y, lo.y)],
		[Vector3(lo.x - 0.5, y - 0.1, hi.y), Vector3(hi.x + 0.5, y, hi.y + 0.5)],
		[Vector3(lo.x - 0.5, y - 0.1, lo.y), Vector3(lo.x, y, hi.y)],
		[Vector3(hi.x, y - 0.1, lo.y), Vector3(hi.x + 0.5, y, hi.y)],
	]:
		WorldKit.block(frame, "Frame", piece[0], piece[1], "iron", false)

	var lid := Threshold.make(zone, Vector3(lo.x, SHED_LO.y - 0.6, lo.y), Vector3(hi.x, SHED_LO.y,
		hi.y), 0.7, "DrainLid", "hollow_frame")
	_dress(lid, "iron", 4)


## Paints a gate's plug and cuts slots in the top of it — drawn, as children of the
## plug, so they go when it does. A gate is built as a box, and a box in the floor
## reads as a box; slots are what make it a drain.
func _dress(gate: Threshold, paint: String, slots: int) -> void:
	var plug := gate.get_node_or_null("Plug") as StaticBody3D
	if plug == null:
		return
	var view := plug.get_node_or_null("Mesh") as MeshInstance3D
	if view != null:
		view.material_override = Palette.paint(paint)
	var shape := plug.get_node_or_null("Shape") as CollisionShape3D
	var box := shape.shape as BoxShape3D if shape != null else null
	if box == null:
		return
	var size := box.size
	for i in slots:
		var across := (float(i) + 1.0) / float(slots + 1) - 0.5
		WorldKit.box(plug, "Slot", Vector3(size.x * 0.72, 0.04, size.z * 0.06),
			WorldKit.at(Vector3(0.0, size.y * 0.5 + 0.01, across * size.z)), "black", false)


# --- the sewers ----------------------------------------------------------

## The sewers: one long tunnel of grey stone under the park, a channel of green
## water down the middle of it and a walkway either side, running between three
## chambers — the one under the shed that the drain comes down into, a hall
## halfway along with a pipe coming in from the north, and the one under the park
## where the storm drain goes up.
##
## It is the first place that fights back. The rats are bigger than a Huntsman and
## come for one, the roaches run, the bats hang up in the dark of the hall, and
## the water is somewhere a web cannot go. The way out is the storm grate at the
## top of the shaft in the far chamber, which gives to a Sewer Widow — or to a
## Storm Rider, who can ride the draught up through its slots.
func _sewers() -> void:
	var zone := Zone.make(self, "The Sewers", SEWERS_LO, SEWERS_HI, Vector2(0.7, 2.0))
	# Past the stone on every side, so the ceilings and the far walls are in it too,
	# and short of the grass.
	_indoors(zone, "Underground", SEWERS_LO - Vector3(3.0, 3.0, 3.0),
		Vector3(SEWERS_HI.x + 3.0, GROUND_LO.y - 0.2, SEWERS_HI.z + 3.0), Color(0.5, 0.55, 0.52), 0.14)
	var drain_hole: Array[Rect2] = [Rect2(DRAIN_LO, DRAIN_HI - DRAIN_LO)]
	var storm_hole: Array[Rect2] = [Rect2(STORM_LO, STORM_HI - STORM_LO)]
	var drain_room := _chamber(zone, "DrainChamber", DRAIN_ROOM_LO, DRAIN_ROOM_HI,
		Vector2(CHANNEL_FROM, DRAIN_ROOM_HI.x), ["east"], drain_hole)
	_tunnel(zone, "WestTunnel", DRAIN_ROOM_HI.x, HALL_LO.x)
	var no_shafts: Array[Rect2] = []
	var hall := _chamber(zone, "Hall", HALL_LO, HALL_HI, Vector2(HALL_LO.x, HALL_HI.x),
		["west", "east"], no_shafts, true)
	_tunnel(zone, "EastTunnel", HALL_HI.x, STORM_ROOM_LO.x)
	var storm_room := _chamber(zone, "StormChamber", STORM_ROOM_LO, STORM_ROOM_HI,
		Vector2(STORM_ROOM_LO.x, CHANNEL_TO), ["west"], storm_hole)
	_pipe(zone)

	# Down from the shed: the rungs in the drain shaft go on down the chamber wall.
	_rungs(drain_room, Vector3((DRAIN_LO.x + DRAIN_HI.x) * 0.5, DRAIN_ROOM_HI.y - 0.6,
		DRAIN_ROOM_HI.z), Vector3.FORWARD, WALK + 0.6, 1.2, 0.5)
	Props.place(zone, "pipe_mouth", WorldKit.at(Vector3(CHANNEL_FROM, WALK + 1.8, SEWER_Z), -90.0))
	Props.place(zone, "valve_wheel", WorldKit.at(Vector3(-160.0, -15.0, DRAIN_ROOM_LO.z), 180.0))
	_lamp(zone, Vector3(-170.0, -13.0, DRAIN_ROOM_LO.z), 180.0)

	# The hall: pillars to the roof, ribs across it, a bridge over the channel, and
	# what has washed up in it.
	for x in [HALL_LO.x + 10.0, HALL_HI.x - 10.0]:
		for z in [HALL_LO.z + 10.0, HALL_HI.z - 10.0]:
			WorldKit.box(hall, "Pillar", Vector3(3.0, HALL_HI.y - WALK, 3.0),
				WorldKit.at(Vector3(x, (WALK + HALL_HI.y) * 0.5, z)), "stone")
	var x := HALL_LO.x + 4.0
	while x < HALL_HI.x:
		WorldKit.block(hall, "Rib", Vector3(x - 0.7, HALL_HI.y - 1.6, HALL_LO.z),
			Vector3(x + 0.7, HALL_HI.y, HALL_HI.z), "stone")
		x += 8.0
	WorldKit.block(hall, "Bridge", Vector3(PIPE_X - 3.0, WALK + 0.4, SEWER_Z - CHANNEL - 0.8),
		Vector3(PIPE_X + 3.0, WALK + 1.0, SEWER_Z + CHANNEL + 0.8), "stone")
	Props.place(zone, "tyre", WorldKit.at(Vector3(-36.0, BED, SEWER_Z + 1.0)))
	Props.place(zone, "crate", WorldKit.at(Vector3(-30.0, WALK, 16.0), 20.0))
	Props.place(zone, "crate", WorldKit.at(Vector3(-58.0, WALK, -24.0), -12.0))
	_lamp(zone, Vector3(-44.0, -12.0, HALL_HI.z), 0.0)
	_lamp(zone, Vector3(-58.0, -12.0, HALL_LO.z), 180.0)

	# The storm chamber: the channel ends at a grating, and rungs go up the east
	# wall and the shaft to the grate.
	for i in 5:
		WorldKit.rod(storm_room, "Grating", Vector3(CHANNEL_TO, BED, SEWER_Z - 3.0 + float(i) * 1.5),
			Vector3(CHANNEL_TO, WALK + 1.0, SEWER_Z - 3.0 + float(i) * 1.5), 0.25, "iron")
	_rungs(storm_room, Vector3(STORM_ROOM_HI.x, -0.9, (STORM_LO.y + STORM_HI.y) * 0.5),
		Vector3.LEFT, WALK + 0.6, 1.2, 0.6)
	_lamp(zone, Vector3(18.0, -12.0, STORM_ROOM_LO.z), 180.0)
	_storm_drain(zone)

	# Rats and roaches on the walkways and in the pipe, bats up in the hall, and
	# midges over the water.
	_stock(zone, "Rats", Vector3(-110.0, WALK + 2.0, SEWER_Z + 7.4), Vector3(80.0, 3.0, 4.0),
		["rat", "cockroach"], 4)
	_stock(zone, "HallFloor", Vector3(-44.0, WALK + 2.0, 12.0), Vector3(34.0, 3.0, 16.0),
		["rat", "cockroach"], 4)
	_stock(zone, "Bats", Vector3(-44.0, -18.0, -6.0), Vector3(30.0, 4.0, 40.0), ["bat"], 4, false)
	_stock(zone, "Midges", Vector3(-104.0, -21.0, SEWER_Z), Vector3(80.0, 2.0, 6.0),
		["midge", "mosquito", "fly"], 6, false)
	_stock(zone, "Nest", Vector3(PIPE_X, -20.0, -52.0), Vector3(4.0, 2.0, 30.0),
		["rat", "cockroach"], 3)
	_stock(zone, "StormChamber", Vector3(28.5, WALK + 2.0, -4.0), Vector3(10.0, 3.0, 20.0),
		["cockroach", "bat"], 3)


## A stretch of the tunnel along x, from one chamber wall to the next: the swept
## arch with its walkways and channel, stone ribs across the roof, the water, a pipe
## run along the north wall, and lamps.
func _tunnel(zone: Node3D, part_name: String, from_x: float, to_x: float) -> void:
	var body := WorldKit.body(zone, part_name)
	var length := to_x - from_x
	var middle := (from_x + to_x) * 0.5
	var shape := _sewer_section()
	WorldKit.extrude(body, "Arch", shape[0], shape[1], length,
		Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(middle, 0.0, SEWER_Z)))
	var x := from_x + 6.0
	var n := 0
	while x < to_x - 3.0:
		_rib(body, x)
		if n % 2 == 1:
			var south := n % 4 == 1
			_lamp(zone, Vector3(x + 4.0, -17.5, SEWER_Z + (WALKWAY if south else -WALKWAY)),
				0.0 if south else 180.0)
		x += 16.0
		n += 1
	WorldKit.water(zone, part_name + "Water", Vector3(length, WATER_TOP - BED, CHANNEL * 2.0),
		WorldKit.at(Vector3(middle, (BED + WATER_TOP) * 0.5, SEWER_Z)), "slime")
	# A pipe run along the north wall, on brackets.
	var run_z := SEWER_Z - WALKWAY + 1.4
	WorldKit.rod(body, "Main", Vector3(from_x, WALK + 2.4, run_z), Vector3(to_x, WALK + 2.4, run_z),
		1.2, "iron")
	x = from_x + 4.0
	while x < to_x:
		WorldKit.box(body, "Bracket", Vector3(0.5, 0.6, 2.2), WorldKit.at(Vector3(x, WALK + 1.0,
			SEWER_Z - WALKWAY + 1.1)), "iron")
		x += 10.0
	if length > 60.0:
		for at in [from_x + length * 0.3, from_x + length * 0.62]:
			Props.place(zone, "pipe_mouth", WorldKit.at(Vector3(at, -19.0, SEWER_Z + WALKWAY)))
		Props.place(zone, "valve_wheel", WorldKit.at(Vector3(from_x + 14.0, -18.5, SEWER_Z - WALKWAY),
			180.0))
		Props.place(zone, "traffic_cone", WorldKit.at(Vector3(from_x + length * 0.55, WALK,
			SEWER_Z + 7.0), 25.0))


## The tunnel's section: (across, up) points round the inside of it, anticlockwise
## seen from ahead, so the surface faces in, and a colour for each. Across the
## channel's bed, up its side and over the kerb, along the walkway, up the wall and
## round the arch, and back down the other side.
func _sewer_section() -> Array:
	var slime := Palette.colour("moss").darkened(0.25)
	var wet := Palette.colour("moss")
	var dark := Palette.colour("stone_dark")
	var stone := Palette.colour("stone")
	var rows := [
		[Vector2(-CHANNEL, BED), slime], [Vector2(CHANNEL, BED), slime],
		[Vector2(CHANNEL, WATER_TOP + 0.4), wet], [Vector2(CHANNEL, WALK + 1.0), stone],
		[Vector2(CHANNEL + 0.8, WALK + 1.0), stone], [Vector2(CHANNEL + 0.8, WALK), dark],
		[Vector2(WALKWAY, WALK), dark], [Vector2(WALKWAY, WALK), stone],
		[Vector2(WALKWAY, SPRING), stone],
	]
	for i in range(1, 16):
		var angle := PI * float(i) / 16.0
		rows.append([Vector2(cos(angle) * WALKWAY, SPRING + sin(angle) * WALKWAY), stone])
	rows.append_array([
		[Vector2(-WALKWAY, SPRING), stone], [Vector2(-WALKWAY, WALK), stone],
		[Vector2(-WALKWAY, WALK), dark], [Vector2(-CHANNEL - 0.8, WALK), dark],
		[Vector2(-CHANNEL - 0.8, WALK + 1.0), stone], [Vector2(-CHANNEL, WALK + 1.0), stone],
		[Vector2(-CHANNEL, WATER_TOP + 0.4), wet], [Vector2(-CHANNEL, BED), slime],
	])
	var points := PackedVector2Array()
	var colours := PackedColorArray()
	for row in rows:
		points.append(row[0])
		colours.append(row[1])
	return [points, colours]


## A stone rib round the inside of the arch at [param x], with a pier down each
## wall to the walkway: blocks set round the curve, each one square to it.
func _rib(body: Node3D, x: float) -> void:
	var pieces := 8
	var chord := 2.0 * WALKWAY * sin(PI / float(pieces) * 0.5) + 0.3
	for k in pieces:
		var angle := PI * (float(k) + 0.5) / float(pieces)
		var out := Vector3(0.0, sin(angle), -cos(angle))
		var along := Vector3(0.0, cos(angle), sin(angle))
		var centre := Vector3(x, SPRING, SEWER_Z) + out * (WALKWAY - 0.4)
		WorldKit.box(body, "Rib", Vector3(1.4, 0.8, chord), Transform3D(Basis(Vector3.RIGHT, out,
			along), centre), "stone")
	for side in [-1.0, 1.0]:
		WorldKit.box(body, "Pier", Vector3(1.4, SPRING - WALK, 0.8), WorldKit.at(Vector3(x,
			(SPRING + WALK) * 0.5, SEWER_Z + side * (WALKWAY - 0.4))), "stone")


## A square chamber of stone, walkway floor to ceiling: the channel let through
## the floor from [param channel].x to [param channel].y with a kerb along it and
## water in it, the tunnel's arch open in the end walls it comes through, and
## [param shafts] let into the roof. [param open_north] leaves the pipe's round
## mouth in the north wall.
func _chamber(zone: Node3D, part_name: String, lo: Vector3, hi: Vector3, channel: Vector2,
		arches: Array, shafts: Array[Rect2], open_north := false) -> StaticBody3D:
	var room := WorldKit.body(zone, part_name)
	var wall := 2.0
	var cut: Array[Rect2] = [Rect2(channel.x, SEWER_Z - CHANNEL, channel.y - channel.x,
		CHANNEL * 2.0)]
	WorldKit.slab(room, "Floor", Vector3(lo.x - wall, BED - 2.0, lo.z - wall),
		Vector3(hi.x + wall, WALK, hi.z + wall), cut, "stone_dark")
	WorldKit.block(room, "Bed", Vector3(channel.x, BED - 2.0, SEWER_Z - CHANNEL),
		Vector3(channel.y, BED, SEWER_Z + CHANNEL), "moss")
	for side in [-1.0, 1.0]:
		var edge: float = SEWER_Z + side * CHANNEL
		WorldKit.block(room, "Kerb", Vector3(channel.x, WALK, edge), Vector3(channel.y, WALK + 1.0,
			edge + side * 0.8), "stone")
	for end in [channel.x, channel.y]:
		if end > lo.x + 0.01 and end < hi.x - 0.01:
			var inward := 0.8 if end == channel.x else -0.8
			WorldKit.block(room, "Kerb", Vector3(end, WALK, SEWER_Z - CHANNEL - 0.8),
				Vector3(end - inward, WALK + 1.0, SEWER_Z + CHANNEL + 0.8), "stone")
	WorldKit.water(zone, part_name + "Water", Vector3(channel.y - channel.x, WATER_TOP - BED,
		CHANNEL * 2.0), WorldKit.at(Vector3((channel.x + channel.y) * 0.5, (BED + WATER_TOP) * 0.5,
		SEWER_Z)), "slime")

	# Walls, with the arch open in the ends the tunnel comes through.
	var arch := Rect2(SEWER_Z - WALKWAY, BED, WALKWAY * 2.0, SPRING + WALKWAY - BED)
	var shape := _sewer_section()
	for end in ["west", "east"]:
		var x: float = lo.x - wall if end == "west" else hi.x
		var hole := arch if arches.has(end) else Rect2()
		for piece in _around(Vector3(x, BED - 2.0, lo.z - wall), Vector3(x + wall, hi.y,
				hi.z + wall), 2, hole):
			WorldKit.block(room, "Wall", piece.position, piece.end, "stone")
		if arches.has(end):
			var face := lo.x if end == "west" else hi.x
			# Facing into the room: east out of a west wall, west out of an east one.
			var turn := PI * 0.5 if end == "west" else -PI * 0.5
			WorldKit.bulkhead(room, "Arch", shape[0], Vector2(0.0, SPRING - 2.0),
				Vector2(-WALKWAY, BED), Vector2(WALKWAY, SPRING + WALKWAY),
				Transform3D(Basis(Vector3.UP, turn), Vector3(face, 0.0, SEWER_Z)), "stone")
	var mouth := Rect2()
	if open_north:
		mouth = Rect2(PIPE_X - PIPE_RADIUS, WALK, PIPE_RADIUS * 2.0, PIPE_RADIUS * 2.0)
	for piece in _around(Vector3(lo.x, BED - 2.0, lo.z - wall), Vector3(hi.x, hi.y, lo.z), 0,
			mouth):
		WorldKit.block(room, "Wall", piece.position, piece.end, "stone")
	if open_north:
		WorldKit.bulkhead(room, "Mouth", _pipe_section(), Vector2(0.0, WALK + PIPE_RADIUS),
			Vector2(-PIPE_RADIUS, WALK), Vector2(PIPE_RADIUS, WALK + PIPE_RADIUS * 2.0),
			WorldKit.at(Vector3(PIPE_X, 0.0, lo.z)), "stone")
	WorldKit.block(room, "Wall", Vector3(lo.x, BED - 2.0, hi.z), Vector3(hi.x, hi.y, hi.z + wall),
		"stone")
	WorldKit.slab(room, "Roof", Vector3(lo.x - wall, hi.y, lo.z - wall),
		Vector3(hi.x + wall, hi.y + 1.0, hi.z + wall), shafts, "stone")
	return room


## The pipe into the hall: a round tunnel north from the hall's wall to a dead end,
## dry but for the damp, with an outlet in the end of it. The rats nest in here.
func _pipe(zone: Node3D) -> void:
	var body := WorldKit.body(zone, "Pipe")
	var length := HALL_LO.z - PIPE_END
	var shape := _pipe_section()
	var colours := PackedColorArray()
	for point in shape:
		colours.append(Palette.colour("moss") if point.y < WALK + 1.0 else Palette.colour("stone"))
	WorldKit.extrude(body, "Pipe", shape, colours, length,
		WorldKit.at(Vector3(PIPE_X, 0.0, (HALL_LO.z + PIPE_END) * 0.5)))
	WorldKit.cylinder(body, "End", PIPE_RADIUS + 0.6, 1.0, Transform3D(Basis(Vector3.RIGHT, PI * 0.5),
		Vector3(PIPE_X, WALK + PIPE_RADIUS, PIPE_END - 0.5)), "stone")
	Props.place(zone, "pipe_mouth", WorldKit.at(Vector3(PIPE_X, WALK + PIPE_RADIUS - 1.0, PIPE_END),
		180.0))
	Props.place(zone, "traffic_cone", Transform3D(Basis(Vector3.BACK, 0.35), Vector3(PIPE_X + 1.2,
		WALK + 0.5, -58.0)))
	_lamp(zone, Vector3(PIPE_X - 3.2, WALK + PIPE_RADIUS + 2.0, PIPE_END + 0.2), 180.0)


## The pipe's section: a circle standing on the walkway, run anticlockwise so it
## faces in.
func _pipe_section() -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 25:
		var angle := -PI * 0.5 + TAU * float(i) / 24.0
		points.append(Vector2(cos(angle), sin(angle)) * PIPE_RADIUS
			+ Vector2(0.0, WALK + PIPE_RADIUS))
	return points


## The storm drain: a shaft of stone from the storm chamber's roof up to the park,
## and at the top of it the storm grate, which is the gate. It gives to a Sewer
## Widow, or to a Storm Rider, who rides the draught up through the slots.
func _storm_drain(zone: Node3D) -> void:
	var shaft := WorldKit.body(zone, "StormShaft")
	var lo := STORM_LO
	var hi := STORM_HI
	var t := 2.0
	var bottom := STORM_ROOM_HI.y
	var top := GROUND_LO.y
	WorldKit.block(shaft, "West", Vector3(lo.x - t, bottom, lo.y - t), Vector3(lo.x, top, hi.y + t),
		"stone")
	WorldKit.block(shaft, "East", Vector3(hi.x, bottom, lo.y - t), Vector3(hi.x + t, top, hi.y + t),
		"stone")
	WorldKit.block(shaft, "North", Vector3(lo.x, bottom, lo.y - t), Vector3(hi.x, top, lo.y), "stone")
	WorldKit.block(shaft, "South", Vector3(lo.x, bottom, hi.y), Vector3(hi.x, top, hi.y + t), "stone")
	var grate := Threshold.make(zone, Vector3(lo.x, -0.8, lo.y), Vector3(hi.x, 0.0, hi.y), 2.0,
		"StormGrate", "storm_rider")
	_dress(grate, "iron", 7)


# --- the park ------------------------------------------------------------

## The park: lawns either side of the main path from the shed door to the lake,
## trees and bushes and flower beds, benches along the path and round the grate
## the spider comes up through, and an animal area in the corner with an aviary
## for the parrots and a run for the dogs. A hedge goes round it all.
##
## It is the first open space, and the first with nothing overhead. At a Sewer
## Widow's size a bench is a frame and a tree is a building, and the cats are
## bigger than you are. What it taxes is anchors: they are far apart out here,
## and a web between two trees is a long one. The lake is past the far end of
## the path.
func _park() -> void:
	var zone := Zone.make(self, "The Park", PARK_LO, PARK_HI, Vector2(2.0, 3.4))
	_paths(zone)
	_pets(zone)
	_planting(zone)
	_seating(zone)
	_hedges(zone)
	_stock(zone, "CatsSouth", Vector3(-50.0, 3.0, 60.0), Vector3(80.0, 6.0, 60.0), ["cat"], 2)
	_stock(zone, "CatsNorth", Vector3(40.0, 3.0, -64.0), Vector3(80.0, 6.0, 60.0), ["cat"], 2)
	_stock(zone, "Dogs", Vector3(-58.0, 3.0, -72.0), Vector3(20.0, 6.0, 50.0), ["dog"], 2)
	_stock(zone, "Aviary", Vector3(-96.0, 3.0, -86.0), Vector3(30.0, 6.0, 26.0), ["parrot"], 4)
	_stock(zone, "FlowersWest", Vector3(-45.0, 1.0, 32.0), Vector3(18.0, 2.0, 18.0),
		["bee", "butterfly"], 3)
	_stock(zone, "FlowersMiddle", Vector3(12.0, 1.0, 56.0), Vector3(18.0, 2.0, 18.0),
		["bee", "butterfly", "wasp"], 3)
	_stock(zone, "FlowersEast", Vector3(60.0, 1.0, 28.0), Vector3(18.0, 2.0, 18.0),
		["bee", "butterfly"], 3)


## The main path from the shed door to the lake, with the grate let into it; the
## paved ring round the grate, its kerb, and the path up to the animal area.
func _paths(zone: Node3D) -> void:
	var paths := WorldKit.body(zone, "Paths")
	var grate: Array[Rect2] = [Rect2(STORM_LO, STORM_HI - STORM_LO)]
	WorldKit.slab(paths, "Main", Vector3(SHED_HI.x + BOARD, 0.0, -PATH_HALF),
		Vector3(PARK_HI.x, 0.15, PATH_HALF), grate, "path")
	WorldKit.block(paths, "ToPets", Vector3(PETS_GATE.x + 2.0, 0.0, PETS_HI.y),
		Vector3(PETS_GATE.y - 2.0, 0.15, -PATH_HALF), "path")
	var middle := (STORM_LO + STORM_HI) * 0.5
	var ring := PackedVector2Array([Vector2(6.0, 0.0), Vector2(6.0, 0.2), Vector2(PLAZA, 0.2),
		Vector2(PLAZA, 0.0)])
	var paving := Palette.colour("paving")
	WorldKit.lathe(paths, "Plaza", ring, PackedColorArray([paving, paving, paving, paving]), 48,
		WorldKit.at(Vector3(middle.x, 0.0, middle.y)))
	var lo := STORM_LO
	var hi := STORM_HI
	for piece in [
		[Vector3(lo.x - 2.0, -0.3, lo.y - 2.0), Vector3(hi.x + 2.0, 0.35, lo.y)],
		[Vector3(lo.x - 2.0, -0.3, hi.y), Vector3(hi.x + 2.0, 0.35, hi.y + 2.0)],
		[Vector3(lo.x - 2.0, -0.3, lo.y), Vector3(lo.x, 0.35, hi.y)],
		[Vector3(hi.x, -0.3, lo.y), Vector3(hi.x + 2.0, 0.35, hi.y)],
	]:
		WorldKit.block(paths, "Kerb", piece[0], piece[1], "stone_dark")


## The animal area: a white fence round it with a gap to come in by, and a sign;
## the aviary for the parrots, and the dogs' kennel, bowls and balls.
func _pets(zone: Node3D) -> void:
	var pets := WorldKit.group(zone, "PetsCorner")
	var lo := PETS_LO
	var hi := PETS_HI
	var x := lo.x + 10.0
	while x < hi.x:
		Props.place(pets, "picket_fence", WorldKit.at(Vector3(x, 0.0, lo.y)))
		if x < PETS_GATE.x or x > PETS_GATE.y:
			Props.place(pets, "picket_fence", WorldKit.at(Vector3(x, 0.0, hi.y), 180.0))
		x += 20.0
	var z := lo.y + 10.0
	while z < hi.y:
		Props.place(pets, "picket_fence", WorldKit.at(Vector3(lo.x, 0.0, z), 90.0))
		Props.place(pets, "picket_fence", WorldKit.at(Vector3(hi.x, 0.0, z), -90.0))
		z += 20.0
	var sign := Props.place(pets, "sign", WorldKit.at(Vector3((PETS_GATE.x + PETS_GATE.y) * 0.5,
		0.0, hi.y + 6.0), 180.0))
	_letter(sign, "Pets' Corner")
	Props.place(pets, "aviary", WorldKit.at(Vector3(-96.0, 0.0, -86.0), 180.0))
	Props.place(pets, "kennel", WorldKit.at(Vector3(-56.0, 0.0, -96.0), 180.0))
	Props.place(pets, "dog_bowl", WorldKit.at(Vector3(-48.0, 0.0, -86.0)))
	Props.place(pets, "dog_bowl", WorldKit.at(Vector3(-64.0, 0.0, -86.0)))
	Props.place(pets, "ball", WorldKit.at(Vector3(-60.0, 0.0, -58.0)))
	Props.place(pets, "ball", WorldKit.at(Vector3(-47.0, 0.0, -44.0)))


## Trees on the lawns either side of the path, bushes about them and along the
## hedge, and three round flower beds on the south lawn.
func _planting(zone: Node3D) -> void:
	var planting := WorldKit.group(zone, "Planting")
	var trees := [
		["tree_oak", -100.0, 45.0], ["tree_birch", -86.0, 60.0], ["tree_oak", -58.0, 88.0],
		["tree_pine", -112.0, 98.0], ["tree_birch", -24.0, 96.0], ["tree_oak", -8.0, 70.0],
		["tree_pine", 18.0, 104.0], ["tree_oak", 40.0, 72.0], ["tree_birch", 56.0, 86.0],
		["tree_oak", 84.0, 44.0], ["tree_pine", 96.0, 98.0], ["tree_birch", 72.0, 108.0],
		["tree_oak", -20.0, -42.0], ["tree_birch", -4.0, -58.0], ["tree_oak", 20.0, -86.0],
		["tree_pine", 46.0, -50.0], ["tree_birch", 70.0, -30.0], ["tree_oak", 86.0, -82.0],
		["tree_pine", 60.0, -106.0], ["tree_birch", 100.0, -46.0],
	]
	for i in trees.size():
		Props.place(planting, trees[i][0], WorldKit.at(Vector3(trees[i][1], 0.0, trees[i][2]),
			float(i) * 47.0))
	var bushes := [
		[-120.0, 22.0], [-68.0, 32.0], [-40.0, 112.0], [2.0, 20.0], [28.0, 44.0], [74.0, 14.0],
		[100.0, 24.0], [-28.0, -22.0], [4.0, -24.0], [62.0, -22.0], [92.0, -22.0], [104.0, -108.0],
		[-10.0, -110.0], [30.0, -112.0], [-120.0, 112.0], [70.0, 116.0], [-30.0, 60.0], [100.0, 70.0],
	]
	for i in bushes.size():
		var kind := "bush_flowering" if i % 3 == 0 else "bush"
		Props.place(planting, kind, WorldKit.at(Vector3(bushes[i][0], 0.0, bushes[i][1]),
			float(i) * 71.0))
	for bed in [Vector3(-45.0, 0.0, 32.0), Vector3(12.0, 0.0, 56.0), Vector3(60.0, 0.0, 28.0)]:
		Props.place(planting, "flower_bed", WorldKit.at(bed, bed.x * 3.0))


## Benches along the path facing it and round the grate facing in, bins beside
## some of them, and lamp posts down the path.
func _seating(zone: Node3D) -> void:
	var seating := WorldKit.group(zone, "Seating")
	for x in [-100.0, -60.0, -10.0, 70.0, 96.0]:
		Props.place(seating, "bench", WorldKit.at(Vector3(x, 0.0, PATH_HALF + 5.0)))
	for x in [-104.0, -44.0, -10.0, 76.0]:
		Props.place(seating, "bench", WorldKit.at(Vector3(x, 0.0, -PATH_HALF - 5.0), 180.0))
	for x in [-84.0, 6.0, 86.0]:
		Props.place(seating, "bin", WorldKit.at(Vector3(x, 0.0, PATH_HALF + 5.0)))
	for x in [-60.0, 92.0]:
		Props.place(seating, "bin", WorldKit.at(Vector3(x, 0.0, -PATH_HALF - 5.0)))
	var middle := (STORM_LO + STORM_HI) * 0.5
	for i in 4:
		var angle := PI * 0.25 + float(i) * PI * 0.5
		var out := Vector3(cos(angle), 0.0, sin(angle))
		Props.place(seating, "bench", Transform3D(Basis(Vector3.UP, atan2(out.x, out.z)),
			Vector3(middle.x, 0.0, middle.y) + out * (PLAZA - 4.4)))
	var side := 1.0
	for x in [-120.0, -80.0, -40.0, 0.0, 64.0, 100.0]:
		Props.place(seating, "lamp_post", WorldKit.at(Vector3(x, 0.0, side * (PATH_HALF + 2.0))))
		side = -side


## The hedge round the park: along the north and the south, and behind the shed.
func _hedges(zone: Node3D) -> void:
	var hedges := WorldKit.body(zone, "Hedge")
	for z in [-HEDGE, HEDGE]:
		_hedge(hedges, Vector3(HEDGE_WEST, 0.0, z), Vector3(PARK_HI.x, 0.0, z))
	_hedge(hedges, Vector3(HEDGE_WEST, 0.0, -HEDGE), Vector3(HEDGE_WEST, 0.0, HEDGE))


## A clipped hedge along the ground from one point to another: square sides and a
## rounded top, a man's height and more.
func _hedge(on: Node3D, from: Vector3, to: Vector3) -> void:
	var along := to - from
	var turn := Basis(Vector3.UP, atan2(along.x, along.z))
	var middle := (from + to) * 0.5
	var length := along.length() + 8.0
	WorldKit.box(on, "Hedge", Vector3(8.0, 14.0, length), Transform3D(turn, middle + Vector3(0.0,
		7.0, 0.0)), "leaf_dark")
	WorldKit.capsule(on, "Top", 4.0, length, Transform3D(turn * Basis(Vector3.RIGHT, PI * 0.5),
		middle + Vector3(0.0, 14.0, 0.0)), "leaf_dark")


## Puts [param words] on a sign.
func _letter(sign: Node, words: String) -> void:
	if sign != null:
		sign.add_child(Props.words_for(words))


# --- the lake ------------------------------------------------------------

## The lake: the park's second half, through a gap in the railings at the end of
## the main path. A round lake with a stone bank and paving round it, an island in
## the middle with a bandstand on it, a jetty out from the west bank, and rowing
## boats going round the island.
##
## It is built for a Park Recluse growing into the Architect. The water is deep
## and the boats are the way across it: they come by the end of the jetty, and
## anything standing in one goes round with it, silk and all. In the water are
## fish, an octopus, and a shark that will not leave it but will follow you round
## underneath until you are the biggest thing in the park.
func _lake() -> void:
	var zone := Zone.make(self, "The Lake", LAKE_LO, LAKE_HI, Vector2(3.4, 9.0))
	var basin := WorldKit.body(zone, "Basin")
	_basin(basin)
	WorldKit.round_water(zone, "Water", WATER_EDGE, LAKE_TOP - LAKE_BED,
		WorldKit.at(Vector3(LAKE_MIDDLE.x, LAKE_BED, LAKE_MIDDLE.z)), "pond")
	_jetty(zone)
	_railings(zone)
	_lakeside(zone)
	_boats(zone)
	var hedges := WorldKit.body(zone, "Hedge")
	for z in [LAKE_LO.z, LAKE_HI.z]:
		_hedge(hedges, Vector3(LAKE_LO.x, 0.0, z), Vector3(LAKE_HI.x, 0.0, z))
	_hedge(hedges, Vector3(LAKE_HI.x, 0.0, LAKE_LO.z), Vector3(LAKE_HI.x, 0.0, LAKE_HI.z))

	# Fish and the octopus round the island, and the shark in the deep between.
	for i in 3:
		var turn := TAU * (float(i) + 0.25) / 3.0
		_stock(zone, "Fish", LAKE_MIDDLE + Vector3(cos(turn) * 72.0, -9.0, sin(turn) * 72.0),
			Vector3(24.0, 6.0, 24.0), ["fish", "octopus"], 2, false)
	_stock(zone, "Shark", LAKE_MIDDLE + Vector3(0.0, -12.0, 68.0), Vector3(20.0, 2.0, 20.0),
		["shark"], 1, false)


## The bowl of the lake and the island in it, turned about the middle: the silt
## bottom, the weedy slope up to the stone bank, the coping, and the paving round
## it; and the island's grass on top of a mound that goes down to the bottom.
func _basin(basin: Node3D) -> void:
	var silt := Palette.colour("moss").darkened(0.35)
	var weed := Palette.colour("moss")
	var stone := Palette.colour("stone")
	var paving := Palette.colour("paving")
	var grass := Palette.colour("grass")
	var bowl := [
		[Vector2(0.0, LAKE_BED), silt], [Vector2(108.0, LAKE_BED), silt],
		[Vector2(WATER_EDGE - 1.0, LAKE_TOP - 1.5), weed], [Vector2(WATER_EDGE, LAKE_TOP - 1.0), stone],
		[Vector2(WATER_EDGE, 0.3), stone], [Vector2(BANK, 0.3), stone],
		[Vector2(BANK, 0.3), paving], [Vector2(PROMENADE, 0.3), paving],
		[Vector2(PROMENADE, 0.3), stone], [Vector2(PROMENADE + 0.8, -0.6), stone],
	]
	var island := [
		[Vector2(0.0, ISLAND_TOP), grass], [Vector2(ISLAND, ISLAND_TOP), grass],
		[Vector2(ISLAND + 4.0, ISLAND_TOP - 1.2), grass],
		[Vector2(ISLAND + 4.0, ISLAND_TOP - 1.2), stone], [Vector2(ISLAND + 9.0, LAKE_TOP), stone],
		[Vector2(ISLAND + 9.0, LAKE_TOP), weed], [Vector2(ISLAND + 17.0, -10.0), weed],
		[Vector2(ISLAND + 24.0, LAKE_BED + 0.1), silt],
	]
	for part in [["Bowl", bowl], ["Island", island]]:
		var points := PackedVector2Array()
		var colours := PackedColorArray()
		for row in part[1]:
			points.append(row[0])
			colours.append(row[1])
		WorldKit.lathe(basin, part[0], points, colours, 72, WorldKit.at(LAKE_MIDDLE))


## The jetty out from the west bank: a deck of planks on posts, from the paving to
## just short of where the boats go by, with a bollard at the end.
func _jetty(zone: Node3D) -> void:
	var jetty := WorldKit.body(zone, "Jetty")
	var from := LAKE_MIDDLE.x - BANK - 4.0
	var to := LAKE_MIDDLE.x - JETTY_END
	var deck := 1.2
	WorldKit.collider(jetty, "Deck", Vector3(to - from, 0.6, 10.0),
		WorldKit.at(Vector3((from + to) * 0.5, deck - 0.3, 0.0)))
	var z := -5.0
	var n := 0
	while z < 5.0 - 0.01:
		WorldKit.block(jetty, "Plank", Vector3(from, deck - 0.6, z), Vector3(to, deck, z + 1.25),
			"wood" if n % 2 == 0 else "wood_warm", false)
		z += 1.25
		n += 1
	var x := from + 6.0
	while x < to:
		for side in [-1.0, 1.0]:
			WorldKit.rod(jetty, "Post", Vector3(x, LAKE_BED + 4.0, side * 4.4), Vector3(x, deck + 1.0,
				side * 4.4), 0.6, "wood_dark")
		x += 9.0
	WorldKit.cylinder(jetty, "Bollard", 0.9, 2.4, WorldKit.at(Vector3(to - 1.5, deck + 1.2, 3.2)),
		"iron", true, 0.7)


## The railings between the park and the lake, with the gap the path comes through
## and a sign over it; and the last of the path, across to the paving.
func _railings(zone: Node3D) -> void:
	var railings := WorldKit.group(zone, "Railings")
	var z := LAKE_LO.z + 12.0
	while z < LAKE_HI.z:
		if absf(z) >= GATEWAY + 11.9:
			Props.place(railings, "railing", WorldKit.at(Vector3(LAKE_LO.x, 0.0, z), 90.0))
		z += 24.0
	var gate := WorldKit.body(zone, "Gateway")
	for side in [-1.0, 1.0]:
		WorldKit.box(gate, "Pillar", Vector3(2.4, 20.0, 2.4), WorldKit.at(Vector3(LAKE_LO.x, 10.0,
			side * (GATEWAY + 1.2))), "stone")
		WorldKit.ball(gate, "Ball", Vector3.ONE * 1.4, WorldKit.at(Vector3(LAKE_LO.x, 21.2,
			side * (GATEWAY + 1.2))), "stone")
	var sign := Props.place(railings, "sign", WorldKit.at(Vector3(LAKE_LO.x - 8.0, 0.0, 0.0), 90.0))
	_letter(sign, "Boating Lake")
	var paths := WorldKit.body(zone, "Path")
	WorldKit.block(paths, "ToLake", Vector3(LAKE_LO.x, 0.0, -PATH_HALF),
		Vector3(LAKE_MIDDLE.x - PROMENADE + 1.0, 0.15, PATH_HALF), "path")


## Round the water: benches on the paving looking out at it, lamp posts, a
## lifebuoy or two, bulrushes along the bank and lily pads on the water, and trees
## on the grass in the corners.
func _lakeside(zone: Node3D) -> void:
	var side := WorldKit.group(zone, "Lakeside")
	for degrees in [30.0, 75.0, 120.0, 150.0, 215.0, 250.0, 290.0, 330.0]:
		var out := _round(degrees)
		Props.place(side, "bench", Transform3D(Basis(Vector3.UP, atan2(out.x, out.z)),
			LAKE_MIDDLE + out * 153.0 + Vector3.UP * 0.3))
	for degrees in [10.0, 55.0, 100.0, 135.0, 225.0, 270.0, 315.0, 350.0]:
		Props.place(side, "lamp_post", WorldKit.at(LAKE_MIDDLE + _round(degrees) * 163.0
			+ Vector3.UP * 0.3))
	for degrees in [40.0, 165.0, 300.0]:
		var out := _round(degrees)
		Props.place(side, "lifebuoy", Transform3D(Basis(Vector3.UP, atan2(out.x, out.z)),
			LAKE_MIDDLE + out * (BANK + 1.5) + Vector3.UP * 0.3))
	var bed_at := func(out: float) -> float:
		return lerpf(LAKE_BED, LAKE_TOP - 1.5, clampf((out - 108.0) / (WATER_EDGE - 1.0 - 108.0),
			0.0, 1.0))
	for degrees in [20.0, 64.0, 110.0, 140.0, 200.0, 238.0, 280.0, 318.0]:
		var out := 136.5
		Props.place(side, "reeds", WorldKit.at(LAKE_MIDDLE + _round(degrees) * out
			+ Vector3.UP * bed_at.call(out), degrees))
	var pads := [[12.0, 120.0], [18.0, 124.0], [26.0, 118.0], [96.0, 126.0], [104.0, 121.0],
		[196.0, 118.0], [204.0, 125.0], [300.0, 122.0], [306.0, 116.0], [40.0, 40.0], [48.0, 36.0],
		[160.0, 38.0], [230.0, 37.0], [236.0, 42.0]]
	for pad in pads:
		Props.place(side, "lily_pad", WorldKit.at(LAKE_MIDDLE + _round(pad[0]) * pad[1]
			+ Vector3.UP * LAKE_TOP, pad[0] * 7.0))
	for at in [Vector3(136.0, 0.0, -160.0), Vector3(136.0, 0.0, 160.0), Vector3(452.0, 0.0, -160.0),
			Vector3(452.0, 0.0, 160.0)]:
		Props.place(side, "tree_oak", WorldKit.at(at, at.x))
	for at in [Vector3(470.0, 0.0, -96.0), Vector3(470.0, 0.0, 100.0), Vector3(150.0, 0.0, 112.0)]:
		Props.place(side, "tree_pine", WorldKit.at(at, at.z))
	for at in [Vector3(152.0, 0.0, -150.0), Vector3(430.0, 0.0, 150.0), Vector3(468.0, 0.0, -30.0),
			Vector3(468.0, 0.0, 34.0)]:
		Props.place(side, "bush", WorldKit.at(at, at.z))
	Props.place(side, "bandstand", WorldKit.at(LAKE_MIDDLE + Vector3.UP * ISLAND_TOP))


## The boats, spaced round the island and going round it. They are the ring's
## children, and it moves them; see [BoatRing].
func _boats(zone: Node3D) -> void:
	var ring := BoatRing.new()
	ring.name = "Boats"
	ring.radius = BOAT_RING
	ring.speed = 5.0
	ring.position = LAKE_MIDDLE + Vector3.UP * (LAKE_TOP - 1.2)
	var colours := ["boat_red", "boat_blue", "boat_green", "boat_yellow", "boat_red", "boat_blue"]
	for i in colours.size():
		Props.place(ring, colours[i], Transform3D.IDENTITY, "Boat%d" % (i + 1))
	zone.add_child(ring)


## Level, out from the middle of the lake at [param degrees] round from east.
func _round(degrees: float) -> Vector3:
	return Vector3(cos(deg_to_rad(degrees)), 0.0, sin(deg_to_rad(degrees)))


## A room that makes its own light from everywhere, [param lo] to [param hi]: dim
## and [param colour] rather than the sky's. The one light from everywhere is the
## outdoors' — without this a sewer is as bright as a lawn in its shadows, and
## grey stone lit like that is a white room.
func _indoors(zone: Node3D, part_name: String, lo: Vector3, hi: Vector3, colour: Color,
		energy: float) -> void:
	var room := ReflectionProbe.new()
	room.name = part_name
	room.size = hi - lo
	room.interior = true
	room.ambient_mode = ReflectionProbe.AMBIENT_COLOR
	room.ambient_color = colour
	room.ambient_color_energy = energy
	room.intensity = 0.4
	room.update_mode = ReflectionProbe.UPDATE_ONCE
	room.position = (lo + hi) * 0.5
	zone.add_child(room)


## A caged lamp on a wall at [param at], turned [param degrees] from facing north
## — out of a south wall — so it sticks out of the wall it is on.
func _lamp(zone: Node3D, at: Vector3, degrees: float) -> void:
	Props.place(zone, "sewer_lamp", WorldKit.at(at, degrees))


## A ladder of iron rungs down a wall, from [param from] to [param down_to]: each
## a bar out of the wall along [param out], spaced [param step] apart.
func _rungs(on: Node3D, from: Vector3, out: Vector3, down_to: float, step: float,
		width: float) -> void:
	var across := out.cross(Vector3.UP).normalized() * width
	var y := from.y
	while y > down_to:
		var at := Vector3(from.x, y, from.z)
		WorldKit.rod(on, "Rung", at - across + out * 0.4, at + across + out * 0.4, 0.07, "iron")
		for end in [-1.0, 1.0]:
			WorldKit.rod(on, "Leg", at + across * end, at + across * end + out * 0.4, 0.06, "iron",
				false)
		y -= step


# --- creatures -----------------------------------------------------------

## A spawner in [param parent], keeping [param population] of the species named in
## [param ids] about [param at], put down within [param extents] of it. Placed
## before it goes into the tree, because it stocks itself the moment it arrives.
func _stock(parent: Node3D, part_name: String, at: Vector3, extents: Vector3, ids: Array,
		population: int, snap := true) -> PreySpawner:
	var spawner := PreySpawner.new()
	spawner.name = part_name
	spawner.prey_scene = load(Prey.SCENE_PATH) as PackedScene
	var stock: Array[PreySpecies] = []
	for id in ids:
		var kind := PreyLibrary.find(str(id))
		if kind != null:
			stock.append(kind)
	spawner.stock = stock
	spawner.population = population
	spawner.spawn_extents = extents
	spawner.snap_to_ground = snap
	spawner.position = at
	parent.add_child(spawner, true)
	return spawner


# --- the spider ----------------------------------------------------------

## Puts the spider where a new one starts. It is in the scene rather than built
## here, so this moves the one that is there — which is also where the kill plane
## puts it back.
func _place_the_spider() -> void:
	var holder := get_parent()
	var spider := holder.get_node_or_null("Player") as Node3D if holder != null else null
	if spider != null:
		spider.global_transform = Transform3D(Basis(Vector3.UP, -PI * 0.5), SPAWN)
