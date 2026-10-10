class_name Weaver
extends CharacterBody3D

## The spider.
##
## Fast, and on the ground. It runs, it jumps, and it does not climb: walls and
## ceilings are not floors any more. What it has instead are three things, each on
## a button of its own and all three usable at once:
##
## * **Grapple** (left mouse) — a line to a web you point at, and you are pulled
##   along it onto the web. Only silk holds it. See [Grapple]. One in the air, back
##   when you land — on the ground or a web that has stuck. A web still flying you
##   ride, all the way: no getting off, and nothing back until it lands.
## * **Silk** (right mouse) — hold to wind it up, let go to throw a web. The web
##   flies; grapple onto it in flight and you ride it to wherever it lands, where
##   it sticks, flat, and the spider can walk on it — up a wall, across a
##   ceiling. See [SilkCaster] and [ThrownWeb].
## * **Pullback** (E, or the middle mouse button) — your oldest web flies home,
##   putting down what it held at your feet. See [Pullback].
##
## Silk is a few webs, no more: a level says how many. A web the spider has stood
## on is used up the moment it leaves it — it comes apart, and its silk is back at
## once — so moving on never runs the silk out. The Pullback is for webs you have
## not stood on: the ones holding something, and the ones set up for later.
##
## A web is springy: jumping off one goes [constant WEB_SPRING] times as hard as a
## jump off the ground.
##
## A web that catches a fly holds it in the air, and reaching it — grappling to it,
## or riding a web into it — takes the fly, gives back the web and the grapple,
## and leaves the spider strung up in the air for [constant HANG] seconds, spread
## out on a frame of silk like a hide stretched to dry. Space cuts it down early.
##
## The camera is the old game's rig, unchanged: see [SpiderCamera].

## Something worth putting on screen happened.
signal notice(text: String)

## A throw found no silk left to throw.
signal out_of_silk()

## Landed, on the ground or on a web: the grapple is back.
signal landed()

enum Mode {
	GROUND,   ## running on a floor
	AIR,      ## jumping or falling
	WEB,      ## on a web stuck to a surface
	GRAPPLE,  ## being pulled along a line
	HUNG,     ## strung up in the air, where it took a fly
}

## How tall the spider is, in metres: a Huntsman.
const HEIGHT := 0.7

## Its collider, a ball.
const RADIUS := 0.3

## The old spider's movement, a Huntsman's, number for number — except that it
## always goes at what was the old spider's sprint.
##
## How fast it goes on its own legs: the old walk (3.8 m/s) times the old sprint
## (1.6).
const WALK := 6.08

## How quickly it gets up to speed, and how quickly it stops, as how much of the
## way there it goes each second: eased in, never snapped.
const ACCEL := 14.0
const DECEL := 18.0

## How quickly speed above a walk bleeds off while the keys go along with it: what a
## grapple gave you is a skid you can use, not something gone in a frame.
const SKID_DAMP := 1.6

## How fast it walks on a web, sprinting as on the ground: the old 4.6 m/s times
## 1.6. A little quicker than the ground.
const WEB_WALK := 7.36

## The old controller's fall — the default gravity three times over — and jump.
const GRAVITY := 29.4
const JUMP := 7.8
const MAX_FALL := 40.0

## How much of the way to where the keys point the air steers each second.
const AIR_STEER := 4.2

## Seconds after running off an edge that a jump still goes, and before landing
## that a jump pressed early still counts.
const COYOTE := 0.12
const BUFFER := 0.14

## Seconds after leaving a web before that web can be landed on again.
const WEB_GRACE := 0.3

## How much harder a jump off a web goes than one off the ground.
const WEB_SPRING := 1.3

## How long throwing a web in the air holds the spider up, and how much of its
## speed is left after the first frame of it: a beat to see where the web goes,
## and to grapple onto it.
const THROW_STALL := 0.4
const STALL_KEEP := 0.15

## How long the spider hangs strung up where it took a fly, and how big the frame
## of silk it hangs in is, across and up.
const HANG := 2.0
const FRAME := Vector2(2.2, 2.4)

## Falling below this puts the spider back at the start.
var kill_y := -30.0

## How many webs it may have out at once.
var max_webs := 2

## Ignore the keys while the mouse is free. Off for headless checks.
var require_captured_mouse := true

var mode := Mode.AIR

## Whether a grapple is ready.
var grapple_ready := true

## Whether the player has done anything yet since the spider was put down: moved,
## jumped, thrown, grappled or called a web home. The level's clock waits for it.
var acted := false



var view: SpiderCamera
var grapple: Grapple
var caster: SilkCaster
var pullback: Pullback
var body: WeaverBody

## Where webs and what they make go; the level, usually.
var container: Node = null

var _webs: Array[ThrownWeb] = []
var _coyote := 0.0
var _buffer := 0.0
var _jump_held := false
var _input_axis := Vector2.ZERO


var _web: ThrownWeb = null
var _web_at := Vector2.ZERO          # where on it, in its own plane
var _web_side := 1.0                 # which face
var _web_walk := Vector2.ZERO        # walking speed on it, in its own plane
var _web_airborne := false           # whether it is still flying, carrying the spider
var _web_turned := 0                 # its face's turns, to know when it sticks askew
var _grace_web: ThrownWeb = null
var _grace := 0.0
## The web the spider stood on last frame: left, it is used up.
var _stood_on: ThrownWeb = null
var _last_position := Vector3.ZERO
var _moving := Vector3.ZERO

var _grapple_time := 0.0
## Seconds left of being held up by a throw: see [method hang_after_throw].
var _stall := 0.0
## Whether this time in the air has had its hang from a throw: one, until the
## spider lands — or throw, call home, throw would hold it up for ever.
var _throw_hang_spent := false
## Seconds left strung up, and the frame of silk it hangs in.
var _hang := 0.0
var _frame: Node3D = null


var _facing := Vector3.FORWARD
var _up := Vector3.UP
var _base_fov := 0.0


func _init() -> void:
	collision_layer = GameLayers.PLAYER
	collision_mask = GameLayers.WORLD
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.35
	platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_ADD_VELOCITY
	safe_margin = 0.01


func _ready() -> void:
	add_to_group("weaver")
	var shape := CollisionShape3D.new()
	shape.name = "Collision"
	var ball := SphereShape3D.new()
	ball.radius = RADIUS
	shape.shape = ball
	add_child(shape)

	view = SpiderCamera.new()
	view.name = "View"
	add_child(view)
	view.setup(self, null)
	view.face(-global_basis.z)

	grapple = Grapple.new()
	grapple.name = "Grapple"
	add_child(grapple)
	grapple.setup(self, view)
	caster = SilkCaster.new()
	caster.name = "Silk"
	add_child(caster)
	caster.setup(self, view)
	pullback = Pullback.new()
	pullback.name = "Pullback"
	add_child(pullback)
	pullback.setup(self)
	body = WeaverBody.new()
	body.name = "Body"
	add_child(body)
	body.setup(self)
	_facing = -global_basis.z
	_last_position = global_position


# --- the keys --------------------------------------------------------------

## Whether keys reach the spider at all.
func accepts_input() -> bool:
	return not require_captured_mouse or Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if not accepts_input():
		return
	if event is InputEventMouseMotion:
		view.look((event as InputEventMouseMotion).relative)
		return
	if event.is_action_pressed("grapple"):
		fire_grapple()
	elif event.is_action_pressed("silk"):
		caster.begin()
	elif event.is_action_released("silk"):
		caster.release()
	elif event.is_action_pressed("pullback"):
		pullback.cast()
	elif event.is_action_pressed("toggle_camera"):
		view.toggle_mode()
	else:
		return
	get_viewport().set_input_as_handled()


func _read_keys(delta: float) -> void:
	_buffer = maxf(0.0, _buffer - delta)
	if not accepts_input():
		_input_axis = Vector2.ZERO
		_jump_held = false
		# A wind-up whose key-up was lost with the mouse is put away, not thrown.
		if caster.charging and require_captured_mouse:
			caster.cancel()
		return
	_input_axis = Input.get_vector("move_left", "move_right", "move_backward", "move_forward")
	if Input.is_action_just_pressed("move_jump"):
		_buffer = BUFFER
	_jump_held = Input.is_action_pressed("move_jump")
	# A wind-up with its key no longer down is let go, in case the key-up was lost.
	if caster.charging and not Input.is_action_pressed("silk") and require_captured_mouse:
		caster.release()


## For a check, or anything else driving the spider without keys: hold
## [param axis] on the movement keys, and press jump if [param jump].
func drive(axis: Vector2, jump := false) -> void:
	_input_axis = axis
	if jump:
		_buffer = BUFFER


# --- every frame -----------------------------------------------------------

func _physics_process(delta: float) -> void:
	if require_captured_mouse:
		_read_keys(delta)
	else:
		_buffer = maxf(0.0, _buffer - delta)
	_grace = maxf(0.0, _grace - delta)
	if _input_axis != Vector2.ZERO or _buffer > 0.0:
		acted = true
	view.update(HEIGHT, global_basis.y)
	match mode:
		Mode.GROUND:
			_step_ground(delta)
		Mode.AIR:
			_step_air(delta)
		Mode.WEB:
			_step_web(delta)
		Mode.GRAPPLE:
			_step_grapple(delta)
		Mode.HUNG:
			_step_hung(delta)
	_use_up_left_web()
	_moving = (global_position - _last_position) / maxf(delta, 0.0001)
	_last_position = global_position
	_orient(delta)
	view.update(HEIGHT, global_basis.y)


func _process(delta: float) -> void:
	view.update(HEIGHT, global_basis.y)
	_rush(delta)
	if body != null:
		body.visible = view.third_person
		body.animate(delta)


## How the spider is actually moving through the world, whatever it is on.
func moving_velocity() -> Vector3:
	return _moving


## Opens the view up with speed, and with a throw being wound up.
func _rush(delta: float) -> void:
	var camera := view.camera
	if camera == null:
		return
	if _base_fov <= 0.0:
		_base_fov = camera.fov
	var rush := clampf(_moving.length() / (WALK * 3.0) - 0.25, 0.0, 1.0)
	var aiming := clampf(view.aim_blend, 0.0, 1.0) * view.aim_fov_gain
	camera.fov = lerpf(camera.fov, _base_fov + rush * 16.0 + aiming,
		clampf(delta * 6.0, 0.0, 1.0))


# --- on the ground -----------------------------------------------------------

func _step_ground(delta: float) -> void:
	_up = Vector3.UP
	up_direction = Vector3.UP
	var wish := _wish_flat()
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	flat = _run_toward(flat, wish, WALK, delta)
	velocity.x = flat.x
	velocity.z = flat.z
	velocity.y -= GRAVITY * delta
	if _buffer > 0.0:
		_jump()
		return
	# Walking into a web on a wall takes you up onto it.
	if wish != Vector3.ZERO and _step_onto_web(wish):
		return
	move_and_slide()
	if is_on_floor():
		_coyote = COYOTE
		_land()
	else:
		_set_mode(Mode.AIR)


## [param flat] eased toward [param wish] at [param top] speed, the old spider's
## way: above the top speed, going the way the keys go, it skids rather than
## stopping dead; otherwise it is eased in, and eased harder to a stop.
func _run_toward(flat: Vector3, wish: Vector3, top: float, delta: float) -> Vector3:
	var target := wish * top
	var with_skid := wish != Vector3.ZERO and flat.length() > top \
		and wish.dot(flat.normalized()) > 0.7
	if with_skid:
		return flat.lerp(target, clampf(SKID_DAMP * delta, 0.0, 1.0))
	var rate := ACCEL if target.dot(flat) > 0.0 else DECEL
	return flat.lerp(target, clampf(rate * delta, 0.0, 1.0))


func _jump() -> void:
	_buffer = 0.0
	_coyote = 0.0
	# Whatever it was carrying goes with it, and half a step more the way the keys go.
	var wish := _wish_flat()
	velocity += wish * WALK * 0.5
	velocity.y = JUMP
	_set_mode(Mode.AIR)
	move_and_slide()


## The keys, as a direction on the level ground, from where the camera looks.
func _wish_flat() -> Vector3:
	if _input_axis == Vector2.ZERO:
		return Vector3.ZERO
	var forward := view.forward()
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		forward = -view.up()
		forward.y = 0.0
	forward = forward.normalized()
	var right := forward.cross(Vector3.UP).normalized()
	var wish := forward * _input_axis.y + right * _input_axis.x
	return wish.normalized() if wish.length_squared() > 0.0001 else Vector3.ZERO


func _land() -> void:
	if mode != Mode.GROUND:
		_set_mode(Mode.GROUND)
	_refill()


## Stood on something that stays put: the grapple is back, and so are the hangs.
func _refill() -> void:
	_throw_hang_spent = false
	if not grapple_ready:
		grapple_ready = true
		landed.emit()


# --- in the air --------------------------------------------------------------

func _step_air(delta: float) -> void:
	_up = Vector3.UP
	up_direction = Vector3.UP
	_coyote = maxf(0.0, _coyote - delta)
	if _buffer > 0.0 and _coyote > 0.0:
		_jump()
		return
	if _stall > 0.0:
		# Held up by a throw: no fall, and the way you were going dying away, for
		# a moment to aim in.
		_stall -= delta
		velocity = velocity.lerp(Vector3.ZERO, clampf(delta * 18.0, 0.0, 1.0))
		if _catch_web(velocity * delta):
			_stall = 0.0
			return
		move_and_slide()
		if is_on_floor():
			_stall = 0.0
			_land()
		return
	velocity.y = maxf(velocity.y - GRAVITY * delta, -MAX_FALL)
	var wish := _wish_flat()
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	flat = flat.lerp(wish * WALK, clampf(AIR_STEER * delta, 0.0, 1.0))
	velocity.x = flat.x
	velocity.z = flat.z
	if _catch_web(velocity * delta):
		return
	move_and_slide()
	if is_on_floor():
		_land()
	_check_fall()


func _check_fall() -> void:
	if global_position.y < kill_y:
		fell.emit()


## Fell out of the level.
signal fell()


# --- on a web ----------------------------------------------------------------

## The web the spider is on, if it is on one.
func standing_web() -> ThrownWeb:
	return _web if mode == Mode.WEB and is_instance_valid(_web) else null


## Takes hold of [param web] where the spider is, on whichever face it is nearer —
## or the other, where that one has no room. The spider stays on that face: a web is
## walked on one side only, and its rim holds you.
func attach_to_web(web: ThrownWeb, at := Vector3.INF) -> void:
	if web != null and web.holds_fly():
		reach_fly(web)
		return
	if web == null or not (web.holds_weight() or web.is_flying()):
		return
	if mode == Mode.GRAPPLE:
		grapple.end()
	var where := global_position if at == Vector3.INF else at
	var local := web.to_local(where)
	_web = web
	_web_at = Vector2(local.x, local.y)
	_pick_face(web.to_local(global_position).z)
	_web_at = Vector2(local.x, local.y).limit_length(maxf(web.current_radius() - 0.2, 0.05))
	var carried := web.global_basis.inverse() * velocity
	_web_walk = Vector2(carried.x, carried.y).limit_length(WEB_WALK)
	_web_turned = web.turned
	_web_airborne = web.is_flying()
	velocity = Vector3.ZERO
	_set_mode(Mode.WEB)
	# A web in flight is a ride, and a ride is a commitment: it gives nothing back.
	# The grapple comes back when the web lands and the spider with it.
	if not _web_airborne:
		_refill()
	_place_on_web()


func _step_web(delta: float) -> void:
	if _web == null or not is_instance_valid(_web) or not _web.is_standing():
		# A web ridden out of reach, or onto slick, stopped dead first: the rider is
		# left where it was. Anything else that comes apart underfoot leaves you
		# with its speed.
		var stood := _web != null and is_instance_valid(_web) and _web.stalled
		_web = null
		velocity = Vector3.ZERO if stood else _moving
		_set_mode(Mode.AIR)
		return
	if _web_airborne and not _web.is_flying():
		if _web.holds_fly():
			# The ride caught a fly: the spider is there, and takes it.
			reach_fly(_web)
			return
		if not _web.holds_weight():
			# The ride stuck to a loose board, which won't hold the spider: off it.
			_web = null
			velocity = Vector3.ZERO
			_set_mode(Mode.AIR)
			return
		# The web being ridden has landed: so has the spider.
		_refill()
	_web_airborne = _web.is_flying()
	if _web.turned != _web_turned:
		# The web turned under us as it stuck: find our footing on its new face.
		_web_turned = _web.turned
		var local := _web.to_local(global_position)
		_web_at = Vector2(local.x, local.y)
		_pick_face(local.z)
	_up = _web.normal() * _web_side
	if _buffer > 0.0:
		if _web.is_flying():
			# No getting off a ride: the spider goes where the web goes.
			_buffer = 0.0
		else:
			_jump_off_web()
			return
	var basis := _web.global_basis.orthonormalized()
	var wish := _wish_on(_up)
	var wish_local := basis.inverse() * wish
	var wish_2d := Vector2(wish_local.x, wish_local.y)
	if wish_2d.length_squared() > 0.0001:
		wish_2d = wish_2d.normalized()
	var rate := ACCEL if wish_2d.dot(_web_walk) >= 0.0 else DECEL
	_web_walk = _web_walk.lerp(wish_2d * WEB_WALK, clampf(rate * delta, 0.0, 1.0))
	var next := _web_at + _web_walk * delta
	var limit := maxf(_web.current_radius() - 0.22, 0.05)
	if next.length() > limit:
		var outward_2d := next.normalized()
		var outward := (basis * Vector3(outward_2d.x, outward_2d.y, 0.0)).normalized()
		# Off a web onto what is past its rim — but not off one in flight.
		if wish_2d.dot(outward_2d) > 0.25 and not _web.is_flying() and _step_off_web(outward):
			return
		next = next.limit_length(limit)
		_web_walk -= outward_2d * maxf(_web_walk.dot(outward_2d), 0.0)
	# Nothing walks the spider into something solid: the web may run on past what it
	# is on, or under the lip of it, but the spider stops at it — or steps off onto it,
	# where it is a floor.
	var lift := ThrownWeb.THICKNESS * 0.5 + RADIUS * 0.95
	var there := _web.to_global(Vector3(next.x, next.y, _web_side * lift))
	if next != _web_at and _blocked(there):
		var going := (there - global_position).normalized()
		var space := get_world_3d().direct_space_state
		var ahead := space.intersect_ray(PhysicsRayQueryParameters3D.create(global_position,
			global_position + going * 0.9, GameLayers.WORLD, [get_rid()]))
		if not ahead.is_empty() and (ahead["normal"] as Vector3).y > 0.6:
			# Walked down a web on a wall into the floor it stands on: onto the floor.
			_onto_floor(ahead)
			return
		next = _web_at
		_web_walk = Vector2.ZERO
	_web_at = next
	_place_on_web()


## Settles which face of [member _web] the spider is on: the side of its plane
## [param depth] says, unless that face has no room at [member _web_at] and the other
## has — a web flat on a wall has no room behind it, whatever side of its plane the
## spider happened to reach it from.
func _pick_face(depth: float) -> void:
	_web_side = 1.0 if depth >= 0.0 else -1.0
	var local := Vector3(_web_at.x, _web_at.y, 0.0)
	if _face_blocked(_web, local, _web_side) and not _face_blocked(_web, local, -_web_side):
		_web_side = -_web_side


## Whether the spider standing at [param local] on face [param side] of
## [param web] would be inside something.
func _face_blocked(web: ThrownWeb, local: Vector3, side: float) -> bool:
	var lift := ThrownWeb.THICKNESS * 0.5 + RADIUS * 0.95
	return _blocked(web.to_global(Vector3(local.x, local.y, side * lift)))


func _place_on_web() -> void:
	var lift := ThrownWeb.THICKNESS * 0.5 + RADIUS * 0.95
	global_position = _web.to_global(Vector3(_web_at.x, _web_at.y, _web_side * lift))


## The keys, as a direction along a surface facing [param up]: the camera's
## forward laid onto it, or, looking straight at it, the top of the screen.
func _wish_on(up: Vector3) -> Vector3:
	if _input_axis == Vector2.ZERO:
		return Vector3.ZERO
	var look := view.forward()
	var forward := look - up * look.dot(up)
	if forward.length_squared() < 0.04:
		var top := view.up() * (-signf(look.dot(up)) if look.dot(up) != 0.0 else 1.0)
		forward = top - up * top.dot(up)
	if forward.length_squared() < 0.000001:
		return Vector3.ZERO
	forward = forward.normalized()
	var right := forward.cross(up).normalized()
	var wish := forward * _input_axis.y + right * _input_axis.x
	return wish.normalized() if wish.length_squared() > 0.0001 else Vector3.ZERO


func _jump_off_web() -> void:
	_buffer = 0.0
	var push := (_up * JUMP * 0.75 + Vector3.UP * JUMP * 0.55) * WEB_SPRING
	if _up.y > 0.7:
		push = _up * JUMP * WEB_SPRING
	var walk := _web.global_basis * Vector3(_web_walk.x, _web_walk.y, 0.0)
	_grace_web = _web
	_grace = WEB_GRACE
	_web = null
	velocity = walk + push
	_set_mode(Mode.AIR)


## A web the spider was on and is not now has been left, however — jumped off,
## walked off, pulled away from, dropped from: it comes apart where it is, and its
## silk is the spider's again. Not one that has come apart already or is on its way
## home, and not one on a loose board, which the spider never stood on: it rode
## there and fell off, and that web is still wanted, to rip the board away.
func _use_up_left_web() -> void:
	var now := standing_web()
	var left := _stood_on
	_stood_on = now
	if left == null or left == now or not is_instance_valid(left):
		return
	if left.is_stuck() and left.holds_weight():
		left.spend()


## Off the rim of a web, going [param outward]: onto a floor there, or another web.
## False if there is nothing there to go to, and the rim holds the spider back.
func _step_off_web(outward: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = [get_rid(), _web.walk_body().get_rid()]
	var here := global_position
	# Another web just past the rim.
	var reach := PhysicsRayQueryParameters3D.create(here, here + outward * 0.9,
		GameLayers.WORLD | GameLayers.WEB_WALK, exclude)
	var ahead := space.intersect_ray(reach)
	if not ahead.is_empty():
		var other := ThrownWeb.of(ahead.get("collider"))
		if other != null and other.holds_weight():
			var leaving := _web
			attach_to_web(other, ahead["position"])
			_grace_web = leaving
			_grace = 0.1
			return true
		if (ahead["normal"] as Vector3).y > 0.6:
			return _onto_floor(ahead)
	# A floor past the rim: down from a little beyond it, and from over the top of
	# whatever the web is on, so a web near the top of a wall lets you over.
	for start in [here + outward * 0.6 + _up * 0.3, here + outward * 0.7 - _up * 0.7,
			here + outward * 1.1 - _up * 0.7]:
		var down := PhysicsRayQueryParameters3D.create(start + Vector3.UP * 0.9,
			start + Vector3.DOWN * 2.0, GameLayers.WORLD, exclude)
		var hit := space.intersect_ray(down)
		if hit.is_empty() or (hit["normal"] as Vector3).y <= 0.6:
			continue
		# A step, not a drop: a floor well below the spider is somewhere to fall to,
		# not to walk onto, and the rim holds the spider there.
		if (hit["position"] as Vector3).y < here.y - RADIUS - 0.6:
			continue
		# Not into the middle of something: there has to be room to stand there.
		if _blocked(hit["position"] + Vector3.UP * (RADIUS + 0.05)):
			continue
		return _onto_floor(hit)
	return false


func _blocked(at: Vector3) -> bool:
	var ball := SphereShape3D.new()
	ball.radius = RADIUS * 0.9
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = ball
	query.transform = Transform3D(Basis.IDENTITY, at)
	query.collision_mask = GameLayers.WORLD
	query.exclude = [get_rid()]
	return not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _onto_floor(hit: Dictionary) -> bool:
	var leaving := _web
	var walk := _web.global_basis * Vector3(_web_walk.x, _web_walk.y, 0.0)
	_web = null
	global_position = hit["position"] + Vector3.UP * (RADIUS + 0.03)
	velocity = Vector3(walk.x, 0.0, walk.z)
	_grace_web = leaving
	_grace = WEB_GRACE
	_set_mode(Mode.GROUND)
	return true


## From the ground: pushing into a web on a wall in front, step up onto it.
func _step_onto_web(wish: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(global_position,
		global_position + wish * (RADIUS + 0.4), GameLayers.WEB_WALK, [get_rid()])
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return false
	var web := ThrownWeb.of(hit.get("collider"))
	# Only a web that has stuck: one still flying is taken with the grapple, not by
	# running into the one you have just thrown.
	if web == null or not web.holds_weight() or (web == _grace_web and _grace > 0.0):
		return false
	var facing: Vector3 = hit["normal"]
	if facing.dot(wish) > -0.4 or absf(facing.y) > 0.6:
		return false
	attach_to_web(web, hit["position"])
	return true


## In the air, about to touch a web along [param step]: take hold of it.
func _catch_web(step: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var ball := SphereShape3D.new()
	ball.radius = RADIUS + 0.12
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = ball
	query.collision_mask = GameLayers.WEB_WALK
	query.exclude = [get_rid()]
	query.transform = Transform3D(Basis.IDENTITY, global_position)
	query.motion = step
	var reach := space.cast_motion(query)
	var touching := reach.size() >= 2 and reach[1] < 1.0
	if not touching:
		return false
	query.transform = Transform3D(Basis.IDENTITY, global_position + step * reach[1])
	query.motion = Vector3.ZERO
	for found in space.intersect_shape(query, 4):
		var web := ThrownWeb.of(found.get("collider"))
		if web == null or not web.holds_weight():
			continue
		if web == _grace_web and _grace > 0.0:
			continue
		attach_to_web(web, global_position + step * reach[1])
		return true
	return false


# --- grappling ---------------------------------------------------------------

## Left mouse. Puts a line on what is aimed at and starts the pull. False if the
## grapple is spent or nothing holds it.
func fire_grapple() -> bool:
	acted = true
	if not grapple_ready:
		notify("Grapple's spent — land to get it back")
		return false
	if not grapple.fire():
		return false
	start_grapple()
	return true


## Starts the pull along the line [member grapple] is holding.
func start_grapple() -> void:
	if mode == Mode.WEB:
		_grace_web = _web
		_grace = WEB_GRACE
		_web = null
	grapple_ready = false
	_grapple_time = 0.0
	_set_mode(Mode.GRAPPLE)


func _step_grapple(delta: float) -> void:
	_up = Vector3.UP
	up_direction = Vector3.UP
	_grapple_time += delta
	if grapple.lost():
		# The web the line was on is gone — come apart, or called home: the pull
		# ends where it is, with half its speed.
		grapple.end()
		velocity *= 0.5
		_set_mode(Mode.AIR)
		return
	var target := grapple.target_point()
	var to := target - global_position
	var distance := to.length()
	var pace := grapple.speed
	if grapple.web != null and grapple.web.is_flying():
		pace = maxf(pace, grapple.web.velocity.length() * 1.5)
	if _buffer > 0.0:
		# Jump mid-pull: let go of the line, and drop where you are.
		grapple.end()
		_drop()
		return
	if distance <= RADIUS + 0.35 or _grapple_time > 2.5:
		var web := grapple.web
		grapple.end()
		# Down on the web's middle, on the face it came at.
		attach_to_web(web, web.global_position)
		if mode != Mode.WEB and mode != Mode.HUNG:
			_set_mode(Mode.AIR)
		return
	# Straight there, through anything the web's rim is in — and quicker than a web
	# in flight, or it would never be caught.
	var step := minf(pace * delta, distance)
	global_position += to / distance * step
	velocity = to / distance * grapple.speed


## Space mid-pull: the line lets go, all the speed goes, and the spider drops
## straight down from where it is.
func _drop() -> void:
	_buffer = 0.0
	velocity = Vector3.ZERO
	_set_mode(Mode.AIR)


# --- strung up ------------------------------------------------------------------

## At the fly [param web] is holding: the fly is the spider's, the web comes apart
## and its silk is the spider's again, and the spider hangs strung up where the fly
## was, with its grapple back.
func reach_fly(web: ThrownWeb) -> void:
	if mode == Mode.GRAPPLE:
		grapple.end()
	var at := web.global_position
	_web = null
	web.give_fly(self)
	global_position = at
	velocity = Vector3.ZERO
	_moving = Vector3.ZERO
	_last_position = at
	_stall = 0.0
	_set_mode(Mode.HUNG)
	_hang = HANG
	_refill()
	_string_up()


## Whether the spider is strung up.
func is_hung() -> bool:
	return mode == Mode.HUNG


func _step_hung(delta: float) -> void:
	_up = Vector3.UP
	up_direction = Vector3.UP
	velocity = Vector3.ZERO
	_hang -= delta
	if _buffer > 0.0 or _hang <= 0.0:
		# Space, or time: the frame tears and the spider drops, with nothing to carry.
		_buffer = 0.0
		_set_mode(Mode.AIR)


## The frame of silk the spider hangs in: a rectangle stood across the way it is
## looking, and a thread from it out to each corner and each side.
func _string_up() -> void:
	_tear_frame(false)
	var across := view.forward()
	across.y = 0.0
	if across.length_squared() < 0.0001:
		across = -global_basis.z
	var face := Basis.looking_at(across.normalized(), Vector3.UP)
	_frame = Node3D.new()
	_frame.name = "Frame"
	_frame.top_level = true
	add_child(_frame)
	_frame.global_transform = Transform3D(face, global_position)
	var mesh := ImmediateMesh.new()
	var paint := WebGeometry.silk_material()
	paint.emission_energy_multiplier = 0.7
	var half := FRAME * 0.5
	var corners := [Vector3(-half.x, -half.y, 0.0), Vector3(half.x, -half.y, 0.0),
		Vector3(half.x, half.y, 0.0), Vector3(-half.x, half.y, 0.0)]
	var silk := Color(0.95, 0.96, 1.0, 0.95)
	for i in 4:
		WebGeometry.draw_line_into(mesh, paint, corners[i], corners[(i + 1) % 4], 0.06, silk)
	# From the spider's legs, splayed, out to the frame.
	for i in 8:
		var angle := TAU * (float(i) + 0.5) / 8.0
		var leg := Vector3(cos(angle), sin(angle), 0.0) * 0.38
		var out := Vector3(cos(angle) * half.x, sin(angle) * half.y, 0.0)
		out = out / maxf(absf(out.x) / half.x, absf(out.y) / half.y)
		WebGeometry.draw_line_into(mesh, paint, leg, out, 0.035, silk)
	var view_node := MeshInstance3D.new()
	view_node.name = "Silk"
	view_node.mesh = mesh
	view_node.material_override = paint
	view_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_frame.add_child(view_node)
	_frame.scale = Vector3.ONE * 0.4
	_frame.create_tween().tween_property(_frame, "scale", Vector3.ONE, 0.12)


## Tears the frame down: torn apart and fading, or straight away.
func _tear_frame(slowly := true) -> void:
	if _frame == null or not is_instance_valid(_frame):
		_frame = null
		return
	var old := _frame
	_frame = null
	if not slowly:
		old.queue_free()
		return
	var tear := old.create_tween()
	tear.set_parallel(true)
	tear.tween_property(old, "scale", Vector3(1.4, 0.2, 1.0), 0.18)
	tear.chain().tween_callback(old.queue_free)


# --- facing --------------------------------------------------------------------

func _orient(delta: float) -> void:
	var up := _up
	var heading := _moving - up * _moving.dot(up)
	if mode == Mode.WEB:
		var wish := _wish_on(up)
		if wish != Vector3.ZERO:
			heading = wish
	if heading.length() > 0.6:
		_facing = heading.normalized()
	else:
		var look := view.forward() - up * view.forward().dot(up)
		if look.length_squared() > 0.01 and mode != Mode.WEB:
			_facing = _facing.slerp(look.normalized(), clampf(delta * 3.0, 0.0, 1.0)).normalized()
	var forward := _facing - up * _facing.dot(up)
	if forward.length_squared() < 0.0001:
		forward = up.cross(Vector3.RIGHT)
	forward = forward.normalized()
	var target := Basis(forward.cross(up).normalized(), up, -forward).orthonormalized()
	var current := global_basis.orthonormalized()
	global_basis = Basis(current.get_rotation_quaternion().slerp(
		target.get_rotation_quaternion(), clampf(12.0 * delta, 0.0, 1.0)))


func _set_mode(next: Mode) -> void:
	if mode == Mode.HUNG and next != Mode.HUNG:
		_hang = 0.0
		_tear_frame()
	mode = next


# --- silk ------------------------------------------------------------------------

## Every web the spider has out.
func webs() -> Array[ThrownWeb]:
	_forget_gone()
	return _webs


## How many more it can throw.
func webs_left() -> int:
	_forget_gone()
	return max_webs - _webs.size()


func web_container() -> Node:
	if container != null and is_instance_valid(container):
		return container
	return get_parent()


## Keeps count of a web just thrown.
func adopt_web(web: ThrownWeb) -> void:
	acted = true
	_webs.append(web)
	web.gone.connect(func(_w: ThrownWeb) -> void: _forget_gone())


## Whether a throw in the air is holding the spider up.
func is_stalled() -> bool:
	return _stall > 0.0


## A web thrown in the air holds the spider up for a moment, its speed mostly gone,
## once until it lands.
func hang_after_throw() -> void:
	if mode != Mode.AIR or _throw_hang_spent:
		return
	_throw_hang_spent = true
	_stall = maxf(_stall, THROW_STALL)
	velocity *= STALL_KEEP


func _forget_gone() -> void:
	var kept: Array[ThrownWeb] = []
	for web in _webs:
		if is_instance_valid(web) and web.is_standing():
			kept.append(web)
	_webs = kept


func notify(text: String) -> void:
	notice.emit(text)


## Puts the spider down at [param where], still, with nothing on it.
func put_at(where: Transform3D) -> void:
	grapple.end()
	caster.cancel()
	_web = null
	global_transform = Transform3D(Basis.IDENTITY, where.origin)
	velocity = Vector3.ZERO
	_moving = Vector3.ZERO
	_last_position = where.origin
	_facing = -where.basis.z
	_up = Vector3.UP
	view.face(-where.basis.z)
	view.settle()
	grapple_ready = true
	_throw_hang_spent = false
	_stall = 0.0
	acted = false
	_stood_on = null
	_set_mode(Mode.AIR)
	_tear_frame(false)
