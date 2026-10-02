class_name FireGeyser
extends Node3D

## A geyser of fire, out of the ground where the cross is.
##
## A ring glows on the ground where it will come up, and a moment later it bursts: a
## column of fire as wide as the wind-up made it, standing for half a second. It
## throws everything it catches up into the air and burns it the way fire burns — a
## fifth of its harm to something bare, all of it to something wrapped or held in a
## web (see [method Prey.burn]).
##
## Silk burns. Every web and line in the column goes up, a web with the frame it was
## walked round on, and what a web held drops out of it burned. A wet web does not —
## see [WetSilk] — so a web the spider has doused stands in the fire, and catches
## whatever the geyser throws up into it.

## Burst: everything it burned, and how many webs and lines went up in it.
signal erupted(geyser: FireGeyser, burned: Array[Prey], webs: int, lines: int)

const GROUP := "fire_geysers"

## How long the ground glows before it bursts, in seconds: long enough to see it
## coming, short enough to be where you aimed it.
const WARN := 0.45

## How long the column stands once it has burst, and how long it takes to die down,
## in seconds.
const BURN := 0.5
const FADE := 0.35

## How tall the column stands, in the caster's body heights.
const TALL := 5.0

## How high it throws what it catches, in the caster's body heights: a walker and a
## flier alike go up about this far before they come down.
const THROW_UP := 3.0

## How wide it is, from the middle to the rim, and how tall, in metres.
var radius := 0.5
var tall := 1.25

## How much of a creature's health it takes, wrapped all the way; how hard it
## throws, in metres a second, and for how long, in seconds.
var harm := 0.4
var throw_speed := 3.5
var throw_for := 0.35

var colour := Color(1.0, 0.45, 0.12, 1.0)

## Everything it has burned, first to last, and how many webs and lines went up.
var burned: Array[Prey] = []
var webs_burned := 0
var lines_burned := 0

var _age := 0.0
var _burst := false
var _ring: MeshInstance3D
var _ring_paint: StandardMaterial3D
var _column: MeshInstance3D
var _column_paint: StandardMaterial3D
var _light: OmniLight3D


## Raises one under [param host] at [param at], on the ground, [param wide] metres
## from its middle to its rim, for a caster [param body] metres tall; a creature
## wrapped all the way loses [param hurt] of its health in it.
static func erupt(host: Node, at: Vector3, wide: float, body: float, hurt: float,
		tint := Color(1.0, 0.45, 0.12, 1.0)) -> FireGeyser:
	if host == null:
		return null
	var geyser := FireGeyser.new()
	geyser.name = "FireGeyser"
	geyser.radius = maxf(wide, 0.05)
	geyser.tall = body * TALL
	geyser.harm = hurt
	# Thrown as fast as it takes to rise that high, for as long as it takes to: a
	# walker falls the rest of the way on its own, and a flier's throw dies away
	# over the same time, so both go up as far.
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	geyser.throw_speed = sqrt(2.0 * gravity * THROW_UP * body)
	geyser.throw_for = geyser.throw_speed / gravity
	geyser.colour = tint
	geyser.add_to_group(GROUP)
	geyser.add_to_group("spell_effects")
	host.add_child(geyser)
	geyser.global_position = at
	geyser._build_view()
	return geyser


## Whether it has burst yet.
func has_burst() -> bool:
	return _burst


## Whether it is burning now: burst, and not yet dying down.
func burning() -> bool:
	return _burst and _age < WARN + BURN


## Whether [param point] is in the column, within [param margin].
func holds(point: Vector3, margin := 0.0) -> bool:
	var off := point - global_position
	if Vector2(off.x, off.z).length() > radius + margin:
		return false
	return off.y >= -margin - radius * 0.25 and off.y <= tall + margin


func _physics_process(delta: float) -> void:
	_age += delta
	if not _burst and _age >= WARN:
		_burst = true
		_burn_creatures()
		_burn_silk()
		erupted.emit(self, burned, webs_burned, lines_burned)
	elif burning():
		_burn_creatures()
	if _age >= WARN + BURN + FADE:
		queue_free()


func _process(_delta: float) -> void:
	_update_view()


## Everything in the column burns and is thrown up — once each.
func _burn_creatures() -> void:
	for node in get_tree().get_nodes_in_group("prey"):
		var creature := node as Prey
		if creature == null or not is_instance_valid(creature) or creature.eaten \
				or burned.has(creature):
			continue
		if not holds(creature.global_position, creature.hit_radius()):
			continue
		_burn(creature)
		creature.shove(Vector3.UP * throw_speed, throw_for)


func _burn(creature: Prey) -> void:
	if burned.has(creature):
		return
	burned.append(creature)
	creature.burn(harm)
	SpellFlash.burst(get_parent(), creature.global_position, colour,
		creature.hit_radius() * 2.5, 0.5)


## Every web and line in the column goes up, a web with its frame — unless it is
## wet. What a web held burns as it goes, held in silk as it is, and drops out.
func _burn_silk() -> void:
	var burning_now: Array[WebStructure] = []
	for node in get_tree().get_nodes_in_group("silk_webs"):
		var web := node as WebStructure
		if web != null and not web.is_queued_for_deletion() and not WetSilk.is_wet(web) \
				and _reaches(web):
			burning_now.append(web)
	var frames: Array[WebStructure] = []
	for web in burning_now:
		var net := web as WebNet
		if net == null:
			continue
		for line in net.frame():
			if not burning_now.has(line) and not frames.has(line) and not WetSilk.is_wet(line):
				frames.append(line)
	for web in burning_now + frames:
		for held in web.snared_prey():
			var creature := held as Prey
			if creature != null and is_instance_valid(creature):
				_burn(creature)
		_flare(web)
		web.tear()
		if web is WebNet:
			webs_burned += 1
		elif not frames.has(web):
			lines_burned += 1


## Whether any of [param web]'s silk is in the column.
func _reaches(web: WebStructure) -> bool:
	for anchor in web.anchors:
		if holds(anchor):
			return true
	var steps := maxi(ceili(tall / maxf(radius, 0.05)), 1)
	for i in range(steps + 1):
		var point := global_position + Vector3.UP * tall * float(i) / float(steps)
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
				radius, 0.5)
		return
	var net := web as WebNet
	if net != null:
		SpellFlash.burst(get_parent(), net.signal_point(), colour, maxf(net.radius, 0.05), 0.5)


# --- what you can see ----------------------------------------------------

func _build_view() -> void:
	_ring_paint = StandardMaterial3D.new()
	_ring_paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ring_paint.albedo_color = Color(colour.r, colour.g * 0.8, colour.b * 0.5, 0.0)
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = maxf(radius * 0.02, 0.005)
	disc.radial_segments = 32
	disc.rings = 1
	_ring = MeshInstance3D.new()
	_ring.name = "Glow"
	_ring.mesh = disc
	_ring.material_override = _ring_paint
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.position = Vector3.UP * radius * 0.02
	add_child(_ring)

	_column_paint = StandardMaterial3D.new()
	_column_paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_column_paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_column_paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	_column_paint.albedo_color = Color(colour.r, colour.g, colour.b, 0.0)
	var column := CylinderMesh.new()
	column.top_radius = radius * 0.55
	column.bottom_radius = radius
	column.height = 1.0
	column.radial_segments = 24
	column.rings = 1
	column.cap_top = false
	column.cap_bottom = false
	_column = MeshInstance3D.new()
	_column.name = "Column"
	_column.mesh = column
	_column.material_override = _column_paint
	_column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_column.visible = false
	add_child(_column)

	_light = OmniLight3D.new()
	_light.name = "Glow"
	_light.light_color = colour
	_light.omni_range = tall * 1.5
	_light.light_energy = 0.0
	add_child(_light)
	_light.position = Vector3.UP * tall * 0.4


## The ground glows brighter as it gathers, then the column shoots up to its full
## height in a tenth of a second, flickers while it stands, and sinks as it dies.
func _update_view() -> void:
	if _ring_paint == null:
		return
	if not _burst:
		var gathering := clampf(_age / WARN, 0.0, 1.0)
		_ring_paint.albedo_color.a = 0.25 + 0.5 * gathering * (0.8 + 0.2 * sin(_age * 30.0))
		_light.light_energy = 0.6 * gathering
		return
	var since := _age - WARN
	var rising := clampf(since / 0.1, 0.0, 1.0)
	var dying := clampf((since - BURN) / FADE, 0.0, 1.0)
	var flicker := 0.85 + 0.15 * sin(_age * 37.0)
	var height := tall * rising * (1.0 - dying * 0.7)
	_column.visible = height > 0.01
	_column.scale = Vector3(flicker, maxf(height, 0.01), flicker)
	_column.position = Vector3.UP * height * 0.5
	_column_paint.albedo_color.a = 0.75 * (1.0 - dying)
	_ring_paint.albedo_color.a = 0.6 * (1.0 - dying)
	_light.light_energy = 2.5 * flicker * (1.0 - dying)
