class_name OctopusMotion
extends CreatureMotion

## How an octopus holds itself: sitting, ripples run slowly down its arms and
## round from one to the next, and faster when it crawls; swimming, it tips its
## mantle forward and pulses, its arms trailing behind, opening wide and snapping
## shut; caught, every arm flails to its own beat; spent, they hang; wrapped,
## each one coils up.
##
## An arm is four bones, each turning in its parent's space. The first one's
## parent is the body, so it curls about the axis across it that the body gives;
## every other one's is the bone before it, whose X is that same axis. A positive
## turn curls an arm down and under, a negative one up.

## How much each bone of an arm bends back to leave it straight, trailing, from
## the way it lies at rest: the difference between each one's droop and the one
## before's.
const STRAIGHTEN := [0.0, 43.0, 14.0, 16.0]

var _body: OctopusBody
var _trunk := -1
var _mantle := -1
var _arms: Array[Dictionary] = []
var _pulse := 0.0
var _crawl := 0.0
## How much it is going somewhere, crawling: none sitting still.
var _pace := 0.0

var _tips := PackedVector3Array()


func bind(skeleton: Skeleton3D, body: CreatureBody) -> void:
	_body = body as OctopusBody
	if _body == null:
		return
	_keep_rest(skeleton)
	_trunk = _find(skeleton, "Body")
	_mantle = _find(skeleton, "Mantle")
	_arms.clear()
	for i in 8:
		var bones := PackedInt32Array()
		for k in 4:
			bones.append(_find(skeleton, OctopusBody.arm_bone(i, k)))
		_arms.append({"bones": bones, "across": _body.arm_rest(i)["across"], "index": i})


## Where the end of every arm was drawn last frame, in the world: what it sits
## and crawls on, round from the front.
func feet() -> PackedVector3Array:
	return _tips


## The ends of its arms again, which are what it swims with.
func strokes() -> PackedVector3Array:
	return _tips


func _process_modification_with_delta(delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null or _body == null or _trunk < 0:
		return
	delta = clampf(delta, 0.0, 0.1)
	clock += delta
	_blend(delta)
	_pulse = fposmod(_pulse + _body.pulse_rate * (1.0 + clampf(speed * 0.1, 0.0, 1.0)) * delta, 1.0)
	_pace = move_toward(_pace, clampf(speed * 0.5, 0.0, 1.0), clampf(EASE * delta, 0.0, 1.0))
	_crawl = fposmod(_crawl + _body.ripple_rate * (0.3 + _pace) * delta, 1.0)

	_pose_body(skeleton)
	_pose_arms(skeleton)
	_record(skeleton)


## Tipped mantle-first to swim, bobbing as it crawls, wobbling when caught and
## sagging when spent; the mantle swelling with each pulse and breathing at rest.
func _pose_body(skeleton: Skeleton3D) -> void:
	var beat := sin(_pulse * TAU)
	_shift(skeleton, _trunk, Vector3.UP * (sin(_crawl * TAU * 2.0) * 0.03 * _walk * _pace))
	var roll := sin(clock * 7.0) * 0.2 * _thrash + 0.3 * _slack
	var yaw := sin(clock * 5.0) * 0.15 * _thrash
	_turn(skeleton, _trunk, Quaternion(Vector3.UP, yaw) * Quaternion(Vector3.BACK, roll)
		* Quaternion(Vector3.RIGHT, -1.0 * _air))
	var swell := beat * 0.1 * _air + sin(clock * 1.8) * 0.03 * (1.0 - _air - _curl) \
		+ sin(clock * 9.0) * 0.06 * _thrash
	skeleton.set_bone_pose_scale(_mantle, Vector3(1.0 - swell * 0.5, 1.0 + swell, 1.0 - swell * 0.5))


## Rippling as it sits and crawls, trailing and pulsing as it swims, flailing
## when caught, hanging when spent, coiled at the end.
func _pose_arms(skeleton: Skeleton3D) -> void:
	# Opening slowly, shutting fast: the pulse is a jet.
	var open := pow(0.5 + 0.5 * sin(_pulse * TAU), 1.5) * 2.0 - 1.0
	var ripple := 0.05 + 0.2 * _pace
	for arm in _arms:
		var bones: PackedInt32Array = arm["bones"]
		var i := float(arm["index"])
		for k in 4:
			var along := float(k)
			var wave := sin(_crawl * TAU - along * 0.9 + i * 0.785) * ripple * _walk
			var trail := deg_to_rad(STRAIGHTEN[k]) * _air
			var pulse := (-0.65 if k == 0 else 0.25) * open * _air
			var flail := sin(clock * (8.0 + i * 0.7) + along * 1.1 + i) * 1.0 * _thrash
			var hang := 0.25 * _slack
			var coil := (0.45 if k == 0 else -0.85) * _curl
			var bend := wave + trail + pulse + flail + hang + coil
			if k == 0:
				var sweep := sin(clock * 6.0 + i) * 0.4 * _thrash
				_turn(skeleton, bones[0], Quaternion(Vector3.UP, sweep)
					* Quaternion(arm["across"], bend))
			else:
				_turn(skeleton, bones[k], Quaternion(Vector3.RIGHT, bend))


func _record(skeleton: Skeleton3D) -> void:
	_tips.resize(_arms.size())
	var last := _body.arm * float(OctopusBody.PIECES[3])
	for i in _arms.size():
		_tips[i] = _tip(skeleton, (_arms[i]["bones"] as PackedInt32Array)[3], last)
