class_name FireBreath
extends Node3D

## A jet of fire out of the spider's jaws, along the cross.
##
## Let go of the wind-up and the spider breathes it for as long as the wind-up gave
## it, and it follows the cross while it lasts — so it is swept: across a creature,
## along a line, through the web that is holding what you want burned. It goes as
## far as its reach or the first wall, whichever is nearer, opening a little on the
## way.
##
## What is in it burns the way fire burns, for as long as it is in it: a fifth of
## the harm to something bare, all of it to something wrapped or held in silk (see
## [method Prey.burn]). And silk burns. Every web and line it touches goes up — a web
## with the frame it was walked round on — and what a web held drops out of it,
## burned. A wet web does not: see [WetSilk]. It stands in the flame while what it
## holds burns, which is how a catch is roasted without losing the web it is in.
##
## And water melts. A puddle it reaches turns to lava where it lies, burning
## whatever stands in it — see [Lava].

## It has died down: everything it burned, and how many webs and lines went up.
signal finished(breath: FireBreath, burned: Array[Prey], webs: int, lines: int)

const GROUP := "fire_breaths"

## How wide it is at the jaws, from its middle, in the caster's body heights, and
## how much wider it gets for every metre out.
const MOUTH := 0.12
const SPREAD := 0.2

## How long it takes to flare out to its full reach, and to die down once its time
## is up, in seconds.
const FLARE := 0.12

## How many points along it are tried against a web's silk, each frame.
const SAMPLES := 24

## How long a puddle it turns to lava stays molten, in seconds, and how much of a
## creature's health the lava takes a second, as a share of what the flame burns a
## second.
const LAVA_LASTS := 6.0
const LAVA_HEAT := 0.25

## Where it comes out, which way it goes, and how far it could go, in metres.
var origin := Vector3.ZERO
var heading := Vector3.FORWARD
var reach := 2.0

## How long it is breathed for, in seconds, and how much of a creature's health it
## takes every second it is in it, wrapped all the way.
var lasts := 1.0
var harm := 0.4

## How wide it is at the jaws, from its middle, in metres.
var mouth := 0.03

var colour := Color(1.0, 0.45, 0.12, 1.0)

## The caster it follows: its jaws are where it comes from and its cross is where
## it goes, every frame it lasts. Null, and it stays where it was breathed.
var source: SpiderSpells = null

## Held on a point instead of the cross, for a breath chained onto what the spell
## before it left: it goes there from the jaws for as long as it lasts, wherever the
## cross goes meanwhile. See [method steer_to].
var steered := false
var steer_point := Vector3.ZERO

## Everything it has burned, first to last, how many webs and lines went up, and
## the lava it made of puddles.
var burned: Array[Prey] = []
var webs_burned := 0
var lines_burned := 0
var melted: Array[Lava] = []

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
## [param far] metres, for [param seconds], taking [param hurt] of a creature's
## health every second it is in it, for a caster [param body] metres tall. With
## [param follow], it goes where that caster's cross goes while it lasts.
static func breathe(host: Node, from: Vector3, toward: Vector3, far: float, seconds: float,
		hurt: float, body: float, tint := Color(1.0, 0.45, 0.12, 1.0),
		follow: SpiderSpells = null) -> FireBreath:
	if host == null or toward.length_squared() < 0.000001 or far <= 0.0:
		return null
	var breath := FireBreath.new()
	breath.name = "FireBreath"
	breath.origin = from
	breath.heading = toward.normalized()
	breath.reach = far
	breath.lasts = maxf(seconds, 0.05)
	breath.harm = hurt
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


## Holds it on [param point] for the rest of its length, instead of on the cross.
func steer_to(point: Vector3) -> void:
	steered = true
	steer_point = point
	var toward := point - origin
	if toward.length_squared() > 0.000001:
		heading = toward.normalized()


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
		var toward := (steer_point - origin) if steered else source.breath_heading()
		if toward.length_squared() > 0.000001:
			heading = toward.normalized()
		global_position = origin
	_length = _clear_reach() * clampf(_age / FLARE, 0.0, 1.0)
	if burning():
		_burn_creatures(delta)
		_burn_silk()
		_melt_puddles()
	elif _age >= lasts + FLARE:
		finished.emit(self, burned, webs_burned, lines_burned)
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


## Everything in the flame burns, a little every frame it is in it.
func _burn_creatures(delta: float) -> void:
	for node in get_tree().get_nodes_in_group("prey"):
		var creature := node as Prey
		if creature == null or not is_instance_valid(creature) or creature.eaten:
			continue
		if not holds(creature.global_position, creature.hit_radius()):
			continue
		if creature.burn(harm * delta) > 0.0 and not burned.has(creature):
			burned.append(creature)
			SpellFlash.burst(get_parent(), creature.global_position, colour,
				creature.hit_radius() * 2.5, 0.4)


## Every web and line it touches goes up, a web with its frame — unless it is wet.
## What a web held burns as it goes, held in silk as it is: a second of the flame.
func _burn_silk() -> void:
	var catching: Array[WebStructure] = []
	for node in get_tree().get_nodes_in_group("silk_webs"):
		var web := node as WebStructure
		if web != null and not web.is_queued_for_deletion() and not WetSilk.is_wet(web) \
				and _touches(web):
			catching.append(web)
	if catching.is_empty():
		return
	var frames: Array[WebStructure] = []
	for web in catching:
		var net := web as WebNet
		if net == null:
			continue
		for line in net.frame():
			if not catching.has(line) and not frames.has(line) and not WetSilk.is_wet(line):
				frames.append(line)
	for web in catching + frames:
		for held in web.snared_prey():
			var creature := held as Prey
			if creature != null and is_instance_valid(creature) and creature.burn(harm) > 0.0 \
					and not burned.has(creature):
				burned.append(creature)
		_flare(web)
		web.tear()
		if web is WebNet:
			webs_burned += 1
		elif not frames.has(web):
			lines_burned += 1


## Every puddle the flame reaches turns to lava where it lies.
func _melt_puddles() -> void:
	if _length <= 0.0:
		return
	for node in get_tree().get_nodes_in_group(WetGround.GROUP):
		var wet := node as WetGround
		if wet == null or wet.is_queued_for_deletion() or not wet.is_wet():
			continue
		var along := clampf((wet.centre - origin).dot(heading), 0.0, _length)
		var nearest := origin + heading * along
		if nearest.distance_to(wet.centre) > radius_at(along) + wet.radius:
			continue
		wet.dry()
		var pool := Lava.melt(get_parent(), wet.centre, wet.up, wet.radius, LAVA_LASTS,
			harm * LAVA_HEAT)
		if pool != null:
			melted.append(pool)


## Whether the flame touches any of [param web]'s silk.
func _touches(web: WebStructure) -> bool:
	if _length <= 0.0:
		return false
	var strand := web as WebStrand
	if strand != null:
		var pair := Geometry3D.get_closest_points_between_segments(origin,
			origin + heading * _length, strand.point_a, strand.point_b)
		return pair[0].distance_to(pair[1]) <= radius_at((pair[0] - origin).dot(heading))
	for i in range(SAMPLES + 1):
		var point := origin + heading * _length * float(i) / float(SAMPLES)
		if holds(web.nearest_silk(point)):
			return true
	return false


## Fire running along [param web] as it goes: a bloom at both ends of a line and in
## its middle, or one over the whole of a web.
func _flare(web: WebStructure) -> void:
	var strand := web as WebStrand
	if strand != null:
		for share: float in [0.0, 0.5, 1.0]:
			SpellFlash.burst(get_parent(), strand.point_a.lerp(strand.point_b, share), colour,
				mouth * 4.0, 0.5)
		return
	var net := web as WebNet
	if net != null:
		SpellFlash.burst(get_parent(), net.signal_point(), colour, maxf(net.radius, 0.05), 0.5)


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
