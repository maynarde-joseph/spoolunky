class_name WaterSpit
extends Node3D

## A mouthful of water spat at the cross: a spray of drops out of the spider's
## jaws, arcing down round where it points.
##
## The first drop goes straight at the cross and the rest come down round it, each
## a little sooner or later than the last, so it lands as a patter rather than a
## slap. A drop that hits a creature splashes on it: it is soaked and stung — once,
## however many drops it takes — and soaked wings do not lift, so a flier comes
## down. A drop that comes down on the ground leaves a puddle there, or makes the
## one it lands in bigger: see [WetGround]. One that hits a wall only splashes.
##
## Silk does not stop a drop. But with Wet Silk learned, every web and line one
## goes through is soaked on the way — see [WetSilk] — so a web is wetted by
## spitting through it, and what stands under it gets the rest.

## The last drop is down: every creature it soaked, how many webs and lines it
## wet, and how many puddles it left.
signal landed(mouthful: WaterSpit, soaked: Array[Prey], webs: int, puddles: int)

const GROUP := "water_spits"

## How many drops there are, from a tap to a full wind-up.
const DROPS := Vector2(6.0, 12.0)

## How fast it goes, in the caster's body heights a second, and the least and the
## most time a drop spends in the air on the way, in seconds: always a lob you can
## watch come down, never a flick that lands before you have seen it go.
const PACE := 12.0
const FLIGHT := Vector2(0.5, 1.3)

## How hard a drop falls, in the caster's body heights a second, every second: a
## little softer than a stone, so the arc reads as water.
const FALL := 24.0

## How far round the cross the drops come down, as a share of how wide a puddle is.
const SCATTER := 5.0

## How long it takes for all the drops to leave the jaws, in seconds: a spray, not
## a single slap.
const SPRAY := 0.12

## How much longer or shorter than the first drop's time in the air the rest of
## them take, as shares of it: they come down one after another.
const STAGGER := Vector2(0.85, 1.25)

## How big a drop is from its middle, in the caster's body heights: what it looks
## like, and how near it has to pass something to hit it.
const DROP := 0.05

## How long a drop that hits nothing is kept up for, in seconds, before it is gone.
const LIFE := 2.5

## How level ground has to be for a drop to leave a puddle on it, as the up of the
## ground against the world's: a floor or a slope, not a wall.
const FLOOR := 0.6

## The angle between one drop and the next round the cross, in radians: the golden
## one, so however many there are they spread evenly and never line up.
const GOLDEN := 2.39996

## How wide a puddle a drop leaves, from its middle, in metres, and how long the
## puddles stay wet, in seconds.
var puddle_wide := 0.1
var lasts := 10.0

## How much of a creature's health it takes, once a creature, however many drops.
var harm := 0.05

## Whether it soaks the silk it goes through, and whether what it soaks holds
## harder for it: Wet Silk and Sodden Silk.
var wets_silk := false
var heavy := false

var colour := Color(0.36, 0.74, 0.9, 1.0)

## How many drops it threw.
var thrown := 0

## Everything it soaked, the webs and lines it wet, and the puddles it left, in the
## order it reached them.
var soaked: Array[Prey] = []
var wet_webs: Array[WebStructure] = []
var puddles: Array[WetGround] = []

var _drops: Array[Drop] = []
var _fall := 10.0
var _size := 0.0125
var _bead: SphereMesh
var _paint: StandardMaterial3D


## One drop: where it left from and how, how long it has been out, where it is,
## and what it looks like.
class Drop:
	var start := Vector3.ZERO
	var speed := Vector3.ZERO
	var age := 0.0
	var at := Vector3.ZERO
	var view: MeshInstance3D


## Spits one under [param host] from [param from] at [param at]: [param count]
## drops, for a caster [param body] metres tall, each leaving a puddle
## [param wide] metres across from the middle that stays wet for [param seconds],
## and taking [param hurt] of the health of whatever one hits. With [param silk] it
## soaks the silk it goes through, and with [param sodden] what it soaks holds
## harder.
static func spit(host: Node, from: Vector3, at: Vector3, count: int, body: float,
		wide: float, seconds: float, hurt: float, tint := Color(0.36, 0.74, 0.9, 1.0),
		silk := false, sodden := false) -> WaterSpit:
	if host == null or count <= 0 or body <= 0.0:
		return null
	var mouthful := WaterSpit.new()
	mouthful.name = "WaterSpit"
	mouthful.puddle_wide = maxf(wide, 0.01)
	mouthful.lasts = maxf(seconds, 0.1)
	mouthful.harm = hurt
	mouthful.colour = tint
	mouthful.wets_silk = silk
	mouthful.heavy = sodden
	mouthful._fall = FALL * body
	mouthful._size = maxf(DROP * body, 0.004)
	mouthful.add_to_group(GROUP)
	mouthful.add_to_group("spell_effects")
	host.add_child(mouthful)
	mouthful.global_position = from
	mouthful._build_view()
	mouthful._throw(from, at, count, body)
	return mouthful


## How fast, and which way, a drop has to leave [param from] to come down on
## [param at], for a caster [param body] metres tall: quick and flat close up,
## slower and higher further off. [param stretch] makes its time in the air that
## much longer or shorter.
static func launch(from: Vector3, at: Vector3, body: float, stretch := 1.0) -> Vector3:
	var gap := at - from
	var flight := flight_time(from, at, body) * maxf(stretch, 0.1)
	return gap / flight + Vector3.UP * FALL * body * flight * 0.5


## How long a drop thrown from [param from] to [param at] is in the air, for a caster
## [param body] metres tall, in seconds.
static func flight_time(from: Vector3, at: Vector3, body: float) -> float:
	return clampf(from.distance_to(at) / maxf(PACE * body, 0.01), FLIGHT.x, FLIGHT.y)


## Whether any drop is still in the air.
func flying() -> bool:
	return not _drops.is_empty()


## Every drop out within [constant SPRAY] of a second: the first straight at
## [param at], the rest round it out to [constant SCATTER] puddles' width, each a
## little quicker or slower than the last so they come down one after another.
##
## The rest are thrown at the ground round the cross, not at the cross itself:
## spat at a creature, or a web, the drops that miss it would otherwise sail on past
## and leave their puddles a long way behind it.
func _throw(from: Vector3, at: Vector3, count: int, body: float) -> void:
	var scatter := puddle_wide * SCATTER
	var turn := randf() * TAU
	for i in count:
		var aim := at
		if i > 0 and count > 1:
			var out := scatter * sqrt(float(i) / float(count - 1))
			var angle := turn + float(i) * GOLDEN
			aim = _ground_under(at + Vector3(cos(angle) * out, 0.0, sin(angle) * out), body)
		var drop := Drop.new()
		drop.start = from
		drop.at = from
		drop.speed = launch(from, aim, body, lerpf(STAGGER.x, STAGGER.y,
			fposmod(float(i) * 0.618, 1.0)))
		# Not out of the jaws yet: it waits its turn, out of sight.
		drop.age = -SPRAY * float(i) / float(maxi(count - 1, 1))
		drop.view = _drop_view()
		drop.view.visible = drop.age >= 0.0
		_place(drop)
		_drops.append(drop)
	thrown = count


## The ground under [param point], if there is any within a few of the caster's
## body heights, else the point itself.
func _ground_under(point: Vector3, body: float) -> Vector3:
	var hit := get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(point + Vector3.UP * _size,
			point + Vector3.DOWN * body * 8.0, GameLayers.WORLD))
	return hit["position"] if not hit.is_empty() else point


func _physics_process(delta: float) -> void:
	var space := get_world_3d().direct_space_state
	for drop: Drop in _drops.duplicate():
		var was := drop.at
		drop.age += delta
		if drop.age < 0.0:
			continue
		drop.view.visible = true
		var now := drop.start + drop.speed * drop.age \
			+ Vector3.DOWN * _fall * drop.age * drop.age * 0.5
		if _fly(drop, was, now, space) or drop.age >= LIFE:
			_drops.erase(drop)
			drop.view.queue_free()
	if _drops.is_empty():
		landed.emit(self, soaked, wet_webs.size(), puddles.size())
		queue_free()


## Moves [param drop] on from [param was] to [param now] and does whatever it meets
## on the way: the first creature, else the ground or a wall, and any silk before
## either. True if that was the end of it.
func _fly(drop: Drop, was: Vector3, now: Vector3, space: PhysicsDirectSpaceState3D) -> bool:
	var end := now
	var ground := {}
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(was, now, GameLayers.WORLD))
	if not hit.is_empty():
		end = hit["position"]
		ground = hit
	var struck := _first_creature(was, end)
	if struck != null:
		end = Geometry3D.get_closest_point_to_segment(struck.global_position, was, end)
	_wet_silk(was, end)
	drop.at = end
	_place(drop)
	if struck != null:
		_splash_on(struck, end)
		return true
	if not ground.is_empty():
		_come_down(end, ground["normal"])
		return true
	return false


## The creature the drop meets first going from [param from] to [param to], or null.
func _first_creature(from: Vector3, to: Vector3) -> Prey:
	var best: Prey = null
	var best_along := INF
	for node in get_tree().get_nodes_in_group("prey"):
		var creature := node as Prey
		if creature == null or not is_instance_valid(creature) or creature.eaten \
				or creature.is_bundled():
			continue
		var centre := creature.global_position
		var closest := Geometry3D.get_closest_point_to_segment(centre, from, to)
		if closest.distance_to(centre) > creature.hit_radius() + _size:
			continue
		var along := from.distance_to(closest)
		if along < best_along:
			best_along = along
			best = creature
	return best


## A drop splashed on [param creature] at [param point]: soaked, and stung the first
## time.
func _splash_on(creature: Prey, point: Vector3) -> void:
	_splash(point)
	creature.soak(WetGround.SOAK + lasts * 0.5)
	if soaked.has(creature):
		return
	soaked.append(creature)
	if harm > 0.0:
		creature.wound(harm)


## A drop came down at [param point] on ground facing [param normal]: a puddle, if
## the ground is level enough to hold one — the one it landed in, made bigger, or a
## new one.
func _come_down(point: Vector3, normal: Vector3) -> void:
	_splash(point)
	if normal.dot(Vector3.UP) < FLOOR:
		return
	for node in get_tree().get_nodes_in_group(WetGround.GROUP):
		var wet := node as WetGround
		if wet != null and not wet.is_queued_for_deletion() and wet.holds(point):
			wet.swell(puddle_wide, lasts)
			return
	var puddle := WetGround.puddle(get_parent(), point, normal, puddle_wide, lasts, colour)
	if puddle != null:
		puddles.append(puddle)


## With Wet Silk, every web and line a drop goes through between [param from] and
## [param to] is soaked.
func _wet_silk(from: Vector3, to: Vector3) -> void:
	if not wets_silk:
		return
	for node in get_tree().get_nodes_in_group("silk_webs"):
		var web := node as WebStructure
		if web == null or web.is_queued_for_deletion() or not _goes_through(web, from, to):
			continue
		WetSilk.soak(web, lasts, heavy)
		if not wet_webs.has(web):
			wet_webs.append(web)


## Whether a drop going from [param from] to [param to] goes through [param web]'s
## silk: across a line, or through a web's face.
func _goes_through(web: WebStructure, from: Vector3, to: Vector3) -> bool:
	var strand := web as WebStrand
	if strand != null:
		var pair := Geometry3D.get_closest_points_between_segments(from, to, strand.point_a,
			strand.point_b)
		return pair[0].distance_to(pair[1]) <= _size * 2.0
	var net := web as WebNet
	if net == null:
		return false
	var middle := net.signal_point()
	var before := (from - middle).dot(net.plane_normal)
	var after := (to - middle).dot(net.plane_normal)
	if before * after > 0.0 and minf(absf(before), absf(after)) > _size:
		return false
	var share := clampf(before / (before - after), 0.0, 1.0) \
		if absf(before - after) > 0.000001 else 0.0
	var crossing := from.lerp(to, share)
	return crossing.distance_to(net.nearest_silk(crossing)) <= _size * 2.0


# --- what you can see ----------------------------------------------------

func _build_view() -> void:
	_bead = SphereMesh.new()
	_bead.radius = 1.0
	_bead.height = 2.0
	_bead.radial_segments = 8
	_bead.rings = 4
	_paint = StandardMaterial3D.new()
	_paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_paint.albedo_color = Color(colour.r, colour.g, colour.b, 0.8)


func _drop_view() -> MeshInstance3D:
	var view := MeshInstance3D.new()
	view.name = "Drop"
	view.mesh = _bead
	view.material_override = _paint
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.top_level = true
	add_child(view)
	return view


## A drop drawn where it is, drawn out a little along the way it is going.
func _place(drop: Drop) -> void:
	var going := drop.speed + Vector3.DOWN * _fall * drop.age
	var turn := Basis.IDENTITY
	if going.length_squared() > 0.000001:
		var ahead := going.normalized()
		turn = Basis.looking_at(ahead, Vector3.UP if absf(ahead.y) < 0.99 else Vector3.FORWARD)
	drop.view.global_transform = Transform3D(turn * Basis.from_scale(Vector3(_size, _size,
		_size * 2.2)), drop.at)


func _splash(point: Vector3) -> void:
	SpellFlash.burst(get_parent(), point, colour, _size * 4.0, 0.25)
