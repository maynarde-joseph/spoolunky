class_name Hollows
extends Node3D

## The Hollows: a handful of dungeons pressed together into one place.
##
## Not a hunting ground and not a metroidvania. Everything here is hostile, the
## spider is one size the whole way through — a Huntsman — and nothing is locked
## behind a power you have not got. What there is instead is the shape a
## souls-like world has: a hub with a shrine in it, places that each feel like a
## dungeon of their own leading off it, and ways through between them that loop
## back, so that the deeper you go the shorter the way home becomes — once you
## have opened it from the far side.
##
##     the Tower ................ north of the courtyard: four floors up to the belfry
##     the Ruined Courtyard ..... north of the hall: open, tall, the wyrm's ground
##     the Library .............. west: shelves, a gallery, and a stair down
##     the Shrine Hall .......... the middle: where you start, and nothing hostile
##     the Graveyard ............ east: stones, two crypts, the wyrm's other ground
##     the Undercroft ........... under it all: the ossuary, the crypt way, the
##                                sunken cells, and the Rat King's hall
##
## The loops. The hall opens north into the courtyard and east into the
## graveyard, and the two of those join, so the first loop is there from the
## start. The way west to the library is a gate you open from the library side,
## reached the long way round through the courtyard. Under the library a stair
## goes down into the Undercroft; at the far end of it is the Rat King's hall,
## sealed while it lives, and past it a room under the Shrine Hall whose lever
## opens the hatch in the hall's floor — the way back up, once you have earned it.
##
## The Hollow Wyrm keeps to no room: it walks a beat through the courtyard and the
## graveyard, so it is wherever you are on its rounds. The Rat King keeps to its
## hall. Shrines are lit by touching them; resting at one stirs every hostile
## back onto its feet. See [Checkpoints].
##
## Every room is shut on all six sides, because a spider climbs whatever it is
## given: the only ways out of a room are its doors. The look is greybox on
## purpose — each place a colour of its own and a light of its own, the shapes
## enough to read and to string silk between. Like the hunting ground it is baked
## into its scene and taken off the node, and this is the generator of record:
##
##     godot --headless --path . --script res://tools/bake_level.gd -- hollows --force

## Thickness of every wall, floor and roof.
const W := 1.0

# --- the places, by the space you stand in -------------------------------------

const HALL_LO := Vector3(-18.0, 0.0, -18.0)
const HALL_HI := Vector3(18.0, 16.0, 18.0)

const COURT_LO := Vector3(-36.0, 0.0, -105.0)
const COURT_HI := Vector3(36.0, 34.0, -45.0)

const GRAVES_LO := Vector3(50.0, 0.0, -70.0)
const GRAVES_HI := Vector3(100.0, 18.0, -6.0)

const LIBRARY_LO := Vector3(-96.0, 0.0, -84.0)
const LIBRARY_HI := Vector3(-52.0, 28.0, -8.0)

const TOWER_LO := Vector3(-10.0, 0.0, -139.0)
const TOWER_HI := Vector3(10.0, 64.0, -119.0)

## The tower's floors, by the height of each one's top, and the belfry's.
const TOWER_FLOORS := [16.0, 32.0, 48.0]

## The floor of everything under the hall.
const DEEP := -22.0

const OSSUARY_LO := Vector3(-96.0, DEEP, -20.0)
const OSSUARY_HI := Vector3(-84.0, -12.0, -4.0)

const CELLS_LO := Vector3(-40.0, DEEP, -24.0)
const CELLS_HI := Vector3(-16.0, -12.0, 0.0)

const KING_LO := Vector3(-4.0, DEEP, -28.0)
const KING_HI := Vector3(28.0, -8.0, 4.0)

const UNDERGATE_LO := Vector3(0.0, DEEP, 5.0)
const UNDERGATE_HI := Vector3(16.0, -12.0, 17.0)

## The stair down out of the library, and the shaft up into the hall: where each
## goes through the floors, in (x, z).
const STAIR := Rect2(-94.0, -16.0, 8.0, 8.0)
const SHAFT := Rect2(2.0, 9.0, 4.0, 4.0)

# --- doors, by the hole each cuts ----------------------------------------------

## The ways between places: a passage runs between the outer faces of the two
## walls it joins, and the holes in those walls are its own cross-section.
const DOOR_HIGH := 8.0
const SIDE_DOOR_HIGH := 7.0
const DEEP_DOOR_HIGH := 6.0

## The way between the courtyard and the graveyard, wide and high enough for the
## wyrm to go its rounds through.
const WYRM_WAY := Rect2(-65.0, 0.0, 10.0, 10.0)

# --- what lives where -----------------------------------------------------------

## The hostile marks: species, and where — walkers at the floor, fliers above it.
const HOSTILES := [
	["blade_rat", Vector3(-20.0, 0.4, -60.0)],
	["blade_rat", Vector3(16.0, 0.4, -88.0)],
	["blade_rat", Vector3(26.0, 0.4, -54.0)],
	["charger_beetle", Vector3(-6.0, 0.4, -82.0)],
	["charger_beetle", Vector3(-26.0, 0.4, -96.0)],
	["drill_mosquito", Vector3(12.0, 4.0, -97.0)],

	["tongue_frog", Vector3(70.0, 0.4, -40.0)],
	["tongue_frog", Vector3(90.0, 0.4, -18.0)],
	["drill_mosquito", Vector3(64.0, 3.0, -24.0)],
	["drill_mosquito", Vector3(92.0, 3.0, -56.0)],
	["blade_rat", Vector3(80.0, 0.4, -62.0)],

	["screech_bat", Vector3(-76.0, 6.0, -62.0)],
	["screech_bat", Vector3(-66.0, 6.0, -32.0)],
	["spitter_wasp", Vector3(-90.0, 12.0, -52.0)],
	["spitter_wasp", Vector3(-60.0, 8.0, -74.0)],
	["charger_beetle", Vector3(-70.0, 0.4, -22.0)],

	["drill_mosquito", Vector3(0.0, 6.0, -126.0)],
	["screech_bat", Vector3(4.0, 22.0, -132.0)],
	["spitter_wasp", Vector3(-5.0, 37.0, -125.0)],
	["screech_bat", Vector3(5.0, 40.0, -134.0)],

	["charger_beetle", Vector3(-90.0, DEEP + 0.4, -8.0)],
	["blade_rat", Vector3(-70.0, DEEP + 0.4, -12.0)],
	["blade_rat", Vector3(-52.0, DEEP + 0.4, -12.0)],
	["tongue_frog", Vector3(-34.0, DEEP + 0.4, -20.0)],
	["tongue_frog", Vector3(-24.0, DEEP + 0.4, -2.0)],
]

## The wyrm's beat: the courtyard, out east through the passage, down the path
## between the graves and back the same way. Each point is in sight of the next.
const WYRM_BEAT := [
	Vector3(-6.0, 2.0, -66.0),
	Vector3(26.0, 2.0, -60.0),
	Vector3(43.0, 1.0, -60.0),
	Vector3(72.0, 2.0, -62.0),
	Vector3(76.0, 3.0, -40.0),
	Vector3(76.0, 3.0, -18.0),
	Vector3(76.0, 3.0, -40.0),
	Vector3(72.0, 2.0, -62.0),
	Vector3(43.0, 1.0, -60.0),
	Vector3(26.0, 2.0, -60.0),
]

## Each place's light: what colour its lamps are.
const HALL_LAMP := Color(1.0, 0.78, 0.5)
const COURT_LAMP := Color(0.78, 0.85, 1.0)
const GRAVES_LAMP := Color(0.5, 0.95, 0.8)
const LIBRARY_LAMP := Color(1.0, 0.72, 0.42)
const TOWER_LAMP := Color(0.78, 0.6, 1.0)
const DEEP_LAMP := Color(1.0, 0.5, 0.3)


func _ready() -> void:
	build()


func build() -> void:
	_light()
	_rooms()
	_passages()
	_furnish()
	_places()
	_shrines()
	_gates()
	_lair()
	_hostiles()
	_wyrm()
	_keeper()
	_place_the_spider()


# --- light ------------------------------------------------------------------------

## Underground, so no sky: a dark that the lamps push back, a little everywhere so
## nothing is black, and one cold light from above without shadows, which is what
## gives a wall a lit side and a dark side.
func _light() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.03, 0.03, 0.045)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.62, 0.64, 0.74)
	environment.ambient_light_energy = 0.5
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.12, 0.12, 0.16)
	environment.fog_density = 0.008
	var world := WorldEnvironment.new()
	world.name = "Dark"
	world.environment = environment
	add_child(world)

	var above := DirectionalLight3D.new()
	above.name = "Above"
	above.light_color = Color(0.82, 0.86, 1.0)
	above.light_energy = 0.55
	above.shadow_enabled = false
	add_child(above)
	above.look_at_from_position(Vector3(0.0, 100.0, 0.0), Vector3(-30.0, 0.0, 40.0), Vector3.UP)


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


# --- rooms -------------------------------------------------------------------------

func _rooms() -> void:
	_room("ShrineHall", HALL_LO, HALL_HI, "ruin", "ruin_dark", {
		"north": [Rect2(-4.0, 0.0, 8.0, DOOR_HIGH)],
		"east": [Rect2(-16.0, 0.0, 8.0, SIDE_DOOR_HIGH)],
		"west": [Rect2(-16.0, 0.0, 8.0, SIDE_DOOR_HIGH)],
		"floor": [SHAFT],
	})
	_room("RuinedCourtyard", COURT_LO, COURT_HI, "ruin", "soil", {
		"south": [Rect2(-4.0, 0.0, 8.0, DOOR_HIGH)],
		"north": [Rect2(-4.0, 0.0, 8.0, DOOR_HIGH)],
		"east": [WYRM_WAY],
		"west": [Rect2(-80.0, 0.0, 8.0, DOOR_HIGH)],
	})
	_room("Graveyard", GRAVES_LO, GRAVES_HI, "rock_dark", "moss", {
		"west": [WYRM_WAY, Rect2(-16.0, 0.0, 8.0, SIDE_DOOR_HIGH)],
	})
	_room("Library", LIBRARY_LO, LIBRARY_HI, "stone_dark", "wood_dark", {
		"east": [Rect2(-80.0, 0.0, 8.0, DOOR_HIGH), Rect2(-16.0, 0.0, 8.0, SIDE_DOOR_HIGH)],
		"floor": [STAIR],
	})
	_room("Tower", TOWER_LO, TOWER_HI, "rock", "rock_dark", {
		"south": [Rect2(-4.0, 0.0, 8.0, DOOR_HIGH)],
	})
	_room("Ossuary", OSSUARY_LO, OSSUARY_HI, "rock_dark", "rock_dark", {
		"east": [Rect2(-15.0, DEEP, 6.0, DEEP_DOOR_HIGH)],
		"roof": [STAIR],
	})
	_room("SunkenCells", CELLS_LO, CELLS_HI, "rock_dark", "rock_dark", {
		"west": [Rect2(-15.0, DEEP, 6.0, DEEP_DOOR_HIGH)],
		"east": [Rect2(-15.0, DEEP, 6.0, DEEP_DOOR_HIGH)],
	})
	_room("RatKingsHall", KING_LO, KING_HI, "rock_dark", "rock", {
		"west": [Rect2(-15.0, DEEP, 6.0, DEEP_DOOR_HIGH)],
		"south": [Rect2(6.0, DEEP, 8.0, DEEP_DOOR_HIGH)],
	})
	# Its north side is the hall's south wall, door and all.
	_room("Undergate", UNDERGATE_LO, UNDERGATE_HI, "rock_dark", "rock_dark", {
		"roof": [SHAFT],
	}, ["north"])


func _passages() -> void:
	# Hall to courtyard, and on to the tower.
	_passage("HallToCourtyard", Vector3(-4.0, 0.0, COURT_HI.z + W),
		Vector3(4.0, DOOR_HIGH, HALL_LO.z - W), "z", "ruin", "ruin_dark")
	_passage("CourtyardToTower", Vector3(-4.0, 0.0, TOWER_HI.z + W),
		Vector3(4.0, DOOR_HIGH, COURT_LO.z - W), "z", "rock", "rock_dark")
	# East: hall to graveyard, and courtyard to graveyard.
	_passage("HallToGraveyard", Vector3(HALL_HI.x + W, 0.0, -16.0),
		Vector3(GRAVES_LO.x - W, SIDE_DOOR_HIGH, -8.0), "x", "ruin", "ruin_dark")
	_passage("CourtyardToGraveyard", Vector3(COURT_HI.x + W, 0.0, WYRM_WAY.position.x),
		Vector3(GRAVES_LO.x - W, WYRM_WAY.size.y, WYRM_WAY.end.x), "x", "ruin", "soil")
	# West: courtyard to library, and the gated way from the library to the hall.
	_passage("CourtyardToLibrary", Vector3(LIBRARY_HI.x + W, 0.0, -80.0),
		Vector3(COURT_LO.x - W, DOOR_HIGH, -72.0), "x", "stone_dark", "soil")
	_passage("LibraryToHall", Vector3(LIBRARY_HI.x + W, 0.0, -16.0),
		Vector3(HALL_LO.x - W, SIDE_DOOR_HIGH, -8.0), "x", "stone_dark", "ruin_dark")
	# Down: the library's stair to the ossuary, the hall's shaft to the undergate.
	_passage("Stair", Vector3(STAIR.position.x, OSSUARY_HI.y + W, STAIR.position.y),
		Vector3(STAIR.end.x, LIBRARY_LO.y - W, STAIR.end.y), "y", "rock_dark", "rock_dark")
	_passage("Shaft", Vector3(SHAFT.position.x, UNDERGATE_HI.y + W, SHAFT.position.y),
		Vector3(SHAFT.end.x, HALL_LO.y - W, SHAFT.end.y), "y", "rock_dark", "rock_dark")
	# The Undercroft's ways: the crypt way, and the short one into the king's hall.
	_passage("CryptWay", Vector3(OSSUARY_HI.x + W, DEEP, -15.0),
		Vector3(CELLS_LO.x - W, DEEP + DEEP_DOOR_HIGH, -9.0), "x", "rock_dark", "rock_dark")
	_passage("HallWay", Vector3(CELLS_HI.x + W, DEEP, -15.0),
		Vector3(KING_LO.x - W, DEEP + DEEP_DOOR_HIGH, -9.0), "x", "rock_dark", "rock_dark")


## A room whose space to stand in runs from [param lo] to [param hi], its six sides
## built outside that, with holes cut where [param holes] says: side name to an
## array of holes, each a Rect2 in that side's own two axes — (x, y) for north and
## south, (z, y) for east and west, (x, z) for the floor and the roof. A side in
## [param shared] is left to the room next door.
func _room(room_name: String, lo: Vector3, hi: Vector3, paint: String, floor_paint: String,
		holes := {}, shared: Array = []) -> StaticBody3D:
	var body := WorldKit.body(self, room_name)
	var round_x := Vector2(lo.x - W, hi.x + W)
	var round_z := Vector2(lo.z - W, hi.z + W)
	var sides := {
		"floor": [1, lo.y - W, lo.y, round_x, round_z, floor_paint],
		"roof": [1, hi.y, hi.y + W, round_x, round_z, paint],
		"north": [2, lo.z - W, lo.z, round_x, Vector2(lo.y, hi.y), paint],
		"south": [2, hi.z, hi.z + W, round_x, Vector2(lo.y, hi.y), paint],
		"west": [0, lo.x - W, lo.x, Vector2(lo.z, hi.z), Vector2(lo.y, hi.y), paint],
		"east": [0, hi.x, hi.x + W, Vector2(lo.z, hi.z), Vector2(lo.y, hi.y), paint],
	}
	for side: String in sides:
		if shared.has(side):
			continue
		var plan: Array = sides[side]
		_panel(body, side.capitalize(), plan[0], plan[1], plan[2], plan[3], plan[4],
			holes.get(side, []), plan[5])
	return body


## A way between two rooms: a room open at both ends along [param along] ("x",
## "y" or "z"), its ends being the holes in the rooms' walls.
func _passage(passage_name: String, lo: Vector3, hi: Vector3, along: String, paint: String,
		floor_paint: String) -> StaticBody3D:
	var ends := {"x": ["west", "east"], "y": ["floor", "roof"], "z": ["north", "south"]}
	return _room(passage_name, lo, hi, paint, floor_paint, {}, ends[along])


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


# --- what is in the rooms ---------------------------------------------------------

func _furnish() -> void:
	_furnish_hall()
	_furnish_courtyard()
	_furnish_graveyard()
	_furnish_library()
	_furnish_tower()
	_furnish_undercroft()


## Four pillars, a dais for the shrine, and braziers.
func _furnish_hall() -> void:
	var hall := WorldKit.body(self, "HallFurnishing")
	for corner in [Vector2(-12.0, -12.0), Vector2(12.0, -12.0), Vector2(-12.0, 12.0),
			Vector2(12.0, 12.0)]:
		WorldKit.cylinder(hall, "Pillar", 1.5, HALL_HI.y, WorldKit.at(Vector3(corner.x,
			HALL_HI.y * 0.5, corner.y)), "ruin", true, -1.0, 12)
		_lamp(hall, "Brazier", Vector3(corner.x * 0.75, 3.0, corner.y * 0.75), HALL_LAMP, 16.0)
	WorldKit.cylinder(hall, "Dais", 4.0, 0.4, WorldKit.at(Vector3(0.0, 0.2, 6.0)), "ruin_dark",
		true, -1.0, 16)


## Open and tall: a dry fountain in the middle, a broken colonnade down both long
## sides, and fallen walls to put between you and whatever is coming.
func _furnish_courtyard() -> void:
	var court := WorldKit.body(self, "CourtyardFurnishing")
	var middle := Vector3(0.0, 0.0, -75.0)
	WorldKit.cylinder(court, "FountainRim", 5.5, 1.2, WorldKit.at(middle + Vector3(0.0, 0.6, 0.0)),
		"ruin", true, -1.0, 20)
	WorldKit.cylinder(court, "FountainPost", 0.8, 6.0, WorldKit.at(middle + Vector3(0.0, 3.0, 0.0)),
		"ruin_dark", true, -1.0, 10)
	var heights := [26.0, 9.0, 26.0, 14.0, 26.0, 5.0]
	var xs := [-28.0, -14.0, 14.0, 28.0]
	var i := 0
	for z in [-97.0, -53.0]:
		for x: float in xs:
			var tall: float = heights[i % heights.size()]
			WorldKit.cylinder(court, "Column", 1.3, tall, WorldKit.at(Vector3(x, tall * 0.5, z)),
				"ruin", true, -1.0, 12)
			i += 1
	for wall in [[Vector3(-20.0, 0.0, -80.0), 10.0, 5.0, 20.0],
			[Vector3(18.0, 0.0, -68.0), 12.0, 3.5, -10.0],
			[Vector3(10.0, 0.0, -92.0), 8.0, 6.5, 70.0],
			[Vector3(-24.0, 0.0, -58.0), 7.0, 2.5, 0.0]]:
		var at: Vector3 = wall[0]
		var long: float = wall[1]
		var high: float = wall[2]
		WorldKit.box(court, "FallenWall", Vector3(long, high, 1.0),
			WorldKit.at(at + Vector3(0.0, high * 0.5, 0.0), wall[3]), "ruin_dark")
	for spot in [Vector3(-8.0, 22.0, -66.0), Vector3(8.0, 22.0, -86.0), Vector3(-26.0, 10.0, -90.0),
			Vector3(26.0, 10.0, -60.0)]:
		_lamp(court, "Lamp", spot, COURT_LAMP, 30.0, 1.2)


## Rows of stones and two crypts, with a path down the middle.
func _furnish_graveyard() -> void:
	var yard := WorldKit.body(self, "GraveyardFurnishing")
	var row := 0
	for z in range(-64, -9, 7):
		var col := 0
		for x in range(56, 98, 5):
			# The path down the middle, and the ground the crypts stand on.
			if absf(float(x) - 75.0) < 4.0:
				continue
			if _in_crypt(Vector2(x, z)):
				continue
			var lean := float((row * 7 + col * 3) % 9) - 4.0
			WorldKit.box(yard, "Stone", Vector3(1.4, 1.7, 0.35),
				WorldKit.at(Vector3(float(x), 0.85, float(z)), lean), "stone_dark")
			col += 1
		row += 1
	for crypt in [Vector3(64.0, 0.0, -50.0), Vector3(88.0, 0.0, -30.0)]:
		WorldKit.box(yard, "Crypt", Vector3(8.0, 6.0, 10.0), WorldKit.at(crypt + Vector3(0.0, 3.0,
			0.0)), "rock")
		WorldKit.box(yard, "CryptRoof", Vector3(9.0, 1.0, 11.0), WorldKit.at(crypt + Vector3(0.0,
			6.5, 0.0)), "rock_dark")
	for tree in [Vector3(54.0, 0.0, -36.0), Vector3(96.0, 0.0, -66.0)]:
		WorldKit.rod(yard, "DeadTree", tree, tree + Vector3(0.5, 9.0, 0.3), 0.5, "bark", true, 0.2)
		WorldKit.rod(yard, "Bough", tree + Vector3(0.3, 6.0, 0.2), tree + Vector3(3.5, 9.0, 1.0),
			0.25, "bark", true, 0.1)
	for spot in [Vector3(60.0, 8.0, -60.0), Vector3(90.0, 8.0, -60.0), Vector3(60.0, 8.0, -18.0),
			Vector3(90.0, 8.0, -18.0), Vector3(75.0, 10.0, -38.0)]:
		_lamp(yard, "Lantern", spot, GRAVES_LAMP, 20.0, 1.3)


func _in_crypt(at: Vector2) -> bool:
	for crypt in [Vector2(64.0, -50.0), Vector2(88.0, -30.0)]:
		if absf(at.x - crypt.x) < 6.0 and absf(at.y - crypt.y) < 7.0:
			return true
	return false


## Tall shelves in two blocks with aisles between, a gallery down the west side
## with the stair down under it, and reading tables by the doors.
func _furnish_library() -> void:
	var library := WorldKit.body(self, "LibraryFurnishing")
	for block in [Vector2(-78.0, -52.0), Vector2(-44.0, -18.0)]:
		for x in [-80.0, -72.0, -64.0]:
			var long: float = block.y - block.x
			WorldKit.box(library, "Shelf", Vector3(1.6, 14.0, long),
				WorldKit.at(Vector3(x, 7.0, (block.x + block.y) * 0.5)), "wood_dark")
			for shelf_y in [3.5, 7.0, 10.5]:
				WorldKit.box(library, "Books", Vector3(2.0, 0.25, long - 0.4),
					WorldKit.at(Vector3(x, shelf_y, (block.x + block.y) * 0.5)), "paper", false)
	# The gallery: a floor along the west wall, ten up.
	WorldKit.box(library, "Gallery", Vector3(10.0, 1.0, LIBRARY_HI.z - LIBRARY_LO.z),
		WorldKit.at(Vector3(LIBRARY_LO.x + 5.0, 9.5, (LIBRARY_LO.z + LIBRARY_HI.z) * 0.5)),
		"wood_dark")
	for z in [-70.0, -50.0, -30.0]:
		WorldKit.cylinder(library, "GalleryPost", 0.5, 9.0,
			WorldKit.at(Vector3(LIBRARY_LO.x + 9.5, 4.5, z)), "wood_dark", true, -1.0, 8)
	for table in [Vector3(-57.0, 0.0, -62.0), Vector3(-57.0, 0.0, -30.0)]:
		WorldKit.box(library, "Table", Vector3(3.0, 1.2, 6.0), WorldKit.at(table + Vector3(0.0, 0.6,
			0.0)), "wood_light")
	for spot in [Vector3(-60.0, 12.0, -76.0), Vector3(-60.0, 12.0, -46.0), Vector3(-60.0, 12.0,
			-16.0), Vector3(-90.0, 16.0, -60.0), Vector3(-90.0, 16.0, -24.0)]:
		_lamp(library, "Candle", spot, LIBRARY_LAMP, 22.0, 1.3)


## Four floors, each with a hole to climb through, alternating corners so the way
## up winds.
func _furnish_tower() -> void:
	var tower := WorldKit.body(self, "TowerFloors")
	var holes := [Rect2(2.0, -137.0, 6.0, 6.0), Rect2(-8.0, -127.0, 6.0, 6.0),
		Rect2(2.0, -127.0, 6.0, 6.0)]
	for i in TOWER_FLOORS.size():
		var top: float = TOWER_FLOORS[i]
		_panel(tower, "Floor%d" % i, 1, top - W, top, Vector2(TOWER_LO.x, TOWER_HI.x),
			Vector2(TOWER_LO.z, TOWER_HI.z), [holes[i]], "rock_dark")
	var height := 6.0
	for top in [0.0] + TOWER_FLOORS:
		_lamp(tower, "Sconce", Vector3(-8.0, top + height, -121.0), TOWER_LAMP, 16.0, 1.3)
		_lamp(tower, "Sconce", Vector3(8.0, top + height, -137.0), TOWER_LAMP, 16.0, 1.3)


## Bones in the ossuary, arches down the crypt way, cells either side of the
## sunken cells, and pillars and a throne in the Rat King's hall.
func _furnish_undercroft() -> void:
	var deep := WorldKit.body(self, "UndercroftFurnishing")
	for pile in [Vector3(-93.0, DEEP, -18.0), Vector3(-87.0, DEEP, -5.5), Vector3(-93.0, DEEP,
			-5.5)]:
		WorldKit.ball(deep, "Bones", Vector3(1.6, 0.9, 1.4), WorldKit.at(pile), "paper")
	for x in range(-78, -42, 8):
		for side in [-15.0, -9.0]:
			WorldKit.box(deep, "Arch", Vector3(1.0, 6.0, 0.8),
				WorldKit.at(Vector3(float(x), DEEP + 3.0, side + (0.4 if side < -12.0 else -0.4))),
				"rock")
	for x in [-36.0, -28.0, -20.0]:
		for z in [-24.0, -4.0]:
			WorldKit.box(deep, "CellWall", Vector3(0.8, 5.0, 8.0),
				WorldKit.at(Vector3(x, DEEP + 2.5, z + 4.0)), "rock")
	for pillar in [Vector2(4.0, -20.0), Vector2(20.0, -20.0), Vector2(4.0, -4.0),
			Vector2(20.0, -4.0)]:
		WorldKit.cylinder(deep, "HallPillar", 1.6, KING_HI.y - KING_LO.y,
			WorldKit.at(Vector3(pillar.x, (KING_LO.y + KING_HI.y) * 0.5, pillar.y)), "rock", true,
			-1.0, 12)
	WorldKit.box(deep, "Throne", Vector3(6.0, 2.0, 3.0), WorldKit.at(Vector3(12.0, DEEP + 1.0,
		-26.0)), "rock")
	WorldKit.box(deep, "ThroneBack", Vector3(6.0, 6.0, 1.0), WorldKit.at(Vector3(12.0, DEEP + 3.0,
		-27.5)), "rock_dark")
	for spot in [Vector3(-90.0, DEEP + 7.0, -12.0), Vector3(-62.0, DEEP + 4.5, -12.0),
			Vector3(-28.0, DEEP + 7.0, -12.0), Vector3(12.0, DEEP + 10.0, -12.0),
			Vector3(0.0, DEEP + 10.0, -24.0), Vector3(24.0, DEEP + 10.0, 0.0),
			Vector3(8.0, DEEP + 7.0, 11.0)]:
		_lamp(deep, "Torch", spot, DEEP_LAMP, 18.0, 1.4)


# --- what the places are called ------------------------------------------------------

## The places, as zones that touch and never overlap — what the HUD names when the
## spider walks into one. All of it built for one size, the Huntsman's.
func _places() -> void:
	var size := Vector2(0.7, 0.7)
	Zone.make(self, "The Shrine Hall", HALL_LO, HALL_HI, size)
	Zone.make(self, "The Ruined Courtyard", COURT_LO, COURT_HI, size)
	Zone.make(self, "The Graveyard", GRAVES_LO, GRAVES_HI, size)
	Zone.make(self, "The Library", LIBRARY_LO, LIBRARY_HI, size)
	var belfry: float = TOWER_FLOORS[TOWER_FLOORS.size() - 1]
	Zone.make(self, "The Tower", TOWER_LO, Vector3(TOWER_HI.x, belfry, TOWER_HI.z), size)
	Zone.make(self, "The Belfry", Vector3(TOWER_LO.x, belfry, TOWER_LO.z), TOWER_HI, size)
	Zone.make(self, "The Ossuary Stair", OSSUARY_LO, OSSUARY_HI, size)
	Zone.make(self, "The Crypt Way", Vector3(OSSUARY_HI.x + W, DEEP, -15.0),
		Vector3(CELLS_LO.x - W, DEEP + DEEP_DOOR_HIGH, -9.0), size)
	Zone.make(self, "The Sunken Cells", CELLS_LO, CELLS_HI, size)
	Zone.make(self, "The Rat King's Hall", KING_LO, KING_HI, size)
	Zone.make(self, "The Undergate", UNDERGATE_LO, UNDERGATE_HI, size)


# --- the shrines, the gates, the lair --------------------------------------------------

func _shrines() -> void:
	Shrine.make(self, "Shrine of the Hall", Vector3(0.0, 0.4, 6.0), Vector3.FORWARD, true)
	Shrine.make(self, "Graveside Shrine", Vector3(96.0, 0.0, -8.0), Vector3(-1.0, 0.0, -1.0))
	Shrine.make(self, "Gallery Shrine", Vector3(LIBRARY_LO.x + 3.0, 10.0, -36.0), Vector3.RIGHT)
	Shrine.make(self, "Belfry Shrine", Vector3(-4.0, TOWER_FLOORS[2], -135.0), Vector3(1.0, 0.0,
		1.0))
	Shrine.make(self, "Sunken Shrine", Vector3(-18.0, DEEP, -21.0), Vector3.BACK)


## The two shortcuts: the gate between the library and the hall, opened from the
## library; and the hatch in the hall's floor, opened from the room under it.
func _gates() -> void:
	ShortcutGate.make(self, "Library Gate", Vector3(-24.0, 0.0, -16.0),
		Vector3(-23.4, SIDE_DOOR_HIGH, -8.0), Vector3(-55.0, 0.0, -11.0))
	ShortcutGate.make(self, "Hall Hatch", Vector3(SHAFT.position.x, -W, SHAFT.position.y),
		Vector3(SHAFT.end.x, 0.0, SHAFT.end.y), Vector3(13.0, DEEP, 14.5), Vector3.RIGHT)


## The Rat King's hall: sealed at its door from the sunken cells while the king
## lives, and shut at its way out to the undergate until it is beaten.
func _lair() -> void:
	var lair := BossLair.make(self, "The Rat King's Hall", Vector3(KING_LO.x + 2.5, DEEP,
		KING_LO.z), Vector3(KING_HI.x, KING_HI.y, KING_HI.z - 2.5), "rat_king",
		Vector3(12.0, DEEP + 0.4, -14.0), "wing_buds")
	lair.add_veil(Vector3(KING_LO.x - W, DEEP, -15.0),
		Vector3(KING_LO.x, DEEP + DEEP_DOOR_HIGH, -9.0))
	lair.add_veil(Vector3(6.0, DEEP, KING_HI.z), Vector3(14.0, DEEP + DEEP_DOOR_HIGH,
		KING_HI.z + W), true)


# --- what lives here --------------------------------------------------------------------

func _hostiles() -> void:
	var holder := WorldKit.group(self, "Hostiles")
	var i := 0
	for entry in HOSTILES:
		var mark := HostileSpawn.new()
		mark.name = "%s%d" % [String(entry[0]).to_pascal_case(), i]
		mark.species_id = entry[0]
		holder.add_child(mark)
		mark.global_position = entry[1]
		i += 1


func _wyrm() -> void:
	var mark := HostileSpawn.new()
	mark.name = "HollowWyrm"
	mark.species_id = "hollow_wyrm"
	mark.stays_beaten = true
	mark.route = PackedVector3Array(WYRM_BEAT)
	add_child(mark)
	mark.global_position = WYRM_BEAT[0]


func _keeper() -> void:
	var keeper := Checkpoints.new()
	keeper.name = "Checkpoints"
	add_child(keeper)


## Wakes the spider at the hall's shrine.
func _place_the_spider() -> void:
	var holder := get_parent()
	var spider := holder.get_node_or_null("Player") as Node3D if holder != null else null
	var shrine := get_node_or_null("ShrineoftheHall") as Shrine
	if spider != null and shrine != null:
		spider.global_transform = shrine.wake_transform()
