class_name Gust
extends Node3D

## A gust of wind, blown down a lane in front of the spider.
##
## It shoves everything loose in the lane on down it, away from the spider, and
## stings it on the way. Anything it blows into one of your webs, the web catches —
## so wind is how you drive prey into silk. A boss stands its ground and only takes
## the sting.
##
## Over a puddle it does more: with Waterspout learned, it lifts the water into a
## whirl that runs on down the lane, and stops at the first thing it reaches and
## holds it there — see [WetGround] and [WaterSpiral].

const GROUP := "gusts"

## How hard it shoves, in the caster's body heights a second, from a tap to a full
## wind-up.
const PUSH := Vector2(14.0, 20.0)

## How long what it shoves is thrown for, in seconds.
const THROW := 0.45

## How much it lifts what it shoves, as a share of the shove: enough to carry a
## walker over a kerb and into a web, not enough to make it a launch.
const LIFT := 0.15

## How far up and down the lane reaches, as shares of how long it is: tall enough
## to take a flier low over the ground.
const REACH_UP := 0.4
const REACH_DOWN := 0.3

## How long its streaks are on screen, in seconds.
const SHOWN := 0.5

## Where it blows from, which way, how far, and how wide either side of its middle,
## in metres.
var apex := Vector3.ZERO
var heading := Vector3.FORWARD
var reach := 2.0
var wide := 0.5

## How hard it shoves, in metres a second, and how much of a creature's health it
## takes on the way.
var push := 3.5
var harm := 0.05

var colour := Color(0.82, 0.94, 0.9, 1.0)

## Everything it shoved, and everything it stung, in the order it reached them.
var shoved: Array[Prey] = []
var stung: Array[Prey] = []

var _age := 0.0
var _paint: StandardMaterial3D
var _streaks: MeshInstance3D


## Blows one under [param host] from [param from] along [param toward], laid flat,
## out to [param far] metres and [param half_width] either side, shoving at
## [param strength] metres a second and taking [param sting] of a creature's
## health. It has blown by the time this returns, so what it reached can be read
## straight off it.
static func blow(host: Node, from: Vector3, toward: Vector3, far: float, half_width: float,
		strength: float, sting: float, tint := Color(0.82, 0.94, 0.9, 1.0)) -> Gust:
	var flat := Vector3(toward.x, 0.0, toward.z)
	if host == null or flat.length_squared() < 0.000001 or far <= 0.0:
		return null
	var gust := Gust.new()
	gust.name = "Gust"
	gust.heading = flat.normalized()
	gust.reach = far
	gust.wide = maxf(half_width, 0.01)
	gust.push = strength
	gust.harm = sting
	gust.colour = tint
	gust.add_to_group(GROUP)
	gust.add_to_group("spell_effects")
	host.add_child(gust)
	gust.global_position = from
	gust.apex = from
	gust._blow()
	gust._build_view()
	return gust


## Whether [param point] is in the lane running from [param from] along
## [param toward], flat across the ground, out to [param far] metres and
## [param half_width] either side — with [param margin] to spare all round.
static func in_lane(point: Vector3, from: Vector3, toward: Vector3, far: float,
		half_width: float, margin := 0.0) -> bool:
	var ahead := Vector2(toward.x, toward.z)
	if ahead.length_squared() < 0.000001:
		return false
	ahead = ahead.normalized()
	var off := Vector2(point.x - from.x, point.z - from.z)
	var along := off.dot(ahead)
	if along < -margin or along > far + margin:
		return false
	return absf(off.cross(ahead)) <= half_width + margin


## Whether [param point] is in its lane, within [param margin].
func reaches(point: Vector3, margin := 0.0) -> bool:
	if not in_lane(point, apex, heading, reach, wide, margin):
		return false
	var rise := point.y - apex.y
	return rise >= -reach * REACH_DOWN - margin and rise <= reach * REACH_UP + margin


## Shoves and stings everything loose it reaches, on down the lane.
func _blow() -> void:
	for node in get_tree().get_nodes_in_group("prey"):
		var creature := node as Prey
		if creature == null or not is_instance_valid(creature) or creature.eaten \
				or not creature.is_loose():
			continue
		if not reaches(creature.global_position, creature.hit_radius()):
			continue
		if harm > 0.0:
			creature.wound(harm)
			stung.append(creature)
		if creature.shove(heading * push + Vector3.UP * push * LIFT, THROW):
			shoved.append(creature)


func _process(delta: float) -> void:
	_age += delta
	if _age >= SHOWN:
		queue_free()
		return
	if _streaks != null:
		var share := _age / SHOWN
		_streaks.position = heading * reach * 0.35 * share
		_paint.albedo_color.a = 0.6 * (1.0 - share)


## Streaks down the lane, side by side across it, blowing on as they fade.
func _build_view() -> void:
	var strands := WebGeometry.StrandSet.new()
	var width := maxf(reach * 0.01, 0.004)
	var side := heading.cross(Vector3.UP).normalized()
	for i in 9:
		var across := lerpf(-wide, wide, float(i) / 8.0) * randf_range(0.8, 1.0)
		var start := side * across + heading * reach * randf_range(0.05, 0.3) \
			+ Vector3.UP * wide * randf_range(0.05, 0.4)
		strands.add(start, start + heading * reach * randf_range(0.3, 0.5), width)
	_paint = StandardMaterial3D.new()
	_paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	_paint.albedo_color = Color(colour.r, colour.g, colour.b, 0.6)
	_streaks = MeshInstance3D.new()
	_streaks.name = "Streaks"
	_streaks.mesh = WebGeometry.build_mesh(strands, Color(1, 1, 1, 1))
	_streaks.material_override = _paint
	_streaks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_streaks)
