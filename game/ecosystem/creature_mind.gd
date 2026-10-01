class_name CreatureMind
extends RefCounted

## What a creature wants, and what it does about it.
##
## A creature living in an [Ecosystem] has one of these, made when it arrives. It
## gets hungry at its species' own rate, and when it is hungry enough it goes and
## finds something it eats — see [member PreySpecies.diet] — and eats until it is
## full. That is the whole of it for now, and it is enough to make a meadow of
## grazers a place with somewhere to be: they go to the grass, they eat it down,
## they move on to the next patch.
##
## It never moves the creature itself. It decides, and asks the creature to go
## somewhere or to eat something; the creature does the going and the eating —
## see [method Prey.go_to] and [method Prey.start_feeding]. Caught in silk, wrapped,
## stunned or carried off by water, a creature has no say in what happens to it,
## and neither does its mind.

## How often it stops to think, in seconds, give or take a fifth. Each creature
## thinks on its own beat, so a meadow of them does not all decide at once.
const THINK := 0.6

## Hungry enough to go looking for food, and full enough to stop eating.
const HUNGRY := 0.45
const SATED := 0.04

## How much it takes to fill an empty belly, as a share of its own biomass. A deer
## eats a lot of grass; a midge hardly any.
const APPETITE := 0.6

## How long eating a whole belly takes, in seconds. A meal is something a creature
## stands still for, the same as it is for the spider — which is why somewhere a
## creature eats is somewhere to put a web.
const MEAL_TIME := 8.0

var prey: Prey
var kind: PreySpecies
var world: Ecosystem

## How empty its belly is: 0 full, 1 as hungry as it gets.
var hunger := 0.0

## What it is eating, or on its way to eat.
var food: Node3D = null

var _think := 0.0


func _init(creature: Prey, species: PreySpecies, ecosystem: Ecosystem) -> void:
	prey = creature
	kind = species
	world = ecosystem
	hunger = randf_range(0.0, 0.35)
	_think = randf() * THINK


## Whether it eats anything at all. Something that does not is never hungry.
func eats_anything() -> bool:
	return not kind.diet.is_empty()


## Every physics frame, from the creature.
func tick(delta: float) -> void:
	if eats_anything() and prey.is_loose():
		hunger = minf(1.0, hunger + kind.hunger_rate * world.tempo * delta)
	_think -= delta
	if _think <= 0.0:
		_think = THINK * randf_range(0.8, 1.2)
		decide()


## What filling an empty belly takes, in biomass.
func appetite() -> float:
	return maxf(kind.biomass * APPETITE, 0.5)


## How much it gets down in a second of eating, in biomass.
func gulp() -> float:
	return appetite() / MEAL_TIME


## The creature swallowed [param amount] of biomass.
func swallowed(amount: float) -> void:
	hunger = maxf(0.0, hunger - amount / appetite())


## The creature has got where it was going.
func arrived() -> void:
	decide()


## Looks at where things stand and does the next thing.
func decide() -> void:
	if not prey.can_decide():
		return
	if prey.is_feeding():
		if hunger <= SATED or not _worth_eating(food):
			food = null
			prey.stop_feeding()
		return
	# Coming for the spider is its own business, and it sees that through.
	if prey.is_hunting():
		return
	if eats_anything() and hunger >= HUNGRY:
		var meal := find_food()
		if meal != null:
			_go_for(meal)


## The nearest thing it eats that it can get at, or null.
func find_food() -> Node3D:
	var kinds := forage_kinds()
	if kinds.is_empty():
		return null
	return world.forage_near(prey.global_position, kind.senses, kinds)


## The kinds of forage in its diet.
func forage_kinds() -> PackedStringArray:
	var kinds := PackedStringArray()
	for entry in kind.diet:
		if Forage.KINDS.has(entry):
			kinds.append(entry)
	return kinds


## Whether [param other] is food for it, by species or by kind of creature.
func eats(other: PreySpecies) -> bool:
	if other == null:
		return false
	if kind.diet.has(other.id):
		return true
	for tag in other.tags:
		if kind.diet.has(tag):
			return true
	return false


## Close enough to [param meal] to eat it from where it is.
func within_reach(meal: Node3D) -> bool:
	if meal == null or not is_instance_valid(meal):
		return false
	return prey.global_position.distance_to(feeding_spot(meal)) <= reach_of(meal)


## Where to stand, or hover, to eat [param meal]: at the edge of a patch on foot,
## over it on the wing, where the heads of the flowers are.
func feeding_spot(meal: Node3D) -> Vector3:
	var patch := meal as Forage
	if patch == null:
		return meal.global_position
	if prey.flying:
		return patch.global_position + Vector3.UP * (patch.size * 0.5 + prey.hit_radius())
	return patch.global_position


## How close counts, for [param meal].
func reach_of(meal: Node3D) -> float:
	var patch := meal as Forage
	var edge := patch.size * 0.5 if patch != null else 0.0
	return edge + maxf(prey.hit_radius() * 2.0, 0.15)


func _go_for(meal: Node3D) -> void:
	food = meal
	if within_reach(meal):
		prey.start_feeding(meal)
	else:
		prey.go_to(feeding_spot(meal), reach_of(meal) * 0.8)


func _worth_eating(meal: Node3D) -> bool:
	if meal == null or not is_instance_valid(meal):
		return false
	var patch := meal as Forage
	if patch != null:
		return patch.amount > 0.01
	return false
