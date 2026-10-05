class_name LightningStrike
extends Node3D

## Lightning, called down where the spider pointed: a crooked bolt out of the sky,
## a few short forks off it, and a flash that lights the farm for a moment. What it does
## to the flies it strikes is the spell's — see [SpiderSpells].

const GROUP := "lightning"

## How long the bolt is on screen, in seconds.
const SHOWN := 0.35

## How bright the flash is, at its brightest.
const FLASH := 3.0

## How far above the strike the bolt comes down from, in radii — and in metres,
## at the least.
const FALL := 5.0
const FALL_LEAST := 3.0

## How wide it strikes, in metres.
var radius := 1.0
var colour := Color(0.98, 0.92, 0.55, 1.0)

var _age := 0.0
var _material: StandardMaterial3D
var _light: OmniLight3D


## Calls one down at [param at] under [param host], [param wide] metres across.
static func call_down(host: Node, at: Vector3, wide: float,
		tint := Color(0.98, 0.92, 0.55, 1.0)) -> LightningStrike:
	if host == null:
		return null
	var strike := LightningStrike.new()
	strike.name = "LightningStrike"
	strike.radius = maxf(wide, 0.05)
	strike.colour = tint
	strike.add_to_group(GROUP)
	strike.add_to_group("spell_effects")
	host.add_child(strike)
	strike.global_position = at
	strike._build_view()
	return strike


func _process(delta: float) -> void:
	_age += delta
	var left := clampf(1.0 - _age / SHOWN, 0.0, 1.0)
	if _material != null:
		_material.albedo_color.a = left
	if _light != null:
		_light.light_energy = FLASH * left
	if _age >= SHOWN:
		queue_free()


func _build_view() -> void:
	var at := global_position
	var width := maxf(radius * 0.03, 0.008)
	var strands := WebGeometry.StrandSet.new()
	var drop := maxf(radius * FALL, FALL_LEAST)
	var top := at + Vector3.UP * drop
	zigzag(strands, top, at, 14, drop * 0.05, width * 1.5)
	for fork in 2:
		var from := top.lerp(at, 0.35 + 0.25 * float(fork))
		var out := Vector3(randf_range(-1.0, 1.0), -0.6, randf_range(-1.0, 1.0)).normalized()
		zigzag(strands, from, from + out * drop * 0.18, 4, drop * 0.02, width)
	# Crackling out across whatever it struck.
	for i in 5:
		var turn := TAU * float(i) / 5.0 + randf() * 0.5
		var out := Vector3(cos(turn), 0.0, sin(turn)) * radius * randf_range(0.5, 0.9)
		zigzag(strands, at, at + out + Vector3.UP * radius * 0.05, 4, radius * 0.08, width * 0.7)
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.vertex_color_use_as_albedo = true
	_material.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	var bolt := MeshInstance3D.new()
	bolt.name = "Bolt"
	bolt.mesh = WebGeometry.build_mesh(strands, colour)
	bolt.material_override = _material
	bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bolt.top_level = true
	add_child(bolt)
	bolt.global_transform = Transform3D.IDENTITY
	_light = OmniLight3D.new()
	_light.name = "Flash"
	_light.light_color = colour
	_light.light_energy = FLASH
	_light.omni_range = radius * 4.0
	add_child(_light)
	_light.position = Vector3.UP * radius * 0.5
	SpellFlash.burst(get_parent(), at, colour, radius * 0.6, 0.25)


## A crooked line from [param from] to [param to] in [param pieces] pieces, each
## bend up to [param wander] off the straight: what a charge looks like going
## somewhere.
static func zigzag(strands: WebGeometry.StrandSet, from: Vector3, to: Vector3, pieces: int,
		wander: float, width: float) -> void:
	var span := to - from
	if span.length_squared() < 0.000001:
		return
	var axis := span.normalized()
	var side := axis.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = axis.cross(Vector3.RIGHT)
	side = side.normalized()
	var other := axis.cross(side).normalized()
	var previous := from
	for i in range(1, pieces + 1):
		var t := float(i) / float(pieces)
		var point := from + span * t
		if i < pieces:
			point += side * randf_range(-wander, wander) + other * randf_range(-wander, wander)
		strands.add(previous, point, width)
		previous = point
