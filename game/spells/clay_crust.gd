class_name ClayCrust
extends Node3D

## Clay coming up round something: slabs of it rising out of whatever is under the
## point, leaning in and closing over it, then sinking back into the crust they
## left. Cast at a prep table it seals what is on it in clay — see
## [SpiderSpells]. Looks only.

const GROUP := "clay_crusts"

## How many slabs come up, how long they take to close, and how long to sink.
const SLABS := 7
const CLOSE := 0.35
const SINK := 0.4

## How wide the ring they come up in is, in metres.
var radius := 0.4

var colour := Color(0.62, 0.42, 0.26, 1.0)

var _age := 0.0
var _slabs: Array[MeshInstance3D] = []
var _paint: StandardMaterial3D


## Raises one under [param host] round [param at], [param wide] metres from the
## middle to the slabs.
static func raise(host: Node, at: Vector3, wide: float,
		tint := Color(0.62, 0.42, 0.26, 1.0)) -> ClayCrust:
	if host == null:
		return null
	var crust := ClayCrust.new()
	crust.name = "ClayCrust"
	crust.radius = maxf(wide, 0.05)
	crust.colour = tint
	crust.add_to_group(GROUP)
	crust.add_to_group("spell_effects")
	host.add_child(crust)
	crust.global_position = at
	return crust


func _ready() -> void:
	_paint = StandardMaterial3D.new()
	_paint.albedo_color = colour
	_paint.roughness = 1.0
	_paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var slab := BoxMesh.new()
	slab.size = Vector3(radius * 0.7, radius * 1.4, radius * 0.18)
	for i in SLABS:
		var part := MeshInstance3D.new()
		part.name = "Slab%d" % (i + 1)
		part.mesh = slab
		part.material_override = _paint
		add_child(part)
		_slabs.append(part)
	_place(0.0)


func _process(delta: float) -> void:
	_age += delta
	if _age >= CLOSE + SINK:
		queue_free()
		return
	_place(_age)


## Every slab where it has got to: up out of the ground and leaning in, then down.
func _place(age: float) -> void:
	var up := clampf(age / CLOSE, 0.0, 1.0)
	var down := clampf((age - CLOSE) / SINK, 0.0, 1.0)
	var rise := up * (1.0 - down)
	for i in _slabs.size():
		var turn := TAU * float(i) / float(_slabs.size())
		var out := Vector3(cos(turn), 0.0, sin(turn))
		var lean := Basis(Vector3.UP, -turn + PI * 0.5) * Basis(Vector3.RIGHT, -0.5 * up)
		_slabs[i].transform = Transform3D(lean, out * radius * lerpf(1.2, 0.8, up)
			+ Vector3.UP * radius * lerpf(-0.7, 0.4, rise))
	_paint.albedo_color.a = 1.0 - down
