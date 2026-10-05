@tool
class_name SpiderSpell
extends Resource

## One thing the spider can cast.
##
## Silk catches: a ball of it thrown at a fly wraps it on the spot, ready to be put
## on a line and dragged off. Every other spell does something in the world — a
## gust drives flies, lightning stuns them, a spiral of water holds one — and does
## its one kitchen step to any wrapped fly it reaches: washed in the spiral, cooked
## in the fire. Which steps a dish has had is what it is called and what it is
## worth: see [Prep]. Hold the key to wind a spell up bigger before it goes.
##
## A spell is numbers. What it does is its [member form], and the code for each
## form lives in [SpiderSpells]; drop a new .tres built from this script into
## [code]res://game/data/spells/[/code] with an existing form and it is in the
## game, on the disc, with nothing else to edit.

## What a spell is, which decides what casting it does.
enum Form {
	## A ball of silk, thrown. It wraps what it hits.
	SILK,
	## A spiral of water and wind, sent along the ground. It holds the first fly it
	## reaches, and washes.
	WATER_SPIRAL,
	## A gust of wind down a lane. It drives flies along, and dries.
	GUST,
	## Lightning, called down where you point. It stuns flies, and tenderises.
	LIGHTNING,
	## Fire, breathed out along the cross. It scares flies off, and cooks.
	FIRE,
	## Silk threads to every bundle in reach. It hauls them in, and pulls apart what
	## is cooked.
	PULLBACK,
	## A pillar of clay, raised where you point — or a crust of it, round a bundle.
	EARTH,
}

@export var id := "silk"
@export var display_name := "Silk"

## One line, on the disc and in the help.
@export_multiline var description := ""

@export var form: Form = Form.SILK

## Where it sits on the disc, first to last; also the number key that takes it.
@export var order := 0

## Seconds before it can be cast again.
@export var cooldown := 1.0


@export_group("Wind-up")

## Every number below goes from a tap, on the left, to a full wind-up, on the
## right: hold the key and the spell grows while its circle forms.

## How big it is, in metres: how wide a ball of silk, a spiral or a lane of wind;
## how far a breath of fire or a pullback reaches; how wide a strike; how tall a
## pillar of clay.
@export var size := Vector2(1.0, 1.5)

## How long what it does lasts, in seconds: a fly held in a spiral, a stun, a
## breath of fire, a shove, a pillar standing.
@export var duration := Vector2(2.0, 3.0)

## How far it goes along the ground, in metres: a spiral, a gust. Nought for one
## that lands where you point.
@export var travel := Vector2.ZERO

## Its colour, on the disc and in the world.
@export var colour := Color(0.85, 0.88, 0.95, 1.0)

## How many points the star in its magic circle has: the spell's own mark, so two
## circles side by side can be told apart. See [MagicCircle].
@export_range(3, 12) var sigil := 6


func size_at(wound: float) -> float:
	return lerpf(size.x, size.y, clampf(wound, 0.0, 1.0))


func duration_at(wound: float) -> float:
	return lerpf(duration.x, duration.y, clampf(wound, 0.0, 1.0))


func travel_at(wound: float) -> float:
	return lerpf(travel.x, travel.y, clampf(wound, 0.0, 1.0))
