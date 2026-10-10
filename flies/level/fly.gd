class_name Fly
extends Node3D

## A fly: something to catch, and once caught, somewhere to go.
##
## A web that flies into a fly wraps it, and the fly stops dead where it was: a
## grapple point in the middle of the air, held there by your web — which counts as
## one of yours out until you deal with it. Reach it, by grappling to it or riding a
## web into it, and you take it: the fly is yours, the web comes back, the grapple
## with it, and you hang strung up in the air for a moment. Or call the web home
## and the fly comes with it, and is yours without your going anywhere.
##
## The bag at the exit only opens once every fly in the level is taken — so a level
## with flies is a route: which to use as stepping stones, which to pull in, and in
## what order.
##
## A fly keeps still, flies back and forth along a line, or circles round where it
## was put, all three on the level's clock: the same at the same time on every try.
##
## It is drawn low poly, like everything else — see [FlyBody] — big enough to pick
## out across a room, facing the way it flies, wings buzzing and legs hanging. It
## can glow yellow, too.

signal taken(fly: Fly)

enum State {
	FREE,    ## flying, or hanging still where it was put
	CAUGHT,  ## wrapped in a web, a grapple point
	TAKEN,   ## the spider's
}

const GROUP := "flies"

## How big its body is, from the middle out, in metres.
const SIZE := 0.45
## How near the middle of a web's path a fly has to be to be caught, besides the
## web's own size.
const HIT := 0.9
const YELLOW := Color(1.0, 0.85, 0.25)

## How it moves: "still", "line" (back and forth along [member travel]) or
## "orbit" (round where it was put, about [member axis], [member radius] out).
var move := "still"
## For a line: from where it was put to the far end.
var travel := Vector3(0.0, 0.0, -4.0)
## For an orbit: the axis it goes round, and how far out.
var axis := Vector3.UP
var radius := 2.5
## How long a whole trip takes — there and back, or once round — in seconds, and
## how far into it the fly is at the start, as a share of a trip.
var period := 4.0
var phase := 0.0
## Whether it glows.
var glow := true
## Kept where it was put, as the level editor shows it: it still buzzes, but goes
## nowhere.
var frozen := false

var state := State.FREE
## The web holding it, while it is caught.
var web: Node3D = null

var _home := Vector3.ZERO
var _body: FlyBody
var _cocoon: MeshInstance3D
var _halo: MeshInstance3D
var _light: OmniLight3D
var _clock := 0.0
## Which way it faces, flat: the way it was put, then the way it goes.
var _heading := Vector3.FORWARD


func _ready() -> void:
	add_to_group(GROUP)
	_home = global_position
	_build()
	if not frozen:
		_place(0.0)


## Where it is at [param seconds] on the level's clock, if it is still free.
func where_at(seconds: float) -> Vector3:
	var trip := TAU * (seconds / maxf(period, 0.1) + phase)
	match move:
		"line":
			return _home + travel * (0.5 - 0.5 * cos(trip))
		"orbit":
			var around := axis.normalized() if axis.length_squared() > 0.0001 else Vector3.UP
			var helper := Vector3.RIGHT if absf(around.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
			var u := around.cross(helper).normalized()
			var v := around.cross(u).normalized()
			return _home + (u * cos(trip) + v * sin(trip)) * radius
	return _home


## Points along the way it goes, for drawing it, and for the reach check to try.
func route(count := 16) -> PackedVector3Array:
	var points := PackedVector3Array()
	if move == "still":
		points.append(_home)
		return points
	for i in count:
		points.append(where_at(period * float(i) / float(count) - phase * period))
	return points


func is_free() -> bool:
	return state == State.FREE


func is_caught() -> bool:
	return state == State.CAUGHT


## Wrapped by [param holder]: it stops where it is, folds its wings, and waits.
func catch(holder: Node3D) -> void:
	if state != State.FREE:
		return
	state = State.CAUGHT
	web = holder
	_cocoon.visible = true
	_body.fold()


## Taken by the spider at [param by]: it goes to it, small, and is gone.
func take(by: Node3D = null) -> void:
	if state == State.TAKEN:
		return
	state = State.TAKEN
	web = null
	remove_from_group(GROUP)
	taken.emit(self)
	var shrink := create_tween()
	shrink.set_parallel(true)
	shrink.tween_property(self, "scale", Vector3.ONE * 0.05, 0.25)
	if by != null and is_instance_valid(by):
		shrink.tween_property(self, "global_position", by.global_position, 0.25)
	shrink.chain().tween_callback(queue_free)


## Puts its glow on or off.
func set_glow(on: bool) -> void:
	glow = on
	if _halo != null:
		_halo.visible = on
		_light.visible = on


func _process(delta: float) -> void:
	if state != State.FREE:
		return
	_clock += delta
	var was := global_position
	if not frozen:
		var run := LevelRun.current(self)
		_place(run.time if run != null else 0.0)
	# Facing the way it goes, turning into it rather than snapping round.
	var going := global_position - was
	going.y = 0.0
	if going.length() > 0.0005:
		_heading = _heading.slerp(going.normalized(), clampf(delta * 6.0, 0.0, 1.0)).normalized()
	_body.global_basis = Basis.looking_at(_heading, Vector3.UP).scaled(Vector3.ONE * _body_scale())
	# A hover's bob and sway.
	_body.position = Vector3(0.0, sin(_clock * 3.1) * 0.06, 0.0)
	_body.rotation.z = sin(_clock * 2.3) * 0.08


func _place(seconds: float) -> void:
	if state == State.FREE:
		global_position = where_at(seconds)


# --- how it looks ------------------------------------------------------------------

static var _haze_paint: ShaderMaterial = null


## The glow's paint: only the inside of the ball, fading out toward its rim.
static func _haze() -> ShaderMaterial:
	if _haze_paint != null:
		return _haze_paint
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0, 0.85, 0.25, 0.55);
void fragment() {
	float straight = abs(dot(normalize(NORMAL), normalize(VIEW)));
	ALBEDO = tint.rgb;
	ALPHA = tint.a * pow(straight, 3.0);
}
"""
	_haze_paint = ShaderMaterial.new()
	_haze_paint.shader = shader
	return _haze_paint


## How much bigger than its body units it is drawn: about a metre and a half
## from head to tail.
static func _body_scale() -> float:
	return SIZE * 3.2 / FlyBody.LENGTH


func _build() -> void:
	_heading = -global_basis.z
	_heading.y = 0.0
	_heading = _heading.normalized() if _heading.length() > 0.01 else Vector3.FORWARD
	_body = FlyBody.new()
	_body.name = "Body"
	add_child(_body)
	_body.global_basis = Basis.looking_at(_heading, Vector3.UP).scaled(Vector3.ONE * _body_scale())

	# Wrapped: silk round it, head to tail, turned with it.
	_cocoon = MeshInstance3D.new()
	_cocoon.name = "Cocoon"
	var wrap := SphereMesh.new()
	wrap.radial_segments = 10
	wrap.rings = 6
	_cocoon.mesh = wrap
	_cocoon.scale = Vector3(1.0, 0.9, 1.9)
	_cocoon.position = Vector3(0.0, 0.0, 0.15)
	var silk := StandardMaterial3D.new()
	silk.albedo_color = Color(0.95, 0.96, 1.0, 0.75)
	silk.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	silk.emission_enabled = true
	silk.emission = Color(0.85, 0.9, 1.0)
	silk.emission_energy_multiplier = 0.4
	_cocoon.material_override = silk
	_cocoon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cocoon.visible = false
	_body.add_child(_cocoon)

	# The glow: a soft yellow haze behind it from wherever you look — the far side
	# of a ball round it, brightest straight through the middle — and a little light.
	_halo = MeshInstance3D.new()
	_halo.name = "Halo"
	var ball := SphereMesh.new()
	ball.radius = SIZE * 3.2
	ball.height = SIZE * 6.4
	ball.radial_segments = 24
	ball.rings = 12
	_halo.mesh = ball
	_halo.material_override = _haze()
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_halo)
	_light = OmniLight3D.new()
	_light.light_color = YELLOW
	_light.light_energy = 0.5
	_light.omni_range = 3.0
	add_child(_light)
	set_glow(glow)
