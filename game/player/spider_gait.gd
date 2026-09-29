class_name SpiderGait
extends SkeletonModifier3D

## Eight feet on whatever the spider is standing on, and the body riding on them.
##
## Runs inside the skeleton's own update, after everything else has had its say
## for the frame, so what it poses is what gets drawn. It owns every bone: the
## legs by inverse kinematics against footholds it finds in the world, and the
## body by small turns off its rest pose — bobbing, breathing, feeding, flinching.
##
## The legs walk in two sets of four, the tetrapod gait real spiders use — L1 R2
## L3 R4, then R1 L2 R3 L4 — so there are always four feet down and the body is
## never balanced on fewer than a tripod. A foot stays exactly where it was put in
## the world until the body has moved far enough off it, then lifts, swings, and
## lands a little ahead of where it will be wanted. That is what stops a walk
## sliding: nothing on the ground ever moves.
##
## Footholds are found by looking, not assumed. A spider has no floor, so a foot
## is put on whatever is under where it would rest — a wall, a ceiling, a thread —
## and in an inside corner the front feet land on the wall ahead before the body
## has turned to it, which is most of what makes climbing read as climbing.

enum Stance {
	GROUND,     ## stuck to something, walking or standing
	AIR,        ## falling or jumping
	HANGING,    ## on a dragline
	RIDING,     ## clipped onto a line and sliding
	GRAPPLING,  ## hauling itself somewhere on silk
}

## Seconds a step takes at a stroll. Quicker the faster the body goes, down to
## [member fastest_step] — a spiderling walks ten of its own lengths a second,
## and at that a real spider's legs are a blur.
@export var step_time := 0.12
@export var fastest_step := 0.016

## How far a foot travels in one step, in body heights: [member stride] at a
## stroll, [member stride_gain] more for every body height a second, up to
## [member longest_stride]. A foot lands half a stride ahead of where it rests and
## lifts again when it is half a stride behind — so the longest stride is what
## the shortest leg can still reach at both ends of.
@export var stride := 0.32
@export var stride_gain := 0.025
@export var longest_stride := 0.5

## How high a foot lifts at the top of a step, in body heights.
@export var step_lift := 0.14

# --- what the spider is doing, written every frame by [SpiderBody] ---------

var stance: Stance = Stance.GROUND

## How the body is moving through the world, in metres per second.
var velocity := Vector3.ZERO

## The line being hung from or ridden: its two ends, in the world.
var line_a := Vector3.ZERO
var line_b := Vector3.ZERO

## How far into winding a throw up, 0 to 1, and where the ball is being held.
var aim := 0.0
var ball := Vector3.ZERO

var feeding := false

## Which way a line on the spider pulls, in the world. Zero when nothing is towed.
var towing := Vector3.ZERO

## How far wings spread the legs in a fall, 0 to 1.
var spread := 0.0

## What footholds are looked for on, and what to leave out of the looking.
var mask := GameLayers.WORLD | GameLayers.WEB_WALK
var exclude: Array[RID] = []


class Leg:
	var label := ""
	var pair := 0
	var side := 1.0
	## Which of the two sets of four it walks with.
	var group := 0
	var bones := PackedInt32Array()
	var lengths := PackedFloat32Array()
	## Where it meets the body, in the thorax's own space.
	var hip := Vector3.ZERO
	## Where its foot rests on flat ground, and which way it points, in body space.
	var home := Vector3.ZERO
	var out := Vector3.ZERO
	## Where the foot is now, where it was last put down, and the surface under
	## it — all in the world.
	var foot := Vector3.ZERO
	var planted := Vector3.ZERO
	var ground_normal := Vector3.UP
	## Where it would like to be this frame, and whether that is on anything.
	var target := Vector3.ZERO
	var target_normal := Vector3.UP
	var grounded := false
	## Where the foot was actually drawn last frame, in the world — where the IK
	## got it to, which is short of [member foot] when that is out of reach.
	var tip := Vector3.ZERO
	## A foot with nothing to stand on is held in the body's own space rather
	## than the world's, so it comes along with a body that is falling or riding
	## instead of trailing behind it. [member free] says which kind it is now.
	var loose := Vector3.ZERO
	var free := false
	## How much of its length the leg needed last frame to reach its foot: one or
	## more means it could not, and was drawn short of it.
	var strain := 0.0
	var has_foot := false
	var stepping := false
	var step_t := 0.0
	var step_from := Vector3.ZERO

	func reach() -> float:
		var total := 0.0
		for length in lengths:
			total += length
		return total


var _legs: Array[Leg] = []
var _thorax := -1
var _head := -1
var _abdomen := -1
var _spinnerets := -1
var _jaws := PackedInt32Array()
var _fangs := PackedInt32Array()
var _palps := PackedInt32Array()
var _rest := {}
var _thorax_rest := Transform3D.IDENTITY

var _clock := 0.0
var _last_group := 1
var _still := 0.0
var _hurt := 0.0
var _landing := 0.0
var _feed := 0.0
var _was := Stance.GROUND
var _last_origin := Vector3.ZERO
var _has_origin := false
var _dip := 0.0

## How much faster the set in the air is landing than it otherwise would: more
## than one while a leg of the other set is at full stretch waiting for its turn.
var _hurry := 1.0


## Finds every bone this drives. Called once the skeleton is built.
func bind(skeleton: Skeleton3D) -> void:
	_legs.clear()
	_rest.clear()
	for bone in skeleton.get_bone_count():
		_rest[bone] = skeleton.get_bone_rest(bone)
	_thorax = skeleton.find_bone("Thorax")
	_head = skeleton.find_bone("Head")
	_abdomen = skeleton.find_bone("Abdomen")
	_spinnerets = skeleton.find_bone("Spinnerets")
	_thorax_rest = skeleton.get_bone_global_rest(_thorax)
	_jaws = PackedInt32Array([skeleton.find_bone("Chelicera.L"), skeleton.find_bone("Chelicera.R")])
	_fangs = PackedInt32Array([skeleton.find_bone("Fang.L"), skeleton.find_bone("Fang.R")])
	_palps = PackedInt32Array([skeleton.find_bone("Palp.L.1"), skeleton.find_bone("Palp.R.1"),
		skeleton.find_bone("Palp.L.2"), skeleton.find_bone("Palp.R.2")])
	for pair in SpiderRig.LEGS.size():
		var spec: Dictionary = SpiderRig.LEGS[pair]
		for s in 2:
			var leg := Leg.new()
			leg.pair = pair
			leg.side = -1.0 if s == 0 else 1.0
			leg.group = (pair + s) % 2
			leg.label = "Leg.%s%d" % [SpiderRig.SIDES[s], pair + 1]
			for part in ["Coxa", "Femur", "Tibia", "Tarsus"]:
				leg.bones.append(skeleton.find_bone("%s.%s" % [leg.label, part]))
			leg.lengths = PackedFloat32Array([SpiderRig.COXA, spec["femur"], spec["tibia"],
				spec["tarsus"]])
			leg.hip = _thorax_rest.affine_inverse() * SpiderRig.hip_of(pair, leg.side)
			leg.home = SpiderRig.home_of(pair, leg.side)
			leg.out = SpiderRig.outward(pair, leg.side)
			_legs.append(leg)
	reset_feet()


## Forgets where every foot was put, so the next frame sets them all down fresh.
## For a body that was moved rather than walked: grown, teleported, shown again.
func reset_feet() -> void:
	for leg in _legs:
		leg.has_foot = false
		leg.stepping = false
	_has_origin = false


## Something bit. The body jerks back and the legs pull in, and it passes.
func flinch(amount := 1.0) -> void:
	_hurt = clampf(maxf(_hurt, amount), 0.0, 1.0)


## How many feet are off the ground right now, mid-step.
func lifted() -> int:
	var count := 0
	for leg in _legs:
		if leg.stepping:
			count += 1
	return count


## Whether each leg is mid-step, in leg order — L1 R1 L2 R2 and so on.
func stepping() -> Array[bool]:
	var out: Array[bool] = []
	for leg in _legs:
		out.append(leg.stepping)
	return out


## Which set of four each leg walks with, in the same order.
func groups() -> PackedInt32Array:
	var out := PackedInt32Array()
	for leg in _legs:
		out.append(leg.group)
	return out


## Where each foot is planted, or on its way to, in the world.
func footholds() -> PackedVector3Array:
	var out := PackedVector3Array()
	for leg in _legs:
		out.append(leg.foot)
	return out


## Where each foot was actually drawn last frame, in the world.
##
## Kept here rather than read back off the skeleton, because it cannot be: the
## skeleton hands back its unmodified pose once the frame is drawn, so asking it
## where a foot is afterwards answers with the rest pose every time.
func drawn_feet() -> PackedVector3Array:
	var out := PackedVector3Array()
	for leg in _legs:
		out.append(leg.tip)
	return out


func _process_modification_with_delta(delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null or _legs.is_empty():
		return
	delta = clampf(delta, 0.0, 0.1)
	_clock += delta
	var world := skeleton.global_transform
	var unit := world.basis.get_scale().x
	if unit <= 0.00001:
		return
	var up := world.basis.y.normalized()
	# Moved further than any walk goes in a frame: it was put somewhere, so the
	# feet are put down fresh rather than dragged across the gap.
	if _has_origin and world.origin.distance_to(_last_origin) > unit * 2.5:
		reset_feet()
	_last_origin = world.origin
	_has_origin = true

	# Along the surface only. Falling onto a floor is not walking across it, and a
	# foot led by the fall was put down half a stride into the ground.
	var along := velocity - up * velocity.dot(up)
	var speed := along.length() / unit
	_hurt = maxf(0.0, _hurt - delta * 3.5)
	_landing = maxf(0.0, _landing - delta * 5.0)
	_feed = move_toward(_feed, 1.0 if feeding else 0.0, delta * 6.0)
	if stance == Stance.GROUND and _was == Stance.AIR:
		_landing = 1.0
	_was = stance
	_still = _still + delta if speed < 0.5 else 0.0

	_pose_body(skeleton, speed)
	var thorax := skeleton.get_bone_global_pose(_thorax)
	for leg in _legs:
		_aim_foot(leg, world, thorax, up, unit)
	_walk(delta, along, speed, unit, up, world, thorax)
	var into := world.affine_inverse()
	for leg in _legs:
		var foot := leg.foot
		if _hurt > 0.0:
			# Pulled in, off whatever it was standing on.
			foot = foot.lerp(world * (thorax * leg.hip), 0.35 * _hurt)
		_solve(skeleton, leg, into * foot, into.basis * leg.ground_normal, thorax)


# --- where the feet want to be ------------------------------------------

## Works out where [param leg]'s foot would like to be this frame.
func _aim_foot(leg: Leg, world: Transform3D, thorax: Transform3D, up: Vector3,
		unit: float) -> void:
	leg.grounded = false
	leg.target_normal = up
	var hip := world * (thorax * leg.hip)
	match stance:
		Stance.GROUND:
			_foothold(leg, world, hip, up, unit)
		Stance.AIR:
			# Legs out and a little up, feeling for anything: a falling spider
			# spreads itself wide, and wings spread it wider.
			var flail := sin(_clock * 9.0 + float(leg.pair) * 1.7 + leg.side) * 0.035
			leg.target = world * (leg.home + Vector3.UP * (0.3 + 0.1 * spread + flail)
				+ leg.out * (0.06 + 0.16 * spread))
		Stance.GRAPPLING:
			# Tucked, and the front pair reaching for where it is going.
			var tuck := SpiderRig.hip_of(leg.pair, leg.side) + leg.out * 0.34 + Vector3.DOWN * 0.1
			if leg.pair == 0:
				tuck = SpiderRig.hip_of(leg.pair, leg.side) + Vector3.FORWARD * 0.52 \
					+ leg.out * 0.14 + Vector3.UP * 0.06
			leg.target = world * tuck
		Stance.HANGING:
			# The body hangs with its back to the anchor, so up is up the line: the
			# front legs reach along it and the back ones hang out wide.
			var hang := SpiderRig.hip_of(leg.pair, leg.side) + leg.out * 0.28 + Vector3.UP * 0.55
			if leg.pair >= 2:
				hang = leg.home + Vector3.UP * 0.22 + leg.out * 0.1
			leg.target = world * hang
		Stance.RIDING:
			if leg.pair < 3:
				# Three pairs gripping the line overhead, like hands on a pulley.
				var reach_up := hip + up * unit * 0.5
				leg.target = Geometry3D.get_closest_point_to_segment(reach_up, line_a, line_b)
			else:
				leg.target = world * (leg.home + Vector3.UP * 0.15)
	# Winding a throw up: the front pair comes off the ground to hold the ball.
	if aim > 0.01 and leg.pair == 0:
		var hold := ball + world.basis.x.normalized() * leg.side * unit * 0.09
		leg.target = leg.target.lerp(hold, aim)
		if aim > 0.5:
			leg.grounded = false
	# Feeding: the front legs come in to hold the meal to the jaws.
	if _feed > 0.01 and leg.pair < 2:
		var grasp := world * Vector3(leg.side * (0.1 + 0.08 * leg.pair), SpiderRig.BODY_DROP - 0.2,
			-0.45 + 0.12 * leg.pair)
		leg.target = leg.target.lerp(grasp, _feed * (0.8 if leg.pair == 0 else 0.35))
		if leg.pair == 0 and _feed > 0.5:
			leg.grounded = false


## Looks for somewhere to put a foot: out from the hip first, so a wall beside or
## ahead is found before the floor under it, and then straight down the body.
func _foothold(leg: Leg, world: Transform3D, hip: Vector3, up: Vector3, unit: float) -> void:
	var home := world * leg.home
	var high := home + up * unit * 0.45
	var hit := _ray(hip, high)
	if hit.is_empty():
		hit = _ray(high, home - up * unit * 0.5)
	if hit.is_empty():
		leg.target = home
		return
	var normal: Vector3 = hit.get("normal", up)
	leg.target = hit["position"] + normal * unit * 0.012
	leg.target_normal = normal.normalized() if normal.length_squared() > 0.000001 else up
	leg.grounded = true


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var skeleton := get_skeleton()
	if skeleton == null or not skeleton.is_inside_tree():
		return {}
	var query := PhysicsRayQueryParameters3D.create(from, to, mask, exclude)
	return skeleton.get_world_3d().direct_space_state.intersect_ray(query)


# --- the walk -------------------------------------------------------------

func _walk(delta: float, along: Vector3, speed: float, unit: float, up: Vector3,
		world: Transform3D, thorax: Transform3D) -> void:
	for leg in _legs:
		if not leg.has_foot:
			leg.foot = leg.target
			leg.planted = leg.target
			leg.ground_normal = leg.target_normal
			leg.has_foot = true
			leg.stepping = false

	var into := world.affine_inverse()
	if stance != Stance.GROUND:
		# Nothing to plant on: every foot goes where the pose puts it, and gets
		# there quickly rather than at once, so a jump or a grab reads as a move.
		for leg in _legs:
			leg.stepping = false
			_swing_loose(leg, delta, 16.0, world, into)
		return

	# One set steps while the other stands, so a step has to be over in well under
	# the time the body takes to cover half a stride — or the standing set is
	# left behind at full stretch before its turn comes round.
	var reach := clampf(stride + speed * stride_gain, stride, longest_stride)
	var duration := clampf(0.32 * reach / maxf(speed, 0.001), fastest_step, step_time)
	# Half a stride ahead of where the foot rests. Only that: the rest position is
	# worked out afresh every frame of the step, so the ground the body covers
	# while the foot is in the air is already in it, and adding it again put the
	# front feet down past where the legs could reach.
	var lead := Vector3.ZERO
	if speed > 0.3:
		lead = along.normalized() * reach * 0.5 * unit

	for leg in _legs:
		if not leg.grounded:
			# Nothing under it — over an edge, or held up for something. The foot
			# goes where it is wanted and is put down properly once there is
			# something to put it on.
			leg.stepping = false
			_swing_loose(leg, delta, 18.0, world, into)
			continue
		leg.free = false
		if not leg.stepping:
			continue
		leg.step_t += delta / duration * _hurry
		var land := leg.target + lead
		if leg.step_t >= 1.0:
			leg.stepping = false
			leg.planted = land
			leg.foot = land
			leg.ground_normal = leg.target_normal
			continue
		var t := smoothstep(0.0, 1.0, leg.step_t)
		var arc := sin(PI * leg.step_t) * (step_lift + minf(speed * 0.012, 0.12)) * unit
		leg.foot = leg.step_from.lerp(land, t) + up * arc
		leg.ground_normal = leg.ground_normal.slerp(leg.target_normal, t).normalized()

	# Whose turn. One set is up at a time; the set that went last goes second.
	var busy := [false, false]
	for leg in _legs:
		if leg.stepping:
			busy[leg.group] = true
	for g in [1 - _last_group, _last_group]:
		if busy[1 - g] or busy[g]:
			continue
		var went := false
		for leg in _legs:
			if leg.group != g or leg.stepping or not leg.grounded:
				continue
			var off := leg.planted.distance_to(leg.target) / unit
			var settle := _still > 0.25 and off > 0.06
			if off > reach * 0.5 or settle:
				_lift_foot(leg)
				went = true
		if went:
			_last_group = g
			break

	# A foot left so far behind that the leg cannot reach it goes as soon as its
	# set may — never while the other set is up, because four feet down is the one
	# rule the gait does not bend. Until then the leg is simply at full stretch.
	# And the set in the air hurries down, so the wait is as short as it can be.
	busy = [false, false]
	for leg in _legs:
		if leg.stepping:
			busy[leg.group] = true
	_hurry = 1.0
	for leg in _legs:
		if leg.stepping or not leg.grounded:
			continue
		var stretched := leg.strain > 0.98
		if stretched and not busy[1 - leg.group]:
			_lift_foot(leg)
			busy[leg.group] = true
		else:
			if stretched:
				_hurry = 2.5
			leg.foot = leg.planted


## Eases a foot with nothing under it toward where it is wanted, in the body's
## own space — see [member Leg.loose].
func _swing_loose(leg: Leg, delta: float, rate: float, world: Transform3D,
		into: Transform3D) -> void:
	if not leg.free:
		leg.loose = into * leg.foot
		leg.free = true
	var ease := 1.0 - exp(-delta * rate)
	leg.loose = leg.loose.lerp(into * leg.target, ease)
	leg.foot = world * leg.loose
	leg.planted = leg.foot
	leg.ground_normal = leg.ground_normal.slerp(leg.target_normal, ease).normalized()


func _lift_foot(leg: Leg) -> void:
	leg.stepping = true
	leg.step_t = 0.0
	leg.step_from = leg.foot


# --- the body -------------------------------------------------------------

## Everything that is not a leg: small turns off the rest pose, layered.
func _pose_body(skeleton: Skeleton3D, speed: float) -> void:
	var moving := clampf(speed / 3.0, 0.0, 1.0)
	# The body dips a little while a set of legs is in the air, and more on
	# landing; it sinks toward a meal and rears back from a bite.
	var lifted_share := float(lifted()) / 4.0
	_dip = lerpf(_dip, lifted_share * moving, 0.35)
	var drop := -0.014 * _dip - 0.06 * _landing - 0.05 * _feed + 0.025 * _hurt
	var pitch := deg_to_rad(6.0 * aim - 9.0 * _feed + 18.0 * _hurt)
	var sway := sin(_clock * 17.0) * 0.012 * moving
	var thorax := Transform3D(Basis.from_euler(Vector3(pitch, 0.0, sway)),
		_thorax_rest.origin + Vector3(0.0, drop, 0.03 * _hurt))
	skeleton.set_bone_pose(_thorax, thorax)

	# The abdomen breathes, lifts its spinnerets toward a throw, and swings round
	# to whatever is on the line.
	var rest: Transform3D = _rest[_abdomen]
	var breath := 1.0 + sin(_clock * TAU * 0.7) * 0.022
	var lift := deg_to_rad(-34.0 * aim + 8.0 * _hurt - 6.0 * moving)
	var yaw := 0.0
	if towing.length_squared() > 0.000001:
		var world_basis := skeleton.global_transform.basis.orthonormalized()
		var local := (world_basis * thorax.basis).inverse() * towing.normalized()
		# Round from pointing straight back toward where the line is.
		yaw = clampf(atan2(local.x, local.z), -0.5, 0.5)
		lift += clampf(-local.y * 0.6, -0.3, 0.3)
	var turn := Basis(Vector3.UP, yaw) * rest.basis * Basis(Vector3.RIGHT, lift)
	skeleton.set_bone_pose(_abdomen, Transform3D(turn.scaled_local(Vector3(breath, 1.0 + (breath - 1.0) * 0.5, breath)),
		rest.origin))

	var spin: Transform3D = _rest[_spinnerets]
	skeleton.set_bone_pose(_spinnerets, Transform3D(
		spin.basis * Basis(Vector3.RIGHT, sin(_clock * 13.0) * 0.35 * aim), spin.origin))

	var head: Transform3D = _rest[_head]
	skeleton.set_bone_pose(_head, Transform3D(
		head.basis * Basis(Vector3.RIGHT, deg_to_rad(5.0 * aim - 6.0 * _feed)), head.origin))

	# Jaws: shut and still, a twitch now and then, working hard on a meal.
	var chew := (0.5 + 0.5 * sin(_clock * 11.0)) * _feed
	var twitch := maxf(sin(_clock * 0.9) - 0.96, 0.0) * 6.0
	for i in 2:
		var jaw: Transform3D = _rest[_jaws[i]]
		var side := -1.0 if i == 0 else 1.0
		skeleton.set_bone_pose(_jaws[i], Transform3D(
			jaw.basis * Basis(Vector3.RIGHT, -0.4 * chew - 0.12 * aim - 0.1 * twitch), jaw.origin))
		var fang: Transform3D = _rest[_fangs[i]]
		skeleton.set_bone_pose(_fangs[i], Transform3D(
			fang.basis * Basis(Vector3.BACK, side * (0.5 * chew + 0.15 * twitch)), fang.origin))

	# Pedipalps feel the ground as it walks and drum on a meal.
	for i in 4:
		var palp: Transform3D = _rest[_palps[i]]
		var side := -1.0 if i % 2 == 0 else 1.0
		var feel := sin(_clock * (10.0 if moving > 0.1 else 1.6) + side * 1.5) \
			* lerpf(0.1, 0.3, moving)
		var drum := sin(_clock * 15.0 + side) * 0.35 * _feed
		skeleton.set_bone_pose(_palps[i], Transform3D(
			palp.basis * Basis(Vector3.RIGHT, feel + drum - 0.2 * aim), palp.origin))


# --- the legs -------------------------------------------------------------

## Puts [param leg]'s four bones where they need to be for its foot to be at
## [param foot], everything in skeleton space.
##
## The coxa turns the leg about the hip to face the foot. The tarsus comes down
## onto the surface at a slant, and the femur and tibia between them are the
## classic two-bone solve, bent so the knee rides high above the body — which is
## the silhouette that says spider rather than table.
func _solve(skeleton: Skeleton3D, leg: Leg, foot: Vector3, surface: Vector3,
		thorax: Transform3D) -> void:
	var up := thorax.basis.y.normalized()
	var hip := thorax * leg.hip
	var rest_out := (thorax.basis * leg.out).normalized()
	var flat := foot - hip
	flat -= up * flat.dot(up)
	var out := rest_out
	if flat.length_squared() > 0.000001:
		out = flat.normalized()
		# Never swung round across the body, or back past its neighbours.
		var turn := clampf(rest_out.signed_angle_to(out, up), -1.1, 1.1)
		out = rest_out.rotated(up, turn)
	var normal := out.cross(up).normalized()

	var coxa_dir := (out - up * 0.15).normalized()
	var knee_base := hip + coxa_dir * leg.lengths[0]
	var down := -surface.normalized() if surface.length_squared() > 0.000001 else -up
	var tarsus_dir := (down * 0.88 + out * 0.48).normalized()
	var ankle := foot - tarsus_dir * leg.lengths[3]

	var a := leg.lengths[1]
	var b := leg.lengths[2]
	# Near full stretch the tarsus gives up its slant and lines up with the rest
	# of the leg, which is how a real one reaches: the last few percent of a leg's
	# length only exist straight.
	var strain := (ankle - knee_base).length() / (a + b)
	if strain > 0.85:
		var straight := (foot - knee_base).normalized()
		tarsus_dir = tarsus_dir.lerp(straight, clampf((strain - 0.85) / 0.15, 0.0, 1.0)).normalized()
		ankle = foot - tarsus_dir * leg.lengths[3]
		strain = (ankle - knee_base).length() / (a + b)
	leg.strain = strain
	var span := ankle - knee_base
	var reach := span.length()
	var toward := span / reach if reach > 0.00001 else out
	var d := clampf(reach, absf(a - b) + 0.001, a + b - 0.001)
	var cos_a := clampf((a * a + d * d - b * b) / (2.0 * a * d), -1.0, 1.0)
	var pole := (up * 0.96 + out * 0.2).normalized()
	var bend := pole - toward * pole.dot(toward)
	bend = bend.normalized() if bend.length_squared() > 0.000001 else up
	var femur_dir := toward * cos_a + bend * sqrt(maxf(1.0 - cos_a * cos_a, 0.0))
	var knee := knee_base + femur_dir * a
	var tibia_dir := (knee_base + toward * d - knee).normalized()
	var heel := knee + tibia_dir * b
	var last := foot - heel
	var tarsus_final := last.normalized() if last.length_squared() > 0.000001 else tarsus_dir

	skeleton.set_bone_global_pose(leg.bones[0], Transform3D(SpiderRig.along(coxa_dir, normal), hip))
	skeleton.set_bone_global_pose(leg.bones[1],
		Transform3D(SpiderRig.along(femur_dir, normal), knee_base))
	skeleton.set_bone_global_pose(leg.bones[2], Transform3D(SpiderRig.along(tibia_dir, normal), knee))
	skeleton.set_bone_global_pose(leg.bones[3],
		Transform3D(SpiderRig.along(tarsus_final, normal), heel))
	leg.tip = skeleton.global_transform * (heel + tarsus_final * leg.lengths[3])
