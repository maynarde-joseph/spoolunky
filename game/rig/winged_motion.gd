class_name WingedMotion
extends CreatureMotion

## How something on two wings holds itself: beating them in flight, the hands a
## beat behind the arms and tucking in on the way up; folding them down its sides
## on the ground, where it walks on its two legs — a parrot standing up straight
## to do it; flapping in bursts when caught; drooping half open when spent; and
## wrapping them round itself at the end.

## How far the body goes, in body radii, in each step of a walk.
const STEP := 0.45

## The most steps a second, however fast the body goes.
const MOST_STEPS := 5.0

var _body: WingedBody
var _trunk := -1
var _head := -1
var _jaw := -1
var _ears: Array[Dictionary] = []
var _wings: Array[Dictionary] = []
var _legs: Array[Dictionary] = []
var _tail := PackedInt32Array()
var _stride := 0.0
## How much of a step the legs are taking: none standing still.
var _pace := 0.0

var _feet := PackedVector3Array()
var _wing_tips := PackedVector3Array()


func bind(skeleton: Skeleton3D, body: CreatureBody) -> void:
	_body = body as WingedBody
	if _body == null:
		return
	_keep_rest(skeleton)
	_trunk = _find(skeleton, "Body")
	_head = _find(skeleton, "Head")
	_jaw = _find(skeleton, "Jaw")
	_ears.clear()
	_wings.clear()
	_legs.clear()
	for s in 2:
		var side := -1.0 if s == 0 else 1.0
		if _body.ears != Vector2.ZERO:
			_ears.append({"bone": _find(skeleton, "Ear.%s" % WingedBody.SIDES[s]), "side": side})
		_wings.append({
			"arm": _find(skeleton, WingedBody.wing_bone(s, 0)),
			"hand": _find(skeleton, WingedBody.wing_bone(s, 1)), "side": side,
		})
		_legs.append({
			"leg": _find(skeleton, WingedBody.leg_bone(s, 0)),
			"foot": _find(skeleton, WingedBody.leg_bone(s, 1)), "side": side,
			"reach": _body.leg_rest(side)["reach"],
		})
	_tail.clear()
	if _body.whip > 0.0:
		for i in _body.whip_bones:
			_tail.append(_find(skeleton, "Tail.%d" % (i + 1)))
	elif _body.tail > 0.0:
		for i in 2:
			_tail.append(_find(skeleton, "Tail.%d" % (i + 1)))


## Where the toes of each foot were drawn last frame, in the world: left, right.
func feet() -> PackedVector3Array:
	return _feet


## Where the tip of each wing was drawn last frame, in the world: left, right.
func strokes() -> PackedVector3Array:
	return _wing_tips


func _process_modification_with_delta(delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null or _body == null or _trunk < 0:
		return
	delta = clampf(delta, 0.0, 0.1)
	clock += delta
	_blend(delta)
	var steps := minf(speed / STEP, MOST_STEPS)
	_stride = fposmod(_stride + steps * 0.5 * delta, 1.0)
	_pace = move_toward(_pace, clampf(steps / 2.0, 0.0, 1.0), clampf(EASE * delta, 0.0, 1.0))
	# On the ground it stands the way it perches.
	var tilt := deg_to_rad(_body.perch) * _walk

	_pose_body(skeleton, tilt)
	_pose_wings(skeleton)
	_pose_legs(skeleton, tilt)
	_pose_head(skeleton, tilt)
	_pose_tail(skeleton)
	_record(skeleton)


## Rising on each downstroke; rolling from foot to foot as it waddles; wriggling
## when caught, sagging when spent, hunched at the end.
func _pose_body(skeleton: Skeleton3D, tilt: float) -> void:
	var stepping := _walk * _pace
	var beat := sin(clock * _body.flap_rate * TAU)
	var calm := clampf(1.0 - _air - _curl - _thrash, 0.0, 1.0)
	_shift(skeleton, _trunk, Vector3.UP * (-beat * 0.05 * _air + sin(clock * 2.0) * 0.01 * calm))
	var roll := sin(_stride * TAU) * 0.12 * stepping + sin(clock * 8.0) * 0.2 * _thrash \
		+ 0.25 * _slack
	_turn(skeleton, _trunk, Quaternion(Vector3.BACK, roll)
		* Quaternion(Vector3.RIGHT, tilt - 0.15 * _curl))


## Beating in flight, folded down its sides at rest, flapping in bursts when
## caught, hanging half open when spent, wrapped round it at the end.
##
## Folding is two turns of the arm in the body's space, after the beat: back along
## the body about up, and then about its own length, so the wing's trailing edge
## hangs down the flank instead of lying across the back. The hand bends in the
## arm's space, where X runs back across the wing and Z is the way its upper face
## looks — up on the right, down on the left.
func _pose_wings(skeleton: Skeleton3D) -> void:
	var swing := deg_to_rad(_body.flap_swing)
	var centre := deg_to_rad(_body.flap_centre)
	var shut := PI * 0.5 - atan(_body.wing_sweep) - deg_to_rad(4.0)
	var phase := clock * _body.flap_rate * (1.0 + 0.6 * _thrash) * TAU
	var beat := sin(phase)
	for wing in _wings:
		var side: float = wing["side"]
		var burst := minf(_thrash * 2.2, 1.0) * clampf(sin(clock * 3.1 + side * 0.8) * 1.5 + 0.4,
			0.0, 1.0)
		var flapping := maxf(_air, burst)
		var closed := 1.0 - maxf(flapping, 0.55 * _slack)
		var lift := flapping * (beat * swing + centre) - _slack * 0.6
		var roll := closed * deg_to_rad(115.0 - 55.0 * _curl)
		_turn(skeleton, wing["arm"], Quaternion(Vector3.BACK, side * roll)
			* Quaternion(Vector3.UP, -side * closed * shut) * Quaternion(Vector3.BACK, side * lift))
		# Shut, it narrows across — the arm's X, which the hand's width lies along too
		# once it folds — the way skin pleats up between the fingers. Wrapped round the
		# body it opens out again, into a cloak.
		var narrow := lerpf(_body.fold_width, 0.75, _curl)
		skeleton.set_bone_pose_scale(wing["arm"], Vector3(lerpf(1.0, narrow, closed), 1.0, 1.0))
		var trail := -flapping * cos(phase - 0.45) * swing * 0.3
		var tuck := flapping * maxf(-cos(phase), 0.0) * 0.35 \
			+ closed * deg_to_rad(_body.hand_fold) + _slack * 0.3
		_turn(skeleton, wing["hand"], Quaternion(Vector3.BACK, -tuck)
			* Quaternion(Vector3.RIGHT, side * trail))


## Tucked back in flight; a step at a time on the ground, kept straight under the
## body however far back it stands; kicking when caught; drawn up at the end.
## Forward is positive, about the body's side to side.
func _pose_legs(skeleton: Skeleton3D, tilt: float) -> void:
	var stepping := _walk * _pace
	for leg in _legs:
		var side: float = leg["side"]
		var phase := (_stride + (0.0 if side < 0.0 else 0.5)) * TAU
		var kick := sin(clock * 12.0 + side * 2.0)
		var step := stepping * sin(phase) * 0.45
		var swing := step - tilt - _air * 1.1 + _thrash * kick * 0.6 + _slack * 0.15 + _curl * 1.5
		_turn(skeleton, leg["leg"], Quaternion(Vector3.RIGHT, swing))
		var toes := -step + maxf(cos(phase), 0.0) * stepping * 0.4 - _air * 0.9 - _curl * 1.2 \
			+ _thrash * kick * 0.4
		_turn(skeleton, leg["foot"], Quaternion(Vector3.RIGHT, toes))


## Looking about, kept level however it stands; bobbing as it walks; shaking
## with its mouth open when caught; hanging when spent; tucked at the end.
func _pose_head(skeleton: Skeleton3D, tilt: float) -> void:
	var stepping := _walk * _pace
	var calm := clampf(1.0 - _curl - _thrash - _slack, 0.0, 1.0)
	var look := sin(clock * 0.6) * 0.35 * calm * (1.0 - _air * 0.7)
	var nod := -tilt + sin(_stride * TAU * 2.0) * 0.1 * stepping + 0.3 * _thrash - 0.6 * _slack \
		- 0.8 * _curl
	var shake := sin(clock * 14.0) * 0.3 * _thrash
	_turn(skeleton, _head, Quaternion(Vector3.UP, look + shake) * Quaternion(Vector3.RIGHT, nod))
	var gape := _thrash * (0.3 + 0.3 * sin(clock * 11.0)) + _slack * 0.15
	_turn(skeleton, _jaw, Quaternion(Vector3.RIGHT, -gape))
	for flap in _ears:
		var side: float = flap["side"]
		var flick := maxf(sin(clock * 0.9 + side * 1.3) - 0.92, 0.0) * 6.0 * calm
		var back := 0.5 * _air + 0.6 * _thrash + 0.7 * _curl + 0.3 * _slack
		_turn(skeleton, flap["bone"], Quaternion(Vector3.BACK, -side * flick * 0.25)
			* Quaternion(Vector3.RIGHT, back))


## Bobbing as it walks, flicking when caught, hanging when spent, tucked under
## at the end. A whip lashes instead.
func _pose_tail(skeleton: Skeleton3D) -> void:
	if _body.whip > 0.0:
		_pose_whip(skeleton)
		return
	var stepping := _walk * _pace
	var pitch := sin(_stride * TAU * 2.0) * 0.12 * stepping \
		+ sin(clock * 1.5) * 0.04 * (1.0 - _curl) + _thrash * sin(clock * 12.0) * 0.4 \
		+ 0.35 * _slack - 0.1 * _air + 0.4 * _curl
	for i in _tail.size():
		var fan := _thrash * sin(clock * 9.0 + float(i)) * 0.2
		var across := Vector3.UP if i == 0 else Vector3.FORWARD
		_turn(skeleton, _tail[i], Quaternion(across, fan)
			* Quaternion(Vector3.RIGHT, pitch * (1.0 if i == 0 else 0.5)))


## A whip: a slow wave down it from the root as it flies or stands, lashing when
## it is caught, hanging when it is spent, and wrapped round to one side at the
## end. Side to side is about up for the first bone, whose parent is the body, and
## about its parent's -Z for the rest, as down a beast's tail.
func _pose_whip(skeleton: Skeleton3D) -> void:
	var calm := clampf(1.0 - _curl - _thrash - _slack, 0.0, 1.0)
	var rate := 1.8 * calm + 9.0 * _thrash
	var reach := 0.12 * calm + 0.5 * _thrash
	var count := float(maxi(_tail.size(), 1))
	for i in _tail.size():
		var lag := float(i) * 0.6
		var across := sin(clock * rate - lag) * reach + _curl * 2.0 / count
		var droop := (0.8 * _slack + 0.3 * _walk + 0.4 * _curl) / count
		var up := Vector3.UP if i == 0 else Vector3.FORWARD
		_turn(skeleton, _tail[i], Quaternion(up, across) * Quaternion(Vector3.RIGHT, droop))


func _record(skeleton: Skeleton3D) -> void:
	_feet.resize(_legs.size())
	for i in _legs.size():
		var leg: Dictionary = _legs[i]
		_feet[i] = _tip(skeleton, leg["foot"], leg["reach"])
	_wing_tips.resize(_wings.size())
	for i in _wings.size():
		_wing_tips[i] = _tip(skeleton, _wings[i]["hand"], _body.hand)
