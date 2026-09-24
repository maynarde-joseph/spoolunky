@tool
class_name WebPattern
extends Resource

## A buildable kind of web.
##
## Everything that makes one web different from another lives here: what shape
## it can be, what it costs, how well it holds prey and what it does when
## something touches it. Drop a new .tres built from this script into
## [code]res://game/data/patterns/[/code] and it shows up in the build wheel.

## How the anchors the player places are turned into a structure.
enum Shape {
	## Two anchors, one line. Triplines and bridges.
	STRAND,
	## Three or more anchors closed into a plane. Everything that catches.
	NET,
}

## What the web does when prey touches it.
enum Trigger {
	## Sticks to whatever lands in it.
	PASSIVE,
	## Doesn't hold, but tells you something crossed it.
	ALERT,
	## Built under tension: snaps shut on contact, then needs re-arming.
	SNARE,
	## Passive, but drags wandering prey toward it from a distance.
	LURE,
}


@export_group("Identity")

## Stable id, used for saves and lookups. Keep it unique.
@export var id := "sheet_web"

## Name shown in the build wheel.
@export var display_name := "Sheet Web"

## One line of flavour/help shown while this pattern is selected.
@export var description := ""

## Growth stage index required before this pattern can be built (0 = from the start).
@export var unlock_stage := 0

## Position in the build wheel. Lower comes first.
@export var sort_order := 0

## Draw colour of the finished silk. Dark: the material puts the shine and the
## glow on top, and a pale thread disappears against a pale wall.
@export var color := Color(0.10, 0.11, 0.13, 0.9)


@export_group("Shape")

@export var shape: Shape = Shape.NET

## Fewest anchors that make a valid web of this pattern.
@export var min_anchors := 3

## Most anchors the player may place before having to finish.
@export var max_anchors := 10

## Spokes drawn from the centre out to the rim.
@export var radial_count := 12

## Spiral rings drawn between the spokes.
@export var ring_count := 5

## 0 = geometric and neat, 1 = tangled mess. Sheet webs want a lot, orbs none.
@export_range(0.0, 1.0, 0.01) var jitter := 0.05

## Thickness of a single silk line, in metres, before size scaling.
@export var strand_thickness := 0.008


@export_group("Behaviour")

@export var trigger: Trigger = Trigger.PASSIVE

## How hard prey is held. Prey escapes when its struggle beats this.
@export var hold_strength := 1.0

## How much struggling the web survives before it tears apart.
@export var durability := 12.0

## Smallest prey this web will hold. Raised by opening the mesh out, so a web
## meant for rats isn't clogged and torn by gnats.
@export var min_catch_size := 1

## How many things this holds at once. A full web stops catching, so the way to
## catch more is another web somewhere else — which is what makes a second site
## worth walking to rather than just spinning this one bigger.
@export var capacity := 2

## SNARE only: how long prey is held completely rigid when the trap springs.
@export var snap_hold_time := 4.0

## LURE only: radius in metres over which prey is drawn in.
@export var lure_radius := 0.0

## ALERT only: how long a tripped target stays marked for you.
@export var mark_time := 6.0

## Gives the finished web a solid surface you can walk on. Silk bridges.
@export var walkable := false

## Width of that walkable surface, in metres, before size scaling.
@export var walk_width := 0.14

## Whether this web catches prey at all. Bridges and triplines don't.
@export var catches_prey := true


@export_group("Trigger links")

## Whether this web can be wired up as the source of a signal — i.e. whether
## anything interesting ever happens to it. Bridges don't report.
@export var can_signal := true

## SNARE only: how far a remotely-triggered snare can whip out and drag prey
## in, as a multiple of the web's own radius. This is what a wired snare can do
## that an untouched one cannot.
@export var signal_strike_factor := 2.5

## Non-snare webs tense up when signalled: hold strength is multiplied by this
## for [member tense_duration] seconds.
@export var tense_multiplier := 2.0

@export var tense_duration := 5.0


## True if this pattern is available at the given growth stage index.
func is_unlocked_at(stage_index: int) -> bool:
	return stage_index >= unlock_stage

