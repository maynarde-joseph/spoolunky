class_name SpiderInventory
extends Node

## What the spider is carrying: the dishes it has made and not sold yet.
##
## A dish goes in when it is taken off a prep table and comes out at the market,
## all at once. The bag holds [constant CAPACITY] of them, which is the one reason
## to walk to the market before the kitchen is done for the day.

## Something went in or came out.
signal changed()

## How many dishes the bag holds.
const CAPACITY := 12

var dishes: Array[Dish] = []


## Puts [param dish] in. False if the bag is full, and nothing changes.
func add(dish: Dish) -> bool:
	if dish == null or is_full():
		return false
	dishes.append(dish)
	changed.emit()
	return true


## Empties the bag, and hands over what was in it.
func take_all() -> Array[Dish]:
	var taken := dishes.duplicate()
	dishes.clear()
	if not taken.is_empty():
		changed.emit()
	return taken


func count() -> int:
	return dishes.size()


func is_empty() -> bool:
	return dishes.is_empty()


func is_full() -> bool:
	return dishes.size() >= CAPACITY


## What everything in the bag would sell for.
func total_value() -> int:
	var total := 0
	for dish in dishes:
		total += dish.value()
	return total
