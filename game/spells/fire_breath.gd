class_name FireBreath
extends Node3D

## A jet of fire out of the spider's jaws, along the cross.
##
## Let go of the key and the spider breathes it for a moment, and it follows the
## cross while it lasts, so it can be swept. It goes as far as its reach or the
## first wall, whichever is nearer, opening a little on the way. A fly it reaches
## flees it; a bundle it reaches is cooked — see [SpiderSpells].

## It has died down.
signal finished(breath: FireBreath)

## It reached [param insect], the first time it did.
signal touched(breath: FireBreath, insect: Insect)

const GROUP := "fire_breaths"

## How wide it is at the jaws, from its middle, in the caster's body heights, and
## how much wider it gets for every metre out.
const MOUTH := 0.12
const SPREAD := 0.2

## How long it takes to flare out to its full reach, and to die down once its time
## is up, in seconds.
const FLARE := 0.12

## Where it comes out, which way it goes, and how far it could go, in metres.
var origin := Vector3.ZERO
var heading := Vector3.FORWARD
var reach := 2.0

## How long it is breathed for, in seconds.
var lasts := 1.0

## How wide it is at the jaws, from its middle, in metres.
var mouth := 0.03

var colour := Color(1.0, 0.45, 0.12, 1.0)

## The caster it follows: its jaws are where it comes from and its cross is where
## it goes, every frame it lasts. Null, and it stays where it was breathed.
var source: SpiderSpells = null

## Everything it has reached.
var reached: Array[Insect] = []

var _age := 0.0
var _length := 0.0
var _exclude: Array[RID] = []
var _cone: MeshInstance3D
var _cone_mesh: CylinderMesh
var _core: MeshInstance3D
var _core_mesh: CylinderMesh
var _paint: StandardMaterial3D
var _core_paint: StandardMaterial3D
var _light: OmniLight3D


## Breathes one under [param host] from [param from] along [param toward], out to
## [param far] metres, for [param seconds], for a caster [param body] metres tall.
## With [param follow], it goes where that caster's cross goes while it lasts.
static func breathe(host: Node, from: Vector3, toward: Vector3, far: float, seconds: float,
		body: float, tint := Color(1.0, 0.45, 0.12, 1.0),
		follow: SpiderSpells = null) -> FireBreath:
	if host == null or toward.length_squared() < 0.000001 or far <= 0.0:
		return null
	var breath := FireBreath.new()
	breath.name = "FireBreath"
	breath.origin = from
	breath.heading = toward.normalized()
	breath.reach = far
	breath.lasts = maxf(seconds, 0.05)
	breath.mouth = maxf(body * MOUTH, 0.005)
	breath.colour = tint
	breath.source = follow
	if follow != null:
		breath._exclude = follow.exclusions()
	breath.add_to_group(GROUP)
	breath.add_to_group("spell_effects")
	host.add_child(breath)
	breath.global_position = from
	breath._build_view()
	return breath


## Whether it is still being breathed.
func burning() -> bool:
	return _age < lasts


## How far out it reaches now, in metres: as far as it can, or to the first wall.
func length() -> float:
	return _length


## How wide it is, from its middle, [param out] metres from the jaws.
func radius_at(out: float) -> float:
	return mouth + SPREAD * maxf(out, 0.0)


## Whether [param point] is in the flame, within [param margin].
func holds(point: Vector3, margin := 0.0) -> bool:
	var off := point - origin
	var along := off.dot(heading)
	if along < -margin or along > _length + margin:
		return false
	return (off - heading * along).length() <= radius_at(along) + margin


func _physics_process(delta: float) -> void:
	_age += delta
	if source != null and is_instance_valid(source):
		origin = source.breath_origin()
		var toward := source.breath_heading()
		if toward.length_squared() > 0.000001:
			heading = toward.normalized()
		global_position = origin
	_length = _clear_reach() * clampf(_age / FLARE, 0.0, 1.0)
	if burning():
		for node in get_tree().get_nodes_in_group(Insect.GROUP):
			var insect := node as Insect
			if insect != null and not reached.has(insect) and holds(insect.global_position, insect.radius()):
				reached.append(insect)
				touched.emit(self, insect)
	if not burning() and _age >= lasts + FLARE:
		finished.emit(self)
		queue_free()


func _process(_delta: float) -> void:
	_update_view()


## How far it gets before something solid stops it.
func _clear_reach() -> float:
	if not is_inside_tree():
		return reach
	var query := PhysicsRayQueryParameters3D.create(origin, origin + heading * reach,
		GameLayers.WORLD, _exclude)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return reach
	return origin.distance_to(hit["position"])


# --- what you can see ----------------------------------------------------

func _build_view() -> void:
	_paint = _flame_paint(Color(colour.r, colour.g, colour.b, 0.0))
	_cone_mesh = _flame_mesh()
	_cone = _flame_part("Flame", _cone_mesh, _paint)
	_core_paint = _flame_paint(Color(1.0, 0.86, 0.45, 0.0))
	_core_mesh = _flame_mesh()
	_core = _flame_part("Core", _core_mesh, _core_paint)
	_light = OmniLight3D.new()
	_light.name = "Glow"
	_light.light_color = colour
	_light.light_energy = 0.0
	_light.top_level = true
	add_child(_light)


func _flame_paint(tint: Color) -> StandardMaterial3D:
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	paint.albedo_color = tint
	return paint


func _flame_mesh() -> CylinderMesh:
	var cone := CylinderMesh.new()
	cone.radial_segments = 16
	cone.rings = 1
	cone.cap_top = false
	cone.cap_bottom = false
	return cone


func _flame_part(part_name: String, cone: CylinderMesh,
		paint: StandardMaterial3D) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = part_name
	part.mesh = cone
	part.material_override = paint
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	part.top_level = true
	part.visible = false
	add_child(part)
	return part


## A cone of flame from the jaws to as far as it gets, narrow end first, with a
## brighter core down the middle: flickering while it lasts, and fading as it dies.
func _update_view() -> void:
	if _cone == null:
		return
	var shown := 1.0 if burning() else 1.0 - clampf((_age - lasts) / FLARE, 0.0, 1.0)
	var flicker := 0.85 + 0.15 * sin(_age * 41.0)
	var long := maxf(_length, 0.01)
	# A cylinder stands along its own y with its top up, so up is turned back toward
	# the jaws: the narrow end at the mouth, the wide end out where it is going.
	var back := -heading
	var across := back.cross(Vector3.UP)
	if across.length_squared() < 0.000001:
		across = back.cross(Vector3.FORWARD)
	across = across.normalized()
	var turn := Basis(across, back, across.cross(back).normalized())
	var middle := origin + heading * long * 0.5
	for part: MeshInstance3D in [_cone, _core]:
		part.visible = _length > 0.01 and shown > 0.0
		part.global_transform = Transform3D(turn, middle)
	_cone_mesh.height = long
	_cone_mesh.top_radius = mouth
	_cone_mesh.bottom_radius = radius_at(long) * flicker
	_core_mesh.height = long * 0.85
	_core_mesh.top_radius = mouth * 0.5
	_core_mesh.bottom_radius = radius_at(long) * 0.45 * flicker
	_paint.albedo_color.a = 0.55 * shown * flicker
	_core_paint.albedo_color.a = 0.8 * shown
	_light.global_position = origin + heading * long * 0.4
	_light.omni_range = long * 1.5
	_light.light_energy = 2.2 * shown * flicker
