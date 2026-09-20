@tool
class_name WebDesign
extends Resource

## A rig the player built and kept: several webs, the wiring between them, and
## the shape they sit in relative to each other.
##
## What is saved is the *arrangement*, not the place. Re-placing a design spins
## the same webs in the same relative positions wherever the player is looking,
## turned to face the way they are facing — so a trap that worked over one drain
## can be put over the next one without rebuilding it thread by thread.
##
## Pieces are stored as flat parallel arrays rather than nested resources, which
## keeps a saved design a single readable .tres file.

@export var id := ""
@export var display_name := "Design"

## One pattern id per piece, in order.
@export var pattern_ids: PackedStringArray = PackedStringArray()

## How many anchors belong to each piece, in the same order.
@export var anchor_counts: PackedInt32Array = PackedInt32Array()

## Every piece's anchors, concatenated, in the rig's own space.
@export var anchors: PackedVector3Array = PackedVector3Array()

## Each piece's dial settings, so a design remembers how it was spun and not
## just what it was made of.
@export var tuning_tension: PackedInt32Array = PackedInt32Array()
@export var tuning_weight: PackedInt32Array = PackedInt32Array()
@export var tuning_mesh: PackedInt32Array = PackedInt32Array()

## How each piece was woven, so a kept rig comes back looking the same.
@export var weaves: PackedInt32Array = PackedInt32Array()

## Signal lines, as piece indices: link_from[i] sets off link_to[i].
@export var link_from: PackedInt32Array = PackedInt32Array()
@export var link_to: PackedInt32Array = PackedInt32Array()

## What it cost to build the first time, for the HUD. The real cost is measured
## again when it is placed, because bigger spiders spin heavier silk.
@export var recorded_silk := 0.0

## Growth stage it was designed at, so the player knows why it looks expensive.
@export var made_at_stage := 0

## Silk quality it was recorded at, so the cost can be scaled to the spider
## placing it now — a bigger spider spins the same design in heavier silk.
@export var made_at_quality := 1.0


## What this design would roughly cost a spider spinning at [param quality].
func cost_at(quality: float) -> float:
	return recorded_silk * (quality / maxf(made_at_quality, 0.001))


func piece_count() -> int:
	return pattern_ids.size()


func link_count() -> int:
	return link_from.size()


## Dials recorded for one piece, or standard ones if the design predates them.
func tuning_for(piece: int) -> WebTuning:
	var tuning := WebTuning.new()
	if piece < 0 or piece >= tuning_tension.size():
		return tuning
	tuning.tension = tuning_tension[piece]
	tuning.weight = tuning_weight[piece]
	tuning.mesh = tuning_mesh[piece]
	return tuning


## How one piece was woven, defaulting to stretched for older designs.
func weave_for(piece: int) -> WebGeometry.Weave:
	if piece < 0 or piece >= weaves.size():
		return WebGeometry.Weave.STRETCHED
	return weaves[piece] as WebGeometry.Weave


## Anchors for one piece, still in the rig's own space.
func anchors_for(piece: int) -> PackedVector3Array:
	var slice := PackedVector3Array()
	if piece < 0 or piece >= anchor_counts.size():
		return slice
	var start := 0
	for i in piece:
		start += anchor_counts[i]
	for i in anchor_counts[piece]:
		slice.append(anchors[start + i])
	return slice


## How far the rig reaches along a direction, for sitting it proud of a wall
## instead of halfway inside one.
func extent_along(direction: Vector3) -> float:
	if anchors.is_empty():
		return 0.0
	var lowest := INF
	var highest := -INF
	for point in anchors:
		var along := point.dot(direction)
		lowest = minf(lowest, along)
		highest = maxf(highest, along)
	return maxf(highest - lowest, 0.0) * 0.5


## One line for the build wheel.
func summary() -> String:
	var pieces := piece_count()
	var text := "%s — %d web%s" % [display_name, pieces, "" if pieces == 1 else "s"]
	if link_count() > 0:
		text += ", %d wired" % link_count()
	return text
