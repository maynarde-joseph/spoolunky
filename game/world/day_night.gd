class_name DayNight
extends Node

## The light of the day the [Ecosystem] keeps: the sun going over, the moon after
## it, and the sky going with them.
##
## A level's sky and sun are ordinary nodes — a [WorldEnvironment] and a
## [DirectionalLight3D] — so they can be seen and moved in the editor like
## anything else, and this drives them from the ecosystem's clock. The sun is
## where the hour puts it and the colour the hour makes it: white overhead, low
## and orange at either end of the day, and gone at night. Then the moon is up in
## its place, dim and blue, and what glows of its own — the glowcaps in a cave,
## the spells — is what a spider sees by.
##
## The colours the level was built with are its noon. Night and the ends of the
## day are worked out from them, so a level only has to say what its sky looks
## like at its best.
##
## Without an ecosystem it leaves the light alone: a level that does not keep
## time is always the hour it was built at.

## How often the sky's colours are worked out again, in seconds. The lights move
## every frame — that is cheap, and a shadow that jumps is worse than one that
## crawls — but a sky that changes has to be drawn again, all the way round.
const SKY_EVERY := 0.5

## What it drives. Found by itself if left empty: the first sky and the first sun
## in the level.
@export var sky: WorldEnvironment
@export var sun: DirectionalLight3D

## Which way the sun goes over. It comes up in the east, goes over leaning this
## far to the south, in degrees, and goes down in the west — with east turned to
## [member heading], in degrees about the vertical, for a level that wants the
## sunrise somewhere else.
@export_range(0.0, 80.0) var lean := 30.0
@export_range(-180.0, 180.0) var heading := 0.0

## How bright the moon is at its highest, and its colour.
@export var moon_energy := 0.28
@export var moon_colour := Color(0.7, 0.78, 1.0)

## How big the sun and the moon look in the sky, in degrees across, and how bright
## the moon's face is.
@export var sun_size := 2.2
@export var moon_size := 1.8
@export var moon_face := 0.55

## The sun's colour low down, at either end of the day.
@export var low_sun := Color(1.0, 0.6, 0.36)

## The sky at night, top and horizon, and the sky at the ends of the day.
@export var night_top := Color(0.02, 0.03, 0.07)
@export var night_horizon := Color(0.05, 0.07, 0.14)
@export var dusk_top := Color(0.24, 0.26, 0.45)
@export var dusk_horizon := Color(0.92, 0.52, 0.3)

## The light from everywhere at night, against noon's: dimmer and bluer, but never
## so dark that a spider cannot see where it is going.
@export var night_ambient := Color(0.36, 0.44, 0.7)
@export_range(0.0, 1.0) var night_ambient_share := 0.55

## How strongly what glows blooms at night, and by day.
@export var night_glow := 0.9
@export var day_glow := 0.2

var moon: DirectionalLight3D

## What draws the sun and the moon in the sky. Not the lights themselves: a sky
## draws a light's disc as bright as the light, so a sun dimming as it sets went
## down as a black hole in an orange sky. These stay bright to the horizon and
## light nothing.
var sun_disc: DirectionalLight3D
var moon_disc: DirectionalLight3D

var _noon := {}
var _sky_in := 0.0
var _world: Ecosystem


func _ready() -> void:
	_find()
	_world = Ecosystem.of(self)
	if _world == null or sun == null:
		return
	_remember_noon()
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	moon = _light("Moon", moon_colour, DirectionalLight3D.SKY_MODE_LIGHT_ONLY)
	moon.directional_shadow_max_distance = sun.directional_shadow_max_distance
	sun_disc = _light("SunDisc", Color.WHITE, DirectionalLight3D.SKY_MODE_SKY_ONLY)
	sun_disc.light_angular_distance = sun_size * 0.5
	moon_disc = _light("MoonDisc", moon_colour.lerp(Color.WHITE, 0.5),
		DirectionalLight3D.SKY_MODE_SKY_ONLY)
	moon_disc.light_angular_distance = moon_size * 0.5
	if sky != null and sky.environment != null:
		sky.environment.glow_enabled = true
	show_hour(true)


func _process(delta: float) -> void:
	if _world == null or not is_instance_valid(_world) or sun == null:
		return
	_sky_in -= delta
	show_hour(_sky_in <= 0.0)


## Puts the lights where the hour says, and the sky's colours too when
## [param sky_too] — which is every [constant SKY_EVERY] seconds, and at once for
## a check that has just moved the clock.
func show_hour(sky_too := true) -> void:
	if _world == null or sun == null:
		return
	var up := toward_sun(_world.time_of_day)
	var high := up.y
	_aim(sun, up)
	_aim(moon, -up)
	_aim(sun_disc, up)
	_aim(moon_disc, -up)
	var day := smoothstep(-0.05, 0.25, high)
	sun.light_energy = _noon.get("sun_energy", 1.0) * day
	sun.light_color = low_sun.lerp(_noon.get("sun_colour", Color.WHITE),
		smoothstep(0.0, 0.45, high))
	moon.light_energy = moon_energy * smoothstep(-0.05, 0.25, -high)
	# Bright right down to the horizon, and out once they are under it.
	sun_disc.light_color = sun.light_color
	sun_disc.light_energy = smoothstep(-0.06, 0.02, high)
	moon_disc.light_energy = moon_face * smoothstep(-0.06, 0.02, -high)
	# Shadows from one of them at a time: whichever is up.
	var sun_up := high > -0.02
	if sun.shadow_enabled != (sun_up and _noon.get("shadows", true)):
		sun.shadow_enabled = sun_up and _noon.get("shadows", true)
	if moon.shadow_enabled != (not sun_up and _noon.get("shadows", true)):
		moon.shadow_enabled = not sun_up and _noon.get("shadows", true)
	if sky_too:
		_sky_in = SKY_EVERY
		_colour_the_sky(high)


## Which way the sun is at [param time] of day: a unit vector from the ground
## towards it, under the horizon at night.
func toward_sun(time: float) -> Vector3:
	# The hour angle: nought at noon, a quarter turn either side at sunrise and
	# sunset.
	var hour := (time - 0.5) * TAU
	var arc := Vector3(-sin(hour), cos(hour), 0.0)
	var leaning := Basis(Vector3.RIGHT, deg_to_rad(lean)) * arc
	return (Basis(Vector3.UP, deg_to_rad(heading)) * leaning).normalized()


## A light of its own, made at run time and kept off the level's list of nodes, so
## a bake never saves it.
func _light(light_name: String, colour: Color, mode: DirectionalLight3D.SkyMode) \
		-> DirectionalLight3D:
	var light := DirectionalLight3D.new()
	light.name = light_name
	light.light_color = colour
	light.light_energy = 0.0
	light.shadow_enabled = false
	light.sky_mode = mode
	add_child(light, false, Node.INTERNAL_MODE_FRONT)
	return light


func _aim(light: DirectionalLight3D, up: Vector3) -> void:
	if light == null:
		return
	# A light shines down its own -Z, so it looks away from where it is in the sky.
	var side := Vector3.UP if absf(up.dot(Vector3.UP)) < 0.98 else Vector3.BACK
	light.global_basis = Basis.looking_at(-up, side)


func _colour_the_sky(high: float) -> void:
	if sky == null or sky.environment == null:
		return
	var environment := sky.environment
	var day := smoothstep(-0.18, 0.3, high)
	var low := clampf(1.0 - absf(high + 0.02) / 0.28, 0.0, 1.0)
	var material := _sky_material()
	if material != null:
		var top: Color = night_top.lerp(_noon.get("top", material.sky_top_color), day)
		var horizon: Color = night_horizon.lerp(_noon.get("horizon", material.sky_horizon_color),
			day)
		material.sky_top_color = top.lerp(dusk_top, low * 0.45)
		material.sky_horizon_color = horizon.lerp(dusk_horizon, low * 0.7)
		var dim := lerpf(0.12, 1.0, day)
		material.ground_horizon_color = (_noon.get("ground_horizon", Color.GRAY) as Color) * dim
		material.ground_bottom_color = (_noon.get("ground_bottom", Color.GRAY) as Color) * dim
	var noon_ambient: Color = _noon.get("ambient", Color.WHITE)
	environment.ambient_light_color = night_ambient.lerp(noon_ambient, day)
	environment.ambient_light_energy = lerpf(night_ambient_share, 1.0, day) \
		* _noon.get("ambient_energy", 0.35)
	environment.glow_intensity = lerpf(night_glow, day_glow, day)
	if environment.fog_enabled:
		var fog: Color = _noon.get("fog", environment.fog_light_color)
		var dusky := fog.lerp(dusk_horizon, low * 0.5)
		environment.fog_light_color = night_horizon.lerp(dusky, day)


func _sky_material() -> ProceduralSkyMaterial:
	if sky == null or sky.environment == null or sky.environment.sky == null:
		return null
	return sky.environment.sky.sky_material as ProceduralSkyMaterial


## Keeps what the level was built with, as its noon.
func _remember_noon() -> void:
	_noon["sun_energy"] = sun.light_energy
	_noon["sun_colour"] = sun.light_color
	_noon["shadows"] = sun.shadow_enabled
	if sky == null or sky.environment == null:
		return
	var environment := sky.environment
	_noon["ambient"] = environment.ambient_light_color
	_noon["ambient_energy"] = environment.ambient_light_energy
	_noon["fog"] = environment.fog_light_color
	var material := _sky_material()
	if material != null:
		_noon["top"] = material.sky_top_color
		_noon["horizon"] = material.sky_horizon_color
		_noon["ground_horizon"] = material.ground_horizon_color
		_noon["ground_bottom"] = material.ground_bottom_color


## Fills in whatever was left empty: the first sky and the first sun in the level.
func _find() -> void:
	var level := owner if owner != null else get_parent()
	if level == null:
		return
	if sky == null:
		sky = _first(level, "WorldEnvironment") as WorldEnvironment
	if sun == null:
		sun = _first(level, "DirectionalLight3D") as DirectionalLight3D


static func _first(under: Node, type: String) -> Node:
	for child in under.get_children():
		if child.is_class(type):
			return child
		var deeper := _first(child, type)
		if deeper != null:
			return deeper
	return null
