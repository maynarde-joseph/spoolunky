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
## roof of the chamber under the shed.
const DRAIN_LO := Vector2(-168.6, 1.4)
const DRAIN_HI := Vector2(-165.4, 4.6)
const DRAIN_BOTTOM := -8.0

## Where a new spider starts: on the shed floor, between the bench and the drain,
## facing the drain.
const SPAWN := Vector3(-173.0, 1.4, 6.5)


func _ready() -> void:
	build()


func build() -> void:
	_sky()
	_ground()
	_shed()
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
	environment.ambient_light_color = Color(0.7, 0.74, 0.82)
	environment.ambient_light_energy = 0.4
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.name = "Sky"
	world.environment = environment
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 320.0
	add_child(sun)
	sun.global_position = Vector3(0.0, 200.0, 0.0)
	sun.look_at(sun.global_position + SUNLIGHT, Vector3.UP)


## The grass, with holes let into it where something goes down through it.
func _ground() -> void:
	var ground := WorldKit.body(self, "Ground")
	WorldKit.slab(ground, "Grass", GROUND_LO, GROUND_HI, _holes_in_the_ground(), "grass")


## Where the ground is open: the drain shaft under the shed.
func _holes_in_the_ground() -> Array[Rect2]:
	var holes: Array[Rect2] = [Rect2(DRAIN_LO, DRAIN_HI - DRAIN_LO)]
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
	_rungs(shaft, Vector3((lo.x + hi.x) * 0.5, top - 0.8, lo.y), Vector3.BACK, DRAIN_BOTTOM + 0.8,
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
	parent.add_child(spawner)
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
