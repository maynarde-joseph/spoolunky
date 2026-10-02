class_name WaterSpiral
extends Node3D

## A whirl of water, where the spider pointed.
##
## For as long as it spins it takes hold of anything loose that comes inside it —
## walking, flying or swimming — and carries it round and in towards the middle,
## where it is held turning. What it holds is soaked, and stays wet for a while
## after it gets out, and wet wings do not lift: a flier that has been through it
## comes down and cannot climb again until it dries.
##
## On its own it is a way to hold things still, and to bring fliers down to where
## silk is easy. It is better with the rest of what the spider has:
##
## * **Silk.** It carries things round and in, and whatever it carries through a
##   web is caught by the web the ordinary way — so a whirl beside a web fills it.
## * **Lightning.** Everything in it is wet, and water carries a strike to all of
##   it — see [LightningStrike].
## * **Digestive Flood.** The spider's water eats what it holds: everything in it
##   is dosed from the moment it goes in.

const GROUP := "water_spirals"

## How far up from its floor it reaches, and how far down, as shares of its
## radius. Tall rather than flat, so it has fliers too.
const REACH_UP := 1.6
const REACH_DOWN := 0.4

## How long something stays wet once it is out, in seconds.
const SOAK := 6.0

## How fast it carries what it holds, in radii a second: round, and in. Round is
## faster near the middle, the way water goes down a drain.
const SWIRL := 2.4
const DRAW := 1.1

## The eye, as a share of the radius: nearer the middle than this, nothing is
## drawn in any further and it only turns.
const EYE := 0.18

## The height it holds things at, as a share of its radius above its floor.
const HOLD_AT := 0.25

## How long it takes to rise, and to sink away once it is spent, in seconds.
const RISE := 0.25
const FADE := 0.4

## How much of the spray round it shows. Enough to read which way it turns, and
## no more: it is the water that matters, not the streaks on it.
const STREAK_ALPHA := 0.6

## How wide it is and how long it spins, in metres and seconds.
var radius := 1.0
var life := 5.0

## Whether its water eats what it holds, and how hard. The spider's, from
## Digestive Flood.
var acid := false
var venom_strength := 1.0

var colour := Color(0.36, 0.74, 0.9, 1.0)

var _age := 0.0
var _view: Node3D
var _water: StandardMaterial3D
var _streaks: StandardMaterial3D


## Raises one at [param at] under [param host], [param wide] metres from the
## middle to the rim, for [param lasts] seconds. [param eats] is whether its water
## doses what it holds, at [param strength]; [param tint] is the colour of it.
static func summon(host: Node, at: Vector3, wide: float, lasts: float, eats := false,
		strength := 1.0, tint := Color(0.36, 0.74, 0.9, 1.0)) -> WaterSpiral:
	if host == null:
		return null
	var whirl := WaterSpiral.new()
	whirl.name = "WaterSpiral"
	whirl.radius = maxf(wide, 0.05)
	whirl.life = maxf(lasts, 0.1)
	whirl.acid = eats
	whirl.venom_strength = strength
	whirl.colour = tint
	whirl.add_to_group(GROUP)
	whirl.add_to_group("spell_effects")
	host.add_child(whirl)
	whirl.global_position = at
	return whirl


func _ready() -> void:
	_build_view()


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= life + FADE:
		queue_free()
		return
	if spinning():
		for creature in held():
			creature.soak(SOAK)
			creature.sweep(carry_at(creature.global_position))
			if acid:
				creature.poison(1.5, venom_strength)
	_update_view(delta)


## Whether it is still turning. Spent, it sinks away and holds nothing.
func spinning() -> bool:
	return _age < life


## Whether [param point] is inside it.
func holds(point: Vector3) -> bool:
	var offset := point - global_position
	if offset.y < -radius * REACH_DOWN or offset.y > radius * REACH_UP:
		return false
	return Vector2(offset.x, offset.z).length() <= radius


## Everything loose that it has hold of now.
func held() -> Array[Prey]:
	var found: Array[Prey] = []
	if not spinning():
		return found
	for node in get_tree().get_nodes_in_group("prey"):
		var creature := node as Prey
		if creature == null or not is_instance_valid(creature) or not creature.is_loose():
			continue
		if holds(creature.global_position):
			found.append(creature)
	return found


## How fast, and which way, it carries something at [param point]: round, in
## towards the eye, and up or down to the height it holds things at.
func carry_at(point: Vector3) -> Vector3:
	var offset := point - global_position
	var flat := Vector3(offset.x, 0.0, offset.z)
	var across := flat.length()
	var out := flat / across if across > 0.0001 else Vector3.RIGHT
	var near := clampf(1.0 - across / radius, 0.0, 1.0)
	var velocity := Vector3.UP.cross(out) * SWIRL * radius * (0.35 + 0.65 * near)
	if across > radius * EYE:
		velocity -= out * DRAW * radius
	var level := global_position.y + radius * HOLD_AT
	velocity.y = clampf((level - point.y) * 3.0, -DRAW * radius, DRAW * radius)
	return velocity


# --- what you can see ----------------------------------------------------

## A funnel of water turning on its point, with streaks round it to show which
## way. Built at a radius of one and scaled, so its size is one number.
func _build_view() -> void:
	_view = Node3D.new()
	_view.name = "View"
	add_child(_view)
	_view.scale = Vector3.ONE * radius

	var funnel := CylinderMesh.new()
	funnel.top_radius = 1.0
	funnel.bottom_radius = 0.15
	funnel.height = 0.7
	funnel.radial_segments = 32
	funnel.rings = 1
	funnel.cap_top = false
	funnel.cap_bottom = false
	_water = StandardMaterial3D.new()
	_water.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_water.cull_mode = BaseMaterial3D.CULL_DISABLED
	_water.albedo_color = Color(colour.r, colour.g, colour.b, 0.28)
	var body := MeshInstance3D.new()
	body.name = "Funnel"
	body.mesh = funnel
	body.material_override = _water
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.position = Vector3(0.0, 0.35, 0.0)
	_view.add_child(body)

	# Three arms of spray, spiralling down the funnel from the rim to the eye.
	var strands := WebGeometry.StrandSet.new()
	for arm in 3:
		var previous := Vector3.ZERO
		for step in 25:
			var t := float(step) / 24.0
			var turn := float(arm) * TAU / 3.0 + t * TAU * 1.25
			var across := lerpf(1.0, 0.15, t)
			var point := Vector3(cos(turn) * across, lerpf(0.7, 0.02, t), sin(turn) * across)
			if step > 0:
				strands.add(previous, point, 0.022)
			previous = point
	_streaks = StandardMaterial3D.new()
	_streaks.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_streaks.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_streaks.cull_mode = BaseMaterial3D.CULL_DISABLED
	_streaks.albedo_color = Color(0.78, 0.93, 1.0, STREAK_ALPHA)
	var spray := MeshInstance3D.new()
	spray.name = "Spray"
	spray.mesh = WebGeometry.build_mesh(strands, Color(1, 1, 1, 1))
	spray.material_override = _streaks
	spray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_view.add_child(spray)


func _update_view(delta: float) -> void:
	if _view == null:
		return
	_view.rotate_y(-SWIRL * delta)
	var rising := clampf(_age / RISE, 0.0, 1.0)
	var sinking := clampf((_age - life) / FADE, 0.0, 1.0)
	var height := rising * (1.0 - sinking)
	_view.scale = Vector3(radius, radius * maxf(height, 0.02), radius)
	if _water != null:
		_water.albedo_color.a = 0.28 * (1.0 - sinking)
	if _streaks != null:
		_streaks.albedo_color.a = STREAK_ALPHA * (1.0 - sinking)
