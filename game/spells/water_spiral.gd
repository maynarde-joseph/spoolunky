class_name WaterSpiral
extends Node3D

## A whirl of water and wind: a funnel of water turning on its point, with streaks
## of spray round it to show which way. It rises where it is cast, spins for a
## moment and sinks away. Cast at a prep table it washes what is on it — see
## [SpiderSpells]. Looks only.
##
## It was once lifted out of a puddle by a gust; now it is a spell of its own.

const GROUP := "water_spirals"

## How fast it turns, in radians a second.
const SWIRL := 9.0

## How long it takes to rise, and to sink away, in seconds.
const RISE := 0.15
const FADE := 0.35

## How much of the spray round it shows.
const STREAK_ALPHA := 0.6

## How wide it is, from the middle to the rim, in metres, and how long it spins.
var radius := 1.0
var spins := 1.0

var colour := Color(0.36, 0.74, 0.9, 1.0)

var _age := 0.0
var _view: Node3D
var _water: StandardMaterial3D
var _streaks: StandardMaterial3D


## Raises one under [param host] standing on [param at], [param wide] metres from
## the middle to the rim, spinning for [param seconds].
static func rise(host: Node, at: Vector3, wide: float, seconds := 1.0,
		tint := Color(0.36, 0.74, 0.9, 1.0)) -> WaterSpiral:
	if host == null:
		return null
	var whirl := WaterSpiral.new()
	whirl.name = "WaterSpiral"
	whirl.radius = maxf(wide, 0.05)
	whirl.spins = maxf(seconds, 0.1)
	whirl.colour = tint
	whirl.add_to_group(GROUP)
	whirl.add_to_group("spell_effects")
	host.add_child(whirl)
	whirl.global_position = at
	return whirl


## Whether it is still spinning; after this it sinks away.
func spinning() -> bool:
	return _age < spins


func _ready() -> void:
	_build_view()


func _process(delta: float) -> void:
	_age += delta
	if _age >= spins + FADE:
		queue_free()
		return
	_view.rotate_y(-SWIRL * delta)
	var rising := clampf(_age / RISE, 0.0, 1.0)
	var sinking := clampf((_age - spins) / FADE, 0.0, 1.0)
	var height := rising * (1.0 - sinking)
	_view.scale = Vector3(radius, radius * maxf(height, 0.02), radius)
	_water.albedo_color.a = 0.28 * (1.0 - sinking)
	_streaks.albedo_color.a = STREAK_ALPHA * (1.0 - sinking)


## A funnel of water with three arms of spray spiralling down it. Built at a radius
## of one and scaled, so its size is one number.
func _build_view() -> void:
	_view = Node3D.new()
	_view.name = "View"
	add_child(_view)
	_view.scale = Vector3(radius, radius * 0.02, radius)
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
