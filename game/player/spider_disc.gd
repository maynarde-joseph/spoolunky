class_name SpiderDisc
extends Node

## The spell disc: hold its key and the spells in hand come up in a ring round the
## cross, the world slows to a crawl, and a flick of the mouse toward one and letting
## go takes it in hand.
##
## Slowed rather than stopped, so the moment goes on: what you are choosing for is
## still moving, only slowly, and you can let go when it gets where you want it. The
## mouse moves the pointer instead of the view while the disc is up, so the slow is
## help with choosing and none with aiming.
##
## The number keys and the wheel still take spells in hand without it. The disc is
## for when the keys are too far from the hand that is steering — and, being the same
## for every spell in the same place every time, it is soon a flick you do without
## looking.

## The disc came up, or went away.
signal opened()
signal closed()

## How fast the world goes while the disc is up, against its own pace.
@export var slow := 0.25

## How long the world takes to slow when the disc comes up, and to come back up to
## speed when it goes, in real seconds — quick, but not a jolt.
@export var ease_time := 0.12

## How far the mouse has to take the pointer from the middle before it is on a slice,
## and how far it can take it, in pixels of mouse travel. Let go inside the first and
## nothing changes hands.
@export var dead_zone := 24.0
@export var pointer_reach := 120.0

## Whether the disc is up.
var is_open := false

## Where the mouse has taken the pointer since the disc came up, from its middle, in
## pixels; down is positive, as on the screen.
var pointer := Vector2.ZERO

var _spider: SpiderPlayer
var _spells: SpiderSpells

## The pace the world is being run at: 1 when nothing is slowing it.
var _pace := 1.0

## Whether this has the engine's clock slowed, and so has to put it back.
var _slowing := false


func _ready() -> void:
	# The clock has to come back even with the game paused under the disc — a screen
	# opened over it — so this keeps running when everything else stops.
	process_mode = Node.PROCESS_MODE_ALWAYS


func setup(spider: SpiderPlayer, spells: SpiderSpells) -> void:
	_spider = spider
	_spells = spells


func _process(delta: float) -> void:
	if is_open and _spider != null and not _spider.accepts_input():
		close(false)
	_pace_the_world(delta)


func _exit_tree() -> void:
	if _slowing:
		Engine.time_scale = 1.0
		_slowing = false
	_pace = 1.0


## Brings the disc up. A wind-up under way is given up, as a number key gives it up:
## the disc is the player saying they want something else in hand. False if it is up
## already, or there is nothing on the keys to choose between.
func open() -> bool:
	if is_open or _spells == null or slices().size() < 2:
		return false
	_spells.cancel_cast()
	is_open = true
	pointer = Vector2.ZERO
	opened.emit()
	return true


## Puts the disc away, and with [param choose] takes in hand whatever the pointer is
## on. Returns whether anything changed hands.
func close(choose := true) -> bool:
	if not is_open:
		return false
	var spell := pointed() if choose else null
	is_open = false
	pointer = Vector2.ZERO
	closed.emit()
	if spell == null:
		return false
	return _spells.take(_spells.key_for(spell))


## Puts the disc away without taking anything, and the world's clock straight back
## to its own pace rather than easing it: for when the moment is over anyway — put
## back after a fall, or a check starting afresh.
func settle() -> void:
	close(false)
	_pace = 1.0
	if _slowing:
		Engine.time_scale = 1.0
		_slowing = false


## Moves the pointer by [param motion], the way the mouse moved: what the view would
## have turned by, had the disc not been up.
func steer(motion: Vector2) -> void:
	pointer = (pointer + motion).limit_length(pointer_reach)


## What the disc offers, in order round it from the top: what the number keys hold.
func slices() -> Array[SpiderSpell]:
	if _spells == null:
		var none: Array[SpiderSpell] = []
		return none
	return _spells.hand()


## Which slice the pointer is on, or -1 inside the dead zone.
func pointed_index() -> int:
	if pointer.length() < dead_zone:
		return -1
	return slice_at(pointer, slices().size())


## The spell the pointer is on, or null.
func pointed() -> SpiderSpell:
	var keys := slices()
	var index := pointed_index()
	return keys[index] if index >= 0 and index < keys.size() else null


## How fast the world is going now, against its own pace: [member slow] with the disc
## up, 1 with it away, and in between while it eases.
func pace() -> float:
	return _pace


## Which of [param count] slices a pointer [param direction] from the middle is on:
## the first at the top, and on round clockwise, each centred on its own direction.
static func slice_at(direction: Vector2, count: int) -> int:
	if count <= 0:
		return -1
	var share := TAU / float(count)
	var turn := fposmod(direction.angle() + PI * 0.5 + share * 0.5, TAU)
	return clampi(int(turn / share), 0, count - 1)


## The direction of the middle of slice [param index] of [param count], from the
## disc's middle, on the screen: down is positive.
static func slice_direction(index: int, count: int) -> Vector2:
	var share := TAU / float(maxi(count, 1))
	return Vector2.from_angle(-PI * 0.5 + share * float(index))


# --- the world's clock ----------------------------------------------------

## Eases the engine's clock toward the disc's pace, in real time — the frame's time
## is already slowed by however slow the clock is — and gives the clock back whole
## once the disc is away and the world is up to speed.
func _pace_the_world(delta: float) -> void:
	var real := delta / Engine.time_scale if Engine.time_scale > 0.0001 else delta
	var target := slow if is_open else 1.0
	_pace = move_toward(_pace, target, real * absf(1.0 - slow) / maxf(ease_time, 0.001))
	if is_open or _pace < 1.0:
		Engine.time_scale = _pace
		_slowing = true
	elif _slowing:
		Engine.time_scale = 1.0
		_slowing = false
