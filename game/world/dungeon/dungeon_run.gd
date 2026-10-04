class_name DungeonRun
extends Node3D

## A run down the dungeon: the floor the spider is on, put down from a [FloorPlan]
## out of the rooms' scenes, and the next floor put down in its place when the spider
## drops down the pit.
##
## Each floor is laid out from its own seed — the run's, and how deep it is — so the
## same run is the same dungeon all the way down, and a new run is a new one. Wherever
## the plan puts a floor's way in, the floor is put down with its entrance under the
## run itself: the shaft in the entrance's roof always comes up in the same place, so
## whatever leads down to it from above — the stair from the colosseum — leads down
## to every floor. The spider comes into each floor through that shaft.

## The floor has been put down: [param floor_number] counts from 1 at the top.
signal floor_built(floor_number: int)

## Which floor a run starts on, and the seed it is laid out from: nought for a new
## dungeon each time the scene opens.
@export var start_floor := 1
@export var run_seed := 0

## Whether the spider walks into the first floor, down whatever leads to its shaft
## from above, rather than being put down in its entrance when the scene opens. Every
## floor after the first, it is put down in.
@export var walk_in := false

## How far a floor's zone reaches under its floor and over it: from below the deepest
## shaft to just short of the top of the entrance's, where the way down to it begins.
const BELOW := 30.0
const ABOVE := 18.0

## How deep the spider is now, counting from 1.
var floor_number := 1

## The floor's layout, and its rooms by the square each stands in.
var plan: FloorPlan = null
var rooms := {}

var _floor: Node3D = null
var _zone: Zone = null
var _going_down := false


func _ready() -> void:
	floor_number = start_floor
	if run_seed == 0:
		run_seed = randi_range(1, 2147483646)
	# Once everything has set itself up — the spider has to be ready to be put down.
	build_floor.call_deferred(not walk_in)


## Lays this floor out and puts it down, its entrance under the run — and the spider
## in at the way in, unless [param put_down] says it is to walk in.
func build_floor(put_down := true) -> void:
	_clear()
	plan = FloorPlan.make(floor_seed(floor_number))
	_floor = WorldKit.group(self, "Floor%d" % floor_number)
	_floor.position = -FloorPlan.centre(plan.start)
	for cell: Vector2i in plan.cells:
		var info: Dictionary = plan.cells[cell]
		var scene := load(Rooms.scene_of(info["room"])) as PackedScene
		if scene == null:
			push_warning("no scene for room %s" % info["room"])
			continue
		var room := scene.instantiate() as DungeonRoom
		room.name = "%s%d%d" % [str(info["room"]).capitalize(), cell.x, cell.y]
		room.transform = Transform3D(Rooms.turn_basis(info["turn"]), FloorPlan.centre(cell))
		_floor.add_child(room)
		for side in info["open"]:
			room.open(posmod(int(side) - int(info["turn"]), 4))
		rooms[cell] = room
	var way_down := way_down()
	if way_down != null:
		way_down.body_entered.connect(_on_way_down)
	# A zone's bounds are the world's, not the floor's: wherever the run stands.
	var half := Vector2(FloorPlan.COLUMNS, FloorPlan.ROWS) * Rooms.CELL * 0.5
	var middle := _floor.global_position
	_zone = Zone.make(_floor, "Floor %d" % floor_number,
		middle + Vector3(-half.x, -BELOW, -half.y), middle + Vector3(half.x, ABOVE, half.y),
		Vector2.ZERO)
	if put_down:
		_put_down_the_spider()
	floor_built.emit(floor_number)


## The seed floor [param depth] of this run is laid out from.
func floor_seed(depth: int) -> int:
	return abs(hash(Vector2i(run_seed, depth))) + 1


## Where the middle of square [param cell] of this floor is, in the world.
func centre_of(cell: Vector2i) -> Vector3:
	var start := plan.start if plan != null else Vector2i.ZERO
	return global_transform * (FloorPlan.centre(cell) - FloorPlan.centre(start))


## The room the spider comes into this floor by.
func entrance() -> DungeonRoom:
	return rooms.get(plan.start) as DungeonRoom if plan != null else null


## The drop down to the next floor, in the room with the way down.
func way_down() -> Area3D:
	var pit := rooms.get(plan.finish) as DungeonRoom if plan != null else null
	return pit.way_down() if pit != null else null


## Down to the next floor: this one taken up, the next laid out and put down in its
## place, and the spider in at its way in.
func descend() -> void:
	if _going_down:
		return
	_going_down = true
	floor_number += 1
	build_floor()
	_going_down = false


func _on_way_down(body: Node3D) -> void:
	if body is SpiderPlayer:
		descend.call_deferred()


## The spider at the way in, under the shaft, and that the place it comes back to.
func _put_down_the_spider() -> void:
	var spider := get_tree().get_first_node_in_group("spider") as SpiderPlayer
	var way_in := entrance()
	if spider == null or way_in == null or way_in.entry() == null:
		return
	spider.wake_at(way_in.entry().global_transform)


## Takes the floor up, and the silk the spider left in it — webs and lines tied to
## walls that are no longer there. Silk anywhere else — up the stair, in the place
## above — stays where it was spun.
func _clear() -> void:
	rooms.clear()
	var bounds := _zone.bounds if _zone != null and is_instance_valid(_zone) else AABB()
	_zone = null
	if _floor != null and is_instance_valid(_floor):
		remove_child(_floor)
		_floor.free()
	_floor = null
	if not bounds.has_volume():
		return
	var spider := get_tree().get_first_node_in_group("spider") as SpiderPlayer
	if spider == null:
		return
	var silk: Array[Node] = []
	if spider.web_builder != null:
		silk.append_array(spider.web_builder.webs())
	var host := spider.get_parent().get_node_or_null("Webs") if spider.get_parent() != null else null
	if host != null:
		silk.append_array(host.get_children())
	for piece in silk:
		if is_instance_valid(piece) and not piece.is_queued_for_deletion() and _tied_into(piece, bounds):
			piece.queue_free()


## Whether [param silk] is tied to anything inside [param bounds]: a web or a line by
## any of the points it was spun across, anything else by where it is.
static func _tied_into(silk: Node, bounds: AABB) -> bool:
	var spun := silk as WebStructure
	if spun != null and not spun.anchors.is_empty():
		for point in spun.anchors:
			if bounds.has_point(point):
				return true
		return false
	var thing := silk as Node3D
	return thing != null and bounds.has_point(thing.global_position)
