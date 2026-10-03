class_name WetGround
extends Node3D

## A puddle: where a drop of the spider's water came down on the ground.
##
## Everything standing in it stays soaked while it lasts, and soaked carries
## lightning twice as hard and on to anything wet near it — see [LightningStrike].
## A drop that comes down in one already there makes it bigger rather than making
## another, so a spit lands as a few puddles, not a dozen. It dries off in a few
## seconds — see [WaterSpit].
##
## Wind blown over it lifts it into a whirl, and the ground it came from is dry
## again — see [Gust] and [WaterSpiral].

const GROUP := "wet_ground"

## How long a creature stays soaked once it is off it, in seconds.
const SOAK := 4.0

## How often it soaks what is standing in it, in seconds.
const PULSE := 0.25

## How long it takes to dry off at the end, in seconds.
const FADE := 1.0

## How dark and how clear the wet looks, at its wettest.
const SHEEN := 0.5

## How much bigger drops coming down in it can make it, as a share of how wide it
## started: a pool, not a lake.
const POOL := 2.0

## Its middle, which way is up from the ground it is on, and how wide it is from the
## middle to the rim, in metres — now, and when the first drop made it.
var centre := Vector3.ZERO
var up := Vector3.UP
var radius := 0.1
var first_radius := 0.1

## How long it stays wet, in seconds from when it was made.
var life := 10.0

var colour := Color(0.36, 0.74, 0.9, 1.0)

var _age := 0.0
var _pulse := 0.0
var _dry_at := -1.0
var _paint: StandardMaterial3D
var _sheen: MeshInstance3D


## Leaves a puddle under [param host] at [param at], on ground facing
## [param normal], [param wide] metres from the middle to the rim and wet for
## [param lasts] seconds.
static func puddle(host: Node, at: Vector3, normal: Vector3, wide: float, lasts: float,
		tint := Color(0.36, 0.74, 0.9, 1.0)) -> WetGround:
	if host == null or wide <= 0.0:
		return null
	var wet := WetGround.new()
	wet.name = "WetGround"
	wet.centre = at
	wet.up = normal.normalized() if normal.length_squared() > 0.000001 else Vector3.UP
	wet.radius = wide
	wet.first_radius = wide
	wet.life = maxf(lasts, 0.1)
	wet.colour = tint
	wet.add_to_group(GROUP)
	wet.add_to_group("spell_effects")
	host.add_child(wet)
	wet.global_transform = MagicCircle.facing(at, wet.up)
	wet._build_view()
	return wet


## Whether it is still wet.
func is_wet() -> bool:
	return _dry_at < 0.0


## Whether [param point] is in it — inside its rim, and down at the ground rather
## than above it — within [param margin], while it is still wet.
func holds(point: Vector3, margin := 0.0) -> bool:
	if not is_wet():
		return false
	var off := point - centre
	var rise := off.dot(up)
	if rise < -radius - margin or rise > radius + margin * 2.0:
		return false
	return (off - up * rise).length() <= radius + margin


## Whether a lane of wind blown from [param from] along [param toward], out to
## [param far] metres and [param half_width] either side, passes over it.
func met_by(from: Vector3, toward: Vector3, far: float, half_width: float) -> bool:
	if not is_wet() or not Gust.in_lane(centre, from, toward, far, half_width, radius):
		return false
	var rise := centre.y - from.y
	return rise >= -far * Gust.REACH_DOWN - radius and rise <= far * Gust.REACH_UP + radius


## Another drop came down in it: it spreads, up to [constant POOL] times as wide as
## it started, and stays wet [param lasts] seconds from now if that is longer.
## [param wide] is how wide a puddle the drop would have left on its own.
func swell(wide: float, lasts: float) -> void:
	if not is_wet():
		return
	radius = minf(sqrt(radius * radius + wide * wide), first_radius * POOL)
	life = maxf(life, _age + lasts)
	if _sheen != null:
		_sheen.scale = Vector3(radius, 1.0, radius)


## The wind took it: it dries off now.
func dry() -> void:
	if is_wet():
		_dry_at = _age


func _physics_process(delta: float) -> void:
	_age += delta
	if not is_wet():
		if _age >= _dry_at + FADE:
			queue_free()
		return
	if _age >= life:
		dry()
		return
	_pulse -= delta
	if _pulse > 0.0:
		return
	_pulse = PULSE
	for node in get_tree().get_nodes_in_group("prey"):
		var creature := node as Prey
		if creature != null and is_instance_valid(creature) and not creature.eaten \
				and holds(creature.global_position, creature.hit_radius()):
			creature.soak(SOAK)


func _process(_delta: float) -> void:
	if _paint == null:
		return
	var shown := 1.0
	if not is_wet():
		shown = 1.0 - clampf((_age - _dry_at) / FADE, 0.0, 1.0)
	elif life - _age < FADE:
		shown = clampf((life - _age) / FADE, 0.0, 1.0)
	_paint.albedo_color.a = SHEEN * shown


# --- what you can see ----------------------------------------------------

## A dark sheen on the ground, round but not quite — a puddle, not a coin — laid
## on the ground a hair above it.
func _build_view() -> void:
	_paint = StandardMaterial3D.new()
	_paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	_paint.albedo_color = Color(colour.r * 0.45, colour.g * 0.55, colour.b * 0.7, SHEEN)
	var sides := 18
	var lumps := randf() * TAU
	var rim := PackedVector3Array()
	for i in sides:
		var turn := TAU * float(i) / float(sides)
		var out := 1.0 + 0.08 * sin(turn * 3.0 + lumps) + 0.05 * sin(turn * 5.0 + lumps * 2.0)
		rim.append(Vector3(cos(turn) * out, 0.0, sin(turn) * out))
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in sides:
		tool.add_vertex(Vector3.ZERO)
		tool.add_vertex(rim[i])
		tool.add_vertex(rim[(i + 1) % sides])
	_sheen = MeshInstance3D.new()
	_sheen.name = "Sheen"
	_sheen.mesh = tool.commit()
	_sheen.material_override = _paint
	_sheen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sheen.position = Vector3.UP * maxf(radius * 0.04, 0.003)
	_sheen.scale = Vector3(radius, 1.0, radius)
	add_child(_sheen)
