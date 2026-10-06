class_name MovingPlatform
extends AnimatableBody3D

## A piece that moves along a path: back and forth along it, or round it, waiting
## a moment at each end. With a channel it only moves while that channel is
## powered. Whatever is on it rides it, and silk stuck to it goes with it.

var path := PackedVector3Array()
var speed := 3.0
var wait := 0.8
var loops := false
var channel := ""

var _leg := 1
var _forward := true
var _waiting := 0.0


func _ready() -> void:
	collision_layer = GameLayers.WORLD
	collision_mask = 0
	sync_to_physics = true
	if path.size() >= 1:
		position = path[0]


func _physics_process(delta: float) -> void:
	var run := LevelRun.current(self)
	if run == null or path.size() < 2:
		return
	if channel != "" and not run.is_powered(channel):
		return
	if _waiting > 0.0:
		_waiting -= delta
		return
	var goal := path[_leg]
	var to := goal - position
	var step := speed * delta
	if to.length() <= step:
		position = goal
		_waiting = wait
		_next()
		return
	position += to.normalized() * step


func _next() -> void:
	if loops and path.size() >= 3:
		_leg = (_leg + 1) % path.size()
		return
	if _forward and _leg >= path.size() - 1:
		_forward = false
	elif not _forward and _leg <= 0:
		_forward = true
	_leg += 1 if _forward else -1
