class_name SpiderWorld
extends Node3D

## The whole world, greyboxed.
##
## Five zones in one space rather than five scenes, because the payoff of a
## game about scale is standing in the park and looking back at the downpipe
## you came out of. That only works if the attic is really up there.
##
## It is laid out as a descent and then a spread: the house stands on the park,
## the crawlspace runs down inside it, the sewer runs underneath, and the storm
## grate brings you back up into the open. Nothing here is decoration — every
## box is somewhere to walk, anchor silk or grapple to.
##
## Built in code because that is how everything else in this project makes
## geometry, and because a layout you can read as numbers is a layout you can
## change. The constants below are the whole design.

# --- the house, standing on the park -------------------------------------

const HOUSE_X := Vector2(-96.0, -56.0)
const HOUSE_Z := Vector2(-20.0, 20.0)

## Interior of the attic, and the crawlspace shaft that drops out of it.
const ATTIC_LO := Vector3(-92.0, 40.0, -16.0)
const ATTIC_HI := Vector3(-60.0, 54.0, 16.0)
const SHAFT_LO := Vector3(-80.0, 2.0, -6.0)
const SHAFT_HI := Vector3(-68.0, 40.0, 6.0)

# --- underneath ----------------------------------------------------------

const SEWER_LO := Vector3(-84.0, -34.0, -10.0)
const SEWER_HI := Vector3(-4.0, -20.0, 10.0)

## Where the storm grate comes up into daylight.
const GRATE_X := -14.0
const GRATE_Z := 0.0

# --- outside -------------------------------------------------------------

const PARK_LO := Vector3(-50.0, 0.0, -70.0)
const PARK_HI := Vector3(40.0, 46.0, 70.0)
const CITY_LO := Vector3(40.0, 0.0, -80.0)
const CITY_HI := Vector3(190.0, 96.0, 80.0)

const WALL := 2.0

## Where a new spider starts: in the attic, on the floor, near the vent.
const SPAWN := Vector3(-88.0, 41.5, 12.0)


func _ready() -> void:
	build()


func build() -> void:
	_attic()
	_crawlspace()
	_sewer()
	_park()
	_city()


# --- 4.1 The Room --------------------------------------------------------

## Dry, still and cluttered, and the only place in the world where nothing is
## trying to take your silk back. Crates and a beam to string between.
func _attic() -> void:
	var zone := Zone.make(self, "The Attic", ATTIC_LO, ATTIC_HI, Vector2(0.25, 0.4))
	Greybox.room(zone, ATTIC_LO, ATTIC_HI, WALL, "Shell", ["floor"] as Array[String])

	# The floor has the crawlspace mouth in it, so the way down is visible from
	# the moment you arrive — you just cannot shift the flap over it yet.
	Greybox.panel_with_hole(zone,
		Vector3(ATTIC_LO.x - WALL, ATTIC_LO.y - WALL, ATTIC_LO.z - WALL),
		Vector3(ATTIC_HI.x + WALL, ATTIC_LO.y, ATTIC_HI.z + WALL), 1,
		Vector2(SHAFT_LO.x, SHAFT_LO.z), Vector2(SHAFT_HI.x, SHAFT_HI.z), "Floor")

	# Roof beams, low enough to reach and far enough apart to span.
	for i in 4:
		var x := ATTIC_LO.x + 6.0 + float(i) * 7.0
		Greybox.span(zone, Vector3(x, ATTIC_HI.y - 4.0, ATTIC_LO.z),
			Vector3(x + 1.2, ATTIC_HI.y - 2.6, ATTIC_HI.z), "Beam%d" % i)

	Greybox.clutter(zone, Vector3(-86.0, 44.0, -8.0), Vector3(9.0, 8.0, 7.0), "Crate")
	Greybox.clutter(zone, Vector3(-76.0, 42.5, -11.0), Vector3(6.0, 5.0, 5.0), "Box")
	Greybox.clutter(zone, Vector3(-64.0, 43.5, 9.0), Vector3(5.0, 7.0, 11.0), "Trunk")
	Greybox.clutter(zone, Vector3(-70.0, 41.2, -2.0), Vector3(14.0, 2.4, 3.0), "Plank")

	_bulb(zone, Vector3(-76.0, 51.0, 2.0), 34.0, 2.4)

	# The way out: a vent flap over the crawlspace mouth. A spiderling walks
	# over it; a house spider puts it through — or a hollow-framed one folds
	# between the slats, which is the first place the tree pays for itself.
	Threshold.make(zone, Vector3(SHAFT_LO.x, ATTIC_LO.y - 0.7, SHAFT_LO.z),
		Vector3(SHAFT_HI.x, ATTIC_LO.y, SHAFT_HI.z), 0.4, "VentFlap", "hollow_frame")


# --- 4.2 The Walls & Crawlspace ------------------------------------------

## Vertical, dark, and made of gaps. Joists to grapple between and a long drop
## if you get it wrong.
func _crawlspace() -> void:
	var zone := Zone.make(self, "The Crawlspace", SHAFT_LO, SHAFT_HI, Vector2(0.4, 0.7))
	Greybox.room(zone, SHAFT_LO, SHAFT_HI, WALL, "Shell",
		["floor", "ceiling"] as Array[String])

	# Joists across the shaft, alternating sides, so the way down is a series
	# of swings rather than a fall.
	for i in 9:
		var y := SHAFT_LO.y + 3.0 + float(i) * 4.0
		var near := i % 2 == 0
		var z_lo: float = SHAFT_LO.z if near else SHAFT_LO.z + 6.0
		Greybox.span(zone, Vector3(SHAFT_LO.x, y, z_lo),
			Vector3(SHAFT_HI.x, y + 1.0, z_lo + 6.0), "Joist%d" % i)

	# The shaft floor, with the downpipe through it.
	Greybox.panel_with_hole(zone,
		Vector3(SHAFT_LO.x - WALL, SHAFT_LO.y - WALL, SHAFT_LO.z - WALL),
		Vector3(SHAFT_HI.x + WALL, SHAFT_LO.y, SHAFT_HI.z + WALL), 1,
		Vector2(-77.0, -3.0), Vector2(-71.0, 3.0), "Floor")

	# The pipe itself: a square chimney down to the sewer roof.
	_chimney(zone, Vector2(-77.0, -3.0), Vector2(-71.0, 3.0), SEWER_HI.y, SHAFT_LO.y, "Downpipe")

	_bulb(zone, Vector3(-74.0, 34.0, 0.0), 18.0, 0.7)
	_bulb(zone, Vector3(-74.0, 14.0, 0.0), 18.0, 0.5)

	# A cap of matted dust and old web over the pipe. You go through it when
	# there is enough of you to fall through — or when you can dissolve it,
	# which is what a digestive flood is for.
	Threshold.make(zone, Vector3(-77.0, SHAFT_LO.y - 0.6, -3.0),
		Vector3(-71.0, SHAFT_LO.y, 3.0), 0.7, "DustCap", "digestive")


# --- 4.3 The Gutter & Sewer ----------------------------------------------

## Wet and hostile, and the first place that takes silk back off you. The
## channel down the middle is where the water will run.
func _sewer() -> void:
	var zone := Zone.make(self, "The Sewer", SEWER_LO, SEWER_HI, Vector2(0.7, 1.2))
	Greybox.room(zone, SEWER_LO, SEWER_HI, WALL, "Shell",
		["ceiling", "floor"] as Array[String])

	# A floor with a channel cut down the middle of it.
	Greybox.span(zone, Vector3(SEWER_LO.x, SEWER_LO.y - WALL, SEWER_LO.z - WALL),
		Vector3(SEWER_HI.x, SEWER_LO.y + 2.0, -3.0), "LedgeNorth")
	Greybox.span(zone, Vector3(SEWER_LO.x, SEWER_LO.y - WALL, 3.0),
		Vector3(SEWER_HI.x, SEWER_LO.y + 2.0, SEWER_HI.z + WALL), "LedgeSouth")
	Greybox.span(zone, Vector3(SEWER_LO.x, SEWER_LO.y - WALL, -3.0),
		Vector3(SEWER_HI.x, SEWER_LO.y, 3.0), "Channel")

	# The roof, holed where the downpipe comes in and where the grate goes out.
	Greybox.panel_with_hole(zone,
		Vector3(SEWER_LO.x, SEWER_HI.y, SEWER_LO.z - WALL),
		Vector3(-30.0, SEWER_HI.y + WALL, SEWER_HI.z + WALL), 1,
		Vector2(-77.0, -3.0), Vector2(-71.0, 3.0), "RoofWest")
	Greybox.panel_with_hole(zone,
		Vector3(-30.0, SEWER_HI.y, SEWER_LO.z - WALL),
		Vector3(SEWER_HI.x, SEWER_HI.y + WALL, SEWER_HI.z + WALL), 1,
		Vector2(GRATE_X - 3.0, GRATE_Z - 3.0), Vector2(GRATE_X + 3.0, GRATE_Z + 3.0),
		"RoofEast")

	# Arch ribs, to break up a long tunnel and give the silk somewhere to go.
	for i in 6:
		var x := SEWER_LO.x + 8.0 + float(i) * 12.0
		Greybox.span(zone, Vector3(x, SEWER_HI.y - 3.0, SEWER_LO.z),
			Vector3(x + 1.6, SEWER_HI.y, SEWER_HI.z), "Rib%d" % i)

	# The shaft up to daylight.
	_chimney(zone, Vector2(GRATE_X - 3.0, GRATE_Z - 3.0), Vector2(GRATE_X + 3.0, GRATE_Z + 3.0),
		SEWER_HI.y, PARK_LO.y, "GrateShaft")

	_bulb(zone, Vector3(-70.0, SEWER_HI.y - 3.0, 0.0), 24.0, 0.6)
	_bulb(zone, Vector3(-40.0, SEWER_HI.y - 3.0, 0.0), 24.0, 0.5)
	_bulb(zone, Vector3(-12.0, SEWER_HI.y - 3.0, 0.0), 26.0, 0.9)

	# A hinged pressure lid, sprung for something the size of a rat. Weight
	# opens it; so does riding the draught coming up through the slots.
	Threshold.make(zone, Vector3(GRATE_X - 3.0, PARK_LO.y - 0.8, GRATE_Z - 3.0),
		Vector3(GRATE_X + 3.0, PARK_LO.y, GRATE_Z + 3.0), 1.2, "StormGrate", "storm_rider")


# --- 4.4 The Park --------------------------------------------------------

## The first open space, and the first place with nothing overhead to anchor
## to. Trees and a bench are the only frames until you can make your own.
func _park() -> void:
	var zone := Zone.make(self, "The Park", PARK_LO, PARK_HI, Vector2(1.2, 3.4))
	Greybox.span(zone, Vector3(PARK_LO.x, PARK_LO.y - WALL, PARK_LO.z),
		Vector3(PARK_HI.x, PARK_LO.y, PARK_HI.z), "Ground")

	# The house it all started in, so the attic is a thing you can look back at.
	Greybox.room(zone, Vector3(HOUSE_X.x, PARK_LO.y, HOUSE_Z.x),
		Vector3(HOUSE_X.y, ATTIC_LO.y - WALL, HOUSE_Z.y), WALL, "House",
		["ceiling"] as Array[String])

	var trunks := [
		Vector3(-34.0, 0.0, -40.0), Vector3(-10.0, 0.0, -22.0),
		Vector3(14.0, 0.0, -48.0), Vector3(-28.0, 0.0, 26.0),
		Vector3(6.0, 0.0, 44.0), Vector3(26.0, 0.0, 10.0),
	]
	for i in trunks.size():
		var at: Vector3 = trunks[i]
		Greybox.span(zone, at + Vector3(-2.0, 0.0, -2.0), at + Vector3(2.0, 26.0, 2.0),
			"Trunk%d" % i)
		# A canopy to sling webs under: the park's only ceiling.
		Greybox.span(zone, at + Vector3(-11.0, 26.0, -11.0), at + Vector3(11.0, 29.0, 11.0),
			"Canopy%d" % i)

	Greybox.clutter(zone, Vector3(-20.0, 2.0, 4.0), Vector3(14.0, 4.0, 4.0), "Bench")
	Greybox.clutter(zone, Vector3(2.0, 3.0, -8.0), Vector3(6.0, 6.0, 6.0), "Bin")
	Greybox.clutter(zone, Vector3(22.0, 4.0, -30.0), Vector3(20.0, 8.0, 12.0), "Playground")

	_sun(zone)


# --- 4.5 The City --------------------------------------------------------

## Blocks and the gaps between them. At this size a street is a span and a
## fire escape is a staircase, which is the joke landing.
func _city() -> void:
	var zone := Zone.make(self, "The City", CITY_LO, CITY_HI, Vector2(3.4, 9.0))
	Greybox.span(zone, Vector3(CITY_LO.x, CITY_LO.y - WALL, CITY_LO.z),
		Vector3(CITY_HI.x, CITY_LO.y, CITY_HI.z), "Street")

	var blocks := [
		[Vector2(56.0, -62.0), Vector2(94.0, -26.0), 72.0],
		[Vector2(56.0, -12.0), Vector2(88.0, 22.0), 54.0],
		[Vector2(56.0, 36.0), Vector2(96.0, 70.0), 88.0],
		[Vector2(112.0, -58.0), Vector2(152.0, -18.0), 94.0],
		[Vector2(110.0, -4.0), Vector2(146.0, 30.0), 64.0],
		[Vector2(118.0, 44.0), Vector2(158.0, 72.0), 78.0],
		[Vector2(166.0, -30.0), Vector2(186.0, 26.0), 46.0],
	]
	for i in blocks.size():
		var lo: Vector2 = blocks[i][0]
		var hi: Vector2 = blocks[i][1]
		var top: float = blocks[i][2]
		Greybox.span(zone, Vector3(lo.x, CITY_LO.y, lo.y), Vector3(hi.x, top, hi.y),
			"Block%d" % i)
		# Fire escape: a stack of ledges up one face, which is a staircase once
		# you are big enough for the treads to be steps.
		for step in 6:
			var y := 10.0 + float(step) * 10.0
			if y > top - 6.0:
				break
			Greybox.span(zone, Vector3(lo.x - 5.0, y, lo.y + 4.0),
				Vector3(lo.x, y + 1.4, lo.y + 16.0), "Escape%d_%d" % [i, step])

	_bulb(zone, Vector3(100.0, 18.0, 0.0), 60.0, 0.5)
	_bulb(zone, Vector3(160.0, 18.0, 40.0), 60.0, 0.4)


# --- fittings ------------------------------------------------------------

## A square pipe between two heights, open at both ends.
func _chimney(parent: Node3D, lo: Vector2, hi: Vector2, bottom: float, top: float,
		part_name: String) -> void:
	var pipe := Node3D.new()
	pipe.name = part_name
	parent.add_child(pipe)
	var t := 1.5
	Greybox.span(pipe, Vector3(lo.x - t, bottom, lo.y - t), Vector3(lo.x, top, hi.y + t), "West")
	Greybox.span(pipe, Vector3(hi.x, bottom, lo.y - t), Vector3(hi.x + t, top, hi.y + t), "East")
	Greybox.span(pipe, Vector3(lo.x, bottom, lo.y - t), Vector3(hi.x, top, lo.y), "North")
	Greybox.span(pipe, Vector3(lo.x, bottom, hi.y), Vector3(hi.x, top, hi.y + t), "South")


## One hanging source per interior, because a single light is what makes a
## white box read as a shape at all.
func _bulb(parent: Node3D, at: Vector3, reach: float, energy: float) -> void:
	var lamp := OmniLight3D.new()
	lamp.name = "Bulb"
	lamp.omni_range = reach
	lamp.light_energy = energy
	lamp.shadow_enabled = true
	parent.add_child(lamp)
	lamp.global_position = at


## Outdoors shares one sun. Interiors are sealed boxes, so it does not reach
## them and each keeps the light it was given.
func _sun(parent: Node3D) -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 320.0
	parent.add_child(sun)
	sun.global_position = Vector3(0.0, 120.0, 0.0)
	sun.look_at(Vector3(40.0, 0.0, 30.0), Vector3.UP)
