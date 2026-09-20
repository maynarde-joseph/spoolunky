class_name SpiderGrowth
extends Node

## Biomass in, size out.
##
## Holds the ladder of [GrowthStage] resources and decides when the spider has
## eaten enough to move up it. It does not resize anything itself — it just
## announces the new stage and lets the spider apply it.

signal stage_changed(stage: GrowthStage, index: int)
signal biomass_changed(biomass: float, progress: float)
signal fed(amount: float, source: String)

## Leave empty to use the default ladder from [WebLibrary].
@export var stages: Array[GrowthStage] = []

var biomass := 0.0
var stage_index := 0


func _ready() -> void:
	if stages.is_empty():
		stages = WebLibrary.default_stages()


## Announces the starting stage. Called by the spider once it is set up.
func apply_initial() -> void:
	stage_index = 0
	stage_changed.emit(current_stage(), stage_index)
	biomass_changed.emit(biomass, progress())


func current_stage() -> GrowthStage:
	if stages.is_empty():
		return GrowthStage.new()
	return stages[clampi(stage_index, 0, stages.size() - 1)]


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
		stage_changed.emit(current_stage(), stage_index)
	biomass_changed.emit(biomass, progress())
	return gained


## 0..1 toward the next size tier. Returns 1.0 when fully grown.
func progress() -> float:
	var next := next_stage()
	if next == null:
		return 1.0
	var floor_value := current_stage().biomass_required
	var span: float = maxf(next.biomass_required - floor_value, 0.001)
	return clampf((biomass - floor_value) / span, 0.0, 1.0)


## Biomass still needed for the next tier, or 0 when fully grown.
func biomass_to_next() -> float:
	var next := next_stage()
	if next == null:
		return 0.0
	return maxf(0.0, next.biomass_required - biomass)
