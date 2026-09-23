class_name PreySpawner
extends Node3D

## Keeps a patch of the world stocked with things to catch.
##
## The mix is what makes a patch worth visiting: a stock of midges is a web you
## leave out, a stock with wasps in it is somewhere you go prepared. Leave
## [member stock] empty and it takes every species in the game, weighted by how
## often each says it should turn up.
##
## A placeholder for real prey lanes — good enough to test webs against, and
## the place to hang proper spawn rules later.

## The one scene every creature is built from. Left unset, prey finds it.
@export var prey_scene: PackedScene

## Which species turn up here. Empty means all of them.
@export var stock: Array[PreySpecies] = []

## How many to keep alive at once.
@export var population := 10

## Box around this node that prey spawns inside.
@export var spawn_extents := Vector3(16, 3, 16)

## Seconds before a dead one is replaced.
@export var respawn_delay := 5.0

## Drop spawns onto whatever is below, then lift them by this much. Fliers get
## their own species' height band instead; this is the fallback.
@export var snap_to_ground := true
@export var hover_height := Vector2(0.4, 2.2)

var _alive: Array[Node3D] = []
var _pending := 0.0
var _weight_total := 0.0


func _ready() -> void:
	if stock.is_empty():
		stock = PreyLibrary.load_species()
	_weight_total = 0.0
	for kind in stock:
		_weight_total += maxf(kind.spawn_weight, 0.0)
	if stock.is_empty() or _weight_total <= 0.0:
		push_warning("PreySpawner has no species to stock")
		return
	for i in population:
		_spawn()


func _process(delta: float) -> void:
	if _weight_total <= 0.0:
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


## How many of each species are alive here, by display name. The catalogue and
## the HUD both want this eventually; for now it is how a test asks whether the
## mix is a mix.
func alive_by_species() -> Dictionary:
	var counts := {}
	for node in _alive:
		var prey := node as Prey
		if prey == null or not is_instance_valid(prey):
			continue
		counts[prey.species] = int(counts.get(prey.species, 0)) + 1
	return counts


func _spawn() -> void:
	var kind := _pick_species()
	if kind == null:
		return
	var prey: Prey = null
	if prey_scene != null:
		prey = prey_scene.instantiate() as Prey
		if prey != null:
			prey.apply_species(kind)
	else:
		prey = Prey.of(kind)
	if prey == null:
		return
	add_child(prey)
	prey.global_position = _random_point(kind)
	_alive.append(prey)


## Weighted draw, so a patch is mostly the common things with the good ones
## scattered through it rather than an even split.
func _pick_species() -> PreySpecies:
	if _weight_total <= 0.0:
		return null
	var roll := randf() * _weight_total
	for kind in stock:
		roll -= maxf(kind.spawn_weight, 0.0)
		if roll <= 0.0:
			return kind
	return stock[stock.size() - 1]


func _random_point(kind: PreySpecies) -> Vector3:
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
	# A creature starts where it lives. Beetles walk, so they start on the
	# floor; moths live near the ceiling, so that is where a web has to be to
	# ever see one. Putting them all in the same band would throw away the one
	# thing that makes placement a decision.
	var lift := randf_range(hover_height.x, hover_height.y)
	if kind != null:
		lift = randf_range(kind.wander_height.x, kind.wander_height.y) if kind.flying else 0.1
	return hit["position"] + Vector3.UP * lift
