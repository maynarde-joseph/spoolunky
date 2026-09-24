@tool
class_name GrowthStage
extends Resource

## One size tier of the spider.
##
## Size is the whole progression system, so nearly every tunable in the game
## hangs off one of these: how big the body is, how far silk can reach, how
## much of it you can hold, what you are strong enough to bite.

@export_group("Identity")

## Name shown in the HUD, e.g. "House Spider".
@export var display_name := "Spiderling"

## Total biomass eaten before this stage is reached. The first stage is 0.
@export var biomass_required := 0.0


@export_group("Body")

## Capsule height in metres. Drives the collider, the eye height and the
## apparent scale of the whole world.
@export var body_height := 0.35

## Ground speed in metres per second.
@export var move_speed := 2.6

## Upward velocity of a jump, in metres per second.
@export var jump_velocity := 4.5


@export_group("Web building")

## How far away an anchor can be shot, in metres.
@export var anchor_range := 4.0

## Longest single strand between two anchors, in metres.
@export var max_strand_length := 3.0

## Multiplies every web's hold strength and durability — bigger spider,
## thicker silk.
@export var silk_quality := 1.0


@export_group("Predation")

## Largest prey size class this stage can subdue. Prey above it shrugs you off.
@export var bite_power := 1

## How far you can reach to wrap or drain something, in metres.
@export var reach := 1.2
