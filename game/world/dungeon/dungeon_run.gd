class_name DungeonRun
extends Node3D

## A run down the dungeon: the floor the spider is on, put down from a [FloorPlan]
## out of the rooms' scenes, and the next floor put down in its place when the spider
## drops down the pit.
##
## Each floor is laid out from its own seed — the run's, and how deep it is — so the
## same run is the same dungeon all the way down, and a new run is a new one. The
## spider comes into each floor through the shaft in its entrance's roof, and falling
## out of the world puts it back there.

## The floor has been put down: [param floor_number] counts from 1 at the top.
signal floor_built(floor_number: int)

## Which floor a run starts on, and the seed it is laid out from: nought for a new
## dungeon each time the scene opens.
@export var start_floor := 1
@export var run_seed := 0

## How deep the spider is now, counting from 1.
var floor_number := 1

## The floor's layout, and its rooms by the square each stands in.
var plan: FloorPlan = null
var rooms := {}

var _floor: Node3D = null
var _going_down := false


func _ready() -> void:
	floor_number = start_floor
	if run_seed == 0:
		run_seed = randi_range(1, 2147483646)
	# Once everything has set itself up — the spider has to be ready to be put down.
	build_floor.call_deferred()


## Lays this floor out and puts it down, with the spider at the way in.
func build_floor() -> void:
	_clear()
	plan = FloorPlan.make(floor_seed(floor_number))
	_floor = WorldKit.group(self, "Floor%d" % floor_number)
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
	var half := Vector2(FloorPlan.COLUMNS, FloorPlan.ROWS) * Rooms.CELL * 0.5
	Zone.make(_floor, "Floor %d" % floor_number, Vector3(-half.x, -30.0, -half.y),
		Vector3(half.x, 30.0, half.y), Vector2.ZERO)
	_put_down_the_spider()
	floor_built.emit(floor_number)


## The seed floor [param depth] of this run is laid out from.
func floor_seed(depth: int) -> int:
	return abs(hash(Vector2i(run_seed, depth))) + 1


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


## Takes the floor up, and the silk the spider left on it — webs and lines tied to
## walls that are no longer there.
func _clear() -> void:
	rooms.clear()
	if _floor != null and is_instance_valid(_floor):
		remove_child(_floor)
		_floor.free()
	_floor = null
	var spider := get_tree().get_first_node_in_group("spider") as SpiderPlayer
	if spider == null or spider.web_builder == null:
		return
	for web in spider.web_builder.webs():
		if is_instance_valid(web) and not web.is_queued_for_deletion():
			web.queue_free()
	var host := get_parent().get_node_or_null("Webs")
	if host != null:
		for silk in host.get_children():
			if not silk.is_queued_for_deletion():
				silk.queue_free()
