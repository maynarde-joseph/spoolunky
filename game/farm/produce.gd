class_name Produce
extends RefCounted

## Something grown and picked: fruit to fill a trough with, or herbs to season a
## fly with. It goes in the bag beside the dishes; the market does not buy it.

## What it is for: [code]"feed"[/code] goes in a trough, [code]"herb"[/code] on a
## fly at the prep table.
var use := "feed"
var display_name := "Melon"

## How many meals it puts in a trough, if it is feed.
var meals := 0


static func make(produce_name: String, produce_use: String, produce_meals := 0) -> Produce:
	var made := Produce.new()
	made.display_name = produce_name
	made.use = produce_use
	made.meals = produce_meals
	return made


func label() -> String:
	if use == "feed":
		return "%s (%d meals)" % [display_name, meals]
	return display_name
