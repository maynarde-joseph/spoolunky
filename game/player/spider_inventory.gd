class_name SpiderInventory
extends Node

## What the spider is carrying: the dishes it has made and not sold yet, and what
## it has picked from its crops.
##
## A dish goes in when it is taken off a prep table and comes out at the market,
## all at once. Fruit goes in from a melon patch or a berry bush and out into a
## trough; herbs come out onto a fly at the prep table. Everything shares
## [constant CAPACITY] places.

## Something went in or came out.
signal changed()

## How many things the bag holds, dishes and produce together.
const CAPACITY := 12

var dishes: Array[Dish] = []
var produce: Array[Produce] = []


## Puts [param dish] in. False if the bag is full, and nothing changes.
func add(dish: Dish) -> bool:
	if dish == null or is_full():
		return false
	dishes.append(dish)
	changed.emit()
	return true


## Puts [param picked] in. False if the bag is full.
func add_produce(picked: Produce) -> bool:
	if picked == null or is_full():
		return false
	produce.append(picked)
	changed.emit()
	return true


## Takes out one thing grown for [param use], or null if there is none.
func take_produce(use: String) -> Produce:
	for i in produce.size():
		if produce[i].use == use:
			var taken := produce[i]
			produce.remove_at(i)
			changed.emit()
			return taken
	return null


## How many things grown for [param use] are in the bag.
func count_produce(use: String) -> int:
	var found := 0
	for picked in produce:
		found += 1 if picked.use == use else 0
	return found


## Empties the bag of dishes, and hands them over. Produce stays.
func take_all() -> Array[Dish]:
	var taken := dishes.duplicate()
	dishes.clear()
	if not taken.is_empty():
		changed.emit()
	return taken


## How many dishes are in the bag.
func count() -> int:
	return dishes.size()


func is_empty() -> bool:
	return dishes.is_empty()


func is_full() -> bool:
	return dishes.size() + produce.size() >= CAPACITY


## What the dishes in the bag would sell for.
func total_value() -> int:
	var total := 0
	for dish in dishes:
		total += dish.value()
	return total
