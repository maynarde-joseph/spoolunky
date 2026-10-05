@tool
class_name InsectSpecies
extends Resource

## A kind of insect the farm can raise: what it looks like, what it needs, how
## quickly it comes on, and what it is worth at the end.
##
## Drop a new .tres built from this script into [code]res://game/data/insects/[/code]
## and it is in the game, with nothing else to edit: one [Insect] serves every kind
## and takes its body and its numbers from here.
##
## The farming is the numbers in [code]Keeping[/code]. Kept fed, watered and with
## room to move, an insect grows to market weight in [member grow_time] seconds and
## its grade climbs from A1 to A5 over [member grade_time] — the way a herd is
## raised for marbling rather than just for weight. Hungry, thirsty or crowded, it
## does neither, and its grade slips back.

@export var id := "ant"
@export var display_name := "Ant"
@export_multiline var description := ""

## Where it sits in the shop, low first.
@export var sort_order := 0


@export_group("Body")

## What it looks like and how it moves. See [InsectBody].
@export var body: CreatureBody

## How big a grown one is: the radius of its body, in metres. A hatchling is
## [constant Insect.HATCHLING] of this, and it fills out as it grows.
@export var adult_radius := 0.26

## Whether it flies about its pen rather than walking it. A pen holds a flier the
## same as a walker: it keeps to its own ground and will not go over a fence.
@export var flying := false

## How high a flier keeps off the ground, in metres: the bottom and the top of
## where it goes.
@export var hover := Vector2(0.5, 1.4)

## How fast a grown one gets about, in metres a second.
@export var move_speed := 1.4


@export_group("Keeping")

## Seconds of good keeping it takes to grow from a hatchling to market weight.
@export var grow_time := 120.0

## Seconds of good keeping it takes to go from grade A1 to A5.
@export var grade_time := 240.0

## Seconds from fed to hungry, and from watered to thirsty.
@export var hunger_time := 50.0
@export var thirst_time := 70.0

## How much ground each one wants, in square metres. Fewer than the pen has room
## for and they come on at full speed; more, and they all come on slower.
@export var space := 4.0


@export_group("Trade")

## What one grown, grade A1, plain roast is worth, in coins. Everything else is
## a share of this: see [Dish].
@export var value := 20
