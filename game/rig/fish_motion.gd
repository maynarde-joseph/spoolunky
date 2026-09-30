class_name FishMotion
extends CreatureMotion

## How something that swims holds itself: a wave that runs down it from nose to
## tail, faster and wider the faster it goes, with its side fins paddling and its
## mouth gulping; out of the water, on its side, gasping, and flopping when it
## tries to go anywhere; caught, thrashing hard; spent, rolling over; and bent
## double at the end.
##
## Its flying is swimming: something that moves through water the way an insect
## moves through air is, as far as its body goes, flying in it.

var _body: FishBody
var _trunk := -1
var _tail := -1
var _fin := -1
var _jaw := -1
var _paddles: Array[Dictionary] = []
var _wave := 0.0
var _strokes := PackedVector3Array()


func bind(skeleton: Skeleton3D, body: CreatureBody) -> void:
	_body = body as FishBody
	if _body == null:
		return
	_keep_rest(skeleton)
	_trunk = _find(skeleton, "Body")
	_tail = _find(skeleton, "Tail")
	_fin = _find(skeleton, "Fin")
	_jaw = _find(skeleton, "Jaw")
	_paddles.clear()
	for s in 2:
		_paddles.append({"bone": _find(skeleton, "Pectoral.%s" % FishBody.SIDES[s]),
			"side": -1.0 if s == 0 else 1.0})


## Where the tip of the tail fin's top lobe and the tips of the side fins were
## drawn last frame, in the world.
func strokes() -> PackedVector3Array:
	return _strokes


func _process_modification_with_delta(delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null or _body == null or _trunk < 0:
		return
	delta = clampf(delta, 0.0, 0.1)
	clock += delta
	_blend(delta)
	# The tail beats faster the faster it goes, and far faster in a fight.
	var rate := _body.beat_rate * (1.0 + clampf(speed * 0.2, 0.0, 1.5)) * (1.0 + 2.5 * _thrash)
	_wave = fposmod(_wave + rate * delta, 1.0)

	_pose_body(skeleton)
	_pose_fins(skeleton)
	_record(skeleton)


## The wave down the body and tail, and how the body lies: level in water, on its
## side out of it, rolled over when spent, bent double at the end.
func _pose_body(skeleton: Skeleton3D) -> void:
	var swing := deg_to_rad(_body.swing)
	var wave := _wave * TAU
	var cruise := swing * (0.45 + 0.55 * clampf(speed / 4.0, 0.0, 1.0)) * _air
	var fight := swing * 1.7 * _thrash
	var idle := swing * (0.06 * _walk + 0.15 * _slack)
	var reach := cruise + fight + idle
	# Out of the water it lies on its side and gasps; trying to go anywhere, it
	# flops — bends hard, and springs up off the floor.
	var flop := pow(maxf(sin(clock * 5.0), 0.0), 3.0) * clampf(speed, 0.0, 1.0) * _walk
	_shift(skeleton, _trunk, Vector3.UP * (0.2 * flop))
	var roll := PI * 0.5 * _walk + 0.7 * _slack + sin(clock * 7.0) * 0.15 * _thrash
	_turn(skeleton, _trunk, Quaternion(Vector3.BACK, roll)
		* Quaternion(Vector3.UP, -sin(wave) * reach * 0.25 - 0.25 * _curl - 0.3 * flop))
	_turn(skeleton, _tail, Quaternion(Vector3.UP, sin(wave - 0.9) * reach + 1.1 * _curl
		+ 0.6 * flop))
	_turn(skeleton, _fin, Quaternion(Vector3.UP, sin(wave - 1.8) * reach * 1.3 + 1.1 * _curl
		+ 0.5 * flop))


## The side fins paddling, flapping in a fight and folded back at the end; the
## mouth gulping, gasping out of water, snapping when caught.
func _pose_fins(skeleton: Skeleton3D) -> void:
	# Only in water: out of it they lie flat.
	var calm := _air
	for paddle in _paddles:
		var side: float = paddle["side"]
		var sweep := sin(clock * 3.0 + side) * 0.3 * calm + sin(clock * 13.0 + side) * 0.5 * _thrash \
			- side * 0.8 * _curl - side * 0.4 * _walk
		var flap := sin(clock * 3.0 + side * 0.5) * 0.15 * calm + sin(clock * 11.0) * 0.4 * _thrash \
			- side * 0.3 * _slack
		_turn(skeleton, paddle["bone"], Quaternion(Vector3.UP, sweep)
			* Quaternion(Vector3.BACK, side * flap))
	var gape := (0.08 + 0.08 * sin(clock * 2.5)) * _air + (0.22 + 0.18 * sin(clock * 4.0)) * _walk \
		+ (0.3 + 0.3 * sin(clock * 9.0)) * _thrash + 0.2 * _slack \
		+ deg_to_rad(_body.grin) * (1.0 - _curl)
	_turn(skeleton, _jaw, Quaternion(Vector3.RIGHT, -gape))


func _record(skeleton: Skeleton3D) -> void:
	var high := _body.tail_fin.x * 0.5 * sqrt(_body.lobe)
	var long := _body.tail_fin.y * sqrt(_body.lobe)
	_strokes.resize(1 + _paddles.size())
	_strokes[0] = _at(skeleton, _fin, Vector3(0.0, high, long))
	for i in _paddles.size():
		_strokes[i + 1] = _tip(skeleton, _paddles[i]["bone"], _body.pectoral.x)
