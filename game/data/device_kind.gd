@tool
class_name DeviceKind
extends Resource

## A thing the spider carries and places, rather than spins.
##
## Devices are deliberately **not** better webs. Silk can already catch anything,
## in any orientation, anywhere — so the only room left for an item is doing
## something silk cannot. They are finite, they are found rather than made from
## silk, and they hang off the same signal network webs do.

enum Effect {
	## Kills what it is pointed at, so it can be drained whatever its size.
	## Silk can only ever hold something until you get there.
	VENOM,
	## Draws prey from much further than a web, and needs no web at all.
	LURE,
	## Passes a signal on to the spider wherever it is in the level. This is
	## what makes leaving a trap and coming back to it work.
	BELL,
}

@export var id := "venom_spur"
@export var display_name := "Venom Spur"
@export var description := ""
@export var effect: Effect = Effect.VENOM
@export var colour := Color(0.7, 0.9, 0.4, 1.0)

## How far its effect reaches, in metres.
@export var radius := 4.0

## Spent when it goes off, rather than sitting there.
@export var one_shot := true

## How many the spider can carry.
@export var stack_limit := 6

## Whether it reports into the network, and whether it listens to it.
@export var reports := true
@export var listens := true
