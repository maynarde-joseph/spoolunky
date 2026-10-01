class_name CreatureMind
extends RefCounted

## What a creature wants, and what it does about it.
##
## A creature living in an [Ecosystem] has one of these, made when it arrives. It
## gets hungry at its species' own rate, and when it is hungry enough it goes and
## finds something it eats — see [member PreySpecies.diet] — and eats until it is
## full:
##
## * **Forage** it walks or flies to, and grazes where it stands.
## * **Something alive** it hunts, if it is no bigger than itself: chases it down,
##   kills it, and eats the carcass where it fell.
## * **Carrion** — anything dead — it goes to and eats, whoever killed it.
##
## And before any of that it keeps an eye out. Anything near that would eat it, and
## could, it runs from — from as far off as it can see it if the thing is hunting,
## and only up close if it is not. A wary creature keeps clear of a spider big
## enough to eat it as well.
##
## It never moves the creature itself. It decides, and asks the creature to go
## somewhere, eat something, chase something or run; the creature does the going —
## see [method Prey.go_to], [method Prey.start_feeding], [method Prey.hunt] and
## [method Prey.flee_from]. Caught in silk, wrapped, stunned, carried off by water
## or dead, a creature has no say in what happens to it, and neither does its mind.

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

## How much slower it gets hungry while it rests.
const RESTING_HUNGER := 0.25

## Hungry enough to get up and go and eat out of its hours.
const RAVENOUS := 0.85

## How far off danger is noticed, as a share of how far it notices anything. Food
## is worth walking to; danger only matters when it is close.
const FEAR := 0.6

## How much nearer carrion is than it looks: a free meal is worth going a little
## further for than one that has to be chased.
const CARRION_PULL := 0.7

var prey: Prey
var kind: PreySpecies
var world: Ecosystem

## How empty its belly is: 0 full, 1 as hungry as it gets.
var hunger := 0.0

## What it is eating, or on its way to eat or to kill.
var food: Node3D = null

## What it last ran from, while it is running.
var fleeing_from: Node3D = null

## Where it lives, if it lives somewhere: where it rests, and where its meals are
## put by towards the next of its kind. See [Den].
var den: Den = null

## How long it has been as hungry as it gets, in seconds. At its species'
## [member PreySpecies.starve_after] it starves.
var starving := 0.0

## How many kills it has made, and how many meals it has finished. A den reads
## these to know whether its creatures are eating well.
var kills := 0
var meals := 0

var _think := 0.0


func _init(creature: Prey, species: PreySpecies, ecosystem: Ecosystem) -> void:
	prey = creature
	kind = species
	world = ecosystem
	hunger = randf_range(0.0, 0.35) if eats_anything() else 0.0
	_think = randf() * THINK


## Whether it eats anything at all. Something that does not is never hungry.
func eats_anything() -> bool:
	return not kind.diet.is_empty()


## Every physics frame, from the creature.
func tick(delta: float) -> void:
	if prey.is_dead():
		return
	if eats_anything() and prey.is_loose():
		var rate := kind.hunger_rate * world.tempo
		if prey.is_resting():
			rate *= RESTING_HUNGER
		hunger = minf(1.0, hunger + rate * delta)
		if hunger >= 1.0:
			starving += delta
			if starving >= kind.starve_after:
				prey.wake()
				prey.die()
				return
		else:
			starving = 0.0
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


## The creature caught and killed [param victim], and is eating it.
func made_a_kill(victim: Prey) -> void:
	kills += 1
	food = victim


## A meal finished: put by at home, towards the next of its kind.
func _finished_a_meal() -> void:
	meals += 1
	if den != null and is_instance_valid(den):
		den.ate()


## Back to its den to rest, or resting there if it has arrived.
func _go_home() -> void:
	if den == null or not is_instance_valid(den):
		return
	var spot := den.resting_spot(prey)
	var reach := maxf(prey.hit_radius() * 3.0, den.spread * 0.4)
	var flat := prey.global_position - spot
	if not prey.flying:
		flat.y = 0.0
	if flat.length() <= reach:
		prey.rest(den.shelters)
	elif prey.is_hunting():
		return
	else:
		prey.go_to(spot, reach * 0.8)


## Looks at where things stand and does the next thing.
func decide() -> void:
	if not prey.can_decide():
		return
	# Underground, nothing can get at it and it cannot see out: it only wonders
	# whether it is time to come up.
	if prey.is_sheltered():
		if world.awake(kind.active) or hunger >= RAVENOUS:
			prey.wake()
		return
	var danger := threat()
	if danger != null:
		fleeing_from = danger
		food = null
		if prey.is_resting():
			prey.wake()
		prey.flee_from(danger.global_position)
		return
	fleeing_from = null
	if prey.is_feeding():
		if hunger <= SATED or not _worth_eating(food):
			if hunger <= SATED:
				_finished_a_meal()
			food = null
			prey.stop_feeding()
		return
	if prey.is_resting():
		if world.awake(kind.active) or hunger >= RAVENOUS:
			prey.wake()
		else:
			return
	# Out of its hours, it goes home, unless it is too hungry to.
	if den != null and not world.awake(kind.active) and hunger < RAVENOUS:
		_go_home()
		return
	# A chase is seen through, or given up by the creature itself.
	if prey.is_hunting():
		return
	if eats_anything() and hunger >= HUNGRY:
		var meal := find_food()
		if meal != null:
			_go_for(meal)


# --- danger --------------------------------------------------------------

## The nearest thing that would eat it and could, close enough to run from — or
## null. Something hunting is run from as far off as danger is noticed at all;
## something only passing, from half that.
func threat() -> Node3D:
	var sight := kind.senses * FEAR
	var danger: Node3D = null
	var closest := INF
	for other in world.creatures_near(prey.global_position, sight):
		if other == prey or other.is_dead() or not other.is_loose() or other.swims != prey.swims:
			continue
		var theirs := other.mind()
		if theirs == null or not theirs.eats(kind) or other.size_class < prey.size_class:
			continue
		var gap := other.global_position.distance_to(prey.global_position)
		if not other.is_hunting() and gap > sight * 0.5:
			continue
		if gap < closest:
			closest = gap
			danger = other
	if kind.wary:
		var spider := prey.get_tree().get_first_node_in_group("spider") as Node3D
		if spider != null and spider.has_method("stage") \
				and spider.stage().bite_power >= prey.size_class:
			var gap := spider.global_position.distance_to(prey.global_position)
			var keep := maxf(sight * 0.5, spider.stage().body_height * 3.0)
			if gap < keep and gap < closest:
				danger = spider
	return danger


# --- food ----------------------------------------------------------------

## The best thing it eats that it can get at — a patch, a carcass, or something to
## hunt — or null. Nearest wins, with carrion counted a little nearer than it is.
func find_food() -> Node3D:
	var best: Node3D = null
	var best_gap := INF
	var kinds := forage_kinds()
	if not kinds.is_empty():
		var patch := world.forage_near(prey.global_position, kind.senses, kinds, prey.swims)
		if patch != null:
			best = patch
			best_gap = patch.global_position.distance_to(prey.global_position)
	var scavenges := kind.diet.has("carrion")
	var hunts := _hunts_anything()
	if not scavenges and not hunts:
		return best
	for other in world.creatures_near(prey.global_position, kind.senses):
		if other == prey or other.swims != prey.swims:
			continue
		var gap := other.global_position.distance_to(prey.global_position)
		if other.is_dead():
			if scavenges and other.biomass > 0.5:
				gap *= CARRION_PULL
				if gap < best_gap:
					best_gap = gap
					best = other
		elif hunts and can_take(other) and gap < best_gap:
			best_gap = gap
			best = other
	return best


## Whether [param other] is something it could hunt now: alive, loose, something it
## eats, no bigger than it is — and where it can get at it. What swims keeps to
## the water and everything else keeps out of it, so neither hunts the other: a
## pike does not chase a hare up the bank.
func can_take(other: Prey) -> bool:
	if other == null or not is_instance_valid(other) or other == prey:
		return false
	if other.is_dead() or not other.is_loose() or other.swims != prey.swims:
		return false
	return other.size_class <= prey.size_class and eats(other.kind)


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
## over it on the wing, where the heads of the flowers are; beside a carcass.
func feeding_spot(meal: Node3D) -> Vector3:
	var patch := meal as Forage
	if patch == null:
		return meal.global_position
	if prey.flying:
		return patch.global_position + Vector3.UP * (patch.size * 0.5 + prey.hit_radius())
	return patch.global_position


## How close counts, for [param meal].
func reach_of(meal: Node3D) -> float:
	var edge := 0.0
	var patch := meal as Forage
	if patch != null:
		edge = patch.size * 0.5
	var corpse := meal as Prey
	if corpse != null:
		edge = corpse.hit_radius()
	return edge + maxf(prey.hit_radius() * 2.0, 0.15)


func _hunts_anything() -> bool:
	for entry in kind.diet:
		if entry != "carrion" and not Forage.KINDS.has(entry):
			return true
	return false


func _go_for(meal: Node3D) -> void:
	food = meal
	var quarry := meal as Prey
	if quarry != null and not quarry.is_dead():
		prey.hunt(quarry)
		return
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
	var corpse := meal as Prey
	if corpse != null:
		return corpse.is_dead() and not corpse.eaten and corpse.biomass > 0.01
	return false
