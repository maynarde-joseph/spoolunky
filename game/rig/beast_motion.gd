class_name BeastMotion
extends CreatureMotion

## How something on four legs holds itself: a trot, two legs at a time, that
## bobs the body and swings the tail; stretched out in a leap when it is off the
## ground; paws scrabbling at nothing and head shaking when it is caught; hanging
## when it is spent; and curled up small at the end.
##
## Like an insect's, nothing here plants a foot. The legs trot in the diagonal
## pairs a real one uses — front left with hind right, then front right with hind
## left — and a creature that stops puts all four down.

## The most strides a second the legs will take, however fast the body goes.
const MOST_STRIDES := 3.5

var _body: BeastBody
var _trunk := -1
var _head := -1
var _jaw := -1
var _ears: Array[Dictionary] = []
var _legs: Array[Dictionary] = []
var _tail := PackedInt32Array()
var _stride := 0.0
## How much of a stride the legs are taking: none standing still.
var _pace := 0.0
## How far its legs splay out to the sides, 0 to 1.
var _splay := 0.0

var _feet := PackedVector3Array()


func bind(skeleton: Skeleton3D, body: CreatureBody) -> void:
	_body = body as BeastBody
	if _body == null:
		return
	_keep_rest(skeleton)
	_splay = clampf(_body.sprawl / 70.0, 0.0, 1.0)
	_trunk = _find(skeleton, "Body")
	_head = _find(skeleton, "Head")
	_jaw = _find(skeleton, "Jaw")
	_ears.clear()
	if _body.ears != BeastBody.Ears.NONE:
		for s in 2:
			_ears.append({"bone": _find(skeleton, "Ear.%s" % BeastBody.SIDES[s]),
				"side": -1.0 if s == 0 else 1.0})
	_legs.clear()
	for end in 2:
		for s in 2:
			var bones := PackedInt32Array()
			for part in 3:
				bones.append(_find(skeleton, BeastBody.leg_bone(end, s, part)))
			_legs.append({
				"bones": bones, "side": -1.0 if s == 0 else 1.0, "end": end,
				"group": (end + s) % 2, "reach": _body.foot,
			})
	_tail.clear()
	if _body.tail > 0.0:
		for i in _body.tail_bones:
			_tail.append(_find(skeleton, BeastBody.tail_bone(i)))


## Where the sole of every paw was drawn last frame, in the world: front left,
## front right, hind left, hind right.
func feet() -> PackedVector3Array:
	return _feet


func _process_modification_with_delta(delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null or _body == null or _trunk < 0:
		return
	delta = clampf(delta, 0.0, 0.1)
	clock += delta
	_blend(delta)
	var strides := minf(speed / maxf(_body.stride, 0.01), MOST_STRIDES)
	_stride = fposmod(_stride + strides * delta, 1.0)
	_pace = move_toward(_pace, clampf(strides, 0.0, 1.0), clampf(EASE * delta, 0.0, 1.0))

	_pose_body(skeleton)
	_pose_legs(skeleton)
	_pose_head(skeleton)
	_pose_tail(skeleton)
	_record(skeleton)


## Bobbing and rolling a little as it trots, breathing as it stands, wriggling
## when caught and sagging when spent.
func _pose_body(skeleton: Skeleton3D) -> void:
	var stepping := _walk * _pace
	var calm := 1.0 - _curl - _thrash
	var rise := cos(_stride * TAU * 2.0) * 0.035 * stepping + sin(clock * 2.1) * 0.012 * calm
	_shift(skeleton, _trunk, Vector3.UP * rise)
	var roll := sin(_stride * TAU) * 0.05 * stepping + sin(clock * 9.0) * 0.22 * _thrash \
		+ 0.2 * _slack
	var yaw := sin(clock * 7.0) * 0.12 * _thrash
	# Stretched out in a leap, it arches its back a little: the nose comes up.
	var pitch := 0.08 * _air
	_turn(skeleton, _trunk, Quaternion(Vector3.UP, yaw) * Quaternion(Vector3.BACK, roll)
		* Quaternion(Vector3.RIGHT, pitch))


## Trotting; reaching out front and back in a leap; paddling at the air when
## caught; loose when spent; tucked under at the end. Forward is positive: a leg
## swings about the body's sideways axis, and its lower part and paw bend about
## their own.
func _pose_legs(skeleton: Skeleton3D) -> void:
	var stepping := _walk * _pace
	for leg in _legs:
		var bones: PackedInt32Array = leg["bones"]
		var front: bool = leg["end"] == 0
		var phase := (_stride + 0.5 * float(leg["group"])) * TAU
		var swing := sin(phase)
		var lifted := maxf(cos(phase), 0.0)
		var k := float(leg["end"]) * 2.0 + (0.0 if float(leg["side"]) < 0.0 else 1.0)
		var paddle := clock * 11.0 + k * 1.7
		var twitch := maxf(sin(clock * 1.3 + k * 2.3) - 0.9, 0.0) * 3.0
		var upper := stepping * swing * 0.45 + _air * (0.9 if front else -0.8) \
			+ _thrash * sin(paddle) * 1.0 + _slack * (twitch * 0.2 - 0.1) + _curl * 1.0
		var lower := -(stepping * lifted * 0.9 + _air * 0.35 \
			+ _thrash * (0.8 + 0.8 * cos(paddle)) + _slack * 0.25 + _curl * 2.0)
		# The paw stays level, whatever the leg above it is doing, until the end.
		var paw := -(upper + lower) * (1.0 - _curl) + _curl * 0.4 - _thrash * 0.4
		# Legs splayed out to the sides kick up and down as well when it is caught:
		# short as they are, swinging back and forth alone they hardly move. Wrapped,
		# they come in under it, out of the splay.
		var kick := _thrash * sin(paddle * 0.7 + 1.0) * 1.2 * _splay \
			+ _curl * deg_to_rad(_body.sprawl) * 0.9
		_turn(skeleton, bones[0], Quaternion(Vector3.BACK, -float(leg["side"]) * kick)
			* Quaternion(Vector3.RIGHT, upper))
		_turn(skeleton, bones[1], Quaternion(Vector3.RIGHT, lower))
		_turn(skeleton, bones[2], Quaternion(Vector3.RIGHT, paw))


## Looking about; bobbing as it trots; shaking its head, mouth open, when caught;
## drooping when spent; tucked in at the end. The ears twitch, or flap.
func _pose_head(skeleton: Skeleton3D) -> void:
	var stepping := _walk * _pace
	var calm := clampf(1.0 - _curl - _thrash - _slack, 0.0, 1.0)
	var look := sin(clock * 0.53) * 0.3 * calm * (1.0 - stepping * 0.7)
	var nod := sin(_stride * TAU * 2.0 + 0.8) * 0.06 * stepping + sin(clock * 0.8) * 0.05 * calm \
		+ 0.12 * _air - 0.55 * _slack - 0.75 * _curl + 0.25 * _thrash
	var shake := sin(clock * 13.0) * 0.35 * _thrash
	_turn(skeleton, _head, Quaternion(Vector3.UP, look + shake) * Quaternion(Vector3.RIGHT, nod))

	var panting := 1.0 - _thrash - _curl if _body.pants else 0.0
	var gape := maxf(panting, 0.0) * (0.3 + 0.06 * sin(clock * 9.0)) \
		+ _thrash * (0.35 + 0.25 * sin(clock * 10.0)) + _slack * 0.15
	_turn(skeleton, _jaw, Quaternion(Vector3.RIGHT, -gape))

	for flap in _ears:
		var side: float = flap["side"]
		if _body.ears == BeastBody.Ears.FLOPPY:
			# Hanging loose, they swing with the head, fly out in a leap and flap
			# about when it thrashes.
			var swing := sin(_stride * TAU * 2.0) * 0.18 * stepping \
				+ sin(clock * 12.0 + side) * 0.5 * _thrash
			var lift := 0.6 * _air + _thrash * (0.35 + 0.35 * sin(clock * 9.0 + side)) \
				+ absf(sin(_stride * TAU * 2.0)) * 0.12 * stepping
			_turn(skeleton, flap["bone"], Quaternion(Vector3.BACK, side * lift)
				* Quaternion(Vector3.RIGHT, swing))
		else:
			# Upright, they flick out now and then, and flatten back when things go
			# badly.
			var flick := maxf(sin(clock * 0.9 + side * 1.3) - 0.92, 0.0) * 6.0 * calm
			var back := 0.6 * _thrash + 0.7 * _curl + 0.3 * _slack
			_turn(skeleton, flap["bone"], Quaternion(Vector3.BACK, -side * flick * 0.25)
				* Quaternion(Vector3.RIGHT, back))


## Swinging as it goes, or wagging; lashing when caught; hanging when spent;
## wrapped round to the side at the end. A wave runs down it from the root, each
## bone a little behind the one before.
##
## Each bone turns in its parent's space. The first one's parent is the body, so
## side to side is about up; every other one's is the bone before it, which runs
## along the tail with its X out to the side, so side to side there is about its
## -Z. Down is about X for all of them.
func _pose_tail(skeleton: Skeleton3D) -> void:
	var stepping := _walk * _pace
	var calm := clampf(1.0 - _curl - _thrash - _slack, 0.0, 1.0)
	var wag := _body.wag
	var rate := lerpf(1.6, 9.0, wag * maxf(stepping, 0.5)) * calm + 10.0 * _thrash
	var reach := (0.1 + 0.1 * stepping + 0.25 * wag) * calm + 0.45 * _thrash
	var count := float(maxi(_tail.size(), 1))
	for i in _tail.size():
		var lag := float(i) * 0.7
		var across := sin(clock * rate - lag) * reach + _curl * 1.6 / count
		var droop := (0.7 * _slack + 0.3 * _air + 0.35 * _curl) / count
		var up := Vector3.UP if i == 0 else Vector3.FORWARD
		_turn(skeleton, _tail[i], Quaternion(up, across) * Quaternion(Vector3.RIGHT, droop))


func _record(skeleton: Skeleton3D) -> void:
	_feet.resize(_legs.size())
	for i in _legs.size():
		var leg: Dictionary = _legs[i]
		_feet[i] = _tip(skeleton, (leg["bones"] as PackedInt32Array)[2], leg["reach"])
