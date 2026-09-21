class_name PreySpawner
extends Node3D

## Keeps a patch of the world stocked with things to catch.
##
## A placeholder for real prey lanes — good enough to test webs against, and
## the place to hang proper spawn rules later.

## What to spawn.
@export var prey_scene: PackedScene

## How many to keep alive at once.
@export var population := 10

## Box around this node that prey spawns inside.
@export var spawn_extents := Vector3(16, 3, 16)

## Seconds before a dead one is replaced.
@export var respawn_delay := 5.0

## Drop spawns onto whatever is below, then lift them by this much.
@export var snap_to_ground := true
@export var hover_height := Vector2(0.4, 2.2)

var _alive: Array[Node3D] = []
var _pending := 0.0


func _ready() -> void:
	if prey_scene == null:
		push_warning("PreySpawner has no prey scene assigned")
		return
	for i in population:
		_spawn()


func _process(delta: float) -> void:
	if prey_scene == null:
		return
	# Not filter() with a typed lambda: Array.filter returns an untyped Array,
	# which will not assign back to Array[Node3D], and a freed instance cannot
	# be passed as a Node3D either. Both of those throw once per frame, for
	# every frame after anything is freed.
	var live: Array[Node3D] = []
	for node in _alive:
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			live.append(node)
	_alive = live
	if _alive.size() >= population:
		return
	_pending -= delta
	if _pending <= 0.0:
		_pending = respawn_delay
		_spawn()


## How many of our prey are currently stuck in a web.
func caught_count() -> int:
	var total := 0
	for node in _alive:
		var prey := node as Prey
		if prey != null and prey.is_stuck():
			total += 1
	return total


func alive_count() -> int:
	return _alive.size()


func _spawn() -> void:
	var prey := prey_scene.instantiate() as Node3D
	if prey == null:
		return
	add_child(prey)
	prey.global_position = _random_point()
	_alive.append(prey)


func _random_point() -> Vector3:
	var local := Vector3(
		randf_range(-spawn_extents.x, spawn_extents.x) * 0.5,
		randf_range(-spawn_extents.y, spawn_extents.y) * 0.5,
		randf_range(-spawn_extents.z, spawn_extents.z) * 0.5)
	var point := global_position + local
	if not snap_to_ground:
		return point
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * spawn_extents.y,
		point - Vector3.UP * spawn_extents.y * 2.0, GameLayers.WORLD)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return point
	return hit["position"] + Vector3.UP * randf_range(hover_height.x, hover_height.y)
