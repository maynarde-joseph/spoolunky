class_name SpiderTraits
extends Node

## What the spider has become, and what it has eaten toward becoming more.
##
## Two things live here because they are the same thing seen from either end:
## the larder — a tally of every creature drained, by species — and the traits
## that tally has been spent on. That is the whole economy of the tree. Biomass
## still grows you along the ladder, so eating is never the wrong move; the
## larder is what makes eating a *choice*, because a beetle spent on Broad Back
## is a beetle not spent on Hunting Fangs.
##
## Traits act on the world by reshaping the size tier — see [method shape] —
## which is why nothing else in the game had to learn about them. Everything
## already asks [method SpiderGrowth.current_stage] how tall it is and how far
## its silk goes, and that answer now has the traits folded in.

## A trait was bought, or something was eaten. The tree redraws off this.
signal changed()

## A trait was bought. Carries the trait, for the message.
signal gained(gift: SpiderTrait)

## Leave empty to load every trait in the traits folder.
@export var tree: Array[SpiderTrait] = []

## Trait id to true, for everything owned.
var owned := {}

## Species id to how many of that creature have been eaten and not yet spent.
var larder := {}


func _ready() -> void:
	if tree.is_empty():
		tree = TraitLibrary.load_traits()


# --- the larder ---------------------------------------------------------

## Notes a drained creature. Called by the spider, which is the only thing that
## knows a creature went down rather than got away.
func record(species: PreySpecies) -> void:
	if species == null:
		return
	larder[species.id] = eaten(species.id) + 1
	changed.emit()


## How many of that species are in the larder, unspent.
func eaten(species_id: String) -> int:
	return int(larder.get(species_id, 0))


## Everything unspent, most numerous first. For the line above the tree.
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


## Species still short, by id. Empty when the larder covers it.
func shortfall(gift: SpiderTrait) -> Dictionary:
	var short := {}
	if gift == null:
		return short
	for species_id in gift.cost:
		var want := int(gift.cost[species_id])
		var held := eaten(str(species_id))
		if held < want:
			short[str(species_id)] = want - held
	return short


func affordable(gift: SpiderTrait) -> bool:
	return gift != null and shortfall(gift).is_empty()


## Spends the larder and takes the trait. False — and nothing changes — if it
## is already owned, still locked, or not paid for.
func buy(gift: SpiderTrait) -> bool:
	if gift == null or has(gift.id) or not unlocked(gift) or not affordable(gift):
		return false
	for species_id in gift.cost:
		var key := str(species_id)
		larder[key] = eaten(key) - int(gift.cost[species_id])
	owned[gift.id] = true
	gained.emit(gift)
	changed.emit()
	return true


## What it costs, written out. Marks what is still short rather than what is
## held, because the shortfall is the only part you can act on.
func cost_line(gift: SpiderTrait) -> String:
	if gift == null:
		return ""
	var parts := PackedStringArray()
	for species_id in gift.cost:
		var key := str(species_id)
		var want := int(gift.cost[species_id])
		var kind := PreyLibrary.find(key)
		var label: String = kind.display_name if kind != null else key.capitalize()
		parts.append("%d %s (%d)" % [want, label, eaten(key)])
	return "   ".join(parts)


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
		shaped.silk_capacity *= gift.silk_scale
		shaped.silk_regen *= gift.regen_scale
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


## Whether a kill still needs a web behind it.
func has_fangs() -> bool:
	for gift in tree:
		if has(gift.id) and gift.fangs:
			return true
	return false
