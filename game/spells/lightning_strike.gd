class_name LightningStrike
extends Node3D

## Lightning, called down where the spider pointed.
##
## It strikes once, at once, and everything it reaches is stunned — out of it for
## a few seconds, going nowhere, biting nothing, fighting nothing (see
## [method Prey.shock]). A hunter stunned gives up the chase and a flier stunned
## falls. Something a web is holding loses a share of its fight as well, so a
## strike is how a web wins a fight it was losing.
##
## What makes it worth more than a stun is where it runs to:
##
## * **Webs.** A strike on a web, or near enough to one, runs through it — and
##   through every web touching it, and every web wired to it — and reaches
##   everything they hold. And it stays: each of them is live for a while after,
##   keeping what it holds stunned and striking anything that touches it — see
##   [WebCharge] — and twice as long in a web Douse left wet. Lines carry nothing:
##   a strike on a line is a strike on the floor under it.
## * **Water.** Anything wet takes it twice as hard and passes it on to anything
##   wet near it, and a strike on a whirl reaches everything the whirl holds.
## * **Storm Rider.** It jumps on from what it struck to what is near, wet or not
##   — see [member arcs].
##
## The spider is never struck by its own lightning: it is not a creature.

const GROUP := "lightning"

## How far a charge jumps from one wet thing to the next, or on an arc, as a share
## of the strike's radius.
const CHAIN_REACH := 1.6

## How long the bolt is on screen, in seconds.
const SHOWN := 0.35

## How bright the flash it lights the room with is, at its brightest.
const FLASH := 3.0

## How long a web it reaches stays live, as so many times the stun.
const LIVE_FOR := 2.0

## How far above the strike the bolt comes down from, in radii — and in metres,
## at the least.
const FALL := 5.0
const FALL_LEAST := 3.0

## How wide it strikes, in metres; how long what it strikes stays stunned, in
## seconds, before anything wet doubles it.
var radius := 1.0
var stun := 2.5

## How many times it jumps on from what it struck to the nearest thing it did not,
## wet or dry. Storm Rider's.
var arcs := 0

## How close two webs' silk has to come for a charge to cross from one to the
## other, in metres.
var touch := 0.2

var colour := Color(0.98, 0.92, 0.55, 1.0)

## What it stunned, and the webs it ran through, in the order it reached them.
var shocked: Array[Prey] = []
var charged: Array[WebStructure] = []

## Where it went, as pairs of points, for drawing.
var _paths: Array = []
var _age := 0.0
var _material: StandardMaterial3D
var _light: OmniLight3D


## Calls one down at [param at] under [param host]. It has struck by the time
## this returns, so what it reached can be read straight off it.
static func call_down(host: Node, at: Vector3, wide: float, stun_for: float, jumps := 0,
		gap := 0.2, tint := Color(0.98, 0.92, 0.55, 1.0)) -> LightningStrike:
	if host == null:
		return null
	var strike := LightningStrike.new()
	strike.name = "LightningStrike"
	strike.radius = maxf(wide, 0.05)
	strike.stun = stun_for
	strike.arcs = maxi(jumps, 0)
	strike.touch = maxf(gap, 0.01)
	strike.colour = tint
	strike.add_to_group(GROUP)
	strike.add_to_group("spell_effects")
	host.add_child(strike)
	strike.global_position = at
	strike.discharge()
	strike._build_view()
	return strike


func _process(delta: float) -> void:
	_age += delta
	var left := clampf(1.0 - _age / SHOWN, 0.0, 1.0)
	if _material != null:
		_material.albedo_color.a = left
	if _light != null:
		_light.light_energy = FLASH * left
	if _age >= SHOWN:
		queue_free()


# --- where it goes ------------------------------------------------------

## Strikes: works out everything it reaches and stuns it.
func discharge() -> void:
	var at := global_position
	var creatures: Array[Prey] = []
	for node in get_tree().get_nodes_in_group("prey"):
		var creature := node as Prey
		if creature != null and is_instance_valid(creature) and not creature.eaten:
			creatures.append(creature)

	# What it lands on.
	for creature in creatures:
		if creature.global_position.distance_to(at) <= radius + creature.hit_radius():
			_shock(creature, at)

	# Water: a whirl it lands in, or near enough to touch, carries it to all it holds.
	for node in get_tree().get_nodes_in_group(WaterSpiral.GROUP):
		var whirl := node as WaterSpiral
		if whirl == null or not whirl.spinning():
			continue
		var offset := at - whirl.global_position
		if not whirl.holds(at) and Vector2(offset.x, offset.z).length() > whirl.radius + radius:
			continue
		var eye := whirl.eye()
		_paths.append([at, eye])
		for creature in whirl.held():
			_shock(creature, eye)

	# Webs: every one it reaches, every one those touch or are wired to, and
	# everything any of them holds — and the charge stays in all of them. Not lines.
	var frontier: Array[WebStructure] = []
	for node in get_tree().get_nodes_in_group("silk_webs"):
		var web := node as WebNet
		if web == null or web.is_queued_for_deletion() or not web.reaches(at, radius):
			continue
		charged.append(web)
		frontier.append(web)
		_paths.append([at, _middle(web)])
	while not frontier.is_empty():
		var web: WebStructure = frontier.pop_back()
		for held in web.snared_prey():
			var creature := held as Prey
			if creature != null:
				_shock(creature, _middle(web))
		for other in _neighbours(web):
			if charged.has(other):
				continue
			charged.append(other)
			frontier.append(other)
			_paths.append([_middle(web), _middle(other)])
	for web in charged:
		var live := stun * LIVE_FOR * (WetSilk.LIVE_LONGER if WetSilk.is_wet(web) else 1.0)
		WebCharge.lay(web, live, stun, colour)

	# Water carries it on: anything wet near anything wet that it reached.
	var reach := radius * CHAIN_REACH
	var wet: Array[Prey] = []
	for creature in shocked:
		if creature.is_wet():
			wet.append(creature)
	while not wet.is_empty():
		var from: Prey = wet.pop_back()
		for creature in creatures:
			if shocked.has(creature) or not creature.is_wet():
				continue
			if creature.global_position.distance_to(from.global_position) <= reach:
				if _shock(creature, from.global_position):
					wet.append(creature)

	# And the storm: it jumps on to whatever is nearest, wet or not.
	for i in arcs:
		var best: Prey = null
		var best_gap := reach
		var from_point := at
		for creature in creatures:
			if shocked.has(creature) or (not creature.is_loose() and not creature.is_stuck()):
				continue
			for struck in shocked:
				var gap := creature.global_position.distance_to(struck.global_position)
				if gap < best_gap:
					best_gap = gap
					best = creature
					from_point = struck.global_position
		if best == null:
			break
		_shock(best, from_point)


func _shock(creature: Prey, from: Vector3) -> bool:
	if creature == null or shocked.has(creature) or not creature.shock(stun):
		return false
	shocked.append(creature)
	_paths.append([from, creature.global_position])
	return true


## The webs a charge in [param web] crosses to: any whose silk comes within
## [member touch] of its own, and any it is wired to either way. Webs only — never
## a line.
func _neighbours(web: WebStructure) -> Array[WebStructure]:
	var found: Array[WebStructure] = []
	for link in web.links:
		var linked := link as WebNet
		if linked != null and is_instance_valid(linked):
			found.append(linked)
	for source in web.linked_sources():
		var linked := source as WebNet
		if linked != null and is_instance_valid(linked) and not found.has(linked):
			found.append(linked)
	for node in get_tree().get_nodes_in_group("silk_webs"):
		var other := node as WebNet
		if other == null or other == web or other.is_queued_for_deletion() or found.has(other):
			continue
		for anchor in web.anchors:
			if other.reaches(anchor, touch):
				found.append(other)
				break
	return found


## The middle of a web's silk, for drawing a charge to and from.
static func _middle(web: WebStructure) -> Vector3:
	var net := web as WebNet
	if net != null:
		return net.to_global(net.centre_local)
	var strand := web as WebStrand
	if strand != null:
		return (strand.point_a + strand.point_b) * 0.5
	return web.global_position


# --- what you can see ----------------------------------------------------

## The bolt from above, and a crooked line for every place it ran on to: along
## the silk, through the water, into everything it stunned. Crooked on purpose —
## a straight line is a laser — and thin, the width of silk a few times over.
func _build_view() -> void:
	var at := global_position
	var width := maxf(radius * 0.03, 0.008)
	var strands := WebGeometry.StrandSet.new()
	var drop := maxf(radius * FALL, FALL_LEAST)
	var top := at + Vector3.UP * drop
	zigzag(strands, top, at, 14, drop * 0.05, width * 1.5)
	# Two short forks off the main bolt, part way down.
	for fork in 2:
		var from := top.lerp(at, 0.35 + 0.25 * float(fork))
		var out := Vector3(randf_range(-1.0, 1.0), -0.6, randf_range(-1.0, 1.0)).normalized()
		zigzag(strands, from, from + out * drop * 0.18, 4, drop * 0.02, width)
	for path in _paths:
		var a: Vector3 = path[0]
		var b: Vector3 = path[1]
		zigzag(strands, a, b, maxi(3, int(a.distance_to(b) / maxf(radius * 0.15, 0.01))),
			a.distance_to(b) * 0.08, width * 0.7)
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	var bolt := MeshInstance3D.new()
	bolt.name = "Bolt"
	bolt.mesh = WebGeometry.build_mesh(strands, colour)
	_material.vertex_color_use_as_albedo = true
	bolt.material_override = _material
	bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bolt.top_level = true
	add_child(bolt)
	bolt.global_transform = Transform3D.IDENTITY
	_light = OmniLight3D.new()
	_light.name = "Flash"
	_light.light_color = colour
	_light.light_energy = FLASH
	_light.omni_range = radius * 4.0
	add_child(_light)
	_light.position = Vector3.UP * radius * 0.5
	SpellFlash.burst(get_parent(), at, colour, radius * 0.6, 0.25)


## A crooked line from [param from] to [param to] in [param pieces] pieces, each
## bend up to [param wander] off the straight: what a charge looks like going
## somewhere.
static func zigzag(strands: WebGeometry.StrandSet, from: Vector3, to: Vector3, pieces: int,
		wander: float, width: float) -> void:
	var span := to - from
	if span.length_squared() < 0.000001:
		return
	var axis := span.normalized()
	var side := axis.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = axis.cross(Vector3.RIGHT)
	side = side.normalized()
	var other := axis.cross(side).normalized()
	var previous := from
	for i in range(1, pieces + 1):
		var t := float(i) / float(pieces)
		var point := from + span * t
		if i < pieces:
			point += side * randf_range(-wander, wander) + other * randf_range(-wander, wander)
		strands.add(previous, point, width)
		previous = point
