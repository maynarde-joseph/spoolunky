@tool
class_name StructureKind
extends Resource

## Something the spider can build on the farm: a length of fence, a gate, a
## trough, a pond, a table to cook at.
##
## The numbers are here; what it looks like and what it does is the code for its
## [member id] — see [method FarmStructure.make]. A new .tres in
## [code]res://game/data/structures/[/code] with an id that code knows is a new
## card in the shop.

## How it goes down on the land.
enum Placement {
	## A length of fence: from one corner of the grid to another, the outline of the
	## rectangle between them — or a straight run if they share a row.
	RUN,
	## On one edge between two cells: a gate, swapped in for the fence already
	## there or put up on its own.
	EDGE,
	## On a patch of cells [member footprint] big.
	CELLS,
}

@export var id := "trough"
@export var display_name := "Trough"
@export_multiline var description := ""

## The row it is shown in, in the shop.
@export var category := "Care"

## Where it sits in its row, low first.
@export var sort_order := 0

## What one costs, in coins: a length, for a fence.
@export var cost := 20

@export var placement: Placement = Placement.CELLS

## How many cells it covers, across and deep, before it is turned.
@export var footprint := Vector2i.ONE
