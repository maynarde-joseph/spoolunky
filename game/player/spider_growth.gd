class_name SpiderGrowth
extends Node

## Biomass in, size out.
##
## Holds the ladder of [GrowthStage] resources and decides when the spider has
## eaten enough to move up it. It does not resize anything itself — it just
## announces the new stage and lets the spider apply it.
##
## The tier it announces is the ladder's tier with the spider's traits folded
## in — see [method SpiderTraits.shape]. Everything in the game asks this node
## how big the spider is, so that is the one place traits have to reach for all
## of them to pick them up, and buying one is announced exactly the same way
## growing a tier is.

signal stage_changed(stage: GrowthStage, index: int)
signal biomass_changed(biomass: float, progress: float)
signal fed(amount: float, source: String)

## Leave empty to use the default ladder from [WebLibrary].
@export var stages: Array[GrowthStage] = []

var biomass := 0.0
var stage_index := 0

## What the spider has become. Set by the spider; null means the bare ladder.
var traits: SpiderTraits

var _shaped: GrowthStage


func _ready() -> void:
	if stages.is_empty():
		stages = WebLibrary.default_stages()


## Hands the traits node over. A trait changes the body, so buying one has to
## go out as a stage change — that is the path the spider already has for
## resizing itself, and there is no reason for a second one.
func shaped_by(new_traits: SpiderTraits) -> void:
	traits = new_traits
	if traits != null and not traits.changed.is_connected(_on_traits_changed):
		traits.changed.connect(_on_traits_changed)
	_reshape()


## Announces the starting stage. Called by the spider once it is set up.
func apply_initial() -> void:
	stage_index = 0
	_reshape()
	stage_changed.emit(current_stage(), stage_index)
	biomass_changed.emit(biomass, progress())


## The tier as the ladder wrote it, before any trait has had a say.
func base_stage() -> GrowthStage:
	if stages.is_empty():
		return GrowthStage.new()
	return stages[clampi(stage_index, 0, stages.size() - 1)]


## The tier the spider actually is: the ladder's, reshaped by its traits.
func current_stage() -> GrowthStage:
	if _shaped == null:
		_reshape()
	return _shaped


func next_stage() -> GrowthStage:
	if stage_index + 1 >= stages.size():
		return null
	return stages[stage_index + 1]


## Eats [param amount] of biomass. Returns how many size tiers that gained.
func feed(amount: float, source := "") -> int:
	if amount <= 0.0:
		return 0
	biomass += amount
	fed.emit(amount, source)
	var gained := 0
	while true:
		var next := next_stage()
		if next == null or biomass < next.biomass_required:
			break
		stage_index += 1
		gained += 1
		_reshape()
		stage_changed.emit(current_stage(), stage_index)
	biomass_changed.emit(biomass, progress())
	return gained


## 0..1 toward the next size tier. Returns 1.0 when fully grown.
func progress() -> float:
	var next := next_stage()
	if next == null:
		return 1.0
	var floor_value := base_stage().biomass_required
	var span: float = maxf(next.biomass_required - floor_value, 0.001)
	return clampf((biomass - floor_value) / span, 0.0, 1.0)


## Biomass still needed for the next tier, or 0 when fully grown.
func biomass_to_next() -> float:
	var next := next_stage()
	if next == null:
		return 0.0
	return maxf(0.0, next.biomass_required - biomass)


func _on_traits_changed() -> void:
	var before := _shaped
	_reshape()
	# Eating something changes the larder without changing the body, and a stage
	# change means "resize yourself" to everything listening. Only say it when
	# the body really did move.
	if before == null or not is_equal_approx(before.body_height, _shaped.body_height) \
			or not is_equal_approx(before.move_speed, _shaped.move_speed) \
			or not is_equal_approx(before.silk_quality, _shaped.silk_quality) \
			or before.bite_power != _shaped.bite_power:
		stage_changed.emit(current_stage(), stage_index)


func _reshape() -> void:
	var base := base_stage()
	_shaped = base if traits == null else traits.shape(base)
