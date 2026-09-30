class_name SpiderTraits
extends Node

## What the spider has become, and what it has eaten.
##
## Traits come from what you eat. Every creature carries a few, and each meal you
## finish is a chance one of them passes to you — see [method digest]. Nothing is
## bought and nothing is spent: eating is the whole of it, which keeps the one
## thing worth protecting, that there is never a reason to stop.
##
## The odds climb three ways, and [method odds] is all of them in one place:
##
## * **Up the ladder.** Every rung past the first raises every chance, so the
##   further along you are the more a meal can do to you.
## * **Bad luck runs out.** Every meal a trait could have come from and did not
##   makes it likelier next time, until it is certain. Luck can slow you down;
##   it can never lock you out.
## * **The bigger it is next to you.** One size past your bite doubles the odds.
##   Anything further past it than that is a sure thing: taking down something
##   you had no business taking on always pays, and if it carries nothing you
##   could take, it pays in something else you could.
##
## The larder is the other half: a tally of every creature drained, by species.
## Nothing is spent from it any more, so it is simply a record of what you have
## hunted.
##
## Traits act on the world by reshaping the size tier — see [method shape] —
## which is why nothing else in the game had to learn about them. Everything
## already asks [method SpiderGrowth.current_stage] how tall it is and how far
## its silk goes, and that answer has the traits folded in.

## A trait was taken, or something was eaten. The tree redraws off this.
signal changed()

## A trait passed to the spider. Carries the trait and the name of the creature it
## came from — empty when it came from nowhere in particular.
signal gained(gift: SpiderTrait, source: String)

## Leave empty to load every trait in the traits folder.
@export var tree: Array[SpiderTrait] = []

## Whether a meal can change the spider at all. On in play. A check that is
## measuring the body turns it off, so a lucky fly cannot resize the spider half-way
## through what it is measuring.
@export var evolving := true

## How much each rung of the ladder past the first adds to every chance, as a share
## of it. At a quarter, a spider on the fifth rung has twice a spiderling's odds.
@export_range(0.0, 2.0, 0.05) var evolution_boost := 0.25

## How much each miss adds to the next roll for the same trait, as a share of its
## chance. At a half, a trait with a one-in-ten chance is certain by the nineteenth
## meal that could have given it.
@export_range(0.0, 2.0, 0.05) var pity := 0.5

## What eating something one size past your bite does to the odds.
@export_range(1.0, 5.0, 0.1) var stretch := 2.0

## How many sizes past your bite something has to be for eating it to be a sure
## thing.
@export_range(1, 9) var sure_past := 2

## Trait id to true, for everything owned.
var owned := {}

## Species id to how many of that creature have been eaten.
var larder := {}

## Trait id to how many meals could have passed it on and did not. Cleared when it
## comes.
var misses := {}

## The dice. Its own, so a check can seed it and get the same meals every time.
var dice := RandomNumberGenerator.new()


func _ready() -> void:
	if tree.is_empty():
		tree = TraitLibrary.load_traits()
	dice.randomize()


# --- the larder ---------------------------------------------------------

## Notes a drained creature. Called by the spider, which is the only thing that
## knows a creature went down rather than got away.
func record(species: PreySpecies) -> void:
	if not is_wild(species):
		return
	larder[species.id] = eaten(species.id) + 1
	changed.emit()


## Whether [param species] is one of the game's creatures, rather than a practice
## target off a post in the gym. Those are drunk like anything else, but they are
## not in the world, and nothing about them counts toward what you are.
static func is_wild(species: PreySpecies) -> bool:
	return species != null and PreyLibrary.find(species.id) != null


## How many of that species have been eaten.
func eaten(species_id: String) -> int:
	return int(larder.get(species_id, 0))


## Everything eaten so far, species by species. For the line above the tree.
func larder_line() -> String:
	var species := PreyLibrary.load_species()
	var parts := PackedStringArray()
	for kind in species:
		var held := eaten(kind.id)
		if held > 0:
			parts.append("%s ×%d" % [kind.display_name, held])
	return "   ".join(parts) if parts.size() > 0 else "Nothing eaten yet"


# --- the tree -----------------------------------------------------------

func by_id(trait_id: String) -> SpiderTrait:
	for gift in tree:
		if gift.id == trait_id:
			return gift
	return null


func has(trait_id: String) -> bool:
	return owned.get(trait_id, false)


## The traits of one branch, shallowest first. Takes the branch as a plain int
## so the tree can walk the branches by number without naming each one.
func branch(which: int) -> Array[SpiderTrait]:
	var found: Array[SpiderTrait] = []
	for gift in tree:
		if gift.branch == which:
			found.append(gift)
	return found


## Whether what this one is built on is already owned.
func unlocked(gift: SpiderTrait) -> bool:
	if gift == null:
		return false
	for needed in gift.requires:
		if not has(needed):
			return false
	return true


## Every trait the spider could take now, from anything: not owned yet, and
## standing on everything it needs.
func open_traits() -> Array[SpiderTrait]:
	var found: Array[SpiderTrait] = []
	for gift in tree:
		if not has(gift.id) and unlocked(gift):
			found.append(gift)
	return found


## The open traits [param kind] carries — what a meal of it could do to you now.
func carried(kind: PreySpecies) -> Array[SpiderTrait]:
	var found: Array[SpiderTrait] = []
	if kind == null:
		return found
	for gift in open_traits():
		if gift.carried_by.has(kind.id):
			found.append(gift)
	return found


## The creatures that carry [param gift], in the order the game lists them.
func carriers(gift: SpiderTrait) -> Array[PreySpecies]:
	var found: Array[PreySpecies] = []
	if gift == null:
		return found
	for kind in PreyLibrary.load_species():
		if gift.carried_by.has(kind.id):
			found.append(kind)
	return found


# --- evolving -----------------------------------------------------------

## What a finished meal of [param kind] does to you. Rolls for each open trait it
## carries, in a shuffled order, and takes the first that comes up — at most one a
## meal. Returns it, or null.
##
## [param rung] is where the spider is on the ladder, 0 for a spiderling, and
## [param past] is how many sizes past its bite the creature was when the meal
## began.
func digest(kind: PreySpecies, rung: int, past := 0) -> SpiderTrait:
	if not evolving or not is_wild(kind):
		return null
	var hopes := carried(kind)
	if hopes.is_empty() and past >= sure_past:
		hopes = open_traits()
	# Shuffled with the traits' own dice, so which of two traits a creature
	# carries is tried first is luck, not the order the folder lists them in.
	for i in range(hopes.size() - 1, 0, -1):
		var j := dice.randi_range(0, i)
		var swap := hopes[i]
		hopes[i] = hopes[j]
		hopes[j] = swap
	for gift in hopes:
		if dice.randf() < odds(gift, kind, rung, past):
			take(gift, kind.display_name)
			return gift
		misses[gift.id] = missed(gift.id) + 1
	return null


## The chance, 0 to 1, that one meal of [param kind] passes [param gift] on, for a
## spider on rung [param rung] of the ladder eating something [param past] sizes
## past its bite.
##
## Nothing for a trait already owned or still standing on one that is not, or
## from a creature that does not carry it — unless the creature is far enough past
## your bite that anything open is certain.
func odds(gift: SpiderTrait, kind: PreySpecies, rung: int, past := 0) -> float:
	if gift == null or has(gift.id) or not unlocked(gift):
		return 0.0
	if past >= sure_past:
		return 1.0
	if kind == null or not gift.carried_by.has(kind.id):
		return 0.0
	var chance := gift.chance * evolution_scale(rung) * (1.0 + pity * float(missed(gift.id)))
	if past >= 1:
		chance *= stretch
	return clampf(chance, 0.0, 1.0)


## What the ladder does to every chance at rung [param rung].
func evolution_scale(rung: int) -> float:
	return 1.0 + evolution_boost * float(maxi(rung, 0))


## How many meals could have passed [param trait_id] on and did not.
func missed(trait_id: String) -> int:
	return int(misses.get(trait_id, 0))


## Takes a trait. False — and nothing changes — if it is already owned or still
## stands on one that is not. [param source] names what it came from, for the
## message.
func take(gift: SpiderTrait, source := "") -> bool:
	if gift == null or has(gift.id) or not unlocked(gift):
		return false
	owned[gift.id] = true
	misses.erase(gift.id)
	gained.emit(gift, source)
	changed.emit()
	return true


# --- what the traits actually do ----------------------------------------

## The size tier with every owned trait folded into it.
##
## This is the whole mechanism. Scales multiply, bonuses add, and the result is
## an ordinary [GrowthStage] — so the climb component, the web builder, the
## thresholds and the HUD all pick the traits up without knowing they exist.
func shape(base: GrowthStage) -> GrowthStage:
	if base == null:
		return GrowthStage.new()
	if owned.is_empty():
		return base
	var shaped := base.duplicate() as GrowthStage
	for gift in tree:
		if not has(gift.id):
			continue
		# Size carries reach with it. That is not an extra effect bolted on —
		# it is what size means on the ladder this is multiplying, where every
		# one of these numbers climbs together tier by tier.
		shaped.body_height *= gift.body_scale
		shaped.reach *= gift.body_scale
		shaped.anchor_range *= gift.body_scale * gift.reach_scale
		shaped.max_strand_length *= gift.body_scale * gift.reach_scale
		shaped.move_speed *= gift.speed_scale
		shaped.jump_velocity *= gift.jump_scale
		shaped.silk_quality *= gift.quality_scale
		shaped.bite_power += gift.bite_bonus
	return shaped


## Multiplies what comes out of a drained creature.
func drain_scale() -> float:
	var scale := 1.0
	for gift in tree:
		if has(gift.id):
			scale *= gift.drain_scale
	return scale


## How much of a fall the wings cancel, 0 for none. Capped short of whole, so
## there is always a floor coming and always a reason to aim for one.
func glide() -> float:
	var lift := 0.0
	for gift in tree:
		if has(gift.id):
			lift += gift.glide
	return clampf(lift, 0.0, 0.9)


## What every owned trait does to the wait between casts, silk's included. See
## [member SpiderTrait.cast_scale].
func cast_scale() -> float:
	var scale := 1.0
	for gift in tree:
		if has(gift.id):
			scale *= gift.cast_scale
	return scale


## Whether the spider's water eats what it holds. See
## [member SpiderTrait.acid_water].
func acid_water() -> bool:
	for gift in tree:
		if has(gift.id) and gift.acid_water:
			return true
	return false


## What every owned trait does to how long a stun lasts. See
## [member SpiderTrait.stun_scale].
func stun_scale() -> float:
	var scale := 1.0
	for gift in tree:
		if has(gift.id):
			scale *= gift.stun_scale
	return scale


## How many more times the spider's lightning jumps on. See
## [member SpiderTrait.arc_bonus].
func arc_bonus() -> int:
	var total := 0
	for gift in tree:
		if has(gift.id):
			total += gift.arc_bonus
	return total


## Whether a kill still needs a web behind it.
func has_fangs() -> bool:
	for gift in tree:
		if has(gift.id) and gift.fangs:
			return true
	return false
