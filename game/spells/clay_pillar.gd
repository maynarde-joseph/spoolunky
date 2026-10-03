class_name ClayPillar
extends StaticBody3D

## A pillar of clay, raised out of whatever the cross is on: up from a floor, out
## of a wall. Square, not round — a block, the way an ice block comes up out of
## water — with one face turned to whoever raised it.
##
## It comes up fast, and what is standing where it comes up goes with it. A creature
## is stunned first, so it rides the pillar up rather than fighting it, then flung
## off the top, hurt, and comes down still stunned: an easy catch. A boss stands its
## ground, and only takes the stun and the hurt. The spider standing there is thrown
## up ahead of it, higher than any jump: a way up, as well as a weapon. A web it
## comes up under is thrown off it — up off its anchors, wrapping what it passes on
## the way, as a web called back does, and what it held comes down bundled where it
## ends up: see [WebPull].
##
## Then it stands for a while — as solid as any wall, something to climb, to tie
## silk to, to put between you and a charge — and sinks back into the ground, and
## any silk tied to it comes down with it.
##
## Water changes it, and which came first decides how:
##
## * **Raised out of a puddle, it is mud.** It drinks the puddle and comes up dark
##   and wet, and what it carries up it does not throw: it holds it fast on its top,
##   going nowhere, for a few seconds — something a thrown web does not have to
##   lead. The spider standing there is thrown as ever: mud grips what it caught,
##   not the one who raised it.
## * **Water on it slumps it.** A drop of the spider's water that lands on a pillar
##   already standing softens it: it sinks back at once, and leaves a wide puddle
##   round where it stood.

const GROUP := "clay_pillars"

## How long it takes to come up, and to sink back, in seconds.
const RISE := 0.25
const SINK := 0.4

## How long what it throws stays stunned once it has come back down, in seconds.
const STUN := 1.0

## How far above its top a creature it throws goes, in the caster's body heights,
## and how far out from its middle it comes down, in its radii: off the top, rather
## than back down onto it.
const HOP := 2.0
const SPILL := 1.5

## How long a creature it throws is thrown for, in seconds: how quickly the push
## out from the pillar dies away.
const THROW := 0.6

## How fast a web it flings goes, in the caster's body heights a second, and how
## far past its top.
const FLING_PACE := 18.0
const FLING_PAST := 4.0

## How far down into the ground its foot goes, as a share of its radius: it stands
## out of rough ground rather than on it.
const ROOT := 0.3

## How near its clay a web's anchor has to be to count as tied to it, as a share of
## its radius.
const TIED := 0.15

## The clay: wet earth, brown and matte; and mud, darker, with a wet shine.
const CLAY := Color(0.45, 0.31, 0.2, 1.0)
const MUD := Color(0.29, 0.2, 0.13, 1.0)

## How long mud holds what it carried up, in seconds.
const MIRE := 4.0

## How wide the puddle a slumped pillar leaves is, as so many times its half-width.
const SLUMP := 2.5

## Where it comes up from, which way, how wide it is from the middle to the middle
## of a face, and how tall it stands, in metres.
var base := Vector3.ZERO
var axis := Vector3.UP
var radius := 0.15
var tall := 1.0

## Square to [member axis] and to each other: the way its front face looks — toward
## whoever raised it — and the way across that face.
var face := Vector3.BACK
var flank := Vector3.RIGHT

## How long it stands, in seconds, counted from when it began to come up.
var lasts := 10.0

## How much of a creature's health it takes from what it comes up under.
var harm := 0.08

## How tall the one who raised it is: how far it throws, and how fast it flings.
var body := 0.25

var colour := Color(0.62, 0.42, 0.26, 1.0)

## Whether it came up out of a puddle, as mud.
var muddy := false

## Everything it came up under, everything of that it threw — or, as mud, held fast
## on its top — whether it threw the spider, and the webs it flung. All but what it
## threw or held known by the time it is raised.
var struck: Array[Prey] = []
var thrown: Array[Prey] = []
var mired: Array[Prey] = []
var spider_thrown := false
var flung: Array[WebNet] = []

var _age := 0.0
var _now := 0.0
var _sinking := -1.0
var _riders: Array[Prey] = []
var _across: Array[Vector3] = []
var _shape: BoxShape3D
var _collider: CollisionShape3D
var _mesh: BoxMesh
var _view: MeshInstance3D


## Raises one under [param host] at [param at], out of ground facing
## [param normal]: [param wide] metres from its middle to the middle of a face and
## [param height] tall, standing for [param seconds], taking [param hurt] of the
## health of what it comes up under, for a caster [param body_height] metres tall.
## [param spider] is thrown if it is standing there. Its front face looks along
## [param looking] as near as it can square to [param normal] — the camera's way
## back, the way an ice block comes up facing whoever raised it — or failing that
## toward [param spider]; out of a wall, a face looks straight up instead, so there
## is a level top to stand on. What it struck, threw and flung can be read straight
## off it.
static func raise(host: Node, at: Vector3, normal: Vector3, wide: float, height: float,
		seconds: float, hurt: float, body_height: float,
		tint := Color(0.62, 0.42, 0.26, 1.0), spider: SpiderPlayer = null,
		looking := Vector3.ZERO) -> ClayPillar:
	if host == null or wide <= 0.0 or height <= 0.0:
		return null
	var pillar := ClayPillar.new()
	pillar.name = "ClayPillar"
	pillar.base = at
	pillar.axis = normal.normalized() if normal.length_squared() > 0.000001 else Vector3.UP
	var toward := looking
	if absf(pillar.axis.dot(Vector3.UP)) < 0.7:
		toward = Vector3.UP
	elif spider != null and _flat(toward, pillar.axis) == Vector3.ZERO:
		toward = spider.global_position - at
	pillar.face = _flat(toward, pillar.axis)
	if pillar.face == Vector3.ZERO:
		pillar.face = _flat(Vector3.BACK if absf(pillar.axis.dot(Vector3.BACK)) < 0.9
			else Vector3.RIGHT, pillar.axis)
	pillar.flank = pillar.axis.cross(pillar.face).normalized()
	pillar.radius = wide
	pillar.tall = height
	pillar.lasts = maxf(seconds, RISE + SINK)
	pillar.harm = hurt
	pillar.body = maxf(body_height, 0.05)
	pillar.colour = tint
	pillar.collision_layer = GameLayers.WORLD
	pillar.collision_mask = 0
	# Out of a puddle, the clay drinks it and comes up as mud.
	for node in host.get_tree().get_nodes_in_group(WetGround.GROUP):
		var wet := node as WetGround
		if wet != null and not wet.is_queued_for_deletion() and wet.holds(at, wide):
			wet.dry()
			pillar.muddy = true
	# After the creatures it carries have moved, so where it puts them is where
	# they are.
	pillar.process_physics_priority = 100
	pillar.add_to_group(GROUP)
	pillar.add_to_group("spell_effects")
	host.add_child(pillar)
	pillar.global_transform = Transform3D(Basis(pillar.flank, pillar.axis, pillar.face), at)
	pillar._build()
	pillar._strike(spider)
	return pillar


## How tall it stands now, in metres.
func height() -> float:
	return _now


## Whether it is still coming up.
func rising() -> bool:
	return _age < RISE


## Whether it is going back into the ground.
func sinking() -> bool:
	return _sinking >= 0.0


## Water landed on it: it softens and sinks back now, leaving a puddle
## [constant SLUMP] times its half-width round its foot if it stands out of the
## floor, wet for [param seconds], in [param tint]. False if it was already going.
func slump(seconds: float, tint := Color(0.36, 0.74, 0.9, 1.0)) -> bool:
	if sinking() or is_queued_for_deletion():
		return false
	_sink()
	if axis.dot(Vector3.UP) >= 0.7:
		WetGround.puddle(get_parent(), base, axis, radius * SLUMP, seconds, tint)
	return true


## Whether [param point] is where it is coming up, or has come up: inside it, to
## within [param margin].
func in_the_way(point: Vector3, margin := 0.0) -> bool:
	var off := point - base
	var up := off.dot(axis)
	if up < -margin or up > tall + margin:
		return false
	return _over(off, margin)


## Whether [param off], from its base, is over its square, to within [param margin].
func _over(off: Vector3, margin: float) -> bool:
	return absf(off.dot(face)) <= radius + margin and absf(off.dot(flank)) <= radius + margin


## [param direction] laid flat against [param normal], as a direction; zero if it
## stands straight out of it.
static func _flat(direction: Vector3, normal: Vector3) -> Vector3:
	var flat := direction - normal * direction.dot(normal)
	return flat.normalized() if flat.length_squared() > 0.000001 else Vector3.ZERO


func _physics_process(delta: float) -> void:
	_age += delta
	if _sinking >= 0.0:
		var gone := clampf((_age - _sinking) / SINK, 0.0, 1.0)
		_set_height(tall * (1.0 - gone))
		if gone >= 1.0:
			queue_free()
		return
	if _age < RISE:
		_set_height(tall * _age / RISE)
		_carry()
		return
	if not _riders.is_empty():
		_set_height(tall)
		_carry()
		_let_fly()
	elif _now < tall:
		_set_height(tall)
	if _age >= lasts:
		_sink()


## Everything standing where it comes up: what it stuns, hurts and carries, the
## spider it throws, and the webs it flings.
func _strike(spider: SpiderPlayer) -> void:
	for node in get_tree().get_nodes_in_group("prey"):
		var creature := node as Prey
		if creature == null or not is_instance_valid(creature) or creature.eaten \
				or creature.is_bundled():
			continue
		if not in_the_way(creature.global_position, creature.hit_radius()):
			continue
		struck.append(creature)
		# Stunned before it is thrown, so it rides up rather than fighting the clay,
		# and for as long as it is in the air and a moment after it lands. Mud throws
		# nothing: up, and held there.
		creature.stun(RISE + (STUN if muddy else _flight() + STUN))
		if harm > 0.0:
			creature.wound(harm)
		if creature.is_loose() and not creature.is_boss() and not creature.is_held():
			_riders.append(creature)
			var off := creature.global_position - base
			_across.append(off - axis * off.dot(axis))
	if spider != null and is_instance_valid(spider) \
			and in_the_way(spider.global_position, body * 0.5):
		# Up ahead of the clay all the way, quickly enough that its top never
		# catches the spider up, and on past it: higher than any jump.
		spider.fling(axis * (tall / RISE + spider.gravity * RISE))
		spider_thrown = true
	for node in get_tree().get_nodes_in_group("silk_webs"):
		var net := node as WebNet
		if net != null and not net.is_queued_for_deletion() and not net.called_back \
				and _comes_up_through(net):
			_fling(net)


## Keeps what it is carrying on its top as it comes up.
func _carry() -> void:
	var climb := axis * tall / RISE
	for i in _riders.size():
		var rider := _riders[i]
		if not is_instance_valid(rider) or rider.eaten:
			continue
		rider.global_position = base + axis * (_now + rider.hit_radius()) + _across[i]
		rider.velocity = climb


## How long something thrown off its top is in the air: up, and down past it to its
## foot.
func _flight() -> float:
	var gravity := _gravity()
	return sqrt(2.0 * HOP * body / gravity) + sqrt(2.0 * (tall + HOP * body) / gravity)


func _gravity() -> float:
	return maxf(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8), 0.1)


## Up: everything it carried is thrown off the top, up and out past its edge — or,
## as mud, held fast where it is.
func _let_fly() -> void:
	if muddy:
		for rider in _riders:
			if is_instance_valid(rider) and not rider.eaten:
				rider.hold_at(rider.global_position, MIRE)
				mired.append(rider)
		_riders.clear()
		_across.clear()
		return
	var speed := sqrt(2.0 * _gravity() * HOP * body)
	for i in _riders.size():
		var rider := _riders[i]
		if not is_instance_valid(rider) or rider.eaten:
			continue
		var out := _across[i]
		var past := maxf(radius * SPILL + rider.hit_radius() - out.length(), radius * 0.5)
		if out.length_squared() < 0.000001:
			out = axis.cross(Vector3.FORWARD if absf(axis.dot(Vector3.FORWARD)) < 0.9
				else Vector3.RIGHT)
		if rider.shove(axis * speed + out.normalized() * _spill_speed(speed, past), THROW):
			thrown.append(rider)
	_riders.clear()
	_across.clear()


## How fast something thrown off the top at [param up] metres a second has to go out
## as well to come down [param out] metres further out. A shove [i]L[/i] long dies
## away at [i]L[/i] over [constant THROW] a second, sideways, so going out at
## [i]s[/i] it gets [i]s² · THROW / 2L[/i] before it stops — and [i]L[/i] has the
## sideways part in it, which makes it a quadratic.
static func _spill_speed(up: float, out: float) -> float:
	var k := 2.0 * maxf(out, 0.0) / THROW
	var squared := (k * k + sqrt(k * k * k * k + 4.0 * k * k * up * up)) * 0.5
	return sqrt(squared)


## Whether any of [param net]'s silk is where it comes up.
func _comes_up_through(net: WebNet) -> bool:
	var steps := maxi(1, ceili(tall / maxf(radius * 0.5, 0.01)))
	for i in range(steps + 1):
		var point := base + axis * tall * float(i) / float(steps)
		if net.nearest_silk(point).distance_to(point) <= radius:
			return true
	return false


## Throws [param net] up off its anchors and on past the top, the frame it was
## walked round on coming down as it goes.
func _fling(net: WebNet) -> void:
	for line in net.frame():
		line.demolish()
	var goal := net.signal_point() + axis * (tall + FLING_PAST * body)
	if WebPull.fling(get_parent(), net, goal, FLING_PACE * body, radius * 2.0, 1.0,
			body) != null:
		flung.append(net)


## Its time is up: back into the ground, and every web or line tied to it comes down
## with it.
func _sink() -> void:
	_sinking = _age
	var margin := maxf(radius * TIED, 0.02)
	for node in get_tree().get_nodes_in_group("silk_webs"):
		var web := node as WebStructure
		if web == null or web.is_queued_for_deletion():
			continue
		for anchor in web.anchors:
			if _holds(anchor, margin):
				web.tear()
				break
	SpellFlash.burst(get_parent(), base, colour, radius * 2.5, 0.4)


## Whether [param point] is on its clay, to within [param margin].
func _holds(point: Vector3, margin: float) -> bool:
	var off := point - base
	var up := off.dot(axis)
	if up < -radius * ROOT - margin or up > _now + margin:
		return false
	return _over(off, margin)


# --- what you can see ----------------------------------------------------

## A square block of brown clay, straight up, with a burst of dust where it comes
## up — or of mud, darker and wet.
func _build() -> void:
	_shape = BoxShape3D.new()
	_collider = CollisionShape3D.new()
	_collider.name = "Clay"
	_collider.shape = _shape
	add_child(_collider)
	_mesh = BoxMesh.new()
	var paint := StandardMaterial3D.new()
	paint.albedo_color = MUD if muddy else CLAY
	paint.roughness = 0.35 if muddy else 1.0
	_view = MeshInstance3D.new()
	_view.name = "Block"
	_view.mesh = _mesh
	_view.material_override = paint
	add_child(_view)
	_set_height(0.0)
	SpellFlash.burst(get_parent(), base, colour, radius * 2.5, 0.35)


func _set_height(height_now: float) -> void:
	_now = height_now
	var foot := radius * ROOT
	var span := maxf(height_now + foot, 0.01)
	var size := Vector3(radius * 2.0, span, radius * 2.0)
	_shape.size = size
	_mesh.size = size
	var middle := Vector3.UP * (span * 0.5 - foot)
	_collider.position = middle
	_view.position = middle
