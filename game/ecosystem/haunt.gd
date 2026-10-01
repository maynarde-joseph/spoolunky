class_name Haunt
extends Node3D

## Somewhere a big creature goes: a glade it grazes, a ridge it watches from, a
## pool it drinks at.
##
## Something that roams — see [member PreySpecies.roams] — does not keep to the
## country round its den the way a hare does. Every so often it leaves wherever it
## is for another of its haunts and wanders about that one instead, which is how
## the biggest things in the hunting ground get from one part of it to another:
## why a stag can turn up in the ruins, and why the wyvern is sometimes over the
## glade and sometimes not.

const GROUP := "haunts"

## Who comes here, by species id. Empty for anything that roams.
@export var species_ids := PackedStringArray()

## How far round it a creature wanders once it is here, in metres.
@export var radius := 12.0


func _ready() -> void:
	add_to_group(GROUP)


## Whether [param kind] comes here.
func welcomes(kind: PreySpecies) -> bool:
	return kind != null and (species_ids.is_empty() or species_ids.has(kind.id))


## Where [param creature] makes for, arriving: the haunt itself, or above it at
## its own height for something that flies.
func spot_for(creature: Prey) -> Vector3:
	var at := global_position
	if creature != null and creature.flying and creature.kind != null and not creature.swims:
		var band := creature.kind.wander_height
		at.y += (band.x + band.y) * 0.5
	return at
