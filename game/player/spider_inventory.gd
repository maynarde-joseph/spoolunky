class_name SpiderInventory
extends Node

## What the spider is carrying.
##
## Devices are finite and are found rather than spun, which is the whole reason
## they are allowed to do things silk cannot. The bag is therefore the honest
## limit on them: no silk cost, no cooldown, just "you have two left".

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
func summary(selected: DeviceKind = null) -> String:
	var held := carried()
	if held.is_empty():
		return "Bag empty"
	var parts := PackedStringArray()
	for kind in held:
		var text := "%s ×%d" % [kind.display_name, count(kind)]
		parts.append("[%s]" % text if kind == selected else " %s " % text)
	return "   ".join(parts)
