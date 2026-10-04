class_name DungeonRoom
extends Node3D

## One room of the dungeon as its scene has it: the sides with a doorway, the plugs
## that brick up the ones leading nowhere, and the marks inside it — where the spider
## comes in, where creatures can stand, where something can be left — and, in the
## room with the way down, the drop that takes you to the next floor.
##
## Sides are the room's own, before the floor plan turns it: [enum Rooms.Side].

## Which room this is, as [constant Rooms.ROOMS] knows it.
@export var room_id := ""

## The sides with a doorway, before the room is turned.
@export var doors: Array[int] = []

## How high it is inside, floor to roof.
@export var height := 12.0


## Whether the room has a doorway on [param side].
func has_door(side: int) -> bool:
	return doors.has(side)


## The plug bricking up the doorway on [param side], or null if it is open or there
## is no doorway there.
func plug(side: int) -> Node3D:
	return get_node_or_null(NodePath("Shell/Plug%s" % Rooms.SIDE_NAMES[side])) as Node3D


## Opens the doorway on [param side]: takes its plug out. False if there is no
## doorway there, or it is open already.
func open(side: int) -> bool:
	var stopper := plug(side)
	if stopper == null or not has_door(side):
		return false
	stopper.get_parent().remove_child(stopper)
	stopper.free()
	return true


## Whether the doorway on [param side] is there and open.
func is_open(side: int) -> bool:
	return has_door(side) and plug(side) == null


## Where its marks are kept, made if it has none yet.
func marks() -> Node3D:
	var found := get_node_or_null("Marks") as Node3D
	if found == null:
		found = WorldKit.group(self, "Marks")
	return found


## Where the spider comes into the room, if it is a way in.
func entry() -> Marker3D:
	return get_node_or_null("Marks/Entry") as Marker3D


## Where creatures can stand.
func spawns() -> Array[Marker3D]:
	var found: Array[Marker3D] = []
	var holder := get_node_or_null("Marks/Spawns")
	if holder != null:
		for child in holder.get_children():
			if child is Marker3D:
				found.append(child)
	return found


## The drop down to the next floor, if this is the room with the way down.
func way_down() -> Area3D:
	return get_node_or_null("WayDown") as Area3D
