class_name WaterSpiral
extends Node3D

## A whirl of water, lifted off wet ground by the wind.
##
## No spell casts it on its own. Douse wets the ground in a fan in front of the
## spider; a Gust blown over that ground lifts the water into a whirl, which runs on
## the way the wind blew, riding whatever the ground does on the way and breaking
## on the first wall it meets — see [WetGround] and [Gust].
##
## It stops at the first thing it reaches and holds it there: round and round in
## the water, going nowhere and doing nothing, soaked and worn down a little, for a
## few seconds — see [method Prey.hold_at]. A boss is held for half as long. And it
## is better with the rest of what the spider has:
##
## * **Silk.** Something held is something a thrown web does not have to lead.
## * **Lightning.** What it holds is wet, and water carries a strike twice as hard;
##   a strike on the whirl itself reaches what it holds — see [LightningStrike].
## * **Digestive Flood.** The spider's water eats what it holds: it is dosed.

## Said when it is spent, with what it held, if it held anything.
signal spent(whirl: WaterSpiral, held: Array[Prey])

const GROUP := "water_spirals"

## How fast it goes, in the caster's body heights a second.
const PACE := 10.0

## How much shorter a hold on a boss is, as a share.
const BOSS_HOLD := 0.5

## How far up from its floor it reaches, and how far down, as shares of its
## radius. Tall rather than flat, so it has fliers too.
const REACH_UP := 1.6
const REACH_DOWN := 0.4

## How long something stays wet once it is out, in seconds.
const SOAK := 6.0

## How high off its floor a wall has to stand to stop it, as a share of its radius:
## a kerb it rides up, a wall it breaks on.
const WALL_AT := 0.5

## How fast it turns, in radians a second. Looks only.
const SWIRL := 9.0

## How long it takes to rise, and to sink away once it is spent, in seconds.
const RISE := 0.15
const FADE := 0.35

## How much of the spray round it shows. Enough to read which way it turns, and
## no more: it is the water that matters, not the streaks on it.
const STREAK_ALPHA := 0.6

## How wide it is, from the middle to the rim, in metres.
var radius := 1.0

## How far it goes, and how fast, in metres and metres a second.
var distance := 6.0
var speed := 6.0

## How long it holds what it catches, in seconds, and how much of that creature's
## health it wears away over the hold.
var hold_for := 3.0
var harm := 0.1

## Whether its water eats what it touches, and how hard. The spider's, from
## Digestive Flood.
var acid := false
var venom_strength := 1.0

var colour := Color(0.36, 0.74, 0.9, 1.0)

## Which way it is going, flat across the ground.
var heading := Vector3.FORWARD

## How far it has come.
var travelled := 0.0

## What it has hold of, while it holds it.
var caught: Prey = null

## Whatever it held, once it has let go.
var had: Array[Prey] = []

var _age := 0.0
var _hold_left := 0.0
var _spent_at := -1.0
var _view: Node3D
var _water: StandardMaterial3D
var _streaks: StandardMaterial3D


## Sends one out from [param from] under [param host], along [param toward] laid
## flat, [param wide] metres from the middle to the rim, [param far] metres at
## [param pace] metres a second; what it catches it holds for [param holds]
## seconds, wearing away [param hurt] of its health over the hold. [param eats] is
## whether its water doses what it holds, at [param strength]; [param tint] is the
## colour of it.
static func send(host: Node, from: Vector3, toward: Vector3, wide: float, far: float,
		pace: float, holds: float, hurt := 0.1, eats := false, strength := 1.0,
		tint := Color(0.36, 0.74, 0.9, 1.0)) -> WaterSpiral:
	if host == null:
		return null
	var flat := Vector3(toward.x, 0.0, toward.z)
	var whirl := WaterSpiral.new()
	whirl.name = "WaterSpiral"
	whirl.radius = maxf(wide, 0.05)
	whirl.distance = maxf(far, 0.0)
	whirl.speed = maxf(pace, 0.01)
	whirl.hold_for = maxf(holds, 0.1)
	whirl.harm = hurt
	whirl.acid = eats
	whirl.venom_strength = strength
	whirl.colour = tint
	whirl.heading = flat.normalized() if flat.length_squared() > 0.000001 else Vector3.FORWARD
	whirl.add_to_group(GROUP)
	whirl.add_to_group("spell_effects")
	host.add_child(whirl)
	whirl.global_position = whirl._floor_under(from)
	return whirl


func _ready() -> void:
	_build_view()


func _physics_process(delta: float) -> void:
	_age += delta
	if caught != null:
		_hold(delta)
	elif spinning():
		_travel(delta)
		_catch_first()
	elif _age >= _spent_at + FADE:
		queue_free()
		return
	_update_view(delta)


## Whether it is still going. Spent, it sinks away and touches nothing.
func spinning() -> bool:
	return _spent_at < 0.0


## Whether [param point] is inside it.
func holds(point: Vector3) -> bool:
	var offset := point - global_position
	if offset.y < -radius * REACH_DOWN or offset.y > radius * REACH_UP:
		return false
	return Vector2(offset.x, offset.z).length() <= radius


## What it has hold of now: the one thing it caught, or nothing.
func held() -> Array[Prey]:
	var found: Array[Prey] = []
	if caught != null and is_instance_valid(caught):
		found.append(caught)
	return found


## The middle of it, a little off its floor: where a charge goes in.
func eye() -> Vector3:
	return global_position + Vector3.UP * radius * 0.25


## Where it will be spent if nothing stops it: the rest of its run, laid straight
## out from where it is.
func end_point() -> Vector3:
	return global_position + heading * (distance - travelled)


## On along the ground by one frame's worth, over a kerb and up a slope, and spent
## where its run ends or a wall stands in the way.
func _travel(delta: float) -> void:
	var step := minf(speed * delta, distance - travelled)
	if step <= 0.0:
		_spend()
		return
	var from := global_position
	var to := from + heading * step
	var lift := Vector3.UP * radius * WALL_AT
	var query := PhysicsRayQueryParameters3D.create(from + lift, to + lift, GameLayers.WORLD)
	var wall := get_world_3d().direct_space_state.intersect_ray(query)
	if not wall.is_empty():
		var at: Vector3 = wall.get("position", to)
		global_position = Vector3(at.x, from.y, at.z) - heading * minf(radius * 0.25, step)
		_spend()
		return
	global_position = _floor_under(to)
	travelled += step
	if travelled >= distance - 0.0001:
		_spend()


## The floor under [param point], if there is one within its reach; over a drop it
## carries on at the height it was. Looked for from no higher than a kerb it could
## ride up, so a branch or a ledge overhead is not a floor it jumps on to.
func _floor_under(point: Vector3) -> Vector3:
	if not is_inside_tree():
		return point
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * radius * WALL_AT,
		point + Vector3.DOWN * radius * (WALL_AT + 1.5), GameLayers.WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return point
	return hit.get("position", point)


## Stops at the first loose thing inside it and takes hold of it, where it caught
## it.
func _catch_first() -> void:
	if not spinning():
		return
	for node in get_tree().get_nodes_in_group("prey"):
		var creature := node as Prey
		if creature == null or not is_instance_valid(creature) or creature.eaten \
				or not creature.is_loose():
			continue
		if not holds(creature.global_position):
			continue
		caught = creature
		_hold_left = hold_for * (BOSS_HOLD if creature.is_boss() else 1.0)
		global_position = _floor_under(creature.global_position)
		# Held and soaked from the moment it is caught, not from the next step.
		creature.hold_at(eye(), 0.1)
		creature.soak(SOAK)
		return


## Round and round: what it caught is kept at its eye, soaked and worn down, until
## the hold runs out or there is nothing left to hold.
func _hold(delta: float) -> void:
	if not is_instance_valid(caught) or caught.eaten or not caught.is_loose():
		_let_go()
		return
	_hold_left -= delta
	caught.hold_at(eye(), maxf(delta * 2.0, 0.05))
	caught.soak(SOAK)
	caught.wound(harm / hold_for * delta)
	if acid:
		caught.poison(1.5, venom_strength)
	if _hold_left <= 0.0:
		_let_go()


func _let_go() -> void:
	if caught != null and is_instance_valid(caught):
		had.append(caught)
	caught = null
	_spend()


func _spend() -> void:
	if not spinning():
		return
	_spent_at = _age
	spent.emit(self, had)


# --- what you can see ----------------------------------------------------

## A funnel of water turning on its point, with streaks round it to show which
## way. Built at a radius of one and scaled, so its size is one number.
func _build_view() -> void:
	_view = Node3D.new()
	_view.name = "View"
	add_child(_view)
	_view.scale = Vector3.ONE * radius

	var funnel := CylinderMesh.new()
	funnel.top_radius = 1.0
	funnel.bottom_radius = 0.15
	funnel.height = 0.7
	funnel.radial_segments = 32
	funnel.rings = 1
	funnel.cap_top = false
	funnel.cap_bottom = false
	_water = StandardMaterial3D.new()
	_water.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_water.cull_mode = BaseMaterial3D.CULL_DISABLED
	_water.albedo_color = Color(colour.r, colour.g, colour.b, 0.28)
	var body := MeshInstance3D.new()
	body.name = "Funnel"
	body.mesh = funnel
	body.material_override = _water
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.position = Vector3(0.0, 0.35, 0.0)
	_view.add_child(body)

	# Three arms of spray, spiralling down the funnel from the rim to the eye.
	var strands := WebGeometry.StrandSet.new()
	for arm in 3:
		var previous := Vector3.ZERO
		for step in 25:
			var t := float(step) / 24.0
			var turn := float(arm) * TAU / 3.0 + t * TAU * 1.25
			var across := lerpf(1.0, 0.15, t)
			var point := Vector3(cos(turn) * across, lerpf(0.7, 0.02, t), sin(turn) * across)
			if step > 0:
				strands.add(previous, point, 0.022)
			previous = point
	_streaks = StandardMaterial3D.new()
	_streaks.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_streaks.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_streaks.cull_mode = BaseMaterial3D.CULL_DISABLED
	_streaks.albedo_color = Color(0.78, 0.93, 1.0, STREAK_ALPHA)
	var spray := MeshInstance3D.new()
	spray.name = "Spray"
	spray.mesh = WebGeometry.build_mesh(strands, Color(1, 1, 1, 1))
	spray.material_override = _streaks
	spray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_view.add_child(spray)


func _update_view(delta: float) -> void:
	if _view == null:
		return
	_view.rotate_y(-SWIRL * delta)
	var rising := clampf(_age / RISE, 0.0, 1.0)
	var sinking := clampf((_age - _spent_at) / FADE, 0.0, 1.0) if not spinning() else 0.0
	var height := rising * (1.0 - sinking)
	_view.scale = Vector3(radius, radius * maxf(height, 0.02), radius)
	if _water != null:
		_water.albedo_color.a = 0.28 * (1.0 - sinking)
	if _streaks != null:
		_streaks.albedo_color.a = STREAK_ALPHA * (1.0 - sinking)
