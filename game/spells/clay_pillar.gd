class_name ClayPillar
extends StaticBody3D

## A pillar of clay, raised out of the ground where the cross is: a square block,
## coming up fast. What stands there goes up with it — a fly is stunned and tossed
## off the top, the spider is thrown up higher than it can jump — and then it
## stands for a while, as solid as any wall, something to climb or to put between
## a fly and the open field, and sinks back into the ground.

const GROUP := "clay_pillars"

## How long it takes to come up, and to sink back, in seconds.
const RISE := 0.25
const SINK := 0.4

## How long a fly it throws stays stunned, in seconds.
const STUN := 2.0

const CLAY := Color(0.45, 0.31, 0.2, 1.0)

var base := Vector3.ZERO
var radius := 0.4
var tall := 2.0
var lasts := 10.0

## Whether it threw the spider, and the flies it threw.
var spider_thrown := false
var thrown: Array[Insect] = []

var _age := 0.0
var _now := 0.0
var _sinking := -1.0
var _shape: BoxShape3D
var _collider: CollisionShape3D
var _mesh: BoxMesh
var _view: MeshInstance3D


## Raises one under [param host] at [param at]: [param wide] metres from its middle
## to a face and [param height] tall, standing for [param seconds]. [param spider]
## is thrown if it is standing there.
static func raise(host: Node, at: Vector3, wide: float, height: float, seconds: float,
		spider: SpiderPlayer = null) -> ClayPillar:
	if host == null:
		return null
	var pillar := ClayPillar.new()
	pillar.name = "ClayPillar"
	pillar.base = at
	pillar.radius = maxf(wide, 0.05)
	pillar.tall = maxf(height, 0.2)
	pillar.lasts = maxf(seconds, RISE + 0.1)
	pillar.collision_layer = GameLayers.WORLD
	pillar.collision_mask = 0
	pillar.add_to_group(GROUP)
	pillar.add_to_group("spell_effects")
	host.add_child(pillar)
	pillar.global_position = at
	if spider != null:
		var look := spider.global_position - at
		look.y = 0.0
		if look.length_squared() > 0.0001:
			pillar.rotation.y = atan2(look.x, look.z)
	pillar._build()
	pillar._strike(spider)
	return pillar


func _physics_process(delta: float) -> void:
	_age += delta
	if _sinking >= 0.0:
		var gone := clampf((_age - _sinking) / SINK, 0.0, 1.0)
		_set_height(tall * (1.0 - gone))
		if gone >= 1.0:
			queue_free()
		return
	_set_height(tall * clampf(_age / RISE, 0.0, 1.0))
	if _age >= lasts:
		_sinking = _age


## Whether [param point] is where it comes up, within [param margin].
func in_the_way(point: Vector3, margin := 0.0) -> bool:
	var off := point - base
	return absf(off.x) <= radius + margin and absf(off.z) <= radius + margin \
		and off.y > -radius and off.y < tall + margin


## What stands where it comes up: flies are stunned and tossed up, the spider thrown.
func _strike(spider: SpiderPlayer) -> void:
	var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	for node in get_tree().get_nodes_in_group(Insect.GROUP):
		var insect := node as Insect
		if insect == null or insect.is_bundle() or not in_the_way(insect.global_position, insect.radius()):
			continue
		var out := insect.global_position - base
		out.y = 0.0
		out = out.normalized() if out.length_squared() > 0.0001 else Vector3.FORWARD
		insect.shove(Vector3.UP * sqrt(2.0 * gravity * (tall + 0.5)) + out * 3.0, 0.5)
		insect.stun(STUN + 1.0)
		thrown.append(insect)
	if spider != null and is_instance_valid(spider) and in_the_way(spider.global_position, spider.body_height * 0.5):
		spider.fling(Vector3.UP * (tall / RISE + spider.gravity * RISE))
		spider_thrown = true


func _build() -> void:
	_shape = BoxShape3D.new()
	_collider = CollisionShape3D.new()
	_collider.name = "Clay"
	_collider.shape = _shape
	add_child(_collider)
	_mesh = BoxMesh.new()
	var paint := StandardMaterial3D.new()
	paint.albedo_color = CLAY
	paint.roughness = 1.0
	_view = MeshInstance3D.new()
	_view.name = "Block"
	_view.mesh = _mesh
	_view.material_override = paint
	add_child(_view)
	_set_height(0.0)
	SpellFlash.burst(get_parent(), base, CLAY, radius * 2.5, 0.35)


func _set_height(height_now: float) -> void:
	_now = height_now
	var foot := radius * 0.3
	var span := maxf(height_now + foot, 0.01)
	var size := Vector3(radius * 2.0, span, radius * 2.0)
	_shape.size = size
	_mesh.size = size
	var middle := Vector3.UP * (span * 0.5 - foot)
	_collider.position = middle
	_view.position = middle
