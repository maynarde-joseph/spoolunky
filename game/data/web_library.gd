class_name WebLibrary
extends RefCounted

## Loads the web patterns and the growth ladder.
##
## Patterns are plain resources in [code]res://game/data/patterns/[/code], so
## adding a new kind of web is a matter of duplicating a .tres and editing the
## numbers — no code change needed. Anything found in that folder is merged in
## with the built-in set and sorted into the build wheel.

const PATTERN_DIR := "res://game/data/patterns"
const DEVICE_DIR := "res://game/data/devices"

const BUILTIN_PATTERNS: Array[String] = [
	"res://game/data/patterns/frame_line.tres",
	"res://game/data/patterns/trip_line.tres",
	"res://game/data/patterns/sheet_web.tres",
	"res://game/data/patterns/orb_web.tres",
	"res://game/data/patterns/pressure_snare.tres",
	"res://game/data/patterns/funnel_lure.tres",
	"res://game/data/patterns/silk_bridge.tres",
]


## Every pattern in the game, ordered the way the build wheel shows them.
static func load_patterns() -> Array[WebPattern]:
	var patterns: Array[WebPattern] = []
	var seen := {}
	for path in BUILTIN_PATTERNS:
		var pattern := _load_pattern(path)
		if pattern != null:
			patterns.append(pattern)
			seen[path] = true

	# Anything else the player dropped in the folder.
	var dir := DirAccess.open(PATTERN_DIR)
	if dir != null:
		for file in dir.get_files():
			var file_name := file.trim_suffix(".remap")
			if not file_name.ends_with(".tres"):
				continue
			var path := PATTERN_DIR.path_join(file_name)
			if seen.has(path):
				continue
			var pattern := _load_pattern(path)
			if pattern != null:
				patterns.append(pattern)

	patterns.sort_custom(_compare_patterns)
	return patterns


## Every kind of device the spider can carry, in a stable order.
static func load_devices() -> Array[DeviceKind]:
	var kinds: Array[DeviceKind] = []
	var dir := DirAccess.open(DEVICE_DIR)
	if dir == null:
		return kinds
	var files := dir.get_files()
	files.sort()
	for file in files:
		var file_name := file.trim_suffix(".remap")
		if not file_name.ends_with(".tres"):
			continue
		var kind := ResourceLoader.load(DEVICE_DIR.path_join(file_name)) as DeviceKind
		if kind != null:
			kinds.append(kind)
	return kinds


## The size tiers, smallest first. Stage 0 is where a new spider starts.
##
## The jump numbers are upward velocity, so the height they buy is v² / 2g —
## a spiderling clears about a metre and a half, which is six of its own body
## lengths. Spiders jump like that; the old numbers were a person's jump scaled
## down, and a spider that hops is a spider that walks everywhere.
static func default_stages() -> Array[GrowthStage]:
	var stages: Array[GrowthStage] = []
	stages.append(_stage("Spiderling", 0.0, 0.25, 2.4, 5.6, 3.2, 2.4, 1.0, 1, 0.6))
	stages.append(_stage("House Spider", 24.0, 0.4, 3.0, 6.7, 4.8, 3.6, 1.35, 2, 0.9))
	stages.append(_stage("Huntsman", 70.0, 0.7, 3.8, 7.8, 7.0, 5.2, 1.8, 3, 1.3))
	stages.append(_stage("Gutter Spider", 160.0, 1.2, 4.8, 9.2, 9.5, 7.2, 2.4, 4, 1.9))
	stages.append(_stage("Sewer Widow", 340.0, 2.0, 6.0, 10.9, 13.0, 10.0, 3.2, 5, 2.7))
	stages.append(_stage("Park Recluse", 700.0, 3.4, 7.4, 12.9, 18.0, 14.0, 4.2, 6, 3.8))
	stages.append(_stage("City Weaver", 1400.0, 5.6, 9.2, 14.8, 26.0, 20.0, 5.5, 7, 5.2))
	stages.append(_stage("The Architect", 2800.0, 9.0, 11.0, 16.8, 40.0, 30.0, 7.0, 9, 7.5))
	return stages


static func _load_pattern(path: String) -> WebPattern:
	if not ResourceLoader.exists(path):
		push_warning("Web pattern missing: %s" % path)
		return null
	var res := ResourceLoader.load(path)
	var pattern := res as WebPattern
	if pattern == null:
		push_warning("Not a WebPattern: %s" % path)
	return pattern


static func _compare_patterns(a: WebPattern, b: WebPattern) -> bool:
	if a.unlock_stage != b.unlock_stage:
		return a.unlock_stage < b.unlock_stage
	if a.sort_order != b.sort_order:
		return a.sort_order < b.sort_order
	return a.id < b.id


static func _stage(display_name: String, biomass: float, height: float, speed: float,
		jump: float, anchor_range: float, strand: float, quality: float,
		bite: int, reach: float) -> GrowthStage:
	var stage := GrowthStage.new()
	stage.display_name = display_name
	stage.biomass_required = biomass
	stage.body_height = height
	stage.move_speed = speed
	stage.jump_velocity = jump
	stage.anchor_range = anchor_range
	stage.max_strand_length = strand
	stage.silk_quality = quality
	stage.bite_power = bite
	stage.reach = reach
	return stage
