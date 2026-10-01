class_name Forage
extends Node3D

## Something growing that creatures eat: a mat of moss, a clump of toadstools, a
## stand of flowers, a tussock of grass, a bush of berries.
##
## It is where every food chain in the world starts. A grazer that is hungry goes
## to the nearest patch of what it eats and eats it down; the patch grows back,
## slowly, so a meadow with too many hares on it is a meadow with nothing on it,
## and the hares go hungry, and fewer of them are born — see [Den]. Nothing here
## decides any of that. A patch only knows how much is on it.
##
## It shows how much is left: grass is shorter, flowers lose their heads, a bush
## loses its berries. A patch the size of a doormat to a spiderling is a mouthful
## to a deer, so it is sized in metres and drawn to them.

const GROUP := "forage"

## Every kind of forage there is. A diet names these.
const KINDS := ["moss", "fungus", "flowers", "grass", "berries"]

## Under this share of full it is too thin to be worth going to.
const BARE := 0.1

## What grows here: one of [constant KINDS].
@export_enum("moss", "fungus", "flowers", "grass", "berries") var kind := "grass"

## How much is on it when it has grown all the way back, in the same units as
## biomass — what eating all of it is worth.
@export var capacity := 40.0

## How much grows back a second.
@export var regrow := 0.25

## How wide it is, in metres.
@export var size := 2.0

## Whether it glows in the dark: the fungus that lights a cave.
@export var glows := false

## How much is on it now.
var amount := 0.0

var _view: Node3D
var _growth: Array[Node3D] = []
var _shown := -1.0


func _ready() -> void:
	add_to_group(GROUP)
	amount = capacity
	_build_view()
	var world := Ecosystem.of(self)
	if world != null:
		world.add_forage(self)


func _exit_tree() -> void:
	var world := Ecosystem.of(self)
	if world != null:
		world.remove_forage(self)


func _process(delta: float) -> void:
	if amount < capacity:
		amount = minf(capacity, amount + regrow * delta)
	if absf(share() - _shown) > 0.02:
		_show()


## Takes up to [param want] off it, and returns what was really there.
func graze(want: float) -> float:
	if want <= 0.0:
		return 0.0
	var taken := minf(want, amount)
	amount -= taken
	return taken


## How full it is, 0 to 1.
func share() -> float:
	return clampf(amount / maxf(capacity, 0.001), 0.0, 1.0)


## Whether there is enough on it to be worth going to.
func worth_it() -> bool:
	return share() >= BARE


# --- what you can see ----------------------------------------------------

## A few plain shapes, by kind, laid out from a seed taken off where the patch is,
## so two patches of grass are not one tuft copied and the same patch is the same
## every time the level opens. What gets eaten is kept in a list, and shrinks.
func _build_view() -> void:
	_view = Node3D.new()
	_view.name = "View"
	add_child(_view, false, Node.INTERNAL_MODE_FRONT)
	_growth.clear()
	var dice := RandomNumberGenerator.new()
	dice.seed = hash(Vector3i(roundi(global_position.x * 10.0),
		roundi(global_position.y * 10.0), roundi(global_position.z * 10.0)))
	var half := size * 0.5
	match kind:
		"moss":
			for i in 6:
				var at := _scatter(dice, half * 0.7)
				var wide := half * dice.randf_range(0.35, 0.6)
				_growth.append(_lump(at, Vector3(wide, wide * 0.32, wide), "moss"))
		"fungus":
			for i in 5:
				var at := _scatter(dice, half * 0.6)
				var tall := half * dice.randf_range(0.25, 0.55)
				_stalk(at, tall, tall * 0.18, "glowcap" if glows else "stem")
				_growth.append(_lump(at + Vector3.UP * tall,
					Vector3(tall * 0.6, tall * 0.28, tall * 0.6), "glowcap" if glows else "cap"))
		"flowers":
			var petals := ["petal_red", "petal_yellow", "petal_purple", "petal_white"]
			for i in 9:
				var at := _scatter(dice, half * 0.8)
				var tall := half * dice.randf_range(0.5, 0.9)
				_stalk(at, tall, half * 0.025, "leaf")
				_growth.append(_lump(at + Vector3.UP * tall, Vector3.ONE * half * 0.09,
					petals[dice.randi() % petals.size()]))
		"grass":
			for i in 14:
				var at := _scatter(dice, half * 0.8)
				_growth.append(_blade(at, half * dice.randf_range(0.5, 1.0), half * 0.05,
					"leaf_light" if i % 3 == 0 else "grass", dice))
		"berries":
			var bush := _lump(Vector3.UP * half * 0.45, Vector3(half * 0.8, half * 0.6, half * 0.8),
				"leaf_dark")
			bush.name = "Bush"
			for i in 10:
				var turn := dice.randf() * TAU
				var lift := dice.randf_range(0.25, 0.85)
				var out := Vector3(cos(turn), 0.0, sin(turn)) * half * 0.78 * sin(lift * PI)
				_growth.append(_lump(out + Vector3.UP * half * (0.1 + lift * 0.75),
					Vector3.ONE * half * 0.09, "berry"))
	_show()


## Shrinks what has been eaten. The eaten part never goes quite to nothing: a bare
## patch still shows where it will grow back.
func _show() -> void:
	_shown = share()
	var left := lerpf(0.15, 1.0, _shown)
	for part in _growth:
		if part == null:
			continue
		var full: Vector3 = part.get_meta("full", part.scale)
		if kind == "grass":
			part.scale = Vector3(full.x, full.y * left, full.z)
		else:
			part.scale = full * left


func _scatter(dice: RandomNumberGenerator, spread: float) -> Vector3:
	var turn := dice.randf() * TAU
	return Vector3(cos(turn), 0.0, sin(turn)) * spread * sqrt(dice.randf())


func _lump(at: Vector3, radii: Vector3, paint: String) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 10
	sphere.rings = 5
	var part := _part(sphere, paint)
	part.position = at
	part.scale = radii
	part.set_meta("full", radii)
	return part


func _stalk(at: Vector3, tall: float, thick: float, paint: String) -> MeshInstance3D:
	var tube := CylinderMesh.new()
	tube.top_radius = thick * 0.8
	tube.bottom_radius = thick
	tube.height = tall
	tube.radial_segments = 6
	tube.rings = 1
	var part := _part(tube, paint)
	part.position = at + Vector3.UP * tall * 0.5
	return part


## A blade of grass: a thin cone from the root, leaning a little. Scaled from its
## root, so a grazed blade is a short blade rather than a floating one.
func _blade(at: Vector3, tall: float, thick: float, paint: String,
		dice: RandomNumberGenerator) -> Node3D:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = thick
	cone.height = 1.0
	cone.radial_segments = 4
	cone.rings = 1
	var root := Node3D.new()
	_view.add_child(root)
	root.position = at
	root.rotation = Vector3(dice.randf_range(-0.25, 0.25), dice.randf() * TAU,
		dice.randf_range(-0.25, 0.25))
	var blade := _part(cone, paint, root)
	blade.position = Vector3.UP * 0.5
	root.scale = Vector3(1.0, tall, 1.0)
	root.set_meta("full", root.scale)
	return root


func _part(mesh: Mesh, paint: String, parent: Node3D = null) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = Palette.paint(paint)
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent != null else _view).add_child(part)
	return part
