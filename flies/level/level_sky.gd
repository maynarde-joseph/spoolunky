class_name LevelSky
extends RefCounted

## The light every level is played in: a bright, hazy sky over test chambers that
## hang in it, a sun to throw hard shadows to read heights by, and a little glow
## so an open exit stands out.

static func dress(level: Node3D) -> void:
	var sky_paint := ProceduralSkyMaterial.new()
	sky_paint.sky_top_color = Color(0.36, 0.52, 0.78)
	sky_paint.sky_horizon_color = Color(0.78, 0.82, 0.86)
	sky_paint.ground_horizon_color = Color(0.72, 0.74, 0.78)
	sky_paint.ground_bottom_color = Color(0.3, 0.33, 0.4)
	sky_paint.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_paint
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_white = 6.0
	environment.glow_enabled = true
	environment.glow_intensity = 0.6
	environment.glow_bloom = 0.05
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.74, 0.79, 0.86)
	environment.fog_density = 0.004
	environment.fog_aerial_perspective = 0.6
	environment.ssao_enabled = true
	environment.ssao_radius = 1.2
	environment.ssao_intensity = 1.4
	var world := WorldEnvironment.new()
	world.name = "Sky"
	world.environment = environment
	level.add_child(world)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
	sun.light_energy = 1.35
	sun.light_color = Color(1.0, 0.96, 0.9)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	level.add_child(sun)
