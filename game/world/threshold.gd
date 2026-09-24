class_name Threshold
extends Node3D

## The way out of a zone: a thing that gives when there is enough of you.
##
## Not a locked door and not a message. It is a plug in a hole — a vent flap on
## a tired spring, a cap of matted dust, a grate sprung for something the size
## of a rat — and it comes away when the spider is big enough to shift it.
##
## The feedback is the object itself. Stand on it too small and it dips a
## little and settles back, which says three things at once with no words: this
## is a way through, it is yours to open, and you are not enough yet.
##
## It compares body height rather than a weight, because a weight would be
## derived from body height and nothing else — the same comparison in different
## units, plus a second number to keep in sync. Most gates in the world should
## not even be this: a gap you fit through or you do not is the collider's
## business, and needs no script at all.
##
## Size is one key and not the only one. A gate can also name a trait that
## opens it — a lean body that folds through the slats, a spit that dissolves
## matted web — so a spider that went up the tree some way other than Bulk is
## not stuck behind a door it can never be big enough for. Both keys open the
## same gate, and the gate never says which one you are missing: it dips and
## settles back, and the answer is what you try next.

signal opened()

## Body height that shifts it. The tier table in the design doc is the source:
## 0.4 is a House Spider, 0.7 a Huntsman, 1.2 a Gutter Spider.
@export var opens_at := 0.4

## A trait id that also opens it, whatever size you are. Empty for a gate that
## only size can shift.
@export var opens_for := ""

## How far it sags under something too small, as a fraction of its thickness.
@export var nudge := 0.35

@export var nudge_speed := 6.0

var open := false

var _plug: StaticBody3D
var _sensor: Area3D
var _rest := Vector3.ZERO
var _thickness := 0.2
var _leaned_on := false


## Builds one filling the hole between [param lo] and [param hi].
static func make(parent: Node3D, lo: Vector3, hi: Vector3, size_to_open: float,
		gate_name: String, trait_key := "") -> Threshold:
	var gate := Threshold.new()
	gate.name = gate_name
	gate.opens_at = size_to_open
	gate.opens_for = trait_key
	parent.add_child(gate)
	gate._build(lo, hi)
	return gate


func _build(lo: Vector3, hi: Vector3) -> void:
	_plug = Greybox.span(self, lo, hi, "Plug")
	if _plug == null:
		return
	_rest = _plug.global_position
	_thickness = minf(minf(absf(hi.x - lo.x), absf(hi.y - lo.y)), absf(hi.z - lo.z))

	# A little taller than the plug, so standing on it counts as leaning on it.
	var sensor_shape := BoxShape3D.new()
	sensor_shape.size = (hi - lo).abs() + Vector3(0.0, _thickness * 4.0, 0.0)
	var collider := CollisionShape3D.new()
	collider.shape = sensor_shape
	_sensor = Area3D.new()
	_sensor.name = "Sensor"
	_sensor.collision_layer = 0
	_sensor.collision_mask = GameLayers.PLAYER
	_sensor.add_child(collider)
	add_child(_sensor)
	_sensor.global_position = (lo + hi) * 0.5


func _physics_process(delta: float) -> void:
	if open or _plug == null:
		return
	var spider := _spider()
	if spider == null:
		return
	if spider.stage().body_height >= opens_at or _carries_the_key(spider):
		_give_way()
		return
	# Too small. Dip under them while they are on it, and settle back after.
	var wanted := _rest
	if _leaning(spider):
		wanted = _rest - Vector3.UP * _thickness * nudge
	_plug.global_position = _plug.global_position.lerp(
		wanted, clampf(nudge_speed * delta, 0.0, 1.0))


## Whether the spider evolved its way past this one instead of growing into it.
func _carries_the_key(spider: SpiderPlayer) -> bool:
	return opens_for != "" and spider.traits != null and spider.traits.has(opens_for)


## Whether the spider is actually putting weight on it rather than passing by.
func _leaning(spider: Node3D) -> bool:
	if _sensor == null:
		return false
	_leaned_on = _sensor.overlaps_body(spider)
	return _leaned_on


func _give_way() -> void:
	open = true
	if _plug != null:
		_plug.queue_free()
		_plug = null
	if _sensor != null:
		_sensor.queue_free()
		_sensor = null
	opened.emit()


func _spider() -> SpiderPlayer:
	return get_tree().get_first_node_in_group("spider") as SpiderPlayer
