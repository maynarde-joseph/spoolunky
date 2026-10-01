class_name Ecosystem
extends Node

## The living part of a level: what time of day it is, and what is near what.
##
## Creatures only have needs where there is one of these. In a level without it —
## the sandbox, the gym, the test arenas — they wander as they always have,
## hungry for nothing and afraid of nothing, which is what every check written
## before there was an ecosystem was written against. Put one in a level and the
## same creatures start to live there: they get hungry, they go and find what they
## eat, they run from what eats them, and they go home when it is not their time
## of day (see [CreatureMind]).
##
## Two jobs live here because every creature needs both and none of them should
## do either for itself:
##
## * **The clock.** One day, going round, and whether it is day or night now.
##   Night is when the moths and bats are out and the hares are underground.
## * **Who is near whom.** Every creature looks for food and danger several times
##   a second. Looking through every other creature each time is a cost that grows
##   with the square of how many there are, and a hunting ground has a lot of them.
##   So they are sorted into a grid a few times a second, and a look only goes
##   through the squares it can reach.

const GROUP := "ecosystem"

## How wide a square of the grid is, in metres. About as far as a small creature
## looks, so most looks touch a handful of squares.
const CELL := 24.0

## How often the grid is sorted again, in seconds. Stale by up to this much, which
## is less than anything moves far enough in to matter.
const SORT_EVERY := 0.25

## How often the carcasses are looked over for flies to come off them, in seconds;
## and how many flies one carcass draws at a time.
const FLIES_EVERY := 3.0
const FLIES_PER_CARCASS := 3

## How long one whole day is, in seconds: dawn to dawn.
@export var day_length := 720.0

## Where the day is when the level opens: 0 is midnight, a quarter dawn, a half
## noon, three quarters dusk.
@export_range(0.0, 1.0) var start_time := 0.32

## Whether the day goes round. A check about something else stops it.
@export var running := true

## How quickly everything gets hungry, against each species' own rate. One dial
## for the pace of the whole world.
@export_range(0.0, 10.0, 0.05) var tempo := 1.0

## Whether flies come off carcasses — see [method _breed_flies] — and the most
## there can be in the whole world at once.
@export var breeds_flies := true
@export var max_flies := 40

## What comes off a carcass. The game's fly, unless a check says otherwise.
var fly_kind: PreySpecies

## Where the day has got to, 0 to 1. See [member start_time].
var time_of_day := 0.32

var _cells := {}
var _sort_in := 0.0
var _forage: Array[Forage] = []
var _flies_in := FLIES_EVERY


## The ecosystem a node is living in, or null if it is not living in one.
static func of(node: Node) -> Ecosystem:
	if node == null or not node.is_inside_tree():
		return null
	return node.get_tree().get_first_node_in_group(GROUP) as Ecosystem


func _ready() -> void:
	add_to_group(GROUP)
	time_of_day = start_time
	if fly_kind == null:
		fly_kind = PreyLibrary.find("fly")


func _process(delta: float) -> void:
	if running and day_length > 0.0:
		time_of_day = fposmod(time_of_day + delta / day_length, 1.0)


func _physics_process(delta: float) -> void:
	_sort_in -= delta
	if _sort_in <= 0.0:
		_sort_in = SORT_EVERY
		_sort()
	_flies_in -= delta
	if _flies_in <= 0.0:
		_flies_in = FLIES_EVERY
		if breeds_flies:
			_breed_flies()


# --- the clock ----------------------------------------------------------

## Whether it is day: from a little before sunrise to a little after sunset.
func is_day() -> bool:
	return time_of_day > 0.23 and time_of_day < 0.77


## How light it is, 0 at midnight to 1 at noon, easing through dawn and dusk.
func daylight() -> float:
	return clampf(0.5 - 0.5 * cos(time_of_day * TAU) * 1.6, 0.0, 1.0)


## Whether something out at [param activity] is out now.
func awake(activity: PreySpecies.Activity) -> bool:
	match activity:
		PreySpecies.Activity.DAY:
			return is_day()
		PreySpecies.Activity.NIGHT:
			return not is_day()
	return true


## What the time is, for the HUD.
func clock_text() -> String:
	var minutes := roundi(time_of_day * 24.0 * 60.0) % (24 * 60)
	return "%02d:%02d" % [minutes / 60, minutes % 60]


# --- who is near whom ----------------------------------------------------

## Every creature — alive or a carcass — within [param radius] of [param point],
## as of the last sort.
func creatures_near(point: Vector3, radius: float) -> Array[Prey]:
	var found: Array[Prey] = []
	var lo := _cell_of(point - Vector3(radius, 0.0, radius))
	var hi := _cell_of(point + Vector3(radius, 0.0, radius))
	var reach := radius * radius
	for x in range(lo.x, hi.x + 1):
		for z in range(lo.y, hi.y + 1):
			var square: Array = _cells.get(Vector2i(x, z), [])
			for node in square:
				var creature := node as Prey
				if creature == null or not is_instance_valid(creature) or creature.eaten:
					continue
				if creature.global_position.distance_squared_to(point) <= reach:
					found.append(creature)
	return found


## The nearest patch of anything in [param kinds] with food on it, within
## [param radius] of [param point], or null.
func forage_near(point: Vector3, radius: float, kinds: PackedStringArray) -> Forage:
	var best: Forage = null
	var best_gap := radius * radius
	for patch in _forage:
		if patch == null or not is_instance_valid(patch) or not kinds.has(patch.kind):
			continue
		if patch.amount < patch.capacity * 0.1:
			continue
		var gap := patch.global_position.distance_squared_to(point)
		if gap < best_gap:
			best_gap = gap
			best = patch
	return best


## Every patch of forage in the level.
func all_forage() -> Array[Forage]:
	return _forage.duplicate()


## Called by a patch as it arrives, so the ecosystem knows it is there without
## having to look for it.
func add_forage(patch: Forage) -> void:
	if patch != null and not _forage.has(patch):
		_forage.append(patch)


func remove_forage(patch: Forage) -> void:
	_forage.erase(patch)


## Every carcass with something left on it.
func carcasses() -> Array[Prey]:
	var found: Array[Prey] = []
	for node in get_tree().get_nodes_in_group("prey"):
		var creature := node as Prey
		if creature != null and is_instance_valid(creature) and creature.is_dead() \
				and not creature.eaten and creature.biomass > 1.0:
			found.append(creature)
	return found


## Flies come off carcasses. A kill left lying draws a few, and they hang about it
## eating — which is what makes a carcass somewhere to put a web, and somewhere a
## bird or a frog comes to. Capped per carcass and across the world, so a hunting
## ground after a good night is not a cloud.
func _breed_flies() -> void:
	if fly_kind == null:
		return
	var dead := carcasses()
	if dead.is_empty():
		return
	var flies := 0
	for node in get_tree().get_nodes_in_group("prey"):
		var creature := node as Prey
		if creature != null and creature.kind != null and creature.kind.id == fly_kind.id \
				and not creature.is_dead() and not creature.eaten:
			flies += 1
	for corpse in dead:
		if flies >= max_flies:
			return
		var around := corpse.hit_radius() * 4.0 + 3.0
		var near := 0
		for other in creatures_near(corpse.global_position, around):
			if other.kind != null and other.kind.id == fly_kind.id and not other.is_dead():
				near += 1
		if near >= FLIES_PER_CARCASS or randf() > 0.6:
			continue
		var fly := Prey.of(fly_kind)
		if fly == null:
			return
		corpse.get_parent().add_child(fly)
		fly.global_position = corpse.global_position + Vector3(randf_range(-0.3, 0.3),
			corpse.hit_radius() + 0.4, randf_range(-0.3, 0.3))
		flies += 1


## Sorts every creature into the grid.
func _sort() -> void:
	_cells.clear()
	for node in get_tree().get_nodes_in_group("prey"):
		var creature := node as Prey
		if creature == null or not is_instance_valid(creature) or creature.eaten:
			continue
		var key := _cell_of(creature.global_position)
		if not _cells.has(key):
			_cells[key] = []
		(_cells[key] as Array).append(creature)


## Sorts at once rather than on the next tick, for a check that has just put
## creatures down and wants them found.
func sort_now() -> void:
	_sort()
	_sort_in = SORT_EVERY


static func _cell_of(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x / CELL), floori(point.z / CELL))
