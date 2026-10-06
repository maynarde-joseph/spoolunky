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
			made.albedo_color = Color(0.17, 0.2, 0.25)
			made.metallic = 0.65
			made.roughness = 0.28
			made.metallic_specular = 0.8
		"accent":
			made.albedo_color = Color(0.95, 0.66, 0.22)
			made.roughness = 0.6
		"crate":
			made.albedo_color = Color(0.72, 0.5, 0.3)
			made.roughness = 0.85
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
			made.albedo_color = Color(0.9, 0.87, 0.8)
			made.roughness = 0.9
	_paints[kind] = made
	return made


## Marks [param body] as being of [param kind], and paints [param view] to match.
static func apply(body: CollisionObject3D, view: GeometryInstance3D, kind: String) -> void:
	if body != null:
		if kind == SLICK:
			body.add_to_group(SLICK_GROUP)
		elif body.is_in_group(SLICK_GROUP):
			body.remove_from_group(SLICK_GROUP)
	if view != null:
		view.material_override = paint(kind)
