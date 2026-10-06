class_name SlideDoor
extends AnimatableBody3D

## A block that slides out of the way while its channel is powered, and back when
## it is not. Silk sticks to it and goes with it.

const SPEED := 5.0

var channel := "a"

## How far it slides when open, in the level's own axes.
var open_by := Vector3(0.0, 4.2, 0.0)

var _closed := Vector3.ZERO


func _ready() -> void:
	collision_layer = GameLayers.WORLD
	collision_mask = 0
	sync_to_physics = true
	_closed = position


func _physics_process(delta: float) -> void:
	var run := LevelRun.current(self)
	if run == null:
		return
	var goal := _closed + open_by if run.is_powered(channel) else _closed
	position = position.move_toward(goal, SPEED * delta)
