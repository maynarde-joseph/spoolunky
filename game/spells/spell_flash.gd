class_name SpellFlash
extends MeshInstance3D

## A bloom where a spell lands: a ball of its colour that swells and fades in a
## moment. Looks only — nothing in the game reads it.

## How long it lasts, and how wide it gets, in seconds and metres.
var life := 0.3
var radius := 0.2

var _age := 0.0
var _material: StandardMaterial3D


## Puts one down at [param at] under [param host], in [param colour], swelling to
## [param wide] across [param lasts] seconds.
static func burst(host: Node, at: Vector3, colour: Color, wide: float,
		lasts := 0.3) -> SpellFlash:
	if host == null:
		return null
	var flash := SpellFlash.new()
	flash.name = "SpellFlash"
	flash.life = maxf(lasts, 0.05)
	flash.radius = maxf(wide, 0.01)
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	flash.mesh = sphere
	flash._material = StandardMaterial3D.new()
	flash._material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash._material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash._material.cull_mode = BaseMaterial3D.CULL_DISABLED
	flash._material.albedo_color = Color(colour.r, colour.g, colour.b, 0.75)
	flash.material_override = flash._material
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash.add_to_group("spell_effects")
	host.add_child(flash)
	flash.global_position = at
	flash.scale = Vector3.ONE * flash.radius * 0.3
	return flash


func _process(delta: float) -> void:
	_age += delta
	var t := clampf(_age / life, 0.0, 1.0)
	scale = Vector3.ONE * radius * lerpf(0.3, 1.0, sqrt(t))
	_material.albedo_color.a = 0.75 * (1.0 - t)
	if t >= 1.0:
		queue_free()
