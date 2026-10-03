class_name Site
extends RefCounted

## What every place built from the kit has besides its stones: a sky, ground to
## stand on, the spider with its HUD and somewhere for its webs, and a name for the
## HUD to show. And the few shapes more than one of them is laid out with — the
## side of a square, the segments of an oval — and the rubble an abandoned place
## is strewn with.
##
## Each place is its own scene, built by a class of its own ([Temple], [Colosseum],
## [Cathedral], [Castle], [Aqueduct], [Watchtower]) and baked by
## `tools/bake_level.gd`. Open one and press F6 to walk about in it.

## The places, by the name the bake knows them by, and the class that builds each.
const PLACES := {
	"colosseum": "res://game/world/colosseum.gd",
	"cathedral": "res://game/world/cathedral.gd",
	"castle": "res://game/world/castle.gd",
	"aqueduct": "res://game/world/aqueduct.gd",
	"watchtower": "res://game/world/watchtower.gd",
	"temple": "res://game/world/temple.gd",
}

## Skies. The kit is pure white, and pure white under a full sun and a full sky
## shows no shading at all — every face comes out the same — so every one of these
## holds the light down and lets the shade between faces show the shape.
const MOODS := {
	# A clear afternoon.
	"clear": {
		"top": Color(0.36, 0.52, 0.76), "horizon": Color(0.72, 0.77, 0.82),
		"low": Color(0.48, 0.58, 0.44), "far": Color(0.64, 0.71, 0.66),
		"ambient": Color(0.62, 0.68, 0.78), "ambient_energy": 0.32,
		"sun": Color(1.0, 0.93, 0.82), "sun_energy": 0.8, "sun_from": Vector3(-60.0, 90.0, 45.0),
		"fog": Color(0.66, 0.72, 0.8), "fog_density": 0.002,
	},
	# Late in a hot day: the sun low in the west, dust in the air.
	"warm": {
		"top": Color(0.34, 0.5, 0.76), "horizon": Color(0.82, 0.76, 0.66),
		"low": Color(0.56, 0.56, 0.42), "far": Color(0.76, 0.72, 0.62),
		"ambient": Color(0.7, 0.66, 0.62), "ambient_energy": 0.3,
		"sun": Color(1.0, 0.86, 0.68), "sun_energy": 0.85, "sun_from": Vector3(-80.0, 55.0, 25.0),
		"fog": Color(0.8, 0.74, 0.64), "fog_density": 0.0018,
	},
	# A grey sky that is going to rain: flat light, the far end lost in haze.
	"overcast": {
		"top": Color(0.42, 0.46, 0.52), "horizon": Color(0.62, 0.64, 0.66),
		"low": Color(0.4, 0.44, 0.4), "far": Color(0.58, 0.6, 0.6),
		"ambient": Color(0.68, 0.7, 0.76), "ambient_energy": 0.5,
		"sun": Color(0.9, 0.92, 1.0), "sun_energy": 0.45, "sun_from": Vector3(20.0, 100.0, -30.0),
		"fog": Color(0.6, 0.62, 0.66), "fog_density": 0.004,
	},
	# The sun going down red behind something that burned.
	"dusk": {
		"top": Color(0.28, 0.32, 0.5), "horizon": Color(0.9, 0.6, 0.44),
		"low": Color(0.38, 0.34, 0.3), "far": Color(0.7, 0.54, 0.46),
		"ambient": Color(0.52, 0.46, 0.56), "ambient_energy": 0.36,
		"sun": Color(1.0, 0.66, 0.42), "sun_energy": 0.85, "sun_from": Vector3(-100.0, 26.0, -40.0),
		"fog": Color(0.74, 0.55, 0.46), "fog_density": 0.003,
	},
	# A bright morning with a long way to see.
	"bright": {
		"top": Color(0.3, 0.52, 0.84), "horizon": Color(0.75, 0.82, 0.9),
		"low": Color(0.46, 0.58, 0.42), "far": Color(0.66, 0.74, 0.72),
		"ambient": Color(0.62, 0.7, 0.8), "ambient_energy": 0.34,
		"sun": Color(1.0, 0.96, 0.88), "sun_energy": 0.85, "sun_from": Vector3(60.0, 80.0, 40.0),
		"fog": Color(0.7, 0.78, 0.86), "fog_density": 0.0015,
	},
	# High and pale, with the wind taking the colour out of everything.
	"windy": {
		"top": Color(0.5, 0.62, 0.78), "horizon": Color(0.8, 0.84, 0.86),
		"low": Color(0.52, 0.6, 0.5), "far": Color(0.74, 0.78, 0.78),
		"ambient": Color(0.7, 0.74, 0.8), "ambient_energy": 0.3,
		"sun": Color(1.0, 0.97, 0.92), "sun_energy": 0.75, "sun_from": Vector3(80.0, 55.0, -10.0),
		"fog": Color(0.78, 0.82, 0.86), "fog_density": 0.0018,
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


## The spider at [param start], turned [param turn] degrees from facing north, held
## at one size with every spell open; the HUD; and a home for its webs.
static func spider(level: Node3D, start: Vector3, turn := 0.0) -> SpiderPlayer:
	var webs := Node3D.new()
	webs.name = "Webs"
	level.add_child(webs)
	var spider_body := (load("res://game/player/spider.tscn") as PackedScene).instantiate() as SpiderPlayer
	spider_body.name = "Player"
	spider_body.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(turn)), start)
	spider_body.grows_by_eating = false
	spider_body.start_stage = 2
	spider_body.evolves_by_eating = false
	spider_body.all_spells_open = true
	level.add_child(spider_body)
	var hud := (load("res://game/ui/hud.tscn") as PackedScene).instantiate()
	hud.name = "HUD"
	level.add_child(hud)
	return spider_body


## The place's name, for the HUD to show on the way in, claiming everything within
## [param half] of the middle across and up to [param high] above the ground.
static func zone(level: Node3D, place_name: String, half: Vector2, high: float) -> Zone:
	return Zone.make(level, place_name, Vector3(-half.x, -6.0, -half.y),
		Vector3(half.x, high, half.y), Vector2.ZERO)


# --- shapes to lay things out on --------------------------------------------

## Where a point on the side facing [param facing] is — [param along] it, [param out]
## from the middle and [param up] off the ground — turned so that a piece put there
## runs along the side with its back to the outside. A piece's own -Z is outward.
static func frame(facing: Vector3, along: float, out: float, up: float) -> Transform3D:
	var turn := Basis(Vector3.UP, atan2(-facing.x, -facing.z))
	var side := turn * Vector3.RIGHT
	return Transform3D(turn, facing * out + side * along + Vector3.UP * up)


## An oval [param across] by [param deep] — its half-widths east-west and
## north-south — cut into [param count] straight segments of the same length, the
## first centred on the east end; with a count that four divides, there is one
## centred on each end and each side. Each segment is its middle, its two ends, its
## length, which way is out from the middle, which way it runs, the turn that lines
## a piece up with it (its length along the segment, its back outward), and the
## bearing of its middle round the oval, in degrees from east towards south.
static func oval(across: float, deep: float, count: int) -> Array[Dictionary]:
	# Walk the curve in small steps, keeping the distance gone, and cut it every
	# so far along — equal lengths, rather than equal angles, so the tight ends of
	# a long oval are not cut into slivers.
	var steps := 1440
	var points: Array[Vector3] = []
	var gone: Array[float] = [0.0]
	for i in steps + 1:
		var turn := TAU * float(i) / float(steps)
		points.append(Vector3(cos(turn) * across, 0.0, sin(turn) * deep))
		if i > 0:
			gone.append(gone[i - 1] + points[i].distance_to(points[i - 1]))
	var total := gone[steps]
	var corners: Array[Vector3] = []
	var j := 0
	for k in count:
		var at := fposmod((float(k) - 0.5) * total / float(count), total)
		j = 0 if at < gone[j] else j
		while j < steps and gone[j + 1] < at:
			j += 1
		var share := (at - gone[j]) / maxf(gone[j + 1] - gone[j], 0.000001)
		corners.append(points[j].lerp(points[j + 1], share))
	var segments: Array[Dictionary] = []
	for k in count:
		var a := corners[k]
		var b := corners[(k + 1) % count]
		var middle := (a + b) * 0.5
		var run := (b - a).normalized()
		var out := Vector3.UP.cross(run)
		if out.dot(middle) < 0.0:
			out = -out
		var along := out.cross(Vector3.UP)
		segments.append({
			"middle": middle,
			"from": a,
			"to": b,
			"length": a.distance_to(b),
			"out": out,
			"along": along,
			"basis": Basis(along, Vector3.UP, -out),
			"bearing": fposmod(rad_to_deg(atan2(middle.z, middle.x)), 360.0),
		})
	return segments


# --- what an abandoned place is strewn with ---------------------------------

## A heap of fallen stone round [param centre]: [param count] blocks of the kit's
## wall, none bigger than [param biggest] a side, lying where they fell within
## [param spread] of it — tipped, turned and half sunk.
static func rubble(parent: Node3D, rng: RandomNumberGenerator, centre: Vector3, spread: float,
		count: int, biggest := 1.6) -> void:
	for i in count:
		var size := Vector3(rng.randf_range(0.4, biggest), rng.randf_range(0.3, biggest * 0.7),
			rng.randf_range(0.4, biggest))
		var reach := spread * sqrt(rng.randf())
		var bearing := rng.randf() * TAU
		var at := centre + Vector3(cos(bearing) * reach, -size.y * rng.randf_range(0.1, 0.4),
			sin(bearing) * reach)
		var turn := Basis(Vector3.UP, rng.randf() * TAU) \
			* Basis(Vector3.RIGHT, rng.randf_range(-0.35, 0.35)) \
			* Basis(Vector3.FORWARD, rng.randf_range(-0.35, 0.35))
		KitBlock.make(parent, "Rubble%d" % (parent.get_child_count() + 1), "wall", size,
			Transform3D(turn, at))


## A column that fell: the kit's [param piece] [param length] long and
## [param thick] through, lying at [param at] along [param bearing] degrees.
static func fallen(parent: Node3D, part_name: String, piece: String, at: Vector3, bearing: float,
		length: float, thick: float) -> KitBlock:
	# Laid down along its own +X, and lifted so it rests on its side.
	var turn := Basis(Vector3.UP, deg_to_rad(bearing)) * Basis(Vector3.BACK, -PI * 0.5)
	return KitBlock.make(parent, part_name, piece, Vector3(thick, length, thick),
		Transform3D(turn, at + Vector3(0.0, thick * 0.5, 0.0) - turn * Vector3(0.0, length * 0.5, 0.0)))
