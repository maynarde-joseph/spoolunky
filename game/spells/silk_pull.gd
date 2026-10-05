class_name SilkPull
extends Node3D

## Threads of silk hooked into something and pulled back to the spider: they shoot
## out to it, go taut, and snap back, fraying as they come. Cast at a prep table it
## pulls the cooked meat on it apart — see [SpiderSpells]. Looks only.

const GROUP := "silk_pulls"

## How many threads, how long they take to reach, and how long to come back.
const THREADS := 5
const REACH := 0.15
const BACK := 0.45

var from := Vector3.ZERO
var to := Vector3.ZERO
var colour := Color(0.74, 0.62, 0.98, 1.0)
var width := 0.02

var _age := 0.0
var _mesh: ImmediateMesh
var _paint: StandardMaterial3D
var _ends: Array[Vector3] = []


## Pulls on [param target] from [param source] under [param host], with threads
## [param thick] metres across.
static func pull(host: Node, source: Vector3, target: Vector3, thick := 0.02,
		tint := Color(0.74, 0.62, 0.98, 1.0)) -> SilkPull:
	if host == null:
		return null
	var threads := SilkPull.new()
	threads.name = "SilkPull"
	threads.from = source
	threads.to = target
	threads.width = maxf(thick, 0.004)
	threads.colour = tint
	threads.add_to_group(GROUP)
	threads.add_to_group("spell_effects")
	host.add_child(threads)
	return threads


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_paint = WebGeometry.silk_material()
	_mesh = ImmediateMesh.new()
	var view := MeshInstance3D.new()
	view.name = "Threads"
	view.mesh = _mesh
	view.material_override = _paint
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(view)
	var spread := maxf(from.distance_to(to) * 0.04, 0.05)
	for i in THREADS:
		_ends.append(to + Vector3(randf_range(-spread, spread), randf_range(0.0, spread),
			randf_range(-spread, spread)))
	SpellFlash.burst(get_parent(), to, colour, spread * 3.0, 0.3)


func _process(delta: float) -> void:
	_age += delta
	if _age >= REACH + BACK:
		queue_free()
		return
	_mesh.clear_surfaces()
	var out := clampf(_age / REACH, 0.0, 1.0)
	var back := clampf((_age - REACH) / BACK, 0.0, 1.0)
	var tint := Color(colour.r, colour.g, colour.b, 1.0 - back * 0.8)
	for end in _ends:
		# Out to the meat, then the far end comes back with a bit of it.
		var tip := from.lerp(end, out * (1.0 - back))
		WebGeometry.draw_line_into(_mesh, _paint, from, tip, width, tint)
