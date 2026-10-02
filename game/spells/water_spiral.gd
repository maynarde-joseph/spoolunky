class_name WaterSpiral
extends Node3D

## A whirl of water, sent out from under the spider along the ground.
##
## It leaves from the spider's feet and runs straight out the way you aimed, as far
## as the wind-up sends it, riding whatever the ground does on the way, and breaks
## on the first wall it meets. Everything it passes over is soaked, and slowed for
## a few seconds after it has gone by: a hunter coming at you comes on at a crawl,
## and a charge is half a charge. Wet wings do not lift, so a flier it catches comes
## down and cannot climb again until it dries.
##
## It is a slow, not a hold — what it catches is still yours to deal with, sooner —
## and it is better with the rest of what the spider has:
##
## * **Silk.** Something slowed is something a thrown web hardly has to lead.
## * **Lightning.** Everything it has been over is wet, and water carries a strike
##   twice as hard and on to anything wet near it; a strike on the whirl itself
##   reaches everything in it — see [LightningStrike].
## * **Digestive Flood.** The spider's water eats what it passes over: everything
##   it touches is dosed.

## Said when it is spent, with everything it slowed on the way.
signal spent(whirl: WaterSpiral, slowed: Array[Prey])

const GROUP := "water_spirals"

## How fast it goes, in the caster's body heights a second.
const PACE := 10.0

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

## How long what it passes over stays slowed once it has gone by, in seconds.
var slow_for := 3.0

## Whether its water eats what it touches, and how hard. The spider's, from
## Digestive Flood.
var acid := false
var venom_strength := 1.0

var colour := Color(0.36, 0.74, 0.9, 1.0)

## Which way it is going, flat across the ground.
var heading := Vector3.FORWARD

## How far it has come.
var travelled := 0.0

## Everything it has slowed, in the order it reached them.
var slowed: Array[Prey] = []

var _age := 0.0
var _spent_at := -1.0
var _view: Node3D
var _water: StandardMaterial3D
var _streaks: StandardMaterial3D


## Sends one out from [param from] under [param host], along [param toward] laid
## flat, [param wide] metres from the middle to the rim, [param far] metres at
## [param pace] metres a second; what it passes over is slowed for [param slows]
## seconds. [param eats] is whether its water doses what it touches, at
## [param strength]; [param tint] is the colour of it.
static func send(host: Node, from: Vector3, toward: Vector3, wide: float, far: float,
		pace: float, slows: float, eats := false, strength := 1.0,
		tint := Color(0.36, 0.74, 0.9, 1.0)) -> WaterSpiral:
	if host == null:
		return null
	var flat := Vector3(toward.x, 0.0, toward.z)
	var whirl := WaterSpiral.new()
	whirl.name = "WaterSpiral"
	whirl.radius = maxf(wide, 0.05)
	whirl.distance = maxf(far, 0.0)
	whirl.speed = maxf(pace, 0.01)
	whirl.slow_for = slows
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
	if spinning():
		_travel(delta)
		_soak_what_it_holds()
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


## Everything loose that is inside it now.
func held() -> Array[Prey]:
	var found: Array[Prey] = []
	if not spinning():
		return found
	for node in get_tree().get_nodes_in_group("prey"):
		var creature := node as Prey
		if creature == null or not is_instance_valid(creature) or not creature.is_loose():
			continue
		if holds(creature.global_position):
			found.append(creature)
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


func _soak_what_it_holds() -> void:
	for creature in held():
		creature.soak(SOAK)
		creature.slow(slow_for)
		if acid:
			creature.poison(1.5, venom_strength)
		if not slowed.has(creature):
			slowed.append(creature)


func _spend() -> void:
	if not spinning():
		return
	_spent_at = _age
	spent.emit(self, slowed)


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
