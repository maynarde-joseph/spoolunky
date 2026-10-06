class_name Weaver
extends CharacterBody3D

## The spider, in the fly game.
##
## Fast, and on the ground. It runs, it jumps, and it does not climb: walls and
## ceilings are not floors any more. What it has instead are three things, each on
## a button of its own and all three usable at once:
##
## * **Grapple** (left mouse) — a line to where you point, and you are pulled along
##   it. See [Grapple]. One in the air, back when you land.
## * **Silk** (right mouse) — hold to wind it up, let go to throw a web. The web
##   flies; grapple onto it and ride it; where it lands it sticks, flat, and the
##   spider can walk on it — up a wall, across a ceiling. See [SilkCaster] and
##   [ThrownWeb]. A web thrown through a fly takes the fly.
## * **Pullback** (E, or the middle mouse button) — every web in reach flies home,
##   wrapping what it passes and putting down what it held at your feet. See
##   [Pullback].
##
## Silk is a few webs, no more: a level says how many. Throw them all and the
## Pullback is how you get them back.
##
## The camera is the old game's rig, unchanged: see [SpiderCamera].

## Something worth putting on screen happened.
signal notice(text: String)

## A fly went on the line.
signal fly_caught(fly: Fly)

## A throw found no silk left to throw.
signal out_of_silk()

## Landed, on the ground or on a web: the grapple is back.
signal landed()

enum Mode {
	GROUND,   ## running on a floor
	AIR,      ## jumping or falling
	WEB,      ## on a web: stuck to a surface, or riding one through the air
	GRAPPLE,  ## being pulled along a line
	CLING,    ## a grapple ended on a wall: a moment to jump off it
}

## How tall the spider is, in metres: a Huntsman.
const HEIGHT := 0.7

## Its collider, a ball.
const RADIUS := 0.3

## How fast it runs, and how quickly it gets there and stops.
const RUN := 9.0
const ACCEL := 70.0
const DECEL := 55.0

## How quickly speed above a run bleeds away while the keys go along with it, in
## metres a second per second: what a grapple or a ride gave you is a skid you can
## use, not something gone in a frame.
const SKID_BLEED := 7.0

## How fast it walks on a web, and how quickly it turns there.
const WEB_RUN := 7.5
const WEB_ACCEL := 60.0

const GRAVITY := 24.0
const JUMP := 8.6
const MAX_FALL := 40.0

## How hard the keys steer in the air, in metres a second per second.
const AIR_ACCEL := 32.0

## Seconds after running off an edge that a jump still goes, and before landing
## that a jump pressed early still counts.
const COYOTE := 0.12
const BUFFER := 0.14

## Seconds after leaving a web before that web can be landed on again.
const WEB_GRACE := 0.3

## How long a grapple that ends on a wall holds you there, and how hard a jump off
## it goes.
const CLING_TIME := 0.65
const WALL_JUMP := Vector2(7.0, 8.5)

## Falling below this puts the spider back at the start.
var kill_y := -30.0

## How many webs it may have out at once.
var max_webs := 3

## Ignore the keys while the mouse is free. Off for headless checks.
var require_captured_mouse := true

var mode := Mode.AIR

## Whether a grapple is ready.
var grapple_ready := true

var view: SpiderCamera
var grapple: Grapple
var caster: SilkCaster
var pullback: Pullback
var fly_line: FlyLine
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
var _web_turned := 0
var _grace_web: ThrownWeb = null
var _grace := 0.0
var _last_position := Vector3.ZERO
var _moving := Vector3.ZERO

var _grapple_time := 0.0
var _cling_left := 0.0
var _cling_normal := Vector3.FORWARD
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
	fly_line = FlyLine.new()
	fly_line.name = "FlyLine"
	add_child(fly_line)
	fly_line.setup(self)
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
		Mode.CLING:
			_step_cling(delta)
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
	var rush := clampf(_moving.length() / (RUN * 2.2) - 0.25, 0.0, 1.0)
	var aiming := clampf(view.aim_blend, 0.0, 1.0) * view.aim_fov_gain
	camera.fov = lerpf(camera.fov, _base_fov + rush * 16.0 + aiming,
		clampf(delta * 6.0, 0.0, 1.0))


# --- on the ground -----------------------------------------------------------

func _step_ground(delta: float) -> void:
	_up = Vector3.UP
	up_direction = Vector3.UP
	var wish := _wish_flat()
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	flat = _run_toward(flat, wish, RUN, ACCEL, DECEL, delta)
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


## [param flat] brought toward [param wish] at [param top] speed. Above the top
## speed, going the way the keys go, it skids rather than stopping dead.
func _run_toward(flat: Vector3, wish: Vector3, top: float, accel: float, decel: float,
		delta: float) -> Vector3:
	var speed := flat.length()
	if speed > top * 1.02 and wish != Vector3.ZERO and wish.dot(flat / speed) > 0.3:
		speed = move_toward(speed, top, SKID_BLEED * delta)
		var heading := (flat / flat.length()).slerp(wish, clampf(8.0 * delta, 0.0, 1.0))
		return heading.normalized() * speed
	var rate := accel if wish != Vector3.ZERO else decel
	return flat.move_toward(wish * top, rate * delta)


func _jump() -> void:
	_buffer = 0.0
	_coyote = 0.0
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
	velocity.y = maxf(velocity.y - GRAVITY * delta, -MAX_FALL)
	var wish := _wish_flat()
	if wish != Vector3.ZERO:
		var flat := Vector3(velocity.x, 0.0, velocity.z)
		var keep := maxf(flat.length(), RUN)
		flat = (flat + wish * AIR_ACCEL * delta).limit_length(keep)
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


## Takes hold of [param web] where the spider is, on whichever face it is nearer.
func attach_to_web(web: ThrownWeb, at := Vector3.INF) -> void:
	if web == null or not web.is_standing():
		return
	if mode == Mode.GRAPPLE:
		grapple.end()
	var where := global_position if at == Vector3.INF else at
	var local := web.to_local(where)
	_web = web
	_web_side = 1.0 if web.to_local(global_position).z >= 0.0 else -1.0
	_web_at = Vector2(local.x, local.y).limit_length(maxf(web.current_radius() - 0.2, 0.05))
	var carried := web.global_basis.inverse() * velocity
	_web_walk = Vector2(carried.x, carried.y).limit_length(WEB_RUN)
	_web_turned = web.turned
	velocity = Vector3.ZERO
	_set_mode(Mode.WEB)
	grapple_ready = true
	landed.emit()
	_place_on_web()


## Lets go of the web, keeping whatever speed it was giving.
func let_go_of_web() -> void:
	if mode != Mode.WEB:
		return
	_grace_web = _web
	_grace = WEB_GRACE
	velocity = _moving
	_web = null
	_set_mode(Mode.AIR)


func _step_web(delta: float) -> void:
	if _web == null or not is_instance_valid(_web) or not _web.is_standing():
		_web = null
		velocity = _moving
		_set_mode(Mode.AIR)
		return
	if _web.turned != _web_turned:
		# The web turned under us as it stuck: find our footing on its new face.
		_web_turned = _web.turned
		var local := _web.to_local(global_position)
		_web_side = 1.0 if local.z >= 0.0 else -1.0
		_web_at = Vector2(local.x, local.y)
	_up = _web.normal() * _web_side
	if _buffer > 0.0:
		_jump_off_web()
		return
	var basis := _web.global_basis.orthonormalized()
	var wish := _wish_on(_up)
	var wish_local := basis.inverse() * wish
	var wish_2d := Vector2(wish_local.x, wish_local.y)
	if wish_2d.length_squared() > 0.0001:
		wish_2d = wish_2d.normalized()
	_web_walk = _web_walk.move_toward(wish_2d * WEB_RUN, WEB_ACCEL * delta)
	var next := _web_at + _web_walk * delta
	var limit := maxf(_web.current_radius() - 0.22, 0.05)
	if next.length() > limit:
		var outward_2d := next.normalized()
		var outward := (basis * Vector3(outward_2d.x, outward_2d.y, 0.0)).normalized()
		if wish != Vector3.ZERO and wish.dot(outward) > 0.25 and _step_off_web(outward):
			return
		next = next.limit_length(limit)
		_web_walk -= outward_2d * maxf(_web_walk.dot(outward_2d), 0.0)
	_web_at = next
	_place_on_web()


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
	var push := _up * JUMP * 0.75 + Vector3.UP * JUMP * 0.55
	if _up.y > 0.7:
		push = _up * JUMP
	var ride := _web.velocity if _web.is_flying() else Vector3.ZERO
	var walk := _web.global_basis * Vector3(_web_walk.x, _web_walk.y, 0.0)
	_grace_web = _web
	_grace = WEB_GRACE
	_web = null
	velocity = ride + walk + push
	_set_mode(Mode.AIR)


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
		if other != null and other.is_standing():
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
			start + Vector3.DOWN * 1.0, GameLayers.WORLD, exclude)
		var hit := space.intersect_ray(down)
		if hit.is_empty() or (hit["normal"] as Vector3).y <= 0.6:
			continue
		# Not into the middle of something: there has to be room to stand there.
		if _blocked(hit["position"] + Vector3.UP * (RADIUS + 0.05)):
			continue
		return _onto_floor(hit)
	return false


## The top of a wall facing [param wall_normal] in front of [param from], if it is
## low enough over the spider to get up onto: a hit on the floor up there, or empty.
func _ledge_above(from: Vector3, wall_normal: Vector3) -> Dictionary:
	var space := get_world_3d().direct_space_state
	for inward in [0.45, 0.8]:
		var over: Vector3 = from - wall_normal * (RADIUS + float(inward))
		var query := PhysicsRayQueryParameters3D.create(over + Vector3.UP * MANTLE,
			over + Vector3.DOWN * 0.3, GameLayers.WORLD, [get_rid()])
		var hit := space.intersect_ray(query)
		if hit.is_empty() or (hit["normal"] as Vector3).y <= 0.6:
			continue
		if _blocked(hit["position"] + Vector3.UP * (RADIUS + 0.05)):
			continue
		return hit
	return {}


## How far above the spider a ledge can be and still be got up onto from a line
## that ended on its face.
const MANTLE := 1.4


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
	if web == null or not web.is_standing() or (web == _grace_web and _grace > 0.0):
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
		if web == null or not web.is_standing():
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
		grapple.end()
		_set_mode(Mode.AIR)
		return
	if _buffer > 0.0:
		# Let go mid-pull: fly on with the pull's speed, and a little lift.
		_buffer = 0.0
		velocity = velocity * 0.9
		velocity.y = maxf(velocity.y, 0.0) + 5.0
		grapple.end()
		_set_mode(Mode.AIR)
		return
	var target := grapple.target_point()
	var to := target - global_position
	var distance := to.length()
	var arrive := RADIUS + 0.35 if grapple.web != null else RADIUS + 0.15
	if distance <= arrive or _grapple_time > 2.5:
		_grapple_arrive()
		return
	var step := minf(grapple.speed * delta, distance)
	velocity = to / distance * (step / delta)
	var before := global_position
	if grapple.web == null:
		move_and_slide()
		if global_position.distance_to(before) < step * 0.3:
			_grapple_arrive()
			return
	else:
		# Onto a web: straight there, through anything its rim is in.
		global_position += to / distance * step
	velocity = to / distance * grapple.speed


func _grapple_arrive() -> void:
	var web := grapple.web
	var normal := grapple.target_normal()
	var travel := velocity
	grapple.end()
	if web != null and is_instance_valid(web) and web.is_standing():
		attach_to_web(web)
		return
	if normal.y > 0.6:
		# A floor: land running, with the pull's speed along it.
		var along := travel - normal * travel.dot(normal)
		velocity = along.limit_length(RUN * 1.6)
		_set_mode(Mode.GROUND)
		_land()
		return
	if absf(normal.y) <= 0.6:
		var flat_normal := Vector3(normal.x, 0.0, normal.z).normalized()
		var top := _ledge_above(global_position, flat_normal)
		if not top.is_empty():
			# Just under the lip: over it and onto the top, running.
			global_position = top["position"] + Vector3.UP * (RADIUS + 0.03)
			velocity = -flat_normal * RUN * 0.6
			_set_mode(Mode.GROUND)
			_land()
			return
		_cling_normal = flat_normal
		_cling_left = CLING_TIME
		velocity = Vector3.ZERO
		_set_mode(Mode.CLING)
		return
	velocity = Vector3.ZERO
	_set_mode(Mode.AIR)


# --- clinging ------------------------------------------------------------------

func _step_cling(delta: float) -> void:
	_cling_left -= delta
	if _buffer > 0.0:
		_buffer = 0.0
		velocity = _cling_normal * WALL_JUMP.x + Vector3.UP * WALL_JUMP.y
		_set_mode(Mode.AIR)
		return
	if _cling_left <= 0.0:
		_set_mode(Mode.AIR)
		return
	var wish := _wish_flat()
	if wish.dot(-_cling_normal) > 0.5:
		var top := _ledge_above(global_position, _cling_normal)
		if not top.is_empty():
			global_position = top["position"] + Vector3.UP * (RADIUS + 0.03)
			velocity = -_cling_normal * RUN * 0.6
			_set_mode(Mode.GROUND)
			_land()
			return
	velocity = Vector3.DOWN * 1.2 - _cling_normal * 0.5
	if _catch_web(velocity * delta):
		return
	move_and_slide()
	if is_on_floor():
		_land()


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
	_webs.append(web)
	web.gone.connect(func(_w: ThrownWeb) -> void: _forget_gone())


func _forget_gone() -> void:
	var kept: Array[ThrownWeb] = []
	for web in _webs:
		if is_instance_valid(web) and web.is_standing():
			kept.append(web)
	_webs = kept


## A web took [param fly]: it is wrapped and goes on the line.
func catch_fly(fly: Fly) -> void:
	if fly == null or not fly.catch_it():
		return
	fly_line.add(fly)
	fly_caught.emit(fly)


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
	_set_mode(Mode.AIR)
