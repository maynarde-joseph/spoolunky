class_name Zone
extends Node3D

## One place in the world, and the volume it occupies.
##
## A zone owns its geometry and its light. What it does *not* own yet is what
## it does to silk — the wind, the damp, the flood, the cleaning. Those hang
## here when they arrive, which is why a zone is a node with bounds rather
## than a folder of boxes.

## Shown wherever the player is told where they are.
@export var display_name := "Somewhere"

## Which size tier this place is built around, for sanity-checking the scale
## rather than for gating anything. Gating is the thresholds' job.
@export var built_for := Vector2(0.25, 0.4)

## The volume this zone claims, in world space.
##
## The **interior** — the space you stand in — not the shell around it. Shells
## are shared: the attic's floor is also the roof of the crawlspace below it,
## and if both zones claimed their walls then the slab between them would
## belong to two places at once and "where am I" would be a coin toss. Zones
## touch, and never overlap.
var bounds := AABB()


static func make(parent: Node3D, zone_name: String, lo: Vector3, hi: Vector3,
		built_for_range: Vector2) -> Zone:
	var zone := Zone.new()
	zone.name = zone_name.replace(" ", "").replace("&", "And")
	zone.display_name = zone_name
	zone.built_for = built_for_range
	zone.bounds = AABB(lo, hi - lo).abs()
	parent.add_child(zone)
	zone.add_to_group("zones")
	return zone


func _ready() -> void:
	add_to_group("zones")


## Whichever zone a point falls in, or null for the space between them.
static func at(tree: SceneTree, point: Vector3) -> Zone:
	for node in tree.get_nodes_in_group("zones"):
		var zone := node as Zone
		if zone != null and zone.bounds.has_point(point):
			return zone
	return null


func contains(point: Vector3) -> bool:
	return bounds.has_point(point)


## How big the space is against the body it was built for — a rough check that
## a room is a room and not a stadium.
func body_lengths_across() -> float:
	var span: float = maxf(bounds.size.x, bounds.size.z)
	return span / maxf(built_for.x, 0.001)
