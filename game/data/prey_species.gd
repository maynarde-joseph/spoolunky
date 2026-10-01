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

## When a creature is out and about. Out of its hours it goes home and rests.
enum Activity {
	ALWAYS,
	DAY,
	NIGHT,
}

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

## Whether its flying is swimming. Something that swims keeps below the top of
## the water it is in and goes nowhere above it — not after a lure, not after a
## spider on the bank — so a fish is caught in the water or not at all. Out of
## water it has nothing to keep under, and gets about like anything that flies.
@export var swims := false

## How far from where it started it will wander.
@export var wander_radius := 7.0

## Low and high limits above its home, for fliers.
@export var wander_height := Vector2(0.3, 2.8)

## Seconds before it picks somewhere new to be, even if it hasn't arrived.
@export var wander_interval := 2.6

## How strongly it drifts toward a lure it can smell.
@export_range(0.0, 1.0, 0.05) var lure_susceptibility := 0.85


@export_group("Living")

## What it eats, where there is an [Ecosystem] for it to live in: kinds of
## [Forage] ("moss", "fungus", "flowers", "grass", "berries"), species ids, the
## [member tags] a kind of creature carries ("insect", "bird"…), and "carrion" for
## anything dead. Empty, it eats nothing and is never hungry.
##
## A creature can only take what it can overpower: something in its diet that is
## no bigger than it is. What is bigger it leaves alone however hungry it gets.
@export var diet := PackedStringArray()

## What kind of creature it is, for a diet that names a kind rather than a species
## — "insect", "bird", "fish", "beast".
@export var tags := PackedStringArray()

## How quickly it gets hungry: how much of a whole belly it empties a second.
@export var hunger_rate := 0.007

## How long it can stay at its hungriest before it starves, in seconds.
@export var starve_after := 150.0

## How far off it notices food and danger, in metres.
@export var senses := 10.0

## When it is out. Out of its hours it goes home to its [Den] and rests there.
@export var active: Activity = Activity.ALWAYS

## Whether it keeps clear of a spider big enough to eat it. Insects blunder into
## webs; a hare does not let a spider walk up to it.
@export var wary := false


@export_group("Body")

## What it looks like and how it moves: a skeleton, a mesh on it and the motion
## that poses it, all from one resource — see [CreatureBody]. A species without
## one is drawn as a placeholder, a ball in [member colour] with a pair of flat
## wings if it is [member winged].
@export var body: CreatureBody

## The placeholder's colour. A [member body] carries its own.
@export var colour := Color(0.13, 0.12, 0.15, 1.0)

## Faint glow on the placeholder, so a species reads across a dark room.
@export var sheen := Color(0.45, 0.3, 0.08, 1.0)

## How big it is: its hitbox, and the unit its [member body] is drawn in.
@export var body_radius := 0.045

## Whether the placeholder gets a pair of wings that beat while it flies. A
## [member body] says for itself how many it has.
@export var winged := true


@export_group("Spawning")

## How often this turns up against the others in the same stock. Zero keeps it
## out of the ordinary mix, for something only placed by hand.
@export var spawn_weight := 1.0

## Where it lives, if that is somewhere in particular — "sewers", "park", "lake".
##
## The insects turn up anywhere, and a spawner left to choose its own stock draws
## from them. A rat does not: it lives in the sewers, so only a spawner that names
## it puts one down. Without this, a room built to test webs in would fill with
## dogs and sharks the day they were added, because an empty stock meant every
## species there is.
@export var habitat := ""


## Everything it will throw at a web before it tires itself out: the number a
## web has to beat to keep hold of it.
func total_thrash() -> float:
	return struggle_power * struggle_stamina
