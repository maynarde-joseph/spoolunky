class_name WetGround
extends Node3D

## Ground the spider has doused: a fan of wet out in front of where it stood.
##
## Everything standing in it stays soaked while it does, and soaked carries
## lightning twice as hard and on to anything wet near it — see [LightningStrike].
## It dries off in a few seconds.
##
## Wind blown over it lifts it into a whirl, and the ground it came from is dry
## again — see [Gust] and [WaterSpiral].

const GROUP := "wet_ground"

## How wide the fan opens either side of its middle, in degrees.
const SPREAD := 35.0

## How long a creature stays soaked once it is off it, in seconds.
const SOAK := 4.0

## How often it soaks what is standing in it, in seconds.
const PULSE := 0.25

## How long it takes to dry off at the end, in seconds.
const FADE := 1.0

## How dark and how clear the wet looks, at its wettest.
const SHEEN := 0.42

## Where the fan starts — at the spider's feet — the way it opens, laid flat, and
## how far it reaches, in metres.
var apex := Vector3.ZERO
var heading := Vector3.FORWARD
var reach := 2.0

## How long it stays wet, in seconds.
var life := 10.0

var colour := Color(0.36, 0.74, 0.9, 1.0)

var _age := 0.0
var _pulse := 0.0
var _dry_at := -1.0
var _paint: StandardMaterial3D


## Spills a fan of wet under [param host] from [param from], opening along
## [param toward] laid flat out to [param far] metres, wet for [param lasts]
## seconds.
static func spill(host: Node, from: Vector3, toward: Vector3, far: float, lasts: float,
		tint := Color(0.36, 0.74, 0.9, 1.0)) -> WetGround:
	var flat := Vector3(toward.x, 0.0, toward.z)
	if host == null or flat.length_squared() < 0.000001 or far <= 0.0:
		return null
	var wet := WetGround.new()
	wet.name = "WetGround"
	wet.heading = flat.normalized()
	wet.reach = far
	wet.life = maxf(lasts, 0.1)
	wet.colour = tint
	wet.add_to_group(GROUP)
	wet.add_to_group("spell_effects")
	host.add_child(wet)
	wet.global_position = from
	wet.apex = from
	wet._build_view()
	return wet


## Whether [param point] is in the fan opening from [param from] along
## [param toward], flat across the ground, out to [param far] metres — with
## [param margin] to spare all round.
static func in_fan(point: Vector3, from: Vector3, toward: Vector3, far: float,
		margin := 0.0) -> bool:
	var off := Vector2(point.x - from.x, point.z - from.z)
	var ahead := Vector2(toward.x, toward.z)
	if ahead.length_squared() < 0.000001:
		return false
	var distance := off.length()
	if distance > far + margin:
		return false
	if distance <= margin:
		return true
	var spare := rad_to_deg(asin(clampf(margin / distance, 0.0, 1.0)))
	return absf(rad_to_deg(ahead.angle_to(off))) <= SPREAD + spare


## Whether it is still wet.
func is_wet() -> bool:
	return _dry_at < 0.0


## Whether [param point] is on it — in the fan, and down at the ground rather than
## above it — within [param margin], while it is still wet.
func holds(point: Vector3, margin := 0.0) -> bool:
	if not is_wet() or not in_fan(point, apex, heading, reach, margin):
		return false
	var rise := point.y - apex.y
	return rise >= -reach * 0.5 - margin and rise <= reach * 0.15 + margin * 2.0


## The nearest of it to [param from] that a lane of wind blown from there along
## [param toward], out to [param far] and [param half_width] either side, passes
## over — or null if the wind misses it.
func met_by(from: Vector3, toward: Vector3, far: float, half_width: float) -> Variant:
	if not is_wet():
		return null
	var flat := Vector3(toward.x, 0.0, toward.z)
	if flat.length_squared() < 0.000001:
		return null
	flat = flat.normalized()
	var side := flat.cross(Vector3.UP).normalized()
	var best: Variant = null
	var best_gap := INF
	for step in range(1, 13):
		var out := far * float(step) / 12.0
		for across: float in [-1.0, -0.5, 0.0, 0.5, 1.0]:
			var point := from + flat * out + side * half_width * across
			point.y = apex.y
			if holds(point) and out < best_gap:
				best_gap = out
				best = point
	return best


## The wind took it: it dries off now.
func dry() -> void:
	if is_wet():
		_dry_at = _age


func _physics_process(delta: float) -> void:
	_age += delta
	if not is_wet():
		if _age >= _dry_at + FADE:
			queue_free()
		return
	if _age >= life:
		dry()
		return
	_pulse -= delta
	if _pulse > 0.0:
		return
	_pulse = PULSE
	for node in get_tree().get_nodes_in_group("prey"):
		var creature := node as Prey
		if creature != null and is_instance_valid(creature) and not creature.eaten \
				and holds(creature.global_position, creature.hit_radius()):
			creature.soak(SOAK)


func _process(_delta: float) -> void:
	if _paint == null:
		return
	var shown := 1.0
	if not is_wet():
		shown = 1.0 - clampf((_age - _dry_at) / FADE, 0.0, 1.0)
	elif life - _age < FADE:
		shown = clampf((life - _age) / FADE, 0.0, 1.0)
	_paint.albedo_color.a = SHEEN * shown


# --- what you can see ----------------------------------------------------

## A dark sheen on the ground over the whole fan, laid onto the ground underneath
## it rather than flat at the spider's feet.
func _build_view() -> void:
	_paint = StandardMaterial3D.new()
	_paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	_paint.albedo_color = Color(colour.r * 0.45, colour.g * 0.55, colour.b * 0.7, SHEEN)
	var rings := 5
	var sides := 10
	var lift := maxf(reach * 0.004, 0.004)
	var space := get_world_3d().direct_space_state
	var points: Array[PackedVector3Array] = []
	for ring in range(rings + 1):
		var row := PackedVector3Array()
		var out := reach * float(ring) / float(rings)
		for i in range(sides + 1):
			var turn := deg_to_rad(lerpf(-SPREAD, SPREAD, float(i) / float(sides)))
			var at := apex + heading.rotated(Vector3.UP, turn) * out
			var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * reach * 0.3,
				at + Vector3.DOWN * reach * 0.6, GameLayers.WORLD)
			var hit := space.intersect_ray(query)
			if not hit.is_empty():
				at.y = (hit["position"] as Vector3).y
			row.append(at + Vector3.UP * lift - apex)
		points.append(row)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in rings:
		for i in sides:
			var a := points[ring][i]
			var b := points[ring][i + 1]
			var c := points[ring + 1][i + 1]
			var d := points[ring + 1][i]
			for corner in [a, b, c, a, c, d]:
				tool.add_vertex(corner)
	var sheen := MeshInstance3D.new()
	sheen.name = "Sheen"
	sheen.mesh = tool.commit()
	sheen.material_override = _paint
	sheen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sheen)
