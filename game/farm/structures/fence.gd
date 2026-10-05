class_name Fence
extends FarmStructure

## A length of fence between two cells, or a gate in one: what pens are made of.
##
## A fence is a wall as far as an insect is concerned, and a climb as far as the
## spider is. A gate is the same until it is opened — F — and then it lets things
## through, which joins its pen to whatever is on the other side: usually the open
## farm, which is how a herd gets out. See [FarmGrid].

## How tall a fence is, and how thick its posts and rails are, in metres.
const HEIGHT := 1.1
const POST := 0.13
const RAIL := Vector2(0.1, 0.06)

## How much taller a gate's posts are than a fence's.
const GATE_POSTS := 1.4

var is_gate := false

## Whether the gate stands open. A fence never does.
var open := false

var _door: Node3D
var _door_shape: CollisionShape3D


func draw(on: Node3D, solid: bool) -> void:
	var length := _cell()
	var half := length * 0.5
	if not is_gate:
		for side: float in [-1.0, 1.0]:
			WorldKit.box(on, "Post%s" % ("A" if side < 0.0 else "B"), Vector3(POST, HEIGHT, POST),
				WorldKit.at(Vector3(side * (half - POST * 0.5), HEIGHT * 0.5, 0.0)), "wood_dark",
				false)
		for i in 2:
			var up := HEIGHT * (0.4 + 0.42 * float(i))
			WorldKit.box(on, "Rail%d" % (i + 1), Vector3(length - POST, RAIL.x, RAIL.y),
				WorldKit.at(Vector3(0.0, up, 0.0)), "wood_light", false)
		if solid:
			_wall(on, Vector3(length, HEIGHT, POST + 0.02), Vector3(0.0, HEIGHT * 0.5, 0.0))
		return
	# Posts, a head high, capped; and the door between them on a hinge at the first.
	for side: float in [-1.0, 1.0]:
		var tag := "A" if side < 0.0 else "B"
		var at := side * (half - POST * 0.5)
		WorldKit.box(on, "Post" + tag, Vector3(POST * 1.3, GATE_POSTS, POST * 1.3),
			WorldKit.at(Vector3(at, GATE_POSTS * 0.5, 0.0)), "wood_dark", false)
		WorldKit.box(on, "Cap" + tag, Vector3(POST * 1.7, 0.06, POST * 1.7),
			WorldKit.at(Vector3(at, GATE_POSTS + 0.03, 0.0)), "gate_red", false)
		if solid:
			_wall(on, Vector3(POST * 1.3, GATE_POSTS, POST * 1.3), Vector3(at, GATE_POSTS * 0.5, 0.0))
	var span := length - POST * 2.6
	_door = Node3D.new()
	_door.name = "Door"
	_door.position = Vector3(-half + POST * 1.3, 0.0, 0.0)
	on.add_child(_door)
	for i in 3:
		var up := HEIGHT * (0.2 + 0.32 * float(i))
		WorldKit.box(_door, "Board%d" % (i + 1), Vector3(span, RAIL.x * 1.2, RAIL.y),
			WorldKit.at(Vector3(span * 0.5, up, 0.0)), "gate_red", false)
	for end: float in [0.06, span - 0.06]:
		WorldKit.box(_door, "Stile%d" % (1 if end < span * 0.5 else 2), Vector3(0.09, HEIGHT * 0.78, RAIL.y),
			WorldKit.at(Vector3(end, HEIGHT * 0.53, 0.0)), "gate_red", false)
	var brace := Vector3(span - 0.12, HEIGHT * 0.64, 0.0)
	WorldKit.rod(_door, "Brace", Vector3(0.06, HEIGHT * 0.2, 0.0),
		Vector3(0.06, HEIGHT * 0.2, 0.0) + brace, 0.03, "wood_light", false)
	if solid:
		_door_shape = _wall(on, Vector3(span, HEIGHT, POST), Vector3(0.0, HEIGHT * 0.5, 0.0))
	_swing()


## A box collider of [param size] centred on [param middle], on the body itself.
func _wall(on: Node3D, size: Vector3, middle: Vector3) -> CollisionShape3D:
	var box := BoxShape3D.new()
	box.size = size
	var shape := CollisionShape3D.new()
	shape.name = "Wall%d" % on.get_child_count()
	shape.shape = box
	shape.position = middle
	on.add_child(shape)
	return shape


func lets_through() -> bool:
	return is_gate and open


## Opens or shuts the gate, and tells the farm, whose pens it has just changed.
func set_open(value: bool) -> void:
	if not is_gate or open == value:
		return
	open = value
	_swing()
	if farm != null:
		farm.gate_moved()


func _swing() -> void:
	if _door != null:
		_door.rotation.y = -PI * 0.5 if open else 0.0
	if _door_shape != null:
		_door_shape.disabled = open


func describe() -> String:
	if not is_gate:
		return "Fence"
	return "Gate · %s" % ("open" if open else "shut")


func interact_hint(_spider: SpiderPlayer) -> String:
	if not is_gate:
		return ""
	return "F — shut the gate" if open else "F — open the gate"


func interact(_spider: SpiderPlayer) -> bool:
	if not is_gate:
		return false
	set_open(not open)
	if farm != null:
		farm.notice.emit("Gate open — anything in there can wander out" if open else "Gate shut")
	return true
