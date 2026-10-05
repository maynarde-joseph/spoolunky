class_name Site
extends RefCounted

## What every place has besides what is built in it: a sky, ground to stand on,
## and the spider with its HUD.
##
## Each place is its own scene, built by a class of its own and baked by
## `tools/bake_level.gd`. There is one now: the farm ([FarmLand]). Open it and press
## F6 to walk about in it.

## The places, by the name the bake knows them by, and the class that builds each.
const PLACES := {
	"farm": "res://game/world/farm_land.gd",
}

## Skies. Each holds the light down a little, so the shade between faces shows
## the shape of things.
const MOODS := {
	# A clear afternoon.
	"clear": {
		"top": Color(0.36, 0.52, 0.76), "horizon": Color(0.72, 0.77, 0.82),
		"low": Color(0.48, 0.58, 0.44), "far": Color(0.64, 0.71, 0.66),
		"ambient": Color(0.62, 0.68, 0.78), "ambient_energy": 0.32,
		"sun": Color(1.0, 0.93, 0.82), "sun_energy": 0.8, "sun_from": Vector3(-60.0, 90.0, 45.0),
		"fog": Color(0.66, 0.72, 0.8), "fog_density": 0.002,
	},
	# A bright morning with a long way to see.
	"bright": {
		"top": Color(0.3, 0.52, 0.84), "horizon": Color(0.75, 0.82, 0.9),
		"low": Color(0.46, 0.58, 0.42), "far": Color(0.66, 0.74, 0.72),
		"ambient": Color(0.62, 0.7, 0.8), "ambient_energy": 0.34,
		"sun": Color(1.0, 0.96, 0.88), "sun_energy": 0.85, "sun_from": Vector3(60.0, 80.0, 40.0),
		"fog": Color(0.7, 0.78, 0.86), "fog_density": 0.0015,
	},
	# Underground: no sky to speak of, only what comes down a shaft and the rooms'
	# own fires — and a haze in the air the length of a room.
	"deep": {
		"top": Color(0.07, 0.08, 0.1), "horizon": Color(0.12, 0.13, 0.16),
		"low": Color(0.05, 0.05, 0.06), "far": Color(0.09, 0.09, 0.11),
		"ambient": Color(0.55, 0.6, 0.74), "ambient_energy": 0.42,
		"sun": Color(0.8, 0.86, 1.0), "sun_energy": 0.7, "sun_from": Vector3(15.0, 100.0, 10.0),
		"fog": Color(0.07, 0.07, 0.09), "fog_density": 0.012,
	},
}

## How far out the ground goes from the middle, every way: far enough that the
## haze has it before its edge shows.
const GROUND := 1000.0


## The class that builds the place called [param place].
static func builder(place: String) -> Script:
	return load(PLACES[place]) as Script if PLACES.has(place) else null


## The sky called [param mood] from [constant MOODS], and its sun.
static func sky(level: Node3D, mood: String) -> void:
	var look: Dictionary = MOODS[mood]
	var sky_paint := ProceduralSkyMaterial.new()
	sky_paint.sky_top_color = look["top"]
	sky_paint.sky_horizon_color = look["horizon"]
	# Below the horizon the sky is the colour of ground seen through haze, so the
	# ground meets it rather than stopping at an edge.
	sky_paint.ground_bottom_color = look["low"]
	sky_paint.ground_horizon_color = look["far"]
	sky_paint.sun_angle_max = 18.0
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.sky.sky_material = sky_paint
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = look["ambient"]
	environment.ambient_light_energy = look["ambient_energy"]
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.85
	environment.ssao_enabled = true
	environment.fog_enabled = true
	environment.fog_light_color = look["fog"]
	environment.fog_density = look["fog_density"]
	environment.fog_sky_affect = 0.1
	var world := WorldEnvironment.new()
	world.name = "Sky"
	world.environment = environment
	level.add_child(world)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = look["sun"]
	sun.light_energy = look["sun_energy"]
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 160.0
	var from: Vector3 = look["sun_from"]
	sun.transform = Transform3D(Basis.looking_at(-from, Vector3.UP), from)
	level.add_child(sun)


## Ground all the way out, under everything, its top at nought — with a hole in it
## where [param hole] says, if it says anywhere: a rectangle across the ground, in
## metres east and south of the middle.
static func ground(level: Node3D, paint := "grass", hole := Rect2()) -> StaticBody3D:
	var body := WorldKit.body(level, "Ground")
	for part in cut(Rect2(-GROUND, -GROUND, GROUND * 2.0, GROUND * 2.0), hole):
		var middle := part.get_center()
		WorldKit.box(body, "Earth%d" % (body.get_child_count() / 2 + 1),
			Vector3(part.size.x, 1.0, part.size.y), WorldKit.at(Vector3(middle.x, -0.5, middle.y)),
			paint)
	return body


## [param whole] with [param hole] taken out of it, as the four rectangles round the
## hole — or [param whole] itself, if the hole is empty.
static func cut(whole: Rect2, hole: Rect2) -> Array[Rect2]:
	if not hole.has_area():
		return [whole]
	var parts: Array[Rect2] = [
		Rect2(whole.position.x, whole.position.y, whole.size.x, hole.position.y - whole.position.y),
		Rect2(whole.position.x, hole.end.y, whole.size.x, whole.end.y - hole.end.y),
		Rect2(whole.position.x, hole.position.y, hole.position.x - whole.position.x, hole.size.y),
		Rect2(hole.end.x, hole.position.y, whole.end.x - hole.end.x, hole.size.y),
	]
	return parts.filter(func(part: Rect2) -> bool: return part.has_area())


## A floor of [param paint], [param size] across, its top a hair above the ground at
## [param centre] — with a hole in it where [param hole] says, if it says anywhere.
static func floor_of(parent: Node3D, part_name: String, size: Vector2, centre: Vector3,
		paint: String, hole := Rect2()) -> StaticBody3D:
	var body := WorldKit.body(parent, part_name)
	var whole := Rect2(centre.x - size.x * 0.5, centre.z - size.y * 0.5, size.x, size.y)
	for part in cut(whole, hole):
		var middle := part.get_center()
		WorldKit.box(body, "%sTop%d" % [part_name, body.get_child_count() / 2 + 1],
			Vector3(part.size.x, 0.1, part.size.y),
			WorldKit.at(Vector3(middle.x, centre.y - 0.04, middle.y)), paint)
	return body


## The spider at [param start], turned [param turn] degrees from facing north, and
## the HUD.
static func spider(level: Node3D, start: Vector3, turn := 0.0) -> SpiderPlayer:
	var spider_body := (load("res://game/player/spider.tscn") as PackedScene).instantiate() as SpiderPlayer
	spider_body.name = "Player"
	spider_body.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(turn)), start)
	level.add_child(spider_body)
	var hud := (load("res://game/ui/hud.tscn") as PackedScene).instantiate()
	hud.name = "HUD"
	level.add_child(hud)
	return spider_body
