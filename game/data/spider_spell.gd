@tool
class_name SpiderSpell
extends Resource

## One thing the spider can cast.
##
## The thrown web was the first spell before there was a word for it: point,
## press, and something leaves the spider and does its work where it lands. The
## rest are the same verb with other things behind it — water, lightning, fire —
## so they share the web's keys, its reach, its wind-up and its kind of limit: a
## wait, never a bill.
##
## Which spells a spider has is the spell tree's: each is learned there, with
## points the ranks hand out, and goes on the number keys in the loadout. See
## [SpellTree] and [SpellSkill].
##
## A spell is numbers. What it does is its [member form], and the code for each
## form lives in [SpiderSpells]; drop a new .tres built from this script into
## [code]res://game/data/spells/[/code] with an existing form and it is in the
## game, on the strip, with nothing else to edit.

## What a spell is, which decides what casting it does.
enum Form {
	## The thrown web, cast by the web builder exactly as it always was.
	SILK,
	## Water spat at the cross in a spray of drops, that leave puddles where they land.
	DOUSE,
	## Lightning, called down where you point.
	LIGHTNING,
	## Fire breathed out of the spider's jaws along the cross, swept while it lasts,
	## that burns what it touches: harder the more silk is on it.
	FIRE,
	## Every web in reach called back to the spider, hitting what it passes on the way.
	PULLBACK,
	## Wind blown down a lane in front of the spider, that shoves what it reaches away —
	## and over a puddle, lifts the water into a whirl.
	GUST,
	## A pillar of clay raised where you point, that throws what stands there off
	## its top.
	EARTH,
}

@export var id := "silk"
@export var display_name := "Silk"

## One line, on the strip and in the book.
@export var description := ""

@export var form: Form = Form.SILK

## Where it sits on the strip, first to last.
@export var order := 0


@export_group("Casting")

## Seconds before it can be cast again. Silk's wait is the web builder's own.
@export var cooldown := 6.0

## How wide it reaches, in body heights, from a tap to a full wind-up: the radius
## of a strike, how wide a puddle each drop of water leaves, how far a breath of
## fire reaches, how wide a lane of wind is either side of its middle, or how tall
## a pillar of clay stands.
@export var size := Vector2(1.5, 3.0)

## How long what it leaves behind lasts, in seconds, from a tap to a full wind-up:
## a puddle, a whirl's hold, a stun, a pillar of clay.
@export var duration := Vector2(2.5, 4.0)

## How much of a creature's health it takes, from a tap to a full wind-up, when
## the creature is wrapped all the way: what a spell that harms does. Nought for
## one that does not.
@export var power := Vector2.ZERO

## How far it goes out along the ground, as a share of how far silk reaches, from
## a tap to a full wind-up: what a spell sent out from the spider has instead of a
## place it lands. Nought for one that lands where you point.
@export var travel := Vector2.ZERO

## Its colour, on the strip and in the world.
@export var colour := Color(0.85, 0.88, 0.95, 1.0)

## How many points the star in its magic circle has: the spell's own mark, so two
## circles side by side can be told apart. See [MagicCircle].
@export_range(3, 12) var sigil := 6


## How wide, at [param wound] from 0 for a tap to 1 for a full wind-up, in body
## heights.
func size_at(wound: float) -> float:
	return lerpf(size.x, size.y, clampf(wound, 0.0, 1.0))


## How long, at [param wound], in seconds.
func duration_at(wound: float) -> float:
	return lerpf(duration.x, duration.y, clampf(wound, 0.0, 1.0))


## How much harm, at [param wound], as a share of a creature's health.
func power_at(wound: float) -> float:
	return lerpf(power.x, power.y, clampf(wound, 0.0, 1.0))


## How far, at [param wound], as a share of silk's reach.
func travel_at(wound: float) -> float:
	return lerpf(travel.x, travel.y, clampf(wound, 0.0, 1.0))
