class_name InsectMotion
extends CreatureMotion

## How an insect holds itself: wings that beat in flight and fold at rest, six legs
## that tuck up to fly, walk three at a time, thrash in a web and curl up at the
## end, and feelers that never quite keep still.
##
## Nothing here looks at the world or plants a foot. Every pose is a turn off the
## rest pose, blended in and out over a moment, so going from flying to caught to
## wrapped is a change of shape rather than a jump — and at an insect's size that
## is all anyone will see.
##
## The legs walk in the two sets of three real insects use, L1 R2 L3 and then R1
## L2 R3, so there is always a tripod on the ground.

## The most steps a second the legs will take, however fast the body goes. Past
## this a walk reads as a shimmer, not as legs.
const MOST_STEPS := 7.0

var _body: InsectBody
var _thorax := -1
var _head := -1
var _abdomen := -1
var _legs: Array[Dictionary] = []
var _wings: Array[Dictionary] = []
var _feelers: Array[Dictionary] = []
var _jaws: Array[Dictionary] = []
var _stride := 0.0
## How much of a stride the legs are taking: none standing still, so that an
## insect that stops puts all six feet down instead of freezing mid-step.
var _pace := 0.0

var _feet := PackedVector3Array()
var _wing_tips := PackedVector3Array()


func bind(skeleton: Skeleton3D, body: CreatureBody) -> void:
	_body = body as InsectBody
	if _body == null:
		return
	_keep_rest(skeleton)
	_thorax = _find(skeleton, "Thorax")
	_head = _find(skeleton, "Head")
	_abdomen = _find(skeleton, "Abdomen")
	_legs.clear()
	for pair in 3:
		for s in 2:
			var side := -1.0 if s == 0 else 1.0
			var limb := _body.leg_rest(pair, side)
			var bones := PackedInt32Array()
			for part in 3:
				bones.append(_find(skeleton, InsectBody.leg_bone(pair, s, part)))
			_legs.append({
				"bones": bones, "side": side, "pair": pair, "group": (pair + s) % 2,
				"normal": limb["normal"], "reach": (limb["lengths"] as Vector3).z,
			})
	_wings.clear()
	for hind in _body.wing_pairs:
		for s in 2:
			var size: Vector2 = _body.hind_wing if hind == 1 else _body.wing
			_wings.append({
				"bone": _find(skeleton, InsectBody.wing_bone(hind == 1, s)),
				"side": -1.0 if s == 0 else 1.0, "hind": hind == 1, "length": size.x,
			})
	_feelers.clear()
	_jaws.clear()
	for s in 2:
		var tag: String = InsectBody.SIDES[s]
		_feelers.append({
			"base": _find(skeleton, "Antenna.%s.1" % tag),
			"tip": _find(skeleton, "Antenna.%s.2" % tag), "side": -1.0 if s == 0 else 1.0,
		})
		var jaw := _find(skeleton, "Mandible.%s" % tag, true)
		if jaw >= 0:
			_jaws.append({"bone": jaw, "side": -1.0 if s == 0 else 1.0})


## Where the tip of every foot was drawn last frame, in the world, in leg order:
## L1 R1 L2 R2 L3 R3.
func feet() -> PackedVector3Array:
	return _feet


## Where the tip of every wing was drawn last frame, in the world, forewings first.
func strokes() -> PackedVector3Array:
	return _wing_tips


func _process_modification_with_delta(delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null or _body == null or _thorax < 0:
		return
	delta = clampf(delta, 0.0, 0.1)
	clock += delta
	_blend(delta)
	var steps := minf(speed / maxf(_body.stride, 0.01), MOST_STEPS)
	_stride = fposmod(_stride + steps * delta, 1.0)
	_pace = move_toward(_pace, clampf(steps / 2.0, 0.0, 1.0), clampf(EASE * delta, 0.0, 1.0))

	_pose_body(skeleton)
	_pose_wings(skeleton)
	_pose_legs(skeleton)
	_pose_head(skeleton)
	_record(skeleton)


## Hovering bobs; breathing and thrashing move the abdomen; the end curls it under.
func _pose_body(skeleton: Skeleton3D) -> void:
	_shift(skeleton, _thorax, Vector3.UP * sin(clock * 2.3) * 0.04 * _air)
	if _abdomen >= 0:
		var pitch := sin(clock * 2.2) * 0.04 - 0.08 * _air + 0.35 * _curl \
			+ _thrash * sin(clock * 11.0) * 0.25 + _walk * sin(_stride * TAU * 2.0) * 0.03
		_turn(skeleton, _abdomen, Quaternion(Vector3.RIGHT, pitch))


## Beating in flight; folded back over the abdomen at rest — or held up together,
## for a butterfly; buzzing in bursts while caught.
func _pose_wings(skeleton: Skeleton3D) -> void:
	var swing := deg_to_rad(_body.flap_swing)
	for wing in _wings:
		var side: float = wing["side"]
		var beat := sin((clock * _body.flap_rate + (0.08 if wing["hind"] else 0.0)) * TAU)
		var buzz := _thrash * clampf(sin(clock * 4.3 + side) * 1.5 + 0.2, 0.0, 1.0)
		var open := maxf(_air, buzz)
		var lift := open * (beat * swing + deg_to_rad(_body.flap_centre))
		var fold := 0.0
		var raise := 0.0
		if _body.wings_up:
			raise = (1.0 - open) * deg_to_rad(85.0)
		else:
			fold = (1.0 - open) * deg_to_rad(82.0 if wing["hind"] else 76.0)
			raise = (1.0 - open) * deg_to_rad(10.0)
		_turn(skeleton, wing["bone"], Quaternion(Vector3.UP, -side * fold)
			* Quaternion(Vector3.BACK, side * (lift + raise)))


## Tucked under to fly; three at a time to walk; thrashing, each to its own beat,
## when caught; hanging slack when the fight is gone; curled up at the end.
func _pose_legs(skeleton: Skeleton3D) -> void:
	for leg in _legs:
		var bones: PackedInt32Array = leg["bones"]
		var side: float = leg["side"]
		var pair: int = leg["pair"]
		var phase := (_stride + 0.5 * float(leg["group"])) * TAU
		var swing := sin(phase)
		var lifted := maxf(cos(phase), 0.0)
		var k := float(pair * 2) + (0.0 if side < 0.0 else 1.0)
		var flail := sin(clock * (9.0 + k * 1.3) + k * 2.1)
		var flail_too := sin(clock * (7.0 + k * 0.9) + k)
		var twitch := maxf(sin(clock * 1.7 + k * 1.9) - 0.85, 0.0) * 4.0
		# Forward is positive; in flight the front pair reaches a little ahead and
		# the rest trail.
		var tuck := 0.15 if pair == 0 else -0.35
		var stepping := _walk * _pace
		var ahead := stepping * swing * 0.4 + _air * tuck + _thrash * flail * 0.5 \
			+ _slack * twitch * 0.2
		var up := stepping * lifted * 0.35 - _air * 0.3 + _thrash * flail_too * 0.5 \
			+ _curl * 0.9 - _slack * 0.15
		var knee := _air * 0.9 + _curl * 1.25 + _thrash * flail * 0.35 + _slack * 0.3 \
			+ stepping * lifted * 0.2
		var ankle := _air * 0.5 + _curl * 0.8 + _thrash * flail_too * 0.3
		_turn(skeleton, bones[0], Quaternion(Vector3.UP, side * ahead)
			* Quaternion(leg["normal"], up))
		# The knee and ankle bend about the leg's own sideways axis, which is every
		# leg bone's X.
		_turn(skeleton, bones[1], Quaternion(Vector3.RIGHT, -knee))
		_turn(skeleton, bones[2], Quaternion(Vector3.RIGHT, -ankle))


## Feelers that wave, jaws that work, and a head that looks about.
func _pose_head(skeleton: Skeleton3D) -> void:
	var calm := 1.0 - _curl
	if _head >= 0:
		_turn(skeleton, _head, Quaternion(Vector3.UP, sin(clock * 0.7) * 0.08 * calm)
			* Quaternion(Vector3.RIGHT, -0.3 * _curl - _thrash * sin(clock * 6.0) * 0.1))
	for feeler in _feelers:
		var side: float = feeler["side"]
		var wave := sin(clock * 1.3 + side) * 0.15 * calm + _thrash * sin(clock * 14.0 + side) * 0.3
		var nod := sin(clock * 1.1 + side * 0.7) * 0.12 * calm + _curl * 0.8 \
			+ _walk * sin(_stride * TAU * 2.0 + side) * 0.1
		_turn(skeleton, feeler["base"], Quaternion(Vector3.UP, side * wave)
			* Quaternion(Vector3.RIGHT, nod))
		_turn(skeleton, feeler["tip"], Quaternion(Vector3.RIGHT,
			sin(clock * 1.7 + side) * 0.1 * calm))
	for jaw in _jaws:
		var open := 0.1 + 0.4 * _thrash * (0.5 + 0.5 * sin(clock * 13.0))
		_turn(skeleton, jaw["bone"], Quaternion(Vector3.UP, -float(jaw["side"]) * open))


func _record(skeleton: Skeleton3D) -> void:
	_feet.resize(_legs.size())
	for i in _legs.size():
		var leg: Dictionary = _legs[i]
		_feet[i] = _tip(skeleton, (leg["bones"] as PackedInt32Array)[2], leg["reach"])
	_wing_tips.resize(_wings.size())
	for i in _wings.size():
		var wing: Dictionary = _wings[i]
		_wing_tips[i] = _tip(skeleton, wing["bone"], wing["length"])
