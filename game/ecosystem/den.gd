class_name Den
extends Node3D

## Where a species lives: a burrow, a nest, a hive, a roost.
##
## A den keeps its creatures. It puts the first of them out when the level opens,
## and from then on they breed — but only as well as they eat. Every meal one of
## them finishes is put by, and a new one is born when enough has been put by and
## there is room for it. A den whose creatures eat well fills up; one whose
## creatures go hungry stays as it is and dwindles as they are eaten or starve. If
## it empties altogether, one of its kind wanders in from elsewhere in the end, so
## a species can be hunted out of a place but never out of the world.
##
## That is the whole population model, and it is enough for the numbers to move
## the way they should: too many hares eat the grass down and stop breeding;
## foxes that are eating hares breed, and then there are fewer hares, and the
## foxes go hungry. Nothing has to be told to keep the balance. It is what the
## eating does.
##
## It is also home. Its creatures wander about it, and go back to it to rest when
## it is not their time of day — out of sight underground, for something that
## lives in a burrow.

const GROUP := "dens"

## Who lives here, by species id — or [member species], for a check that wants a
## species of its own.
@export var species_id := "hare"
@export var species: PreySpecies

## The most it holds, and how many are put out when the level opens.
@export var capacity := 6
@export var start := 4

## How many meals have to be put by for one to be born, and the least time between
## two births, in seconds.
@export var meals_per_birth := 2.0
@export var breed_every := 20.0

## How long it stays empty before one of its kind wanders in, in seconds.
@export var recolonise := 90.0

## How far from the den its creatures are put down, in metres.
@export var spread := 3.0

## Whether resting here is out of sight and out of reach: a burrow, a hive, a hole
## in a tree. Something resting in the open — a roost, a nest on a ledge — can
## still be got at.
@export var shelters := true

## Its creatures, alive.
var members: Array[Prey] = []

## Meals put by towards the next birth.
var larder := 0.0

## How many it has had, start included, and how many of those it had because a
## den of them ate well.
var born := 0
var bred := 0

var _breed_in := 0.0
var _empty_for := 0.0


func _ready() -> void:
	add_to_group(GROUP)
	if species == null:
		species = PreyLibrary.find(species_id)
	if species == null:
		push_warning("a den for %s, which is no species" % species_id)
		return
	species_id = species.id
	for i in mini(start, capacity):
		hatch()


func _physics_process(delta: float) -> void:
	if species == null:
		return
	_prune()
	if members.is_empty():
		_empty_for += delta
		if _empty_for >= recolonise:
			_empty_for = 0.0
			hatch()
		return
	_empty_for = 0.0
	_breed_in -= delta
	if _breed_in <= 0.0 and members.size() < capacity and larder >= meals_per_birth:
		larder -= meals_per_birth
		_breed_in = breed_every
		bred += 1
		hatch()


## One of its creatures finished a meal.
func ate() -> void:
	larder += 1.0


## Puts one of its creatures out, and returns it.
func hatch() -> Prey:
	var creature := Prey.of(species)
	if creature == null:
		return null
	# Added before it is placed, so it takes the den as home: where a creature is
	# when it arrives is where it wanders about.
	add_child(creature)
	creature.global_position = _spot()
	creature.belongs_to(self)
	members.append(creature)
	born += 1
	return creature


## How many of its creatures are alive now.
func count() -> int:
	_prune()
	return members.size()


## Where one of its creatures rests: the den itself, a little to one side so they
## do not all stand in the one place.
func resting_spot(creature: Prey) -> Vector3:
	var turn := float(creature.get_instance_id() % 97) / 97.0 * TAU
	var aside := Vector3(cos(turn), 0.0, sin(turn)) * spread * 0.3
	return global_position + aside


func _prune() -> void:
	var alive: Array[Prey] = []
	for creature in members:
		if is_instance_valid(creature) and not creature.eaten and not creature.is_dead():
			alive.append(creature)
	members = alive


## Somewhere near the den to put a creature down: on the ground for something that
## walks, at its own height for something that flies, in the water for something
## that swims.
func _spot() -> Vector3:
	var turn := randf() * TAU
	var out := Vector3(cos(turn), 0.0, sin(turn)) * spread * sqrt(randf())
	var point := global_position + out
	if species.swims:
		return point
	if species.flying:
		return point + Vector3.UP * randf_range(species.wander_height.x, species.wander_height.y)
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * spread,
		point + Vector3.DOWN * spread * 2.0, GameLayers.WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var ground: Vector3 = hit.get("position", point) if not hit.is_empty() else point
	return ground + Vector3.UP * maxf(0.05, species.body_radius * Prey.HITBOX_SCALE)
