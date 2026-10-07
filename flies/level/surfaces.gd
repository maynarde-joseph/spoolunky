class_name Surfaces
extends RefCounted

## What a level is built of, and what silk makes of it.
##
## Two kinds of surface, the way Portal has two: **stone**, pale, which silk sticks
## to and a grapple holds on, and **slick**, dark metal, which neither does — a web
## thrown at it slides off and comes apart, and a grapple line finds nothing to
## bite. The spider walks on the floor of either; it climbs neither. Only its own
## webs let it up a wall.

const SLICK_GROUP := "slick"

const STONE := "stone"
const SLICK := "slick"

## Every kind there is, in the order the editor offers them.
const KINDS := [STONE, SLICK]

static var _paints := {}


## Whether silk will not hold on [param collider].
static func is_slick(collider: Variant) -> bool:
	var node := collider as Node
	return node != null and node.is_in_group(SLICK_GROUP)


## The material for a surface of [param kind].
static func paint(kind: String) -> StandardMaterial3D:
	if _paints.has(kind):
		return _paints[kind]
	var made := StandardMaterial3D.new()
	match kind:
		SLICK:
			made.albedo_color = Color(0.2, 0.23, 0.29)
			made.metallic = 0.6
			made.roughness = 0.3
			made.metallic_specular = 0.8
			_panelled(made, Color(1, 1, 1), Color(0.55, 0.6, 0.7), true)
		"accent":
			made.albedo_color = Color(0.95, 0.66, 0.22)
			made.roughness = 0.6
		"crate":
			made.albedo_color = Color(0.72, 0.5, 0.3)
			made.roughness = 0.85
		"loose":
			# Weathered boards: silk sticks, but they won't hold the spider.
			made.albedo_color = Color(0.55, 0.4, 0.28)
			made.roughness = 0.95
			_panelled(made, Color(1, 1, 1), Color(0.62, 0.52, 0.42), true)
		"plate":
			made.albedo_color = Color(0.86, 0.3, 0.24)
			made.roughness = 0.5
		"door":
			made.albedo_color = Color(0.3, 0.55, 0.62)
			made.roughness = 0.45
			made.metallic = 0.3
		"hazard":
			made.albedo_color = Color(0.85, 0.15, 0.2)
			made.roughness = 0.5
			made.emission_enabled = true
			made.emission = Color(0.9, 0.1, 0.15)
			made.emission_energy_multiplier = 0.6
		"platform":
			made.albedo_color = Color(0.86, 0.82, 0.68)
			made.roughness = 0.75
		_:
			made.albedo_color = Color(0.93, 0.91, 0.86)
			made.roughness = 0.9
			_panelled(made, Color(1, 1, 1), Color(0.72, 0.72, 0.74), false)
	_paints[kind] = made
	return made


## The ceiling over a level: a faint grid seen from below, lit by nothing and
## shadowing nothing.
static func ceiling_paint() -> StandardMaterial3D:
	if _paints.has("ceiling"):
		return _paints["ceiling"]
	var made := StandardMaterial3D.new()
	made.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	made.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	made.cull_mode = BaseMaterial3D.CULL_DISABLED
	made.albedo_color = Color(0.25, 0.3, 0.38, 1.0)
	_panelled(made, Color(1, 1, 1, 0.08), Color(1, 1, 1, 0.45), true)
	_paints["ceiling"] = made
	return made


## Lays a grid of panels over [param made], two metres a panel, in the world's own
## axes, so the panels run on from one block to the next and a distance can be read
## off a wall by counting them. Slick metal gets stripes across each panel as well.
static func _panelled(made: StandardMaterial3D, fill: Color, seam: Color, striped: bool) -> void:
	var size := 128
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(fill)
	for i in size:
		for j in size:
			var edge := i < 3 or j < 3 or i >= size - 3 or j >= size - 3
			var inner := (i == 10 or j == 10 or i == size - 11 or j == size - 11) \
				and i >= 10 and j >= 10 and i <= size - 11 and j <= size - 11
			if edge:
				image.set_pixel(i, j, seam)
			elif inner:
				image.set_pixel(i, j, fill.lerp(seam, 0.35))
			elif striped and ((i + j) / 12) % 2 == 0:
				image.set_pixel(i, j, fill.lerp(seam, 0.5))
	image.generate_mipmaps()
	made.albedo_texture = ImageTexture.create_from_image(image)
	made.uv1_triplanar = true
	made.uv1_world_triplanar = true
	made.uv1_scale = Vector3.ONE * 0.5
	made.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC


## Marks [param body] as being of [param kind], and paints [param view] to match.
static func apply(body: CollisionObject3D, view: GeometryInstance3D, kind: String) -> void:
	if body != null:
		if kind == SLICK:
			body.add_to_group(SLICK_GROUP)
		elif body.is_in_group(SLICK_GROUP):
			body.remove_from_group(SLICK_GROUP)
	if view != null:
		view.material_override = paint(kind)
