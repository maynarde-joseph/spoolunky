class_name Fly
extends Node3D

## A fly: something to catch, and once caught, somewhere to go.
##
## A web that flies into a fly wraps it, and the fly stops dead where it was, held
## in the middle of the air by your web — which counts as one of yours out until you
## deal with it. Ride a web into it (hold left mouse at it, caught or not; a new web
## takes a caught fly over) and you take it: the fly is yours, the web comes back,
## the grapple with it, and you hang strung up in the air for a moment. Or call the
## web home and the fly comes with it, and is yours without your going anywhere.
##
## The bag at the exit only opens once every fly in the level is taken — so a level
## with flies is a route: which to use as stepping stones, which to pull in, and in
## what order.
##
## A fly keeps still, flies back and forth along a line, or circles round where it
## was put, all three on the level's clock: the same at the same time on every try.
##
## It looks like a cartoon fly — a round black body with a sheen of eye, and two
## pale wings with black rims — big, and always turned to face you, so its shape
## reads from across a room. It can glow yellow, too.

signal taken(fly: Fly)

enum State {
	FREE,    ## flying, or hanging still where it was put
	CAUGHT,  ## wrapped in a web, held in the air
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
## Kept where it was put, as the level editor shows it: it still flaps and turns
## to face you, but goes nowhere.
var frozen := false

var state := State.FREE
## The web holding it, while it is caught.
var web: Node3D = null

var _home := Vector3.ZERO
var _view: Node3D
var _wings: Array[Node3D] = []
var _cocoon: MeshInstance3D
var _halo: MeshInstance3D
var _light: OmniLight3D
var _flap := 0.0


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


## Wrapped by [param holder]: it stops where it is, folds its wings, and waits. A
## caught fly can be caught again, by a new web that takes it over.
func catch(holder: Node3D) -> void:
	if state == State.TAKEN:
		return
	state = State.CAUGHT
	web = holder
	_cocoon.visible = true
	for wing in _wings:
		wing.visible = false


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
	if state == State.FREE:
		if not frozen:
			var run := LevelRun.current(self)
			_place(run.time if run != null else 0.0)
		_flap += delta * 40.0
	for i in _wings.size():
		var side := -1.0 if i == 0 else 1.0
		_wings[i].rotation.z = -side * (0.15 + sin(_flap) * 0.3)
	# Turned to face whoever is looking, like the cartoon it is.
	var camera := get_viewport().get_camera_3d()
	if camera != null and _view != null:
		var to := camera.global_position - global_position
		if to.length_squared() > 0.01:
			var up := Vector3.UP if absf(to.normalized().y) < 0.98 else Vector3.FORWARD
			_view.global_basis = Basis.looking_at(-to, up).scaled(_view.global_basis.get_scale())


func _place(seconds: float) -> void:
	if state == State.FREE:
		global_position = where_at(seconds)


# --- how it looks ------------------------------------------------------------------

func _build() -> void:
	_view = Node3D.new()
	_view.name = "View"
	add_child(_view)

	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.05, 0.05, 0.06)
	black.roughness = 0.45
	black.rim_enabled = true
	black.rim = 0.6
	black.rim_tint = 0.2

	var body := MeshInstance3D.new()
	body.name = "Body"
	var ball := SphereMesh.new()
	ball.radius = SIZE
	ball.height = SIZE * 2.0
	body.mesh = ball
	body.material_override = black
	_view.add_child(body)

	# The sheen: a grey eye low on the side facing you, off to one side.
	var eye := MeshInstance3D.new()
	eye.name = "Eye"
	var spot := SphereMesh.new()
	spot.radius = SIZE * 0.36
	spot.height = SIZE * 0.2
	eye.mesh = spot
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.42, 0.42, 0.44)
	grey.roughness = 0.3
	eye.material_override = grey
	eye.position = Vector3(-SIZE * 0.22, -SIZE * 0.18, SIZE * 0.93)
	eye.rotation.x = PI * 0.5
	_view.add_child(eye)

	# The wings: two round loops over its back, pale inside a thick black rim.
	# Flat, like ink and paper: no light changes them.
	var pale := StandardMaterial3D.new()
	pale.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pale.albedo_color = Color(0.93, 0.93, 0.95)
	pale.cull_mode = BaseMaterial3D.CULL_DISABLED
	var rim := StandardMaterial3D.new()
	rim.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rim.albedo_color = Color(0.04, 0.04, 0.05)
	rim.cull_mode = BaseMaterial3D.CULL_DISABLED
	for side in [-1.0, 1.0]:
		var shoulder := Node3D.new()
		shoulder.name = "Wing"
		shoulder.position = Vector3(side * SIZE * 0.4, SIZE * 0.6, -SIZE * 0.1)
		_view.add_child(shoulder)
		var outline := MeshInstance3D.new()
		outline.mesh = _wing_mesh(SIZE * 1.45, SIZE * 1.05)
		outline.material_override = rim
		outline.position = Vector3(side * SIZE * 0.3, SIZE * 0.7, -0.01)
		outline.rotation.z = -side * 0.35
		shoulder.add_child(outline)
		var fill := MeshInstance3D.new()
		fill.mesh = _wing_mesh(SIZE * 1.1, SIZE * 0.72)
		fill.material_override = pale
		fill.position = Vector3(side * SIZE * 0.33, SIZE * 0.78, 0.01)
		fill.rotation.z = -side * 0.35
		shoulder.add_child(fill)
		_wings.append(shoulder)

	# Wrapped: a ball of silk round it.
	_cocoon = MeshInstance3D.new()
	_cocoon.name = "Cocoon"
	var wrap := SphereMesh.new()
	wrap.radius = SIZE * 1.15
	wrap.height = SIZE * 2.6
	_cocoon.mesh = wrap
	var silk := StandardMaterial3D.new()
	silk.albedo_color = Color(0.95, 0.96, 1.0, 0.8)
	silk.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	silk.emission_enabled = true
	silk.emission = Color(0.85, 0.9, 1.0)
	silk.emission_energy_multiplier = 0.4
	_cocoon.material_override = silk
	_cocoon.visible = false
	_view.add_child(_cocoon)

	# The glow: a soft yellow halo and a little light.
	_halo = MeshInstance3D.new()
	_halo.name = "Halo"
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * SIZE * 7.0
	_halo.mesh = quad
	var soft := GradientTexture2D.new()
	soft.fill = GradientTexture2D.FILL_RADIAL
	soft.fill_from = Vector2(0.5, 0.5)
	soft.fill_to = Vector2(0.5, 0.0)
	var fade := Gradient.new()
	fade.set_color(0, Color(YELLOW, 0.7))
	fade.set_color(1, Color(YELLOW, 0.0))
	soft.gradient = fade
	var haze := StandardMaterial3D.new()
	haze.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	haze.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	haze.albedo_texture = soft
	haze.no_depth_test = false
	haze.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_halo.material_override = haze
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_halo.position.z = -SIZE * 1.2
	_view.add_child(_halo)
	_light = OmniLight3D.new()
	_light.light_color = YELLOW
	_light.light_energy = 1.2
	_light.omni_range = 4.0
	add_child(_light)
	set_glow(glow)
	for node in [body, eye] + _cocoon.get_children():
		if node is GeometryInstance3D:
			(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## A flat rounded wing, [param long] from root to tip and [param wide] across, in
## the xy plane, its root at the origin, pointing up.
static func _wing_mesh(long: float, wide: float) -> ArrayMesh:
	var outline := PackedVector2Array()
	for i in 24:
		var angle := TAU * float(i) / 24.0
		# An egg: fuller at the tip than at the root.
		var y := sin(angle) * long * 0.5
		var x := cos(angle) * wide * 0.5 * (1.0 + 0.25 * sin(angle))
		outline.append(Vector2(x, y))
	var corners := PackedVector3Array()
	for point in outline:
		corners.append(Vector3(point.x, point.y, 0.0))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = corners
	arrays[Mesh.ARRAY_INDEX] = Geometry2D.triangulate_polygon(outline)
	var normals := PackedVector3Array()
	normals.resize(corners.size())
	normals.fill(Vector3.BACK)
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
