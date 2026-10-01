class_name ShortcutGate
extends Node3D

## A way back that has to be opened from the far side.
##
## A portcullis filling a passage from wall to wall and floor to ceiling, with a
## lever on one side of it. From the near side it is a wall with a room you
## already know behind it; reach the lever the long way round, and the gate
## grinds up into the roof and the long way is short from then on. It stays
## open: through every rest and every waking, a shortcut once found is yours.
##
## Spider-proof because it has to be. A spider climbs whatever it is given, so
## the gate fills the hole entire, and a lever is touched rather than shot: silk
## does not go through bars.

signal opened(gate: ShortcutGate)

@export var display_name := "Gate"
@export var open := false

## Where the lever is, in world space, and how close counts as touching it.
@export var lever_at := Vector3.ZERO
@export var reach := 1.4

## Which way it goes when it opens: up into the roof for a gate across a passage,
## aside into the floor for a hatch over a shaft.
@export var slide := Vector3.UP

## How far it goes when it opens: its own size that way, so it is all the way out.
@export var lift := 4.0

## Seconds it takes to rise.
const RISE := 1.6

var _door: StaticBody3D
var _handle: Node3D
var _rising := -1.0
var _shut_at := Vector3.ZERO


## One filling the hole between [param lo] and [param hi], with its lever at
## [param lever], all in world space; opening along [param way].
static func make(parent: Node3D, gate_name: String, lo: Vector3, hi: Vector3,
		lever: Vector3, way := Vector3.UP) -> ShortcutGate:
	var gate := ShortcutGate.new()
	gate.name = gate_name.replace(" ", "")
	gate.display_name = gate_name
	gate.slide = way.normalized()
	parent.add_child(gate)
	# Its own space is the world's, so the corners and the lever are where they say.
	gate.global_transform = Transform3D.IDENTITY
	gate._build(lo, hi, lever)
	return gate


func _build(lo: Vector3, hi: Vector3, lever: Vector3) -> void:
	var low := Vector3(minf(lo.x, hi.x), minf(lo.y, hi.y), minf(lo.z, hi.z))
	var high := Vector3(maxf(lo.x, hi.x), maxf(lo.y, hi.y), maxf(lo.z, hi.z))
	var size := high - low
	lift = absf(size.dot(slide)) + 0.1
	_door = WorldKit.body(self, "Door", Transform3D(Basis.IDENTITY, (low + high) * 0.5))
	_shut_at = _door.position
	WorldKit.box(_door, "Slab", size, Transform3D.IDENTITY, "rock_dark")
	# Bars down both faces, so it reads as a gate and not a wall.
	var across := 0 if size.x >= size.z else 2
	var width: float = size[across]
	var bars := maxi(int(width / 0.9), 3)
	for i in bars:
		var along := Vector3.ZERO
		along[across] = lerpf(-width * 0.5 + 0.35, width * 0.5 - 0.35, float(i) / float(bars - 1))
		var bar := Vector3(0.18, size.y, 0.18)
		bar[2 - across] = size[2 - across] + 0.24
		WorldKit.box(_door, "Bar%d" % i, bar, Transform3D(Basis.IDENTITY, along), "wood_dark",
			false)
	lever_at = lever
	var stand := WorldKit.group(self, "Lever", Transform3D(Basis.IDENTITY, lever))
	WorldKit.box(stand, "Base", Vector3(0.6, 0.3, 0.6), WorldKit.at(Vector3(0.0, 0.15, 0.0)),
		"rock_dark", false)
	var handle := WorldKit.group(stand, "Handle", WorldKit.at(Vector3(0.0, 0.3, 0.0)))
	WorldKit.rod(handle, "Arm", Vector3.ZERO, Vector3(0.0, 1.0, 0.0), 0.07, "wood_dark", false)
	WorldKit.ball(handle, "Knob", Vector3.ONE * 0.14, WorldKit.at(Vector3(0.0, 1.05, 0.0)),
		"yellow", false)
	_handle = handle
	_show_handle()


func _ready() -> void:
	add_to_group("shortcut_gates")
	if _door == null:
		_door = get_node_or_null("Door") as StaticBody3D
		_handle = get_node_or_null("Lever/Handle") as Node3D
	if _door != null:
		_shut_at = _door.position
	if open and _door != null:
		_door.queue_free()
		_door = null
	_show_handle()


func _physics_process(delta: float) -> void:
	if _rising >= 0.0:
		_rise(delta)
		return
	if open:
		return
	var spider := get_tree().get_first_node_in_group("spider") as SpiderPlayer
	if spider != null and spider.global_position.distance_to(lever_at) <= reach + 0.4:
		pull(spider)


## Opens it. Returns whether it was shut.
func pull(by: SpiderPlayer = null) -> bool:
	if open:
		return false
	open = true
	_rising = 0.0
	_show_handle()
	opened.emit(self)
	if by != null:
		by.notice.emit("The %s grinds open — a way back" % display_name)
	return true


## Whether the gate is out of the way yet, not just unlatched.
func is_clear() -> bool:
	return open and _door == null


func _rise(delta: float) -> void:
	_rising += delta
	if _door == null:
		_rising = -1.0
		return
	var t := clampf(_rising / RISE, 0.0, 1.0)
	_door.position = _shut_at + slide * lift * t * t * (3.0 - 2.0 * t)
	if t >= 1.0:
		_door.queue_free()
		_door = null
		_rising = -1.0


func _show_handle() -> void:
	if _handle != null:
		_handle.rotation = Vector3(0.0, 0.0, -0.7 if open else 0.7)
