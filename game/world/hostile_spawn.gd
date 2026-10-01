class_name HostileSpawn
extends Node3D

## Where one hostile creature lives, and where it is put back when the Hollows
## stir.
##
## Something hostile here is a fixture of its room: you learn where it stands,
## you get past it or put it down, and when you rest it is back where it was —
## the room is the same room again. That is all this is: a mark with a species
## on it, the creature it stands up, and [method reset] to stand a fresh one up
## in its place, whatever became of the last. Anything the creature called up
## went into the world under this mark, and goes with it.
##
## A boss is the exception. One that [member stays_beaten] is back at its post
## after it beats you, as if you had never come; once you have beaten it, it
## stays beaten.

signal beaten_for_good(spawn: HostileSpawn)

## The hostile species it stands up, by id. See [method CreatureFighter.hostile_species].
@export var species_id := ""

## Stays down once beaten, through every rest and every waking: a boss.
@export var stays_beaten := false

## Whether the one here has been beaten for good.
@export var beaten := false

## A beat to walk, for one that roams rather than keeps to a room: points in world
## space it goes between in turn while it is not after you. Empty, and it keeps
## to its mark.
@export var route := PackedVector3Array()

## Seconds it spends about each point of its beat before it moves on.
@export var dwell := 14.0

var creature: Prey = null

var _leg := 0
var _dwelt := 0.0


func _ready() -> void:
	add_to_group("hostile_spawns")
	if not beaten and not Engine.is_editor_hint():
		stand_up.call_deferred()


func _physics_process(delta: float) -> void:
	if stays_beaten and not beaten and creature != null and is_down():
		_beat()
	_walk_the_beat(delta)


func _beat() -> void:
	beaten = true
	beaten_for_good.emit(self)


## Moves its haunt on to the next point of its beat, every so often, while it is
## not busy with you.
func _walk_the_beat(delta: float) -> void:
	if route.is_empty() or is_down() or creature.is_hunting():
		return
	_dwelt += delta
	if _dwelt < dwell:
		return
	_dwelt = 0.0
	_leg = (_leg + 1) % route.size()
	creature.wander_about(route[_leg], true)


## Where on its beat it is making for, or its mark if it has none.
func beat_point() -> Vector3:
	return route[_leg] if not route.is_empty() else global_position


## The species, as it ships.
func species() -> PreySpecies:
	return CreatureFighter.hostile_species(species_id)


## A fresh one at the mark, in place of whatever was here.
func stand_up() -> Prey:
	_clear()
	var kind := species()
	if kind == null:
		push_warning("%s: no hostile species '%s'" % [name, species_id])
		return null
	creature = Prey.of(kind)
	add_child(creature)
	creature.global_position = global_position
	_leg = 0
	_dwelt = 0.0
	if not route.is_empty():
		creature.wander_about(route[0])
	return creature


## Whether the one here is out of the fight: wrapped, bundled, eaten, dead or gone.
func is_down() -> bool:
	if creature == null or not is_instance_valid(creature) or creature.is_queued_for_deletion():
		return true
	return creature.eaten or creature.wrapped or creature.is_bundled() or creature.is_dead()


## Put back as it was: a fresh one at the mark, unless this is a boss that has
## been beaten for good.
func reset() -> void:
	# Put down in the same moment as the stir, before anything noticed: it still
	# counts, and whatever waits on it still hears.
	if stays_beaten and not beaten and creature != null and is_down():
		_beat()
	if stays_beaten and beaten:
		_clear()
		return
	stand_up()


func _clear() -> void:
	for child in get_children():
		if child is Prey:
			remove_child(child)
			child.queue_free()
	creature = null
