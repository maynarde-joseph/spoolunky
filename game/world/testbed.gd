class_name SpiderTestbed
extends Node3D

## A gym. Nine stations on one flat floor, each isolating one thing.
##
## The five-zone world is the game; this is the workshop. It exists because that
## world is two hundred and eighty metres across and mostly corridor, so
## checking whether a web fits a corner meant a walk, and checking whether it
## fits a *different* corner meant another one. Everything here is inside
## fifty-two metres by forty, all on one level, all in sight of the middle.
##
## The rule for adding to it: a station tests one thing and says on it what that
## thing is. If you cannot tell from standing in front of it what it is for,
## it needs a better shape, not a longer sign.

const FLOOR_LO := Vector3(-26.0, -1.0, -20.0)
const FLOOR_HI := Vector3(26.0, 0.0, 20.0)

## The hole in the floor, for testing what happens when you go through it.
const PIT_LO := Vector2(13.0, 10.0)
const PIT_HI := Vector2(19.0, 16.0)

## Where you start: the middle, under the deck, with everything a short walk off.
const SPAWN := Vector3(0.0, 0.6, -4.0)

## Station centres. Three rows of three, sixteen metres apart in x and thirteen
## in z, which is about four seconds of walking at the first tier's pace.
const CORNERS := Vector3(-17.0, 0.0, -13.0)
const SLOTS := Vector3(0.0, 0.0, -13.0)
const CLIMB := Vector3(16.0, 0.0, -13.0)
const GRAPPLE := Vector3(-16.0, 0.0, 0.0)
const DECK := Vector3(0.0, 0.0, 0.0)
const ZIP := Vector3(16.0, 0.0, 0.0)
const GATES := Vector3(-16.0, 0.0, 13.0)
const PEN := Vector3(0.0, 0.0, 13.0)
const PIT := Vector3(16.0, 0.0, 13.0)

## Loose items, two metres in front of where you start.
const PICKUPS := Vector3(0.0, 0.0, -6.5)


func _ready() -> void:
	build()


func build() -> void:
	_ground()
	_corners()
	_slots()
	_climbing()
	_grapple_range()
	_deck()
	_zipline()
	_gates()
	_prey_pen()
	_the_pit()
	_pickups()
	_sun()


## One slab with one hole in it. The hole is the pit station, and it goes all the
## way through — under the floor there is nothing at all, which is the point.
func _ground() -> void:
	Greybox.panel_with_hole(self, FLOOR_LO, FLOOR_HI, 1, PIT_LO, PIT_HI, "Floor")
	# A lip round the outside, so walking off the edge is a decision.
	var kerb := Node3D.new()
	kerb.name = "Kerb"
	add_child(kerb)
	Greybox.span(kerb, Vector3(FLOOR_LO.x - 0.6, 0.0, FLOOR_LO.z - 0.6),
		Vector3(FLOOR_HI.x + 0.6, 0.5, FLOOR_LO.z), "North")
	Greybox.span(kerb, Vector3(FLOOR_LO.x - 0.6, 0.0, FLOOR_HI.z),
		Vector3(FLOOR_HI.x + 0.6, 0.5, FLOOR_HI.z + 0.6), "South")
	Greybox.span(kerb, Vector3(FLOOR_LO.x - 0.6, 0.0, FLOOR_LO.z),
		Vector3(FLOOR_LO.x, 0.5, FLOOR_HI.z), "West")
	Greybox.span(kerb, Vector3(FLOOR_HI.x, 0.0, FLOOR_LO.z),
		Vector3(FLOOR_HI.x + 0.6, 0.5, FLOOR_HI.z), "East")


## Every kind of corner a web has to fit itself into: square, splayed, and a
## dead end narrow enough that the rim finds stone on three sides.
func _corners() -> void:
	var here := _station(CORNERS, "CORNERS\nweb rim fitting")
	# Square: two walls meeting at a right angle, opening toward the middle.
	Greybox.span(here, Vector3(-23.0, 0.0, -18.0), Vector3(-22.6, 3.5, -10.0), "SquareA")
	Greybox.span(here, Vector3(-23.0, 0.0, -18.0), Vector3(-15.0, 3.5, -17.6), "SquareB")
	# Splayed: a V on the diagonal, so nothing about it is axis-aligned and a
	# surface normal is a real number rather than exactly one.
	Greybox.fence(here, Vector3(-15.0, 0.0, -17.5), Vector3(-18.5, 0.0, -11.5), 3.0, 0.4, "SplayA")
	Greybox.fence(here, Vector3(-15.0, 0.0, -17.5), Vector3(-11.5, 0.0, -11.5), 3.0, 0.4, "SplayB")
	# A dead end eighty centimetres wide: three sides in reach of one web.
	Greybox.span(here, Vector3(-22.0, 0.0, -14.0), Vector3(-19.0, 2.5, -13.6), "AlcoveA")
	Greybox.span(here, Vector3(-22.0, 0.0, -12.8), Vector3(-19.0, 2.5, -12.4), "AlcoveB")
	Greybox.span(here, Vector3(-22.4, 0.0, -14.0), Vector3(-22.0, 2.5, -12.4), "AlcoveBack")


## Three gaps, wide to narrow. What a web does across each, and what fits down
## each, are two different questions and this answers both.
func _slots() -> void:
	var here := _station(SLOTS, "SLOTS\n3.0m / 1.2m / 0.4m")
	_slot(here, -9.0, 3.0, "Wide")
	_slot(here, -13.0, 1.2, "Middling")
	_slot(here, -16.5, 0.4, "Tight")


## One pair of parallel walls. [param gap] is the space between their faces, so
## the number on the sign is the number you can measure.
func _slot(parent: Node3D, at_z: float, gap: float, part_name: String) -> void:
	var thick := 0.4
	var inner := gap * 0.5
	Greybox.span(parent, Vector3(-4.0, 0.0, at_z - inner - thick),
		Vector3(4.0, 3.0, at_z - inner), part_name + "Near")
	Greybox.span(parent, Vector3(-4.0, 0.0, at_z + inner),
		Vector3(4.0, 3.0, at_z + inner + thick), part_name + "Far")


## Wall, then the underside of an overhang, then a ceiling to walk upside down
## on — the three surfaces climbing has to hand you between — plus slopes at
## every steepness between floor and wall.
func _climbing() -> void:
	var here := _station(CLIMB, "CLIMB\nwall, overhang, ceiling, slopes")
	Greybox.span(here, Vector3(11.0, 0.0, -18.0), Vector3(11.6, 5.0, -10.0), "Face")
	# Sticks out two metres, so coming up the face rolls you onto its underside.
	Greybox.span(here, Vector3(9.0, 5.0, -18.0), Vector3(11.6, 5.6, -10.0), "Overhang")
	# A metre and a half above that: inside a first-tier jump, on purpose.
	Greybox.span(here, Vector3(9.0, 7.0, -18.0), Vector3(21.0, 7.6, -10.0), "Ceiling")
	Greybox.span(here, Vector3(20.4, 0.0, -18.0), Vector3(21.0, 7.0, -10.0), "BackWall")
	# Slopes. Twenty degrees is a floor, eighty is a wall, and the interesting
	# part is where the spider stops treating one as the other.
	#
	# Every one rises the same two metres and the run is what changes. Fixing
	# the run instead makes the steep ones enormous — eighty degrees over four
	# metres is twenty-two metres tall, which is a slope that leaves the gym —
	# and it also means comparing four ramps of four different heights.
	var rise := 2.0
	for i in 4:
		var degrees := 20.0 + float(i) * 20.0
		var z := -17.0 + float(i) * 1.8
		var run: float = rise / tan(deg_to_rad(degrees))
		Greybox.ramp(here, Vector3(13.0, 0.1, z), Vector3(13.0 + run, rise, z),
			1.4, 0.3, "Slope%d" % roundi(degrees))


## Anchors at one, three, seven and thirteen metres from the pad. Grapple them
## in order and the oldest line comes down as the fourth goes up.
func _grapple_range() -> void:
	var here := _station(GRAPPLE, "GRAPPLE\n1 / 3 / 7 / 13m — and the three-line cap")
	Greybox.span(here, Vector3(-23.0, 0.0, -2.0), Vector3(-21.0, 0.4, 2.0), "Pad")
	for distance in [1.0, 3.0, 7.0, 13.0]:
		var x: float = -21.0 + distance
		Greybox.span(here, Vector3(x - 0.3, 0.0, -0.3), Vector3(x + 0.3, 2.6, 0.3),
			"Post%d" % roundi(distance))


## A roof with a hole in it. Somewhere to drop a dragline from, somewhere to web
## across, and a ceiling you have to get onto before either.
func _deck() -> void:
	var here := _station(DECK, "DECK\ndragline, ceiling webs")
	Greybox.panel_with_hole(here, Vector3(-5.0, 6.0, -5.0), Vector3(5.0, 6.4, 5.0),
		1, Vector2(-1.2, -1.2), Vector2(1.2, 1.2), "Roof")
	for corner in [Vector2(-1.0, -1.0), Vector2(1.0, -1.0), Vector2(-1.0, 1.0), Vector2(1.0, 1.0)]:
		var x: float = corner.x * 4.6
		var z: float = corner.y * 4.6
		Greybox.span(here, Vector3(x - 0.3, 0.0, z - 0.3), Vector3(x + 0.3, 6.0, z + 0.3),
			"Leg%d%d" % [roundi(corner.x), roundi(corner.y)])


## Two posts of different heights. A line between their tops is a slope, and a
## slope is the only thing worth riding.
func _zipline() -> void:
	var here := _station(ZIP, "ZIPLINE\ntall post to short post")
	Greybox.span(here, Vector3(11.7, 0.0, -0.3), Vector3(12.3, 6.0, 0.3), "Tall")
	Greybox.span(here, Vector3(19.7, 0.0, -0.3), Vector3(20.3, 1.2, 0.3), "Short")
	# A rung ladder up the tall one, so getting to the top is not the test.
	for i in 6:
		var y := 0.8 + float(i) * 0.9
		Greybox.span(here, Vector3(12.3, y, -0.2), Vector3(12.9, y + 0.2, 0.2), "Rung%d" % i)


## The three size gates, side by side, each over a drop. Stand on one too small
## and it dips and settles; stand on it big enough and you go through.
func _gates() -> void:
	var here := _station(GATES, "GATES\n0.4m / 0.7m / 1.2m, or a trait")
	var sizes: Array[float] = [0.4, 0.7, 1.2]
	var keys: Array[String] = ["hollow_frame", "digestive", "storm_rider"]
	for i in sizes.size():
		var x := -22.0 + float(i) * 4.4
		var lo := Vector3(x, 2.0, 10.0)
		var hi := Vector3(x + 3.6, 2.4, 14.0)
		Greybox.panel_with_hole(here, lo, hi, 1,
			Vector2(x + 1.0, 11.2), Vector2(x + 2.6, 12.8), "Plinth%d" % i)
		Threshold.make(here, Vector3(x + 1.0, 2.0, 11.2), Vector3(x + 2.6, 2.4, 12.8),
			sizes[i], "Gate%d" % roundi(sizes[i] * 10.0), keys[i])
	# One ramp along the front reaches all three.
	Greybox.ramp(here, Vector3(-16.0, 0.2, 17.0), Vector3(-16.0, 2.2, 14.2),
		13.0, 0.4, "Ramp")


## Somewhere with things in it to catch. Walled so the stock stays put, open on
## top so you can shoot down into it, with a beam to hang a web from.
func _prey_pen() -> void:
	var here := _station(PEN, "PREY\nfliers above, walkers below")
	Greybox.room(here, Vector3(-5.0, 0.0, 9.0), Vector3(5.0, 3.2, 17.0), 0.4, "Pen",
		["floor", "ceiling"] as Array[String])
	Greybox.span(here, Vector3(-5.0, 3.2, 12.8), Vector3(5.0, 3.6, 13.2), "Beam")
	Greybox.clutter(here, Vector3(-2.5, 0.5, 11.0), Vector3(1.4, 1.0, 1.4), "Crate")
	Greybox.clutter(here, Vector3(2.5, 0.35, 15.0), Vector3(2.0, 0.7, 1.0), "Plank")


## A hole through the floor and a ledge beside it. Falling out of the world is a
## thing that has to work, and it is easier to check on purpose than by accident.
func _the_pit() -> void:
	var here := _station(PIT, "PIT\nfall out and come back")
	Greybox.span(here, Vector3(PIT_LO.x - 0.4, 0.0, PIT_LO.y - 0.4),
		Vector3(PIT_HI.x + 0.4, 0.6, PIT_LO.y), "LipNorth")
	Greybox.span(here, Vector3(PIT_LO.x - 0.4, 0.0, PIT_HI.y),
		Vector3(PIT_HI.x + 0.4, 0.6, PIT_HI.y + 0.4), "LipSouth")
	Greybox.span(here, Vector3(PIT_LO.x - 0.4, 0.0, PIT_LO.y),
		Vector3(PIT_LO.x, 0.6, PIT_HI.y), "LipWest")
	Greybox.span(here, Vector3(PIT_HI.x, 0.0, PIT_LO.y),
		Vector3(PIT_HI.x + 0.4, 0.6, PIT_HI.y), "LipEast")
	# A gantry over the middle of it, to web across and to fall off.
	Greybox.span(here, Vector3(PIT_LO.x, 2.4, 12.6), Vector3(PIT_HI.x, 2.8, 13.4), "Gantry")
	Greybox.span(here, Vector3(PIT_LO.x - 0.4, 0.0, 12.6),
		Vector3(PIT_LO.x, 2.4, 13.4), "GantryPost")


## One of everything carryable, lying on the floor where you start.
##
## Devices are the only thing in the game that is found rather than made, so the
## only way to know picking one up works is to have one to pick up. Look at one
## and press X — the same key that pulls a web down, because a device under the
## crosshair wins over a web behind it.
func _pickups() -> void:
	var here := _station(PICKUPS, "PICKUPS\nlook at one, press X")
	var kinds := WebLibrary.load_devices()
	if kinds.is_empty():
		return
	# Spread wider than the pick tolerance, or looking at one is looking at two.
	var step := 1.5
	var first: float = -step * float(kinds.size() - 1) * 0.5
	for i in kinds.size():
		var at := Vector3(first + step * float(i), 0.0, PICKUPS.z)
		# Sized to the first tier, which is the size a new spider sees them at.
		var item := SilkDevice.make(kinds[i], at, Vector3.UP, 0.25)
		if item != null:
			item.place_in(here)


## A named folder with a sign over it. The sign is the documentation: a gym you
## have to read a file to use is a gym nobody uses.
func _station(at: Vector3, text: String) -> Node3D:
	var here := Node3D.new()
	here.name = text.split("\n")[0].capitalize()
	add_child(here)
	var plaque := Label3D.new()
	plaque.name = "Sign"
	plaque.text = text
	plaque.font_size = 72
	plaque.pixel_size = 0.005
	plaque.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	plaque.modulate = Color(0.08, 0.09, 0.12, 1.0)
	plaque.outline_modulate = Color(1.0, 1.0, 1.0, 0.85)
	plaque.outline_size = 24
	plaque.shaded = false
	plaque.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	here.add_child(plaque)
	plaque.global_position = at + Vector3(0.0, 4.6, 0.0)
	return here


## One sun, high and to the side. A gym wants to be legible rather than moody,
## so there is no second light and nothing is in shadow you cannot see into.
func _sun() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	add_child(sun)
	sun.global_position = Vector3(0.0, 40.0, 0.0)
	sun.look_at(Vector3(14.0, 0.0, 10.0), Vector3.UP)
