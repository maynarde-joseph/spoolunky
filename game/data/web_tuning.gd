@tool
class_name WebTuning
extends Resource

## Three dials the player sets before spinning a web.
##
## Every one of them is a trade, never an upgrade — turn a dial up and
## something else goes down. A web you can simply make better is a web with no
## decision in it.
##
## * **Tension** trades holding power against durability. Spun tight it grabs
##   hard and tears fast; spun slack it gives with the struggling and lasts.
## * **Weight** trades both of those against silk. Heavy silk is stronger in
##   every way and costs accordingly.
## * **Mesh** trades what you catch against what you spend. A fine mesh stops
##   everything, including the gnats that clog and tear it; a coarse mesh is
##   cheap and lets the small stuff through to save the web for something
##   worth having.
##
## Mesh and weight both change how the web is woven, so a tuned web looks
## different as well as behaving differently.

enum Dial {
	TENSION,
	WEIGHT,
	MESH,
}

## Settings per dial, and the one in the middle that changes nothing.
const STEPS := 5
const NEUTRAL := 2

const DIAL_NAMES: PackedStringArray = ["Tension", "Weight", "Mesh"]

## What each dial does, at the low end and the high end, for the HUD.
const DIAL_HINTS: PackedStringArray = [
	"slack: holds less, lasts longer   ·   tight: holds hard, tears sooner",
	"fine: cheap and weak   ·   heavy: stronger all round, costs more silk",
	"close: catches everything, pricier   ·   open: cheap, lets small prey through",
]

@export_range(0, 4) var tension := NEUTRAL
@export_range(0, 4) var weight := NEUTRAL
@export_range(0, 4) var mesh := NEUTRAL


func get_dial(dial: Dial) -> int:
	match dial:
		Dial.TENSION:
			return tension
		Dial.WEIGHT:
			return weight
		_:
			return mesh


func set_dial(dial: Dial, value: int) -> void:
	var clamped := clampi(value, 0, STEPS - 1)
	match dial:
		Dial.TENSION:
			tension = clamped
		Dial.WEIGHT:
			weight = clamped
		_:
			mesh = clamped


## Moves a dial a step. Returns false if it was already at the end.
func nudge(dial: Dial, step: int) -> bool:
	var before := get_dial(dial)
	set_dial(dial, before + step)
	return get_dial(dial) != before


func is_default() -> bool:
	return tension == NEUTRAL and weight == NEUTRAL and mesh == NEUTRAL


func copy() -> WebTuning:
	var other := WebTuning.new()
	other.tension = tension
	other.weight = weight
	other.mesh = mesh
	return other


## A copy of [param pattern] with these settings baked in. The original is a
## shared resource and is never touched; the web keeps the tuned copy, so
## everything downstream — cost, geometry, holding power — just works.
func apply_to(pattern: WebPattern) -> WebPattern:
	var tuned := pattern.duplicate() as WebPattern
	if tuned == null:
		return pattern
	var t := _amount(tension)
	var w := _amount(weight)
	var m := _amount(mesh)

	tuned.hold_strength = pattern.hold_strength * (1.0 + 0.5 * t) * (1.0 + 0.35 * w)
	tuned.durability = pattern.durability * (1.0 - 0.35 * t) * (1.0 + 0.5 * w)

	tuned.strand_thickness = pattern.strand_thickness * (1.0 + 0.5 * w)
	# Heavy silk is better in every way and takes longer to lay. That wait is
	# the whole cost of a web now, so it is where the weight dial has to bite —
	# a dial that is simply better is not a dial.
	tuned.spin_time = pattern.spin_time * (1.0 + 0.45 * w)

	# A coarser mesh is literally fewer threads, so it is quicker to lay without
	# needing a multiplier — the geometry does it.
	if pattern.radial_count > 0:
		tuned.radial_count = maxi(3, roundi(pattern.radial_count * (1.0 - 0.25 * m)))
	if pattern.ring_count > 0:
		tuned.ring_count = maxi(1, roundi(pattern.ring_count * (1.0 - 0.3 * m)))
	tuned.min_catch_size = pattern.min_catch_size + maxi(0, mesh - NEUTRAL)

	return tuned


## Compact readout, e.g. "Tension ●●●○○".
func bar(dial: Dial) -> String:
	var filled := get_dial(dial) + 1
	var text := "%s " % DIAL_NAMES[dial]
	for i in STEPS:
		text += "●" if i < filled else "○"
	return text


func hint(dial: Dial) -> String:
	return DIAL_HINTS[dial]


static func _amount(step: int) -> float:
	return float(step - NEUTRAL) / float(NEUTRAL)
