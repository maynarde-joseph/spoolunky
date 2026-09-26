@tool
class_name PreySpecies
extends Resource

## A kind of creature worth eating.
##
## Everything that makes one creature different from another lives here, the
## same way [WebPattern] holds everything that makes one web different from
## another. Drop a new .tres built from this script into
## [code]res://game/data/prey/[/code] and it turns up in the world — no scene
## to author and no code to change, because one prey scene serves all of them
## and takes its body, its size and its behaviour from here.
##
## The three numbers that decide where a creature belongs are [member
## size_class], which says whether a web's mesh even notices it and whether
## the spider can bite it; [method total_thrash], which says which webs can
## keep hold of it; and [member flying], which says where in the room you have
## to put the web.

@export var id := "fly"
@export var display_name := "Fly"
@export var description := ""

## Where it sits in the catalogue, low first.
@export var sort_order := 0


@export_group("Worth")

## Biomass gained by draining it.
@export var biomass := 8.0

## How big it is. Checked against a pattern's mesh, which decides whether the
## web notices it at all, and against the spider's bite power, which decides
## whether it can be drained without being subdued first. 1 is fly-sized.
@export var size_class := 1


@export_group("Fight")

## How hard it fights a web. Tears silk and eventually pulls free.
@export var struggle_power := 1.0

## How long it fights for before it tires out. A catch is won or lost inside
## this window.
@export var struggle_stamina := 5.0

## How hard a tired catch keeps pulling, wearing the web it hangs in.
@export var settled_drain := 0.015


@export_group("Hunting you")

## Whether it will come for a spider it outclasses. Zero means it never does,
## whatever the size difference — a midge is a midge.
##
## The rule is the one the design doc always had: everything you can eat can also
## eat you at the wrong size. A creature inside your bite power is food; one that
## is out of it, and aggressive, comes looking. So growing *flips the
## relationship* rather than swapping in a different bestiary, and every zone
## opens with you as the smallest thing in it.
@export_range(0.0, 1.0, 0.05) var aggression := 0.0

## How far off it notices a spider worth attacking, in metres.
@export var hunt_range := 6.0

## Stamina taken out of the spider per bite.
@export var bite_damage := 3.0

## Seconds between bites, so being caught out is survivable for a moment.
@export var bite_interval := 1.1


@export_group("Movement")

@export var move_speed := 1.7

## Flying prey ignores gravity and drifts; walking prey falls. This is the
## difference between a web that has to be up in the air and one that has to
## be on the ground, so it decides where a creature is caught.
@export var flying := true

## How far from where it started it will wander.
@export var wander_radius := 7.0

## Low and high limits above its home, for fliers.
@export var wander_height := Vector2(0.3, 2.8)

## Seconds before it picks somewhere new to be, even if it hasn't arrived.
@export var wander_interval := 2.6

## How strongly it drifts toward a lure it can smell.
@export_range(0.0, 1.0, 0.05) var lure_susceptibility := 0.85


@export_group("Body")

@export var colour := Color(0.13, 0.12, 0.15, 1.0)

## Faint glow, so a species reads across a dark room.
@export var sheen := Color(0.45, 0.3, 0.08, 1.0)

@export var body_radius := 0.045

## Winged things get a pair that beat while they fly.
@export var winged := true


@export_group("Spawning")

## How often this turns up against the others in the same stock. Zero keeps it
## out of the ordinary mix, for something only placed by hand.
@export var spawn_weight := 1.0


## Everything it will throw at a web before it tires itself out: the number a
## web has to beat to keep hold of it.
func total_thrash() -> float:
	return struggle_power * struggle_stamina
