class_name Palette
extends RefCounted

## The world's colours: a few flat, matte paints, each one material shared by
## everything painted with it.
##
## The look the creatures have — smooth parts in a few flat colours, matte, no
## detail — put on wood, stone, leaves and water. A colour lives in one place.
## [constant PAINTS] says what each one is when the world is first built, and
## the bake writes each one out to [constant DIR] the first time; from then on
## the file is the paint, so changing a colour is changing that one file, and
## every shelf, stone and leaf painted with it follows.

const DIR := "res://game/world/materials"

## Every paint: its colour, and how it takes the light. An alpha under one makes
## it see-through, for water; [code]glow[/code] makes it give off its own colour,
## for the fungus that lights a cave.
const PAINTS := {
	# Wood: the pale of a cut face, and the dark inside an old log.
	"wood_light": {"colour": Color(0.79, 0.64, 0.45)},
	"wood_dark": {"colour": Color(0.42, 0.29, 0.19)},
	# Plain colours: the middle of a flower, sugar, an egg, straw, and the dark of
	# a pot.
	"yellow": {"colour": Color(0.92, 0.74, 0.2)},
	"white": {"colour": Color(0.9, 0.9, 0.86)},
	"black": {"colour": Color(0.09, 0.09, 0.1)},
	"straw": {"colour": Color(0.84, 0.72, 0.44)},
	"stone_dark": {"colour": Color(0.41, 0.42, 0.43)},
	# The ground, and what grows in it.
	"grass": {"colour": Color(0.3, 0.46, 0.21)},
	"soil": {"colour": Color(0.36, 0.26, 0.18)},
	"bark": {"colour": Color(0.4, 0.3, 0.22)},
	"leaf": {"colour": Color(0.28, 0.5, 0.22)},
	"leaf_light": {"colour": Color(0.4, 0.56, 0.24)},
	"leaf_dark": {"colour": Color(0.19, 0.37, 0.18)},
	"petal_red": {"colour": Color(0.86, 0.22, 0.24)},
	"petal_yellow": {"colour": Color(0.96, 0.82, 0.26)},
	"petal_white": {"colour": Color(0.95, 0.94, 0.9)},
	# Wild rock, a shade darker than stone anyone has cut.
	"rock": {"colour": Color(0.44, 0.43, 0.41)},
	"rock_dark": {"colour": Color(0.34, 0.33, 0.31)},
	# The farm: fruit mash in a trough, clay for a crust, the market's striped
	# canvas, a gate's paint, the road, and the farm's own grass.
	"fruit_mash": {"colour": Color(0.62, 0.38, 0.22)},
	"grain": {"colour": Color(0.86, 0.72, 0.38)},
	"clay": {"colour": Color(0.62, 0.42, 0.26)},
	"canvas_red": {"colour": Color(0.78, 0.2, 0.18)},
	"canvas_cream": {"colour": Color(0.95, 0.9, 0.78)},
	"gate_red": {"colour": Color(0.6, 0.2, 0.15)},
	"dirt": {"colour": Color(0.52, 0.4, 0.27)},
	"meadow": {"colour": Color(0.36, 0.52, 0.24)},
	# Water, see-through.
	"pond": {"colour": Color(0.2, 0.42, 0.46, 0.8), "rough": 0.2},
	# For shapes built a point at a time, whose colour is carried on the points
	# rather than on the material.
	"painted": {"colour": Color(1.0, 1.0, 1.0), "painted": true},
}

## How rough a paint is when it does not say: matte, like everything else.
const ROUGH := 0.88

static var _made := {}


## The material for [param paint_name], shared by everything painted with it:
## the file, once the bake has written it, and until then one made from
## [constant PAINTS].
static func paint(paint_name: String) -> Material:
	if _made.has(paint_name):
		return _made[paint_name]
	var material: Material = null
	var path := path_of(paint_name)
	if ResourceLoader.exists(path):
		material = load(path) as Material
	if material == null:
		material = mix(paint_name)
	_made[paint_name] = material
	return material


## The colour of [param paint_name] as its material has it now: for the shapes
## built a point at a time, whose colour is carried on their points. They take it
## when they are built, so a paint changed afterwards reaches them at the next bake.
static func colour(paint_name: String) -> Color:
	var material := paint(paint_name) as BaseMaterial3D
	return material.albedo_color if material != null else Color.MAGENTA


## Where the paint's file lives.
static func path_of(paint_name: String) -> String:
	return DIR.path_join(paint_name + ".tres")


## A fresh material from [constant PAINTS], whatever is on disk.
static func mix(paint_name: String) -> StandardMaterial3D:
	var recipe: Dictionary = PAINTS.get(paint_name, {})
	if recipe.is_empty():
		push_warning("no such paint: %s" % paint_name)
	var colour: Color = recipe.get("colour", Color.MAGENTA)
	var material := StandardMaterial3D.new()
	material.resource_name = paint_name
	material.albedo_color = colour
	material.roughness = float(recipe.get("rough", ROUGH))
	material.metallic = 0.0
	if colour.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		# Seen from both sides: water from underneath as well as from above.
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if recipe.has("glow"):
		material.emission_enabled = true
		material.emission = colour
		material.emission_energy_multiplier = float(recipe["glow"])
	if recipe.get("painted", false):
		material.vertex_color_use_as_albedo = true
	return material


## Writes out every paint that has no file yet, and forgets what it had made,
## so what is built next is painted from the files. The bakes call this first;
## nothing else needs to.
static func save_missing() -> int:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var written := 0
	for paint_name in PAINTS:
		var path := path_of(paint_name)
		if ResourceLoader.exists(path):
			continue
		var err := ResourceSaver.save(mix(paint_name), path)
		if err != OK:
			push_error("could not save %s: %d" % [path, err])
			continue
		written += 1
	_made.clear()
	return written
