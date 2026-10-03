class_name MagicCircle
extends Node3D

## A circle of magic, drawn in the air or on the ground: where a spell comes from.
##
## Thin bright line art and nothing else — two rings with marks between them like
## writing, an inner ring with a star drawn in it, and a small ring at the heart —
## in the spell's colour, a little towards white. Drawn over what is behind it
## rather than added to it, so it keeps its colour on a pale floor as well as in
## the dark. It draws itself in a moment, turns
## while it is held (the band one way, the star the other), and when the spell goes
## it flares and fades. The spell leaves through it, so a cast always has a place
## it came from, and a wind-up always has something in the world to read.
##
## It lies flat in its own XZ plane and faces along its own up: see [method facing].
## Or it is wrapped round a ball — the ball of silk a web is wound up in — with its
## lines bent onto it, so it is curved, capping the ball and rolling round it while
## it is held: see [method wrap]. Looks only — nothing in the game reads it.

## How long it takes to draw itself in, and to fade once it is let go, in seconds.
const FORM := 0.18
const FADE := 0.35

## How fast the band and the star turn, in radians a second. Looks only.
const TURN := Vector2(0.6, -1.1)

## How wide its lines are, as a share of its radius, and never thinner than this
## many metres — or, wrapped round a ball, this many: a ball is small, and the
## floor a circle on the ground needs would make its lines fat.
const LINE := 0.018
const LINE_LEAST := 0.003
const WRAP_LINE_LEAST := 0.001

## How much brighter it burns for the moment the spell goes.
const FLARE := 1.8

## How far out each ring sits, as shares of the radius.
const OUTER := 1.0
const BAND := 0.86
const INNER := 0.58
const HEART := 0.16

## How far round a ball a wrapped circle reaches from its middle, in radians: its
## rim a little short of the ball's equator, so it caps the ball.
const WRAP := 1.35

## How far a wrapped circle stands off its ball, as a share of the ball's radius:
## on it, not in it.
const WRAP_LIFT := 1.06

## How far a wrapped circle's middle leans off the top of its ball, in radians, and
## how fast the lean goes round, in radians a second: it rolls round the ball while
## its band and star turn on it.
const LEAN := 0.45
const LEAN_TURN := 1.7

## How long a bent stroke is cut into pieces, as a share of the radius, so it
## follows the ball round rather than cutting through it.
const PIECE := 0.08

var radius := 1.0
var colour := Color(0.8, 0.85, 1.0, 1.0)

## How many points the star in it has. A spell's own number: three for fire, four
## for lightning and so on, so two circles side by side can be told apart.
var points := 6

## Whether it is wrapped round a ball rather than drawn flat. Its radius is then the
## ball's, and its middle is the ball's middle.
var wrapped := false

var _age := 0.0
var _let_go := -1.0
var _lean: Node3D
var _band: MeshInstance3D
var _star: MeshInstance3D
var _paint: StandardMaterial3D


## Draws one under [param host] at [param where], [param wide] metres across from
## the middle to the rim, in [param tint], with a [param star_points]-pointed star.
static func draw(host: Node, where: Transform3D, wide: float, tint: Color,
		star_points := 6) -> MagicCircle:
	return _make(host, where, wide, tint, star_points, false)


## Wraps one round a ball under [param host]: the ball's middle at [param centre]
## and [param wide] metres from there to its surface, the circle capping the top of
## it as [param up] has it, in [param tint], with a [param star_points]-pointed star.
static func wrap(host: Node, centre: Vector3, up: Vector3, wide: float, tint: Color,
		star_points := 6) -> MagicCircle:
	return _make(host, facing(centre, up), wide * WRAP_LIFT, tint, star_points, true)


static func _make(host: Node, where: Transform3D, wide: float, tint: Color, star_points: int,
		bent: bool) -> MagicCircle:
	if host == null:
		return null
	var circle := MagicCircle.new()
	circle.name = "MagicCircle"
	circle.radius = maxf(wide, 0.005 if bent else 0.02)
	circle.colour = tint
	circle.points = maxi(star_points, 3)
	circle.wrapped = bent
	circle.add_to_group("spell_effects")
	host.add_child(circle)
	circle.global_transform = where
	return circle


## A transform that puts a circle at [param at], facing along [param normal].
static func facing(at: Vector3, normal: Vector3) -> Transform3D:
	var up := normal.normalized() if normal.length_squared() > 0.000001 else Vector3.UP
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.95 \
		else Vector3.RIGHT).normalized()
	var ahead := side.cross(up).normalized()
	return Transform3D(Basis(side, up, ahead), at)


func _ready() -> void:
	_paint = StandardMaterial3D.new()
	_paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	_paint.vertex_color_use_as_albedo = true
	_paint.albedo_color = Color(1.0, 1.0, 1.0, 0.0)
	_lean = Node3D.new()
	_lean.name = "Lean"
	add_child(_lean)
	_band = _part("Band", _draw_band())
	_star = _part("Star", _draw_star())
	_show(0.0)


func _process(delta: float) -> void:
	_age += delta
	_band.rotate_y(TURN.x * delta)
	_star.rotate_y(TURN.y * delta)
	if wrapped:
		var going := _age * LEAN_TURN
		_lean.basis = Basis(Vector3(cos(going), 0.0, sin(going)), LEAN)
	if _let_go < 0.0:
		_show(clampf(_age / FORM, 0.0, 1.0))
		return
	var gone := clampf((_age - _let_go) / FADE, 0.0, 1.0)
	if gone >= 1.0:
		queue_free()
		return
	# A flare as the spell goes, then out, opening a little as it fades.
	var flare := lerpf(FLARE, 1.0, gone)
	_paint.albedo_color = Color(flare, flare, flare, 1.0 - gone)
	scale = Vector3.ONE * radius * (1.0 + gone * 0.25)


## Kept where [param where] says while the spell is held, at [param wide] across.
func hold(where: Transform3D, wide: float) -> void:
	if _let_go >= 0.0:
		return
	radius = maxf(wide, 0.02)
	global_transform = where
	_show(clampf(_age / FORM, 0.0, 1.0))


## A wrapped one kept round its ball while it is held: the ball's middle at
## [param centre], [param up] the top of it, and [param wide] metres to its surface.
func hold_round(centre: Vector3, up: Vector3, wide: float) -> void:
	if _let_go >= 0.0:
		return
	radius = maxf(wide * WRAP_LIFT, 0.005)
	global_transform = facing(centre, up)
	_show(clampf(_age / FORM, 0.0, 1.0))


## The spell has gone: flare, fade, and be gone.
func release() -> void:
	if _let_go >= 0.0:
		return
	_let_go = _age


## Whether it has been let go and is on its way out.
func is_fading() -> bool:
	return _let_go >= 0.0


## Drawn in as far as [param formed], 0 to 1: it swells up to its size and fades in.
func _show(formed: float) -> void:
	var eased := 1.0 - pow(1.0 - formed, 3.0)
	scale = Vector3.ONE * radius * lerpf(0.55, 1.0, eased)
	if _paint != null:
		_paint.albedo_color = Color(1.0, 1.0, 1.0, eased)


func _part(part_name: String, strands: WebGeometry.StrandSet) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = part_name
	var tint := colour.lerp(Color.WHITE, 0.2)
	part.mesh = _ribbons(_bend(strands), tint) if wrapped \
		else WebGeometry.build_mesh(strands, tint)
	part.material_override = _paint
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lean.add_child(part)
	return part


## [param strands], drawn flat, bent onto a ball of radius one round the middle: a
## point some way out from the middle goes that far times [constant WRAP] round the
## ball from its top, the way it was facing. Long strokes are cut into pieces first,
## so they bend with the ball.
static func _bend(strands: WebGeometry.StrandSet) -> WebGeometry.StrandSet:
	var bent := WebGeometry.StrandSet.new()
	for i in strands.size():
		var a := strands.starts[i]
		var b := strands.ends[i]
		var pieces := maxi(1, ceili(a.distance_to(b) / PIECE))
		var last := _on_ball(a)
		for step in range(1, pieces + 1):
			var next := _on_ball(a.lerp(b, float(step) / float(pieces)))
			bent.add(last, next, strands.widths[i])
			last = next
	return bent


## [param strands] on a ball of radius one, drawn as flat ribbons lying on it: one
## strip a stroke, rather than the crossed pair a flat circle's lines are drawn as.
## On a ball the second of the pair stands straight out from it, and round the
## ball's edge, seen side on, it is a thick fin rather than a line.
static func _ribbons(strands: WebGeometry.StrandSet, tint: Color) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in strands.size():
		var a := strands.starts[i]
		var b := strands.ends[i]
		var out := ((a + b) * 0.5).normalized()
		var side := (b - a).cross(out)
		if side.length_squared() < 0.0000001:
			continue
		side = side.normalized() * strands.widths[i] * 0.5
		for corner: Vector3 in [a - side, a + side, b + side, a - side, b + side, b - side]:
			tool.set_color(tint)
			tool.set_normal(out)
			tool.add_vertex(corner)
	return tool.commit()


## Where the flat point [param flat] goes on a ball of radius one capped from its top.
static func _on_ball(flat: Vector3) -> Vector3:
	var across := Vector2(flat.x, flat.z)
	var out := across.length()
	if out < 0.000001:
		return Vector3.UP
	var turned := out * WRAP
	across /= out
	return Vector3(across.x * sin(turned), cos(turned), across.y * sin(turned))


## The outer band: two rings, and marks between them like a line of writing.
func _draw_band() -> WebGeometry.StrandSet:
	var strands := WebGeometry.StrandSet.new()
	var width := _width()
	_ring(strands, OUTER, 64, width * 1.2)
	_ring(strands, BAND, 64, width * 0.8)
	var marks := 24
	for i in marks:
		var turn := TAU * float(i) / float(marks)
		var gap := (OUTER - BAND)
		var low := BAND + gap * 0.22
		var high := OUTER - gap * 0.22
		if i % 3 == 0:
			# A short upright stroke.
			strands.add(_at(turn, low), _at(turn, high), width * 0.7)
		elif i % 3 == 1:
			# A small chevron.
			var mid := (low + high) * 0.5
			strands.add(_at(turn - 0.04, low), _at(turn + 0.02, mid), width * 0.6)
			strands.add(_at(turn + 0.02, mid), _at(turn - 0.04, high), width * 0.6)
		else:
			# A dot of a stroke, off centre.
			strands.add(_at(turn, (low + high) * 0.5), _at(turn + 0.05, (low + high) * 0.5),
				width * 0.7)
	return strands


## The inner ring with the star drawn in it, and the small ring at the heart.
func _draw_star() -> WebGeometry.StrandSet:
	var strands := WebGeometry.StrandSet.new()
	var width := _width()
	_ring(strands, INNER, 48, width)
	_ring(strands, HEART, 24, width * 0.8)
	# A star of [member points] points, drawn as one line that skips round the ring:
	# every second point for an odd star, two triangles' worth for an even one.
	var count := points
	var step := 2 if count % 2 == 1 or count < 6 else count / 2 - 1
	if count == 4:
		step = 1
	var corner := INNER * 0.97
	for i in count:
		var a := _at(TAU * float(i) / float(count), corner)
		var b := _at(TAU * float((i + step) % count) / float(count), corner)
		strands.add(a, b, width * 0.9)
	if count == 4:
		# A square on its point, and a second one square to it: an eight-point star.
		for i in count:
			var turn := TAU * (float(i) + 0.5) / float(count)
			var next := TAU * (float(i) + 1.5) / float(count)
			strands.add(_at(turn, corner), _at(next, corner), width * 0.9)
	# Spokes from the heart to the inner ring, between the points.
	for i in count:
		var turn := TAU * (float(i) + 0.5) / float(count)
		strands.add(_at(turn, HEART), _at(turn, INNER * 0.5), width * 0.6)
	return strands


func _ring(strands: WebGeometry.StrandSet, at: float, pieces: int, width: float) -> void:
	var previous := _at(0.0, at)
	for i in range(1, pieces + 1):
		var point := _at(TAU * float(i) / float(pieces), at)
		strands.add(previous, point, width)
		previous = point


## A point [param across] of the radius out from the middle, [param turn] round.
## Drawn at a radius of one: the node's scale is the radius.
static func _at(turn: float, across: float) -> Vector3:
	return Vector3(cos(turn) * across, 0.0, sin(turn) * across)


## How wide its lines are, as a share of its radius.
func _width() -> float:
	if wrapped:
		return maxf(LINE, WRAP_LINE_LEAST / maxf(radius, 0.005))
	return maxf(LINE, LINE_LEAST / maxf(radius, 0.02))
