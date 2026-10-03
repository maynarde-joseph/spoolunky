class_name Steam
extends Node3D

## A cloud of steam: a puddle the spider's fire boiled off.
##
## No spell casts it on its own. Douse leaves puddles where its drops land; a breath
## of fire that reaches one boils it away, and the steam rises off the ground where
## it was — see [WetGround] and [FireBreath].
##
## Everything in it is soaked, fliers included — and wet wings do not lift — and
## scalded a little every moment it stays. Soaked carries lightning twice as hard and
## on to anything wet near it (see [LightningStrike]), so a strike into the steam
## reaches all of it.

const GROUP := "steam"

## How often it soaks and scalds what is in it, in seconds.
const PULSE := 0.25

## How long it takes to rise, and to thin away at the end, in seconds.
const RISE := 0.3
const FADE := 1.0

## How many puffs it is drawn as. Looks only.
const PUFFS := 7

## Where it rises from, which way is up from the ground there, how wide it is from
## the middle to its edge, and how tall it stands, in metres.
var base := Vector3.ZERO
var up := Vector3.UP
var radius := 0.3
var tall := 1.0

## How long it hangs there, in seconds, and how much of a creature's health it
## takes every second something stays in it.
var life := 4.0
var scald := 0.04

var colour := Color(0.92, 0.95, 0.97, 1.0)

## Everything it soaked, in the order it reached them.
var soaked: Array[Prey] = []

var _age := 0.0
var _pulse := 0.0
var _puffs: Array[MeshInstance3D] = []
var _drift: Array[Vector3] = []
var _paint: StandardMaterial3D


## Boils one off under [param host] at [param at], on ground facing [param normal]:
## [param wide] metres from the middle to its edge and [param height] tall, hanging
## for [param seconds] and taking [param hurt] of a creature's health every second.
static func boil(host: Node, at: Vector3, normal: Vector3, wide: float, height: float,
		seconds: float, hurt: float) -> Steam:
	if host == null or wide <= 0.0 or height <= 0.0:
		return null
	var cloud := Steam.new()
	cloud.name = "Steam"
	cloud.base = at
	cloud.up = normal.normalized() if normal.length_squared() > 0.000001 else Vector3.UP
	cloud.radius = wide
	cloud.tall = height
	cloud.life = maxf(seconds, RISE + FADE)
	cloud.scald = maxf(hurt, 0.0)
	cloud.add_to_group(GROUP)
	cloud.add_to_group("spell_effects")
	host.add_child(cloud)
	cloud.global_transform = MagicCircle.facing(at, cloud.up)
	cloud._build_view()
	return cloud


## Whether it is still hanging there.
func lingering() -> bool:
	return _age < life


## Whether [param point] is in it, within [param margin], while it lasts.
func holds(point: Vector3, margin := 0.0) -> bool:
	if not lingering():
		return false
	var off := point - base
	var rise := off.dot(up)
	if rise < -margin or rise > tall + margin:
		return false
	return (off - up * rise).length() <= radius + margin


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= life + FADE:
		queue_free()
		return
	if not lingering():
		return
	_pulse -= delta
	if _pulse > 0.0:
		return
	_pulse = PULSE
	for node in get_tree().get_nodes_in_group("prey"):
		var creature := node as Prey
		if creature == null or not is_instance_valid(creature) or creature.eaten \
				or not holds(creature.global_position, creature.hit_radius()):
			continue
		creature.soak(WetGround.SOAK)
		# Steam scalds what it touches, silk or none; something bundled is caught, and
		# left be.
		if scald > 0.0 and not creature.is_bundled():
			creature.wound(scald * PULSE)
		if not soaked.has(creature):
			soaked.append(creature)


func _process(delta: float) -> void:
	if _paint == null:
		return
	var shown := clampf(_age / RISE, 0.0, 1.0)
	if not lingering():
		shown = 1.0 - clampf((_age - life) / FADE, 0.0, 1.0)
	_paint.albedo_color.a = 0.35 * shown
	for i in _puffs.size():
		var puff := _puffs[i]
		puff.position += _drift[i] * delta
		if puff.position.y > tall:
			puff.position.y -= tall
		var height_share := clampf(puff.position.y / tall, 0.0, 1.0)
		puff.scale = Vector3.ONE * radius * lerpf(0.45, 0.8, height_share)


# --- what you can see ----------------------------------------------------

## Pale puffs drifting up through it, swelling as they rise.
func _build_view() -> void:
	_paint = StandardMaterial3D.new()
	_paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	_paint.albedo_color = Color(colour.r, colour.g, colour.b, 0.0)
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 10
	sphere.rings = 5
	for i in PUFFS:
		var turn := TAU * float(i) / float(PUFFS)
		var out := radius * 0.45 * randf_range(0.2, 1.0)
		var puff := MeshInstance3D.new()
		puff.name = "Puff"
		puff.mesh = sphere
		puff.material_override = _paint
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		puff.position = Vector3(cos(turn) * out, tall * float(i) / float(PUFFS), sin(turn) * out)
		add_child(puff)
		_puffs.append(puff)
		_drift.append(Vector3(randf_range(-0.1, 0.1) * radius, tall * randf_range(0.25, 0.4),
			randf_range(-0.1, 0.1) * radius))
