@tool
class_name SpiderSpell
extends Resource

## One thing the spider can cast.
##
## Silk catches: a ball of it thrown at an insect wraps it on the spot, ready to be
## put on a line and dragged off. Every other spell is a step in getting it ready
## to sell — washed in a spiral of water, cooked in a breath of fire — and each one
## does exactly one thing to a bundle on a prep table. Which steps a dish has had,
## and in what order, is what it is called and what it is worth: see [Prep].
##
## A spell is numbers. What it does is its [member form], and the code for each
## form lives in [SpiderSpells]; drop a new .tres built from this script into
## [code]res://game/data/spells/[/code] with an existing form and it is in the
## game, on the disc, with nothing else to edit.

## What a spell is, which decides what casting it does.
enum Form {
	## A ball of silk, thrown. It wraps what it hits.
	SILK,
	## A spiral of water and wind, sent along the ground. It washes.
	WATER_SPIRAL,
	## A gust of wind down a lane. It dries.
	GUST,
	## Lightning, called down where you point. It tenderises.
	LIGHTNING,
	## Fire, breathed out along the cross. It cooks.
	FIRE,
	## The meat pulled apart on silk threads. It pulls what is cooked.
	PULLBACK,
	## Clay, raised up round what you point at. It seals it in a crust.
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

## Its colour, on the disc and in the world.
@export var colour := Color(0.85, 0.88, 0.95, 1.0)

## How many points the star in its magic circle has: the spell's own mark, so two
## circles side by side can be told apart. See [MagicCircle].
@export_range(3, 12) var sigil := 6
