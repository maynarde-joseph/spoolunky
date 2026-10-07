class_name LoosePanel
extends StaticBody3D

## A loose board, nailed over whatever is behind it: stone a web could stick to, a
## way through, a line of sight.
##
## Silk sticks to it, but it will not take the spider's weight: the grapple will not
## pull you to a web on it, and you cannot walk onto one. What a web on it is for is
## the Pullback. Call that web home and it rips the board away — the board tumbles
## off toward you and is gone, and so is any other silk that was on it — leaving
## what it covered.

const GROUP := "loose_panel"

## How long the board takes to tumble away, in seconds.
const FALL_TIME := 1.0

var _falling := false
var _left := 0.0
var _flight := Vector3.ZERO
var _spin := Vector3.ZERO


func _ready() -> void:
	collision_layer = GameLayers.WORLD
	collision_mask = 0
	add_to_group(GROUP)


## Whether it has been ripped away.
func is_gone() -> bool:
	return _falling


## Ripped off by a web called home to [param toward]: it stops being solid at once,
## and tumbles away toward there. Silk still on it comes apart.
func rip(toward: Vector3) -> void:
	if _falling:
		return
	_falling = true
	_left = FALL_TIME
	collision_layer = 0
	for child in get_children():
		var web := child as ThrownWeb
		if web != null and web.is_standing():
			web.spend()
	var away := toward - global_position
	away.y = 0.0
	_flight = (away.normalized() if away.length() > 0.01 else Vector3.ZERO) * 4.0 + Vector3.UP * 3.0
	_spin = Vector3(randf_range(-3.0, 3.0), randf_range(-2.0, 2.0), randf_range(-3.0, 3.0))


func _physics_process(delta: float) -> void:
	if not _falling:
		return
	_left -= delta
	_flight.y -= 20.0 * delta
	global_position += _flight * delta
	rotation += _spin * delta
	scale = Vector3.ONE * clampf(_left / FALL_TIME * 1.5, 0.01, 1.0)
	if _left <= 0.0:
		queue_free()
