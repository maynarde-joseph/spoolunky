class_name SpiderInventory
extends Node

## What the spider is carrying.
##
## Devices are finite and are found rather than spun, which is the whole reason
## they are allowed to do things silk cannot. The bag is therefore the honest
## limit on them: no silk cost, no cooldown, just "you have two left".

## How many slots the bar shows. Fixed, and the bar is the whole inventory:
## what you are carrying is what is on screen, and there is no second screen
## behind it.
const SLOTS := 9

## The bag changed — something was placed, picked up or found.
signal changed()

## A device was added that the spider had none of.
signal found(kind: DeviceKind)

## What the spider starts a level holding, by device id. Anything not listed
## starts at zero, and an id with no matching resource is quietly ignored.
@export var starting_kit := {
	"venom_spur": 2,
	"scent_lure": 1,
	"signal_bell": 1,
}

## Every kind that exists, in the order the placer cycles them.
var kinds: Array[DeviceKind] = []

## Which of the bar's slots is in hand, 0 to SLOTS - 1.
var selected := 0

var _counts := {}


func _ready() -> void:
	kinds = WebLibrary.load_devices()
	for id in starting_kit:
		var kind := kind_by_id(str(id))
		if kind != null:
			_counts[kind.id] = clampi(int(starting_kit[id]), 0, kind.stack_limit)
	changed.emit()


func kind_by_id(id: String) -> DeviceKind:
	for kind in kinds:
		if kind.id == id:
			return kind
	return null


func count(kind: DeviceKind) -> int:
	if kind == null:
		return 0
	return int(_counts.get(kind.id, 0))


## Everything the spider is actually holding right now.
func carried() -> Array[DeviceKind]:
	var held: Array[DeviceKind] = []
	for kind in kinds:
		if count(kind) > 0:
			held.append(kind)
	return held


func total() -> int:
	var sum := 0
	for id in _counts:
		sum += int(_counts[id])
	return sum


## Spends one. False if the bag is empty, and nothing changes.
func take(kind: DeviceKind) -> bool:
	if count(kind) <= 0:
		return false
	_counts[kind.id] = count(kind) - 1
	changed.emit()
	return true


## Puts one in. False if it will not fit, so a picked-up device stays where it
## is rather than evaporating.
func give(kind: DeviceKind, amount := 1) -> bool:
	if kind == null or amount <= 0:
		return false
	var held := count(kind)
	if held >= kind.stack_limit:
		return false
	_counts[kind.id] = mini(held + amount, kind.stack_limit)
	if held == 0:
		found.emit(kind)
	changed.emit()
	return true


func has_room_for(kind: DeviceKind) -> bool:
	return kind != null and count(kind) < kind.stack_limit


## One line for the HUD: what is in the bag, with the selected one marked.
## The bar, slot by slot, with nulls for the empty ones. Carried things fill
## from the left in a stable order, so a slot means the same thing from one
## glance to the next.
func slots() -> Array[DeviceKind]:
	var bar: Array[DeviceKind] = []
	bar.resize(SLOTS)
	var at := 0
	for kind in kinds:
		if at >= SLOTS:
			break
		if count(kind) > 0:
			bar[at] = kind
			at += 1
	return bar


## What is in hand, or null if that slot is empty.
func in_hand() -> DeviceKind:
	var bar := slots()
	return bar[selected] if selected >= 0 and selected < bar.size() else null


## Picks a slot outright. Out-of-range is ignored rather than wrapped, because
## a number key is an exact request.
func select(slot: int) -> void:
	if slot < 0 or slot >= SLOTS or slot == selected:
		return
	selected = slot
	changed.emit()


## Wheels along the bar, wrapping. Empty slots are included: the bar is a fixed
## row of pockets, not a list that closes up.
func scroll(by: int) -> void:
	if by == 0:
		return
	selected = posmod(selected + by, SLOTS)
	changed.emit()


func summary(selected_kind: DeviceKind = null) -> String:
	var held := carried()
	if held.is_empty():
		return "Bag empty"
	var parts := PackedStringArray()
	for kind in held:
		var text := "%s ×%d" % [kind.display_name, count(kind)]
		parts.append("[%s]" % text if kind == selected_kind else " %s " % text)
	return "   ".join(parts)
